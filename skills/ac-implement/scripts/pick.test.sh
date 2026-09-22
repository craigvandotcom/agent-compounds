#!/usr/bin/env bash
# pick.test.sh — proof harness for pick.sh against a stub br (no beads DB needed).
# Invariants: the filter and order hold, burned ids are skipped, the prod-write gate routes,
# an epic is the terminal pick, empty is DRY — and a failed read is NEVER DRY.
# Runs under bash and zsh:  bash <this> && zsh <this>       Exit 0 = all cases pass.

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
PICK="$SELF_DIR/pick.sh"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
export FIX="$W/fix" AC2_BR_CMD="$W/br"
PASS=0; FAIL=0

cat > "$AC2_BR_CMD" <<'STUB'
#!/usr/bin/env bash
case $1 in
  ready) [ -f "$FIX/ready.fail" ] && { echo '{"error":{"message":"database locked"}}'; exit 1; }
         [ -f "$FIX/ready.envelope" ] && { echo '{"error":{"message":"schema mismatch"}}'; exit 0; }
         cat "$FIX/ready.json" ;;
  show)  [ -f "$FIX/show.fail" ] && exit 1
         cat "$FIX/show-$2.json" ;;
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
show() {  # show <id> <deps-json>
  printf '[{"id":"%s","dependencies":%s}]' "$1" "$2" > "$FIX/show-$1.json"
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
show p-ok   '[{"id":"d1","title":"DECISION: ship it","status":"closed","dependency_type":"blocks"}]'
show p-open '[{"id":"d2","title":"DECISION: ship it?","status":"open","dependency_type":"blocks"}]'
show p-none '[{"id":"e1","title":"epic","status":"open","dependency_type":"parent-child"}]'
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
check "count on failure is NOT-GATED" "" 2 --count
reset; ready "$(bead a task 0 2026-01-01 "$R")"; : > "$FIX/ready.envelope"
check "rc-0 error envelope is NOT-GATED" "" 2
reset; ready "$(bead p task 0 2026-01-01 '["refined","sensitive-prod"]')"; : > "$FIX/show.fail"
check "br show failure is NOT-GATED" "" 2

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = 0 ]
