#!/usr/bin/env python3
# ---
# id: 27-instance-tokens
# prevents: this deployment's own names (its apps, org, people, project ids) reaching the published tree
# scope: TRACKED
# severity: fail
# fixture: lint/fixtures/27-instance-tokens
# ---
"""27-instance-tokens — the published tree names no specific deployment of it.

A banned-word list. Read the words, search every tracked file, fail on a hit.

The registry is portable engineering doctrine; a clone of it must not tell the
reader whose deployment it came from. The words that would give that away are
this deployment's own — its app names, its org, its people, its project ids —
so THE LIST ITSELF CANNOT LIVE HERE. Naming them in a public file is the exact
thing this check exists to prevent.

The list is therefore `lint/instance-tokens.local.txt`, gitignored, one word per
line, `#` comments and blank lines ignored, matched case-insensitively as a
substring. `lint/instance-tokens.example.txt` is the tracked template.

No list -> SKIP, reported as a skip. A clone has no list and nothing to hunt;
that is honest, not a pass. The deployment that HAS a list gets the protection,
at the pre-commit gate where its own words would leak.

Population is scope.TRACKED — what a clone receives — not a filesystem walk.
The gitignored adopter-local artifacts (friction ledgers, the bead board,
_archive/) are full of these words by design and are never published, so seeing
them would be pure noise.

EXEMPT_PATHS are the files that must contain a banned word to do their job:
a guard cannot hunt a literal it is forbidden to spell.

Exit: 0 clean or skipped, 1 hits, 2 a list to hunt but nothing read.
"""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

TOKEN_FILE = "lint/instance-tokens.local.txt"
EXAMPLE_FILE = "lint/instance-tokens.example.txt"

# A guard cannot hunt a literal it is forbidden to spell. Each entry states why.
EXEMPT_PATHS = {
    "LICENSE": "the copyright holder's name is a deliberate authorship claim",
    "lint/checks/37-engine-canon-literals.py": "its detection regex names the domain segments it forbids",
    "lint/checks/1-dead-patterns.py": "hunts retired names, one of which contains a banned word",
    "lint/checks/1-dead-patterns.test.sh": "asserts on the retired name 1-dead-patterns hunts",
    "lint/fixtures/1-dead-patterns/skills/legacy-skill/SKILL.md": "the RED fixture must carry the retired name",
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


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    # scope's sets are derived once at import, against ITS root. Auditing a different
    # tree (a fixture) means re-deriving them there, or every path resolves under the
    # wrong root and the scan silently covers nothing.
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)
    token_path = os.path.join(root, TOKEN_FILE)

    if not os.path.isfile(token_path):
        print(f"27-instance-tokens skipped: no {TOKEN_FILE} in this checkout — the "
              f"banned-word list is deployment-local (gitignored); copy {EXAMPLE_FILE} "
              "to start one. Nothing hunted, nothing verified.")
        return 0

    tokens = read_tokens(token_path)
    if not tokens:
        print(f"27-instance-tokens skipped: {TOKEN_FILE} lists no words — "
              "nothing hunted, nothing verified.")
        return 0

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
        print(f"27-instance-tokens NOT-GATED: {len(tokens)} banned word(s) to hunt but no "
              "tracked file was read — nothing was verified", file=sys.stderr)
        return 2

    if findings:
        print(f"FAIL 27-instance-tokens: this deployment's own names reach the published tree "
              f"({len(findings)} hit(s) across {scanned} tracked file(s)):")
        for rel, token in findings:
            print(f"  - {rel}: '{token}'")
        print("  Replace the word with a placeholder, or — if the file must spell it to do "
              "its job — add it to EXEMPT_PATHS in this check with the reason.")
        return 1

    print(f"  ok: 27-instance-tokens — {scanned} tracked file(s) scanned against "
          f"{len(tokens)} banned word(s), 0 hit(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
