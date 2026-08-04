#!/usr/bin/env bash
# bead-refine-concurrent-dir.test.sh — fan-out safety proof for ac-bead-refine (bd-baudw).
#
# SIBLING of run-id-concurrent-dir.test.sh, and deliberately a different scenario.
# That test proves two *conductors* on DIFFERENT RUN_IDs don't collide. This one proves
# the harder case that actually bit us: two `ac-bead-refine` CHILDREN fanned out by ONE
# ac-loop conductor, which hands every child the **same RUN_ID** and the **same claim id**
# by design (RUN_ID identifies the run, not the child — ac-loop/SKILL.md Phase 0 mints
# exactly one). Under the old `ARTIFACTS_DIR=/tmp/bead-refine-${RUN_ID}` formula both
# children resolved to ONE directory, overwrote each other's beads-snapshot.json in the
# same clock second, and the Phase 5 stamp loop — which read that file as its authority —
# stamped `refined` onto beads the child never reviewed. Observed live twice
# (2026-07-22, 2026-07-28); the id sets were FULLY DISJOINT, so a lost race mis-stamps
# 100% of the beads in both directions at once.
#
# REPO: agent-compounds (skills/ac-pipeline/scripts/) — shared by every app that symlinks the
# registry. No `br`, no git state, no network: pure shell against the documented formulas,
# plus a stubbed-`br` probe of the stamp loop.
#
# WHAT IS PROVEN
#   1  two children, SAME RUN_ID, no AGENT_NAME       -> distinct dirs (via $$)          [AC1]
#   2  two children, SAME RUN_ID, distinct AGENT_NAME -> distinct dirs (via identity)    [AC1]
#   3  caller pre-sets CHILD_ID in the env            -> ignored; still distinct         [AC1]
#   4  NEGATIVE CONTROL: the old RUN_ID-only formula  -> DOES collide (test is sensitive)[AC4]
#   5  stamp loop keyed on target-bead-ids.txt        -> zero `br label` on foreign ids  [AC3]
#   5b NEGATIVE CONTROL: old snapshot-keyed loop      -> DOES touch foreign ids          [AC3]
#   5c the SAME loop body under real zsh              -> no read-only-special abort  [bd-x8ios]
#   6  drift guard: the formulas here match workflow.md verbatim                         [AC1]
#   7  ac-loop's rendered refine delegation passes RUN_ID BARE + TARGET_BEAD_IDS         [AC5]
#   8  Phase 0 writes are dcg-safe (no `>` into a variable path)                         [AC6]
#
# WHY `bash -c ... &` AND NOT `( ... ) &`: bash's `$$` stays fixed to the TOP-LEVEL
# shell's PID inside `( )` subshells, so a subshell harness would measure its own process
# structure instead of the formula. `bash -c '...' &` forks a genuinely separate process
# with its own PID — the only shape that simulates two independent child SESSIONS.
#
# Usage: bash bead-refine-concurrent-dir.test.sh [--mkdir]
# Exit 0 — all assertions passed. Exit 1 — a collision, a scope leak, or doc drift.
set -uo pipefail

MKDIR_PROOF=0
[ "${1:-}" = "--mkdir" ] && MKDIR_PROOF=1

FAILURES=0
CREATED_DIRS=()
TMP_ROOT="$(mktemp -d /tmp/bead-refine-test-XXXXXX)"

cleanup() {
  rm -rf "$TMP_ROOT"
  if [ "${#CREATED_DIRS[@]}" -gt 0 ]; then
    for d in "${CREATED_DIRS[@]}"; do rm -rf "$d"; done
  fi
}
trap cleanup EXIT INT TERM

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }
skip() { echo "  SKIP: $1"; }

# skills/ac-pipeline/scripts -> skills/   (works through the per-app .claude/skills symlink too)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOW="$SKILLS_DIR/ac-bead-refine/references/workflow.md"
AC_LOOP="$SKILLS_DIR/ac-loop/SKILL.md"

# The child's derivation, byte-identical to workflow.md § Phase 0 "Configuration".
# Case 6 asserts these two lines still exist verbatim in the doc, so the test cannot
# silently drift away from the contract it claims to gate.
CHILD_ID_LINE='CHILD_ID="$(printf '"'"'%s'"'"' "${AGENT_NAME:-anon}" | command tr -cd '"'"'A-Za-z0-9'"'"')-$$"'
DIR_LINE='ARTIFACTS_DIR="/tmp/bead-refine-${CHILD_ID}${RUN_ID:+-$RUN_ID}"'

# Body run inside each simulated child process (fresh PID per invocation).
CHILD_BODY='
  RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
  unset CHILD_ID 2>/dev/null || true
  CHILD_ID="$(printf "%s" "${AGENT_NAME:-anon}" | command tr -cd "A-Za-z0-9")-$$"
  ARTIFACTS_DIR="/tmp/bead-refine-${CHILD_ID}${RUN_ID:+-$RUN_ID}"
  printf "%s\n" "$ARTIFACTS_DIR"
'

# Sets globals KID_A / KID_B. (No `mapfile` anywhere in this script — macOS ships bash 3.2.)
run_two_children() { # $1=shared RUN_ID  $2=AGENT_NAME for A ("" = unset)  $3=for B  $4=preset CHILD_ID ("" = none)
  local run_id="$1" name_a="$2" name_b="$3" preset="$4"
  local out_a="$TMP_ROOT/child-a.out" out_b="$TMP_ROOT/child-b.out"
  RUN_ID="$run_id" AGENT_NAME="$name_a" CHILD_ID="$preset" bash -c "$CHILD_BODY" >"$out_a" &
  local pid_a=$!
  RUN_ID="$run_id" AGENT_NAME="$name_b" CHILD_ID="$preset" bash -c "$CHILD_BODY" >"$out_b" &
  local pid_b=$!
  wait "$pid_a" "$pid_b"
  KID_A=$(cat "$out_a")
  KID_B=$(cat "$out_b")
  rm -f "$out_a" "$out_b"
}

SHARED_RUN_ID="20260729-170058-3584"   # one RUN_ID, exactly as ac-loop threads it

echo "=== Case 1: two refine children, SAME RUN_ID, AGENT_NAME unset (PID discriminator) ==="
run_two_children "$SHARED_RUN_ID" "" "" ""
DIR_A="$KID_A"; DIR_B="$KID_B"
echo "  child A: $DIR_A"
echo "  child B: $DIR_B"
if [ "$DIR_A" = "$DIR_B" ]; then
  fail "Case 1: two children on one RUN_ID resolved to the SAME dir ($DIR_A) — the per-child discriminator is gone; this is bd-baudw"
else
  pass "Case 1: same RUN_ID -> distinct ARTIFACTS_DIR: $DIR_A != $DIR_B"
fi

echo
echo "=== Case 2: two refine children, SAME RUN_ID, distinct Agent Mail identities ==="
run_two_children "$SHARED_RUN_ID" "CobaltHeron" "WildSparrow" ""
DIR_C="$KID_A"; DIR_D="$KID_B"
echo "  child CobaltHeron: $DIR_C"
echo "  child WildSparrow: $DIR_D"
if [ "$DIR_C" = "$DIR_D" ]; then
  fail "Case 2: distinct identities still collided ($DIR_C)"
elif ! printf '%s' "$DIR_C" | grep -q 'CobaltHeron' || ! printf '%s' "$DIR_D" | grep -q 'WildSparrow'; then
  fail "Case 2: the Agent Mail identity is not present in the dir name — identity half of the discriminator is missing"
else
  pass "Case 2: identity + PID both discriminate: $DIR_C != $DIR_D"
fi

echo
echo "=== Case 3: a caller-supplied CHILD_ID must NOT be honoured (no caller override) ==="
run_two_children "$SHARED_RUN_ID" "CobaltHeron" "WildSparrow" "ATTACKER-SUPPLIED"
DIR_E="$KID_A"; DIR_F="$KID_B"
echo "  child CobaltHeron (CHILD_ID=ATTACKER-SUPPLIED in env): $DIR_E"
echo "  child WildSparrow (CHILD_ID=ATTACKER-SUPPLIED in env): $DIR_F"
if printf '%s%s' "$DIR_E" "$DIR_F" | grep -q 'ATTACKER'; then
  fail "Case 3: an inherited CHILD_ID leaked into the dir — the caller can override the discriminator"
elif [ "$DIR_E" = "$DIR_F" ]; then
  fail "Case 3: a shared caller-supplied CHILD_ID collapsed both children onto $DIR_E"
else
  pass "Case 3: env CHILD_ID ignored; children still distinct: $DIR_E != $DIR_F"
fi

echo
echo "=== Case 4: NEGATIVE CONTROL — the OLD RUN_ID-only formula must collide ==="
OLD_BODY='RUN_ID="${RUN_ID:-x}"; printf "%s\n" "/tmp/bead-refine-${RUN_ID}"'
OLD_A=$(RUN_ID="$SHARED_RUN_ID" bash -c "$OLD_BODY")
OLD_B=$(RUN_ID="$SHARED_RUN_ID" bash -c "$OLD_BODY")
echo "  old-formula child A: $OLD_A"
echo "  old-formula child B: $OLD_B"
if [ "$OLD_A" = "$OLD_B" ]; then
  pass "Case 4: the pre-fix formula collides as expected — this test is sensitive to the discriminator being removed"
else
  fail "Case 4: the negative control did NOT collide — the harness is not measuring what it claims"
fi

echo
echo "=== Case 5: stamp loop is authoritative on target-bead-ids.txt, not the snapshot ==="
# Fixture reproduces the observed live shape: the child owns 3 beads; the snapshot on disk
# holds a SIBLING's 4 beads (fully disjoint — comm -12 empty), exactly as after a lost race.
PROBE_DIR="$TMP_ROOT/probe"
mkdir -p "$PROBE_DIR/bin"
printf '%s\n' bd-mine01 bd-mine02 bd-mine03 | tee "$PROBE_DIR/target-bead-ids.txt" >/dev/null
tee "$PROBE_DIR/beads-snapshot.json" >/dev/null <<'JSON'
{"issues":[
 {"id":"bd-alien1","status":"open","title":"sibling bead 1","issue_type":"task","labels":["unrefined"]},
 {"id":"bd-alien2","status":"open","title":"sibling bead 2","issue_type":"task","labels":["unrefined"]},
 {"id":"bd-alien3","status":"open","title":"sibling bead 3","issue_type":"task","labels":["unrefined"]},
 {"id":"bd-alien4","status":"open","title":"sibling bead 4","issue_type":"task","labels":["unrefined"]}
]}
JSON

# `br` stub: logs every invocation; `br list --json --id X ...` re-emits those ids as open.
tee "$PROBE_DIR/bin/br" >/dev/null <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BR_CALL_LOG"
if [ "${1:-}" = "list" ]; then
  ids=(); prev=""
  for a in "$@"; do [ "$prev" = "--id" ] && ids+=("$a"); prev="$a"; done
  printf '{"issues":['
  sep=""
  for i in "${ids[@]}"; do
    printf '%s{"id":"%s","status":"open","title":"t","issue_type":"task","labels":["unrefined"]}' "$sep" "$i"
    sep=","
  done
  printf ']}\n'
fi
exit 0
STUB
chmod +x "$PROBE_DIR/bin/br"

# The Phase 5 stamp loop, retyped verbatim from workflow.md § Remove `unrefined`, Stamp `refined`.
# STAMP_SHELL is parameterised so Case 5c can re-run the identical body under real zsh — the
# fleet's default shell, where a variable named `status` is READ-ONLY and aborts the loop
# (bd-x8ios). Running this only under bash is exactly why that bug survived.
run_stamp_loop() {
  ARTIFACTS_DIR="$PROBE_DIR" PATH="$PROBE_DIR/bin:$PATH" BR_CALL_LOG="$1" "${STAMP_SHELL:-bash}" -c '
    set -uo pipefail
    REFINE_PATH="refine-full"
    [ -s "$ARTIFACTS_DIR/target-bead-ids.txt" ] || { echo "FATAL: no target list" >&2; exit 2; }
    MISSING=$(comm -23 \
      <(sort -u "$ARTIFACTS_DIR/target-bead-ids.txt") \
      <(jq -r ".issues[].id" "$ARTIFACTS_DIR/beads-snapshot.json" | sort -u))
    if [ -n "$MISSING" ]; then
        echo "  (loop) WARN: snapshot does not cover targets ($(echo "$MISSING" | tr "\n" " ")) — rebuilding from the target list"
        REBUILD_FLAGS=()
        while IFS= read -r t; do [ -n "$t" ] && REBUILD_FLAGS+=(--id "$t"); done < "$ARTIFACTS_DIR/target-bead-ids.txt"
        br list --json "${REBUILD_FLAGS[@]}" --all | tee "$ARTIFACTS_DIR/beads-snapshot.json" >/dev/null
    fi
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        bstatus=$(jq -r --arg id "$id" "first(.issues[] | select(.id == \$id) | .status) // \"unknown\"" "$ARTIFACTS_DIR/beads-snapshot.json")
        [ "$bstatus" = "open" ] || { echo "  (loop) SKIP $id (status=$bstatus)"; continue; }
        br label remove "$id" "unrefined" 2>/dev/null
        br label add "$id" "refined" 2>/dev/null
        br label add "$id" "$REFINE_PATH" 2>/dev/null
    done < "$ARTIFACTS_DIR/target-bead-ids.txt"
  '
}

if ! command -v jq >/dev/null 2>&1; then
  skip "Case 5: jq not installed — cannot exercise the stamp loop"
else
  NEW_LOG="$PROBE_DIR/new-calls.log"; printf '' | tee "$NEW_LOG" >/dev/null
  run_stamp_loop "$NEW_LOG"
  LEAKED=$(grep -c 'bd-alien' "$NEW_LOG" || true)
  STAMPED=$(grep -c 'label add bd-mine.* refined' "$NEW_LOG" || true)
  echo "  br calls against FOREIGN (sibling) ids: $LEAKED"
  echo "  br 'label add <mine> refined' calls:     $STAMPED"
  if [ "$LEAKED" -ne 0 ]; then
    fail "Case 5: the stamp loop made $LEAKED call(s) against beads this child was never handed"
  elif [ "$STAMPED" -ne 3 ]; then
    fail "Case 5: expected 3 refined-stamps on the child's own beads, got $STAMPED"
  else
    pass "Case 5: zero calls against foreign ids; all 3 target beads stamped despite a hostile snapshot"
  fi

  # 5c — the SAME loop body under real zsh (bd-x8ios). Must stamp all 3; any assignment to a
  # zsh read-only special (`status`, `path`, `argv`, `pipestatus`, …) fails here and only here.
  if command -v zsh >/dev/null 2>&1; then
    ZSH_LOG="$PROBE_DIR/zsh-calls.log"; printf '' | tee "$ZSH_LOG" >/dev/null
    if STAMP_SHELL=zsh run_stamp_loop "$ZSH_LOG" >/dev/null 2>"$PROBE_DIR/zsh-stamp.err"; then
      ZSH_STAMPED=$(grep -c 'label add bd-mine.* refined' "$ZSH_LOG" || true)
      if [ "$ZSH_STAMPED" -eq 3 ]; then
        pass "Case 5c: the stamp loop runs clean under zsh — no read-only-special assignment"
      else
        fail "Case 5c: under zsh only $ZSH_STAMPED/3 beads stamped ($(tr '\n' ' ' < "$PROBE_DIR/zsh-stamp.err"))"
      fi
    else
      fail "Case 5c: the stamp loop ABORTED under zsh ($(tr '\n' ' ' < "$PROBE_DIR/zsh-stamp.err"))"
    fi
  else
    skip "Case 5c: zsh not on PATH — cannot prove the loop is read-only-special safe"
  fi

  # 5b — negative control: the pre-fix loop (snapshot-keyed) must leak, proving the probe bites.
  OLD_LOG="$PROBE_DIR/old-calls.log"; printf '' | tee "$OLD_LOG" >/dev/null
  tee "$PROBE_DIR/beads-snapshot.json" >/dev/null <<'JSON'
{"issues":[
 {"id":"bd-alien1","status":"open","title":"sibling bead 1","issue_type":"task","labels":["unrefined"]},
 {"id":"bd-alien2","status":"open","title":"sibling bead 2","issue_type":"task","labels":["unrefined"]},
 {"id":"bd-alien3","status":"open","title":"sibling bead 3","issue_type":"task","labels":["unrefined"]},
 {"id":"bd-alien4","status":"open","title":"sibling bead 4","issue_type":"task","labels":["unrefined"]}
]}
JSON
  ARTIFACTS_DIR="$PROBE_DIR" PATH="$PROBE_DIR/bin:$PATH" BR_CALL_LOG="$OLD_LOG" bash -c '
    for id in $(jq -r ".issues[] | select(.status == \"open\") | .id" "$ARTIFACTS_DIR/beads-snapshot.json"); do
        br label remove "$id" "unrefined" 2>/dev/null
        br label add "$id" "refined" 2>/dev/null
    done
  ' >/dev/null
  OLD_LEAKED=$(grep -c 'bd-alien' "$OLD_LOG" || true)
  echo "  pre-fix (snapshot-keyed) loop, calls against foreign ids: $OLD_LEAKED"
  if [ "$OLD_LEAKED" -gt 0 ]; then
    pass "Case 5b: the pre-fix loop mis-stamps $OLD_LEAKED time(s) on the same fixture — the probe is sensitive"
  else
    fail "Case 5b: the negative control did not leak — the probe proves nothing"
  fi
fi

echo
echo "=== Case 6: drift guard — the formula under test matches workflow.md verbatim ==="
if [ ! -f "$WORKFLOW" ]; then
  skip "Case 6: workflow.md not reachable from $SKILLS_DIR"
else
  ok=1
  grep -qF "$CHILD_ID_LINE" "$WORKFLOW" || { fail "Case 6: CHILD_ID line not found verbatim in workflow.md"; ok=0; }
  grep -qF "$DIR_LINE" "$WORKFLOW" || { fail "Case 6: ARTIFACTS_DIR line not found verbatim in workflow.md"; ok=0; }
  grep -qF 'target-bead-ids.txt' "$WORKFLOW" || { fail "Case 6: workflow.md has no target-bead-ids.txt authority file"; ok=0; }
  grep -qF 'TARGET_BEAD_IDS' "$WORKFLOW" || { fail "Case 6: workflow.md has no TARGET_BEAD_IDS scope branch"; ok=0; }
  # bd-x8ios: the documented loop must not reintroduce a zsh read-only special as its own variable.
  grep -qE '^ *(status|path|argv|pipestatus|options|signals)=' "$WORKFLOW" && { fail "Case 6: workflow.md assigns a zsh read-only special (bd-x8ios) — rename it"; ok=0; }
  [ "$ok" -eq 1 ] && pass "Case 6: workflow.md still documents exactly the formulas + scope channel this test exercises"
fi

echo
echo "=== Case 7: ac-loop's rendered refine delegation — bare RUN_ID + explicit TARGET_BEAD_IDS ==="
if [ ! -f "$AC_LOOP" ]; then
  skip "Case 7: ac-loop/SKILL.md not reachable from $SKILLS_DIR"
else
  ok=1
  # The safety must live in the child's key, NOT in a hand-suffixed RUN_ID in the prompt.
  if grep -nE 'RUN_ID=[^ `"]*-(refine|child)[A-Z0-9]' "$AC_LOOP" >/dev/null; then
    fail "Case 7: ac-loop renders a per-child-suffixed RUN_ID — the bd-baudw workaround is back"
    ok=0
  fi
  grep -qF 'TARGET_BEAD_IDS' "$AC_LOOP" || { fail "Case 7: no refine delegation passes TARGET_BEAD_IDS"; ok=0; }
  grep -qF 'RUN_ID=<RUN_ID>' "$AC_LOOP" || { fail "Case 7: no bare RUN_ID=<RUN_ID> in the delegation prompts"; ok=0; }
  # And with that bare shared RUN_ID, two children must STILL land in distinct dirs.
  run_two_children "$SHARED_RUN_ID" "ChildOne" "ChildTwo" ""
  if [ "$KID_A" = "$KID_B" ]; then
    fail "Case 7: under the bare rendered RUN_ID the two children collided ($KID_A)"
    ok=0
  fi
  [ "$ok" -eq 1 ] && pass "Case 7: prompt passes RUN_ID bare + TARGET_BEAD_IDS; children still distinct ($KID_A != $KID_B)"
fi

echo
echo "=== Case 8: Phase 0 writes are dcg-safe (no '>' redirect into a variable path) ==="
if [ ! -f "$WORKFLOW" ]; then
  skip "Case 8: workflow.md not reachable"
else
  BAD=$(grep -nE '[^>]> *"?\$(ARTIFACTS_DIR|PROBE_DIR)' "$WORKFLOW" || true)
  if [ -n "$BAD" ]; then
    fail "Case 8: truncating redirect(s) into a variable path — dcg rule core.filesystem:redirect-truncate-dynamic-path will block these:"
    printf '%s\n' "$BAD" | sed 's/^/        /'
  else
    pass "Case 8: no truncating redirect into \$ARTIFACTS_DIR (writes go through 'tee <path> >/dev/null')"
  fi
  if command -v dcg >/dev/null 2>&1; then
    DCG_BAD=0; DCG_N=0
    while IFS= read -r line; do
      DCG_N=$((DCG_N + 1))
      if ! dcg test "$line" 2>&1 | grep -q 'ALLOWED'; then
        fail "Case 8: dcg BLOCKS a documented Phase 0 write: $line"
        DCG_BAD=$((DCG_BAD + 1))
      fi
    done < <(grep -E 'tee "\$ARTIFACTS_DIR' "$WORKFLOW" | sed 's/^ *//')
    [ "$DCG_BAD" -eq 0 ] && pass "Case 8 (live dcg): all $DCG_N documented \$ARTIFACTS_DIR writes are ALLOWED as written"
  else
    skip "Case 8 (live dcg): dcg not on PATH — static check only"
  fi
fi

if [ "$MKDIR_PROOF" -eq 1 ]; then
  echo
  echo "=== Filesystem-level proof (--mkdir): both children's dirs exist independently ==="
  mkdir -p "$DIR_A" "$DIR_B"
  CREATED_DIRS+=("$DIR_A" "$DIR_B")
  printf 'snapshot-A\n' | tee "$DIR_A/beads-snapshot.json" >/dev/null
  printf 'snapshot-B\n' | tee "$DIR_B/beads-snapshot.json" >/dev/null
  if [ "$(cat "$DIR_A/beads-snapshot.json")" = "snapshot-A" ] && [ "$(cat "$DIR_B/beads-snapshot.json")" = "snapshot-B" ]; then
    pass "--mkdir: both snapshots survive on disk — no last-writer-wins clobber"
  else
    fail "--mkdir: one child's beads-snapshot.json was overwritten by the other"
  fi
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All ac-bead-refine fan-out assertions passed — siblings isolate automatically (bd-baudw)."
  exit 0
else
  echo "$FAILURES ac-bead-refine fan-out assertion(s) FAILED."
  exit 1
fi
