#!/usr/bin/env bash
# 22-ledger-integrity.test.sh — the fixture proving Check 22's contract.
#
#   PROBE: an entry citing a control the constitution does not define is RED;
#           a friction re-observed after its control landed is RED as a FAILED
#           CONTROL; a well-formed treated entry is GREEN; an EMPTY ledger
#           fails CLOSED (RED carrying NOT-GATED); an entry with unscorable
#           ordinals is RED as a named NOT-SCORABLE finding; a missing shared
#           parser or judge is NOT-GATED (exit 2); the real registry is GREEN
#           since 2026-09-09 — the live NOT-SCORABLE pin (ac-polish's
#           `frequency: sometimes`) was cured by a human-ledger edit in run
#           20260907-exhaust, so the ONE-friction-sensor pin now asserts the
#           fix holds. Entry counts are read at parse time (`.ledger.entries |
#           length`), never from a hand-kept frontmatter field — the ledgers
#           carry no `entries:` header (2026-09-12, Craig-decided lint audit:
#           the header was a stale copy concurrent appends raced on).
#
# ASSURANCE
#   PROBE:    bash lint/checks/22-ledger-integrity.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/22-ledger-integrity.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

build_tree() { # <root> <ledger-text|EMPTY> <with-rollup:yes|no>
  local w="$1" ledger="$2" rollup="$3"
  mkdir -p "$w/scripts" "$w/skills/skill-builder/scripts" "$w/skills/ac-pipeline"
  cp "$ROOT/scripts/ac-ledger-integrity.sh" "$w/scripts/"
  [ "$rollup" = yes ] && cp "$ROOT/skills/skill-builder/scripts/friction-rollup.py" "$w/skills/skill-builder/scripts/"
  cp "$ROOT/skills/ac-pipeline/SKILL.md" "$w/skills/ac-pipeline/"
  chmod +x "$w/scripts/"*.sh
  if [ "$ledger" != EMPTY ]; then printf '%s' "$ledger" > "$w/skills/ac-pipeline/FRICTIONS.md"; fi
}

# NOTE on entry shape: the judge reads the rollup TSV with `IFS=$'\t' read`,
# and tab is IFS whitespace, so an entry with an EMPTY MIDDLE field shifts every
# later column. Fixture entries therefore always carry receipt, control,
# control_landed and last_seen populated — the "entry names no control at all"
# class is undiagnosable at this layer (filed separately, discovered-from here).

LEDGER_OK='---
skill: ac-pipeline
created: 2026-09-07
last_pass: never
---

# fixture ledger

## fixture-friction
- skills: [ac-pipeline]
- impact: M
- frequency: every-run
- perceptibility: silent
- recurrence: 3
- first_seen: 2026-09-01
- last_seen: 2026-09-02
- status: closed
- receipt: somewhere (fixture)
- control: I1
- control_landed: 2026-08-27
'

# --- RED: a control the constitution does not define ----------------------------
w="$(mktemp -d)"
build_tree "$w" "$LEDGER_OK" yes
printf '%s' "$LEDGER_OK" | sed 's/^- control: I1$/- control: I99/' > "$w/skills/ac-pipeline/FRICTIONS.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "cites control 'I99', which the constitution does not define"; then
  ok "RED: unresolvable control -> exit 1 naming the entry"
else
  bad "RED case: expected 1 naming unresolvable control I99, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- RED: a FAILED CONTROL — friction re-observed after its control landed ------
w="$(mktemp -d)"
build_tree "$w" "$LEDGER_OK" yes
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "FAILED CONTROL"; then
  ok "RED: last_seen after control_landed -> exit 1 as a FAILED CONTROL"
else
  bad "failed-control case: expected 1 as FAILED CONTROL, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- RED: an empty ledger fails CLOSED ------------------------------------------
w="$(mktemp -d)"
build_tree "$w" EMPTY yes
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "NOT-GATED"; then
  ok "RED: absent ledger fails CLOSED (exit 1 carrying NOT-GATED)"
else
  bad "fail-closed case: expected 1 carrying NOT-GATED, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: a well-formed treated entry, friction not re-observed ----------------
w="$(mktemp -d)"
build_tree "$w" "$LEDGER_OK" yes
printf '%s' "$LEDGER_OK" | sed 's/^- last_seen: .*$/- last_seen: 2026-08-01/' > "$w/skills/ac-pipeline/FRICTIONS.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "contract holds both directions"; then
  ok "GREEN: well-formed ledger -> exit 0"
else
  bad "GREEN case: expected 0, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- RED: an entry with no scorable ordinals fails with a NAMED finding --------------
# The folded-in --strict class: an entry whose frequency/impact/recurrence is outside
# the schema's canonical set silently vanishes from the dream weights. Detection is
# automated; the ledger edit is human-gated — this check only REPORTS the finding.
w="$(mktemp -d)"
build_tree "$w" "$LEDGER_OK" yes
printf '%s' "$LEDGER_OK" \
  | sed 's/^- last_seen: .*$/- last_seen: 2026-08-01/' \
  | sed 's/^- frequency: every-run$/- frequency: sometimes/' > "$w/skills/ac-pipeline/FRICTIONS.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "NOT-SCORABLE: fixture-friction" \
   && ! printf '%s' "$out" | grep -q "FAILED CONTROL"; then
  ok "RED: unscorable ordinals -> exit 1 naming the NOT-SCORABLE finding only"
else
  bad "unscorable case: expected 1 naming NOT-SCORABLE only, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: entry count in the summary line is read at parse time, not from a
# hand-kept header (the ledgers carry no `entries:` field at all) -----------------
w="$(mktemp -d)"
build_tree "$w" "$LEDGER_OK" yes
printf '%s' "$LEDGER_OK" | sed 's/^- last_seen: .*$/- last_seen: 2026-08-01/' > "$w/skills/ac-pipeline/FRICTIONS.md"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "1 entr(y|ies)"; then
  ok "GREEN: entry count derived from the parsed ledger, no entries: header needed"
else
  bad "read-time-count case: expected 0 naming '1 entr(y|ies)', got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- NOT-GATED: the shared parser is missing from the audited tree ---------------
w="$(mktemp -d)"
build_tree "$w" "$LEDGER_OK" no
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-GATED"; then
  ok "NOT-GATED: missing shared parser -> exit 2, verified nothing"
else
  bad "NOT-GATED case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- NOT-GATED: the judge script is missing --------------------------------------
w="$(mktemp -d)"
mkdir -p "$w/skills/ac-pipeline"
out="$(python3 "$CHECK" "$w" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q "NOT-CHECKED"; then
  ok "NOT-GATED: missing judge -> exit 2, verified nothing"
else
  bad "missing-judge case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- the real registry: the ONE sensor sees a clean scorable ledger ------------------
# GREEN pin (2026-09-09): the live NOT-SCORABLE — ac-polish's seams-reader entry
# carrying `frequency: sometimes`, outside the schema's canonical set — was cured
# by a human-ledger edit (mapped to the honest nearest ordinal, `occasional`) in
# run 20260907-exhaust. This case now asserts the fix holds: exit 0, no
# NOT-SCORABLE named. If the ledger regresses, this case flips back to RED-first.
out="$(python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q "NOT-SCORABLE"; then
  ok "GREEN: the real registry's ledger is scorable — the live NOT-SCORABLE is cured"
else
  bad "real-tree case: expected 0 with no NOT-SCORABLE, got $rc"; printf '%s\n' "$out"
fi

echo "22-ledger-integrity.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
