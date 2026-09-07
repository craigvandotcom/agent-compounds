#!/usr/bin/env python3
# ---
# id: 04-readme-disk
# prevents: README drift — a skill or agent that exists on disk but is never mentioned, a README table row linking to a skill or agent that is not there, and the link-existence sub-checks silently no-oping when README.md itself is missing
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/04-readme-disk
# ---
"""04-readme-disk — README.md and the disk agree in both directions.

The legacy lint.sh Check 4 block's four legs over README.md:

  4a  every skills/<name>/ with a SKILL.md is mentioned in README.md
  4b  every agents/<name>.md is mentioned in README.md
  4c  every README link of the form ](./skills/<name>/) resolves to a dir
  4d  every README link of the form ](./agents/<name>.md) resolves to a file

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
        findings.append(f"README: {os.path.abspath(readme)} is missing — Check 4c/4d's link-existence sub-checks silently no-op without it")

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
