#!/usr/bin/env bash
# autopilot-gate.test.sh — proof harness for autopilot-gate.sh. Stub br, model and gh; a real
# throwaway git repo with a bare local origin; no network, no real beads, no claude session.
# Exit 0 = every case passes.
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/autopilot-gate.test.sh
#   SCHEDULE:   scripts/run-all-proofs.sh (repo-wide *.test.sh discovery)
#   MODE:       blocking
#   ON-FAILURE: closed

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
GATE="$SELF_DIR/autopilot-gate.sh"
[ -x "$GATE" ] || { echo "autopilot-gate.test: autopilot-gate.sh missing or not executable at $GATE"; exit 1; }
# The harness never inherits a live autopilot session's switch; the gate exports its own.
unset AC2_AUTOPILOT AC2_AUTOPILOT_STATE
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); echo "ok $PASS"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

GITENV=(-c user.name=t -c user.email=t@example.com -c commit.gpgsign=false)
BLOCK='{"autopilot":{"enabled":true,"implement":false,"max_priority":1,"width":2,"cap":1,"protect":"^supabase/"}}'

mkdir -p "$W/bin"
# br stub: `list` and `ready` answer from fixture files; `list` fails when list.fail exists.
cat >"$W/bin/br" <<SH
#!/usr/bin/env bash
echo "\$*" >>"$W/br.log"
case "\$1" in
  list)  [ -f "$W/list.fail" ] && exit 1; cat "$W/list.json" ;;
  ready) cat "$W/ready.json" ;;
  *)     exit 9 ;;
esac
SH
# gh stub: `run list … --commit <sha> …` answers from gh/<sha>.json ([] when absent); gh.fail fails.
cat >"$W/bin/gh" <<SH
#!/usr/bin/env bash
[ -f "$W/gh.fail" ] && exit 1
sha=""
while [ \$# -gt 0 ]; do [ "\$1" = --commit ] && sha=\$2; shift; done
echo "\$sha" >>"$W/gh.log"
if [ -f "$W/gh/\$sha.json" ]; then cat "$W/gh/\$sha.json"; else echo '[]'; fi
SH
# model stub: records the switch + state dir it was handed; writes last-run.json when model.report exists.
cat >"$W/model" <<SH
#!/usr/bin/env bash
echo "ran AC2_AUTOPILOT=\$AC2_AUTOPILOT STATE=\$AC2_AUTOPILOT_STATE lock-fd9=\$([ -e /proc/self/fd/9 ] && echo open || echo closed)" >>"$W/model.log"
[ -f "$W/model.report" ] && cp "$W/model.report" "\$AC2_AUTOPILOT_STATE/last-run.json"
[ -f "$W/model.rc" ] && exit "\$(cat "$W/model.rc")"
exit 0
SH
chmod +x "$W/bin/br" "$W/bin/gh" "$W/model"
export PATH="$W/bin:$PATH" AC2_BR_CMD="$W/bin/br" AUTOPILOT_GATE_MODEL="$W/model" AUTOPILOT_GATE_STATE="$W/state"

setup() {
  rm -rf "$W/repo" "$W/origin.git" "$W/state" "$W/gh" "$W/br.log" "$W"/model.* "$W"/list.* "$W"/ready.* "$W"/gh.* "$W/holder"
  mkdir -p "$W/repo/.claude" "$W/gh"
  git init -q --bare -b main "$W/origin.git"
  git -C "$W/repo" init -q -b main
  git -C "$W/repo" remote add origin "$W/origin.git"
  git "${GITENV[@]}" -C "$W/repo" commit -q --allow-empty -m init
  git -C "$W/repo" push -q origin main
  git -C "$W/repo" remote set-head origin main >/dev/null
  printf '%s\n' "$BLOCK" >"$W/repo/.claude/factory.json"
  echo '[]' >"$W/list.json"; echo '[]' >"$W/ready.json"
}
gate() { (cd "$W/repo" && bash "$GATE" "$@" >"$W/gate.out" 2>&1); echo $?; }
last() { tail -n1 "$W/state/ledger.jsonl" 2>/dev/null; }
lines() { wc -l <"$W/state/ledger.jsonl" 2>/dev/null || echo 0; }
ran() { grep -c '^ran' "$W/model.log" 2>/dev/null || echo 0; }
iso_ago() { date -u -d "$1 ago" +%FT%TZ; }
issue() {  # issue <id> <priority> <labels-json>
  printf '{"id":"%s","issue_type":"task","priority":%s,"created_at":"2026-01-01","labels":%s,"status":"open","assignee":"","title":"work %s"}' "$1" "$2" "$3" "$1"
}

# 1. usage
setup
rc=$(gate --nope); [ "$rc" = 64 ] && ok || bad "unknown argument is usage (got $rc)"
rc=$(gate --verdict); [ "$rc" = 64 ] && ok || bad "--verdict without days is usage (got $rc)"
rc=$(gate --verdict abc); [ "$rc" = 64 ] && ok || bad "--verdict with a non-number is usage (got $rc)"

# 2. no work → exit 0, no model, one no-work line
setup
rc=$(gate)
[ "$rc" = 0 ] && ok || bad "no work exits 0 (got $rc)"
[ "$(ran)" = 0 ] && ok || bad "no work starts no model"
[ "$(lines)" = 1 ] && jq -e '.outcome == "no-work" and .closed == 0' <<<"$(last)" >/dev/null && ok || bad "no work appends one {closed:0} no-work line: $(last)"

# 3. work from a ready bead → the model runs once with the switch and state dir; last-run merged
setup
echo "[$(issue a 1 '["refined"]')]" >"$W/ready.json"
printf '{"closed":3,"polished":2,"pushed":["abc123"],"protected":1}' >"$W/model.report"
rc=$(gate)
[ "$rc" = 0 ] && ok || bad "a handled run exits 0 (got $rc): $(cat "$W/gate.out")"
[ "$(ran)" = 1 ] && ok || bad "work starts the model exactly once ($(ran))"
grep -q "AC2_AUTOPILOT=1 STATE=$W/state" "$W/model.log" && ok || bad "the session gets AC2_AUTOPILOT=1 and AC2_AUTOPILOT_STATE: $(cat "$W/model.log" 2>/dev/null)"
grep -q 'lock-fd9=closed' "$W/model.log" && ok || bad "the session does not inherit the gate's lock descriptor"
jq -e '.outcome == "ran" and .exit == 0 and .closed == 3 and .polished == 2 and .protected == 1
       and .pushed == ["abc123"] and (.start | length > 0) and (.end | length > 0) and (.base | length == 40)' \
  <<<"$(last)" >/dev/null && ok || bad "the ledger line carries last-run.json plus start/end/exit/base: $(last)"

# 3b. the DEFAULT session (no test seam) is headless with permissions bypassed, opus, on scheduled.md
setup
cat >"$W/bin/claude" <<SH
#!/usr/bin/env bash
echo "\$*" >"$W/claude.args"
cp "$W/model.report" "\$AC2_AUTOPILOT_STATE/last-run.json"
SH
chmod +x "$W/bin/claude"
echo "[$(issue a 1 '["refined"]')]" >"$W/ready.json"; printf '{"closed":0}' >"$W/model.report"
rc=$(cd "$W/repo" && env -u AUTOPILOT_GATE_MODEL bash "$GATE" >"$W/gate.out" 2>&1; echo $?)
[ "$rc" = 0 ] && ok || bad "the default session runs and is handled (rc=$rc): $(cat "$W/gate.out")"
grep -q -- '^-p --dangerously-skip-permissions --model opus Execute .*workflows/scheduled.md now$' "$W/claude.args" \
  && ok || bad "the default session is claude -p --dangerously-skip-permissions --model opus: $(cat "$W/claude.args" 2>/dev/null)"
rm -f "$W/bin/claude"

# 4. work from an unrefined bead at or above the cap; above the cap or human-gated is no work
setup
echo "[$(issue u 1 '["unrefined"]')]" >"$W/list.json"; printf '{"closed":0}' >"$W/model.report"
rc=$(gate); [ "$rc" = 0 ] && [ "$(ran)" = 1 ] && ok || bad "an unrefined P1 is work (rc=$rc ran=$(ran)): $(cat "$W/gate.out")"
grep -q '^list .*--label unrefined .*--priority 0-1 ' "$W/br.log" && ok || bad "the unrefined count is capped at the block's max_priority: $(cat "$W/br.log")"
setup
echo "[$(issue u 1 '["unrefined","human-gate"]')]" >"$W/list.json"
rc=$(gate); [ "$rc" = 0 ] && [ "$(ran)" = 0 ] && ok || bad "a human-gated unrefined bead is not work"

# 5. a stale last-run.json is never reused; a session that writes no report is a failure
setup
echo "[$(issue a 1 '["refined"]')]" >"$W/ready.json"
mkdir -p "$W/state"; printf '{"closed":9}' >"$W/state/last-run.json"
rc=$(gate)
[ "$rc" = 1 ] && ok || bad "a session that wrote no report exits 1 (got $rc)"
jq -e '.closed == 0 and .report == "missing"' <<<"$(last)" >/dev/null && ok || bad "stale last-run.json was reused: $(last)"

# 6. the session failing is a failure, and the ledger records its exit
setup
echo "[$(issue a 1 '["refined"]')]" >"$W/ready.json"; echo 3 >"$W/model.rc"
printf '{"closed":1}' >"$W/model.report"
rc=$(gate)
[ "$rc" = 1 ] && ok || bad "a failed session exits 1 (got $rc)"
jq -e '.exit == 3 and .outcome == "ran"' <<<"$(last)" >/dev/null && ok || bad "the ledger records the session exit: $(last)"

# 7. lock held → exit 0, no model, a lock-held line
setup
echo "[$(issue a 1 '["refined"]')]" >"$W/ready.json"; mkdir -p "$W/state"
flock "$W/state/lock" sleep 8 & HOLDER=$!
sleep 1
rc=$(gate)
[ "$rc" = 0 ] && ok || bad "lock held exits 0 (got $rc)"
[ "$(ran)" = 0 ] && ok || bad "lock held starts no model"
jq -e '.outcome == "lock-held" and .closed == 0' <<<"$(last)" >/dev/null && ok || bad "lock held appends a {closed:0} line: $(last)"
kill "$HOLDER" 2>/dev/null; wait "$HOLDER" 2>/dev/null

# 8. disabled → exit 0, no model
setup
echo "[$(issue a 1 '["refined"]')]" >"$W/ready.json"
printf '%s\n' '{"autopilot":{"enabled":false,"max_priority":1,"protect":"^supabase/"}}' >"$W/repo/.claude/factory.json"
rc=$(gate)
[ "$rc" = 0 ] && [ "$(ran)" = 0 ] && ok || bad "disabled exits 0 without a model (rc=$rc ran=$(ran))"
jq -e '.outcome == "disabled"' <<<"$(last)" >/dev/null && ok || bad "disabled is recorded: $(last)"
rm -f "$W/repo/.claude/factory.json"
rc=$(gate)
[ "$rc" = 2 ] && [ "$(ran)" = 0 ] && ok || bad "no factory.json under the switch is NOT-GATED, never a run (rc=$rc)"

# 9. misconfigured block → exit 2 NOT-GATED, no model
setup
echo "[$(issue a 1 '["refined"]')]" >"$W/ready.json"
printf '%s\n' '{"autopilot":{"enabled":true,"max_priority":1,"protect":"^supabase/(["}}' >"$W/repo/.claude/factory.json"
rc=$(gate)
[ "$rc" = 2 ] && [ "$(ran)" = 0 ] && ok || bad "a malformed block exits 2 without a model (rc=$rc)"
grep -q 'NOT-GATED' "$W/gate.out" && ok || bad "NOT-GATED is named: $(cat "$W/gate.out")"
jq -e '.outcome == "not-gated"' <<<"$(last)" >/dev/null && ok || bad "not-gated is recorded: $(last)"

# 10. wrong branch → exit 0, no model
setup
echo "[$(issue a 1 '["refined"]')]" >"$W/ready.json"
git -C "$W/repo" checkout -q -b topic
rc=$(gate)
[ "$rc" = 0 ] && [ "$(ran)" = 0 ] && ok || bad "a topic branch exits 0 without a model (rc=$rc ran=$(ran))"
jq -e '.outcome == "wrong-branch"' <<<"$(last)" >/dev/null && ok || bad "wrong-branch is recorded: $(last)"

# 11. a failed br read is a failure, never "no work"
setup
: >"$W/list.fail"
rc=$(gate)
[ "$rc" = 1 ] && [ "$(ran)" = 0 ] && ok || bad "a failed br list exits 1, never no-work (rc=$rc)"
jq -e '.outcome == "br-failed"' <<<"$(last)" >/dev/null && ok || bad "br-failed is recorded: $(last)"

# 12. --verdict: a fixture ledger, real commits, stubbed gh
verdict_repo() {
  setup
  mkdir -p "$W/repo/.github/workflows" "$W/repo/.beads" "$W/repo/src" "$W/state"
  cat >"$W/repo/.github/workflows/ci.yml" <<'YML'
name: CI
on:
  push:
    branches: [main]
    # Skipped only when EVERY changed path is bookkeeping.
    paths-ignore:
      - '.beads/**'
      - '_plans/**'
permissions:
  contents: read
YML
  git "${GITENV[@]}" -C "$W/repo" add .github && git "${GITENV[@]}" -C "$W/repo" commit -q -m "add ci"
  BASE=$(git -C "$W/repo" rev-parse HEAD)
  echo code >"$W/repo/src/a.ts"; echo '{"id":"x"}' >"$W/repo/.beads/issues.jsonl"
  git "${GITENV[@]}" -C "$W/repo" add src .beads && git "${GITENV[@]}" -C "$W/repo" commit -q -m "code"
  CODE=$(git -C "$W/repo" rev-parse HEAD)
  echo '{"id":"y"}' >"$W/repo/.beads/issues.jsonl"
  git "${GITENV[@]}" -C "$W/repo" add .beads && git "${GITENV[@]}" -C "$W/repo" commit -q -m "ledger"
  LEDGERONLY=$(git -C "$W/repo" rev-parse HEAD)
}
green() { printf '[{"status":"completed","conclusion":"success"}]' >"$W/gh/$1.json"; }
red()   { printf '[{"status":"completed","conclusion":"failure"}]' >"$W/gh/$1.json"; }
row()   { jq -nc --arg ts "$1" --argjson closed "$2" --arg base "$3" --argjson pushed "$4" '{ts:$ts,outcome:"ran",closed:$closed,base:$base,pushed:$pushed}'; }

# PASS: 6+5 closes, the code push green, the ledger-only push (no run) not counted
verdict_repo
{ row "$(iso_ago 3days)" 6 "$BASE" "[\"$LEDGERONLY\"]"; row "$(iso_ago 1day)" 5 "$LEDGERONLY" "[\"$LEDGERONLY\"]"; } >"$W/state/ledger.jsonl"
green "$LEDGERONLY"
out=$(cd "$W/repo" && bash "$GATE" --verdict 14 2>&1); rc=$?
[ "$rc" = 0 ] && [ "$(tail -n1 <<<"$out")" = "PASS closes=11 red=0" ] && ok || bad "verdict PASS (rc=$rc): $out"
# the second row's push (base == head) is bookkeeping-only; it must not be asked of gh
[ "$(grep -c "^$LEDGERONLY$" "$W/gh.log")" = 1 ] && ok || bad "a bookkeeping-only push is not looked up in CI: $(cat "$W/gh.log")"

# FAIL: a triggering push with a red run
verdict_repo
row "$(iso_ago 1day)" 12 "$BASE" "[\"$LEDGERONLY\"]" >"$W/state/ledger.jsonl"
red "$LEDGERONLY"
out=$(cd "$W/repo" && bash "$GATE" --verdict 14 2>&1); rc=$?
[ "$rc" = 1 ] && [ "$(tail -n1 <<<"$out")" = "FAIL closes=12 red=1" ] && ok || bad "verdict FAIL on a red CI run (rc=$rc): $out"

# FAIL: a triggering push with no CI run at all
verdict_repo
row "$(iso_ago 1day)" 12 "$BASE" "[\"$LEDGERONLY\"]" >"$W/state/ledger.jsonl"
out=$(cd "$W/repo" && bash "$GATE" --verdict 14 2>&1); rc=$?
[ "$rc" = 1 ] && [ "$(tail -n1 <<<"$out")" = "FAIL closes=12 red=1" ] && ok || bad "verdict FAIL when a triggering push has no run (rc=$rc): $out"

# FAIL: too few closes in the window (an old row outside it does not count)
verdict_repo
{ row "$(iso_ago 40days)" 50 "$BASE" '[]'; row "$(iso_ago 1day)" 9 "$BASE" '[]'; } >"$W/state/ledger.jsonl"
out=$(cd "$W/repo" && bash "$GATE" --verdict 14 2>&1); rc=$?
[ "$rc" = 1 ] && [ "$(tail -n1 <<<"$out")" = "FAIL closes=9 red=0" ] && ok || bad "verdict FAIL on 9 closes in the window (rc=$rc): $out"
out=$(cd "$W/repo" && bash "$GATE" --verdict 60 2>&1); rc=$?
[ "$rc" = 0 ] && [ "$(tail -n1 <<<"$out")" = "PASS closes=59 red=0" ] && ok || bad "a wider window counts the old row (rc=$rc): $out"

# NOT-GATED: no ledger, and gh failing, are UNKNOWN (2), never a PASS or FAIL
verdict_repo; rm -rf "$W/state"
out=$(cd "$W/repo" && bash "$GATE" --verdict 14 2>&1); rc=$?
[ "$rc" = 2 ] && ok || bad "verdict with no ledger is exit 2 (got $rc): $out"
verdict_repo
row "$(iso_ago 1day)" 12 "$BASE" "[\"$LEDGERONLY\"]" >"$W/state/ledger.jsonl"; : >"$W/gh.fail"
out=$(cd "$W/repo" && bash "$GATE" --verdict 14 2>&1); rc=$?
[ "$rc" = 2 ] && ok || bad "verdict with gh failing is exit 2 (got $rc): $out"

echo "$PASS passed, $FAIL failed"
[ "$PASS" -gt 0 ] && [ "$FAIL" = 0 ]
