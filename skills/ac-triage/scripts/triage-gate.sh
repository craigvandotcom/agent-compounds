#!/usr/bin/env bash
# triage-gate.sh — the hourly ac-triage gate. Runs every declared source fetch in plain shell;
# starts the model ONLY when a source returns an item the gate has not handed off before.
#
# Sources are declared by the app, never named here: the first ```triage-gate fence in
# .claude/skills/CORE/triage.md, one source per line —
#
#     <name> <timeout-seconds> <command…>
#
# A source command prints one `<key>\t<summary>` line per current item (key = stable
# fingerprint) and exits 0 or 1 when it checked; any other exit, or its timeout, is
# COULD-NOT-CHECK with the first stderr line as the reason. Sources run in declared order.
#
# Rules:
#   - An item is new when its key is absent from the source's seen-set. A key that leaves the
#     source is pruned, so a recurrence is new again.
#   - Keys join the seen-set only after the model run that consumes them exits 0 AND its report
#     commit is on origin/<default>: the gate records the remote tip before the run, fetches
#     after it, and requires a commit in that range touching .compounds/state/triage-last-run.md
#     (scheduled-daily.md step 3 writes it on every run). A zero exit alone only means the
#     session ended. A run that exits 0 without landing is a failed run; an origin the gate
#     cannot reach cannot prove a landing, so it fails closed (the model is not started).
#     Either way the keys resurface next run.
#   - A could-not-check source upserts ONE open ops bead (marker `triage-gate:source-down:<name>`):
#     created once, commented at most every TRIAGE_GATE_COMMENT_EVERY_H hours, closed on
#     recovery. It never starts the model and never touches the seen-set.
#   - Every run rewrites $STATE/heartbeat.json — its age is the gate's proof of life.
#
# Usage:  triage-gate.sh [--no-escalate] [--seed | --status]
#           --no-escalate  dry run: print new items; no model, no ops bead, nothing marked seen
#           --seed         baseline: mark every current item seen; no model, no ops bead
#           --status       one line from heartbeat.json (`triage: ✓ 7m ago` · `⚠ silent 3h` · down
#                          sources), nothing when the repo declares no gate; reads only, exits 0
# Env:    TRIAGE_GATE_CONFIG (default .claude/skills/CORE/triage.md)
#         TRIAGE_GATE_STATE  (default ${XDG_STATE_HOME:-~/.local/state}/ac-triage/<repo>)
#         TRIAGE_GATE_MODEL  command run as `$TRIAGE_GATE_MODEL <items-file>` (default: claude -p
#                            on workflows/scheduled-daily.md at TRIAGE_GATE_MODEL_NAME, sonnet)
#         TRIAGE_GATE_COMMENT_EVERY_H (default 24) · AC2_BR_CMD (default br)
#         TRIAGE_GATE_STALE_H (default 2) — --status calls a heartbeat older than this silent
# Exit:   0  every source handled (clean · escalated and landed · down with its ops bead current)
#         1  the model run failed or landed nothing on origin — its items stay unseen and
#            resurface next run
#         2  a down source could not be recorded on its ops bead (br failed); wins over 1
#         3  skipped — another gate run holds the lock
#         64 usage or config error

NO_ESCALATE=0; SEED=0; STATUS=0
for a in "$@"; do
  case "$a" in
    --no-escalate) NO_ESCALATE=1 ;;
    --seed) SEED=1 ;;
    --status) STATUS=1 ;;
    *) echo "usage: triage-gate.sh [--no-escalate] [--seed | --status]" >&2; exit 64 ;;
  esac
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "triage-gate: not in a git repo" >&2; exit 64; }
cd "$ROOT" || exit 64
CONFIG="${TRIAGE_GATE_CONFIG:-$ROOT/.claude/skills/CORE/triage.md}"
STATE="${TRIAGE_GATE_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/ac-triage/$(basename "$ROOT")}"
BR="${AC2_BR_CMD:-br}"
TOOLS="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../_tools" && pwd)"
REPORT=".compounds/state/triage-last-run.md"
EVERY_H="${TRIAGE_GATE_COMMENT_EVERY_H:-24}"
WORKFLOW=".claude/skills/ac-triage/workflows/scheduled-daily.md"

if [ "$STATUS" = 1 ]; then  # proof of life for the board — never takes the lock, never writes
  grep -q '^```triage-gate$' "$CONFIG" 2>/dev/null || exit 0
  HB="$STATE/heartbeat.json"
  [ -f "$HB" ] || { echo "triage: ⚠ never ran"; exit 0; }
  jq -r --argjson now "$(date -u +%s)" --argjson stale "${TRIAGE_GATE_STALE_H:-2}" '
    (($now - (.ts | fromdateiso8601)) / 60 | floor) as $m
    | (if $m < 60 then "\($m)m" else "\($m / 60 | floor)h" end) as $age
    | [.sources[]? | select(test("✗")) | split(":")[0]] as $down
    | "triage: "
      + (if $m > $stale * 60 then "⚠ silent \($age)"
         elif .exit != 0 then "⚠ last run exit \(.exit) · \($age) ago"
         else "✓ \($age) ago" end)
      + (if ($down | length) > 0 then " · down: " + ($down | join(", ")) else "" end)
  ' "$HB" 2>/dev/null || echo "triage: ⚠ unreadable heartbeat"
  exit 0
fi
. "$TOOLS/br-call.sh" || exit 64
command -v flock >/dev/null || { echo "triage-gate: flock not found" >&2; exit 64; }
mkdir -p "$STATE/seen" "$STATE/down" || exit 64

exec 9>"$STATE/lock"
flock -n 9 || { echo "triage-gate: another run holds $STATE/lock — skipped"; exit 3; }

SOURCES=$(awk '/^```triage-gate$/{f=1;next} f&&/^```$/{exit} f&&NF&&$1!~/^#/' "$CONFIG" 2>/dev/null)
[ -n "$SOURCES" ] || { echo "triage-gate: no \`\`\`triage-gate fence in $CONFIG" >&2; exit 64; }

now() { date -u +%s; }
default_model() {
  claude -p --dangerously-skip-permissions --model "${TRIAGE_GATE_MODEL_NAME:-sonnet}" \
    "Execute $WORKFLOW now in gate mode. Gate items file: $1 — triage ONLY these items; the fetch already ran."
}
open_down_bead() {  # open_down_bead <name> — id of the open ops bead for this source, if any
  local out
  out=$(br_call list --desc-contains "triage-gate:source-down:$1" --json 2>/dev/null) || return 1
  jq -er 'if type=="object" then .issues else . end | [.[].id] | first // ""' <<<"$out"
}

upsert_down() {  # upsert_down <name> <reason> — non-zero when br failed
  local name=$1 reason=$2 id last
  id=$(open_down_bead "$name") || return 1
  if [ -z "$id" ]; then
    "$BR" create --title "ops: triage source $name could-not-check" --type task --priority 1 \
      --labels origin:ac-triage,ops \
      --description "Triage source \`$name\` could not be checked: $reason. It is configured but failing — neither a finding nor a clean pass. triage-gate:source-down:$name" \
      >/dev/null || return 1
  else
    last=$(cat "$STATE/down/$name" 2>/dev/null || echo 0)
    [ $(( $(now) - last )) -ge $(( EVERY_H * 3600 )) ] || return 0
    "$BR" comments add "$id" --content "Still could-not-check at $(date -u +%FT%TZ): $reason" >/dev/null || return 1
  fi
  now >"$STATE/down/$name"
}

recovered() {  # recovered <name> — close the open ops bead, then forget the outage
  local id
  id=$(open_down_bead "$1")
  [ -n "$id" ] && "$BR" close "$id" --reason "obsolete: triage source $1 recovered at $(date -u +%FT%TZ) — it checks again; nothing left to do." >/dev/null
  rm -f "$STATE/down/$1"
}

RUN=$(mktemp -d); trap 'rm -rf "$RUN"' EXIT
PENDING="$STATE/pending.tsv"; : >"$RUN/new"
EXIT=0; SUMMARY=()
say() { SUMMARY+=("$1"); echo "$1"; }

while read -r name secs cmd <&3; do
  timeout "$secs" bash -c "$cmd" </dev/null >"$RUN/out" 2>"$RUN/err" 9>&-; rc=$?
  if [ "$rc" -gt 1 ]; then
    if [ "$rc" -eq 124 ]; then why="timed out after ${secs}s"
    else why=$(grep -m1 . "$RUN/err" || echo "exit $rc"); fi
    say "$name: ✗ could-not-check ($why)"
    [ "$NO_ESCALATE" = 1 ] || [ "$SEED" = 1 ] && continue
    upsert_down "$name" "$why" || { echo "triage-gate: ops bead upsert failed for $name" >&2; EXIT=2; }
    continue
  fi
  [ -f "$STATE/down/$name" ] && [ "$NO_ESCALATE$SEED" = 00 ] && recovered "$name"
  awk -F'\t' 'NF>=2 && $1!="" && !seen[$1]++' "$RUN/out" >"$RUN/items"
  cut -f1 "$RUN/items" >"$RUN/keys"
  touch "$STATE/seen/$name"
  grep -Fxf "$RUN/keys" "$STATE/seen/$name" >"$RUN/kept"   # prune keys that left the source
  mv "$RUN/kept" "$STATE/seen/$name"
  n_new=0
  while IFS=$'\t' read -r key summary; do
    grep -Fxq -- "$key" "$STATE/seen/$name" && continue
    printf '%s\t%s\t%s\n' "$name" "$key" "$summary" >>"$RUN/new"; n_new=$((n_new + 1))
  done <"$RUN/items"
  say "$name: ✓ $(wc -l <"$RUN/items") current · $n_new new"
done 3<<<"$SOURCES"

# origin_tip — resolve trunk and fetch it; sets TRUNK_BRANCH and TIP (the remote tip sha). Non-zero
# when the remote cannot be reached: the gate cannot prove a landing then. No subshell — the
# variables must survive.
origin_tip() {
  TIP=""
  TRUNK_BRANCH=$(bash "$TOOLS/trunk.sh" 2>/dev/null) || return 1
  git fetch -q origin "+refs/heads/$TRUNK_BRANCH:refs/remotes/origin/$TRUNK_BRANCH" 2>/dev/null || return 1
  TIP=$(git rev-parse --verify -q "refs/remotes/origin/$TRUNK_BRANCH") && [ -n "$TIP" ]
}
landed() {  # landed <base-sha> — a report commit reached origin/<default> since <base-sha>
  origin_tip || return 1
  [ -n "$(git log -n1 --format=%H "$1..$TIP" -- "$REPORT" 2>/dev/null)" ]
}

mark_seen() { while IFS=$'\t' read -r name key _; do echo "$key" >>"$STATE/seen/$name"; done <"$1"; }

N_NEW=$(wc -l <"$RUN/new")
ESCALATED=no
if [ "$N_NEW" -gt 0 ]; then
  if [ "$SEED" = 1 ]; then
    mark_seen "$RUN/new"; ESCALATED="seeded $N_NEW"
  elif [ "$NO_ESCALATE" = 1 ]; then
    echo "new items ($N_NEW) — not escalated (--no-escalate):"; cat "$RUN/new"; ESCALATED="dry-run $N_NEW"
  else
    cp "$RUN/new" "$PENDING"
    if ! origin_tip; then
      echo "triage-gate: origin unreachable or trunk unresolved — cannot prove a landing, model not started; $N_NEW item(s) stay unseen" >&2
      ESCALATED="failed $N_NEW"; [ "$EXIT" = 2 ] || EXIT=1
    else
      BASE=$TIP
      echo "escalating $N_NEW new item(s) to the model"
      if ${TRIAGE_GATE_MODEL:-default_model} "$PENDING"; then
        if landed "$BASE"; then
          mark_seen "$PENDING"; rm -f "$PENDING"; ESCALATED="landed $N_NEW"
        else
          echo "triage-gate: model run exited 0 without a landed commit on origin/$TRUNK_BRANCH — $N_NEW item(s) stay unseen" >&2
          ESCALATED="failed $N_NEW"; [ "$EXIT" = 2 ] || EXIT=1
        fi
      else
        echo "triage-gate: model run failed — $N_NEW item(s) stay unseen" >&2
        ESCALATED="failed $N_NEW"; [ "$EXIT" = 2 ] || EXIT=1
      fi
    fi
  fi
fi

printf '%s\n' "${SUMMARY[@]}" | jq -Rn --arg ts "$(date -u +%FT%TZ)" --argjson exit "$EXIT" \
  --arg escalated "$ESCALATED" '{ts:$ts, exit:$exit, escalated:$escalated, sources:[inputs]}' \
  >"$STATE/heartbeat.json.tmp" && mv "$STATE/heartbeat.json.tmp" "$STATE/heartbeat.json"
echo "triage-gate: exit $EXIT · escalated: $ESCALATED"
exit "$EXIT"
