#!/usr/bin/env python3
# ---
# id: 04-readme-disk
# prevents: README drift — a skill or agent that exists on disk but is never mentioned, a README table
#   row linking to a skill or agent that is not there, a skill-table row naming a skill in plain bold
#   text (no link) that does not exist on disk, and the link-existence sub-checks silently no-oping
#   when README.md itself is missing
# scope: LIVE_TEXT README
# severity: fail
# fixture: lint/fixtures/04-readme-disk
# ---
"""04-readme-disk — README.md and the disk agree in both directions.

The legacy lint.sh Check 4 block's four legs over README.md, plus a fifth
leg absorbed from the retired Check 26 (ac-1p7j.5, folded in 2026-09-12):

  4a  every skills/<name>/ with a SKILL.md is mentioned in README.md
  4b  every agents/<name>.md is mentioned in README.md
  4c  every README link of the form ](./skills/<name>/) resolves to a dir
  4d  every README link of the form ](./agents/<name>.md) resolves to a file
  4e  every PLAIN-BOLD first-cell name in a Skill-table row (no markdown
      link — e.g. `**ac-gone**`) resolves to skills/<name>/SKILL.md. 4c only
      greps link-form rows (`](./skills/<name>/)`); a row whose first cell
      is bare bold text names a dead skill invisibly without this leg. Only
      the FIRST cell of a data row is a candidate (mid-row bold text is
      prose, e.g. `**no probe, no bead**` inside another cell) and only
      tables whose header's first cell is exactly `Skill` are governed —
      the Agent and Dependency tables name stances and CLIs that are
      deliberately not skill dirs (`**openrouter**`). Link-form rows are
      left to leg 4c so a ghost is never reported twice.

A missing README.md is itself a FAIL (the link legs silently no-op without
it) — the check fails closed, it never passes on an absent sensor.

Exit: 0 every leg holds and something was scanned, 1 findings, 2 nothing
scanned (NOT-GATED, never a pass).
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "04-readme-disk"
SKILL_LINK_RE = re.compile(r"\]\(\./skills/([^/]+)/\)")
AGENT_LINK_RE = re.compile(r"\]\(\./agents/([^)]*?)\.md\)")
BOLD_LINK_RE = re.compile(r"\[([^\]]*)\]\(\./skills/([^/]+)/\)")
BOLD_BARE_RE = re.compile(r"^\*\*([A-Za-z0-9][A-Za-z0-9._-]*)\*\*$")
TABLE_SEP_RE = re.compile(r"^\|[ :|-]+\|?\s*$")


def _first_cell(line):
    parts = line.split("|")
    return parts[1].strip() if len(parts) > 2 else ""


def _skill_table_bare_ghosts(root, text):
    """Leg 4e: bare-bold Skill-table rows naming a skill absent on disk."""
    findings = []
    rows = 0
    lines = text.splitlines()
    table_kind = None
    for lineno, line in enumerate(lines, 1):
        if not line.startswith("|"):
            table_kind = None
            continue
        nxt = lines[lineno] if lineno < len(lines) else ""
        if TABLE_SEP_RE.match(line):
            continue
        cell = _first_cell(line)
        if nxt.startswith("|") and TABLE_SEP_RE.match(nxt):
            # A row immediately followed by a separator line IS the header
            # row: its first cell names the table kind.
            table_kind = cell
            continue
        if not (cell.startswith("**") and cell.endswith("**")):
            continue
        inner = cell[2:-2]
        if BOLD_LINK_RE.search(inner):
            continue  # link-form row: leg 4c already resolves it
        bare = BOLD_BARE_RE.match(cell)
        if not bare:
            continue
        if table_kind != "Skill":
            continue
        name = bare.group(1)
        rows += 1
        if not os.path.isfile(os.path.join(root, "skills", name, "SKILL.md")):
            findings.append(
                f"README.md:{lineno}: skill-table row names '{name}' but "
                f"skills/{name}/SKILL.md does not exist — a ghost row: remove it "
                "or restore the skill")
    return findings, rows


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT
    readme = os.path.join(root, "README.md")
    findings = []
    scanned = 0
    text = ""
    if os.path.isfile(readme):
        with open(readme, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    else:
        findings.append(f"README: {os.path.abspath(readme)} is missing — Check 4c/4d's "
                        "link-existence sub-checks silently no-op without it")

    skills_dir = os.path.join(root, "skills")
    if os.path.isdir(skills_dir):
        for d in sorted(os.listdir(skills_dir)):
            if os.path.isfile(os.path.join(skills_dir, d, "SKILL.md")):
                scanned += 1
                if d not in text:
                    findings.append(f"README: skill '{d}' (has SKILL.md) not mentioned in README.md")
    agents_dir = os.path.join(root, "agents")
    if os.path.isdir(agents_dir):
        for fn in sorted(os.listdir(agents_dir)):
            if fn.endswith(".md") and os.path.isfile(os.path.join(agents_dir, fn)):
                scanned += 1
                name = fn[:-3]
                if name not in text:
                    findings.append(f"README: agent '{name}' not mentioned in README.md")
    seen = set()
    for m in SKILL_LINK_RE.finditer(text):
        name = m.group(1)
        if name in seen:
            continue
        seen.add(name)
        scanned += 1
        if not os.path.isdir(os.path.join(root, "skills", name)):
            findings.append(f"README: links to ./skills/{name}/ but that directory does not exist")
    seen = set()
    for m in AGENT_LINK_RE.finditer(text):
        name = m.group(1)
        if name in seen:
            continue
        seen.add(name)
        scanned += 1
        if not os.path.isfile(os.path.join(root, "agents", f"{name}.md")):
            findings.append(f"README: links to ./agents/{name}.md but that file does not exist")

    if text:
        bare_findings, bare_rows = _skill_table_bare_ghosts(root, text)
        scanned += bare_rows
        findings.extend(bare_findings)

    if scanned == 0:
        print(f"{CHECK_ID} NOT-CHECKED: no README, skills or agents under {root} — verified nothing", file=sys.stderr)
        return 2
    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    if findings:
        return 1
    print(f"  ok: {CHECK_ID} — README and the disk agree ({scanned} surface(s) checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
