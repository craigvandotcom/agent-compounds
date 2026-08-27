#!/usr/bin/env bash
# element4-check.sh — the mechanical element-4 gate.
#
# Element 4 of the implementation contract (`beads-standards/reference/bead-conventions.md`
# § Implementation contract) is the only element the converge phase mechanically consumes:
# the mutation sampler reads the declared RED verbatim. A RED reconstructed after the fix
# falsifies nothing. Prose enforcement does not hold, so this gate is executable.
#
# Usage:
#   element4-check.sh <bead-id> [<bead-id>...]     # resolves via `br show --json`
#   element4-check.sh --file <path> [--type <t>]   # checks a description file (fixtures/tests)
#
# Exit 0 — every checked bead satisfies element 4 (or is an exempt type).
# Exit 1 — at least one bead FAILS. Each failure is named with its reason.
# Exit 2 — usage error, or a bead id that does not resolve.
#
# Three assertions, and the third is the point:
#   1. no `## Declared RED` header             -> FAIL
#   2. `RED: n/a — <reason>` under the header  -> PASS. Blocking the sanctioned escape
#      hatch would push authors to fabricate REDs, one order worse than omitting one.
#   3. header present but the SECTION IS EMPTY -> FAIL. A header-presence grep passes
#      this, and would ship a check as hollow as the gap it closes.
#
# TWO ACCEPTED SHAPES, and which one applies is an EXPLICIT RULE, never grep order:
#   - `## Declared RED` present -> the six-element ac-* contract above decides, alone.
#   - `## Declared RED` absent  -> the ac2 schema (ac2-beadify/references/bead-schema.md),
#     where element 4's ASSERTION is carried by the ACs: EVERY top-level bullet of
#     `## Acceptance Criteria` must name an executable probe as ``Probe: `<command>` ``.
#     A bulletless AC section FAILS (vacuously "every bullet has a probe"), and PARTIAL
#     coverage FAILS — otherwise the widening degrades into "has an AC section".
set -uo pipefail

EXEMPT_TYPES="epic decision investigation"

usage() { sed -n '9,11p' "$0" >&2; exit 2; }

fail_bead() {
  printf 'element4-check: FAIL %s — %s\n' "$1" "$2" >&2
  RC=1
}

# check_ac2_probes <label> <description>
# The ac2 shape: no `## Declared RED`, element 4 carried by probe-carrying ACs.
# Header match is `br lint`-compatible — case-insensitive, trailing text allowed.
check_ac2_probes() {
  local label="$1" desc="$2"

  if ! printf '%s\n' "$desc" | grep -qiE '^## Acceptance[[:space:]]+Criteria'; then
    fail_bead "$label" "no '## Declared RED' header and no '## Acceptance Criteria' section — element 4 of the implementation contract is missing"
    return 1
  fi

  # Section body: everything after the AC header up to the next '## ' heading or EOF.
  local ac_body
  ac_body=$(printf '%s\n' "$desc" | awk '
    { low = tolower($0) }
    inac && low ~ /^## / { exit }
    inac { print; next }
    low ~ /^## acceptance[ \t]+criteria/ { inac = 1 }
  ')

  # One AC = one TOP-LEVEL bullet; indented lines are its continuation, which is where
  # the schema puts the probe. Any line of the block may carry it.
  local counts bullets probed
  counts=$(printf '%s\n' "$ac_body" | awk '
    /^[-*][ \t]+/ { if (cur && hasprobe) probed++; bullets++; cur = 1; hasprobe = 0 }
    cur && /Probe:[ \t]*`[^`]+`/ { hasprobe = 1 }
    END { if (cur && hasprobe) probed++; print bullets + 0, probed + 0 }
  ')
  bullets=${counts% *}; probed=${counts#* }

  if [ "$bullets" -eq 0 ]; then
    fail_bead "$label" "'## Acceptance Criteria' has no AC bullets — 'every AC names a probe' is vacuously true of zero ACs, so this declares nothing"
    return 1
  fi

  if [ "$probed" -lt "$bullets" ]; then
    fail_bead "$label" "no '## Declared RED' header, and $((bullets - probed)) of $bullets '## Acceptance Criteria' bullets name no executable probe (expected \`Probe: \`<command>\`\` on the AC) — element 4 of the implementation contract is missing"
    return 1
  fi

  printf 'element4-check: PASS %s (element 4 via probe-carrying ## Acceptance Criteria — %d/%d ACs name a probe)\n' "$label" "$probed" "$bullets"
  return 0
}

# check_description <label> <issue_type> <description>
check_description() {
  local label="$1" itype="$2" desc="$3"

  case " $EXEMPT_TYPES " in
    *" $itype "*) printf 'element4-check: SKIP %s (issue_type=%s is exempt)\n' "$label" "$itype"; return 0 ;;
  esac

  # Shape selection is a rule, not a race: a `## Declared RED` header, when present,
  # decides — even if the description ALSO carries probe-carrying ACs.
  if ! printf '%s\n' "$desc" | grep -qE '^## Declared RED[[:space:]]*$'; then
    check_ac2_probes "$label" "$desc"
    return $?
  fi

  # The section body: everything after the header up to the next '## ' heading or EOF.
  local body
  body=$(printf '%s\n' "$desc" | awk '
    /^## Declared RED[[:space:]]*$/ { inred=1; next }
    inred && /^## / { exit }
    inred { print }
  ')

  if [ -z "$(printf '%s' "$body" | tr -d '[:space:]')" ]; then
    fail_bead "$label" "'## Declared RED' section is EMPTY — a header alone declares nothing"
    return 1
  fi

  # Sanctioned n/a form: `RED: n/a` carries a reason on the same line.
  if printf '%s\n' "$body" | grep -qiE '^[[:space:]]*RED:[[:space:]]*n/a'; then
    if printf '%s\n' "$body" | grep -qiE '^[[:space:]]*RED:[[:space:]]*n/a[[:space:]]*([-—:]|--)[[:space:]]*[^[:space:]]'; then
      printf 'element4-check: PASS %s (element 4 via ## Declared RED — n/a with a stated reason)\n' "$label"
      return 0
    fi
    fail_bead "$label" "'RED: n/a' with no reason — the escape hatch requires 'RED: n/a — <why>'"
    return 1
  fi

  # RED-vs-Territory (bd friction: declared-red-not-reconciled-against-territory-or-existing-tests).
  # A RED that names a TEST file absent from the bead's own Territory is internally
  # contradictory: Territory wins at implement time, so the RED can never be satisfied
  # (bd-9uszd became a discovery bead this way). Test-shaped paths FAIL; other paths only
  # WARN, because a RED legitimately cites a source file it asserts ABOUT but never edits.
  # No `## Territory` section at all = legacy bead: skip, never fail on missing paperwork.
  local terr
  terr=$(printf '%s\n' "$desc" | awk '
    /^## Territory[[:space:]]*$/ { interr=1; next }
    interr && /^## / { exit }
    interr { print }
  ')
  if [ -n "$(printf '%s' "$terr" | tr -d '[:space:]')" ]; then
    local path
    for path in $(printf '%s\n' "$body" | grep -oE '[A-Za-z0-9_./-]+/[A-Za-z0-9_.-]+\.[A-Za-z0-9]+' | sort -u); do
      printf '%s\n' "$terr" | grep -qF "$path" && continue
      case "$path" in
        *.test.*|*.spec.*|tests/*|*/tests/*|__tests__/*|*/__tests__/*)
          fail_bead "$label" "Declared RED names test file '$path', absent from this bead's ## Territory — Territory wins at implement time, so this RED cannot be satisfied"
          return 1 ;;
        *)
          printf 'element4-check: WARN %s — Declared RED names '"'"'%s'"'"', absent from ## Territory. Fine if the bead only asserts ABOUT it; a defect if it must be edited.\n' "$label" "$path" >&2 ;;
      esac
    done
  fi

  # Advisory, never blocking: element 4's bar is that the ASSERTION is named, not merely
  # the test title. Not mechanically decidable, so warn and leave the judgement to refine.
  if ! printf '%s\n' "$body" | grep -qiE 'must FAIL|assert|expect|exit|violations|returns'; then
    printf 'element4-check: WARN %s — the section names no observable (assert/expect/exit code). Element 4 asks for the ASSERTION, not just the test title.\n' "$label" >&2
  fi
  printf 'element4-check: PASS %s (element 4 via ## Declared RED)\n' "$label"
  return 0
}

RC=0
if [ $# -eq 0 ]; then usage; fi

if [ "$1" = "--file" ]; then
  [ $# -ge 2 ] || usage
  FILE="$2"; shift 2
  ITYPE="task"
  if [ "${1:-}" = "--type" ]; then [ $# -ge 2 ] || usage; ITYPE="$2"; shift 2; fi
  [ -f "$FILE" ] || { echo "element4-check: ERROR — no such file: $FILE" >&2; exit 2; }
  check_description "$FILE" "$ITYPE" "$(cat "$FILE")"
  exit "$RC"
fi

for id in "$@"; do
  case "$id" in --*) usage ;; esac
  raw=$(br show --json "$id" 2>/dev/null || true)
  arr=$(printf '%s' "$raw" | jq 'if type == "array" then . else [] end' 2>/dev/null) || arr='[]'
  [ -n "$arr" ] || arr='[]'
  if [ "$(printf '%s' "$arr" | jq 'length')" -eq 0 ]; then
    echo "element4-check: ERROR — bead '$id' did not resolve via 'br show --json'" >&2
    exit 2
  fi
  itype=$(printf '%s' "$arr" | jq -r '.[0].issue_type // "task"')
  desc=$(printf '%s' "$arr" | jq -r '.[0].description // ""')
  check_description "$id" "$itype" "$desc"
done
exit "$RC"
