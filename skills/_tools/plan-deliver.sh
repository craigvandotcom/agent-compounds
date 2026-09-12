#!/usr/bin/env bash
# plan-deliver.sh — the ONE writer of the delivered: stamp on a _plans/_done/ file.
# Sibling of plan-approve.sh (the ONE-writer precedent, ac-wp8i.10); never a hand edit.
#
# Three checks, then one key:
#   1. the plan carries a `beadified: <epic-id>` key (a plan never compiled is not deliverable)
#   2. every non-closeout child of that plan's epic is closed per `br list --json`
#      (the closeout bead itself — title `closeout: ...` — is still open while it delivers)
#   3. the plan is not already stamped (an already-stamped plan is a NOOP, never double-written)
# On success it writes delivered: <UTC-ISO> into the frontmatter — nothing else.
#
# Verdict tokens (one greppable line each):
#   DELIVERED · REFUSED not-beadified · REFUSED children-open N · NOOP · NOT-GATED
#
# Usage: plan-deliver.sh <plan-path>
# Env:   AC2_BR_CMD (the br binary br_call reads through; default: br)
set -u
PLAN="${1:-}"

# The ONE br_call invocation shape (ac-heyt.3): a raw br --json read turns a dead
# board into empty data, so every read below refuses instead.
# shellcheck source=br-call.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/br-call.sh" 2>/dev/null \
  || { echo "NOT-GATED: br-call.sh helper missing — no board read can be verified"; exit 2; }

if [ -z "$PLAN" ] || [ ! -r "$PLAN" ]; then
  echo "NOT-GATED: plan missing or unreadable: ${PLAN:-<none>}"
  exit 2
fi

# Idempotent first: a stamp already written is never written twice.
if grep -q '^delivered:' "$PLAN"; then
  echo "NOOP already-delivered: $PLAN already carries a delivered: stamp"
  exit 0
fi

if ! grep -q '^beadified:' "$PLAN"; then
  echo "REFUSED not-beadified: $PLAN carries no beadified: key (never compiled, never deliverable)"
  exit 1
fi
EPIC=$(grep -m1 '^beadified:' "$PLAN" | sed 's/^beadified:[[:space:]]*//' | awk '{print $1}')

command -v jq >/dev/null 2>&1 \
  || { echo "NOT-GATED: jq unavailable — the br list payload cannot be parsed"; exit 2; }

# The child set is the union close-gate's epic pick reads: dotted ids (<epic>.<n>) plus
# parent-child edges. br list rows carry no edge detail, so dotted membership is decided
# from the list payload and edge membership from one br_call show per open non-dotted
# bead. A refused read is NOT-GATED, never an undercount that delivers early.
RAW=$(br_call list --status open --limit 0 --json) \
  || { echo "NOT-GATED: br list refused — the epic's children cannot be read"; exit 2; }
[ -n "$RAW" ] || { echo "NOT-GATED: 'br list' returned nothing — the audit verified nothing"; exit 2; }
printf '%s' "$RAW" | jq -e 'if type == "object" then (.issues // []) else . end | type == "array"' >/dev/null 2>&1 \
  || { echo "NOT-GATED: br list payload parses to neither {issues:[]} nor a bare array"; exit 2; }

OPEN_COUNT=0
while IFS= read -r cid; do
  [ -n "$cid" ] || continue
  [ "$cid" = "$EPIC" ] && continue
  title=$(printf '%s' "$RAW" | jq -r --arg id "$cid" \
    'if type == "object" then (.issues // []) else . end | map(select(.id == $id))[0] | .title // ""')
  case "$title" in
    closeout:*) continue ;; # the deliverer itself: open while it delivers
  esac
  case "$cid" in
    "$EPIC".*) OPEN_COUNT=$((OPEN_COUNT + 1)) ;;
    *)
      deps=$(br_call show "$cid" --json) \
        || { echo "NOT-GATED: br show refused for $cid — an unreadable candidate is never counted absent"; exit 2; }
      if printf '%s' "$deps" | jq -e --arg e "$EPIC" \
        'if type == "array" then .[0] else . end
         | (.dependencies // []) | map(select(.dependency_type == "parent-child" and .id == $e)) | length > 0' \
         >/dev/null 2>&1; then
        OPEN_COUNT=$((OPEN_COUNT + 1))
      fi ;;
  esac
done < <(printf '%s' "$RAW" | jq -r \
  'if type == "object" then (.issues // []) else . end | .[] | select(.status == "open") | .id')

if [ "$OPEN_COUNT" -gt 0 ]; then
  echo "REFUSED children-open $OPEN_COUNT: $OPEN_COUNT non-closeout child(ren) of $EPIC still open"
  exit 1
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TMP="$(mktemp /tmp/plan-deliver-XXXXXX)"
awk -v ts="$TS" '
  BEGIN { infm=0; done=0 }
  NR==1 && $0=="---" { infm=1; print; next }
  infm && $0=="---" {
    if (!done) printf "delivered: %s\n", ts
    done=1; infm=0; print; next
  }
  { print }
  END { if (!done) exit 3 }
' "$PLAN" > "$TMP" \
  || { rm -f "$TMP"; echo "NOT-GATED: $PLAN carries no frontmatter block to stamp"; exit 2; }
mv "$TMP" "$PLAN"
echo "DELIVERED: $PLAN — delivered: $TS"
exit 0
