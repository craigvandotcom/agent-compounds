#!/usr/bin/env python3
# ---
# id: 2-ac-cross-references
# prevents: /ac-skill cross-references in live skill text pointing at a skill directory that does not exist — an invocation of a skill the registry does not ship
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/2-ac-cross-references
# ---
"""2-ac-cross-references — every /ac-* invocation in live skill text resolves.

The legacy lint.sh Check 2 block, ported to the runner.

SCOPE: the pattern is `/ac-[a-z]...`. Since the pipeline rename it matches the
WHOLE pipeline family — the former blind spot (invocations of the old prefixed
family, invisible here and resolved by Check 23 instead) no longer exists. Do
not widen the regex without re-reading that history — one engine per pattern.

An INVOCATION is `/ac-<name>` at line start or after a non-path character
(space, quote, backtick, bracket). Preceded by a letter, digit, dot or slash
it is a PATH SEGMENT — `/tmp/ac-claim.txt`, `scripts/ac-budget-check.sh`,
`_archive/skills/ac-loop/` — and naming a file is not invoking a skill.
It is TERMINAL: never followed by `/` or `:`. `/ac-example-bead:start` is a
sed address, `<git-common-dir>/ac-flight/` is a directory.

A token that appears ONLY as a glob shorthand (`/ac-plan-refine-*`) is not a
concrete invocation and is skipped — unless a real skill dir carries the name.

Exit: 0 every token resolves and at least one file scanned, 1 findings,
2 nothing scanned (NOT-GATED, never a pass).
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

CHECK_ID = "2-ac-cross-references"

# An INVOCATION: line start or after a non-path char (letter/digit/dot/slash
# would make it a PATH SEGMENT); never followed by `/` or `:` (a sed address
# or a directory). One trailing char is matched and stripped.
TOKEN_RE = re.compile(r"(^|[^A-Za-z0-9_./-])/ac-[a-z][a-z-]*[a-z]([^A-Za-z0-9_/:-]|$)")
GLOB_RE = re.compile(r"(^|[^A-Za-z0-9_./-])/ac-[a-z][a-z-]*[a-z]-\*")

SCAN_LEAVES = ("SKILL.md", "references", "workflows")


def iter_skill_files(skills_dir):
    for name in sorted(os.listdir(skills_dir)):
        skill_dir = os.path.join(skills_dir, name)
        if not os.path.isdir(skill_dir):
            continue
        leaf = os.path.join(skill_dir, "SKILL.md")
        if os.path.isfile(leaf):
            yield leaf
        for sub in SCAN_LEAVES[1:]:
            subdir = os.path.join(skill_dir, sub)
            if not os.path.isdir(subdir):
                continue
            for fn in sorted(os.listdir(subdir)):
                if fn.endswith(".md"):
                    yield os.path.join(subdir, fn)


def main():
    import argparse

    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("root", nargs="?", default=None,
                    help="repo root to lint (default: this checkout)")
    args = ap.parse_args()
    root = args.root or scope.ROOT
    skills_dir = os.path.join(root, "skills")
    if not os.path.isdir(skills_dir):
        print(f"{CHECK_ID} NOT-CHECKED: no skills/ directory under {root} — verified nothing",
              file=sys.stderr)
        return 2

    tokens: list[str] = []
    glob_prefixes: list[str] = []
    scanned = 0
    for path in iter_skill_files(skills_dir):
        scanned += 1
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        for m in TOKEN_RE.finditer(text):
            tok = m.group(0)
            tok = tok[1:] if tok[0] != "/" else tok          # strip the boundary char
            tok = tok[:-1] if tok[-1] not in "abcdefghijklmnopqrstuvwxyz" else tok  # strip the terminal char
            tokens.append(tok)
        for m in GLOB_RE.finditer(text):
            g = m.group(0)
            g = g[1:] if g[0] != "/" else g
            g = g[:-2] if g.endswith("-*") else g
            glob_prefixes.append(g)

    if scanned == 0:
        print(f"{CHECK_ID} NOT-CHECKED: no SKILL.md/references/workflows file under skills/ in {root} — verified nothing",
              file=sys.stderr)
        return 2

    distinct = sorted({t[1:] for t in tokens if re.fullmatch(r"/ac-[a-z][a-z-]*", t)})
    globs = set(glob_prefixes)

    findings = []
    for tok in distinct:
        # Skip tokens that only appear as glob shorthands — a token is a pure
        # glob prefix if it does NOT exist as a skill dir AND appears in the
        # glob list. If the skill dir exists it is fine either way.
        if not os.path.isdir(os.path.join(skills_dir, tok)) and tok in globs:
            continue
        if not os.path.isdir(os.path.join(skills_dir, tok)):
            findings.append(f"/{tok} referenced in skills but skills/{tok}/ does not exist")

    for f in findings:
        print(f"FAIL {CHECK_ID}: {f}")
    if findings:
        return 1
    print(f"  ok: {CHECK_ID} — every /ac-* invocation resolves "
          f"({scanned} file(s) scanned, {len(distinct)} token(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
