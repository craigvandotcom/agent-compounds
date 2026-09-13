#!/usr/bin/env bash
#
# actor-identity.test.sh — two workers that start in the SAME UTC SECOND with the SAME PID
# must not compute the same ACTOR. (bd-5b1, ported from easy-mode 2026-09-13)
#
# THE MEASURED FAILURE, not a hypothetical one: run ac2-20260905-eg4 put two containerised
# workers on one bead. Each had its own PID namespace, both started inside one UTC second,
# and `ac-$(date -u +%Y%m%d-%H%M%S)-$$` produced the identical string for both. `br ready`
# treats `assignee == $me` as claimable — by design, so a worker can resume its own claim —
# so the second `--claim` never returned VALIDATION_FAILED, both workers held bd-eg4.5, and
# one committed a tree pairing its own src with the other's in-progress test file. Trunk
# stayed red for four commits, during which two beads closed GREEN because their probes are
# file-scoped and cannot see a broken sibling.
#
# WHAT MAKES THIS A PROBE AND NOT A RESTATEMENT: it LIFTS the ACTOR line out of
# references/worker.md and evaluates THAT — the doctrine's own text, never a copy. A copy
# would keep passing after someone edited the loop back to a colliding formula, which is the
# entire failure mode. If the line cannot be lifted, this exits non-zero; it never assumes.
#
# worker.md carries this line as the NO-Agent-Mail fallback (in a swarm ACTOR is the minted
# Agent Mail name, which the server keeps unique); the fallback is the one that can collide.
#
# The PID is held constant across the two evaluations for free: both run in THIS process, so
# `$$` is identical, which is exactly the container-PID-reuse case. The second is held
# constant by construction (see the fresh-second alignment below).
#
# ASSURANCE (skills/ac-pipeline/references/assurance-declarations.md § The four fields):
#   PROBE:      itself
#   SCHEDULE:   every scripts/run-all-harnesses.sh run (repo-wide *.test.sh discovery),
#               which lint.sh Check 20 audits for scheduling.
#   MODE:       blocking
#   ON-FAILURE: closed — a collision fails the run and prints both identities
#
# EXIT: 0 pass · 77 self-skip (a precondition this runner cannot provision) · else fail
set -uo pipefail

# Skill-relative, never repo-relative: this file is also reached through a consumer's
# .claude/skills symlink, where ../../.. is the harness home, not this registry.
LOOP="$(cd "$(dirname "$0")/../references" && pwd)/worker.md"
FAILURES=0
SAMPLES=200

# TAP-shaped assertion lines (`ok <n> - <what>` / `not ok <n> - <what>`), because a harness
# that prints only a summary reads identical to one that asserted nothing -- and because the
# ac-implement close gate counts exactly these lines as its anti-bail evidence.
ASSERTION=0
fail() { ASSERTION=$((ASSERTION + 1)); echo "not ok $ASSERTION - $*"; FAILURES=$((FAILURES + 1)); }
pass() { ASSERTION=$((ASSERTION + 1)); echo "ok $ASSERTION - $*"; }

[ -f "$LOOP" ] || { echo "not ok 1 - the loop file is missing: $LOOP" >&2; exit 1; }

# --- lift the formula from the doctrine itself -------------------------------------------
FORMULA=$(grep -m1 -E '^[[:space:]]*ACTOR=' "$LOOP" | sed -E 's/^[[:space:]]*//; s/[[:space:]]+#.*$//')
if [ -z "$FORMULA" ]; then
  echo "not ok 1 - no 'ACTOR=' line in $LOOP: the identity formula this harness exists to test is gone" >&2
  exit 1
fi
echo "lifted from worker.md: $FORMULA"

# --- 1. the formula must carry a component that is not the clock and not the PID ----------
case "$FORMULA" in
  *uuid*|*UUID*|*RANDOM*|*openssl*|*counter*) pass "the formula carries a collision-resistant component" ;;
  *) fail "the formula is derived only from the clock and the PID — both COLLIDE across sandboxed workers: $FORMULA" ;;
esac

# --- 2. two identities computed in ONE UTC second, with one PID, must differ --------------
# Align to a fresh second first, so the pair cannot straddle a boundary and pass by accident:
# a tick between them would make the timestamps differ and prove nothing about the case that
# actually bit.
start_second=$(date -u +%S)
while [ "$(date -u +%S)" = "$start_second" ]; do :; done

eval "$FORMULA"; first="$ACTOR"
eval "$FORMULA"; second="$ACTOR"
same_second=$([ "$(printf '%s' "$first" | cut -d- -f2)" = "$(printf '%s' "$second" | cut -d- -f2)" ] && echo yes || echo no)

if [ "$same_second" != "yes" ]; then
  # Not a pass and not a failure of the formula: the pair straddled a second boundary, so the
  # case under test was never exercised. Loud, and counted as a skip by the runner contract.
  echo "SKIP: the two identities landed in different UTC seconds — the collision case was not exercised" >&2
  exit 77
fi

if [ "$first" = "$second" ]; then
  fail "two identities computed in the same UTC second with the same PID are IDENTICAL: $first"
else
  pass "same second, same PID, different identity ($first != $second)"
fi

# --- 3. and at swarm scale: no duplicate across many rapid mints -------------------------
mints=""
i=0
while [ "$i" -lt "$SAMPLES" ]; do
  eval "$FORMULA"
  mints="$mints$ACTOR
"
  i=$((i + 1))
done
unique=$(printf '%s' "$mints" | grep -c . )
distinct=$(printf '%s' "$mints" | sort -u | grep -c . )
if [ "$unique" -ne "$distinct" ]; then
  fail "$((unique - distinct)) duplicate(s) among $unique identities minted back to back"
else
  pass "$distinct distinct identities out of $unique mints"
fi

# --- 4. the identity must still be usable as a --actor value and a commit trailer ---------
eval "$FORMULA"
case "$ACTOR" in
  *[!A-Za-z0-9._-]*) fail "the identity carries a character that is not safe in a label, a path or a commit trailer: $ACTOR" ;;
  "") fail "the formula produced an empty identity" ;;
  *) pass "the identity is shell- and label-safe ($ACTOR)" ;;
esac

if [ "$FAILURES" -gt 0 ]; then
  echo "actor-identity: $FAILURES failure(s)" >&2
  exit 1
fi
echo "actor-identity: all checks passed"
exit 0
