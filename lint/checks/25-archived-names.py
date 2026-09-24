#!/usr/bin/env python3
# ---
# id: 25-archived-names
# prevents: a retired name surviving where it can be revived — an archived skill's name
#   left standing in live doctrine (Check 2 resolves only /ac-* slash refs, so a bare-text
#   ghost passes unseen), a dead pattern string copied back into skills/ or agents/ text, or
#   a retired alias agent file returning to agents/ and re-splitting the stance registry
# scope: LIVE_TEXT AGENT_STANCES
# severity: fail
# fixture: lint/fixtures/25-archived-names
# ---
"""25-archived-names — every retired name stays retired.

One check, three legs, one governed idea: a name that no longer exists must
not survive in live text or on disk.

  ARCHIVE-DERIVED LEG (unchanged): every directory name under _archive/skills/
  that is NOT also a live skill dir and NOT a standing exclusion must be
  absent from LIVE_TEXT (SKILL.md, references/, reference/, workflows/ —
  lib.scope's set). The name set is DERIVED FROM THE FILES, never memory:
  archive a dir and its name becomes illegal in live text in the same commit.
  _archive/ is adopter-local and gitignored (a checkout without it has
  nothing to derive) — this leg alone SKIPS when _archive/skills does not
  exist; it never blocks the other two legs and never claims a pass on their
  behalf.

  RETIRED_NAMES fixed list (one data list, one check guards every retired
  name): each entry is a name that died on disk and must never be copied
  back.

    kind "text" — a dead-pattern string, zero tolerance anywhere under
      skills/ or agents/ (every *.md file, not just LIVE_TEXT — a ledger or a
      stray note can revive a dead thing just as easily as doctrine can).
    kind "file" — a retired alias agent filename that must not exist under
      agents/ at all (the file itself, not its text).

  A pattern or alias leaves RETIRED_NAMES only by dying on disk first — see
  the entries below for each one's history.

  This fixed list is UNCONDITIONAL: unlike the archive-derived leg it never
  skips, so it runs and gates in every checkout, including CI, where
  _archive/ (gitignored) never exists.

Declared HERE, never in the allowlist (a shrink-only list could never carry
them):

  STANDING_EXCLUSIONS
      audit, planning, openrouter — two common nouns and the CLI the
      multi-model skill must keep typing; the words stay legal in text
      forever even though all three source dirs are archived.

  ARCHIVED_V1_SURVIVORS
      ac-beadify, ac-implement, ac-publish — archived v1s of surviving skills.
      The derivation already excludes them (the live dir exists), but the
      declaration makes the reason explicit and refuses a stale declaration:
      an archived v1 whose live successor has disappeared must be renamed out
      of the constant so its name joins the governed set.

The allowlist lint/allowlists/25-archived-names.txt (absent today — 0 live
carriers, nothing to admit) is, when it exists, DATED and SHRINK-ONLY per
lib.ratchet, and applies to the archive-derived leg only — the fixed list is
zero tolerance, never allowlisted:
  - every entry must still carry at least one archived-name hit; a file the
    sweeps cleaned must have its entry REMOVED in the same change;
  - growth is refused against the committed base (lib.ratchet.base_ref,
    honouring LINT_BASE_REF): an entry not present in the committed
    allowlist fails the check. The file's first landing has no committed
    version at base — that IS the seed, and the ratchet starts the moment
    one exists. Adding an entry therefore fails the check from the next
    commit on: the allowlist only shrinks. No file means no exceptions —
    every carrier is a violation.

Exit: 0 clean (at least one leg actually scanned something), 1 violations
(any leg), 2 nothing scanned anywhere by any leg (NOT-GATED, never a pass).
The archive-derived leg's own "nothing to derive" state is reported as a
NOTE, never the process exit — it cannot turn an otherwise-clean, otherwise-
gated run into a skip, because the fixed list already gated for real.
"""

import os
import re
import sys

import _bootstrap  # noqa: F401
from lib import ratchet, scope

STANDING_EXCLUSIONS = ("audit", "planning", "openrouter")
ARCHIVED_V1_SURVIVORS = ("ac-beadify", "ac-implement", "ac-publish")
ALLOWLIST = "lint/allowlists/25-archived-names.txt"

# The fixed retired-name list. Each entry is (kind, pattern, why); a pattern
# or alias leaves this list only by dying on disk first.
#
#   "text" — a dead-pattern string, zero tolerance under skills/ or agents/
#            (every *.md file there).
#   "file" — a retired alias agent filename that must not exist under
#            agents/.
#
# `run /ac-plan first` / `Run /ac-plan ` are current, valid strings — the
# planner is ac-plan; do not add them here.
RETIRED_NAMES = (
    ("text", "persona-catalog", "retired name"),
    ("text", "craigs-setup", "retired name"),
    ("text", "browser-qa-agent", "retired name"),
    ("text", "agent-compounds/commands/", "dead command-dir links (the /commands/ era)"),
    ("file", "engineer.md", "retired alias agent (renamed to implementer)"),
    ("file", "reviewer.md", "retired alias agent (renamed to validator)"),
)

violations = []
notes = []


def archived_names(root):
    """The governed population, derived from the files every run."""
    arch = os.path.join(root, "_archive", "skills")
    live = os.path.join(root, "skills")
    archived = set(os.listdir(arch)) if os.path.isdir(arch) else set()
    live_dirs = set(os.listdir(live)) if os.path.isdir(live) else set()
    for survivor in ARCHIVED_V1_SURVIVORS:
        if survivor in archived and survivor not in live_dirs:
            violations.append(
                f"stale declaration: archived v1 '{survivor}' has no live skill dir "
                f"— its name must enter the governed set; update ARCHIVED_V1_SURVIVORS in this check")
    return sorted(archived - live_dirs - set(STANDING_EXCLUSIONS))


def pattern_for(names):
    return re.compile(
        r"(?:^|[^A-Za-z0-9_-])(" + "|".join(re.escape(n) for n in names) + r")(?:[^A-Za-z0-9_-]|$)")


def scan_archived(root, names, allowlist_path):
    """The archive-derived leg. Appends to `violations`/`notes`; returns nothing."""
    pat = pattern_for(names)
    carriers = {}
    scanned = 0
    for path in scope.scan(scope.LIVE_TEXT, root):
        rel = os.path.relpath(path, root).replace(os.sep, "/")
        scanned += 1
        with open(path, encoding="utf-8", errors="replace") as fh:
            hits = set(pat.findall(fh.read()))
        if hits:
            carriers[rel] = hits

    allowed = set()
    if allowlist_path:
        entries, defects = ratchet.load_allowlist(allowlist_path)
        for d in defects:
            violations.append(d)
        allowed = {k for _, k in entries}
        for entry in sorted(allowed - set(carriers)):
            if not os.path.isfile(os.path.join(root, entry)):
                violations.append(
                    f"allowlist entry '{entry}' names a file that no longer exists "
                    "— the list only shrinks: remove the entry")
            else:
                violations.append(
                    f"allowlist entry '{entry}' no longer carries an archived name "
                    "— the list only shrinks: remove the entry")
    for rel in sorted(carriers):
        if rel not in allowed:
            violations.append(
                f"{rel} carries retired name(s) {', '.join(sorted(carriers[rel]))} and is not allowlisted "
                "— replace the name(s) in the text; the allowlist is a dated shrinking rest home, not an amnesty")

    if allowlist_path:
        base = ratchet.base_ref(root)
        if base:
            committed = ratchet.committed_keys(root, base, ALLOWLIST)
            if committed is None:
                notes.append(
                    f"allowlist has no committed version at base {base[:12]} "
                    "— this is the seed; the shrink-only growth ratchet starts once it lands")
            else:
                for entry in ratchet.shrink_only(allowed, committed):
                    violations.append(
                        f"allowlist GREW vs base {base[:12]}: '{entry}' is not in the committed list "
                        "— the allowlist only shrinks; clean the file and remove an entry instead")
        else:
            notes.append("no resolvable base ref — growth ratchet skipped this run (shallow or standalone checkout)")

    print(f"25-archived-names: {scanned} live file(s) scanned, {len(names)} archived name(s) derived, "
          f"{len(carriers)} carrier(s) on tree, {len(allowed)} allowlist entr(ies)")


def scan_dead_patterns(root):
    """The fixed-list TEXT leg. Every *.md under skills/ or agents/, zero
    tolerance, no allowlist. Returns (scanned, findings)."""
    patterns = tuple(p for kind, p, _ in RETIRED_NAMES if kind == "text")
    scanned = 0
    findings = []
    for sub in ("skills", "agents"):
        base = os.path.join(root, sub)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames
                           if d not in ("node_modules", "__pycache__", ".git")]
            for fn in filenames:
                if not fn.endswith(".md"):
                    continue
                path = os.path.join(dirpath, fn)
                scanned += 1
                try:
                    with open(path, encoding="utf-8", errors="replace") as fh:
                        text = fh.read()
                except OSError as exc:
                    findings.append(f"unreadable file {os.path.relpath(path, root)}: {exc}")
                    continue
                for pattern in patterns:
                    if pattern in text:
                        findings.append(
                            f"dead pattern '{pattern}' found in {os.path.relpath(path, root)}")
    return scanned, findings


def scan_retired_aliases(root):
    """The fixed-list FILE leg. agents/ existence only, not text. Returns
    (checked, findings) — checked is False when agents/ itself does not
    exist (nothing to verify, not a violation)."""
    aliases = tuple((p, why) for kind, p, why in RETIRED_NAMES if kind == "file")
    agents_dir = os.path.join(root, "agents")
    if not os.path.isdir(agents_dir):
        return False, []
    findings = []
    for fn, why in aliases:
        if os.path.exists(os.path.join(agents_dir, fn)):
            findings.append(f"agents/{fn} exists — {why}")
    return True, findings


def run(root):
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    names = archived_names(root)
    if violations:
        print("FAIL 25-archived-names: stale declaration(s):")
        for v in violations:
            print(f"  - {v}")
        return 1

    scanned_any = False

    # Leg 1: archive-derived. _archive/ is adopter-local and gitignored — this leg
    # alone may have nothing to derive or nothing to scan against; it notes that
    # and steps aside, it never speaks for the other two legs.
    if names:
        if scope.LIVE_TEXT:
            scanned_any = True
            allowlist_path = os.path.join(root, ALLOWLIST)
            if not os.path.isfile(allowlist_path):
                allowlist_path = None
            scan_archived(root, names, allowlist_path)
        else:
            notes.append(
                "archive-derived leg NOT-CHECKED: archived name(s) derived but no live text "
                "under this root to scan them against")
    else:
        notes.append(
            "archive-derived leg skipped: no archived skill dir in this checkout — "
            "_archive/ is adopter-local (gitignored), nothing to derive")

    # Leg 2: fixed-list dead patterns (text). Unconditional — runs everywhere, CI included.
    dp_scanned, dp_findings = scan_dead_patterns(root)
    if dp_scanned:
        scanned_any = True
    violations.extend(dp_findings)

    # Leg 3: fixed-list retired alias agents (file existence). Unconditional.
    alias_checked, alias_findings = scan_retired_aliases(root)
    if alias_checked:
        scanned_any = True
    violations.extend(alias_findings)

    if not scanned_any:
        print("25-archived-names NOT-CHECKED: no live text, no *.md under skills/ or agents/, "
              "and no agents/ directory under this root — verified nothing", file=sys.stderr)
        return 2

    for n in notes:
        print(f"NOTE: {n}")

    if violations:
        print("FAIL 25-archived-names: retired name(s) in live text, a non-shrinking allowlist, "
              "a dead pattern, or a retired alias agent file:")
        for v in violations:
            print(f"  - {v}")
        return 1
    print("25-archived-names: PASS")
    return 0


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    return run(root)


if __name__ == "__main__":
    sys.exit(main())
