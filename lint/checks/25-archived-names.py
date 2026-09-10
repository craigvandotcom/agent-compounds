#!/usr/bin/env python3
# ---
# id: 25-archived-names
# prevents: a retired skill's name surviving in live doctrine — an archiving commit that leaves a
#   pointer standing (Check 2 resolves only /ac-* slash refs, so bare-text ghosts pass unseen)
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/25-archived-names
# ---
"""25-archived-names — retired skill names absent from live skill text (ac-1p7j.4).

Every directory name under _archive/skills/ that is NOT also a live skill dir
and NOT a standing exclusion must be absent from LIVE_TEXT (SKILL.md,
references/, reference/, workflows/ — lib.scope's set; the dated ledger files
FRICTIONS.md/MAINTENANCE.md are already outside it). The name set is DERIVED
FROM THE FILES, never memory: archive a dir and its name becomes illegal in
live text in the same commit.

Declared HERE, never in the allowlist (a shrink-only list could never carry
them):

  STANDING_EXCLUSIONS
      audit, planning, openrouter — two common nouns and the CLI the
      multi-model skill must keep typing. WS1 archives all three dirs; the
      words stay legal in text forever.

  ARCHIVED_V1_SURVIVORS
      ac-beadify, ac-implement, ac-publish — archived v1s of surviving skills.
      The derivation already excludes them (the live dir exists), but the
      declaration makes the reason explicit and refuses a stale declaration:
      an archived v1 whose live successor has disappeared must be renamed out
      of the constant so its name joins the governed set.

The allowlist lint/allowlists/25-archived-names.txt is DATED and SHRINK-ONLY:
  - every entry must still carry at least one archived-name hit; a file the
    sweeps cleaned must have its entry REMOVED in the same change;
  - growth is refused against the committed base (merge-base of config
    base_ref and HEAD, falling back to HEAD^): an entry not present in the
    committed allowlist fails the check. The file's first landing has no
    committed version at base — that IS the seed, and the ratchet starts the
    moment one exists. Adding an entry therefore fails the check from the
    next commit on: the allowlist only shrinks.

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

STANDING_EXCLUSIONS = ("audit", "planning", "openrouter")
ARCHIVED_V1_SURVIVORS = ("ac-beadify", "ac-implement", "ac-publish")
ALLOWLIST = "lint/allowlists/25-archived-names.txt"
DEFAULT_BASE_REF = "origin/main"

violations = []
notes = []


def git(root, *args):
    proc = subprocess.run(
        ["git", "--no-optional-locks", "-C", root, *args],
        capture_output=True, text=True, timeout=60,
    )
    return proc.stdout.strip()


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


def load_allowlist(path):
    entries = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                entries.append(line)
    return entries


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
    head = git(root, "rev-parse", "--verify", "--quiet", "HEAD")
    if head and git(root, "rev-parse", "--verify", "--quiet", "HEAD^"):
        return git(root, "rev-parse", "HEAD^")
    return ""


def committed_entries(root, base):
    """The allowlist as committed at base; None when it does not exist there."""
    proc = subprocess.run(
        ["git", "--no-optional-locks", "-C", root, "show", f"{base}:{ALLOWLIST}"],
        capture_output=True, text=True, timeout=60,
    )
    if proc.returncode != 0:
        return None
    out = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line)
    return out


def scan(root, names, allowlist_path):
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
        allowed = set(load_allowlist(allowlist_path))
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
        base = ratchet_base(root)
        if base:
            committed = committed_entries(root, base)
            if committed is None:
                notes.append(
                    f"allowlist has no committed version at base {base[:12]} "
                    "— this is the seed; the shrink-only growth ratchet starts once it lands")
            else:
                for entry in sorted(set(load_allowlist(allowlist_path)) - set(committed)):
                    violations.append(
                        f"allowlist GREW vs base {base[:12]}: '{entry}' is not in the committed list "
                        "— the allowlist only shrinks; clean the file and remove an entry instead")
        else:
            notes.append("no resolvable base ref — growth ratchet skipped this run (shallow or standalone checkout)")

    print(f"25-archived-names: {scanned} live file(s) scanned, {len(names)} archived name(s) derived, "
          f"{len(carriers)} carrier(s) on tree, {len(allowed)} allowlist entr(ies)")
    for n in notes:
        print(f"NOTE: {n}")
    if violations:
        print("FAIL 25-archived-names: retired skill name(s) in live text or a non-shrinking allowlist:")
        for v in violations:
            print(f"  - {v}")
        return 1
    print("25-archived-names: PASS")
    return 0


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
    if not names:
        print("25-archived-names NOT-CHECKED: no archived skill dir outside live/standing sets — nothing to check")
        return 2
    if not scope.LIVE_TEXT:
        print("25-archived-names NOT-CHECKED: no live text under this root — nothing scanned")
        return 2
    allowlist_path = os.path.join(root, ALLOWLIST)
    if not os.path.isfile(allowlist_path):
        allowlist_path = None
    return scan(root, names, allowlist_path)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    return run(root)


if __name__ == "__main__":
    sys.exit(main())
