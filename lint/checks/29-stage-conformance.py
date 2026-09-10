#!/usr/bin/env python3
# ---
# id: 29-stage-conformance
# prevents: a skill declaring a hand-off the stage table does not carry — the canon table
#   (skills/ac-pipeline/references/stage-table.md) rots silently while SKILL.md prose routes work
#   elsewhere
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/29-stage-conformance
# ---
"""29-stage-conformance — declared hand-offs must be carried by the stage table (ac-1p7j.8).

For every live `skills/ac-*/SKILL.md`, every declared hand-off sentence is
compared against the canonical stage table (read from the table file itself,
never a copy). A hand-off the table does not carry is RED.

THE HAND-OFF GRAMMAR the sensor reads (declare edits here, in this header,
so authors know the exact phrase the check sees):

  "hands off to <target>"     — forward edge; <target> must be a table stage
                                strictly DOWNSTREAM of the declaring skill
  "ENDS by invoking <target>" — forward edge, same rule
  "invoked BY <target>"       — backward edge; <target> must be a table stage
                                strictly UPSTREAM of the declaring skill

Target resolution (declared here, never guessed):
  - a table stage's owner skill name (`ac-polish`, …) — taken from the table
  - ALIASES, the free phrases live prose uses today:
      "the loop"            -> the run chain (implement..land)
      "the batch boundary"  -> ac-implement (the post-batch invoker)
    a leading "the " / "ac2 " is stripped before matching.

A skill with no hand-off sentence is scanned and passes (nothing declared).
A target that resolves to nothing — not a table owner, not an alias — is RED
("names a hand-off the table does not carry").

The dated allowlist lint/allowlists/29-stage-conformance.txt is SHRINK-ONLY:
entry = a skill dir name whose today's mismatches WS2 will reword; a clean
allowlisted skill must have its entry REMOVED, and an entry not in the
committed version at the base ref fails the check (growth). The file's first
landing has no committed version at base — that IS the seed.

Exit: 0 clean, 1 violations, 2 scanned nothing (NOT-GATED, never a pass).
"""

import json
import os
import re
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

TABLE = "skills/ac-pipeline/references/stage-table.md"
ALLOWLIST = "lint/allowlists/29-stage-conformance.txt"
DEFAULT_BASE_REF = "origin/main"

HANDOFF_PATTERNS = [
    ("hands off to", re.compile(r"hands off to\s+`?([^.,;()`\u2014\u2013\n]+)", re.I), "forward"),
    ("ENDS by invoking", re.compile(r"ends by invoking\s+`?([^.,;()`\u2014\u2013\n]+)", re.I), "forward"),
    ("invoked BY", re.compile(r"invoked by\s+(?:the\s+|an?\s+)?`?([^.,;()`\u2014\u2013\n]+)", re.I), "backward"),
]

# Free phrases live prose uses; declared here so a table edit cannot strand them silently.
# Keys are the phrase AFTER stripping a leading "the " / "ac2 ".
ALIASES = {
    "loop": ("loop", "the run chain: implement..land"),
    "batch boundary": ("batch boundary", "ac-implement, the post-batch invoker"),
}

violations = []
notes = []


def git(root, *args):
    proc = subprocess.run(
        ["git", "--no-optional-locks", "-C", root, *args],
        capture_output=True, text=True, timeout=60,
    )
    return proc.stdout.strip()


def parse_table(root):
    """Row-ordered chain: [(stage, {owner skills}), ...] from the table file.

    Owner tokens come from the row's backticked spans (prose like
    `references/worker.md` is dropped — tokens are bare identifiers). A row's
    stage exists whether or not its owner skill has a live dir here.
    """
    path = os.path.join(root, TABLE)
    if not os.path.isfile(path):
        return None
    chain = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if not line.startswith("|"):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 2 or cells[0] in ("Stage", "") or set(cells[0]) <= {"-", " "}:
                continue
            owners = set()
            for span in re.findall(r"`([^`]*)`", cells[1]):
                owners.update(t for t in span.split() if re.fullmatch(r"[a-z][a-z0-9-]*", t))
            if owners:
                chain.append((cells[0], owners))
    return chain or None


def position_of(chain, skill):
    for i, (_, owners) in enumerate(chain):
        if skill in owners:
            return i
    return None


def resolve_target(text, owner_set):
    """A target token is (kind, name): owner | alias | unknown."""
    t = text.strip().strip("`").strip()
    low = re.sub(r"^(the|ac2)\s+", "", t.lower()).strip()
    if low in ALIASES:
        return "alias", low
    m = re.match(r"^(ac-[a-z0-9-]+)$", t)
    if m:
        return ("owner", m.group(1)) if m.group(1) in owner_set else ("unknown", t)
    return "unknown", t


def scan(root, chain, allowlist_path):
    owner_set = set().union(*(o for _, o in chain))
    table_pos = {s: position_of(chain, s) for s in owner_set}
    allowed = set()
    if allowlist_path:
        with open(allowlist_path, encoding="utf-8") as fh:
            allowed = {line.strip() for line in fh if line.strip() and not line.startswith("#")}

    scanned = 0
    hits_by_skill = {}
    for path in scope.scan(scope.LIVE_TEXT, root):
        rel = os.path.relpath(path, root).replace(os.sep, "/")
        m = re.match(r"^skills/(ac-[a-z0-9-]+)/SKILL\.md$", rel)
        if not m:
            continue
        scanned += 1
        skill = m.group(1)
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        for phrase, pat, direction in HANDOFF_PATTERNS:
            for tm in pat.finditer(text):
                kind, name = resolve_target(tm.group(1), owner_set)
                if kind == "unknown":
                    hits_by_skill.setdefault(skill, []).append(
                        f"{phrase} -> '{tm.group(1).strip()}' names no table stage or declared alias")
                    continue
                if kind == "alias":
                    continue  # alias targets are valid routes by declaration
                tpos = table_pos.get(name)
                spos = table_pos.get(skill)
                if tpos is None:
                    hits_by_skill.setdefault(skill, []).append(
                        f"{phrase} -> '{name}' is not a table stage")
                    continue
                if spos is None:
                    continue  # entry point off the chain: any route is legal
                if direction == "forward" and not tpos > spos:
                    hits_by_skill.setdefault(skill, []).append(
                        f"{phrase} -> '{name}' is not downstream of '{skill}' in the table")
                if direction == "backward" and not tpos < spos:
                    hits_by_skill.setdefault(skill, []).append(
                        f"invoked BY -> '{name}' is not upstream of '{skill}' in the table")

    for skill in sorted(allowed - set(hits_by_skill)):
        violations.append(
            f"allowlist entry '{skill}' declares no non-conforming hand-off "
            "— the list only shrinks: remove the entry")
    for skill, msgs in sorted(hits_by_skill.items()):
        if skill in allowed:
            notes.append(f"'{skill}' is allowlisted (WS2 will reword); {len(msgs)} mismatch(es) excused today")
            continue
        for msg in msgs:
            violations.append(f"{skill}/SKILL.md: {msg}")

    if allowlist_path:
        base = ratchet_base(root)
        if base:
            proc = subprocess.run(
                ["git", "--no-optional-locks", "-C", root, "show", f"{base}:{ALLOWLIST}"],
                capture_output=True, text=True, timeout=60)
            if proc.returncode != 0:
                notes.append(
                    f"allowlist has no committed version at base {base[:12]} "
                    "— this is the seed; the shrink-only growth ratchet starts once it lands")
            else:
                committed = {line.strip() for line in proc.stdout.splitlines()
                             if line.strip() and not line.startswith("#")}
                for entry in sorted(allowed - committed):
                    violations.append(
                        f"allowlist GREW vs base {base[:12]}: '{entry}' is not in the committed list "
                        "— the allowlist only shrinks; fix the prose instead")

    print(f"29-stage-conformance: {scanned} ac-* skill(s) scanned, {len(chain)} table stage(s) read from {TABLE}, "
          f"{len(hits_by_skill)} non-conforming skill(s)")
    for n in notes:
        print(f"NOTE: {n}")
    if violations:
        print("FAIL 29-stage-conformance: declared hand-off(s) the stage table does not carry:")
        for v in violations:
            print(f"  - {v}")
        return 1
    print("29-stage-conformance: PASS")
    return 0


def ratchet_base(root):
    ref = DEFAULT_BASE_REF
    cfg = os.path.join(root, "lint", "config.json")
    if os.path.isfile(cfg):
        try:
            with open(cfg, encoding="utf-8") as fh:
                ref = json.load(fh).get("base_ref", DEFAULT_BASE_REF)
        except (OSError, ValueError):
            ref = DEFAULT_BASE_REF
    if git(root, "rev-parse", "--verify", "--quiet", ref):
        b = git(root, "merge-base", ref, "HEAD")
        if b:
            return b
    if git(root, "rev-parse", "--verify", "--quiet", "HEAD^"):
        return git(root, "rev-parse", "HEAD^")
    return ""


def run(root):
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)
    live_skills = {p.split("/")[1] for p in scope.LIVE_TEXT
                   if re.match(r"^skills/([^/]+)/SKILL\.md$", p)}
    chain = parse_table(root)
    if chain is None:
        print(f"29-stage-conformance NOT-CHECKED: {TABLE} missing or carries no stage rows — nothing to conform to")
        return 2
    if not live_skills:
        print("29-stage-conformance NOT-CHECKED: no ac-* skills under this root — nothing scanned")
        return 2
    allowlist_path = os.path.join(root, ALLOWLIST)
    if not os.path.isfile(allowlist_path):
        allowlist_path = None
    return scan(root, chain, allowlist_path)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    return run(root)


if __name__ == "__main__":
    sys.exit(main())
