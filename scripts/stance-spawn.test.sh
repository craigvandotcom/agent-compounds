#!/usr/bin/env bash
# scripts/stance-spawn.test.sh — the live probe that every stance can SPAWN and WRITE
# SCRATCH on every harness that carries subagents.
#
# The lint proves the stance files are well formed; nothing else proves a stance runs.
# A stance breaks at the harness boundary — a permission mode that denies the write, a
# tool list the provider rejects — and that is invisible to any check that reads files.
#
#   PROBE: per harness, a cheap parent session spawns each stance in agents/*.md with
#          one instruction: write `ok` to a scratch file INSIDE the repo working
#          directory, then reply `done`. The verdict is the file, never the reply.
#          Scratch used to sit under /tmp. Claude's sandbox refuses that write, so
#          every claude stance failed the same boundary and the probe never measured
#          spawn (ac-7ysx). A harness whose CLI is absent is a skipped leg; a run in
#          which every leg skipped exits 77.
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
#             (self-skips 77 where no harness CLI exists, e.g. CI) + the nightly pai job
#             "Sofi - Stance Spawn Probe" (full run, 02:15; red fails the systemd unit)
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
FAILS=()
bad() { echo "  FAIL  $1"; FAILS+=("  FAIL  $1"); fails=$((fails + 1)); }

# Inside the working directory, not /tmp: the claude harness sandbox allows the
# repo and refuses /tmp. `_scratch/` is the scratch home the stances name; sync.sh
# keeps it gitignored in every target. The trap removes this run's directory.
mkdir -p "$ROOT/_scratch"
WORK="$(mktemp -d "$ROOT/_scratch/stance-probe.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT

child_prompt() { # <stance> <file>
  if [ "$1" = coordinator ]; then
    printf "This is a spawn probe. Judge whether the single word ok is an adequate marker, then write either the single word adequate or the single word inadequate to %s, then reply with the single word done." "$2"
  else
    printf "This is a spawn probe. As a scratch file, write the single word ok to %s, then reply with the single word done." "$2"
  fi
}

scratch_valid() { # <stance> <file>
  if [ "$1" = coordinator ]; then
    grep -Eq '^(adequate|inadequate)$' "$2" 2>/dev/null
  else
    grep -qx 'ok' "$2" 2>/dev/null
  fi
}

# The parent runs in the harness's default permission mode, so it cannot make the write
# itself on claude; on opencode the parent can, so that leg also demands the spawn marker.
spawn_claude() { # <stance> <file> <log>
  printf "Use the Agent tool with subagent_type '%s' and this exact prompt: '%s' Then report the subagent's reply verbatim and nothing else." \
    "$1" "$(child_prompt "$1" "$2")" \
    | (cd "$ROOT" && timeout "$SPAWN_TIMEOUT" claude -p --model haiku) >"$3" 2>&1
}
spawn_opencode() { # <stance> <file> <log>
  (cd "$ROOT" && timeout "$SPAWN_TIMEOUT" opencode run --agent build \
    "Use the task tool to spawn the '$1' subagent with this exact prompt: '$(child_prompt "$1" "$2")' Then report its reply verbatim and nothing else.") >"$3" 2>&1
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
    if ! scratch_valid "$s" "$WORK/$h-$s.txt"; then
      bad "$h/$s: no scratch file written — $(tail -n 1 "$WORK/$h-$s.log" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
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
  echo "  SKIP  no harness CLI on this runner — nothing was probed" >&2
  exit 77
fi
if [ "$fails" -gt 0 ]; then
  echo "  stance-spawn: $fails failure(s)"
  # the scheduler journals only stderr on a failed job — repeat the verdict there
  { printf '%s\n' "${FAILS[@]}"; echo "  stance-spawn: $fails failure(s)"; } >&2
  exit 1
fi
mkdir -p "$(dirname "$STAMP_FILE")" && fingerprint > "$STAMP_FILE"
echo "  stance-spawn: every stance spawned and wrote scratch on $legs_run harness(es)"
