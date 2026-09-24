#!/usr/bin/env python3
# ---
# prevents: this deployment's own names (its apps, org, people, project ids) reaching the published
#   tree, and machine.json — this machine's absolute paths — riding a commit as tracked or staged
# fixture: lint/fixtures/27-instance-tokens
# ---
"""27-instance-tokens — the published tree names no specific deployment of it,
and this machine's machine.json never rides a commit.

Two legs, one check:

  TOKEN-HUNT LEG (needs a local token list)
    A banned-word list. Read the words, search every tracked file, fail on a hit.

    The registry is portable engineering doctrine; a clone of it must not tell the
    reader whose deployment it came from. The words that would give that away are
    this deployment's own — its app names, its org, its people, its project ids —
    so THE LIST ITSELF CANNOT LIVE HERE. Naming them in a public file is the exact
    thing this check exists to prevent.

    The list is therefore `lint/instance-tokens.local.txt`, gitignored, one word per
    line, `#` comments and blank lines ignored, matched case-insensitively as a
    substring. `lint/instance-tokens.example.txt` is the tracked template.

    No list, or an empty one, means this leg alone hunts nothing — but see Exit
    below: that no longer means the whole check verified nothing, because the
    machine-file leg still ran. The deployment that HAS a list gets the token
    protection too, at the pre-commit gate where its own words would leak.

    Population is scope.TRACKED — what a clone receives — not a filesystem walk.
    The gitignored adopter-local artifacts (friction ledgers, the bead board,
    _archive/) are full of these words by design and are never published, so seeing
    them would be pure noise.

    EXEMPT_PATHS are the files that must contain a banned word to do their job:
    a guard cannot hunt a literal it is forbidden to spell.

  MACHINE-FILE LEG (always runs, even with no token list — merged in from the
  standalone check that used to audit machine.json's tracked-ness alone)
    machine.json states THIS machine's facts in full: its org root and every
    target's absolute path. The repository is public, so the file is gitignored
    and only machine.example.json is committed. The ignore rule is the whole
    defence, and an ignore rule is defeated by exactly one thing: `git add -f`.
    This leg asks git, not the filesystem, whether the file would travel — HEAD's
    tree, the index, and one disclosed one-commit amnesty for a `git rm --cached`
    in flight (this check's own printed remediation, so it cannot deadlock the fix
    it gates). Before this merge, a clone or CI run carrying no token list got exit
    77 from this check and NO machine-file coverage at all; this leg closes that
    gap by running unconditionally, ahead of the token-hunt leg's no-list skip.

Exit (worst leg wins, 1 beats 2 beats 0):
  0   both legs verified clean (or the machine-file leg's disclosed amnesty), or
      the token-hunt leg had nothing to hunt (no list, or an empty one) while the
      machine-file leg ran clean — real verification happened either way, so this
      is never a bare "nothing checked"
  1   either leg found a real violation (a banned word, or a tracked/staged
      machine.json)
  2   either leg is NOT-GATED / NOT-CHECKED — a token list existed but no tracked
      file was read, or the machine-file leg found no git checkout to read
"""

import os
import subprocess
import sys

import _bootstrap  # noqa: F401
from lib import scope  # noqa: E402

MACHINE_FILE = "machine.json"

TOKEN_FILE = "lint/instance-tokens.local.txt"
EXAMPLE_FILE = "lint/instance-tokens.example.txt"

# A guard cannot hunt a literal it is forbidden to spell. Each entry states why.
EXEMPT_PATHS = {
    "LICENSE": "the copyright holder's name is a deliberate authorship claim",
    "lint/checks/37-engine-canon-literals.py": "its detection regex names the domain segments it forbids",
    "lint/checks/25-archived-names.py": "hunts retired names, one of which contains a banned word",
    "lint/checks/25-archived-names.test.sh": "asserts on the retired name 25-archived-names hunts",
    "lint/fixtures/25-archived-names/dead-patterns/skills/legacy-skill/SKILL.md": (
        "the RED fixture must carry the retired name"
    ),
    "memory/spawn-prompt-is-a-snapshot-spawn-after-sweep.md": (
        "its domain field names this deployment; the fact is about that domain"
    ),
}

# Files whose bytes are not text we can meaningfully search.
BINARY_EXT = (".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf", ".woff", ".woff2", ".zip", ".db")


def read_tokens(path):
    """One word per line; `#` comments and blank lines ignored."""
    tokens = []
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.split("#", 1)[0].strip()
            if line:
                tokens.append(line.lower())
    return tokens


def _git(root, *args):
    """One git call against `root`. Never raises — callers judge the exit code."""
    return subprocess.run(
        ["git", "--no-optional-locks", "-C", root, *args],
        capture_output=True, text=True, timeout=60,
    )


def check_machine_file(root):
    """machine.json is never tracked and never staged.

    Ported unchanged from the standalone check this leg replaces: three git
    reads (HEAD's tree, the index, and one disclosed one-commit
    amnesty for a `git rm --cached` in flight) rather than a filesystem read —
    tracked-ness is git state, and machine.json is gitignored so it never
    enters scope.TRACKED in the first place.

    Returns (rc, note): 0 clean (or the disclosed amnesty), 1 tracked or
    staged, 2 no git checkout to read (NOT-CHECKED — verified nothing).
    """
    try:
        probe = _git(root, "rev-parse", "--git-dir")
    except (OSError, subprocess.SubprocessError) as exc:
        return 2, f"git is unavailable ({exc}) — tracked-ness of {MACHINE_FILE} verified nothing"
    if probe.returncode != 0:
        return 2, f"{root} is not a git checkout — tracked-ness of {MACHINE_FILE} verified nothing"

    # `git ls-files` reads the index: a tracked file and a staged one both appear.
    indexed = _git(root, "ls-files", "-z", "--", MACHINE_FILE)
    if indexed.returncode != 0:
        return 2, (f"`git ls-files` failed in {root} "
                    f"({indexed.stderr.strip() or 'no detail'}) — verified nothing")
    in_index = bool(indexed.stdout.strip("\0"))

    # HEAD is absent in a fresh repo with no commit yet; that is not an error, it
    # just means nothing is committed. Only when HEAD resolves is the tree compared.
    committed = False
    if _git(root, "rev-parse", "--verify", "-q", "HEAD").returncode == 0:
        tree = _git(root, "ls-tree", "-r", "--name-only", "HEAD", "--", MACHINE_FILE)
        if tree.returncode != 0:
            return 2, (f"`git ls-tree HEAD` failed in {root} "
                        f"({tree.stderr.strip() or 'no detail'}) — verified nothing")
        committed = bool(tree.stdout.strip())

    # A tracked-in-HEAD file STAGED FOR REMOVAL is the remediation in flight, not the
    # defect. `git rm --cached` leaves the file in HEAD's tree until that commit lands,
    # and this check gates that very commit — so refusing here would deadlock the fix
    # and make `git commit --no-verify` the only way to obey the gate. The amnesty is
    # disclosed and lasts one commit: the next run reads the tree it just wrote.
    if committed and not in_index:
        return 0, (f"{MACHINE_FILE} is in HEAD's tree but staged for removal; the "
                    "untracking commit is in flight, so amnesty holds until it lands")

    if committed:
        return 1, (f"{MACHINE_FILE} is TRACKED — it holds this machine's absolute paths "
                    "and this repository is public, so it must never be committed. "
                    f"remove it from history's tip and the index: git rm --cached {MACHINE_FILE}")

    if in_index:
        return 1, (f"{MACHINE_FILE} is STAGED for commit — it holds this machine's absolute "
                    "paths and this repository is public, so it must never be committed. "
                    f"unstage it: git rm --cached {MACHINE_FILE}")

    return 0, f"{MACHINE_FILE} is neither tracked nor staged"


def combine(machine_rc, token_rc):
    """Worst leg wins: 1 beats 2 beats 0.

    A token-hunt SKIP (77 — no list, or an empty one) never downgrades a
    machine-file leg that actually ran: that is the entire point of this
    merge — a listless clone or a CI run still gets real machine.json
    verification, never a bare "nothing checked" 77.
    """
    if 1 in (machine_rc, token_rc):
        return 1
    if 2 in (machine_rc, token_rc):
        return 2
    return 0


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    # scope's sets are derived once at import, against ITS root. Auditing a different
    # tree (a fixture) means re-deriving them there, or every path resolves under the
    # wrong root and the scan silently covers nothing.
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    # The machine-file leg runs unconditionally, ahead of the token-hunt leg's
    # no-list skip: this deployment's own absolute paths must never reach the
    # published tree even in a clone or CI run that carries no token list at all.
    machine_rc, machine_note = check_machine_file(os.path.abspath(root))
    if machine_rc == 1:
        print(f"FAIL 27-instance-tokens (machine-file leg): {machine_note}")
    elif machine_rc == 2:
        print(f"27-instance-tokens NOT-CHECKED (machine-file leg): {machine_note}", file=sys.stderr)
    else:
        print(f"  ok: 27-instance-tokens (machine-file leg) — {machine_note}")

    token_path = os.path.join(root, TOKEN_FILE)

    if not os.path.isfile(token_path):
        print(f"27-instance-tokens: token-hunt leg skipped: no {TOKEN_FILE} in this checkout — "
              f"the banned-word list is deployment-local (gitignored); copy {EXAMPLE_FILE} "
              "to start one. Nothing hunted by this leg.")
        return combine(machine_rc, 77)

    tokens = read_tokens(token_path)
    if not tokens:
        print(f"27-instance-tokens: token-hunt leg skipped: {TOKEN_FILE} lists no words — "
              "nothing hunted by this leg.")
        return combine(machine_rc, 77)

    findings = []
    scanned = 0
    for rel in sorted(scope.TRACKED):
        if rel in EXEMPT_PATHS or rel.endswith(BINARY_EXT) or rel == TOKEN_FILE:
            continue
        full = os.path.join(root, rel)
        if not os.path.isfile(full):
            continue  # tracked but absent from this working tree
        try:
            with open(full, encoding="utf-8", errors="replace") as fh:
                body = fh.read().lower()
        except OSError:
            continue
        scanned += 1
        for token in tokens:
            if token in body:
                findings.append((rel, token))

    # A list exists, so words WERE to be hunted — but nothing was read. That is a
    # broken run (a wrong root, an empty tree), never a clean one. Reporting "ok"
    # here would be a pass claim over an empty set.
    if scanned == 0:
        print(f"27-instance-tokens NOT-GATED (token-hunt leg): {len(tokens)} banned word(s) to "
              "hunt but no tracked file was read — nothing was verified by this leg", file=sys.stderr)
        return combine(machine_rc, 2)

    if findings:
        print(f"FAIL 27-instance-tokens (token-hunt leg): this deployment's own names reach the "
              f"published tree ({len(findings)} hit(s) across {scanned} tracked file(s)):")
        for rel, token in findings:
            print(f"  - {rel}: '{token}'")
        print("  Replace the word with a placeholder, or — if the file must spell it to do "
              "its job — add it to EXEMPT_PATHS in this check with the reason.")
        return combine(machine_rc, 1)

    print(f"  ok: 27-instance-tokens (token-hunt leg) — {scanned} tracked file(s) scanned against "
          f"{len(tokens)} banned word(s), 0 hit(s)")
    return combine(machine_rc, 0)


if __name__ == "__main__":
    sys.exit(main())
