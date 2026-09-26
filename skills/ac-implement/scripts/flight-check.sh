#!/usr/bin/env bash
#
# flight-check.sh — the ac2 CLAIM-TIME premise pass and RED receipt writer (ac-k25c.2).
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/flight-check.test.sh
#   SCHEDULE:   every ac2 worker claim (and again, before any fix, for a bead that delivers
#               its own harness); the harness runs on every scripts/run-all-proofs.sh
#               invocation, scheduled by CI's `proofs` job.
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
# THE REFUSALS, each named in the output so the caller can branch on the class:
#   PREMISE-FAILED: CONSUMES     a `## Consumes` artifact is absent, or its blocker is not closed
#                                (a direct parent-child containment edge is exempt)
#   PREMISE-FAILED: ENVIRONMENT  a declared environment/infra precondition does not hold, or a
#                                probe outlives AC2_PROBE_TIMEOUT (default 120s)
#                                (a prod-only env once blocked a live-DB acceptance criterion
#                                undetected — artifact existence alone would not have seen it)
#   PREMISE-FAILED: PERISHABLE   a perishable external-state claim the bead depends on no
#                                longer holds when re-run
#   PREMISE-FAILED: RED          no RED is recorded per the bead's named probes — every one
#                                of them is ALREADY GREEN, so there is nothing for the diff
#                                to cause
#   PREMISE-FAILED: STALE-STAMP  the `refined` stamp no longer passes the stamp gate; the
#                                gate's downgrade leg has stripped it, the bead returns to
# the refine lane, and the batch report carries the reason
# as one `stale-stamp: <id> — <reason>` line. The bare label is never trusted past this point.
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
#                             [--check-only]
#
# --check-only runs all premise refusals and WRITES NOTHING: no routing comment, no title
# stamp, no unclaim, no receipt. Exit 0 = flyable, 1 = not, 2 = could not verify. It is
# what refly.sh asks of every PREMISE-FAILED bead at swarm start: the stamp is a cached
# verdict, and a cached verdict with no re-check outlives the bug that wrote it.
#
# Env:
#   AC2_BEAD_BODY_FILE  bead body on disk instead of `br show` (offline / harness use)
#   AC2_FLIGHT_DIR      receipt directory (default: <git-common-dir>/ac-flight)
#   AC2_DRY_RUN=1       print the premise-failure routing commands instead of running them
#
# Exit 0  cleared for flight — premises hold, RED observed, receipt written
# Exit 1  PREMISE-FAILED (one named class) — route, do not debug
# Exit 2  NOT-GATED — this gate could not verify; treat as a stop, never as a pass
#
set -uo pipefail

BEAD=""
BODY_FILE="${AC2_BEAD_BODY_FILE:-}"
ROOT=""
PRINT_RECEIPT=0
CHECK_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --body-file)     BODY_FILE="${2:-}"; shift 2 ;;
    --root)          ROOT="${2:-}"; shift 2 ;;
    --print-receipt) PRINT_RECEIPT=1; shift ;;
    --check-only)    CHECK_ONLY=1; shift ;;
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

# The ONE br_call invocation shape (ac-heyt.3); a refusal below is a NOT-GATED /
# keep-stamped routing, never empty data. Sourced before the cd: BASH_SOURCE may be
# relative, so the absolute helper path must resolve from the original cwd.
# shellcheck source=br-call.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)/br-call.sh" 2>/dev/null \
  || { echo "NOT-GATED: br-call.sh helper missing — br reads cannot be verified" >&2; exit 2; }

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
Freshness key: ${STAMP_FRESHNESS_KEY:-unavailable}.
The bead is not flyable as written: re-refine it against the tree that exists."
  msg_file=$(mktemp "${TMPDIR:-/tmp}/ac-flight-premise.XXXXXX") || { echo "NOT-GATED: cannot write the premise comment" >&2; return 2; }
  printf '%s\n' "$note" >"$msg_file"

  local title new_title
  title=""
  if [ "${AC2_DRY_RUN:-0}" != "1" ] && command -v br >/dev/null 2>&1; then
    title=$(br_call show "$BEAD" --json </dev/null \
      | jq -r 'if type == "array" then .[0] else . end | .title // ""' 2>/dev/null) \
      || title=""
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
  br_call show "$BEAD" --json \
    | jq -r 'if type == "array" then .[0] else . end | .description // ""' >"$BODY" \
    || { echo "NOT-GATED: br_call show refused — the bead's premises are unreadable" >&2; exit 2; }
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
BEAD_PARENT=""
BEAD_PARENT_READ=0
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
      # An exact-id `show` refusal IS the prefix-miss signal — br matches exact ids only,
      # so a Consumes line citing a unique prefix (bd-decision-no-drafts for
      # bd-decision-no-drafts-huc5z) refuses here BY DESIGN and resolves below. The
      # resolution reads are the cannot-check points: a refused list/show there is a
      # NOT-GATED, never a fabricated "not on the board".
      bstatus=$(br_call show "$blocker" --json </dev/null \
        | jq -r 'if type == "array" then .[0] else . end | .status // ""' 2>/dev/null) \
        || bstatus=""
      if [ -z "$bstatus" ]; then
        # br show matches EXACT ids only; a Consumes line may cite a unique prefix
        # (bd-decision-no-drafts for bd-decision-no-drafts-huc5z). Resolve exactly one.
        full=$(br_call list --json --limit 0 </dev/null \
          | jq -r --arg b "$blocker" \
            '[.issues[] | select(.id | startswith($b)) | .id]
             | if length == 1 then .[0] elif length == 0 then "" else "AMBIGUOUS" end') \
          || { echo "NOT-GATED: 'br list' refused — blocker '$blocker' resolution unverifiable" >&2; exit 2; }
        if [ -n "$full" ] && [ "$full" != "AMBIGUOUS" ]; then
          bstatus=$(br_call show "$full" --json </dev/null \
            | jq -r 'if type == "array" then .[0] else . end | .status // ""' 2>/dev/null) \
            || { echo "NOT-GATED: 'br show' refused for resolved blocker '$full' — closure unverifiable" >&2; exit 2; }
          blocker="$full"
        fi
      fi
      # A child may not cite its parent in ## Consumes, but legacy/malformed bodies can.
      # Parent-child containment is not sequencing-by-closure: once the cited id has been
      # resolved and found, exempt only the direct parent from the closed-status premise.
      if [ "$BEAD_PARENT_READ" -eq 0 ]; then
        BEAD_PARENT=$(br_call show "$BEAD" --json </dev/null \
          | jq -r 'if type == "array" then .[0] else . end | .parent // .parent_id // ""' 2>/dev/null) \
          || { echo "NOT-GATED: br_call show refused for '$BEAD' — parent-child closure exemption is unverifiable" >&2; exit 2; }
        BEAD_PARENT_READ=1
      fi
      if [ -n "$BEAD_PARENT" ] && [ "$blocker" = "$BEAD_PARENT" ]; then
        echo "flight-check: CONSUMES parent '$blocker' exempted (containment, not closure)"
        continue
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

# --- Refusal 5: STALE-STAMP — the `refined` stamp re-gated where it is spent (ac-l7xt) ---
# A stamp is only as valid as the contract it was written under, and nothing re-checks an
# existing stamp when the gate tightens: the stale stamp rides into the worker pool and its
# discovery costs a claim cycle plus a lost fixpoint. This is where it costs nothing — re-run
# the stamp gate on the bead; its own downgrade leg strips a stale `refined`, and the worker
# skips the bead with one routing decision. The bare label is never trusted past this point.
# The mutating stamp leg is not run in --check-only mode; its touchers derivation is run
# read-only there, so refly can re-ask a mutable count without changing the board. A bead
# that does not currently hold `refined` is not re-gated unless it carries a stale-stamp
# premise title; a gate that cannot run is NOT-GATED, never a pass.
#
# CLAIM-TIME, NOT EVERY-CALL: worker.md §3 tells a bead that delivers its own harness to
# write that harness, then re-run this script so the receipt anchors the stronger RED. That
# second run would otherwise re-gate `refined` against a tree that now has one more untracked
# file (the harness), and a toucher check keyed on "did the referrer set change" bounces
# STALE-STAMP for obeying the loop. The premise this gate holds is CLAIM-TIME, not call-time:
# the stamp is re-gated once per claim AND only while the receipt's freshness key still names
# the current tracked tree. "a receipt exists" is the WRONG key on its own — a prior claim's
# leftover receipt (receipts APPEND and are never cleared) would let a brand new claim skip a
# gate it has never actually run.
FLIGHT_DIR="${AC2_FLIGHT_DIR:-$(git rev-parse --git-common-dir 2>/dev/null || echo .)/ac-flight}"
RECEIPT_FILE="$FLIGHT_DIR/${BEAD}.flight-receipt"
STAMP_GATE="${STAMP_GATE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)/stamp-refined.sh}"
TOUCHERS_TOOL="${TOUCHERS_TOOL:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../_tools" 2>/dev/null && pwd)/touchers.sh}"
STAMP_SKIPPED=0
CURRENT_TREE=$(git rev-parse HEAD 2>/dev/null || echo no-git)
TRACKED_TREE_STATE=clean
if [ "$CURRENT_TREE" != "no-git" ] && ! git diff --quiet --ignore-submodules HEAD -- 2>/dev/null; then
  TRACKED_TREE_STATE=dirty
fi
# The freshness key is derived from the tree, not read from an environment.  A receipt may
# skip a second flight-check only while it describes this same tracked tree; a predecessor
# commit or a tracked sibling edit must force the touchers count to be re-derived.
STAMP_FRESHNESS_KEY="tree=$CURRENT_TREE;tracked=$TRACKED_TREE_STATE"

# touchers_check calls touchers.sh derive for every git-tracked Delivers path.  Run that
# read-only derivation in --check-only as well: refly must be able to re-ask a mutable
# touchers count without invoking the mutating refined-stamp gate.
touchers_check_readonly() (
  [ -f "$TOUCHERS_TOOL" ] || { echo "NOT-GATED: touchers tool not found at '$TOUCHERS_TOOL'"; return 2; }
  . "$TOUCHERS_TOOL" 2>/dev/null || return 2
  touchers_check "$BODY" "$BEAD"
)

if [ "$CHECK_ONLY" -eq 1 ] && [ -z "$FAIL_CLASS" ] \
   && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  TOUCHERS_OUT=$(touchers_check_readonly 2>&1); TOUCHERS_RC=$?
  if [ "$TOUCHERS_RC" -eq 2 ]; then
    printf '%s\n' "$TOUCHERS_OUT" >&2
    echo "NOT-GATED: the touchers count could not be re-derived; refusing rather than replaying a cached verdict" >&2
    exit 2
  elif [ "$TOUCHERS_RC" -ne 0 ]; then
    TOUCHERS_WHY=$(printf '%s\n' "$TOUCHERS_OUT" | grep -m1 'touchers: REFUSED' | sed 's/^touchers: REFUSED[^—]*— //')
    premise_failed STALE-STAMP "the touchers count was re-derived at use and no longer reproduces (freshness key: $STAMP_FRESHNESS_KEY) — ${TOUCHERS_WHY:-the declared count is stale}."
  fi
fi

if [ -z "$FAIL_CLASS" ] && [ "$CHECK_ONLY" -eq 0 ]; then
  if [ ! -f "$STAMP_GATE" ]; then
    echo "NOT-GATED: stamp gate not found at '$STAMP_GATE' — the refined stamp cannot be re-gated; refusing rather than trusting it" >&2
    exit 2
  fi
  if ! command -v br >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo "NOT-GATED: br/jq unavailable — the refined stamp cannot be re-gated; refusing rather than trusting it" >&2
    exit 2
  fi
  BEAD_JSON=$(br_call show "$BEAD" --json </dev/null) \
    || { echo "NOT-GATED: br_call show refused — the refined stamp cannot be re-gated; refusing rather than trusting it" >&2; exit 2; }
  holds_refined=$(printf '%s' "$BEAD_JSON" \
    | jq -r 'if type == "array" then .[0] else . end
             | [ .labels // [] | .[] | select(. == "refined") ] | length' 2>/dev/null)
  if [ "${holds_refined:-0}" -gt 0 ]; then
    # CLAIM_TS: latest `created_at` among comments whose text starts `CLAIM:` (same JSON
    # this leg already fetched — no extra `br` call). LAST_AT: the last receipt's `at:`
    # (same awk close-gate.sh uses to read the last receipt block). norm_ts matches
    # swarm-commit.sh's rule so the two compare the same way everywhere they're compared.
    CLAIM_TS=$(printf '%s' "$BEAD_JSON" \
      | jq -r 'if type == "array" then .[0] else . end
               | [ .comments[]? | select(.text | startswith("CLAIM:")) | .created_at ] | max // ""' 2>/dev/null)
    LAST_AT=""
    LAST_FRESHNESS=""
    if [ -f "$RECEIPT_FILE" ]; then
      LAST_RECEIPT=$(awk '/^FLIGHT-RECEIPT v1/{buf=""} {buf = buf $0 "\n"} END{printf "%s", buf}' "$RECEIPT_FILE")
      LAST_AT=$(printf '%s\n' "$LAST_RECEIPT" | grep -m1 '^at:' | sed 's/^at:[[:space:]]*//')
      LAST_FRESHNESS=$(printf '%s\n' "$LAST_RECEIPT" | grep -m1 '^freshness-key:' | sed 's/^freshness-key:[[:space:]]*//')
    fi
    norm_ts() { printf '%s' "$1" | sed -E 's/\.[0-9]+//; s/Z$//'; }
    if [ -n "$CLAIM_TS" ] && [ -n "$LAST_AT" ] \
       && [ "$LAST_FRESHNESS" = "$STAMP_FRESHNESS_KEY" ] \
       && ! [ "$(norm_ts "$LAST_AT")" \< "$(norm_ts "$CLAIM_TS")" ]; then
      STAMP_SKIPPED=1
      echo "flight-check[$BEAD] STAMP skipped — re-run within this claim (receipt $LAST_AT ≥ claim $CLAIM_TS; freshness $STAMP_FRESHNESS_KEY); gated at claim, never implies fresh"
    else
      [ -n "$LAST_FRESHNESS" ] && [ "$LAST_FRESHNESS" != "$STAMP_FRESHNESS_KEY" ] \
        && echo "flight-check[$BEAD] STAMP re-derived — freshness key changed ($LAST_FRESHNESS → $STAMP_FRESHNESS_KEY); the touchers count is never replayed from the old receipt"
      STAMP_OUT=$(bash "$STAMP_GATE" "$BEAD" </dev/null 2>&1); STAMP_RC=$?
      if [ "$STAMP_RC" -eq 2 ]; then
        printf '%s\n' "$STAMP_OUT" >&2
        echo "NOT-GATED: the stamp gate could not run (rc 2) — the refined stamp is unverified; never a pass" >&2
        exit 2
      elif [ "$STAMP_RC" -ne 0 ]; then
        printf '%s\n' "$STAMP_OUT" >&2
        STAMP_WHY=$(printf '%s\n' "$STAMP_OUT" | grep -m1 'stamp_refined: REFUSED' | sed 's/^stamp_refined: REFUSED[^—]*— //')
        premise_failed STALE-STAMP "the \`refined\` stamp is stale under the current gate — ${STAMP_WHY:-refused}. The gate's downgrade leg has stripped it; the bead returns to the refine lane (freshness key: $STAMP_FRESHNESS_KEY)."
      fi
    fi
  fi

fi
[ -z "$FAIL_CLASS" ] && [ "$STAMP_SKIPPED" -eq 0 ] && echo "flight-check: STAMP ok (refined re-gated or absent)"

# --- Refusal 4: RED, and the receipt ----------------------------------------------------

RED_PROBE=""
RED_EXIT=""
GREEN_COUNT=0
# A probe that never exits must refuse, not hang: a hang writes no stamp, so every next
# worker re-picks the bead. No timeout(1) on PATH → the probe runs bare.
PROBE_TIMEOUT="${AC2_PROBE_TIMEOUT:-120}"
TIMEOUT_CMD=$(command -v timeout || command -v gtimeout || true)
if [ -z "$FAIL_CLASS" ]; then
  while IFS= read -r pr; do
    [ -n "$pr" ] || continue
    ${TIMEOUT_CMD:+"$TIMEOUT_CMD" "$PROBE_TIMEOUT"} sh -c "$pr" >/dev/null 2>&1 </dev/null
    rc=$?
    if [ -n "$TIMEOUT_CMD" ] && [ "$rc" -eq 124 ]; then
      premise_failed ENVIRONMENT "probe '$pr' did not exit within ${PROBE_TIMEOUT}s — a probe runs once and exits, never watches"
      break
    fi
    if [ "$rc" -ne 0 ] && [ -z "$RED_PROBE" ]; then
      RED_PROBE="$pr"; RED_EXIT="$rc"
    elif [ "$rc" -eq 0 ]; then
      GREEN_COUNT=$(( GREEN_COUNT + 1 ))
    fi
  done <<EOF
$PROBES
EOF

  if [ -z "$FAIL_CLASS" ] && [ -z "$RED_PROBE" ]; then
    premise_failed RED "all $PROBE_COUNT named probe(s) are ALREADY GREEN — there is no RED for a diff to flip, so no causal claim is available"
  fi
fi

if [ -n "$FAIL_CLASS" ]; then
  if [ "$CHECK_ONLY" -eq 1 ]; then
    echo "flight-check: not flyable (check-only — nothing routed)"
    exit 1
  fi
  route_premise_failure
  rr=$?
  [ "$rr" -eq 2 ] && exit 2
  exit 1
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "flight-check: flyable (check-only — no receipt written)"
  exit 0
fi

# FLIGHT_DIR/RECEIPT_FILE: derived once, above the STALE-STAMP leg (Refusal 5) — one home.
mkdir -p "$FLIGHT_DIR" 2>/dev/null || { echo "NOT-GATED: cannot create receipt dir '$FLIGHT_DIR'" >&2; exit 2; }

RECEIPT=$(cat <<EOF
FLIGHT-RECEIPT v1
bead: $BEAD
at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
tree: $(git rev-parse HEAD 2>/dev/null || echo no-git)
premise: PASS consumes=$CONSUME_LINES environment=$ENV_CHECKED perishable=$PERISH_CHECKED
freshness-key: $STAMP_FRESHNESS_KEY
red-probe: $RED_PROBE
red-exit: $RED_EXIT
red-green-siblings: $GREEN_COUNT of $PROBE_COUNT probe(s) already green
EOF
)
printf '%s\n\n' "$RECEIPT" >>"$RECEIPT_FILE" 2>/dev/null \
  || { echo "NOT-GATED: cannot append the flight receipt to '$RECEIPT_FILE'" >&2; exit 2; }

printf '%s\n' "$RECEIPT"
echo "flight-check: RED observed — receipt appended to ${RECEIPT_FILE}"
# Post it to the bead: close-gate cites a receipt only when the row carries it.
if [ "${AC2_DRY_RUN:-0}" = "1" ]; then
  echo "POST (dry-run): br comments add $BEAD <this receipt>"
elif ! br comments add "$BEAD" "$RECEIPT" </dev/null >/dev/null 2>&1; then
  echo "warn: could not post the receipt to $BEAD — close-gate will fresh-verify instead" >&2
fi
[ "$PRINT_RECEIPT" -eq 1 ] && cat "$RECEIPT_FILE"
exit 0
