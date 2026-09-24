#!/usr/bin/env python3
# ---
# id: 30-trigger-collisions
# prevents: two skills both quoting the same trigger phrase, so one phrase selects two skills and skill
#   selection is ambiguous — the mechanical half of ac-registry-audit's trigger-collision pass (the
#   WS1 fold that retired that workflow)
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/30-trigger-collisions
# ---
"""30-trigger-collisions — the quoted-trigger-phrase uniqueness gate.

Every skills/*/SKILL.md description's quoted phrases (double- and
single-quoted, parsed through the shared YAML-subset frontmatter parser) are
tokenised and normalised (casefolded, whitespace-collapsed). A phrase that
appears in TWO DISTINCT skills' descriptions is a collision: the phrase
selects two skills, so it can no longer select either deterministically.

Tokenizer guards against the known false-positive classes: a single-quoted
span that crosses into double-quoted text (the `', "what` artifact — dropped,
a phrase token never contains a quote character of the other style); and a
phrase quoted twice inside ONE description (not a collision — the rule is
about selection across skills, and a description re-quoting its own phrase
still selects one skill).

No allowlist: every live collision is a violation. Fix it by separating the
phrases in the same commit that introduced the collision.

Exit: 0 clean (and at least one description scanned), 1 findings, 2 scanned
nothing.
"""

import os
import re
import sys

import _bootstrap  # noqa: F401
from lib import frontmatter, scope  # noqa: E402

SKILL_RE = re.compile(r"^skills/([^/]+)/SKILL\.md$")


def tokenize(description):
    """Quoted phrases from a parsed description, normalised, artifacts dropped."""
    # lib.frontmatter strips outer quotes but does not unescape YAML's doubled
    # single-quote ('' -> ') inside a quoted scalar; restore it here so a
    # phrase tokenises as written ("what''s" -> "what's").
    text = description.replace("''", "'")
    phrases = []
    for q in re.findall(r'"([^"]{3,})"', text):
        phrases.append(q)
    for q in re.findall(r"'([^']{3,})'", text):
        if '"' in q:
            continue  # span crossed into double-quoted text — parse artifact
        phrases.append(q)
    out = set()
    for p in phrases:
        norm = re.sub(r"\s+", " ", p).strip().lower()
        if len(norm) >= 3:
            out.add(norm)
    return out


def scan_skills(root):
    """(phrase -> {skill}) over every live skill description, plus scanned count."""
    owners = {}
    scanned = 0
    for p in sorted(scope.LIVE_TEXT):
        m = SKILL_RE.match(p)
        if not m:
            continue
        full = os.path.join(root, p)
        if not os.path.isfile(full):
            continue
        scanned += 1
        with open(full, encoding="utf-8") as fh:
            fm = frontmatter.parse(fh.read())
        for phr in tokenize(str(fm.get("description", ""))):
            owners.setdefault(phr, set()).add(m.group(1))
    return owners, scanned


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    owners, scanned = scan_skills(root)
    if scanned == 0:
        print("30-trigger-collisions NOT-CHECKED: no skills/*/SKILL.md description found — verified "
              "nothing", file=sys.stderr)
        return 2

    collisions = {p: sorted(s) for p, s in owners.items() if len(s) > 1}

    if collisions:
        print("FAIL 30-trigger-collisions: quoted trigger phrase(s) selecting more than one skill:")
        for phrase in sorted(collisions):
            print(f"    trigger collision: '{phrase}' is quoted by {', '.join(collisions[phrase])} "
                  f"— one phrase selecting two skills is ambiguous; separate the phrases")
        return 1

    print(f"  ok: 30-trigger-collisions — {scanned} description(s) tokenised, 0 collisions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
