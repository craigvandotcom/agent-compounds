#!/usr/bin/env bash
# bead-work-concurrent-dir.test.sh — same-batch SIBLING collision proof for the
# `bead-work` prefix (ac-wno).
#
# WHAT NO EXISTING SCRIPT COVERS. `run-id-concurrent-dir.test.sh` proves two
# conductors with DIFFERENT RUN_IDs stay apart; `bead-refine-concurrent-dir.test.sh`
# proves the same for the `bead-refine` prefix. Neither covers the collision that
# actually happened (RUN 20260802-084558-9799, claim id `ac-gcj.8-20260802`): ONE
# claimed batch split across two ac-implement children, which by contract receive the
# IDENTICAL CLAIM_ID *and* the IDENTICAL RUN_ID — so neither key discriminates them and
# both derived the same `/tmp/bead-work-<claim>-<run>` and appended to one progress.md.
#
# THE SEAM THIS GATES (AC 3): doctrine (`ac-pipeline/references/run-id.md`, the
# `bead-work` row) <-> derivation (`ac-implement/SKILL.md` Phase 0 § Configuration).
# Doc/instruction drift is this bug's own species, so the script must go RED if EITHER
# half alone is reverted — two assertions each covering one half is an untested seam.
#
#   * derivation half — Case 1/2/3 EXTRACT the live `CHILD_ID=` and `ARTIFACTS_DIR=`
#     assignments out of the real SKILL.md and EXECUTE them. Revert that file to the
#     bare `/tmp/bead-work-${CLAIM_ID}${RUN_ID:+-$RUN_ID}` (discriminator comment-only)
#     and Case 0 fails on the missing live CHILD_ID, Case 1 fails on the collision.
#   * doctrine half — Case 4 asserts the run-id.md WORDING, not its mere presence: a
#     presence-grep still passes after the text drifts back to opt-in. CHOSEN SHAPE:
#     **negative + positive grep against the real run-id.md** (the lighter of the two
#     options the bead offered; the alternative was a mutated-copy harness). It fails
#     if the opt-in phrasing ("knows it is one of N") reappears anywhere in the file,
#     and fails if the bead-work row stops stating the key is UNCONDITIONAL.
#
# Both halves read the real files — nothing here is a retyped copy that can drift.
#
# Usage: bash skills/ac-pipeline/scripts/bead-work-concurrent-dir.test.sh
# Exit 0 — all assertions passed. Exit 1 — a collision, a broken glob, or seam drift.
set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SKILL="$REPO_ROOT/skills/ac-implement/SKILL.md"
DOCTRINE="$REPO_ROOT/skills/ac-pipeline/references/run-id.md"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }
skip() { echo "  SKIP: $1"; }

for f in "$SKILL" "$DOCTRINE"; do
  [ -f "$f" ] || { echo "FATAL: cannot read $f (run from the agent-compounds checkout)"; exit 1; }
done

# --- extract the LIVE (uncommented) assignments from the real SKILL.md -------------
# A `#`-prefixed variant does not match: the anchor allows leading whitespace only.
extract_live_assign() {
  grep -nE "^[[:space:]]*$1=" "$SKILL" | head -1 | cut -d: -f2-
}

echo "=== Case 0: ac-implement/SKILL.md carries a LIVE per-child derivation ==="
CHILD_EXPR="$(extract_live_assign CHILD_ID)"
DIR_EXPR="$(extract_live_assign ARTIFACTS_DIR)"
echo "  CHILD_ID     -> ${CHILD_EXPR:-<none>}"
echo "  ARTIFACTS_DIR-> ${DIR_EXPR:-<none>}"

if [ -z "$CHILD_EXPR" ]; then
  fail "Case 0: no LIVE 'CHILD_ID=' assignment in ac-implement/SKILL.md — the derivation half is reverted or the discriminator is comment-only (ac-wno AC 1)"
elif [ -z "$DIR_EXPR" ]; then
  fail "Case 0: no LIVE 'ARTIFACTS_DIR=' assignment in ac-implement/SKILL.md"
elif ! printf '%s' "$DIR_EXPR" | grep -q 'CHILD_ID'; then
  fail "Case 0: the live ARTIFACTS_DIR assignment does not use CHILD_ID — the per-child key is not applied unconditionally"
elif ! printf '%s' "$DIR_EXPR" | grep -qE 'RUN_ID:\+-\$RUN_ID\}?"?[[:space:]]*$'; then
  fail "Case 0: RUN_ID does not TRAIL LAST in the live ARTIFACTS_DIR assignment — ac-land's /tmp/bead-work-*-\$RUN_ID glob would stop matching"
else
  pass "Case 0: live derivation composes CHILD_ID before a trailing RUN_ID suffix"
fi

echo
echo "=== Case 0a (SHAPE GUARD): the extracted assignments match their sanctioned shape ==="
# Cases 1-3 SPLICE the extracted text into a `bash -c` / `zsh -c` payload and execute it.
# Reading the real on-disk file is the whole point (that is what makes the seam proof
# convict), so this is NOT replaced with a hardcoded copy — instead the extracted text is
# VALIDATED BEFORE it can ever be executed. A whole-line ALLOW-LIST is used, not a
# metacharacter blocklist: the sanctioned CHILD_ID line legitimately contains a PIPE
# (`| command tr -cd ...`), so a "no metacharacters" rule would reject the correct text,
# and a blocklist can always be defeated by the one character it forgot.
#
# If you deliberately change either derivation in ac-implement/SKILL.md, update the
# matching pattern here in the same commit — a mismatch is a hard failure by design.
CHILD_ID_SHAPE_RE='^[[:space:]]*CHILD_ID="\$\(printf '\''%s'\'' "\$\{AGENT_NAME:-[A-Za-z0-9_]+\}" \| command tr -cd '\''[A-Za-z0-9-]+'\''\)-\$\$"$'
ARTIFACTS_DIR_SHAPE_RE='^[[:space:]]*ARTIFACTS_DIR="/tmp/bead-work-\$\{CLAIM_ID\}-\$\{CHILD_ID\}\$\{RUN_ID:\+-\$RUN_ID\}"$'

assign_shape_ok() {   # $1=allow-list regex  $2=extracted line
  printf '%s\n' "$2" | grep -Eq "$1"
}

# The ONLY path by which extracted text reaches a shell. Text that fails the allow-list is
# REPORTED and returned as rejected — it is never handed to `bash -c`.
run_if_shaped() {     # $1=allow-list regex  $2=extracted line
  if assign_shape_ok "$1" "$2"; then
    bash -c "$2"
    return 0
  fi
  echo "  REJECTED (reported, NOT executed): $2"
  return 1
}

SHAPE_OK=1
if ! assign_shape_ok "$CHILD_ID_SHAPE_RE" "$CHILD_EXPR"; then
  fail "Case 0a: the CHILD_ID line extracted from ac-implement/SKILL.md does not match its sanctioned shape — refusing to execute it. Got: ${CHILD_EXPR:-<none>}"
  SHAPE_OK=0
elif ! assign_shape_ok "$ARTIFACTS_DIR_SHAPE_RE" "$DIR_EXPR"; then
  fail "Case 0a: the ARTIFACTS_DIR line extracted from ac-implement/SKILL.md does not match its sanctioned shape — refusing to execute it. Got: ${DIR_EXPR:-<none>}"
  SHAPE_OK=0
else
  pass "Case 0a: both extracted assignments match the sanctioned allow-list (pipe inside the CHILD_ID command substitution included)"
fi

echo
echo "=== Case 0b (NEGATIVE): unsanctioned extracted text is reported, never executed ==="
# Proves the guard actually fires on the execution path, using a payload whose execution
# would leave an observable trace. If the guard is ever weakened, this sentinel appears.
SHAPE_SENTINEL="$(mktemp -u /tmp/bead-work-shape-guard-XXXXXX)"
HOSTILE_EXPR="CHILD_ID=\"\$(touch '$SHAPE_SENTINEL')\""
if run_if_shaped "$CHILD_ID_SHAPE_RE" "$HOSTILE_EXPR"; then
  fail "Case 0b: the shape guard ACCEPTED unsanctioned text and executed it — eval-of-markdown is still live"
elif [ -e "$SHAPE_SENTINEL" ]; then
  fail "Case 0b: the guard reported the text but it still executed (sentinel $SHAPE_SENTINEL exists)"
else
  pass "Case 0b: unsanctioned text was reported and NOT executed (no sentinel)"
fi
rm -f "$SHAPE_SENTINEL"

if [ "$SHAPE_OK" -ne 1 ]; then
  echo
  echo "Shape guard failed — Cases 1-3 are NOT run (that would execute unvalidated text)."
  echo "$FAILURES bead-work assertion(s) FAILED."
  exit 1
fi

# --- run the extracted derivation in a genuinely separate process ------------------
# `bash -c '...' &` (never `( ... ) &`): bash pins `$$` to the TOP-LEVEL shell for the
# whole life of that shell, subshells included — a `( ) &` harness would measure its
# own process structure instead of the formula (the run-id-concurrent-dir.test.sh
# rationale, which applies identically here).
derive_in() {   # $1=shell  $2=AGENT_NAME  $3=CLAIM_ID  $4=RUN_ID
  "$1" -c "
    AGENT_NAME='$2'; CLAIM_ID='$3'; RUN_ID='$4'
    $CHILD_EXPR
    $DIR_EXPR
    printf '%s\n' \"\$ARTIFACTS_DIR\"
  "
}

CLAIM_ID="ac-gcj.8-$(date +%Y%m%d)"          # ONE claimed batch — identical for both children
RUN_ID="20260802-084558-9799"                # ONE run — identical for both children (ac-loop mints one)

echo
echo "=== Case 1: two fan-out siblings, IDENTICAL CLAIM_ID *and* IDENTICAL RUN_ID ==="
OUT_A=$(mktemp); OUT_B=$(mktemp)
derive_in bash SiblingChildA "$CLAIM_ID" "$RUN_ID" >"$OUT_A" 2>/dev/null &
PID_A=$!
derive_in bash SiblingChildB "$CLAIM_ID" "$RUN_ID" >"$OUT_B" 2>/dev/null &
PID_B=$!
wait "$PID_A" "$PID_B"
DIR_A=$(cat "$OUT_A"); DIR_B=$(cat "$OUT_B")
rm -f "$OUT_A" "$OUT_B"
echo "  Child A: $DIR_A"
echo "  Child B: $DIR_B"

if [ -z "$DIR_A" ] || [ -z "$DIR_B" ]; then
  fail "Case 1: a child derived an EMPTY ARTIFACTS_DIR — the extracted assignment did not execute"
elif [ "$DIR_A" = "$DIR_B" ]; then
  fail "Case 1: same-batch siblings COLLIDED on $DIR_A — this is the ac-wno defect (they would share one progress.md)"
else
  pass "Case 1: identical CLAIM_ID + identical RUN_ID -> distinct ARTIFACTS_DIR (no shared progress.md)"
fi

echo
echo "=== Case 2: the run-scoped glob /tmp/bead-work-*-\$RUN_ID still matches BOTH ==="
# ac-land gathers every child of the run with this glob (run-id.md § ac-land exception).
# A discriminator appended AFTER the RUN_ID suffix silently breaks it.
matches_run_glob() { case "$1" in /tmp/bead-work-*-"$RUN_ID") return 0 ;; *) return 1 ;; esac; }
if matches_run_glob "$DIR_A" && matches_run_glob "$DIR_B"; then
  pass "Case 2: both children's dirs match /tmp/bead-work-*-$RUN_ID — ac-land still gathers the whole run"
else
  fail "Case 2: /tmp/bead-work-*-$RUN_ID does NOT match both dirs (A=$DIR_A B=$DIR_B) — the child key was composed AFTER the RUN_ID suffix, breaking ac-land's gather"
fi

echo
echo "=== Case 3: the SAME derivation under real zsh (the fleet default shell) ==="
if command -v zsh >/dev/null 2>&1; then
  ZOUT_A=$(mktemp); ZOUT_B=$(mktemp)
  derive_in zsh SiblingChildA "$CLAIM_ID" "$RUN_ID" >"$ZOUT_A" 2>/dev/null &
  ZPID_A=$!
  derive_in zsh SiblingChildB "$CLAIM_ID" "$RUN_ID" >"$ZOUT_B" 2>/dev/null &
  ZPID_B=$!
  wait "$ZPID_A" "$ZPID_B"
  ZDIR_A=$(cat "$ZOUT_A"); ZDIR_B=$(cat "$ZOUT_B")
  rm -f "$ZOUT_A" "$ZOUT_B"
  echo "  zsh Child A: ${ZDIR_A:-<empty>}"
  echo "  zsh Child B: ${ZDIR_B:-<empty>}"
  if [ -z "$ZDIR_A" ] || [ -z "$ZDIR_B" ]; then
    fail "Case 3: the derivation produced nothing under zsh — it aborted (a zsh read-only special, or bash-only syntax)"
  elif [ "$ZDIR_A" = "$ZDIR_B" ]; then
    fail "Case 3: under zsh the siblings COLLIDED on $ZDIR_A"
  elif matches_run_glob "$ZDIR_A" && matches_run_glob "$ZDIR_B"; then
    pass "Case 3: distinct dirs under zsh too, both still matching the run-scoped glob"
  else
    fail "Case 3: under zsh the dirs no longer match /tmp/bead-work-*-$RUN_ID"
  fi
else
  skip "Case 3: zsh not on PATH — cannot prove the derivation is zsh-safe"
fi

echo
echo "=== Case 4 (SEAM, doctrine half): run-id.md states the key is UNCONDITIONAL ==="
# WORDING, not presence. A presence-grep for the bead-work row passes even after the
# text drifts back to the opt-in phrasing this bead abolished.
if grep -qi 'knows it is one of N' "$DOCTRINE"; then
  fail "Case 4: run-id.md has drifted BACK to opt-in wording ('knows it is one of N') — the doctrine half of the seam is reverted"
elif ! grep -n '| *`bead-work` *|' "$DOCTRINE" | grep -qi 'per-CHILD'; then
  fail "Case 4: run-id.md's bead-work row no longer names a per-CHILD key"
elif ! grep -n '| *`bead-work` *|' "$DOCTRINE" | grep -qi 'UNCONDITIONALLY\|applied UNCONDITIONAL'; then
  fail "Case 4: run-id.md's bead-work row no longer states the per-child key is applied UNCONDITIONALLY — doctrine and derivation have drifted apart"
else
  pass "Case 4: run-id.md's bead-work row states an unconditional per-child key, with no opt-in phrasing left anywhere in the file"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All bead-work sibling-collision + seam assertions passed."
  exit 0
else
  echo "$FAILURES bead-work assertion(s) FAILED."
  exit 1
fi
