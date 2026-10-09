#!/usr/bin/env bash
# pick.test.sh — proof harness for pick.sh against a stub br (no beads DB needed).
# Invariants: the filter and order hold, burned ids are skipped, the prod-write gate routes,
# an epic is the terminal pick, empty is DRY — and a failed read is NEVER DRY.
# Runs under bash and zsh:  bash <this> && zsh <this>       Exit 0 = all cases pass.

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
# The harness never inherits a live autopilot session's switch: the autopilot cases set it
# per run, every other case runs with it unset.
unset AC2_AUTOPILOT
PICK="$SELF_DIR/pick.sh"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p "$W/bin"
export FIX="$W/fix" AC2_BR_CMD="$W/bin/br"
export PATH="$W/bin:$PATH"
PASS=0; FAIL=0

# The DECISION-edge leg now shells through bead.py, which calls `br` itself (subprocess,
# resolved on PATH — never $AC2_BR_CMD). This one stub answers both routes: pick's own
# `br_call` (honors AC2_BR_CMD) and bead.py's `_run_br` (PATH lookup only).
cat > "$AC2_BR_CMD" <<'STUB'
#!/usr/bin/env bash
case $1 in
  ready) [ -f "$FIX/ready.fail" ] && { echo '{"error":{"message":"database locked"}}'; exit 1; }
         [ -f "$FIX/ready.envelope" ] && { echo '{"error":{"message":"schema mismatch"}}'; exit 0; }
         cat "$FIX/ready.json" ;;
  show)  shift
         id=""
         for a in "$@"; do case "$a" in --json) ;; *) id="$a" ;; esac; done
         [ -f "$FIX/show.fail" ] && exit 1
         cat "$FIX/show-$id.json" ;;
  *)     exit 9 ;;
esac
STUB
chmod +x "$AC2_BR_CMD"

reset() { rm -rf "$FIX"; mkdir -p "$FIX"; }
bead() {  # bead <id> <type> <priority> <created> <labels-json> [assignee] [title]
  printf '{"id":"%s","issue_type":"%s","priority":%s,"created_at":"%s","labels":%s,"status":"open","assignee":"%s","title":"%s"}' \
    "$1" "$2" "$3" "$4" "$5" "${6-}" "${7:-work $1}"
}
ready() { local IFS=,; printf '[%s]' "$*" > "$FIX/ready.json"; }
show() {  # show <id> <edge-id> <edge-title> <edge-status> <edge-type>
  # Writes two fixtures: the SUBJECT bead's own edge (id + axis only — bead.py's canonical
  # dependency dict drops title/status on purpose) and the edge TARGET's own show (title +
  # status), since bead.py re-reads each blocking id to check its title/closed state.
  printf '[{"id":"%s","dependencies":[{"id":"%s","dependency_type":"%s"}]}]' \
    "$1" "$2" "${5:-blocks}" > "$FIX/show-$1.json"
  printf '[{"id":"%s","title":"%s","status":"%s"}]' "$2" "$3" "$4" > "$FIX/show-$2.json"
}
check() {  # check <name> <expected-stdout> <expected-exit> [pick args…]
  local name=$1 want=$2 wrc=$3; shift 3
  got=$(bash "$PICK" "$@" 2>"$W/err"); rc=$?
  if [ "$got" = "$want" ] && [ "$rc" = "$wrc" ]; then PASS=$((PASS + 1))
  else FAIL=$((FAIL + 1)); echo "FAIL $name: got '$got' rc=$rc, want '$want' rc=$wrc"; fi
}
check_err() {  # check_err <name> <grep-pattern> — asserts on the last run's stderr
  if grep -q "$2" "$W/err"; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL $1: stderr lacks '$2'"; fi
}

R='["refined"]'
# 1 — filter + order: a bug outranks older/higher-priority tasks; every ineligible shape is dropped.
reset
ready "$(bead t-old task 1 2026-01-01 "$R")" \
      "$(bead b-new bug 3 2026-09-01 "$R")" \
      "$(bead x-unref task 0 2025-01-01 '["refined","unrefined"]')" \
      "$(bead x-gate task 0 2025-01-01 '["refined","human-gate"]')" \
      "$(bead x-device task 0 2025-01-01 '["refined","device"]')" \
      "$(bead x-cond task 0 2025-01-01 '["refined","conductor"]')" \
      "$(bead x-dec decision 0 2025-01-01 "$R")" \
      "$(bead x-other task 0 2025-01-01 "$R" someone-else)" \
      "$(bead x-pf task 0 2025-01-01 "$R" '' 'PREMISE-FAILED: STALE-STAMP work')"
check "bug first, ineligible dropped" b-new 0
# 2 — burned ids are skipped; then priority beats age.
check "burned skipped" t-old 0 --burned "b-new"
check "all burned is DRY" DRY 1 --burned "b-new t-old"
# 3 — a bead assigned to the actor is eligible.
check "own assignment eligible" x-other 0 --actor someone-else --burned "b-new t-old"
check "count respects filter" 2 0 --count

# 4 — prod-write gate: closed DECISION edge → eligible; open → GATED; none → MALFORMED.
reset
SP='["refined","sensitive-prod"]'
ready "$(bead p-ok task 0 2026-01-01 "$SP")" "$(bead p-open task 0 2026-01-02 "$SP")" \
      "$(bead p-none task 0 2026-01-03 "$SP")" "$(bead plain task 1 2026-01-04 "$R")"
show p-ok   d1 "DECISION: ship it"  closed blocks
show p-open d2 "DECISION: ship it?" open   blocks
show p-none e1 epic                 open   parent-child
check "closed decision edge proceeds" p-ok 0
check "open decision edge is skipped" plain 0 --burned p-ok
check_err "GATED reported" "^GATED p-open$"
check_err "MALFORMED reported" "^MALFORMED p-none: no DECISION blocks edge$"
check "count excludes gated + malformed" 2 0 --count

# 5 — an epic sorts last and is the terminal pick.
reset
ready "$(bead ep epic 0 2025-01-01 "$R")" "$(bead child task 4 2026-09-01 "$R")"
check "child before epic" child 0
check "epic is terminal pick" "EPIC ep" 0 --burned child

# 6 — empty is DRY.
reset; ready
check "empty is DRY" DRY 1
check "empty count is 0" 0 0 --count

# 7 — a failed read is never DRY.
reset; ready "$(bead a task 0 2026-01-01 "$R")"; : > "$FIX/ready.fail"
check "br ready failure is NOT-GATED" "" 2
check_err "failure named" "NOT-GATED"
check_err "failure tells the worker what to do next (NEXT: handback)" "NEXT: handback"
check "count on failure is NOT-GATED" "" 2 --count
reset; ready "$(bead a task 0 2026-01-01 "$R")"; : > "$FIX/ready.envelope"
check "rc-0 error envelope is NOT-GATED" "" 2
reset; ready "$(bead p task 0 2026-01-01 '["refined","sensitive-prod"]')"; : > "$FIX/show.fail"
check "br show failure is NOT-GATED" "" 2
check_err "br show failure tells the worker what to do next (NEXT: handback)" "NEXT: handback"

# 8 — autopilot (AC2_AUTOPILOT=1 + the project's factory.json block, read through autopilot.sh):
# priority above max_priority and beads delivering a protected path are excluded, in pick AND
# in --count. Every case below runs from inside a throwaway project that owns the block.
P="$W/proj"; mkdir -p "$P/.claude"; git init -q "$P"
factory() { printf '%s\n' "$1" > "$P/.claude/factory.json"; }
BLOCK='{"autopilot":{"enabled":true,"max_priority":1,"protect":"^supabase/|\\.sql$"}}'
dbead() {  # dbead <id> <priority> <created> <delivers-path>… — a refined task with a ## Delivers section
  local id=$1 prio=$2 created=$3; shift 3
  local desc="## Intent\nx\n\n## Delivers" p
  for p in "$@"; do desc="$desc\n- file: $p"; done
  jq -nc --arg id "$id" --argjson prio "$prio" --arg created "$created" --arg desc "$(printf '%b' "$desc")" \
    '{id:$id,issue_type:"task",priority:$prio,created_at:$created,labels:["refined"],status:"open",assignee:"",title:("work "+$id),description:$desc}'
}
reset
ready "$(dbead prot 0 2025-01-01 supabase/migrations/1.sql)" \
      "$(dbead over 2 2025-01-02 skills/over.sh)" \
      "$(dbead mixed 0 2025-01-03 skills/ok.sh db/q.sql)" \
      "$(dbead fine 1 2026-01-01 skills/fine.sh)" \
      "$(bead nodesc task 1 2026-01-02 "$R")"
factory "$BLOCK"
cd "$P" || exit 1
# inactive path: byte-identical behaviour — the switch unset, or the block disabled, picks the
# oldest P0 even though it is protected and counts every bead.
check "inactive (switch unset): the protected P0 is still picked" prot 0
check "inactive (switch unset): count sees every bead" 5 0 --count
AC2_AUTOPILOT=1 check "autopilot: protected + over-cap beads are skipped" fine 0
check_err "PROTECTED reported, not silently dropped" "^PROTECTED prot$"
check_err "a bead with one protected path among several is reported" "^PROTECTED mixed$"
AC2_AUTOPILOT=1 check "autopilot: over-cap bead is never picked" nodesc 0 --burned "fine"
AC2_AUTOPILOT=1 check "autopilot: nothing eligible is DRY" DRY 1 --burned "fine nodesc"
AC2_AUTOPILOT=1 check "autopilot: --count agrees with what workers can take" 2 0 --count
factory '{"autopilot":{"enabled":false,"max_priority":1,"protect":"^supabase/"}}'
AC2_AUTOPILOT=1 check "autopilot block disabled: the protected P0 is still picked" prot 0
AC2_AUTOPILOT=1 check "autopilot block disabled: count unchanged" 5 0 --count
factory '{"ship":{}}'
AC2_AUTOPILOT=1 check "no autopilot block: behaviour unchanged" prot 0
# a misconfigured block is NOT-GATED, never a pick and never DRY
factory '{"autopilot":{"enabled":true,"max_priority":1,"protect":"^supabase/(["}}'
AC2_AUTOPILOT=1 check "malformed protect ERE is NOT-GATED" "" 2
check_err "NOT-GATED named" "NOT-GATED"
check_err "NOT-GATED tells the worker what to do next (NEXT: handback)" "NEXT: handback"
AC2_AUTOPILOT=1 check "malformed protect ERE: --count is NOT-GATED" "" 2 --count
factory '{"autopilot":{"enabled":true,"protect":"^supabase/"}}'
AC2_AUTOPILOT=1 check "missing max_priority is NOT-GATED" "" 2
# --count agrees with a drain: pick, burn, repeat until DRY
factory "$BLOCK"
burned=""; picks=0
while :; do
  got=$(AC2_AUTOPILOT=1 bash "$PICK" --burned "$burned" 2>/dev/null) || break
  burned="$burned $got"; picks=$((picks + 1))
done
want=$(AC2_AUTOPILOT=1 bash "$PICK" --count 2>/dev/null)
if [ "$picks" = "$want" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL drain vs --count: drained $picks, counted $want"; fi
cd "$SELF_DIR" || exit 1

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = 0 ]
