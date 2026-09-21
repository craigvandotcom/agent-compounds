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
#              The source is `engine/machine.sh --targets`, the one reader of this
#              machine's facts — never a second parser of the same file.
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
LAYOUT="$AC_ROOT/harness.config.json"
# The one reader of this machine's facts (`machine.json`, via AC_MACHINE_FILE). This
# script parses that file NOT AT ALL: a second parser is a second copy, and the two drift.
MACHINE_SH="$ENGINE_DIR/machine.sh"

MODE="--list"
[ $# -gt 0 ] && MODE="$1"

[ -f "$LAYOUT" ] || { echo "error: $LAYOUT missing" >&2; exit 2; }

# --- EDITORIAL: read, never derived ------------------------------------------------
editorial() { jq -r '.exceptions.org_only_skills[]? // empty' "$LAYOUT"; }

# --- TECHNICAL: derived, never read ------------------------------------------------
# A target flagged `public` in the roster carries the constraint; the flag is the
# observation, the exclusion is the consequence — and the roster, with its flag, comes
# from `machine.sh --targets` and nowhere else. Printed as BASENAMES: the roster's own
# grammar is a name, and the full path is the reader's business, not this view's.
# The reader's exit code carries its state (0 configured · 4 not configured · 2 present
# but wrong) and PROPAGATES: a set reported empty because the reader failed would read
# as "no constraints" when the truth is that the roster is unknown.
technical() {
  local out
  out="$("$MACHINE_SH" --targets)" || return $?
  printf '%s\n' "$out" \
    | awk -F'\t' '{ n = split($2, f, " ")
                    for (i = 1; i <= n; i++) if (f[i] == "public") { sub(".*/", "", $1); print $1; break } }'
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
      echo "  UNRESOLVED: engine/machine.sh --targets did not resolve the roster, and it is"
      echo "  the only source for the public flag — so the technical set is unknown here,"
      echo "  NOT empty."
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
    # The reader's state is carried TWICE — in the payload (`resolved`, `reader_exit`,
    # `targets`) and in this script's own exit code — because the discarded form this
    # replaces reported `targets: []` with exit 0, which reads as "configured, no
    # constraints" when the truth is that the reader could not resolve the roster.
    rc=0
    tech="$(technical)" || rc=$?
    if [ "$rc" -eq 0 ]; then
      jq -n \
        --argjson editorial "$(editorial | jq -R . | jq -s .)" \
        --argjson technical "$(printf '%s\n' "$tech" | jq -R . | jq -s 'map(select(. != ""))')" \
        '{policy: "full-set-everywhere",
          editorial: {kind: "hand-maintained", reason: "org-only", skills: $editorial},
          technical: {kind: "derived", locked: true, resolved: true,
                      reason: "public repo — harness layer must stay gitignored",
                      targets: $technical}}'
    else
      jq -n \
        --argjson editorial "$(editorial | jq -R . | jq -s .)" \
        --argjson reader_exit "$rc" \
        '{policy: "full-set-everywhere",
          editorial: {kind: "hand-maintained", reason: "org-only", skills: $editorial},
          technical: {kind: "derived", locked: true, resolved: false,
                      reason: "public repo — harness layer must stay gitignored",
                      reader_exit: $reader_exit,
                      targets: null}}'
    fi
    exit "$rc"
    ;;
  *)
    echo "usage: exceptions.sh --list | --json" >&2
    exit 2
    ;;
esac
