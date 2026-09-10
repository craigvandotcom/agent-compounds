#!/usr/bin/env python3
# ---
# id: 26-readme-ghosts
# prevents: a README table row naming a skill that no longer exists on disk — an archived or renamed
#   skill keeping a standing row that advertises a dead invocation (Check 4c resolves only rows
#   written as ](./skills/<name>/) links, so a plain-text ghost row passes unseen)
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/26-readme-ghosts
# ---
"""26-readme-ghosts — every skill a README table row names resolves on disk (ac-1p7j.5).

Check 4c only greps markdown link rows (`](./skills/<name>/)`); a row whose first
cell is plain bold text (`**ac-gone**`) names a dead skill invisibly. This check
resolves EVERY first-cell skill name in every README table whose header row says
`Skill` — both link form (resolve the linked dir) and plain form (resolve the
bare name) — against `skills/<name>/SKILL.md`.

Only the FIRST cell of a data row is a skill name: mid-row bold text is prose
(`**no probe, no bead**` inside the ac-beadify row). Only tables whose header's
first cell is `Skill` are governed: the Agent and Dependency tables name stances
and CLIs that are deliberately not skill dirs (`**openrouter**`).

scope: LIVE_TEXT is the nearest standing set lib.scope exposes — there is no
README set, and adding one is outside this bead (ac-1p7j.5). The check scans
README.md only; the misdeclared set costs a `--changed` skip window when a
diff touches no LIVE_TEXT file, never a false pass on a bare run.

Exit: 0 clean, 1 ghost rows, 2 scanned nothing (no README or no Skill table —
NOT-GATED, never a pass).
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))
from lib import scope  # noqa: E402

LINK_RE = re.compile(r"\[([^\]]*)\]\(\./skills/([^/]+)/\)")
BARE_RE = re.compile(r"^\*\*([A-Za-z0-9][A-Za-z0-9._-]*)\*\*$")
SEP_RE = re.compile(r"^\|[ :|-]+\|?\s*$")

violations = []


def first_cell(line):
    parts = line.split("|")
    return parts[1].strip() if len(parts) > 2 else ""


def scan(root):
    readme = os.path.join(root, "README.md")
    if not os.path.isfile(readme):
        print("26-readme-ghosts NOT-CHECKED: no README.md under this root — nothing scanned")
        return 2
    with open(readme, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    table_kind = None
    rows = 0
    for lineno, line in enumerate(lines, 1):
        if not line.startswith("|"):
            table_kind = None
            continue
        nxt = lines[lineno] if lineno < len(lines) else ""
        if SEP_RE.match(line):
            continue
        cell = first_cell(line)
        if nxt.startswith("|") and SEP_RE.match(nxt):
            # A row followed by a separator line IS the header row: its first
            # cell names the table kind. Any other non-bold row is a malformed
            # data row, and it must NOT silently stop governance of this table.
            table_kind = cell
            continue
        if not (cell.startswith("**") and cell.endswith("**")):
            continue
        inner = cell[2:-2]
        link = LINK_RE.search(inner)
        if link:
            name = link.group(2)
        else:
            bare = BARE_RE.match(cell)
            if not bare:
                continue
            name = bare.group(1)
        if table_kind != "Skill":
            continue
        rows += 1
        if not os.path.isfile(os.path.join(root, "skills", name, "SKILL.md")):
            violations.append(
                f"README.md:{lineno}: skill-table row names '{name}' but "
                f"skills/{name}/SKILL.md does not exist — a ghost row: remove it "
                "or restore the skill")
    print(f"26-readme-ghosts: {rows} skill-table row(s) resolved against disk")
    if violations:
        print("FAIL 26-readme-ghosts: skill-table row(s) naming a missing skill:")
        for v in violations:
            print(f"  - {v}")
        return 1
    print("26-readme-ghosts: PASS")
    return 0


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)
    return scan(root)


if __name__ == "__main__":
    sys.exit(main())
