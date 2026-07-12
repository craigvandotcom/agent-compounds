#!/usr/bin/env bash
# beads-closed-gate.test.sh — fixture-based unit tests for beads-closed-gate.sh
#
# TRUNK-DIRECT REWRITE (bd-u2lo1.7): the gate no longer parses commit
# trailers or wave labels — scope is `br list --assignee <conductor>
# --limit 0 --all`, filtered to status != closed and excluding
# post-merge-labelled beads. These fixtures assert: (1) the assignee is
# correctly threaded through to `br list --assignee` (from $1, or from
# $AGENT_NAME when $1 is empty), (2) post-merge-labelled beads never block,
# (3) exit codes 0 (clear) / 1 (blocked) / 2 (no assignee determinable) are
# correct.
#
# No shell-test framework exists in this repo (bats/shellspec/shunit) — this
# is a self-contained assert harness. Run directly:
#   bash .claude/skills/_shared/scripts/beads-closed-gate.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="$SCRIPT_DIR/beads-closed-gate.sh"

FAILURES=0
pass() { echo "  PASS: $1"; }
fail() {
  echo "  FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

# --- Fixture git repo (only needed for the bleed-check's git plumbing) ---
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

git -C "$WORKDIR" init -q -b main
git -C "$WORKDIR" config user.email "test@test.local"
git -C "$WORKDIR" config user.name "test"
mkdir -p "$WORKDIR/.beads"
echo '[]' >"$WORKDIR/.beads/issues.jsonl"
git -C "$WORKDIR" add .beads/issues.jsonl
git -C "$WORKDIR" commit -q -m "chore: init"

MOCK_BIN="$WORKDIR/bin"
mkdir -p "$MOCK_BIN"

# Writes a mock `br` that only returns the fixture bead when queried with
# `--assignee "$expect_assignee"` (proves the gate threads the right
# assignee through to `br list`) — any other assignee value gets an empty
# result, simulating the real server-side filter.
#   $1 = the assignee value the mock expects to be queried with
#   $2 = status of the fixture bead (open|closed)
#   $3 = "post-merge" to also carry the post-merge label (optional)
write_mock_br() {
  local expect_assignee="$1" fixture_status="$2" extra_label="${3:-}"
  local labels="\"infra\""
  if [ "$extra_label" = "post-merge" ]; then
    labels="\"infra\",\"post-merge\""
  fi
  cat >"$MOCK_BIN/br" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "list" ]; then
  shift
  assignee=""
  while [ \$# -gt 0 ]; do
    case "\$1" in
      --assignee) assignee="\$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ "\$assignee" = "$expect_assignee" ]; then
    cat <<JSON
{"issues":[{"id":"bd-fixture01","status":"$fixture_status","labels":[$labels]}]}
JSON
  else
    echo '{"issues":[]}'
  fi
fi
EOF
  chmod +x "$MOCK_BIN/br"
}

# $1 (optional) = explicit assignee arg to the gate ("" = omit)
# $2 (optional) = AGENT_NAME env value ("" = unset)
run_gate() {
  local explicit="${1:-}" env_agent="${2:-}"
  ( cd "$WORKDIR" && PATH="$MOCK_BIN:$PATH" AGENT_NAME="$env_agent" bash "$GATE_SCRIPT" "$explicit" )
}

# --- Case A: AGENT_NAME-env-sourced assignee, own bead CLOSED ------------
write_mock_br "ConductorA" "closed"
OUT=$(run_gate "" "ConductorA" 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case A: AGENT_NAME-sourced assignee, own bead closed -> gate exits 0"
else
  fail "Case A: expected exit 0, got exit $RC. Output: $OUT"
fi

# --- Case B: own bead OPEN -> blocked ------------------------------------
write_mock_br "ConductorA" "open"
OUT=$(run_gate "" "ConductorA" 2>&1)
RC=$?
if [ "$RC" -eq 1 ]; then
  pass "Case B: own bead open -> gate exits 1 (blocked)"
else
  fail "Case B: expected exit 1, got exit $RC. Output: $OUT"
fi

# --- Case C: explicit $1 assignee overrides/threads independent of AGENT_NAME env ---
write_mock_br "ConductorB" "open"
OUT=$(run_gate "ConductorB" "SomeOtherAgent" 2>&1)
RC=$?
if [ "$RC" -eq 1 ]; then
  pass "Case C: explicit \$1 assignee threads through to br list -> gate exits 1"
else
  fail "Case C: expected exit 1, got exit $RC. Output: $OUT"
fi

# --- Case D: post-merge label excludes an open bead -> gate exits 0 -----
write_mock_br "ConductorA" "open" "post-merge"
OUT=$(run_gate "" "ConductorA" 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case D: post-merge-labelled open bead excluded -> gate exits 0"
else
  fail "Case D: expected exit 0, got exit $RC. Output: $OUT"
fi

# --- Case E: no assignee determinable (no $1, no AGENT_NAME) -> exit 2 --
write_mock_br "ConductorA" "open"
OUT=$(run_gate "" "" 2>&1)
RC=$?
if [ "$RC" -eq 2 ]; then
  pass "Case E: no assignee available -> gate exits 2"
else
  fail "Case E: expected exit 2, got exit $RC. Output: $OUT"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All beads-closed-gate.sh fixture tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
