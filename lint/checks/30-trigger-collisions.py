#!/usr/bin/env python3
# ---
# id: 30-trigger-collisions
# prevents: two skills both quoting the same trigger phrase, so one phrase selects two skills and skill selection is ambiguous — the mechanical half of ac-registry-audit's trigger-collision pass (the WS1 fold that retired that workflow)
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

Known collisions land in a dated SHRINK-ONLY allowlist
(lint/allowlists/30-trigger-collisions.txt), the same ratchet contract as
Check 27's instance-token allowlist:

    # seeded: YYYY-MM-DD
    <date> | <phrase> | <skill>,<skill>

An entry dated after the seed is refused (the allowlist only shrinks); an
entry whose collision no longer reproduces is refused (a description edit
that separates the phrases forces its line out in the same change); a
malformed allowlist (missing seed header, bad date, phrase not in the live
collision set) fails loud.

Exit: 0 clean (and at least one description scanned), 1 findings, 2 scanned
nothing.
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import frontmatter, scope  # noqa: E402

ALLOWLIST = "lint/allowlists/30-trigger-collisions.txt"
SEED_RE = re.compile(r"^#\s*seeded:\s*(\d{4}-\d{2}-\d{2})\s*$")
ENTRY_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})\s*\|\s*([^|]+?)\s*\|\s*(\S+)\s*$")
DATE_OK = re.compile(r"^\d{4}-\d{2}-\d{2}$")
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


def read_allowlist(root, live_collisions):
    """Parse the allowlist. Returns (seed_date, entries, problems)."""
    problems = []
    entries = []
    seed = None
    path = os.path.join(root, ALLOWLIST)
    if not os.path.isfile(path):
        return None, entries, problems
    seen = set()
    with open(path, encoding="utf-8") as fh:
        for ln, raw in enumerate(fh, 1):
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                m = SEED_RE.match(line.strip()) if line.lstrip().startswith("#") else None
                if m:
                    seed = m.group(1)
                continue
            m = ENTRY_RE.match(line)
            if not m:
                problems.append(f"{ALLOWLIST}:{ln}: malformed entry (want '<date> | <phrase> | <skill>,<skill>')")
                continue
            date, phrase, carriers = m.groups()
            if not DATE_OK.match(date):
                problems.append(f"{ALLOWLIST}:{ln}: bad date '{date}'")
                continue
            key = (phrase, carriers)
            if key in seen:
                problems.append(f"{ALLOWLIST}:{ln}: duplicate entry for '{phrase}'")
                continue
            seen.add(key)
            entries.append((date, phrase, carriers))
    if seed is None:
        problems.append(f"{ALLOWLIST}: no '# seeded: YYYY-MM-DD' header — the shrink-only ratchet has no anchor")
    return seed, entries, problems


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    owners, scanned = scan_skills(root)
    if scanned == 0:
        print("30-trigger-collisions NOT-CHECKED: no skills/*/SKILL.md description found — verified nothing", file=sys.stderr)
        return 2

    collisions = {p: sorted(s) for p, s in owners.items() if len(s) > 1}

    seed, entries, problems = read_allowlist(root, collisions)
    violations = []
    carried = set()
    for date, phrase, carriers in entries:
        carried.add(phrase)
        live = collisions.get(phrase)
        if live is None:
            violations.append(
                f"allowlist STALE: entry '{phrase}' ({carriers}) matches no live collision "
                f"— the descriptions no longer share the phrase; remove the line (the allowlist only shrinks)")
            continue
        if sorted(c.strip() for c in carriers.split(",")) != live:
            violations.append(
                f"allowlist MISMATCH: entry '{phrase}' claims {carriers} but the live collision is "
                f"{','.join(live)} — re-derive, then shrink or fix the descriptions")
        if seed is not None and date > seed:
            violations.append(
                f"allowlist GROWTH: entry '{phrase}' dated {date} is after the seed date {seed} "
                f"— the allowlist only shrinks; separate the phrases instead")
    for phrase in sorted(collisions):
        if phrase not in carried:
            violations.append(
                f"trigger collision: '{phrase}' is quoted by {', '.join(collisions[phrase])} "
                f"— one phrase selecting two skills is ambiguous; separate the phrases or allowlist this collision")

    for f in problems:
        print(f"FAIL 30-trigger-collisions: {f}")
    if violations:
        print("FAIL 30-trigger-collisions: quoted trigger phrase(s) selecting more than one skill ("
              + ALLOWLIST + " is SHRINK-ONLY — an entry may be removed once the collision is fixed, never added):")
        for v in violations:
            print(f"    {v}")
        return 1
    if problems:
        return 1
    print(f"  ok: 30-trigger-collisions — {scanned} description(s) tokenised, {len(collisions)} collision(s), "
          f"all carried by the seeded allowlist ({len(entries)} entries, seed {seed})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
