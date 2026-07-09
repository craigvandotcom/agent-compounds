#!/usr/bin/env bash
# beads-closed-gate.test.sh — fixture-based unit tests for beads-closed-gate.sh
# (bd-h1tyu named check: "unit test with a fixture board containing both
# wave and non-wave open beads" — asserts the gate passes when the branch's
# OWN bead is closed even with unrelated open beads on the board, and fails
# only when the branch's own bead is still open).
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

# --- Fixture git repo ---------------------------------------------------
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

git -C "$WORKDIR" init -q -b main
git -C "$WORKDIR" config user.email "test@test.local"
git -C "$WORKDIR" config user.name "test"
echo "init" >"$WORKDIR/file.txt"
git -C "$WORKDIR" add file.txt
git -C "$WORKDIR" commit -q -m "chore: init"

git -C "$WORKDIR" checkout -q -b bug/bd-fixture01-test
echo "change" >>"$WORKDIR/file.txt"
git -C "$WORKDIR" add file.txt
git -C "$WORKDIR" commit -q -m "fix(test): fixture fix

Bead: bd-fixture01"

# --- Mock \`br\` (fixture board: this branch's own bead + 2 unrelated open
#     beads elsewhere on the board, simulating the healthy-busy-board case
#     that deadlocked the old board-wide gate) -----------------------------
MOCK_BIN="$WORKDIR/bin"
mkdir -p "$MOCK_BIN"

write_mock_br() {
  # $1 = status of bd-fixture01 (open|closed) — the branch's OWN bead.
  local fixture_status="$1"
  cat >"$MOCK_BIN/br" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "list" ]; then
  cat <<JSON
{"issues":[
  {"id":"bd-fixture01","status":"$fixture_status","labels":["infra"]},
  {"id":"bd-unrelated1","status":"open","labels":["backlog"]},
  {"id":"bd-unrelated2","status":"open","labels":["backlog","refined"]}
]}
JSON
fi
EOF
  chmod +x "$MOCK_BIN/br"
}

run_gate() {
  ( cd "$WORKDIR" && PATH="$MOCK_BIN:$PATH" bash "$GATE_SCRIPT" )
}

# --- Case A: branch's own bead CLOSED, unrelated board beads OPEN -------
# Old board-wide behavior would exit 1 here (2 unrelated open beads exist).
# Correct wave-scoped behavior: exit 0 — this branch's own work is done.
write_mock_br "closed"
OUT=$(run_gate 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Case A: own bead closed + unrelated open beads on board -> gate exits 0"
else
  fail "Case A: expected exit 0, got exit $RC. Output: $OUT"
fi

# --- Case B: branch's own bead OPEN, unrelated board beads OPEN ---------
# Correct behavior: exit 1 — this branch's own work is not done.
write_mock_br "open"
OUT=$(run_gate 2>&1)
RC=$?
if [ "$RC" -eq 1 ]; then
  pass "Case B: own bead open -> gate exits 1 (blocked)"
else
  fail "Case B: expected exit 1, got exit $RC. Output: $OUT"
fi

# --- Case C: explicit wave-label mode, label bead OPEN, unrelated OPEN --
# Reuses the same fixture board but scopes via label instead of commits.
MOCK_BIN_LABEL="$WORKDIR/bin-label"
mkdir -p "$MOCK_BIN_LABEL"
cat >"$MOCK_BIN_LABEL/br" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "list" ]; then
  cat <<'JSON'
{"issues":[
  {"id":"bd-waveitem1","status":"open","labels":["wave-999"]},
  {"id":"bd-unrelated1","status":"open","labels":["backlog"]}
]}
JSON
fi
EOF
chmod +x "$MOCK_BIN_LABEL/br"
OUT=$(cd "$WORKDIR" && PATH="$MOCK_BIN_LABEL:$PATH" bash "$GATE_SCRIPT" "wave-999" 2>&1)
RC=$?
if [ "$RC" -eq 1 ]; then
  pass "Case C: explicit wave-label mode scopes to labelled bead -> gate exits 1"
else
  fail "Case C: expected exit 1, got exit $RC. Output: $OUT"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All beads-closed-gate.sh fixture tests passed."
  exit 0
else
  echo "$FAILURES fixture test(s) FAILED."
  exit 1
fi
