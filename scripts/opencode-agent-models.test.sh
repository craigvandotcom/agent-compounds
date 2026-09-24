#!/usr/bin/env bash
# scripts/opencode-agent-models.test.sh — the probe that each generated opencode stance
# carries exactly what harnesses.opencode.agent_models says for it.
#
# agent_models resolves a stance by its own name, then its tier. A model id is stamped
# as `model:`; the value "inherit" omits the line, so the stance runs on the model of
# the primary agent that invoked it. Any mix is valid.
#
#   PROBE: render into a TEMP home via `sync.sh --root --opencode-home <dir>` (as
#          opencode-dispatcher.test.sh does), then compare each stance's model line
#          with the live config. No real opencode home is touched.
#
# ASSURANCE
#   PROBE:    bash scripts/opencode-agent-models.test.sh
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

command -v jq >/dev/null 2>&1 || { echo "HARNESS FAIL: jq not on PATH"; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home"
bash "$SYNC" --root --opencode-home "$WORK/home" >/dev/null 2>&1

CFG="$ROOT/harnesses.json"
[ -f "$ROOT/harnesses.local.json" ] && CFG_JSON="$(jq -s '.[0] * .[1]' "$CFG" "$ROOT/harnesses.local.json")" || CFG_JSON="$(cat "$CFG")"

for name in orchestrator coordinator researcher implementer validator; do
  f="$WORK/home/agents/$name.md"
  [ -f "$f" ] || { bad "$name.md not generated"; continue; }
  tier="$(awk '/^---/{c++; next} c==1 && /^tier:/{print $2; exit}' "$ROOT/agents/$name.md")"
  want="$(printf '%s' "$CFG_JSON" | jq -r --arg a "$name" --arg t "$tier" \
    '.harnesses.opencode.agent_models | .[$a] // .[$t] // empty')"
  got="$(awk '/^---/{c++; next} c==1 && /^model:/{print $2; exit}' "$f")"
  if [ "$want" = inherit ]; then
    [ -z "$got" ] && ok "$name ($tier): inherit -> no model line" || bad "$name: want inherit, got model: $got"
  else
    [ "$got" = "$want" ] && ok "$name ($tier): model: $want" || bad "$name: want model: $want, got '$got'"
  fi
done

echo
[ "$fails" -eq 0 ] && { echo "OK: generated opencode stances match agent_models"; exit 0; }
echo "FAILURES: $fails — generated opencode stances drift from agent_models"; exit 1
