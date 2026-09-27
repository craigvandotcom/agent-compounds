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
# Off-canon receipts (ruled ac-vbu3, 2026-09-27) — a historical record, not a defect to repair:
#   The NOOP check below is a whole-file `grep '^delivered:'`, so a `delivered:` line sitting in a
#   plan's BODY reads as delivered to this writer while every frontmatter reader sees the plan as
#   undelivered, and neither this script nor ac-tidy's scan will ever re-derive or repair it
#   (tidy-scan.sh walks `_plans/` only, and skips any plan with no `beadified:` key). Two archived
#   plans are ruled in that state and stay as they are — their prose receipts cite closed epics by
#   content and rewriting shipped frontmatter would falsify what the archive claims:
#     _plans/_done/2026-09-05-2318-agent-compounds-v2.md   delivered: in the BODY (line ~419)
#     _plans/_done/2026-09-21-close-gate-thin-core.md      delivered: in frontmatter, prose form
#   A `delivered:` is never hand-written into a plan: this script writes it, or a plan records in
#   prose why it has none. A new plan gets a stamp only from here.
#
# Verdict tokens (one greppable line each):
#   DELIVERED · WOULD-DELIVER (--check) · REFUSED not-beadified · REFUSED children-open N
#   · REFUSED coverage-gap · NOOP · NOT-GATED
#
# Usage: plan-deliver.sh [--check] <plan-path>   (--check runs the same checks, never writes)
# Env:   AC2_BR_CMD (the br binary br_call reads through; default: br)
set -u
CHECK=0; [ "${1:-}" = --check ] && { CHECK=1; shift; }
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
command -v python3 >/dev/null 2>&1 \
  || { echo "NOT-GATED: python3 unavailable — bead.py cannot be run"; exit 2; }

# bead.py is the one bead reader (ac-m9y4.1): the parent-child edge below reads through
# its forward (child-side) `dependencies` normalisation (`is_child_of`), never a second
# inline jq copy of that edge. A missing/crashing bead.py refuses NOT-GATED here, at load
# time, never a silent undercount.
_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
[ -f "$_TOOLS_DIR/bead.py" ] \
  || { echo "NOT-GATED: bead.py missing at $_TOOLS_DIR/bead.py — the parent-child edge cannot be resolved"; exit 2; }

# The program lives in its own file, never a heredoc attached to `python3 -`: a heredoc
# IS the command's stdin, so a JSON payload piped in on the same command would starve
# `sys.stdin.read()` of everything but EOF — the payload travels via a temp FILE argument
# instead. `BEAD_MODULE_PATH` is the same test-only override bead-capture-guard.py's own
# `_load_bead_module()` uses: a nonexistent path drives the crash-path fixture without
# ever touching the real file in a shared checkout.
_IS_CHILD_PY="$(mktemp)"
trap 'rm -f "$_IS_CHILD_PY"' EXIT
cat > "$_IS_CHILD_PY" <<'PY'
import importlib.util, json, os, sys


def _load_bead():
    override = os.environ.get("BEAD_MODULE_PATH")
    path = override or os.environ["BEAD_PY_PATH"]
    spec = importlib.util.spec_from_file_location("bead", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load bead.py at {path!r}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    bead = _load_bead()
    with open(sys.argv[1], "r") as f:
        data = json.load(f)
    is_child, err = bead.is_child_of(data, os.environ["EPIC_ID"])
    if err:
        print(f"NOT-GATED: {err}", file=sys.stderr)
        return 2
    print("yes" if is_child else "no")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"NOT-GATED: bead.py unavailable or crashed: {e}", file=sys.stderr)
        sys.exit(2)
PY

# <show-json-text> -> "yes"/"no" on stdout; exit 2 NOT-GATED on a missing/crashing bead.py
# or an unreadable payload.
_pd_is_child() {
  local json_text="$1" tf rc
  tf=$(mktemp) && printf '%s' "$json_text" > "$tf" || return 2
  BEAD_PY_PATH="$_TOOLS_DIR/bead.py" EPIC_ID="$EPIC" python3 "$_IS_CHILD_PY" "$tf"; rc=$?
  rm -f "$tf"
  return $rc
}

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
      is_child=$(_pd_is_child "$deps"); rc=$?
      [ "$rc" -eq 0 ] \
        || { echo "NOT-GATED: bead.py failed resolving the parent-child edge for $cid"; exit 2; }
      if [ "$is_child" = "yes" ]; then
        OPEN_COUNT=$((OPEN_COUNT + 1))
      fi ;;
  esac
done < <(printf '%s' "$RAW" | jq -r \
  'if type == "object" then (.issues // []) else . end | .[] | select(.status == "open") | .id')

if [ "$OPEN_COUNT" -gt 0 ]; then
  echo "REFUSED children-open $OPEN_COUNT: $OPEN_COUNT non-closeout child(ren) of $EPIC still open"
  exit 1
fi

# Coverage backstop: every plan "Done when:" reached a child (plan-coverage.sh), whether
# or not beadify ran it. Forward-only — epics created before the check existed are never
# re-judged; a plan with no Done when (a seams source) has nothing to trace.
COVERAGE_CUTOVER="2026-09-27T13:40:23Z"
if grep -q 'Done when:' "$PLAN"; then
  EPIC_ROW=$(br_call show "$EPIC" --json) \
    || { echo "NOT-GATED: br show refused for $EPIC — coverage cannot be judged"; exit 2; }
  EPIC_AT=$(printf '%s' "$EPIC_ROW" | jq -r 'if type == "array" then .[0] else . end | .created_at // ""')
  [ -n "$EPIC_AT" ] || { echo "NOT-GATED: $EPIC carries no created_at — coverage cannot be judged"; exit 2; }
  if [[ ! "$EPIC_AT" < "$COVERAGE_CUTOVER" ]]; then
    COV=$(bash "$(dirname "${BASH_SOURCE[0]}")/plan-coverage.sh" "$PLAN" "$EPIC"); RC=$?
    case "$RC" in
      0) ;;
      1) echo "REFUSED coverage-gap: a plan Done when line reached no child of $EPIC"
         printf '%s\n' "$COV"; exit 1 ;;
      *) echo "NOT-GATED: plan-coverage.sh — $COV"; exit 2 ;;
    esac
  fi
fi

if [ "$CHECK" = 1 ]; then
  echo "WOULD-DELIVER: $PLAN — every non-closeout child of $EPIC closed"
  exit 0
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
