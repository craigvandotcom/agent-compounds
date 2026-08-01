#!/usr/bin/env bash
# claim-race-harness.sh — H6/L4 claim-at-selection race test (bd-u2lo1.15).
#
# GATES trunk-direct stage 3: per the archived plan
# `_plans/_done/2026-07-11-1351-trunk-direct-execution-doctrine.md` §5 ("PRE-STAGE-3
# BUILD SET... GATE: claim-race test green + ...") and §7 ("claim-at-selection race
# test (H6/L4 — gates stage 3)"), this harness must pass green before the
# conductor-concurrency cap can be raised beyond 1.
#
# REPO: agent-compounds (skills/ac-pipeline/scripts/) — symlinked into every neoMeta app
# that adopts trunk-direct claim-at-selection (ac-loop Phase 1/2, ac-implement Phase
# 1a). Lives alongside beads-closed-gate.sh, the sibling script covering the SAME
# mechanism's closing half (assignee-scoped gate vs. this file's claiming-time race
# test). Reused across apps, not made body-compass-app-local, even though it is
# exercised here against BCA's live `.beads` DB (see rationale below).
#
# WHY REAL `br`, NOT A MOCK (documented per the bead's explicit either/or option):
# the property under test — "does concurrent `br update <ids...> --status
# in_progress --assignee <name>` on an OVERLAPPING id set ever produce a double
# claim or a zero-claim deadlock" — is a property of beads_rust's OWN SQLite-backed
# write path (locking, transaction isolation), not of anything this repo controls.
# A mocked `br` (the pattern beads-closed-gate.test.sh uses) would only prove this
# SCRIPT's own bookkeeping is correct, never the actual tool's concurrency
# guarantee — which is exactly what H6/L4 needs proven. So this harness drives the
# REAL `br` binary against REAL throwaway beads:
#   - created with `--ephemeral` (never exported to `.beads/issues.jsonl` — no git
#     diff, no `br sync` call needed or made by this script, zero risk of polluting
#     the shared board or interleaving with a concurrent conductor's real work)
#   - EVERY create/update/delete call below also passes `--no-auto-flush
#     --no-auto-import`: `br`'s default auto-flush exports the FULL local sqlite
#     DB to `.beads/issues.jsonl` on every mutating command (not a scoped diff —
#     same risk `beads-closed-gate.sh`'s `warn_bead_bleed` guards against on the
#     read side). Shakedown-verified 2026-07-12: a run of this harness WITHOUT
#     these flags surfaced an unrelated bead's pending local-DB state as a
#     `.beads/issues.jsonl` working-tree diff — genuine foreign WIP from the
#     shared checkout that this script must never be the trigger for exporting.
#     `--no-auto-flush --no-auto-import` keeps every mutation confined to the
#     ephemeral in-memory/sqlite layer this harness owns.
#   - deleted with `--hard` (prunes the tombstone from JSONL immediately) in a trap
#     that fires on ANY exit path (pass, fail, Ctrl-C) — self-cleaning
#   - labelled `claim-race-harness-smoke` so a paranoia sweep (also in the trap)
#     can catch stragglers even if the trap itself were ever bypassed (`kill -9`)
#
# MECHANISM UNDER TEST (mirrors ac-loop Phase 1/2's own words, not a paraphrase):
# "mark ALL refined ready beads for this plan `in_progress` + assignee (AGENT_NAME)
# in ONE `br update` call" (ac-loop/SKILL.md). This harness fires that EXACT
# invocation shape from two scripted "conductors" at once, on a FULLY overlapping
# id set (every bead contested at once — the worst case; a partial-overlap
# scenario, closer to ac-loop's real "two conductors picked different but
# intersecting `br ready` slices," is strictly easier and covered by the same
# code path since only the overlapping subset is ever contested).
#
# ASSERTIONS (bd-u2lo1.15 acceptance criteria, verbatim from the bead spec):
#   1. Every contested bead ends with exactly ONE assignee (no double-claim).
#   2. No contested bead is left unclaimed (no zero-claim deadlock).
#   3. The LOSING conductor's subsequent `br ready` excludes every bead the OTHER
#      conductor won (claiming flips status open -> in_progress, which drops the
#      bead out of `br ready` for EITHER identity — checked for both, not just the
#      loser, since "loser" is only knowable after the race resolves).
#
# Usage: bash claim-race-harness.sh [N_BEADS] [TRIALS]
#   N_BEADS default 6 beads per trial, TRIALS default 3 — SQLite's write lock tends
#   to serialize a single trial deterministically (last-writer-wins), so repeating
#   with fresh beads guards against a lucky ordering rather than truly exercising
#   the lock; still no substitute for real concurrent access to the real DB.
# Exit 0 — every trial passed all three assertions (beads cleaned up either way).
# Exit 1 — any assertion failed on any trial.
set -uo pipefail

N_BEADS="${1:-6}"
TRIALS="${2:-3}"
LABEL="claim-race-harness-smoke"
CONDUCTOR_A="RaceHarnessConductorA-$$"
CONDUCTOR_B="RaceHarnessConductorB-$$"

FAILURES=0
CREATED_IDS=()

# --- Self-cleaning: fires on pass, fail, or interrupt. No leftover test beads. ---
cleanup() {
  if [ "${#CREATED_IDS[@]}" -gt 0 ]; then
    br delete "${CREATED_IDS[@]}" --hard --no-auto-flush --no-auto-import \
      --reason "claim-race-harness cleanup" >/dev/null 2>&1 || true
  fi
  # Paranoia sweep: catches stragglers if the trap above was ever bypassed (kill -9
  # mid-run, prior aborted invocation left beads behind).
  local strays
  strays=$(br list --json --limit 0 --label "$LABEL" --no-auto-flush --no-auto-import 2>/dev/null \
    | jq -r '.issues[]?.id' 2>/dev/null)
  if [ -n "$strays" ]; then
    # shellcheck disable=SC2086 -- word-split intentional, IDs are single tokens
    br delete $strays --hard --no-auto-flush --no-auto-import \
      --reason "claim-race-harness stray cleanup" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

pass() { echo "  PASS: $1"; }
fail() {
  echo "  FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

for trial in $(seq 1 "$TRIALS"); do
  echo "=== Trial $trial/$TRIALS ($N_BEADS beads, full overlap) ==="
  TRIAL_IDS=()
  for i in $(seq 1 "$N_BEADS"); do
    id=$(br create --title "claim-race-harness trial $trial bead $i" --type task \
      --priority 4 --labels "$LABEL" --ephemeral --no-auto-flush --no-auto-import --silent)
    TRIAL_IDS+=("$id")
    CREATED_IDS+=("$id")
  done

  # Pre-condition sanity: every bead starts open (in `br ready`) before the race.
  for id in "${TRIAL_IDS[@]}"; do
    st=$(br show "$id" --json --no-auto-flush --no-auto-import 2>/dev/null | jq -r '.[0].status')
    [ "$st" = "open" ] || fail "Trial $trial: $id not open pre-race (status=$st)"
  done

  # --- FIRE both conductors at the SAME fully-overlapping id set, concurrently ---
  # Each conductor's invocation is the literal claim-at-selection shape: ONE
  # `br update` call over its whole candidate batch.
  (
    br update "${TRIAL_IDS[@]}" --status in_progress --assignee "$CONDUCTOR_A" \
      --actor "$CONDUCTOR_A" --no-auto-flush --no-auto-import >/dev/null 2>&1
  ) &
  PID_A=$!
  (
    br update "${TRIAL_IDS[@]}" --status in_progress --assignee "$CONDUCTOR_B" \
      --actor "$CONDUCTOR_B" --no-auto-flush --no-auto-import >/dev/null 2>&1
  ) &
  PID_B=$!
  wait "$PID_A" "$PID_B"

  # --- Assertions 1+2: exactly one assignee per bead, no zero-claim deadlock ---
  trial_ok=1
  for id in "${TRIAL_IDS[@]}"; do
    row=$(br show "$id" --json --no-auto-flush --no-auto-import 2>/dev/null | jq -c '.[0]')
    # `bstatus`, not `status` — the latter is a zsh read-only special (bd-x8ios). Harmless under
    # this file's bash shebang, but the name must not be modelled anywhere in the registry.
    bstatus=$(printf '%s' "$row" | jq -r '.status // empty')
    assignee=$(printf '%s' "$row" | jq -r '.assignee // empty')
    if [ "$bstatus" != "in_progress" ] || [ -z "$assignee" ]; then
      fail "Trial $trial: $id — ZERO-CLAIM deadlock (status=${bstatus:-<empty>} assignee=${assignee:-<none>})"
      trial_ok=0
      continue
    fi
    if [ "$assignee" != "$CONDUCTOR_A" ] && [ "$assignee" != "$CONDUCTOR_B" ]; then
      fail "Trial $trial: $id — assignee '$assignee' is neither racing conductor (corruption)"
      trial_ok=0
    fi
  done
  [ "$trial_ok" -eq 1 ] && pass "Trial $trial: every contested bead has exactly one assignee, no deadlock"

  # --- Assertion 3: post-claim `br ready` excludes every claimed bead, checked ---
  # from BOTH conductor identities (the loser is only knowable after the race
  # resolves above, so both are checked — the loser's view is asserted either way).
  READY_A=$(br ready --limit 0 --assignee "$CONDUCTOR_A" --json --no-auto-flush --no-auto-import 2>/dev/null | jq -r '.[].id')
  READY_B=$(br ready --limit 0 --assignee "$CONDUCTOR_B" --json --no-auto-flush --no-auto-import 2>/dev/null | jq -r '.[].id')
  ready_leak=0
  for id in "${TRIAL_IDS[@]}"; do
    if printf '%s\n' "$READY_A" | grep -qx "$id" || printf '%s\n' "$READY_B" | grep -qx "$id"; then
      fail "Trial $trial: $id leaked into a post-claim br ready listing (should be in_progress, excluded from ready for BOTH identities, including the loser's)"
      ready_leak=1
    fi
  done
  [ "$ready_leak" -eq 0 ] && pass "Trial $trial: every claimed bead excluded from br ready for both conductor identities (loser's view included)"
done

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All $TRIALS claim-race trial(s) passed — H6/L4 stage-3 gate condition satisfied."
  exit 0
else
  echo "$FAILURES claim-race assertion(s) FAILED across $TRIALS trial(s)."
  exit 1
fi
