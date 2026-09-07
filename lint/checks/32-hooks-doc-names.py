#!/usr/bin/env python3
# ---
# id: 32-hooks-doc-names
# prevents: hooks/hooks.json documentation text (the `_doc` fields and `assurance` entries) naming skills that do not exist — prose pointing operators and agents at archived or never-built skills, the way the fail-open rationale once justified itself by naming the retired ac-loop and ac-bead-refine
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/32-hooks-doc-names
# ---
"""32-hooks-doc-names — every skill named in hooks.json prose must resolve.

The hook WIRING manifest's `_doc` fields and `assurance` entries are the
doctrine an operator or agent reads to understand why a hook behaves as it
does. When that prose names a skill, the name must resolve against the LIVE
skill roster — a reference to an archived or missing skill is a stale claim
that silently misdirects the reader (the fail-open rationale that named the
retired ac-loop is the found instance).

Two reference shapes are resolved, the only unambiguous ones in prose:
  1. `skills/<segment>...` path references — the segment (or the full file
     path) must exist on the live tree.
  2. bare `ac-<name>` tokens — the ac- family is name-shaped and unique, so
     `ac-<name>` must be a live skills/ac-<name> directory (Check 2's xref
     shape). Tokens that are not skill references are excluded mechanically:
     one preceded by a path separator or followed by `.<ext-or-digit>` is a
     file name or a bead id (`plugins/ac-hooks.js`, `ac-on0y.5`), never a
     skill. Bare non-ac words are never guessed at.

The scanned surfaces are the prose the bead names — every `_doc` field and
every `assurance.BACKSTOP` entry. Structured reference fields
(`assurance.PENDING-DECISION` et al) hold bead ids by contract, not skill
prose, and are out of scope.

The live roster is derived from the shared scope model — the skills/*/SKILL.md
members of LIVE_TEXT — never from a hand-kept list. The manifest itself is a
single named config input (the lint/config.json precedent in Check 14), read
directly; scope declares LIVE_TEXT because the roster it resolves against is
the live skill population.

Exit: 0 every reference resolves (and the manifest exists), 1 findings,
2 nothing verified (no manifest).
"""

import json
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

MANIFEST = "hooks/hooks.json"
SKILL_RE = re.compile(r"^skills/([^/]+)/SKILL\.md$")
SKILLS_PATH_RE = re.compile(r"\bskills/[A-Za-z0-9_./-]+")


def live_roster():
    """Skill dir names derived from the scope model, never hand-kept."""
    return {
        m.group(1) for p in scope.LIVE_TEXT if (m := SKILL_RE.match(p))
    }


def walk_prose(node, path=""):
    """Strings at the prose surfaces: `_doc` fields and `assurance.BACKSTOP`."""
    if isinstance(node, dict):
        for k, v in node.items():
            yield from walk_prose(v, path + "/" + k)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk_prose(v, f"{path}[{i}]")
    elif isinstance(node, str):
        if path.endswith("/_doc") or path.endswith("/BACKSTOP"):
            yield path, node


def resolvable_ac_tokens(text):
    """Bare ac- tokens that claim to be skill references, files and bead ids
    (path-adjacent or dot-suffixed) excluded."""
    out = []
    for m in re.finditer(r"(?<![/\w.-])(ac-[a-z][a-z0-9-]*)(?![-/\w.])", text):
        out.append(m.group(1))
    return out


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    manifest = os.path.join(root, MANIFEST)
    if not os.path.isfile(manifest):
        print(f"32-hooks-doc-names NOT-CHECKED: {MANIFEST} not found — verified nothing", file=sys.stderr)
        return 2
    try:
        with open(manifest, encoding="utf-8") as fh:
            hooks = json.load(fh)
    except (json.JSONDecodeError, OSError) as exc:
        # A manifest that cannot be parsed fails loud with a named reason —
        # never a bare traceback (an unhandled exception exits 1 too, but with
        # no finding an operator cannot tell a broken manifest from a broken
        # check).
        print(f"FAIL 32-hooks-doc-names: {MANIFEST} is unreadable ({exc}) — the prose gate has nothing to verify")
        return 1

    roster = live_roster()
    findings = []
    scanned = 0
    for path, text in walk_prose(hooks):
        scanned += 1
        for m in SKILLS_PATH_RE.finditer(text):
            ref = m.group(0)
            # A sentence period/comma/paren after the path is prose, not path.
            ref = ref.rstrip(".,;:!?)]}")
            if not (os.path.isdir(os.path.join(root, ref)) or os.path.isfile(os.path.join(root, ref))):
                findings.append(f"{path}: skills/ path reference '{ref}' does not exist on the live tree")
        for name in resolvable_ac_tokens(text):
            if name not in roster:
                findings.append(f"{path}: skill reference '{name}' names no live skills/{name}/ directory")

    findings = sorted(set(findings))
    if findings:
        print("FAIL 32-hooks-doc-names: hooks.json prose names unresolvable skill reference(s):")
        for f in findings:
            print(f"    {f}")
        return 1
    print(f"  ok: 32-hooks-doc-names — every skill reference in {scanned} _doc/BACKSTOP prose field(s) of "
          f"{MANIFEST} resolves against the live roster ({len(roster)} skills)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
