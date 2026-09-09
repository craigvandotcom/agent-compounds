#!/usr/bin/env python3
# ---
# id: 34-no-bead-subject-agreement
# prevents: a real behavioral change shipping under [no-bead] — board-truth.sh drops [no-bead] commits wholesale from the review range, so the change is invisible to range-derived review forever (measured: 9b1d745, a stamp-refined-fixpoint.test.sh behavior change under a "Sensor-log append only" subject)
# scope: LEDGER
# severity: fail
# fixture: lint/fixtures/34-no-bead-subject-agreement
# ---
"""34-no-bead-subject-agreement — a [no-bead] commit touches only what it claims.

`[no-bead]` exists for ONE thing: bookkeeping that names beads without
implementing them — ledger appends (FRICTIONS.md / MAINTENANCE.md), board
bookkeeping (`.beads/`), and report commits. It is NOT an escape hatch: a real
change under `[no-bead]` is dropped wholesale from board-truth.sh's review
range, so it never gets reviewed and never re-enters the corpus.

The marker is matched as a TRAILING token: the convention across the window is
`<subject> [no-bead]` (190 of 190 historical marker uses end the subject). A
subject that merely QUOTES the marker mid-text — e.g. a feature commit
describing the marker or the check itself — is not a marker use, and is not a
[no-bead] commit to police (measured at landing: a005143, the check's own
landing commit, quoted "[no-bead] commits assert subject-body agreement" in
its subject).

This check reads the git log, finds `[no-bead]`-marked commits, and flags any
whose diff touches a file outside the ledger/board surfaces the marker is FOR.
The window is the same range board-truth.sh derives (last release tag..HEAD,
falling back to the root commit) so the two agree about what a review would
have covered.

Historical offenders are parked, not relitigated: the commits that predate
this check and already misused the marker are grandfathered by the dated
shrink-only allowlist lint/allowlists/34-no-bead-subject-agreement.txt (seeded
2026-09-09 with the 76 offenders the check's first run named — they are in git
history and cannot be rewritten). A [no-bead] commit NOT on that list fails.
The ratchet is mechanical, mirroring 25-archived-names / 27-instance-tokens:
  - an entry dated AFTER the seed date is refused (the allowlist only shrinks);
  - an entry whose sha is no longer in the review window is refused (a release
    tag rolled past it — remove the line);
  - an entry absent from the committed allowlist at the config base_ref is
    refused once a committed version exists (the file's first landing IS the
    seed; growth is impossible from the next commit on);
  - a malformed entry, a duplicate sha or a missing `seeded:` header is refused
    (a malformed allowlist fails loud, never green).

Exit: 0 clean (at least one commit scanned), 1 findings, 2 nothing scanned.
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

# The marker is a TRAILING token (`<subject> [no-bead]` — the convention across
# the window; 190/190 historical marker uses end the subject). A subject that
# QUOTES the marker mid-text is describing it, not using it — the check's own
# landing commit (a005143) quoted "[no-bead] commits assert subject-body
# agreement" and is not a bookkeeping commit to police.
NO_BEAD = re.compile(r"\[no-bead\]\s*$", re.IGNORECASE)
ALLOWLIST = "lint/allowlists/34-no-bead-subject-agreement.txt"
DEFAULT_BASE_REF = "origin/main"
SEED_RE = re.compile(r"^#\s*seeded:\s*(\d{4}-\d{2}-\d{2})\s*$")
ENTRY_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})\s*\|\s*([0-9a-f]{40})\s*\|\s*(.*)$")

# The surfaces [no-bead] is FOR — repo-root-relative prefixes and exact names.
# Everything else in a [no-bead] commit's diff is a real change hiding.
ALLOWED_PREFIXES = (".beads/", "_archive/")
ALLOWED_EXACT = {"FRICTIONS.md", "MAINTENANCE.md"}


def is_allowed(path):
    """True when a diff path is ledger/board bookkeeping — what [no-bead] claims."""
    base = os.path.basename(path)
    if base in ALLOWED_EXACT:
        return True
    return any(path.startswith(p) for p in ALLOWED_PREFIXES)


def read_allowlist(root):
    """Parse the allowlist. Returns (seed, {sha: date}, problems)."""
    problems = []
    seed = None
    by_sha = {}
    path = os.path.join(root, ALLOWLIST)
    if not os.path.isfile(path):
        return None, by_sha, problems  # no allowlist (e.g. throwaway test repos)
    with open(path, encoding="utf-8") as fh:
        for ln, raw in enumerate(fh, 1):
            line = raw.rstrip("\n")
            if not line.strip():
                continue
            if line.lstrip().startswith("#"):
                m = SEED_RE.match(line.strip())
                if m:
                    seed = m.group(1)
                continue
            m = ENTRY_RE.match(line)
            if not m:
                problems.append(f"{ALLOWLIST}:{ln}: malformed entry (want '<date> | <sha> | <subject>')")
                continue
            date, sha, _subject = m.groups()
            if sha in by_sha:
                problems.append(f"{ALLOWLIST}:{ln}: duplicate sha {sha}")
                continue
            by_sha[sha] = date
    if seed is None:
        problems.append(f"{ALLOWLIST}: no '# seeded: YYYY-MM-DD' header — the shrink-only ratchet has no anchor")
    return seed, by_sha, problems


def ratchet_base(root):
    """The committed-version base: config base_ref's merge-base, else HEAD^."""
    ref = DEFAULT_BASE_REF
    cfg = os.path.join(root, "lint", "config.json")
    if os.path.isfile(cfg):
        try:
            with open(cfg, encoding="utf-8") as fh:
                ref = json.load(fh).get("base_ref", DEFAULT_BASE_REF)
        except (OSError, ValueError):
            ref = DEFAULT_BASE_REF
    rc, out = git(root, "rev-parse", "--verify", "--quiet", ref)
    if rc == 0 and out.strip():
        rc, out = git(root, "merge-base", ref, "HEAD")
        if rc == 0 and out.strip():
            return out.strip().splitlines()[0]
    rc, out = git(root, "rev-parse", "--verify", "--quiet", "HEAD^")
    if rc == 0 and out.strip():
        return out.strip().splitlines()[0]
    return None


def committed_keys(root, base):
    """The allowlist keys (<date> | <sha>) committed at base; None when absent."""
    proc = subprocess.run(
        ["git", "--no-optional-locks", "-C", root, "show", f"{base}:{ALLOWLIST}"],
        capture_output=True, text=True, timeout=60,
    )
    if proc.returncode != 0:
        return None
    keys = set()
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = ENTRY_RE.match(line)
        if m:
            keys.add(f"{m.group(1)} | {m.group(2)}")
    return keys


def git(root, *args):
    """Run git in root; return (rc, stdout)."""
    proc = subprocess.run(
        ["git", "-C", root] + list(args),
        capture_output=True, text=True, timeout=60,
    )
    return proc.returncode, proc.stdout


def review_base(root):
    """The window board-truth.sh derives: last release tag, else root commit."""
    rc, out = git(root, "describe", "--tags", "--match", "v*", "--abbrev=0")
    if rc == 0 and out.strip():
        return out.strip()
    rc, out = git(root, "rev-list", "--max-parents=0", "HEAD")
    if rc == 0 and out.strip():
        return out.strip().splitlines()[-1]
    return None


def no_bead_commits(root, base):
    """(sha, subject) for every [no-bead] commit in base..HEAD."""
    rc, out = git(root, "log", f"{base}..HEAD", "--format=%H%x00%s")
    if rc != 0 or not out.strip():
        return []
    commits = []
    for line in out.splitlines():
        sha, _, subject = line.partition("\0")
        if NO_BEAD.search(subject):
            commits.append((sha, subject))
    return commits


def commit_files(root, sha):
    """Files touched by a commit (name-only, no renames collapsed)."""
    rc, out = git(root, "show", sha, "--name-only", "--format=")
    if rc != 0:
        return []
    return [l for l in out.splitlines() if l.strip()]


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    base = review_base(root)
    if base is None:
        print("34-no-bead-subject-agreement NOT-CHECKED: no review base derivable — verified nothing", file=sys.stderr)
        return 2

    commits = no_bead_commits(root, base)
    if not commits:
        # A window with no [no-bead] commits is a PASS — nothing to police.
        # A window with no commits at all is NOT-GATED (scanned nothing).
        rc, _ = git(root, "rev-list", "--count", f"{base}..HEAD")
        if rc == 0 and out_count(root, base) == 0:
            print("34-no-bead-subject-agreement NOT-CHECKED: empty window — verified nothing", file=sys.stderr)
            return 2
        print("34-no-bead-subject-agreement: no [no-bead] commits in the review window — clean")
        return 0

    seed, by_sha, problems = read_allowlist(root)
    live_shas = {sha for sha, _ in commits}
    violations = []
    notes = []
    grandfathered = 0
    for sha, subject in commits:
        bad = [f for f in commit_files(root, sha) if not is_allowed(f)]
        if bad:
            if sha in by_sha:
                grandfathered += 1
                continue
            violations.append(
                f"{sha} '{subject[:70]}' touches non-bookkeeping file(s): {', '.join(sorted(bad))}")

    if seed is not None:
        for sha, date in by_sha.items():
            if date > seed:
                violations.append(
                    f"allowlist GROWTH: entry for {sha} dated {date} is after the seed date "
                    f"{seed} — the allowlist only shrinks; the commit must comply instead")
            if sha not in live_shas:
                violations.append(
                    f"allowlist STALE: entry for {sha} matches no [no-bead] commit in the window "
                    "— remove the line (the allowlist only shrinks; the commit rolled out of review)")
        base_ratchet = ratchet_base(root)
        if base_ratchet:
            committed = committed_keys(root, base_ratchet)
            if committed is None:
                notes.append(
                    f"allowlist has no committed version at base {base_ratchet[:12]} "
                    "— this is the seed; the shrink-only growth ratchet starts once it lands")
            else:
                for key in sorted(f"{d} | {s}" for s, d in by_sha.items()):
                    if key not in committed:
                        violations.append(
                            f"allowlist GREW vs base {base_ratchet[:12]}: '{key}' is not in the committed "
                            "list — the allowlist only shrinks; the commit must comply instead")
        else:
            notes.append("no resolvable base ref — growth ratchet skipped this run (shallow or standalone checkout)")

    if violations or problems:
        print("FAIL 34-no-bead-subject-agreement: [no-bead] commits whose diff reaches beyond the "
              "ledger/board surfaces (.beads/, FRICTIONS.md, MAINTENANCE.md, _archive/), or a "
              "non-shrinking allowlist — a real change under [no-bead] is dropped from the review range "
              "forever:")
        for p in problems:
            print(f"    {p}")
        for v in violations:
            print(f"    {v}")
        return 1
    for n in notes:
        print(f"NOTE: {n}")
    print(f"34-no-bead-subject-agreement: {len(commits)} [no-bead] commit(s) in the review window "
          f"({grandfathered} historical offender(s) parked in the dated allowlist), "
          f"the rest confined to bookkeeping surfaces — clean")
    return 0


def out_count(root, base):
    rc, out = git(root, "rev-list", "--count", f"{base}..HEAD")
    return int(out.strip() or 0) if rc == 0 else -1


if __name__ == "__main__":
    sys.exit(main())