#!/usr/bin/env bash
#
# close-evidence-check.sh — per-type close-evidence gate (ac-on0y.2).
#
# Bead closure verified STATUS and never EVIDENCE. The per-type close-artifact rules
# existed as convention only — bead-conventions § Per-type close artifacts, explicitly
# "presence-checked, not truth-checked" and delegated to closing-skill prose. So "closed"
# meant "an agent merged something", not "proven the way the bead itself declared".
#
# Usage:
#   close-evidence-check.sh [--force] [--report-only] [--list-unverifiable] <bead-id> <intended close reason>
#
# Exit 0  evidence present (or legitimately exempt, or bypassed, or --report-only)
# Exit 1  REFUSED — the close reason carries no evidence of the shape this type declares
# Exit 2  NOT-CHECKED — the gate could not verify. Never a pass: a gate that verified
#         nothing must not read as coverage (rule: a-gate-must-fail-when-it-verified-nothing).
#         The UNVERIFIABLE-DELIVERS verdict exits 2 too, but names itself: "the bead is
#         structurally unverifiable" and "this close lacks evidence" are different failures
#         (ac-k25c.7 — a gate whose refusals all look alike trains callers to ignore it).
#
# --list-unverifiable: audit mode. Lists every OPEN task/feature bead whose ## Delivers
# holds no path-shaped token (or is missing) — the population whose closes this gate can
# never verify. Exit 0 with the listing; exit 2 if the board cannot be read.
#
# THE BAR IS PRESENCE + CROSS-REFERENCE, never semantic truth — that stays review's job.
#   bug           -> the reason cites a test-shaped path (the regression test)
#   task/feature  -> the reason names >=1 artifact from THIS bead's own ## Delivers
#   investigation -> the reason cites a spawned bead id or a documented-answer marker
#   epic          -> exempt (Delivers-coverage is ac-align's epic-close proposal)
#   human-gate    -> exempt (closure is a recorded human decision)
#
# HISTORICAL CLOSES ARE NEVER SWEPT: this runs at close time, on the bead being closed.
#
# BYPASS is deliberate and permanent: --force is honoured ONLY when the close reason also
# carries `EVIDENCE-BYPASS: <why>`. The escape therefore lands in the bead's own record
# where a reader will meet it — a flag alone would vanish with the shell that typed it.
#
set -uo pipefail

FORCE=0
REPORT_ONLY=0
LIST_UNVERIFIABLE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --force)       FORCE=1; shift ;;
    --report-only) REPORT_ONLY=1; shift ;;
    --list-unverifiable) LIST_UNVERIFIABLE=1; shift ;;
    --) shift; break ;;
    -*) echo "close-evidence-check: unknown flag '$1'" >&2; exit 2 ;;
    *) break ;;
  esac
done

# --- audit mode: the population this gate can never verify -------------------
if [ "$LIST_UNVERIFIABLE" = 1 ]; then
  RAW=$(br list --status open --json 2>/dev/null || true)
  if [ -z "$RAW" ]; then
    echo "close-evidence NOT-CHECKED: 'br list --status open --json' returned nothing — the audit verified nothing" >&2
    exit 2
  fi
  COUNT=0
  # Only task/feature closes cross-reference ## Delivers; every other type is exempt
  # from this check by construction, so a prose-only Delivers there verifiable-closes fine.
  # br list --json returns {issues:[...]} (an array would iterate the same way).
  while IFS= read -r NODE; do
    [ -n "$NODE" ] || continue
    ID=$(printf '%s' "$NODE"   | jq -r '.id // empty')
    ITYPE=$(printf '%s' "$NODE" | jq -r '.issue_type // empty')
    DESC=$(printf '%s' "$NODE" | jq -r '.description // ""')
    [ "$ITYPE" = "task" ] || [ "$ITYPE" = "feature" ] || continue
    DEL=$(printf '%s' "$DESC" | awk '/^##[[:space:]]*Delivers/{p=1;next} p&&/^##[[:space:]]/{exit} p')
    if [ -z "$(printf '%s' "$DEL" | tr -d '[:space:]')" ]; then
      printf 'NO-DELIVERS\t%s\n' "$ID"; COUNT=$((COUNT + 1))
    elif [ -z "$(printf '%s' "$DEL" \
            | grep -oE '[A-Za-z0-9_.][A-Za-z0-9_./-]*\.[A-Za-z0-9]+' \
            | grep -vE '^\.+$' | head -1)" ]; then
      printf 'UNVERIFIABLE-DELIVERS\t%s\n' "$ID"; COUNT=$((COUNT + 1))
    fi
  done < <(printf '%s' "$RAW" | jq -c 'if type == "object" then (.issues // [])[] else .[] end')
  printf 'close-evidence: %s open task/feature bead(s) whose closes can never pass evidence check\n' "$COUNT"
  exit 0
fi

BEAD_ID="${1:-}"
REASON="${2:-}"

verdict() { # <PASS|REFUSE|NOT-CHECKED|EXEMPT|BYPASS> <message> <exit>
  printf 'close-evidence[%s] %s: %s\n' "$BEAD_ID" "$1" "$2"
  if [ "$REPORT_ONLY" = 1 ]; then
    printf 'close-evidence[%s] (report-only: exiting 0 regardless)\n' "$BEAD_ID"
    exit 0
  fi
  exit "$3"
}

if [ -z "$BEAD_ID" ] || [ -z "$REASON" ]; then
  echo "usage: $(basename "$0") [--force] [--report-only] <bead-id> <close reason>" >&2
  echo "close-evidence NOT-CHECKED: missing bead id or close reason" >&2
  exit 2
fi

RAW=$(br show "$BEAD_ID" --json 2>/dev/null || true)
if [ -z "$RAW" ]; then
  verdict "NOT-CHECKED" "'br show $BEAD_ID --json' returned nothing — cannot read the bead's declared evidence" 2
fi

# br returns an object for one id and an array for several; normalise.
NODE=$(printf '%s' "$RAW" | jq -c 'if type=="array" then .[0] else . end' 2>/dev/null || true)
if [ -z "$NODE" ] || [ "$NODE" = "null" ]; then
  verdict "NOT-CHECKED" "could not parse br output for $BEAD_ID" 2
fi

ITYPE=$(printf '%s' "$NODE" | jq -r '.issue_type // empty')
LABELS=$(printf '%s' "$NODE" | jq -r '(.labels // []) | join(",")')
DESC=$(printf '%s' "$NODE" | jq -r '.description // ""')

if [ -z "$ITYPE" ]; then
  verdict "NOT-CHECKED" "bead has no issue_type — cannot select an evidence rule" 2
fi

# --- exemptions ------------------------------------------------------------
case ",$LABELS," in
  *,human-gate,*) verdict "EXEMPT" "human-gate bead — closure is a recorded human decision" 0 ;;
esac
if [ "$ITYPE" = "epic" ]; then
  verdict "EXEMPT" "epic — Delivers-coverage is ac-align's epic-close proposal, not this gate" 0
fi

# --- deliberate, recorded bypass -------------------------------------------
if printf '%s' "$REASON" | grep -qE 'EVIDENCE-BYPASS:[[:space:]]*[^[:space:]]'; then
  if [ "$FORCE" = 1 ]; then
    verdict "BYPASS" "EVIDENCE-BYPASS present in the close reason and --force given — recorded on the bead" 0
  fi
  verdict "REFUSE" "close reason carries EVIDENCE-BYPASS but --force was not passed — the bypass must be BOTH" 1
fi
if [ "$FORCE" = 1 ]; then
  verdict "REFUSE" "--force given without 'EVIDENCE-BYPASS: <why>' in the close reason — a bypass that leaves no trace on the bead is not a bypass" 1
fi

# --- per-type rules --------------------------------------------------------
case "$ITYPE" in
  bug)
    # (a) A NON-FIX disposition has no regression test by construction. Demanding one
    #     would refuse every obsolete/duplicate close — measured on 5 of 24 recent bug
    #     refusals in the ac-on0y.2 calibration sweep.
    if printf '%s' "$REASON" \
       | grep -qiE '^[[:space:]]*(obsolete|duplicate|superseded|wont-?fix|not[- ]reproducible|works[- ]as[- ]intended)\b'; then
      verdict "PASS" "bug — non-fix disposition; evidence-of-fix does not apply" 0
    fi

    # (b) The regression test, named.
    if printf '%s' "$REASON" \
       | grep -qE '[A-Za-z0-9_./-]*([Tt]est|[Ss]pec)[A-Za-z0-9_./-]*\.[A-Za-z0-9]+'; then
      verdict "PASS" "bug — close reason cites a test-shaped path" 0
    fi

    # (c) Prose/doc/config bugs prove themselves with a grep/diff probe, not a test file
    #     — the SAME temporal shape (recorded before-state -> measured after-state).
    #     Requires BOTH a probe command and a before/after marker, so a bare mention of
    #     the word "grep" is not evidence. Measured: 13 of 24 recent bug refusals were
    #     this class, each carrying real recorded evidence.
    if printf '%s' "$REASON" | grep -qE '\b(grep|rg|diff|jq|awk|sed)\b' \
       && printf '%s' "$REASON" | grep -qE '(->|→|\bwas\b|\bnow\b|exit(s|=)|no hits|hits=)'; then
      verdict "PASS" "bug — close reason records a grep/diff probe with a before/after state" 0
    fi

    verdict "REFUSE" "bug — close reason shows no regression evidence: no test path, no recorded grep/diff before-after, no non-fix disposition" 1
    ;;

  investigation)
    if printf '%s' "$REASON" | grep -qE '\b[a-z]{2,}-[a-z0-9]{3,}(\.[0-9]+)*\b'; then
      verdict "PASS" "investigation — close reason cites a spawned bead id" 0
    fi
    if printf '%s' "$REASON" | grep -qE '(ANSWER:|FINDINGS:|[A-Za-z0-9_./-]+\.md)'; then
      verdict "PASS" "investigation — close reason cites a documented answer" 0
    fi
    verdict "REFUSE" "investigation — close reason names neither a spawned bead id nor a documented answer" 1
    ;;

  task|feature)
    DELIVERS=$(printf '%s' "$DESC" | awk '/^##[[:space:]]*Delivers/{p=1;next} p&&/^##[[:space:]]/{exit} p')
    if [ -z "$(printf '%s' "$DELIVERS" | tr -d '[:space:]')" ]; then
      verdict "NOT-CHECKED" "$ITYPE has no populated '## Delivers' section — there is no declared artifact to cross-reference. Give the bead a Delivers section, or bypass explicitly" 2
    fi

    # Path-shaped tokens only. Prose in Delivers is not a checkable promise.
    ARTIFACTS=$(printf '%s' "$DELIVERS" \
      | grep -oE '[A-Za-z0-9_.][A-Za-z0-9_./-]*\.[A-Za-z0-9]+' \
      | grep -vE '^\.+$' | LC_ALL=C sort -u)

    if [ -z "$ARTIFACTS" ]; then
      verdict "UNVERIFIABLE-DELIVERS" "$ITYPE bead $BEAD_ID carries a prose-only '## Delivers' — no path-shaped artifact exists to cross-reference, so NO close of this bead can ever pass evidence check. Fix the bead (give Delivers a path) or bypass explicitly. Audit siblings: close-evidence-check.sh --list-unverifiable" 2
    fi

    while IFS= read -r art; do
      [ -n "$art" ] || continue
      if printf '%s' "$REASON" | grep -qF -- "$art"; then
        verdict "PASS" "$ITYPE — close reason names declared artifact '$art'" 0
      fi
      # A bare basename in the reason still cross-references the promise.
      base="${art##*/}"
      if [ "$base" != "$art" ] && printf '%s' "$REASON" | grep -qF -- "$base"; then
        verdict "PASS" "$ITYPE — close reason names declared artifact '$base'" 0
      fi
    done <<< "$ARTIFACTS"

    printf 'close-evidence[%s] declared artifacts:\n' "$BEAD_ID" >&2
    printf '  - %s\n' $ARTIFACTS >&2
    verdict "REFUSE" "$ITYPE — close reason names NONE of the artifacts this bead's own ## Delivers promised" 1
    ;;

  *)
    verdict "EXEMPT" "issue_type '$ITYPE' has no declared per-type close artifact" 0
    ;;
esac
