#!/usr/bin/env bash
# validate-qa-run.sh <ARTIFACTS_DIR> [--baseline-findings N] [--skip-teardown-check]
#
# Mechanical validation of a conductor/worker QA pass (_shared/qa-shared.md
# evidence protocol). Exit 0 = all assertions hold.
#
# Asserts:
#   1. journeys-manifest.json exists and parses
#   2. every dispatched journey has a verdict-<journey>.json (0 missing)
#   3. if >=2 parallel-lane verdicts exist: at least one pair has overlapping
#      [started_at, ended_at] windows AND distinct session names (real concurrency)
#   4. no leftover agent-browser sessions matching the manifest's session_prefix
#   5. (optional) total findings across verdicts >= --baseline-findings N (parity)

set -euo pipefail

ARTIFACTS_DIR="${1:?usage: validate-qa-run.sh <ARTIFACTS_DIR> [--baseline-findings N] [--skip-teardown-check]}"
shift
BASELINE_FINDINGS=""
SKIP_TEARDOWN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --baseline-findings) BASELINE_FINDINGS="$2"; shift 2 ;;
    --skip-teardown-check) SKIP_TEARDOWN=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

MANIFEST="$ARTIFACTS_DIR/journeys-manifest.json"
FAIL=0

say() { printf '%s\n' "$*"; }
bad() { say "✗ $*"; FAIL=1; }
ok()  { say "✓ $*"; }

# 1. Manifest exists + parses
if ! jq -e . "$MANIFEST" >/dev/null 2>&1; then
  bad "manifest missing or unparseable: $MANIFEST"
  exit 1
fi
ok "manifest parses"

# 2. Completeness: every dispatched journey has a verdict file
MISSING=()
while IFS= read -r j; do
  [ -f "$ARTIFACTS_DIR/verdict-$j.json" ] || MISSING+=("$j")
done < <(jq -r '.dispatched[].journey' "$MANIFEST")
if [ ${#MISSING[@]} -gt 0 ]; then
  bad "missing verdicts (${#MISSING[@]}): ${MISSING[*]}"
else
  ok "completeness: $(jq '.dispatched | length' "$MANIFEST") dispatched, 0 missing"
fi

# 3. Parallel-lane overlap: >=1 pair with overlapping windows + distinct sessions
PAR_COUNT=$(jq -r '[.dispatched[] | select(.lane=="parallel")] | length' "$MANIFEST")
if [ "$PAR_COUNT" -ge 2 ]; then
  OVERLAP=$(jq -s '
    [ .[] | select(.lane=="parallel") | {s: .session, a: .started_at, b: .ended_at} ] as $v
    | [ range(0; $v|length) as $i | range($i+1; $v|length) as $j
        | select($v[$i].s != $v[$j].s and $v[$i].a < $v[$j].b and $v[$j].a < $v[$i].b)
        | 1 ] | length' "$ARTIFACTS_DIR"/verdict-*.json)
  if [ "${OVERLAP:-0}" -ge 1 ]; then
    ok "concurrency: $OVERLAP overlapping parallel pair(s) on distinct sessions"
  else
    bad "no overlapping parallel-lane execution windows found ($PAR_COUNT parallel verdicts)"
  fi
else
  say "– concurrency check skipped ($PAR_COUNT parallel-lane journeys dispatched)"
fi

# 4. Teardown: no leftover sessions matching session_prefix
if [ "$SKIP_TEARDOWN" -eq 0 ]; then
  PREFIX=$(jq -r '.session_prefix // empty' "$MANIFEST")
  if [ -n "$PREFIX" ] && command -v agent-browser >/dev/null 2>&1; then
    LEFTOVER=$(agent-browser session list 2>/dev/null | grep -cF "$PREFIX" || true)
    if [ "${LEFTOVER:-0}" -gt 0 ]; then
      bad "teardown: $LEFTOVER leftover session(s) matching '$PREFIX'"
    else
      ok "teardown: no leftover sessions matching '$PREFIX'"
    fi
  else
    say "– teardown check skipped (no session_prefix or agent-browser absent)"
  fi
fi

# 5. Parity (optional)
if [ -n "$BASELINE_FINDINGS" ]; then
  TOTAL=$(jq -s '[ .[].findings | length ] | add // 0' "$ARTIFACTS_DIR"/verdict-*.json)
  if [ "$TOTAL" -ge "$BASELINE_FINDINGS" ]; then
    ok "parity: $TOTAL findings >= baseline $BASELINE_FINDINGS"
  else
    bad "parity: $TOTAL findings < baseline $BASELINE_FINDINGS"
  fi
fi

exit $FAIL
