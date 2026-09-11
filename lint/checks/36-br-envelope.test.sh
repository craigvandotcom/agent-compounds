#!/usr/bin/env bash
# 36-br-envelope.test.sh — the fixture proving Check 36's contract.
#
#   PROBE: a raw `br … --json` read is RED; a routed-only tree (no raw reads) is
#           GREEN once it carries >= 13 routed call sites; a routed-only tree under
#           the 13-site floor is RED (the vacuous-detector floor — a scan that lost
#           its subject must refuse, never report a clean board it never examined);
#           a tree with no scripts at all is NOT-GATED (exit 2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/36-br-envelope.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/36-br-envelope.py"
FIXTURE="$(cd "$HERE/../fixtures/36-br-envelope" && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
OUT="$WORK/out"

# The check must exist — a missing check makes every case below vacuous.
if [ ! -f "$CHECK" ]; then
  echo "HARNESS FAIL: missing $CHECK"
  exit 1
fi

run_check() { # <tree-dir> -> exit code
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

# Build a tree with N routed call sites (one `br_call … --json` line per file).
routed_tree() { # <dir> <n>
  local d="$1" n="$2" i
  mkdir -p "$d/skills/_tools"
  for i in $(seq 1 "$n"); do
    printf '#!/usr/bin/env bash\n# shellcheck source=br-call.sh\n. "$(dirname "${BASH_SOURCE[0]}")/br-call.sh"\ndata=$(br_call show ac-demo-%s --json) || exit 2\n' "$i" \
      > "$d/skills/_tools/consumer-$i.sh"
  done
}

# --- RED: the fixture carries a raw caller ------------------------------------
rc=$(run_check "$FIXTURE")
[ "$rc" -eq 1 ] && grep -q 'raw br --json read' "$OUT" && grep -q 'raw-caller.sh' "$OUT" \
  && ok "the fixture's raw read is RED and names the caller" \
  || bad "fixture: rc=$rc out=$(cat "$OUT")"

# --- RED: backslash-newline continuation evasion (ac-ia8g) --------------------
# Distinct marker from sibling ac-1jkr's windowed-context cases.
mkdir -p "$WORK/evasion-cont/skills/_tools"
printf '#!/usr/bin/env bash\ndata=$(br \\\n  list --json --limit 0)\n' \
  > "$WORK/evasion-cont/skills/_tools/cont.sh"
rc=$(run_check "$WORK/evasion-cont")
[ "$rc" -eq 1 ] && grep -q 'raw br --json read' "$OUT" \
  && ok "backslash-newline continuation evasion is RED" \
  || bad "evasion-cont: rc=$rc out=$(cat "$OUT")"

# --- RED: quoted-binary evasion (ac-ia8g) -------------------------------------
mkdir -p "$WORK/evasion-quoted/skills/_tools"
printf 'data=$("br" list --json --limit 0)\n' \
  > "$WORK/evasion-quoted/skills/_tools/q.sh"
rc=$(run_check "$WORK/evasion-quoted")
[ "$rc" -eq 1 ] && grep -q 'raw br --json read' "$OUT" \
  && ok "quoted-binary evasion is RED" \
  || bad "evasion-quoted: rc=$rc out=$(cat "$OUT")"

# --- RED: a routed-only tree under the floor refuses, never a clean pass --------
routed_tree "$WORK/floor" 5
rc=$(run_check "$WORK/floor")
[ "$rc" -eq 1 ] && grep -q 'floor' "$OUT" \
  && ok "fewer than thirteen routed sites is RED (vacuous-detector floor)" \
  || bad "floor: rc=$rc out=$(cat "$OUT")"

# --- GREEN: thirteen routed sites, no raw read ---------------------------------
routed_tree "$WORK/green" 13
rc=$(run_check "$WORK/green")
[ "$rc" -eq 0 ] && grep -q 'routed call site' "$OUT" \
  && ok "thirteen routed sites with no raw read is GREEN" \
  || bad "green: rc=$rc out=$(cat "$OUT")"

# --- NOT-GATED: no scripts at all ----------------------------------------------
mkdir -p "$WORK/empty"
rc=$(run_check "$WORK/empty")
[ "$rc" -eq 2 ] && grep -q 'NOT-CHECKED' "$OUT" \
  && ok "a tree with no scripts is NOT-GATED (exit 2), never a pass" \
  || bad "empty: rc=$rc out=$(cat "$OUT")"

# --- RED: a raw read split across lines, no backslash (ac-1jkr) -----------------
# Marker: split — sibling ac-ia8g owns quote/continuation fixtures.
mkdir -p "$WORK/split/skills/_tools"
printf '#!/usr/bin/env bash\ndata=$(br list\n  --json --limit 0)\n' \
  > "$WORK/split/skills/_tools/split.sh"
rc=$(run_check "$WORK/split")
[ "$rc" -eq 1 ] && grep -q 'raw br --json read' "$OUT" && grep -q 'split.sh' "$OUT" \
  && ok "a br/--json split across lines is RED (windowed match)" \
  || bad "split: rc=$rc out=$(cat "$OUT")"

# --- GREEN: a split br_call still counts toward the routed floor ----------------
routed_tree "$WORK/routed-split" 12
printf '#!/usr/bin/env bash\ndata=$(br_call show ac-demo\n  --json) || exit 2\n' \
  > "$WORK/routed-split/skills/_tools/consumer-split.sh"
rc=$(run_check "$WORK/routed-split")
[ "$rc" -eq 0 ] && grep -q 'routed call site' "$OUT" \
  && ok "a split br_call still counts toward the routed floor" \
  || bad "routed-split: rc=$rc out=$(cat "$OUT")"

echo
if [ "$fails" -eq 0 ]; then
  echo "OK: every 36-br-envelope case passed ($(basename "$0"))"
  exit 0
else
  echo "FAILURES: $fails — 36-br-envelope behaves outside its contract ($(basename "$0"))"
  exit 1
fi