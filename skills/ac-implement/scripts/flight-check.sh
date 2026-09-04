#!/usr/bin/env bash
#
# flight-check.sh — the ac2 CLAIM-TIME premise pass and RED receipt writer (ac-k25c.2).
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/flight-check.test.sh
#   SCHEDULE:   every ac2 worker claim (and again, before any fix, for a bead that delivers
#               its own harness); the harness runs on every scripts/run-all-harnesses.sh
#               invocation, which lint.sh Check 20 audits for scheduling.
#   MODE:       blocking
#   ON-FAILURE: closed
#
# WHY IT EXISTS: verification used to happen at refine time and was stale by the time a
# worker claimed. This moves it to the fresh moment — the bead's premises are checked
# against the tree that actually exists, by the implementer, once, at claim.
#
# A premise failure is NOT an error state. It is a ROUTING DECISION: comment, prefix the
# title, unclaim, pick the next bead. Exit 1 means "this bead is not flyable today", not
# "the gate broke". Exit 2 means the gate could not verify, and a gate that cannot verify
# must say so and FAIL — silence is never success.
#
# THE FOUR REFUSALS, each named in the output so the caller can branch on the class:
#   PREMISE-FAILED: CONSUMES     a `## Consumes` artifact is absent, or its blocker is not closed
#   PREMISE-FAILED: ENVIRONMENT  a declared environment/infra precondition does not hold
#                                (a prod-only env once blocked a live-DB acceptance criterion
#                                undetected — artifact existence alone would not have seen it)
#   PREMISE-FAILED: PERISHABLE   a perishable external-state claim the bead depends on no
#                                longer holds when re-run
#   PREMISE-FAILED: RED          no RED is recorded per the bead's named probes — every one
#                                of them is ALREADY GREEN, so there is nothing for the diff
#                                to cause
#

# THE RECEIPT: this script is its ONLY WRITER, and it writes at the moment RED is OBSERVED.
# The receipt anchors WHEN — this bead's named probe failed before the diff existed. It does
# not attempt to prove the diff CAUSED the later GREEN: that is a judgement, it belongs to
# ac-review's causal-sufficiency dimension on the committed tree, and the checksum that used
# to assert it here was deleted (it proved a file had not changed, never that a change
# sufficed, and it was unsatisfiable for every prose bead).
#
# A receipt is only ever written while the named probe is RED: after the fix the probe is
# GREEN and this script refuses with PREMISE-FAILED: RED, so a post-fix receipt is
# unreachable rather than merely discouraged. Receipts APPEND; close-gate reads the LAST one.
#
# Usage:
#   flight-check.sh <bead-id> [--body-file <path>] [--root <repo root>] [--print-receipt]
#
# Env:
#   AC2_BEAD_BODY_FILE  bead body on disk instead of `br show` (offline / harness use)
#   AC2_FLIGHT_DIR      receipt directory (default: <git-common-dir>/ac-flight)
#   AC2_DRY_RUN=1       print the premise-failure routing commands instead of running them
#
# Exit 0  cleared for flight — premises hold, RED observed, receipt written
# Exit 1  PREMISE-FAILED (one of the four, named) — route, do not debug
# Exit 2  NOT-GATED — this gate could not verify; treat as a stop, never as a pass
#
set -uo pipefail

BEAD=""
BODY_FILE="${AC2_BEAD_BODY_FILE:-}"
ROOT=""
PRINT_RECEIPT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --body-file)     BODY_FILE="${2:-}"; shift 2 ;;
    --root)          ROOT="${2:-}"; shift 2 ;;
    --print-receipt) PRINT_RECEIPT=1; shift ;;
    -h|--help)       sed -n '2,60p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*)              echo "NOT-GATED: unknown option '$1'" >&2; exit 2 ;;
    *)               [ -z "$BEAD" ] && BEAD="$1" || { echo "NOT-GATED: unexpected argument '$1'" >&2; exit 2; }; shift ;;
  esac
done

[ -n "$BEAD" ] || { echo "NOT-GATED: usage: $0 <bead-id> [--body-file <path>]" >&2; exit 2; }

if [ -z "$ROOT" ]; then
  # ROOT is the CONSUMER repo's root, never the script's own repo: these scripts are
  # symlinked into consumer repos via .agents/skills/, so script-relative resolution
  # lands inside the skills checkout (or .agents/) and every repo-relative probe
  # dies with FileNotFoundError. Derive from the calling repo's git toplevel.
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
    || ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd) \
    || ROOT="$PWD"
fi
[ -d "$ROOT" ] || { echo "NOT-GATED: repo root '$ROOT' is not a directory" >&2; exit 2; }
cd "$ROOT" || { echo "NOT-GATED: cannot enter repo root '$ROOT'" >&2; exit 2; }

# --- helpers ---------------------------------------------------------------------------

# section <name> — print the body lines under `## <name>` up to the next `## ` header.
section() {
  awk -v want="## $1" '
    /^## /   { inb = ($0 ~ "^" want "([[:space:]]|$)") ? 1 : 0; next }
    inb      { print }
  ' "$BODY"
}

# premise_failed <CLASS> <detail…> — record; the router runs once, at the end.
FAIL_CLASS=""
FAIL_DETAIL=""
premise_failed() {
  FAIL_CLASS="$1"; shift
  FAIL_DETAIL="$*"
  echo "PREMISE-FAILED: ${FAIL_CLASS} — ${FAIL_DETAIL}"
}

# route — comment, prefix the title, unclaim. A premise failure is a routing decision.
route_premise_failure() {
  local msg_file note
  note="Premise failure: ${FAIL_CLASS} — ${FAIL_DETAIL}
Detected by flight-check.sh at claim, against the tree at $(git rev-parse --short HEAD 2>/dev/null || echo unknown).
The bead is not flyable as written: re-refine it against the tree that exists."
  msg_file=$(mktemp "${TMPDIR:-/tmp}/ac-flight-premise.XXXXXX") || { echo "NOT-GATED: cannot write the premise comment" >&2; return 2; }
  printf '%s\n' "$note" >"$msg_file"

  local title new_title
  title=""
  if [ "${AC2_DRY_RUN:-0}" != "1" ] && command -v br >/dev/null 2>&1; then
    title=$(br show "$BEAD" --json </dev/null 2>/dev/null \
      | jq -r 'if type == "array" then .[0] else . end | .title // ""' 2>/dev/null)
  fi
  case "$title" in PREMISE-FAILED:*) new_title="$title" ;; *) new_title="PREMISE-FAILED: ${title}" ;; esac

  if [ "${AC2_DRY_RUN:-0}" = "1" ]; then
    echo "ROUTE (dry-run): br comments add $BEAD -f $msg_file"
    echo "ROUTE (dry-run): br update $BEAD --title <PREMISE-FAILED-prefixed title>"
    echo "ROUTE (dry-run): br update $BEAD --status open --assignee ''"
    return 0
  fi

  if ! command -v br >/dev/null 2>&1; then
    echo "NOT-GATED: br is not on PATH — the premise failure could not be ROUTED (comment/title/unclaim)." >&2
    echo "NOT-GATED: do it by hand, then pick the next bead. Message body: $msg_file" >&2
    return 2
  fi
  br comments add "$BEAD" -f "$msg_file" </dev/null >/dev/null 2>&1 \
    || echo "warn: could not add the premise comment to $BEAD" >&2
  [ -n "$title" ] && { br update "$BEAD" --title "$new_title" </dev/null >/dev/null 2>&1 \
    || echo "warn: could not prefix the title of $BEAD" >&2; }
  br update "$BEAD" --status open --assignee "" </dev/null >/dev/null 2>&1 \
    || echo "warn: could not unclaim $BEAD" >&2
  rm -f "$msg_file"
  return 0
}

# --- the bead body ----------------------------------------------------------------------

BODY=$(mktemp "${TMPDIR:-/tmp}/ac-flight-body.XXXXXX") || { echo "NOT-GATED: cannot create a scratch file" >&2; exit 2; }
cleanup() { rm -f "$BODY"; }
trap cleanup EXIT

if [ -n "$BODY_FILE" ]; then
  [ -r "$BODY_FILE" ] || { echo "NOT-GATED: body file '$BODY_FILE' is unreadable" >&2; exit 2; }
  cat "$BODY_FILE" >"$BODY"
elif command -v br >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  br show "$BEAD" --json 2>/dev/null \
    | jq -r 'if type == "array" then .[0] else . end | .description // ""' >"$BODY"
else
  echo "NOT-GATED: no --body-file and br/jq unavailable — the bead's premises are unreadable" >&2
  exit 2
fi

if [ ! -s "$BODY" ]; then
  echo "NOT-GATED: bead '$BEAD' has an empty body — there are no premises to check" >&2
  exit 2
fi

echo "flight-check: $BEAD @ $(git rev-parse --short HEAD 2>/dev/null || echo no-git)"

# --- Refusal 1: CONSUMES ----------------------------------------------------------------
# Every `## Consumes` line is `<blocker-id> -> <artifact>`, or the single word `none`.
# BOTH halves are checked: the artifact must be on the tree AND the blocker must be closed.
# An open blocker with its artifact already present is still a premise failure — the
# artifact is not yet the committed thing this bead was refined against.

CONSUMES=$(section "Consumes" | sed 's/^[[:space:]]*-[[:space:]]*//' | grep -v '^[[:space:]]*$')
CONSUME_LINES=0
if [ -n "$CONSUMES" ] && ! printf '%s' "$CONSUMES" | grep -qiE '^none\.?$'; then
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in *"->"*) ;; *) continue ;; esac
    CONSUME_LINES=$(( CONSUME_LINES + 1 ))
    # Bead ids contain internal hyphens (bd-epic-kb-seams-573x7.3): the class must
    # include them, and a trailing separator run is trimmed (a "-/._" tail can only
    # come from the arrow or punctuation, never from a minted id).
    blocker=$(printf '%s' "$line" | sed -n 's/^\([A-Za-z][A-Za-z0-9._-]*\).*/\1/p' | sed 's/[-._]*$//')
    artifacts=$(printf '%s' "${line#*->}" | grep -oE '[A-Za-z0-9_.][A-Za-z0-9_./-]*/[A-Za-z0-9_.][A-Za-z0-9_./-]*' || true)
    for a in $artifacts; do
      a="${a%.}"
      if [ ! -e "$a" ]; then
        premise_failed CONSUMES "consumed artifact '$a' (from ${blocker:-an unnamed blocker}) is not on the tree"
        break 2
      fi
    done
    if [ -n "$blocker" ]; then
      if ! command -v br >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        echo "NOT-GATED: '$line' names blocker '$blocker' but br/jq are unavailable — closure unverifiable" >&2
        exit 2
      fi
      bstatus=$(br show "$blocker" --json </dev/null 2>/dev/null \
        | jq -r 'if type == "array" then .[0] else . end | .status // ""')
      if [ -z "$bstatus" ]; then
        # br show matches EXACT ids only; a Consumes line may cite a unique prefix
        # (bd-decision-no-drafts for bd-decision-no-drafts-huc5z). Resolve exactly one.
        full=$(br list --json --limit 5000 </dev/null 2>/dev/null \
          | jq -r --arg b "$blocker" \
            '[.issues[] | select(.id | startswith($b)) | .id]
             | if length == 1 then .[0] elif length == 0 then "" else "AMBIGUOUS" end')
        if [ -n "$full" ] && [ "$full" != "AMBIGUOUS" ]; then
          bstatus=$(br show "$full" --json </dev/null 2>/dev/null \
            | jq -r 'if type == "array" then .[0] else . end | .status // ""')
          blocker="$full"
        fi
      fi
      if [ -z "$bstatus" ]; then
        premise_failed CONSUMES "blocker '$blocker' is not on the board — the premise cites a bead that does not exist"
        break
      fi
      if [ "$bstatus" != "closed" ]; then
        premise_failed CONSUMES "blocker '$blocker' is '$bstatus', not closed — its deliverable is not final"
        break
      fi
    fi
  done <<EOF
$CONSUMES
EOF
fi
[ -z "$FAIL_CLASS" ] && echo "flight-check: CONSUMES ok ($CONSUME_LINES resolved)"

# --- Refusal 2: ENVIRONMENT -------------------------------------------------------------
# Environment and infra preconditions are checked, NOT merely artifact existence. Declared
# forms, read anywhere in the body:
#     Requires-env: NAME          the variable must be set and non-empty HERE
#     Requires-command: NAME      the binary must resolve on THIS PATH
#     Requires-file: <path>       the path must exist on THIS tree
# Plus the always-on leg: every probe's LEADING WORD must resolve as a command, because a
# probe whose interpreter is missing reports "not found" and is indistinguishable from a
# genuine RED — that is a false RED, and a false RED is a fabricated causal claim.

ENV_CHECKED=0
if [ -z "$FAIL_CLASS" ]; then
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    ENV_CHECKED=$(( ENV_CHECKED + 1 ))
    if [ -z "$(eval "printf '%s' \"\${$v:-}\"" 2>/dev/null)" ]; then
      premise_failed ENVIRONMENT "required environment variable '$v' is unset or empty in this environment"
      break
    fi
  done <<EOF
$(grep -oE 'Requires-env:[[:space:]]*[A-Za-z_][A-Za-z0-9_]*' "$BODY" | sed -E 's/.*:[[:space:]]*//' | sort -u)
EOF
fi
if [ -z "$FAIL_CLASS" ]; then
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    ENV_CHECKED=$(( ENV_CHECKED + 1 ))
    command -v "$c" >/dev/null 2>&1 || {
      premise_failed ENVIRONMENT "required command '$c' does not resolve on this PATH"
      break
    }
  done <<EOF
$(grep -oE 'Requires-command:[[:space:]]*[A-Za-z0-9_.-]+' "$BODY" | sed -E 's/.*:[[:space:]]*//' | sort -u)
EOF
fi
if [ -z "$FAIL_CLASS" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    ENV_CHECKED=$(( ENV_CHECKED + 1 ))
    [ -e "$p" ] || {
      premise_failed ENVIRONMENT "required infra path '$p' does not exist on this tree"
      break
    }
  done <<EOF
$(grep -oE 'Requires-file:[[:space:]]*[^[:space:]]+' "$BODY" | sed -E 's/.*:[[:space:]]*//' | sort -u)
EOF
fi

# --- the probes -------------------------------------------------------------------------
# Canonical extractor (bead-schema.md § The probe rule): the command sits alone in single
# backticks after `Probe: `, so a checker lifts it without a human reassembling it.

PROBES=$(grep -o 'Probe: `[^`]*`' "$BODY" | sed 's/^Probe: `//; s/`$//')
PROBE_COUNT=$(printf '%s\n' "$PROBES" | grep -c '[^[:space:]]' || true)

if [ -z "$FAIL_CLASS" ] && [ "$PROBE_COUNT" -eq 0 ]; then
  echo "NOT-GATED: bead '$BEAD' names ZERO extractable probes — a bead with no probe cannot" >&2
  echo "NOT-GATED: have a RED, and this gate would report a green it never earned." >&2
  exit 2
fi

if [ -z "$FAIL_CLASS" ]; then
  while IFS= read -r pr; do
    [ -n "$pr" ] || continue
    lead=$(printf '%s' "$pr" | awk '{print $1}')
    case "$lead" in
      ''|'#'|*=*) continue ;;
    esac
    ENV_CHECKED=$(( ENV_CHECKED + 1 ))
    command -v "$lead" >/dev/null 2>&1 || {
      premise_failed ENVIRONMENT "probe '$pr' leads with '$lead', which does not resolve on this PATH — its RED would be a false RED"
      break
    }
  done <<EOF
$PROBES
EOF
fi
[ -z "$FAIL_CLASS" ] && echo "flight-check: ENVIRONMENT ok ($ENV_CHECKED precondition(s))"

# --- Refusal 3: PERISHABLE --------------------------------------------------------------
# A perishable claim is external state the bead's plan rests on that nothing on the tree
# records: a DB value, "the column exists", "CI is red". Declared as
#     Perishable: <the claim> :: <the command that re-asserts it>
# and RE-RUN here, at claim, because the refine-time answer is exactly the thing that decays.

PERISH_CHECKED=0
if [ -z "$FAIL_CLASS" ]; then
  while IFS= read -r pl; do
    [ -n "$pl" ] || continue
    claim=$(printf '%s' "${pl%%::*}" | sed -E 's/[[:space:]]+$//')
    cmd=$(printf '%s' "${pl#*::}" | sed -E 's/^[[:space:]]+//')
    [ -n "$cmd" ] || continue
    PERISH_CHECKED=$(( PERISH_CHECKED + 1 ))
    if ! sh -c "$cmd" >/dev/null 2>&1 </dev/null; then
      premise_failed PERISHABLE "the claim '$claim' no longer holds — re-asserting it with \`$cmd\` failed"
      break
    fi
  done <<EOF
$(grep -oE 'Perishable:[[:space:]]*.*::.*' "$BODY" | sed -E 's/^Perishable:[[:space:]]*//')
EOF
fi
[ -z "$FAIL_CLASS" ] && echo "flight-check: PERISHABLE ok ($PERISH_CHECKED claim(s) re-asserted)"

# --- Refusal 4: RED, and the receipt ----------------------------------------------------

RED_PROBE=""
RED_EXIT=""
GREEN_COUNT=0
if [ -z "$FAIL_CLASS" ]; then
  while IFS= read -r pr; do
    [ -n "$pr" ] || continue
    sh -c "$pr" >/dev/null 2>&1 </dev/null
    rc=$?
    if [ "$rc" -ne 0 ] && [ -z "$RED_PROBE" ]; then
      RED_PROBE="$pr"; RED_EXIT="$rc"
    elif [ "$rc" -eq 0 ]; then
      GREEN_COUNT=$(( GREEN_COUNT + 1 ))
    fi
  done <<EOF
$PROBES
EOF

  if [ -z "$RED_PROBE" ]; then
    premise_failed RED "all $PROBE_COUNT named probe(s) are ALREADY GREEN — there is no RED for a diff to flip, so no causal claim is available"
  fi
fi

if [ -n "$FAIL_CLASS" ]; then
  route_premise_failure
  rr=$?
  [ "$rr" -eq 2 ] && exit 2
  exit 1
fi

FLIGHT_DIR="${AC2_FLIGHT_DIR:-$(git rev-parse --git-common-dir 2>/dev/null || echo .)/ac-flight}"
mkdir -p "$FLIGHT_DIR" 2>/dev/null || { echo "NOT-GATED: cannot create receipt dir '$FLIGHT_DIR'" >&2; exit 2; }
RECEIPT_FILE="$FLIGHT_DIR/${BEAD}.flight-receipt"

RECEIPT=$(cat <<EOF
FLIGHT-RECEIPT v1
bead: $BEAD
at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
tree: $(git rev-parse HEAD 2>/dev/null || echo no-git)
premise: PASS consumes=$CONSUME_LINES environment=$ENV_CHECKED perishable=$PERISH_CHECKED
red-probe: $RED_PROBE
red-exit: $RED_EXIT
red-green-siblings: $GREEN_COUNT of $PROBE_COUNT probe(s) already green
EOF
)
printf '%s\n\n' "$RECEIPT" >>"$RECEIPT_FILE" 2>/dev/null \
  || { echo "NOT-GATED: cannot append the flight receipt to '$RECEIPT_FILE'" >&2; exit 2; }

printf '%s\n' "$RECEIPT"
echo "flight-check: RED observed — receipt appended to ${RECEIPT_FILE}"
echo "flight-check: post it to the bead so it outlives this checkout:"
echo "flight-check:   br comments add $BEAD -f $RECEIPT_FILE"
[ "$PRINT_RECEIPT" -eq 1 ] && cat "$RECEIPT_FILE"
exit 0
