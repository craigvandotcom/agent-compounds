#!/usr/bin/env bash
# scripts/opencode-edit-perm.test.sh — the OpenCode edit projection keys on Edit,
# not on Write (ac-oqfe).
#
# OpenCode's edit permission covers write, edit, and patch as one key, and its
# path rules cannot name $TMPDIR or $CLAUDE_JOB_DIR. Validator lists Write and
# withholds Edit; that must project as edit=deny. A stance that lists Edit
# still projects as edit=allow. The function under test is the one engine/sync.sh
# actually calls, via --print-opencode-edit-perm, not a reimplementation.
#
# ASSURANCE
#   PROBE:    bash scripts/opencode-edit-perm.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SYNC="$ROOT/engine/sync.sh"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

[ -f "$SYNC" ] || { echo "HARNESS FAIL: missing $SYNC"; exit 1; }

if grep -qF "grep -qE 'Write|Edit'" "$SYNC"; then
  bad "engine/sync.sh still derives edit from the Write-or-Edit alternation"
else
  ok "the Write-or-Edit alternation is gone from engine/sync.sh"
fi

if grep -qF 'Decision (ac-oqfe):' "$SYNC"; then
  ok "the derivation records the ac-oqfe decision"
else
  bad "engine/sync.sh does not record the ac-oqfe decision"
fi

perm_for() { # <agent.md or tools-line> — ask the real sync.sh decision
  local line="$1"
  if [ -f "$1" ]; then
    line="$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^tools:/{print; exit}' "$1")"
  fi
  bash "$SYNC" --print-opencode-edit-perm "$line"
}

expect() { # <label> <want> <got>
  if [ "$2" = "$3" ]; then ok "$1 -> $3"; else bad "$1: want $2, got $3"; fi
}

expect "validator (Write, no Edit)" deny "$(perm_for "$ROOT/agents/validator.md")"
expect "implementer (lists Edit)" allow "$(perm_for "$ROOT/agents/implementer.md")"
expect "researcher (lists Edit)" allow "$(perm_for "$ROOT/agents/researcher.md")"
expect "coordinator (lists Edit)" allow "$(perm_for "$ROOT/agents/coordinator.md")"
expect "orchestrator (lists Edit)" allow "$(perm_for "$ROOT/agents/orchestrator.md")"
expect "Write alone" deny "$(perm_for 'tools: Read, Write')"
expect "Edited is not Edit" deny "$(perm_for 'tools: Read, Edited')"
expect "Edit as its own tool" allow "$(perm_for 'tools: Read, Edit, Bash')"
expect "empty tools line" deny "$(perm_for '')"

echo
if [ "$fails" -eq 0 ]; then
  echo "OK: every opencode-edit-perm case passed ($(basename "$0"))"
  exit 0
else
  echo "FAILURES: $fails — OpenCode edit permission is outside its contract ($(basename "$0"))"
  exit 1
fi
