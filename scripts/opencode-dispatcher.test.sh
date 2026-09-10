#!/usr/bin/env bash
# scripts/opencode-dispatcher.test.sh — the probe for the opencode dispatcher render
# and its fail-closed wiring load (ac-heyt.12, decision D-1).
#
# opencode observation (ac-heyt.12, A2, 2026-09-10, worker PinkBay): renamed the live
# ~/.config/opencode/ac-hooks.wiring.json and ran one bash tool call in a RUNNING
# opencode session. The call succeeded and the session's hooks kept working — the
# dispatcher caches the wiring at plugin LOAD, so a mid-session rename is invisible to
# the running session. The fail-closed BLOCK therefore engages at SESSION START, not
# mid-flight: a fresh session with an absent/corrupt wiring gets `ac-hooks: wiring
# unreadable at <path> — run harness-sync.sh` on every dispatched tool call, which the
# node driver below proves against the rendered plugin directly. Whether opencode
# surfaces the thrown BLOCK message to the model in a fresh session is the pending
# follow-up (a fresh-session live check); the render-time assert on every sync is the
# standing sensor meanwhile.
#
#   PROBE: render the opencode dispatcher + wiring into a TEMP home via
#          `harness-sync.sh --root --opencode-home <dir>`, then drive the rendered
#          plugins/ac-hooks.js with node against a PRESENT, an ABSENT and a CORRUPT
#          wiring file. The absent and corrupt states must BLOCK every dispatched tool
#          call with the `ac-hooks: wiring unreadable at` message; the present state
#          must not block. No real opencode home is ever touched.
#
# ASSURANCE
#   PROBE:    bash scripts/opencode-dispatcher.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SYNC="$ROOT/harness-sync.sh"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
HOME_DIR="$WORK/home"
DRIVER="$WORK/drive.mjs"

[ -f "$SYNC" ] || { echo "HARNESS FAIL: missing $SYNC"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "HARNESS FAIL: node not on PATH — the dispatcher cannot be driven"; exit 77; }
# The render asserts every rendered command path exists under the literal
# $HOME/Repos/... install layout (harness-sync render_hooks_opencode). A machine
# without that layout — CI's /home/runner — cannot render, so the precondition is
# unavailable there (exit 77 self-skip, counted loudly by run-all-harnesses.sh).
[ -d "$HOME/Repos" ] || { echo "SKIP: no \$HOME/Repos layout — the opencode render asserts \$HOME/Repos hook paths (precondition unavailable)"; exit 77; }

cat > "$DRIVER" <<'EOF'
// Drive the rendered plugin's tool-call gate for one wiring state; print RESULT.
const mod = await import(process.argv[2])
const handlers = await mod.server({ directory: process.cwd() })
try {
  await handlers["tool.execute.before"]({ tool: "bash", sessionID: "t1" }, { args: {} })
  console.log("RESULT: no-block")
} catch (e) {
  console.log("RESULT: BLOCKED: " + e.message)
}
EOF

# Render into the temp home (the real opencode home is never touched). The home dir
# must exist first — harness-sync skips a missing opencode home by design.
mkdir -p "$HOME_DIR"
bash "$SYNC" --root --opencode-home "$HOME_DIR" >/dev/null 2>&1
[ -f "$HOME_DIR/ac-hooks.wiring.json" ] || { echo "HARNESS FAIL: render produced no wiring"; exit 1; }
[ -f "$HOME_DIR/plugins/ac-hooks.js" ] || { echo "HARNESS FAIL: render produced no dispatcher"; exit 1; }

DRIVE="node $DRIVER file://$HOME_DIR/plugins/ac-hooks.js"

# PRESENT: hooks wired -> a plain bash call must NOT be blocked.
OUT="$($DRIVE 2>&1 | grep -E '^RESULT' || true)"
case "$OUT" in
  *no-block*) ok "present wiring: plain tool call passes (no block)" ;;
  *) bad "present wiring: expected no-block, got: $OUT" ;;
esac

# ABSENT: the wiring vanishes -> every dispatched call BLOCKS with the repair message.
rm "$HOME_DIR/ac-hooks.wiring.json"
OUT="$($DRIVE 2>&1 | grep -E '^RESULT' || true)"
case "$OUT" in
  *"BLOCKED: ac-hooks: wiring unreadable at"*) ok "absent wiring: tool call blocked with the unreadable message" ;;
  *) bad "absent wiring: expected BLOCKED message, got: $OUT" ;;
esac

# CORRUPT: unparseable wiring -> same fail-closed block.
printf 'not json{{{\n' > "$HOME_DIR/ac-hooks.wiring.json"
OUT="$($DRIVE 2>&1 | grep -E '^RESULT' || true)"
case "$OUT" in
  *"BLOCKED: ac-hooks: wiring unreadable at"*) ok "corrupt wiring: tool call blocked with the unreadable message" ;;
  *) bad "corrupt wiring: expected BLOCKED message, got: $OUT" ;;
esac

echo
if [ "$fails" -eq 0 ]; then
  echo "OK: every opencode-dispatcher case passed ($(basename "$0"))"
  exit 0
else
  echo "FAILURES: $fails — the dispatcher behaves outside its contract ($(basename "$0"))"
  exit 1
fi