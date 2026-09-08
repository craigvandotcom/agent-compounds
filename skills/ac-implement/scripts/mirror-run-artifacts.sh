#!/usr/bin/env bash
#
# mirror-run-artifacts.sh — the ac2 CHECKPOINT leg: mirror a run's /tmp-mortal state into
# the repo's durable ac-flight tree at a batch boundary (ac-28nm, Craig ruling 2026-09-07
# option b).
#
# ASSURANCE
#   PROBE:      bash skills/ac-implement/scripts/mirror-run-artifacts.test.sh
#   SCHEDULE:   at every batch-boundary checkpoint, after the ledger flush in coordinator.sh;
#               the harness runs on every scripts/run-all-harnesses.sh invocation.
#   MODE:       non-blocking advisory
#   ON-FAILURE: closed
#
# WHY IT EXISTS: a multi-day run keeps its run-id.md, claim files, flight receipts and
# similar state under /tmp; a reboot (or the OS /tmp sweep) mid-run loses them, and nothing
# on the tree tells the next conductor what happened (evidence: ac-loop RUN 20260808-221219-
# 47229 lost its carrier and ~35 of 41 claim dirs between batches). The run's FLIGHT RECEIPTS
# already live repo-side under <git-common-dir>/ac-flight/ (written by flight-check.sh) —
# those survive. What does NOT survive is the /tmp scratch: run-id.md, the /tmp ac-*.txt
# claim/comment/worker bodies, the per-child /tmp/bead-work-*/ / /tmp/swarm-<RUN>-* dirs.
# This leg mirrors that scratch into <git-common-dir>/ac-flight/<run-id>/artifacts/ so a
# reboot mid-run loses nothing but a copy step. gitignored is fine — the value is surviving
# a reboot, not surviving history.
#
# Idempotency: copying OVER the same destination is a no-op for the mirrored set (cp -f
# overwrites in place; no set grows or duplicates on re-run). The leg prints what it copied.
#
# Usage:
#   mirror-run-artifacts.sh --run <run-id> [--dest <dir>]
#
#   --run <id>   the RUN_ID whose /tmp scratch to mirror. Required — nothing can be scoped
#                without it, and an unscoped sweep of /tmp is exactly the harm this avoids.
#   --dest <dir> destination ROOT. Defaults to <git-common-dir>/ac-flight/<run-id>/artifacts/.
#                The mirrored set lands in <dest>/artifacts/ so the default and an explicit
#                --dest agree on the same shape.
#
# Env:
#   AC2_MIRROR_SCRATCH  the /tmp-like root to scan (default ${TMPDIR:-/tmp}); the seam the
#                       harness drives so the real /tmp is never touched in tests.
#
# Exit 0  mirrored (or the run left nothing to mirror — stated, never silent)
# Exit 2  usage / NOT-GATED — a required arg is missing or the destination is unwritable
#
set -uo pipefail

RUN=""
DEST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --run)  RUN="${2:-}";  shift 2 ;;
    --dest) DEST="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,45p' "${BASH_SOURCE[0]}"; exit 0 ;;
    -*)  echo "NOT-GATED: unknown option '$1'" >&2; exit 2 ;;
    *)   echo "NOT-GATED: unexpected argument '$1'" >&2; exit 2 ;;
  esac
done

[ -n "$RUN" ] || { echo "NOT-GATED: --run <run-id> is required; without it nothing can be scoped" >&2; exit 2; }

SCRATCH="${AC2_MIRROR_SCRATCH:-/tmp}"
# Literal /tmp, never $TMPDIR: run-id.md writes run scratch to /tmp/bead-work-*,
# /tmp/ac-*.txt, /tmp/swarm-<RUN>-*, and on macOS $TMPDIR resolves to a per-user
# /var/folders tree that carries none of it. /tmp is a SYMLINK on macOS
# (/tmp -> private/tmp); `find /tmp` does not follow the starting symlink and
# enumerates nothing. Resolve to the real path so the scan sees the actual entries.
SCRATCH="$(cd "$SCRATCH" 2>/dev/null && pwd -P)" \
  || { echo "NOT-GATED: cannot enter scratch root '$SCRATCH'" >&2; exit 2; }
[ -d "$SCRATCH" ] || { echo "NOT-GATED: scratch root '$SCRATCH' is not a directory" >&2; exit 2; }

if [ -z "$DEST" ]; then
  COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || echo .)"
  DEST="$COMMON_DIR/ac-flight/$RUN/artifacts"
fi
ART="$DEST/artifacts"
mkdir -p "$ART" || { echo "NOT-GATED: cannot create artifact dir '$ART'" >&2; exit 2; }

MIRRORED=0
SKIPPED_SAFEGUARD=0

# Enumerate the /tmp scratch entries that belong to THIS run: any basename containing the
# full RUN_ID (ac-*.swarm-<RUN>-*.txt, /tmp/swarm-<RUN>-*, /tmp/bead-work-*-<RUN>, ...).
# The FULL run id is the matcher, never a numeric prefix — a name sharing only a prefix
# (e.g. the day stamp) is a different run and must not be swept.
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  base="$(basename "$entry")"
  case "$base" in
    *"$RUN"*)
      # Never copy the destination back onto itself if it happens to live under scratch.
      case "$entry" in "$ART"/*) SKIPPED_SAFEGUARD=$(( SKIPPED_SAFEGUARD + 1 )); continue ;; esac
      if [ -d "$entry" ]; then
        cp -fR "$entry" "$ART/" 2>/dev/null || { echo "NOT-GATED: could not mirror dir '$entry'" >&2; exit 2; }
      else
        cp -f "$entry" "$ART/" 2>/dev/null || { echo "NOT-GATED: could not mirror file '$entry'" >&2; exit 2; }
      fi
      echo "mirrored: $base"
      MIRRORED=$(( MIRRORED + 1 ))
      ;;
  esac
done < <(find "$SCRATCH" -maxdepth 1 2>/dev/null)

if [ "$MIRRORED" -eq 0 ]; then
  echo "mirror-run-artifacts[$RUN]: nothing mirrored — no /tmp entries carry run id '$RUN'"
else
  echo "mirror-run-artifacts[$RUN]: mirrored $MIRRORED run artifact(s) into $ART"
fi
[ "$SKIPPED_SAFEGUARD" -gt 0 ] && echo "mirror-run-artifacts[$RUN]: skipped $SKIPPED_SAFEGUARD self-reference(s) (destination under scratch)"
exit 0
