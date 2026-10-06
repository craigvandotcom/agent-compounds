#!/usr/bin/env bash
#
# needs-device-gate.sh — refuse a publish whose batch touches a surface that already
# carries an OPEN device bead, or an open device bead from which no paths
# can be derived (zero-path, fail-closed).
#
# ASSURANCE
#   PROBE:      bash skills/ac-publish/scripts/needs-device-gate.sh --self-test
#   SCHEDULE:   every ac-publish release, in preflight; the beta route skips it
#   MODE:       blocking
#   ON-FAILURE: closed — a refusal is a stop; there is no override
#
# Paths come from bead.py's canonical ## Delivers and Probe: extractors — the one
# reader every bead tool parses cards through (ac-m9y4.1), never a second hand-rolled
# copy. Territory is ignored: the ac2 schema has no Territory, and a Territory-only
# read would silent-pass every ac2 bead. bead.py is file-shaped-only (whole-word paths
# carrying an extension): a bead whose Delivers names only a bare directory derives no
# paths and falls to the zero-path leg below — fail-closed, never a silent miss.
#
# Usage:
#   needs-device-gate.sh --range <git-rev-range> [--root <app-checkout>]
#   needs-device-gate.sh --paths-file <file> [--board <br-list-json>]
#   needs-device-gate.sh --self-test
#
# Exit 0  GATE PASSED · Exit 1  GATE REFUSED · Exit 2  NOT-GATED
#
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
RANGE="" ROOT="" PATHS_FILE="" BOARD_FILE="" SELF_TEST=0

not_gated() { echo "NOT-GATED: $*" >&2; exit 2; }

TOOLS_DIR="$(cd "$(dirname "$SELF")/../../_tools" 2>/dev/null && pwd)"

# The ONE br_call invocation shape (ac-heyt.3); a refusal below is a NOT-GATED,
# never empty data. SELF is already absolute, so the helper path is cwd-independent.
# shellcheck source=br-call.sh
. "$TOOLS_DIR/br-call.sh" 2>/dev/null \
  || not_gated "br-call.sh helper missing — no br read can be verified"

# Fail-closed rule (Intent): a ship gate exits NOT-GATED when bead.py is missing, not
# when it merely finds nothing — a missing reader must never silently read as clean.
[ -f "$TOOLS_DIR/bead.py" ] || not_gated "bead.py missing at '$TOOLS_DIR/bead.py' — Delivers/Probe paths cannot be derived"

while [ $# -gt 0 ]; do
  case "$1" in
    --range)      RANGE="${2:-}"; shift 2 ;;
    --root)       ROOT="${2:-}"; shift 2 ;;
    --paths-file) PATHS_FILE="${2:-}"; shift 2 ;;
    --board)      BOARD_FILE="${2:-}"; shift 2 ;;
    --self-test)  SELF_TEST=1; shift ;;
    -h|--help)    sed -n '20,25p' "$SELF"; exit 0 ;;
    -*)           not_gated "unknown option '$1'" ;;
    *)            not_gated "unexpected argument '$1'" ;;
  esac
done

# --- path derivation: bead.py's ## Delivers + Probe: extractors, never Territory ------
# A token counts as a surface only if it contains `/` (repo-relative) — a bare
# repo-root filename or a bead id is not a surface, same policy the old hand-rolled
# reader enforced, now layered over the one canonical extractor instead of a second
# implementation of it. The program lives in its own file (never a heredoc attached
# to `python3 -`): a heredoc IS the command's stdin, so piping the bead body in on the
# same command would starve `sys.stdin.read()` of everything but EOF.
write_device_paths_py() {
  cat >"$1" <<'PY'
import os, sys
sys.path.insert(0, os.environ["BEAD_TOOL_DIR"])
import bead

with open(sys.argv[1], "r") as f:
    desc = f.read()
paths = set()
for d in bead.delivers(desc):
    paths.update(p for p in d["paths"] if p)
for probe in bead.probes(desc):
    paths.update(bead.extract_paths(probe))
for p in sorted(paths):
    if "/" in p:
        print(p)
PY
}

derive_device_paths() {
  local desc="$1" descfile rc
  descfile=$(mktemp "${TMPDIR:-/tmp}/needs-device-desc.XXXXXX") || return 2
  printf '%s' "$desc" >"$descfile"
  BEAD_TOOL_DIR="$TOOLS_DIR" python3 "$DEVICE_PATHS_PY" "$descfile"
  rc=$?
  rm -f "$descfile"
  return $rc
}

# Exact path, or a derived directory prefix of a batch path.
intersect_hits() {
  local bead_paths="$1" diff_paths="$2" bp dp
  [ -n "$bead_paths" ] && [ -n "$diff_paths" ] || return 0
  while IFS= read -r bp; do
    [ -n "$bp" ] || continue
    while IFS= read -r dp; do
      [ -n "$dp" ] || continue
      if [ "$bp" = "$dp" ]; then printf '%s\n' "$dp"; continue; fi
      case "$dp" in "$bp"/*) printf '%s\n' "$dp" ;; esac
    done <<EOF
$diff_paths
EOF
  done <<EOF
$bead_paths
EOF
}

# --- self-test (fixture board; never the live board) ----------------------------------
run_self_test() {
  local work fx rc out failures=0
  command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required for --self-test"; return 1; }
  work=$(mktemp -d "${TMPDIR:-/tmp}/needs-device-gate.XXXXXX") || return 1

  ac2_desc='## Intent
Camera capture on the minted row.

## Acceptance Criteria
- Capture lands on the minted row.
  Probe: `grep -q captureInProgressRef features/camera/components/multi-camera-capture.tsx` — tier: none

## Delivers
- fix: features/camera/components/multi-camera-capture.tsx

## Consumes
none
'
  # Path-less, bd-wuxx0-shaped: Delivers is prose, no Probe — refuses on the label alone.
  # No Territory heading anywhere in this file: the ac2 schema carries none, and D1
  # retires the name registry-wide (ac-m9y4.16 proves the deleted-name grep empty).
  zeropath_desc='## Intent
Device confirm on a real phone.

## Acceptance Criteria
- On a real phone the gallery shows every photo.

## Delivers
- Confirmation (or refutation) that the reported symptom is gone on a real device.

## Consumes
none
'

  write_board() {
    jq -n --arg id "$2" --arg desc "$3" --argjson extra "${4:-[]}" \
      '{issues: ([{id:$id, status:"open", labels:["device"], description:$desc}] + $extra)}' \
      >"$work/$1.json"
  }

  write_paths() { printf '%s\n' "$@" >"$work/paths.txt"; }

  run_case() {
    local name="$1" expect_rc="$2" expect_grep="$3"; shift 3
    out=$(bash "$SELF" "$@" 2>&1) || rc=$?
    rc=${rc:-0}
    if [ "$rc" -eq "$expect_rc" ] && printf '%s\n' "$out" | grep -qE "$expect_grep"; then
      echo "ok   $name"
    else
      echo "FAIL $name (rc=$rc expected $expect_rc; grep /$expect_grep/)"
      printf '%s\n' "$out" | sed 's/^/     /'
      failures=$((failures + 1))
    fi
    rc=0
  }

  write_board ac2 fx-ac2 "$ac2_desc"
  write_paths 'features/camera/components/multi-camera-capture.tsx' 'README.md'
  run_case "ac2 Delivers+Probe intersection refuses" 1 'GATE REFUSED: fx-ac2' \
    --board "$work/ac2.json" --paths-file "$work/paths.txt"

  AC_PUBLISH_ROUTE=beta run_case "the beta route skips the gate" 0 'SKIP \(beta route\)' \
    --board "$work/ac2.json" --paths-file "$work/paths.txt"

  write_board zero fx-wuxx0 "$zeropath_desc"
  write_paths 'docs/unrelated.md'
  run_case "zero-path refuses on the label alone" 1 'GATE REFUSED: fx-wuxx0' \
    --board "$work/zero.json" --paths-file "$work/paths.txt"
  out=$(bash "$SELF" --board "$work/zero.json" --paths-file "$work/paths.txt" 2>&1) || true
  if printf '%s\n' "$out" | grep -q 'zero-path'; then
    echo "ok   zero-path class named"
  else
    echo "FAIL zero-path class named"
    printf '%s\n' "$out" | sed 's/^/     /'
    failures=$((failures + 1))
  fi

  write_board clean fx-ac2 "$ac2_desc"
  write_paths 'README.md' 'docs/unrelated.md'
  run_case "clean batch on a pathed board with no intersection" 0 'GATE PASSED: clean batch' \
    --board "$work/clean.json" --paths-file "$work/paths.txt"

  run_case "no range and no paths-file is NOT-GATED" 2 'NOT-GATED' \
    --board "$work/ac2.json"

  # Leading-dot repo paths must keep the dot; /dev/null is not a surface.
  dotted_desc='## Acceptance Criteria
- Probe: `grep -q widget .claude/skills/CORE/journeys/widget.md` — tier: none

## Delivers
- note: .claude/skills/CORE/journeys/widget.md
'
  write_board dotted fx-dot "$dotted_desc"
  write_paths '.claude/skills/CORE/journeys/widget.md'
  run_case "leading-dot .claude path is derived and intersects" 1 'GATE REFUSED: fx-dot' \
    --board "$work/dotted.json" --paths-file "$work/paths.txt"

  devnull_desc='## Acceptance Criteria
- Probe: `git rev-parse HEAD >/dev/null` — tier: none

## Delivers
- Confirmation that the sitting happened.
'
  write_board devnull fx-devnull "$devnull_desc"
  write_paths 'README.md'
  run_case "dev/null is not a derived path (zero-path)" 1 'zero-path' \
    --board "$work/devnull.json" --paths-file "$work/paths.txt"

  # bead.py's extractor is file-shaped only (a whole-word path carrying an extension):
  # a Delivers/Probe pair naming only a bare directory derives zero paths and falls to
  # the zero-path leg — fail-closed (broader refusal), never a silent miss, the
  # intended trade-off of adopting the one canonical extractor (ac-m9y4.13).
  dir_desc='## Acceptance Criteria
- Probe: `grep -rq introPrice features/monetization/` — tier: none

## Delivers
- coverage: features/monetization/
'
  write_board dir fx-dir "$dir_desc"
  write_paths 'features/monetization/components/paywall-drawer.tsx' 'README.md'
  run_case "a bare-directory Delivers/Probe derives zero paths — fail-closed on the label alone" 1 'zero-path' \
    --board "$work/dir.json" --paths-file "$work/paths.txt"

  rm -rf "$work"
  if [ "$failures" -eq 0 ]; then
    echo "needs-device-gate --self-test: PASS"
    return 0
  fi
  echo "needs-device-gate --self-test: FAIL ($failures)"
  return 1
}

if [ "$SELF_TEST" -eq 1 ]; then
  unset AC_PUBLISH_ROUTE
  run_self_test
  exit $?
fi

# --- live / fixture run ----------------------------------------------------------------
# The beta route skips the gate: the TestFlight build is how a device bead gets
# its receipt, so gating that build on the receipt deadlocks. A release stays gated.
if [ "${AC_PUBLISH_ROUTE:-release}" = beta ]; then
  echo "SKIP (beta route): device beads gate the release, not the build that tests them"
  exit 0
fi

command -v jq >/dev/null 2>&1 || not_gated "jq is required to read the board"

if [ -z "$PATHS_FILE" ] && [ -z "$RANGE" ]; then
  not_gated "pass --range <git-rev-range> (or --paths-file); nothing was asserted"
fi

DIFF_PATHS=""
if [ -n "$PATHS_FILE" ]; then
  [ -r "$PATHS_FILE" ] || not_gated "paths-file '$PATHS_FILE' is missing or unreadable"
  DIFF_PATHS=$(sed 's|^\./||; /^[[:space:]]*$/d' "$PATHS_FILE" | sort -u) || true
else
  [ -n "$ROOT" ] || ROOT="$PWD"
  [ -d "$ROOT" ] || not_gated "root '$ROOT' is not a directory"
  DIFF_PATHS=$(git -C "$ROOT" diff --name-only "$RANGE" 2>/dev/null | sed 's|^\./||' | sort -u) \
    || not_gated "git diff --name-only '$RANGE' failed in '$ROOT'"
fi

if [ -n "$BOARD_FILE" ]; then
  [ -r "$BOARD_FILE" ] || not_gated "board file '$BOARD_FILE' is missing or unreadable"
  BOARD_JSON=$(cat "$BOARD_FILE")
else
  BOARD_JSON=$(br_call list --label device --json) \
    || not_gated "br list --label device refused — an unreadable board must not read as an empty one"
fi

ISSUES=$(printf '%s' "$BOARD_JSON" | jq -c '
  (if type=="array" then . elif (type=="object" and has("issues")) then .issues else empty end)
  // empty
' 2>/dev/null) || not_gated "board JSON was unparseable"
if [ -z "$ISSUES" ] || [ "$ISSUES" = "null" ]; then
  not_gated "board JSON was unparseable or had no issues array"
fi

FILTERED=$(printf '%s' "$ISSUES" | jq -c '
  [.[] | select((.status // "open") != "closed")
        | select((.labels // []) | index("device") != null)]
' 2>/dev/null) || not_gated "could not filter open device beads"

REFUSE_FILE=$(mktemp "${TMPDIR:-/tmp}/needs-device-refuse.XXXXXX") || not_gated "mktemp failed"
DEVICE_PATHS_PY=$(mktemp "${TMPDIR:-/tmp}/needs-device-paths.XXXXXX.py") || not_gated "mktemp failed"
trap 'rm -f "$REFUSE_FILE" "$DEVICE_PATHS_PY"' EXIT
write_device_paths_py "$DEVICE_PATHS_PY"

COUNT=$(printf '%s' "$FILTERED" | jq 'length')
i=0
while [ "$i" -lt "$COUNT" ]; do
  node=$(printf '%s' "$FILTERED" | jq -c --argjson i "$i" '.[$i]')
  id=$(printf '%s' "$node" | jq -r '.id // empty')
  desc=$(printf '%s' "$node" | jq -r '.description // ""')
  i=$((i + 1))
  [ -n "$id" ] || continue
  derived=$(derive_device_paths "$desc") || not_gated "bead.py crashed deriving paths for '$id'"
  if [ -z "$derived" ]; then
    printf '%s\t%s\n' "$id" "(zero-path — no paths from Delivers or AC probes; refusing on the device label alone)" >>"$REFUSE_FILE"
    continue
  fi
  hits=$(intersect_hits "$derived" "$DIFF_PATHS" | sort -u | tr '\n' ' ')
  if [ -n "${hits% }" ]; then
    printf '%s\t%s\n' "$id" "(intersect ${hits% })" >>"$REFUSE_FILE"
  fi
done

if [ ! -s "$REFUSE_FILE" ]; then
  echo "GATE PASSED: clean batch"
  exit 0
fi

while IFS="$(printf '\t')" read -r id reason; do
  echo "GATE REFUSED: $id $reason"
done <"$REFUSE_FILE"
exit 1
