#!/usr/bin/env bash
# 34-no-bead-subject-agreement.test.sh — the fixture proving Check 34's contract.
#
#   PROBE: a [no-bead] commit touching a code file is RED naming the file; a
#           [no-bead] commit confined to the ledger/board surfaces (.beads/,
#           FRICTIONS.md) is GREEN; a window with no [no-bead] commits is
#           GREEN; the check is discovered by the runner.
#
# ASSURANCE
#   PROBE:    bash lint/checks/34-no-bead-subject-agreement.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/34-no-bead-subject-agreement.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

run_check() { # <tmp-repo> -> exit code
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}
OUT="$(mktemp)"; trap 'rm -rf "$OUT"' EXIT

new_repo() { # <dir> -> init a repo with a base commit
  git init -q "$1" -b main 2>/dev/null
  ( cd "$1" || exit 2
    git config user.email t@t.t; git config user.name t
    printf 'base\n' > README.md
    git add -A; git commit -qm base )
}

# --- RED: a [no-bead] commit touching a code file -----------------------------
w="$(mktemp -d)"; trap 'rm -rf "$w" "$OUT"' EXIT
new_repo "$w"
( cd "$w" || exit 2
  mkdir -p src
  printf 'real change\n' >> src/app.py
  git add -A; git commit -qm "chore(ac-pipeline): friction — sensor-log append only [no-bead]" )
rc=$(run_check "$w")
if [ "$rc" = 1 ] && grep -q "src/app.py" "$OUT"; then
  ok "RED: [no-bead] commit touching a code file -> exit 1 naming the file"
else
  bad "RED case: expected 1 naming src/app.py, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- GREEN: a [no-bead] commit confined to the board surface ------------------
w="$(mktemp -d)"; trap 'rm -rf "$w" "$OUT"' EXIT
new_repo "$w"
( cd "$w" || exit 2
  mkdir -p .beads
  printf '{"x":1}\n' >> .beads/issues.jsonl
  git add -A; git commit -qm "chore(beads): run ledger append [no-bead]" )
rc=$(run_check "$w")
if [ "$rc" = 0 ]; then
  ok "GREEN: [no-bead] board append -> exit 0"
else
  bad "GREEN board case: expected 0, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- GREEN: a [no-bead] commit confined to the friction ledger ----------------
w="$(mktemp -d)"; trap 'rm -rf "$w" "$OUT"' EXIT
new_repo "$w"
( cd "$w" || exit 2
  mkdir -p skills/ac-pipeline
  printf -- '- observation\n' >> skills/ac-pipeline/FRICTIONS.md
  git add -A; git commit -qm "chore(ac-pipeline): friction — ledger append [no-bead]" )
rc=$(run_check "$w")
if [ "$rc" = 0 ]; then
  ok "GREEN: [no-bead] friction-ledger append -> exit 0"
else
  bad "GREEN ledger case: expected 0, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- GREEN: a window with no [no-bead] commits ---------------------------------
w="$(mktemp -d)"; trap 'rm -rf "$w" "$OUT"' EXIT
new_repo "$w"
( cd "$w" || exit 2
  printf 'more\n' >> README.md
  git add -A; git commit -qm "docs: a normal commit" )
rc=$(run_check "$w")
if [ "$rc" = 0 ]; then
  ok "GREEN: window with no [no-bead] commits -> exit 0"
else
  bad "GREEN no-bead case: expected 0, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- GREEN: a [no-bead] commit touching a code file, sha on the allowlist -----
# The dated shrink-only allowlist parks historical offenders (commits that
# predate the check and cannot be rewritten); a parked sha passes while the
# ratchet still fails anything new.
w="$(mktemp -d)"; trap 'rm -rf "$w" "$OUT"' EXIT
new_repo "$w"
( cd "$w" || exit 2
  mkdir -p src lint/allowlists
  printf 'real change\n' >> src/app.py
  git add -A; git commit -qm "chore(ac-pipeline): friction — sensor-log append only [no-bead]"
  sha="$(git rev-parse HEAD)"
  printf '# seeded: 2026-09-09\n2026-09-09 | %s | the parked offender\n' "$sha" \
    > lint/allowlists/34-no-bead-subject-agreement.txt
  git add -A; git commit -qm "chore: seed the 34 allowlist" )
rc=$(run_check "$w")
if [ "$rc" = 0 ]; then
  ok "GREEN: [no-bead] code-touching commit parked on the allowlist -> exit 0"
else
  bad "GREEN parked case: expected 0, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- RED: the allowlist GREW (an entry dated after the seed date) ---------------
# The ratchet: the allowlist only shrinks. A growth dated after the seed is
# refused even though the commit itself would be parkable.
w="$(mktemp -d)"; trap 'rm -rf "$w" "$OUT"' EXIT
new_repo "$w"
( cd "$w" || exit 2
  mkdir -p src lint/allowlists
  printf 'real change\n' >> src/app.py
  git add -A; git commit -qm "chore(ac-pipeline): friction — sensor-log append only [no-bead]"
  sha="$(git rev-parse HEAD)"
  printf '# seeded: 2026-09-09\n2026-09-10 | %s | growth attempt\n' "$sha" \
    > lint/allowlists/34-no-bead-subject-agreement.txt
  git add -A; git commit -qm "chore: seed the 34 allowlist" )
rc=$(run_check "$w")
if [ "$rc" = 1 ] && grep -q "GROWTH" "$OUT"; then
  ok "RED: allowlist entry dated after the seed -> exit 1 naming GROWTH"
else
  bad "RED growth case: expected 1 naming GROWTH, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- GREEN: a feature commit QUOTING the marker mid-subject (not a marker use) ------
# The marker is a trailing token; a subject that describes the marker itself —
# e.g. a feat commit about the check — must not be read as a [no-bead] commit
# (measured false-positive class at landing: a005143).
w="$(mktemp -d)"; trap 'rm -rf "$w" "$OUT"' EXIT
new_repo "$w"
( cd "$w" || exit 2
  mkdir -p src
  printf 'real change\n' >> src/app.py
  git add -A; git commit -qm "feat(lint): the [no-bead] marker must not carry real changes" )
rc=$(run_check "$w")
if [ "$rc" = 0 ]; then
  ok "GREEN: feat commit quoting the marker mid-subject -> exit 0"
else
  bad "GREEN quote case: expected 0, got $rc"; cat "$OUT"
fi
rm -rf "$w"

# --- DISCOVERED: the runner lists the check ------------------------------------
# The check exits 1 against the LIVE tree (the historical [no-bead] misuses it
# exists to report — TRUE alarms a human dispositions), so this leg greps the
# runner's output directly, never its exit code.
out="$(python3 "$ROOT/lint/run.py" --json --check 34-no-bead-subject-agreement 2>&1 || true)"
if printf '%s' "$out" | grep -q '"id": "34-no-bead-subject-agreement"'; then
  ok "DISCOVERED: lint/run.py resolves the check"
else
  bad "DISCOVERED: the check was not found by the runner"; printf '%s\n' "$out" | head -5
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 34-no-bead-subject-agreement contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1