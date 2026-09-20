#!/usr/bin/env bash
# exceptions.sh — resolve the effective exclusion set for the distribution policy.
#
# The standing policy is FULL-SET-EVERYWHERE: every asset reaches every managed target.
# This script names the few deviations, and the design is that there are exactly two
# kinds, kept apart on purpose:
#
#   TECHNICAL  Derived by the system, never written down. A public target must keep its
#              harness layer gitignored, so it is stamped under a guard and the guard's
#              verdict — not a list — decides. Rendered LOCKED: a human cannot edit these
#              away, because the constraint is real and would simply reassert itself.
#   EDITORIAL  Judgement, and the only hand-maintained input: the org-only skills that
#              operate the factory and have no job inside an app repo. They live in
#              harness.config.json under `exceptions.org_only_skills`.
#
# Keeping them apart is the point. A derived fact written down by hand becomes a second
# copy that drifts from the thing it describes; a judgement call derived by a script
# becomes a rule nobody agreed to. The asset x target grid is a VIEW over this output,
# never an input to it.
#
# ASSURANCE
#   PROBE:    bash engine/exceptions.sh --list
#   SCHEDULE: lint Check 21 declaration surface + ac-gnr3's acceptance probe
#   MODE:     advisory
#   ON-FAILURE: open
#
# Usage: exceptions.sh --list | --json
set -euo pipefail

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC_ROOT="$(cd "$ENGINE_DIR/.." && pwd)"
ORG_ROOT="$(cd "$AC_ROOT/../../.." && pwd)"
LAYOUT="$AC_ROOT/harness.config.json"
# AC_TARGETS_LIST overrides the default sibling path — for an adopter whose org root
# holds the deploy-targets roster under a differently named directory. Unset keeps the
# documented default; the graceful-degradation behavior below (technical() returns 3
# when the file is absent) is unchanged either way.
TARGETS_LIST="${AC_TARGETS_LIST:-$ORG_ROOT/infrastructure/ac-deploy-targets.list}"
# An override that names no file is a typo, never "no roster" (same rule as engine/sync.sh).
if [ -n "${AC_TARGETS_LIST:-}" ] && [ ! -f "$AC_TARGETS_LIST" ]; then
  echo "error: AC_TARGETS_LIST='$AC_TARGETS_LIST' is not a file" >&2; exit 2
fi

MODE="--list"
[ $# -gt 0 ] && MODE="$1"

[ -f "$LAYOUT" ] || { echo "error: $LAYOUT missing" >&2; exit 2; }

# --- EDITORIAL: read, never derived ------------------------------------------------
editorial() { jq -r '.exceptions.org_only_skills[]? // empty' "$LAYOUT"; }

# --- TECHNICAL: derived, never read ------------------------------------------------
# A target flagged `public` in the roster carries the constraint; the flag is the
# observation, the exclusion is the consequence. If the roster is absent we say so
# rather than reporting an empty technical set, which would read as "no constraints".
technical() {
  [ -f "$TARGETS_LIST" ] || return 3
  grep -vE '^[[:space:]]*(#|$)' "$TARGETS_LIST" \
    | awk '{ for (i = 2; i <= NF; i++) if ($i == "public") { print $1; break } }'
}

case "$MODE" in
  --list)
    echo "Distribution policy: full-set-everywhere (every asset reaches every managed target)."
    echo
    echo "EDITORIAL exclusions — org-only skills, hand-maintained in harness.config.json:"
    n=0
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      printf '  %-24s org-only: operates the org, not an app\n' "$s"
      n=$((n + 1))
    done < <(editorial)
    [ "$n" -gt 0 ] || echo "  (none)"
    echo "  -> $n skill(s); each also manual-only at org scope, so zero registry cost."
    echo
    echo "TECHNICAL exclusions — derived, rendered LOCKED:"
    if ! tech="$(technical)"; then
      echo "  UNRESOLVED: $TARGETS_LIST missing — the roster is the only source for the"
      echo "  public flag, so the technical set is unknown here, NOT empty."
    else
      t=0
      while IFS= read -r target; do
        [ -n "$target" ] || continue
        printf '  %-24s LOCKED: public repo — harness layer must stay gitignored\n' "$target"
        t=$((t + 1))
      done <<< "$tech"
      [ "$t" -gt 0 ] || echo "  (none derived)"
      echo "  -> $t target(s). Enforced at stamp time by guard_public() in engine/sync.sh,"
      echo "     which skips the target loudly rather than trusting this list."
    fi
    ;;
  --json)
    jq -n \
      --argjson editorial "$(editorial | jq -R . | jq -s .)" \
      --argjson technical "$(technical 2>/dev/null | jq -R . | jq -s 'map(select(. != ""))')" \
      '{policy: "full-set-everywhere",
        editorial: {kind: "hand-maintained", reason: "org-only", skills: $editorial},
        technical: {kind: "derived", locked: true,
                    reason: "public repo — harness layer must stay gitignored",
                    targets: $technical}}'
    ;;
  *)
    echo "usage: exceptions.sh --list | --json" >&2
    exit 2
    ;;
esac
