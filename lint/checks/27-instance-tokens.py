#!/usr/bin/env python3
# ---
# id: 27-instance-tokens
# prevents: instance tokens (app names, the human's name, memory paths, the Supabase id) living in portable skill text
# scope: LIVE_TEXT
# severity: fail
# fixture: lint/fixtures/27-instance-tokens
# ---
"""27-instance-tokens — the instance-token gate over skills/ LIVE_TEXT.

The registry is portable engineering doctrine; nothing in skills/ may name a
specific deployment of it. This check greps a fixed token set over skills/
LIVE_TEXT and refuses every hit that the dated allowlist does not carry.

Token set — the app names (body compass, art-still, move-free, unsit), the
product family (neometa), the human (craig), the memory substrate paths
(memory/auto), the shared Supabase id, plus every pattern legacy Check 6
carried (canonical_ingredients, 127.0.0.1:54321, bd-8nse, bd-9veq). Matching
is case-insensitive.

Ledgers are exempt through the shared scope model, not a local list —
LIVE_TEXT and scope.LEDGER are disjoint by construction, so a FRICTIONS.md
carrier can never reach this scan. _archive/, _plans/ snapshots and lint
fixtures are likewise outside LIVE_TEXT or outside skills/, and so outside
this check's population.

Allowlist (lint/allowlists/27-instance-tokens.txt), SHRINK-ONLY:

    # seeded: YYYY-MM-DD
    <date> | <token> | <path>

Pipes (not spaces) separate the fields because a token itself contains a
space ("body compass"). Each line permits token in path, dated the day the
carrier was seeded. The
ratchet is mechanical:
  - an entry dated AFTER the seed date is refused (the allowlist only shrinks);
  - an entry whose carrier no longer matches is refused (fixing a carrier
    forces its line out in the same change — WS2 rebuilds and WS4 migrations
    empty the file);
  - an unknown token, a duplicate entry or a missing `seeded:` header is
    refused (a malformed allowlist fails loud, never green).
A hit not carried by the allowlist is the core violation.

Exit: 0 clean (and at least one file scanned), 1 findings, 2 scanned nothing.
"""

import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LINT = os.path.dirname(_HERE)
sys.path.insert(0, _LINT)

from lib import scope  # noqa: E402

ALLOWLIST = "lint/allowlists/27-instance-tokens.txt"
SEED_RE = re.compile(r"^#\s*seeded:\s*(\d{4}-\d{2}-\d{2})\s*$")
ENTRY_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})\s*\|\s*([^|]+?)\s*\|\s*(\S+)\s*$")
DATE_OK = re.compile(r"^\d{4}-\d{2}-\d{2}$")

TOKENS = (
    "body-compass",       # the app, hyphen form
    "body compass",       # the app, prose form (covers legacy 'For Body Compass')
    "art-still",
    "move-free",
    "unsit",
    "neometa",
    "craig",
    "memory/auto",
    "spilwpcqjncrxptqdggn",  # the shared Supabase project id
    "canonical_ingredients",
    "127.0.0.1:54321",
    "bd-8nse",
    "bd-9veq",
)


def read_allowlist(root):
    """Parse the allowlist. Returns (seed_date, entries, problems)."""
    problems = []
    entries = []
    seed = None
    path = os.path.join(root, ALLOWLIST)
    if not os.path.isfile(path):
        return None, entries, problems  # empty allowlist; hits will speak for themselves
    seen = set()
    with open(path, encoding="utf-8") as fh:
        for ln, raw in enumerate(fh, 1):
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("##"):
                continue
            m = SEED_RE.match(line.strip()) if line.lstrip().startswith("#") else None
            if m:
                seed = m.group(1)
                continue
            if line.lstrip().startswith("#"):
                continue
            m = ENTRY_RE.match(line)
            if not m:
                problems.append(f"{ALLOWLIST}:{ln}: malformed entry (want '<date> | <token> | <path>')")
                continue
            date, token, carrier = m.groups()
            if not DATE_OK.match(date):
                problems.append(f"{ALLOWLIST}:{ln}: bad date '{date}'")
                continue
            if token.lower() not in TOKENS:
                problems.append(f"{ALLOWLIST}:{ln}: token '{token}' is not in the check's token set")
                continue
            key = (token.lower(), carrier)
            if key in seen:
                problems.append(f"{ALLOWLIST}:{ln}: duplicate entry for {token} in {carrier}")
                continue
            seen.add(key)
            entries.append((date, token.lower(), carrier))
    if seed is None:
        problems.append(f"{ALLOWLIST}: no '# seeded: YYYY-MM-DD' header — the shrink-only ratchet has no anchor")
    return seed, entries, problems


def scan_hits(root):
    """Hits of the token set over skills/ LIVE_TEXT. Returns (hits, scanned)."""
    hits = []  # (path, token, lineno, line)
    scanned = 0
    for p in sorted(scope.LIVE_TEXT):
        if not p.startswith("skills/"):
            continue
        full = os.path.join(root, p)
        if not os.path.isfile(full):
            continue
        scanned += 1
        with open(full, encoding="utf-8", errors="replace") as fh:
            for ln, line in enumerate(fh, 1):
                low = line.lower()
                for tok in TOKENS:
                    if tok in low:
                        hits.append((p, tok, ln, line.strip()))
    return hits, scanned


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else scope.ROOT
    if os.path.abspath(root) != scope.ROOT:
        os.environ["LINT_ROOT"] = os.path.abspath(root)
        import importlib
        importlib.reload(scope)

    # Ledgers are exempt through the shared scope model, not a local list:
    # this guard is the proof the exemption is structural, not remembered.
    if not scope.LIVE_TEXT.isdisjoint(scope.LEDGER):
        raise SystemExit(
            "27-instance-tokens scope drift: a LEDGER file is inside LIVE_TEXT "
            "— the ledger exemption is no longer structural")

    seed, entries, problems = read_allowlist(root)
    hits, scanned = scan_hits(root)

    if scanned == 0:
        print("27-instance-tokens NOT-CHECKED: no skills/ LIVE_TEXT file found — verified nothing", file=sys.stderr)
        return 2

    violations = []
    carried = {(tok, path) for _, tok, path in entries}
    for path, tok, ln, text in hits:
        if (tok, path) not in carried:
            violations.append(f"instance token '{tok}' in {path}:{ln}: {text[:120]}")

    if seed is not None:
        for date, tok, carrier in entries:
            if date > seed:
                violations.append(
                    f"allowlist GROWTH: {ALLOWLIST} entry '{tok}' {carrier} dated {date} is after the seed date "
                    f"{seed} — the allowlist only shrinks; fix the carrier instead")
            if (tok, carrier) not in {(t, p) for p, t, _, _ in hits}:
                violations.append(
                    f"allowlist STALE: entry '{tok}' {carrier} matches no live hit — remove the line "
                    f"(the allowlist only shrinks; the carrier is already fixed)")

    for f in problems:
        print(f"FAIL 27-instance-tokens: {f}")
    if violations:
        print("FAIL 27-instance-tokens: instance tokens in portable skill text (" + ALLOWLIST
              + " is SHRINK-ONLY — an entry may be removed once its carrier is fixed, never added):")
        for v in violations:
            print(f"    {v}")
        return 1
    if problems:
        return 1
    print(f"  ok: 27-instance-tokens — {scanned} skills/ LIVE_TEXT file(s) scanned, "
          f"{len(hits)} hit(s) all carried by the seeded allowlist ({len(entries)} entries, seed {seed})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
