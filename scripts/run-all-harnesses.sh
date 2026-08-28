#!/usr/bin/env bash
#
# run-all-harnesses.sh — execute every committed proof-test harness in this registry.
#
# Born from ac-on0y.1. At its writing 14 shell harnesses and 1 python harness existed
# and NOT ONE workflow executed any of them: `grep -l 'test\.sh' .github/workflows/*.yml`
# exited 1. A proof test that never runs is documentation, not assurance — the same
# failure class lint.sh Check 18 was born from.
#
# Usage:
#   run-all-harnesses.sh          run every discovered harness; exit 1 if any fails
#   run-all-harnesses.sh --list   print the harnesses that WOULD run (repo-relative,
#                                 sorted, one per line) and exit 0 — this is the
#                                 surface scripts/harness-scheduling-check.sh audits
#
# Harness exit contract:
#   0    pass
#   77   self-skip: a precondition this runner cannot provision. Reported LOUDLY and
#        counted — never silently swallowed. A run in which EVERY harness skipped
#        fails, because it verified nothing.
#   any  fail
#
# Discovery is repo-wide on purpose. A harness that lands somewhere unexpected must be
# RUN, not missed — and harness-scheduling-check.sh independently recomputes this
# inventory so a narrowed glob here cannot quietly shrink coverage.
#
set -uo pipefail

ROOT="${AC_HARNESS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ---------------------------------------------------------------------------
# Known-red quarantine — "<repo-relative harness>|<bead id>|<why>"
# ---------------------------------------------------------------------------
# A quarantined harness STILL RUNS and its full output is printed; only its failure
# is prevented from failing the job. That is the difference between quarantine and a
# skip, and the reason a quarantine is never silent.
#
# SELF-EXPIRING: if a quarantined harness PASSES, this runner FAILS. A quarantine that
# outlives its defect is a lie about what is covered, and nobody remembers to remove it.
QUARANTINE=(
)

# ---------------------------------------------------------------------------
# Known-flaky — "<repo-relative harness>|<bead id>|<why>"
# ---------------------------------------------------------------------------
# Retried up to FLAKY_RETRIES times. If a retry was NEEDED, that fact is printed loudly
# and named in the summary: a flake that passes on retry is still evidence, not silence.
FLAKY=(
  "skills/ac-pipeline/scripts/beads-closed-gate.test.sh|ac-gate-test-flake-53px|intermittent ~1-in-6; builds a real git repo and does git ops per case"
)
FLAKY_RETRIES=2

# ---------------------------------------------------------------------------

# Print every harness this runner would execute, repo-relative and sorted.
discover() {
  find "$ROOT" \
    -type d \( -name node_modules -o -name _archive -o -name .git \) -prune -o \
    -type f \( -name '*.test.sh' -o -name '*.test.py' \) -print 2>/dev/null \
    | sed "s#^$ROOT/##" \
    | LC_ALL=C sort
}

# registry_lookup <repo-relative path> <entry...> -> echoes "<bead>|<why>", rc 0 if found
registry_lookup() {
  local want="$1" entry
  shift
  for entry in "$@"; do
    [ -n "$entry" ] || continue
    if [ "${entry%%|*}" = "$want" ]; then
      printf '%s\n' "${entry#*|}"
      return 0
    fi
  done
  return 1
}

# Every path named by a registry must exist, or the registry is stale and lying.
# verify_registry <label> <entry...>
verify_registry() {
  local label="$1" entry rc=0
  shift
  for entry in "$@"; do
    [ -n "$entry" ] || continue
    if [ ! -f "$ROOT/${entry%%|*}" ]; then
      echo "FAIL: $label names '${entry%%|*}', which does not exist — stale registry entry"
      rc=1
    fi
  done
  return $rc
}

# run_one <repo-relative path> -> exit code of the harness
run_one() {
  local rel="$1" abs="$ROOT/$1"
  case "$rel" in
    *.py) python3 "$abs" 2>&1 ;;
    *)    bash "$abs" 2>&1 ;;
  esac
}

if [ "${1:-}" = "--list" ]; then
  discover
  exit 0
fi

if [ "${1:-}" != "" ]; then
  echo "usage: $(basename "$0") [--list]" >&2
  exit 2
fi

mapfile -t HARNESSES < <(discover)

echo "=== proof-test harnesses: $ROOT ==="
echo ""

FAILED=()
PASSED=()
SKIPPED=()
QUARANTINED_RED=()
QUARANTINE_STALE=()
FLAKE_RETRIED=()

for rel in "${HARNESSES[@]}"; do
  [ -n "$rel" ] || continue

  q_meta=""; f_meta=""
  q_meta=$(registry_lookup "$rel" ${QUARANTINE[@]+"${QUARANTINE[@]}"}) || q_meta=""
  f_meta=$(registry_lookup "$rel" ${FLAKY[@]+"${FLAKY[@]}"}) || f_meta=""

  attempts=1
  [ -n "$f_meta" ] && attempts=$(( FLAKY_RETRIES + 1 ))

  n=0
  while : ; do
    n=$(( n + 1 ))
    out=$(run_one "$rel"); rc=$?
    { [ $rc -eq 0 ] || [ $n -ge $attempts ]; } && break
    echo "--- $rel: attempt $n exited $rc, retrying (known-flaky ${f_meta%%|*}) ---"
  done

  if [ $rc -eq 0 ] && [ $n -gt 1 ]; then
    FLAKE_RETRIED+=("$rel (passed on attempt $n; bead ${f_meta%%|*})")
  fi

  if [ $rc -eq 0 ]; then
    if [ -n "$q_meta" ]; then
      # The quarantine outlived the defect. Fail loudly: stale quarantine reads as coverage.
      printf 'STALE-QUARANTINE  %s  (bead %s)\n' "$rel" "${q_meta%%|*}"
      QUARANTINE_STALE+=("$rel (bead ${q_meta%%|*})")
    else
      printf 'PASS              %s\n' "$rel"
      PASSED+=("$rel")
    fi
  elif [ $rc -eq 77 ]; then
    printf 'SKIP              %s  (exit 77 — precondition unavailable)\n' "$rel"
    printf '%s\n' "$out" | sed 's/^/                  | /'
    SKIPPED+=("$rel")
  elif [ -n "$q_meta" ]; then
    printf 'QUARANTINED-RED   %s  (bead %s — %s)\n' "$rel" "${q_meta%%|*}" "${q_meta#*|}"
    printf '%s\n' "$out" | sed 's/^/                  | /'
    QUARANTINED_RED+=("$rel (bead ${q_meta%%|*})")
  else
    printf 'FAIL              %s  (exit %s)\n' "$rel" "$rc"
    printf '%s\n' "$out" | sed 's/^/                  | /'
    FAILED+=("$rel")
  fi
done

echo ""
echo "=== summary ==="
printf 'discovered %s · passed %s · failed %s · quarantined-red %s · skipped %s\n' \
  "${#HARNESSES[@]}" "${#PASSED[@]}" "${#FAILED[@]}" "${#QUARANTINED_RED[@]}" "${#SKIPPED[@]}"

RC=0

# A gate that verified nothing must fail. An empty inventory means the glob broke.
if [ "${#HARNESSES[@]}" -eq 0 ]; then
  echo "FAIL: discovered ZERO harnesses — this run verified nothing (NOT-GATED)"
  RC=1
fi

# Likewise if every harness opted out.
if [ "${#HARNESSES[@]}" -gt 0 ] && [ "${#SKIPPED[@]}" -eq "${#HARNESSES[@]}" ]; then
  echo "FAIL: EVERY harness self-skipped — this run verified nothing (NOT-GATED)"
  RC=1
fi

verify_registry QUARANTINE ${QUARANTINE[@]+"${QUARANTINE[@]}"} || RC=1
verify_registry FLAKY ${FLAKY[@]+"${FLAKY[@]}"} || RC=1

if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo "NOT-FULLY-GATED: ${#SKIPPED[@]} harness(es) self-skipped — coverage is incomplete this run:"
  printf '  - %s\n' "${SKIPPED[@]}"
fi

if [ "${#FLAKE_RETRIED[@]}" -gt 0 ]; then
  echo "FLAKE-RETRY-USED: a known-flaky harness needed a retry (evidence, not silence):"
  printf '  - %s\n' "${FLAKE_RETRIED[@]}"
fi

if [ "${#QUARANTINED_RED[@]}" -gt 0 ]; then
  echo "QUARANTINED (red, not gating — each cites an open bead):"
  printf '  - %s\n' "${QUARANTINED_RED[@]}"
fi

if [ "${#QUARANTINE_STALE[@]}" -gt 0 ]; then
  echo "FAIL: quarantined harness(es) now PASS — remove the QUARANTINE entry and close the bead:"
  printf '  - %s\n' "${QUARANTINE_STALE[@]}"
  RC=1
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "FAIL: ${#FAILED[@]} harness(es) failed:"
  printf '  - %s\n' "${FAILED[@]}"
  RC=1
fi

# Make the loud parts loud where the workflow actually shows them.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Proof-test harnesses"
    echo ""
    echo "discovered ${#HARNESSES[@]} · passed ${#PASSED[@]} · failed ${#FAILED[@]} · quarantined-red ${#QUARANTINED_RED[@]} · skipped ${#SKIPPED[@]}"
    [ "${#SKIPPED[@]}" -gt 0 ] && { echo ""; echo "**NOT-FULLY-GATED — self-skipped:**"; printf '- %s\n' "${SKIPPED[@]}"; }
    [ "${#FLAKE_RETRIED[@]}" -gt 0 ] && { echo ""; echo "**Flake retry used:**"; printf '- %s\n' "${FLAKE_RETRIED[@]}"; }
    [ "${#QUARANTINED_RED[@]}" -gt 0 ] && { echo ""; echo "**Quarantined (red, not gating):**"; printf '- %s\n' "${QUARANTINED_RED[@]}"; }
    [ "${#FAILED[@]}" -gt 0 ] && { echo ""; echo "**Failed:**"; printf '- %s\n' "${FAILED[@]}"; }
  } >> "$GITHUB_STEP_SUMMARY"
fi

[ $RC -eq 0 ] && echo "OK: every non-quarantined harness passed"
exit $RC
