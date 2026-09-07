#!/usr/bin/env bash
#
# lint.sh — registry self-lint for agent-compounds. The front door every caller
# runs (ruled 2026-09-06: redesigned, never deleted).
#
# Mechanizes the 2026-06-11 audit's checkable invariants.
#
# Usage:  ./lint.sh                 full scan: every un-ported bash block, then
#                                   the v2 runner (lint/run.py) over lint/checks/
#         ./lint.sh --check <id>    ONLY the named v2 check (repeatable)
#         ./lint.sh --changed       only v2 checks whose scope touches the diff
#         ./lint.sh --json          v2 results as JSON
#         ./lint.sh --help
#
# Flags select the RUNNER ONLY — they skip the un-ported bash blocks, so a
# scoped run stays scoped (and a probe on --check <id> cannot be forged by a
# sibling's uncommitted edit elsewhere in the shared tree). A bare invocation
# runs everything: the full bash suite first, then the runner.
#
# Exit 0  all executed checks pass
# Exit 1  one or more checks failed (each reported as FAIL: ...)
# Exit 2  NOT-GATED — a check scanned zero files (verified nothing), or the
#         interpreter is below Python 3.12. Never a pass.
#
# Style-matched to deploy.sh (same repo).

set -uo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

require_py312() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "NOT-GATED: python3 not found — the lint runner cannot run, so nothing can be verified" >&2
    exit 2
  fi
  if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' 2>/dev/null; then
    echo "NOT-GATED: python3 3.12+ required (found $(python3 -V 2>&1)) — the lint runner refuses to run on an older interpreter" >&2
    exit 2
  fi
}

# --- front-door flag parsing -------------------------------------------------
RUNNER_ARGS=()
RUNNER_MODE=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    --changed|--json) RUNNER_ARGS+=("$1"); RUNNER_MODE=1; shift ;;
    --check)    [ $# -ge 2 ] || { echo "lint.sh: --check requires an id" >&2; exit 2; }
                RUNNER_ARGS+=("$1" "$2"); RUNNER_MODE=1; shift 2 ;;
    --check=*)  RUNNER_ARGS+=("--check" "${1#--check=}"); RUNNER_MODE=1; shift ;;
    *)          echo "lint.sh: unknown argument '$1' (usage: ./lint.sh --help)" >&2; exit 2 ;;
  esac
done

require_py312

# Repo-root check: the front door resolves its own checkout, and the runner the
# exec hands to must exist there — a partial checkout would silently scan nothing.
if [ ! -f "$AC_ROOT/lint/run.py" ]; then
  echo "NOT-GATED: $AC_ROOT/lint/run.py missing — this checkout is incomplete; the v2 runner cannot verify anything" >&2
  if [ "$RUNNER_MODE" = 1 ]; then exit 2; fi
fi

if [ "$RUNNER_MODE" = 1 ]; then
  exec python3 "$AC_ROOT/lint/run.py" "${RUNNER_ARGS[@]}" --root "$AC_ROOT"
fi

FAILURES=0
CHECKS=0

# Emit a FAIL line and increment counters.
fail() {
  echo "FAIL: $*"
  FAILURES=$(( FAILURES + 1 ))
}

# Increment check counter.
check() {
  CHECKS=$(( CHECKS + 1 ))
}

# ---------------------------------------------------------------------------
# Check 17 — dcg-blocked shell idioms in published snippets
# ---------------------------------------------------------------------------
echo "--- Check 17: dcg-blocked dynamic-path redirects ---"

# dcg's `core.filesystem:redirect-truncate-dynamic-path` refuses a TRUNCATING redirect whose
# target is shell-expanded — it cannot prove the path before the file is opened O_TRUNC. A
# published snippet prescribing that shape is UNRUNNABLE on this fleet.
#
# Why this check exists (bd-scjgv): bd-5ndzm was closed as Fixed on 2026-07-30 having scoped
# six skills and mechanically fixed exactly ONE. Nothing re-detected the rest, so the class
# read as "fixed" on the board while three separate published snippets still shipped it and
# kept costing conductors live time in Phase 0. The DETECTOR is the deliverable — without it
# the next snippet reintroduces the class and no one learns until someone loses a run.
#
# The discriminator is literal-vs-variable TARGET, not compound-vs-simple command (probed
# against dcg 0.6.7). NOT matched, because all three are allowed:
#   >> "$VAR/path"      appends never truncate
#   >/dev/null          fully-literal target
#   tee "$VAR/path"     tee is not a redirect
# Escape hatch: put `dcg-allow` in a comment on the same line to document the antipattern
# deliberately (shell-guardrails.md does exactly that).
# The `/` is anchored directly after the variable name ON PURPOSE. An earlier form used
# `[^"[:space:]]*/` and matched NOTHING under macOS grep's leftmost-longest semantics (no
# backtracking) — a detector that silently matches nothing is worse than no detector, so
# this pattern is proved red-then-green against fixtures before being trusted.
DCG_BAD_RE='(^|[[:space:]]|[0-9]|&)>[[:space:]]*"?\$\{?[A-Za-z_][A-Za-z0-9_:%+-]*/'

# SCOPE: markdown PRESCRIPTIONS only, deliberately not `*.sh`. dcg intercepts commands an
# agent submits to its Bash tool; a shell script executed as a FILE (`bash foo.sh`) is never
# inspected, so the same shape inside a committed script is not broken and flagging it would
# be a false positive that erodes trust in the check. The risk this guards is a snippet an
# agent COPIES OUT of a skill and runs inline.
dcg_hits=0
dcg_scanned=0
while IFS= read -r f; do
  # Only lines INSIDE ```bash / ```sh fences are prescriptions. Prose naming the antipattern
  # (shell-guardrails.md, and the rationale comments in board-scan.md) must not trip it.
  body=$(awk '/^[[:space:]]*```(bash|sh)[[:space:]]*$/{inb=1;next}
              /^[[:space:]]*```/{inb=0;next}
              inb{print FILENAME":"FNR":"$0}' "$f" 2>/dev/null)
  dcg_scanned=$(( dcg_scanned + 1 ))
  [ -n "$body" ] || continue
  hits=$(printf '%s\n' "$body" | grep -E -- "$DCG_BAD_RE" | grep -v 'dcg-allow' || true)
  [ -n "$hits" ] || continue
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    fail "Check 17: dcg-blocked truncating redirect to a variable path — ${h#$AC_ROOT/}"
    dcg_hits=$(( dcg_hits + 1 ))
  done <<< "$hits"
done < <(find "$AC_ROOT/skills" -type f -name '*.md' 2>/dev/null | sort)

check
if [ "$dcg_scanned" -eq 0 ]; then
  # Zero files scanned accounts for nothing — a broken find reads identical to a clean sweep.
  fail "Check 17: zero files scanned under skills/ — the sweep is vacuous"
elif [ "$dcg_hits" -eq 0 ]; then
  echo "  dcg redirect shapes: 0 violations across ${dcg_scanned} skill files"
fi

# ---------------------------------------------------------------------------
# Check 25 — is_test_shaped single-definition sensor (ac-b62c)
# ---------------------------------------------------------------------------
echo "--- Check 25: is_test_shaped drift sensor ---"
check
# flight-check WRITES the verification scope that close-gate READS. is_test_shaped is the
# contract both sides of that handshake interpret; if a second definition appears, the scope
# one records is not the scope the other interprets and the temporal proof silently rests on
# two different contracts. Exactly ONE definition site — close-gate.sh — enforced here, so a
# re-duplication fails instead of drifting.
ITS_SITES=$(grep -rl 'is_test_shaped()' skills/ac-implement/scripts/ 2>/dev/null || true)
ITS_N=$(printf '%s' "$ITS_SITES" | grep -c . || true)
if [ "$ITS_N" -eq 1 ] && printf '%s\n' "$ITS_SITES" | grep -q 'close-gate.sh'; then
  echo "  ok: is_test_shaped() defined once, in close-gate.sh"
else
  fail "Check 25: is_test_shaped() has $ITS_N definition site(s) ($(printf '%s' "$ITS_SITES" | tr '\n' ' ')) — the contract must live in exactly one place, close-gate.sh (ac-b62c drift sensor)"
fi
grep -q 'is_test_shaped' skills/ac-implement/scripts/flight-check.sh \
  && fail "Check 25: flight-check.sh mentions is_test_shaped — it must carry no copy that could drift from close-gate.sh's definition (ac-b62c)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "lint: ${CHECKS} checks, ${FAILURES} failures (un-ported bash blocks)"

# A failing un-ported block ends the run here — a red suite is not a green run.
if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi

# The v2 runner runs AFTER the un-ported blocks and ITS exit becomes the final
# exit. If the runner is absent (mid-port checkout) the legacy verdict stands.
if [ -f "$AC_ROOT/lint/run.py" ]; then
  exec python3 "$AC_ROOT/lint/run.py" --root "$AC_ROOT"
fi

[ "$FAILURES" -eq 0 ]
