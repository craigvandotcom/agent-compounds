#!/usr/bin/env bash
# scripts/stance-spawn.test.sh — the live probe that every stance can SPAWN and WRITE
# SCRATCH on every harness that carries subagents.
#
# The lint proves the stance files are well formed; nothing else proves a stance runs.
# A stance breaks at the harness boundary — a permission mode that denies the write, a
# tool list the provider rejects — and that is invisible to any check that reads files.
#
#   PROBE: per harness, a cheap parent session spawns each stance in agents/*.md with
#          one instruction: write `ok` to a scratch file OUTSIDE the repo (the scratch
#          home the stances name), then reply `done`. The verdict is the file, never
#          the reply. A harness whose CLI is absent is a skipped leg; a run in which
#          every leg skipped exits 77.
#
#   --if-changed   run only when the stance files, this probe, or a harness CLI version
#                  changed since the last GREEN run; the stamp is written on green only,
#                  so a red probe re-runs until it is fixed. This is the form sync.sh calls.
#
# Not probed: codex — no spawn recipe has been verified against a logged-in codex.
# The probe says so on every run rather than carrying an untested leg.
#
# ASSURANCE
#   PROBE:    bash scripts/stance-spawn.test.sh
#   SCHEDULE: engine/sync.sh (--if-changed, every non-dry sync) + scripts/run-all-proofs.sh
#             (self-skips 77 where no harness CLI exists, e.g. CI)
#   MODE:     advisory in sync.sh (warns, never blocks a sync); blocking in run-all-proofs
#   ON-FAILURE: open
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SPAWN_TIMEOUT="${STANCE_PROBE_TIMEOUT:-300}"
STAMP_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/agent-compounds/stance-spawn.stamp"

IF_CHANGED=0
[ "${1:-}" = "--if-changed" ] && IF_CHANGED=1

STANCES=()
for f in "$ROOT"/agents/*.md; do
  [ -f "$f" ] && STANCES+=("$(basename "$f" .md)")
done
[ "${#STANCES[@]}" -gt 0 ] || { echo "  FAIL  no stance files under agents/"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

fingerprint() {
  {
    cat "$ROOT"/agents/*.md "${BASH_SOURCE[0]}"
    have claude   && claude --version 2>/dev/null
    have opencode && opencode --version 2>/dev/null
  } | sha256sum | cut -d' ' -f1
}

if [ "$IF_CHANGED" = 1 ] && [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE")" = "$(fingerprint)" ]; then
  echo "  stance-spawn: unchanged since the last green probe"
  exit 0
fi

fails=0 legs_run=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/stance-probe.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT

child_prompt() { # <file>
  printf "This is a spawn probe. As a scratch file, write the single word ok to %s, then reply with the single word done." "$1"
}

# The parent runs in the harness's default permission mode, so it cannot make the write
# itself on claude; on opencode the parent can, so that leg also demands the spawn marker.
spawn_claude() { # <stance> <file> <log>
  printf "Use the Agent tool with subagent_type '%s' and this exact prompt: '%s' Then report the subagent's reply verbatim and nothing else." \
    "$1" "$(child_prompt "$2")" \
    | (cd "$ROOT" && timeout "$SPAWN_TIMEOUT" claude -p --model haiku) >"$3" 2>&1
}
spawn_opencode() { # <stance> <file> <log>
  (cd "$ROOT" && timeout "$SPAWN_TIMEOUT" opencode run --agent build \
    "Use the task tool to spawn the '$1' subagent with this exact prompt: '$(child_prompt "$2")' Then report its reply verbatim and nothing else.") >"$3" 2>&1
}

run_leg() { # <harness>
  local h="$1" s
  if ! have "$h"; then echo "  skip  $h: CLI not installed"; return; fi
  legs_run=$((legs_run + 1))
  for s in "${STANCES[@]}"; do
    "spawn_$h" "$s" "$WORK/$h-$s.txt" "$WORK/$h-$s.log" &
  done
  wait
  for s in "${STANCES[@]}"; do
    if ! grep -qx 'ok' "$WORK/$h-$s.txt" 2>/dev/null; then
      bad "$h/$s: no scratch file written — $(tail -n 1 "$WORK/$h-$s.log" 2>/dev/null)"
    elif [ "$h" = opencode ] && ! grep -qi "$s agent" "$WORK/$h-$s.log"; then
      bad "$h/$s: file written, but no '$s' subagent appears in the transcript"
    else
      ok "$h/$s spawned and wrote scratch"
    fi
  done
}

run_leg claude
run_leg opencode
echo "  note  codex: NOT PROBED (no verified spawn recipe)"

if [ "$legs_run" = 0 ]; then
  echo "  SKIP  no harness CLI on this runner — nothing was probed"
  exit 77
fi
if [ "$fails" -gt 0 ]; then
  echo "  stance-spawn: $fails failure(s)"
  exit 1
fi
mkdir -p "$(dirname "$STAMP_FILE")" && fingerprint > "$STAMP_FILE"
echo "  stance-spawn: every stance spawned and wrote scratch on $legs_run harness(es)"
