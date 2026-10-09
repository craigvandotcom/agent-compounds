#!/usr/bin/env bash
# autopilot-gate.sh — the hourly autopilot gate. Plain shell decides; the model starts ONLY when
# P0–P1 work exists, and every run, started or not, leaves one line in the run ledger.
#
#   PROBE:      bash skills/ac-implement/scripts/autopilot-gate.test.sh — stub br, model and gh
#   SCHEDULE:   hourly at :30 (the scheduler job) · run-all-proofs.sh
#   MODE:       blocking
#   ON-FAILURE: closed — a gate that cannot tell never starts the model; non-zero is a Slack alert
#
# Order: flock · AC2_AUTOPILOT=1 exported and `autopilot.sh active` · HEAD on the default branch
# (`_tools/trunk.sh`) · work = open unrefined beads at or above the block's max_priority, plus
# `pick.sh --count` · else one ledger line and exit 0. Work → `claude -p --model opus` on
# workflows/scheduled.md, then the session's last-run.json is appended to the ledger.
#
# State: ${XDG_STATE_HOME:-~/.local/state}/ac-autopilot/<repo>/, exported to the session as
# AC2_AUTOPILOT_STATE.
#   ledger.jsonl   one JSON line per run — the liveness record. Gate fields: ts · start · end ·
#                  exit · outcome (ran · no-work · lock-held · disabled · wrong-branch ·
#                  not-gated · trunk-unresolved · br-failed · pick-failed) · base (HEAD before the
#                  session) · closed (number, 0 when absent) · pushed (SHA array, [] when absent).
#                  Everything else the session wrote to last-run.json is carried along unchanged.
#   last-run.json  written by the session; removed before each run so a stale one is never reused.
#                  `closed` (P0–P1 beads closed this run) and `pushed` (head SHA of each push.sh
#                  push) are the two fields --verdict reads.
#
# Usage:  autopilot-gate.sh                 one gate pass
#         autopilot-gate.sh --verdict <days>  PASS iff the ledger holds >= 10 closes in the window
#                                           and every pushed head that ci.yml triggers on has a green
#                                           CI run (a push whose changed files all match ci.yml
#                                           `paths-ignore`, base..head, gets no run and is not
#                                           counted). Last line: `PASS closes=<N> red=0` /
#                                           `FAIL closes=<N> red=<R>`.
# Env:    AUTOPILOT_GATE_STATE  state dir (default as above)
#         AUTOPILOT_GATE_MODEL  command run instead of the default claude session (the test seam)
#         AC2_BR_CMD            the br binary (br-call.sh)
# Exit:   0  no work · disabled · wrong branch · lock held · session handled (incl. push pending);
#            --verdict PASS
#         1  a real failure (the session failed or wrote no report; trunk or a br/pick read failed);
#            --verdict FAIL
#         2  NOT-GATED — the autopilot block is misconfigured; --verdict could not be judged
#         64 usage

MIN_CLOSES=10

usage() { echo "usage: autopilot-gate.sh [--verdict <days>]" >&2; exit 64; }
VERDICT=""
case ${1-} in
  "") ;;
  --verdict) [ "$#" -eq 2 ] && [[ $2 =~ ^[0-9]+$ ]] && [ "$2" -gt 0 ] || usage; VERDICT=$2 ;;
  *) usage ;;
esac

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "autopilot-gate: not in a git repo" >&2; exit 64; }
cd "$ROOT" || exit 64
STATE="${AUTOPILOT_GATE_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/ac-autopilot/$(basename "$ROOT")}"
LEDGER="$STATE/ledger.jsonl"
TOOLS="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../_tools" && pwd)"
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
WORKFLOW=".claude/skills/ac-implement/workflows/scheduled.md"
. "$TOOLS/br-call.sh" || exit 64
command -v jq >/dev/null || { echo "autopilot-gate: jq not found" >&2; exit 64; }

# ---------------------------------------------------------------------------------------------
# --verdict
# ---------------------------------------------------------------------------------------------
glob_to_ere() {  # GitHub path glob -> anchored ERE
  printf '%s' "$1" | sed -E \
    -e 's/[.+^${}()|\\]/\\&/g' -e 's/\[/\\[/g' -e 's/\]/\\]/g' \
    -e 's#\*\*/#\x01#g' -e 's#\*\*#\x02#g' -e 's#\*#[^/]*#g' -e 's#\?#[^/]#g' \
    -e 's#\x01#(.*/)?#g' -e 's#\x02#.*#g' -e 's#^#^#' -e 's#$#$#'
}
ci_ignore_globs() {  # on.push.paths-ignore of ci.yml, one glob per line
  awk '/^  push:/ {p=1; next} p && /^  [A-Za-z_-]+:/ {p=0}
       p && /paths-ignore:/ {i=1; next}
       i && /^[[:space:]]*- / {sub(/^[[:space:]]*- /, ""); gsub(/^['"'"'"]|['"'"'"][[:space:]]*$/, ""); print; next}
       i && !/^[[:space:]]*(#|$)/ {i=0}' "$1"
}
push_triggers_ci() {  # push_triggers_ci <base> <sha> — a changed path outside paths-ignore exists
  local base=$1 sha=$2 files f ere ignored
  files=$(git -c core.quotepath=off diff --name-only "$base" "$sha" 2>/dev/null) || return 2
  [ -n "$files" ] || { files=$(git -c core.quotepath=off diff --name-only "$sha^" "$sha" 2>/dev/null) || return 2; }
  [ -n "$files" ] || return 1
  while IFS= read -r f; do
    ignored=0
    while IFS= read -r g; do
      [ -n "$g" ] || continue
      ere=$(glob_to_ere "$g")
      if printf '%s\n' "$f" | grep -qE -- "$ere"; then ignored=1; break; fi
    done <<EOF
$IGNORES
EOF
    [ "$ignored" -eq 1 ] || return 0
  done <<EOF
$files
EOF
  return 1
}

if [ -n "$VERDICT" ]; then
  [ -f "$LEDGER" ] || { echo "autopilot-gate: no ledger at $LEDGER — the verdict cannot be judged" >&2; echo "UNKNOWN"; exit 2; }
  CI=".github/workflows/ci.yml"
  [ -f "$CI" ] || { echo "autopilot-gate: $CI not found — CI runs cannot be judged" >&2; echo "UNKNOWN"; exit 2; }
  command -v gh >/dev/null || { echo "autopilot-gate: gh not found — CI runs cannot be read" >&2; echo "UNKNOWN"; exit 2; }
  IGNORES=$(ci_ignore_globs "$CI")
  SINCE=$(( $(date -u +%s) - VERDICT * 86400 ))
  CLOSES=$(jq -s --argjson since "$SINCE" '[.[] | select((.ts | fromdateiso8601) >= $since) | .closed // 0 | numbers] | add // 0' "$LEDGER") \
    || { echo "autopilot-gate: ledger unreadable" >&2; echo "UNKNOWN"; exit 2; }
  PUSHES=$(jq -r --argjson since "$SINCE" 'select((.ts | fromdateiso8601) >= $since)
      | (.base // "") as $b | (.pushed // [])[] | strings | [., $b] | @tsv' "$LEDGER") \
    || { echo "autopilot-gate: ledger unreadable" >&2; echo "UNKNOWN"; exit 2; }
  RED=0; COUNTED=0
  while IFS=$'\t' read -r sha base; do
    [ -n "$sha" ] || continue
    push_triggers_ci "${base:-$sha^}" "$sha"; trc=$?
    if [ "$trc" -eq 2 ]; then echo "autopilot-gate: cannot diff pushed head $sha" >&2; echo "UNKNOWN"; exit 2; fi
    [ "$trc" -eq 0 ] || { echo "skip  $sha (bookkeeping-only push; ci.yml paths-ignore)"; continue; }
    COUNTED=$((COUNTED + 1))
    runs=$(gh run list --workflow ci.yml --commit "$sha" --json status,conclusion --limit 20 2>/dev/null) \
      || { echo "autopilot-gate: gh run list failed for $sha — CI cannot be judged" >&2; echo "UNKNOWN"; exit 2; }
    if jq -e 'any(.[]?; .status == "completed" and .conclusion == "success")' <<<"$runs" >/dev/null 2>&1; then
      echo "green $sha"
    else
      echo "red   $sha (no green CI run)"; RED=$((RED + 1))
    fi
  done <<EOF
$PUSHES
EOF
  echo "window=${VERDICT}d pushes-counted=$COUNTED"
  if [ "$CLOSES" -ge "$MIN_CLOSES" ] && [ "$RED" -eq 0 ]; then echo "PASS closes=$CLOSES red=$RED"; exit 0; fi
  echo "FAIL closes=$CLOSES red=$RED"; exit 1
fi

# ---------------------------------------------------------------------------------------------
# one gate pass
# ---------------------------------------------------------------------------------------------
command -v flock >/dev/null || { echo "autopilot-gate: flock not found" >&2; exit 64; }
mkdir -p "$STATE" || exit 64

now_iso() { date -u +%FT%TZ; }
ledger() {  # ledger <outcome> [extra-json-object] — one line; closed defaults to 0
  local extra=${2-}
  [ -n "$extra" ] || extra='{}'
  jq -nc --arg ts "$(now_iso)" --arg outcome "$1" --argjson extra "$extra" \
    '{closed: 0, pushed: []} + $extra + {ts: $ts, outcome: $outcome}' >>"$LEDGER"
}

exec 9>"$STATE/lock"
flock -n 9 || { echo "autopilot-gate: another run holds $STATE/lock — skipped"; ledger lock-held; exit 0; }

export AC2_AUTOPILOT=1 AC2_AUTOPILOT_STATE="$STATE"
bash "$TOOLS/autopilot.sh" active; arc=$?
case $arc in
  0) ;;
  1) echo "autopilot-gate: autopilot not enabled for this project — skipped"; ledger disabled; exit 0 ;;
  *) ledger not-gated; exit 2 ;;
esac

TRUNK=$(bash "$TOOLS/trunk.sh") || { echo "autopilot-gate: default branch unresolved" >&2; ledger trunk-unresolved; exit 1; }
CUR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$CUR" != "$TRUNK" ]; then
  echo "autopilot-gate: HEAD is on '$CUR', not '$TRUNK' — skipped"; ledger wrong-branch; exit 0
fi

MAXP=$(bash "$TOOLS/autopilot.sh" get max_priority) || { ledger not-gated; exit 2; }
listed=$(br_call list --status open --label unrefined --priority "0-$MAXP" --json) \
  || { echo "autopilot-gate: br list failed — work cannot be counted" >&2; ledger br-failed; exit 1; }
UNREFINED=$(jq -r 'if type == "object" then .issues else . end
  | [.[] | select(((.labels // []) | index("human-gate")) == null)] | length' <<<"$listed") \
  || { echo "autopilot-gate: br list unparseable" >&2; ledger br-failed; exit 1; }
READY=$(bash "$HERE/pick.sh" --count 2>"$STATE/pick.err"); prc=$?
if [ "$prc" -ne 0 ]; then
  cat "$STATE/pick.err" >&2; echo "autopilot-gate: pick.sh --count failed (exit $prc)" >&2
  ledger pick-failed; exit 1
fi
if [ $((UNREFINED + READY)) -eq 0 ]; then
  echo "autopilot-gate: no P0–$MAXP work — skipped"; ledger no-work; exit 0
fi

default_model() { claude -p --model opus "Execute $WORKFLOW now"; }
rm -f "$STATE/last-run.json"
BASE=$(git rev-parse HEAD)
START=$(now_iso)
echo "autopilot-gate: $UNREFINED unrefined · $READY ready — starting the session"
${AUTOPILOT_GATE_MODEL:-default_model} 9>&-; mrc=$?
END=$(now_iso)

report='{}'; haverep=1
if [ -f "$STATE/last-run.json" ] && jq -e 'type == "object"' "$STATE/last-run.json" >/dev/null 2>&1; then
  report=$(jq -c '. + {closed: (if (.closed | type) == "number" then .closed else 0 end),
                       pushed: (if (.pushed | type) == "array" then .pushed else [] end)}' "$STATE/last-run.json")
else
  haverep=0
fi
ledger ran "$(jq -nc --argjson r "$report" --arg start "$START" --arg end "$END" --arg base "$BASE" --argjson exit "$mrc" \
  '$r + {start: $start, end: $end, base: $base, exit: $exit} + (if $r == {} then {report: "missing"} else {} end)')"

if [ "$mrc" -ne 0 ]; then echo "autopilot-gate: the session exited $mrc" >&2; exit 1; fi
if [ "$haverep" -eq 0 ]; then echo "autopilot-gate: the session wrote no valid $STATE/last-run.json" >&2; exit 1; fi
echo "autopilot-gate: run handled"
exit 0
