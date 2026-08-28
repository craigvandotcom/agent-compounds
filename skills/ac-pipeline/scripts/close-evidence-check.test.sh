#!/usr/bin/env bash
# close-evidence-check.test.sh — proof harness for close-evidence-check.sh (ac-on0y.2).
#
# Mirrors beads-closed-gate.test.sh's pattern: a data-driven mock `br` on PATH, so the
# harness runs anywhere (no board, no br binary, no network) — CI included.
#
# It also carries the SEAM-PROOF case: the gate is worthless if the single live call site
# in ac-implement is silently reverted, so this harness greps that call site and goes RED
# when the invocation is missing. The script breaking and the wiring vanishing are two
# different failures; only checking the first is how orphaned gates are born (see
# beads-closed-gate.sh, which is fully tested and has ZERO live callers).
#
# Exit 0 = all cases pass.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/close-evidence-check.sh"
AC_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# Phase-4 cutover (2026-08-28): ac-implement is archived. The gate's live call site is
# now ac2-implement/scripts/close-gate.sh, which sets EVIDENCE_CORE and invokes it in
# LEG 7. The seam-proof follows the wiring rather than retiring with the old skill.
IMPLEMENT="$AC_ROOT/skills/ac2-implement/scripts/close-gate.sh"
CASES=0
FAILURES=0

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/close-evidence.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

MOCK_BIN="$WORKDIR/bin"
FIXTURE_DIR="$WORKDIR/fixtures"
mkdir -p "$MOCK_BIN" "$FIXTURE_DIR"
export FIXTURE_DIR

# Data-driven mock `br`: `br show --json <id>` emits $FIXTURE_DIR/<id>.json, or nothing
# at all for an unknown id (mirroring an unresolvable lookup, which must be NOT-CHECKED).
cat >"$MOCK_BIN/br" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "show" ]; then
  shift
  id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) shift ;;
      -*) shift ;;
      *) [ -z "$id" ] && id="$1"; shift ;;
    esac
  done
  fx="${FIXTURE_DIR:-}/$id.json"
  [ -f "$fx" ] && cat "$fx"
  exit 0
fi
exit 0
EOF
chmod +x "$MOCK_BIN/br"

# bead <id> <issue_type> <labels-json> <description>
bead() {
  jq -n --arg id "$1" --arg t "$2" --arg d "$4" --argjson l "$3" \
    '{id:$id, issue_type:$t, status:"in_progress", labels:$l, description:$d}' \
    > "$FIXTURE_DIR/$1.json"
}

run_gate() { # <expected exit> <label> -- <gate args...>
  local want="$1" label="$2"; shift 3
  CASES=$((CASES + 1))
  local out rc
  out=$(env "PATH=$MOCK_BIN:$PATH" bash "$GATE" "$@" 2>&1); rc=$?
  if [ "$rc" = "$want" ]; then
    printf '  PASS  %s\n' "$label"
  else
    printf '  FAIL  %s (wanted exit %s, got %s)\n' "$label" "$want" "$rc"
    printf '%s\n' "$out" | sed 's/^/          | /'
    FAILURES=$((FAILURES + 1))
  fi
}

expect() { # <1|0> <label>
  CASES=$((CASES + 1))
  if [ "$1" = 1 ]; then printf '  PASS  %s\n' "$2"
  else printf '  FAIL  %s\n' "$2"; FAILURES=$((FAILURES + 1)); fi
}

DELIVERS_TASK='## Intent
whatever
## Delivers
- script: skills/ac-pipeline/scripts/thing.sh
- doc: skills/beads-standards/reference/bead-conventions.md
## Consumes
- none'

bead bd-bug     bug         '[]'             'a bug'
bead bd-task    task        '[]'             "$DELIVERS_TASK"
bead bd-prose   task        '[]'             '## Delivers
- the team understands the thing better
## Consumes
- none'
bead bd-nodel   task        '[]'             '## Intent
no delivers section at all'
bead bd-epic    epic        '[]'             'an epic'
bead bd-gated   task        '["human-gate"]' "$DELIVERS_TASK"
bead bd-inv     investigation '[]'           'an investigation'

echo "--- bug: the regression test, or an equivalent recorded probe ---"
run_gate 1 "bug closed with no evidence -> REFUSE" -- bd-bug "fixed it"
run_gate 0 "bug citing a test path -> PASS" -- bd-bug "fixed; regression test skills/x/y.test.sh passes"
run_gate 0 "bug closed obsolete -> PASS (no fix, so no regression test)" -- bd-bug "obsolete: wrong channel, machinery not product"
run_gate 0 "bug closed duplicate -> PASS" -- bd-bug "duplicate: bd-ye0rp shipped at f066ee8"
run_gate 0 "doc bug with recorded grep before/after -> PASS" -- bd-bug "fixed: grep -c 'foo' -> 0 (was 2 at 8fc9e36)"
run_gate 1 "bare mention of grep with no before/after -> REFUSE" -- bd-bug "fixed, you can grep it"

echo "--- task/feature: cross-reference this bead's own ## Delivers ---"
run_gate 0 "task naming a declared artifact -> PASS" -- bd-task "shipped. Delivered: skills/ac-pipeline/scripts/thing.sh"
run_gate 0 "task naming it by basename -> PASS" -- bd-task "shipped: thing.sh landed"
run_gate 1 "task naming NO declared artifact -> REFUSE" -- bd-task "shipped: some other file"
run_gate 2 "task whose Delivers is prose only -> NOT-CHECKED" -- bd-prose "shipped: everything"
run_gate 2 "task with no Delivers section -> NOT-CHECKED" -- bd-nodel "shipped: everything"

echo "--- exemptions ---"
run_gate 0 "epic -> EXEMPT" -- bd-epic "closing the epic"
run_gate 0 "human-gate bead -> EXEMPT" -- bd-gated "human ruled"

echo "--- investigation ---"
run_gate 0 "investigation citing a spawned bead id -> PASS" -- bd-inv "answered; spawned ac-1227"
run_gate 0 "investigation citing a documented answer -> PASS" -- bd-inv "written up in docs/findings.md"
run_gate 1 "investigation with neither -> REFUSE" -- bd-inv "looked into it, all good"

echo "--- the bypass must be BOTH the flag and the record ---"
run_gate 1 "EVIDENCE-BYPASS without --force -> REFUSE" -- bd-task "shipped EVIDENCE-BYPASS: outage"
run_gate 0 "EVIDENCE-BYPASS with --force -> PASS" -- --force bd-task "shipped EVIDENCE-BYPASS: outage"
run_gate 1 "--force with no EVIDENCE-BYPASS in the reason -> REFUSE" -- --force bd-task "shipped"

echo "--- a gate that verified nothing is never a pass ---"
run_gate 2 "unresolvable bead -> NOT-CHECKED" -- bd-does-not-exist "shipped"
run_gate 2 "missing close reason -> NOT-CHECKED" -- bd-task
run_gate 0 "--report-only exits 0 even when it would refuse" -- --report-only bd-task "shipped: nothing declared"

echo "--- seam-proof: the single live call site must still invoke the gate ---"
# A gate whose wiring is silently reverted fails NOTHING. This case is the sensor for that.
if grep -q 'close-evidence-check\.sh' "$IMPLEMENT"; then
  expect 1 "ac2-implement/scripts/close-gate.sh invokes close-evidence-check.sh"
else
  expect 0 "ac2-implement/scripts/close-gate.sh invokes close-evidence-check.sh (MISSING — the gate is orphaned)"
fi

# ...and the same assertion must go RED on a copy with the invocation removed, or it is
# not actually sensing anything.
REVERTED="$WORKDIR/close-gate-reverted.sh"
grep -v 'close-evidence-check\.sh' "$IMPLEMENT" > "$REVERTED"
if grep -q 'close-evidence-check\.sh' "$REVERTED"; then
  expect 0 "the call-site assertion goes RED when the invocation is removed"
else
  expect 1 "the call-site assertion goes RED when the invocation is removed"
fi

echo ""
echo "close-evidence-check.test: ${CASES} cases, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
