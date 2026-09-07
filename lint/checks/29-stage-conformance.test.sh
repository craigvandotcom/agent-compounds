#!/usr/bin/env bash
# 29-stage-conformance.test.sh — the contract harness for lint/checks/29-stage-conformance.py.
#
#   PROBE: a hand-off the stage table does not carry is FAILED with the skill
#           named; a conforming tree PASSES; a backwards "hands off to" edge
#           is failed; "invoked BY" a downstream stage is failed while the
#           upstream form passes; declared aliases resolve; an allowlisted
#           violator passes, a clean allowlisted skill is refused (shrink),
#           and an added entry is refused against the committed base (growth);
#           a missing table is NOT-GATED (exit 2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/29-stage-conformance.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/29-stage-conformance.py"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
run_check() {
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

write_table() { # <root>
  mkdir -p "$1/skills/ac-pipeline/references"
  cat > "$1/skills/ac-pipeline/references/stage-table.md" <<'TBL'
| Stage | Owner skill | Trigger | Human gate | Artifact | Non-ac skills loaded |
|---|---|---|---|---|---|
| One | `ac-one` | on demand | none | report | — |
| Two | `ac-two` | after One | none | artifact | — |
| Three | `ac-three` | after Two | none | artifact | — |
TBL
}

# --- 1 RED: hand-off to a stage the table lacks -> exit 1, skill named -------
t="$work/red"; write_table "$t"
mkdir -p "$t/skills/ac-red"
printf '%s\n' '# ac-red' 'Hands off to ac-four — not a stage.' > "$t/skills/ac-red/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "ac-red/SKILL.md" "$OUT"; then
  ok "RED: non-carried hand-off failed, named"
else
  bad "RED: expected exit 1 naming the skill, got $rc"; cat "$OUT"
fi

# --- 2 GREEN: forward edges + aliases conform -> exit 0 ------------------------
t="$work/green"; write_table "$t"
mkdir -p "$t/skills/ac-green" "$t/skills/ac-entry"
printf '%s\n' '# ac-green' 'Hands off to ac-three. It ENDS by invoking ac-three.' > "$t/skills/ac-green/SKILL.md"
printf '%s\n' '# ac-entry' 'Optional pre-pass; hands off to the loop.' > "$t/skills/ac-entry/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: conforming edges and the loop alias pass"
else
  bad "GREEN: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 3 BACKWARDS: hands off to an UPSTREAM stage -> exit 1 ---------------------
t="$work/back"; write_table "$t"
mkdir -p "$t/skills/ac-three" "$t/skills/ac-one"
printf '%s\n' '# ac-three' 'Hands off to ac-one.' > "$t/skills/ac-three/SKILL.md"
printf '%s\n' '# ac-one' 'Hands off to ac-two.' > "$t/skills/ac-one/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "ac-three/SKILL.md" "$OUT" && ! grep -q "^  - ac-one/SKILL.md" "$OUT"; then
  ok "BACKWARDS: upstream target refused, forward edge passes"
else
  bad "BACKWARDS: expected exit 1 naming only ac-three, got $rc"; cat "$OUT"
fi

# --- 4 INVOKED BY: downstream refused, upstream passes -------------------------
t="$work/inv"; write_table "$t"
mkdir -p "$t/skills/ac-two" "$t/skills/ac-three"
printf '%s\n' '# ac-two' 'Invoked BY ac-three.' > "$t/skills/ac-two/SKILL.md"
printf '%s\n' '# ac-three' 'Invoked BY ac-one.' > "$t/skills/ac-three/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "ac-two/SKILL.md" "$OUT" && ! grep -q "^  - ac-three/SKILL.md" "$OUT"; then
  ok "INVOKED-BY: downstream invoker refused, upstream passes"
else
  bad "INVOKED-BY: expected exit 1 naming only ac-two, got $rc"; cat "$OUT"
fi

# --- 5 ALIAS: invoked BY the batch boundary resolves ---------------------------
t="$work/alias"; write_table "$t"
mkdir -p "$t/skills/ac-two"
printf '%s\n' '# ac-two' 'Invoked BY the batch boundary ("go").' > "$t/skills/ac-two/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 0 ] && grep -q "conforming" "$OUT"; then
  ok "ALIAS: the batch boundary resolves to the stage-1 invoker"
else
  bad "ALIAS: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 6 ALLOWLIST-OK: allowlisted violator passes -------------------------------
t="$work/alw-ok"; write_table "$t"
mkdir -p "$t/skills/ac-red" "$t/lint/allowlists"
printf '%s\n' '# ac-red' 'Hands off to ac-four.' > "$t/skills/ac-red/SKILL.md"
printf '%s\n' '# allowlist' 'ac-red' > "$t/lint/allowlists/29-stage-conformance.txt"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "ALLOWLIST-OK: allowlisted violator excused"
else
  bad "ALLOWLIST-OK: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 7 SHRINK: clean skill still allowlisted -> exit 1 -------------------------
t="$work/alw-stale"; write_table "$t"
mkdir -p "$t/skills/ac-clean" "$t/lint/allowlists"
printf '%s\n' '# ac-clean' 'Nothing declared here.' > "$t/skills/ac-clean/SKILL.md"
printf '%s\n' '# allowlist' 'ac-clean' > "$t/lint/allowlists/29-stage-conformance.txt"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "only shrinks: remove the entry" "$OUT"; then
  ok "SHRINK: stale allowlist entry refused"
else
  bad "SHRINK: expected exit 1 naming the shrink rule, got $rc"; cat "$OUT"
fi

# --- 8 GROWTH: entry added vs committed base -> exit 1 -------------------------
t="$work/alw-grow"; write_table "$t"
mkdir -p "$t/skills/ac-red" "$t/lint/allowlists"
printf '%s\n' '# ac-red' 'Hands off to ac-four.' > "$t/skills/ac-red/SKILL.md"
printf '%s\n' '# allowlist' > "$t/lint/allowlists/29-stage-conformance.txt"
git -C "$t" init -q
git -C "$t" -c user.name=h -c user.email=h@x add -A
git -C "$t" -c user.name=h -c user.email=h@x commit -qm base
BASE_SHA=$(git -C "$t" rev-parse HEAD)
git -C "$t" update-ref refs/remotes/origin/main "$BASE_SHA"
printf '%s\n' '# allowlist' 'ac-red' > "$t/lint/allowlists/29-stage-conformance.txt"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "allowlist GREW" "$OUT"; then
  ok "GROWTH: added allowlist entry refused"
else
  bad "GROWTH: expected exit 1 naming growth, got $rc"; cat "$OUT"
fi

# --- 9 NOT-GATED: no table -> exit 2 -------------------------------------------
t="$work/empty"
mkdir -p "$t/skills/ac-lonely"
printf '%s\n' '# ac-lonely' 'Hands off to ac-two.' > "$t/skills/ac-lonely/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no stage table -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 29-stage-conformance contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
