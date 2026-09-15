#!/usr/bin/env bash
# plan-approve.test.sh — RED/GREEN over every plan-approve.sh verdict, all three modes
# (ac-ympj.1). Fixtures cover: approve writing four identity keys + the internal section
# ledger; every approve refusal (needs-human, no-decisions, no-seams, seams-incomplete,
# uncited-decision, no-approver); ready writing bead-ready + regate: none on a matching
# digest; regate firing on an edit INSIDE a gated section and staying silent on an edit
# OUTSIDE one; ready's not-polished / not-approved refusals; check's OK / missing-keys /
# status / digest-mismatch verdicts, including a `## Deliverables (artifacts)` fixture
# (the documented prefix-match case) and a retired-plan-shaped `status: done` pass; the
# bare positional / missing-mode form refusing; the AM_SELF/BR_AGENT_NAME fallback being
# gone; and approval keys surviving `polish-fixpoint.sh --mode plan` across two rounds.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/plan-approve.sh"
PF="$HERE/polish-fixpoint.sh"
FAILURES=0
CASES=0

expect() {
  CASES=$((CASES + 1))
  if [ "$1" = "$2" ]; then
    printf '  PASS  %s\n' "$3"
  else
    printf '  FAIL  %s (want %s got %s)\n' "$3" "$2" "$1"
    FAILURES=$((FAILURES + 1))
  fi
}

W=$(mktemp -d /tmp/plan-approve-test-XXXXXX)

# A Deliverable path with a ## Seams row carrying the same FULL path, so the
# seams-complete fixtures exercise the full-path row requirement (ac-zug5.1: rows
# match by full path, never basename, and exempt nothing).
REAL_PATH="skills/_tools/touchers.sh"

vision_line='writes the vision back in plain prose'

mk_plan() {
  # mk_plan <file> <deliverables-body> <decisions-body> <seams-body> [extra-frontmatter]
  local file="$1" deliv="$2" dec="$3" seams="$4" extra="${5:-}"
  {
    printf -- '---\nstatus: draft\ncreated: 2026-09-05\n'
    [ -n "$extra" ] && printf '%s\n' "$extra"
    printf -- '---\n# Plan\n\n## Vision\n\n%s\n\n## Deliverables\n\n%s\n\n## Decisions\n\n%s\n\n## Seams\n\n%s\n\n## Out of scope\n\n- nothing\n\n## Success criterion\n\nSome criterion.\n' \
      "$vision_line" "$deliv" "$dec" "$seams"
  } > "$file"
}

SETTLED_CARD="- **A fork?** Options: a, b. **settled: a (Craig).** vision: \"$vision_line\""
SEAMS_OK="| object | finding | disposition |
| --- | --- | --- |
| \`$REAL_PATH\` | some finding | -> D1 |"

# 1 — approve on a clean plan -> APPROVED, four identity keys + the internal ledger written
mk_plan "$W/p1.md" "- **D1 \`$REAL_PATH\`** — a thing." "$SETTLED_CARD" "$SEAMS_OK"
OUT=$("$SCRIPT" approve "$W/p1.md" "Craig")
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "clean plan -> APPROVED"
expect "$(grep -c '^status: approved$' "$W/p1.md")" 1 "approve writes status: approved"
expect "$(grep -c '^approved_by: Craig$' "$W/p1.md")" 1 "approve writes approved_by"
expect "$(grep -c '^approved_at:' "$W/p1.md")" 1 "approve writes approved_at"
expect "$(grep -c '^approved_sha256:' "$W/p1.md")" 1 "approve writes approved_sha256"
expect "$(grep -c '^approved_section_digest:' "$W/p1.md")" 1 "approve writes the internal section ledger"

# 2 — approve refuses an open Decision card
mk_plan "$W/p2.md" "- D1 x" "- **A fork?** Options: a, b. **needs-human**" "a"
OUT=$("$SCRIPT" approve "$W/p2.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED needs-human 1' <<<"$OUT")" 1 "open Decision card -> REFUSED needs-human 1"
expect "$(grep -c '^status: draft$' "$W/p2.md")" 1 "refused plan is not re-stamped"

# 3 — approve refuses a missing ## Decisions section
{
  printf -- '---\nstatus: draft\n---\n# Plan\n\n## Vision\n\nv\n\n## Deliverables\n\n- D1 x\n\n## Seams\n\na\n\n## Out of scope\n\nn\n\n## Success criterion\n\ns\n'
} > "$W/p3.md"
OUT=$("$SCRIPT" approve "$W/p3.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED no-decisions' <<<"$OUT")" 1 "no ## Decisions -> REFUSED no-decisions"

# 4 — approve refuses a missing ## Seams section
{
  printf -- '---\nstatus: draft\n---\n# Plan\n\n## Vision\n\nv\n\n## Deliverables\n\n- D1 x\n\n## Decisions\n\n%s\n\n## Out of scope\n\nn\n\n## Success criterion\n\ns\n' "$SETTLED_CARD"
} > "$W/p4.md"
OUT=$("$SCRIPT" approve "$W/p4.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED no-seams' <<<"$OUT")" 1 "no ## Seams -> REFUSED no-seams"

# 5 — approve refuses an existing Deliverable path with no ## Seams row
mk_plan "$W/p5.md" "- **D1 \`$REAL_PATH\`** — a thing." "$SETTLED_CARD" "| object | finding | disposition |
| --- | --- | --- |
| \`unrelated-name\` | x | -> D1 |"
OUT=$("$SCRIPT" approve "$W/p5.md" "Craig" 2>&1)
expect "$(grep -c "REFUSED seams-incomplete $REAL_PATH" <<<"$OUT")" 1 "existing path with no Seams row -> REFUSED seams-incomplete"

# 6 — approve refuses a settled card with no vision: quote
mk_plan "$W/p6.md" "- D1 x" "- **A fork?** Options: a, b. **settled: a (Craig).**" "a"
OUT=$("$SCRIPT" approve "$W/p6.md" "Craig" 2>&1)
expect "$(grep -c 'REFUSED uncited-decision 1' <<<"$OUT")" 1 "settled card with no vision quote -> REFUSED uncited-decision 1"

# 7 — approve refuses an explicitly empty approver
mk_plan "$W/p7.md" "- D1 x" "$SETTLED_CARD" "a"
OUT=$("$SCRIPT" approve "$W/p7.md" "" 2>&1)
expect "$(grep -c 'REFUSED no-approver' <<<"$OUT")" 1 "empty approver -> REFUSED no-approver"

# 8 — approve with no second arg defaults to git config user.name; the value is injected
#     through git's env config so the case does not depend on the host (CI has none set)
mk_plan "$W/p8.md" "- D1 x" "$SETTLED_CARD" "a"
OUT=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=ci-tester "$SCRIPT" approve "$W/p8.md" 2>&1)
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "omitted approver falls back to git config user.name"
expect "$(grep -c '^approved_by: ci-tester$' "$W/p8.md")" 1 "the git user.name is what gets written"

# 8b — no second arg AND no git user.name anywhere -> REFUSED no-approver, nothing written
mk_plan "$W/p8b.md" "- D1 x" "$SETTLED_CARD" "a"
OUT=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0= "$SCRIPT" approve "$W/p8b.md" 2>&1)
expect "$(grep -c 'REFUSED no-approver' <<<"$OUT")" 1 "empty git user.name and no arg -> REFUSED no-approver"
expect "$(grep -c '^approved_by:' "$W/p8b.md")" 0 "a refused approve writes no approver"

# 9 — missing plan file -> NOT-GATED
OUT=$("$SCRIPT" approve "$W/absent.md" "Craig" 2>&1)
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "missing plan -> NOT-GATED"

# 10 — the bare positional form (no mode) refuses; so does an unknown mode
OUT=$("$SCRIPT" "$W/p1.md" "Craig" 2>&1)
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "bare positional form (no mode) -> NOT-GATED"
OUT=$("$SCRIPT" frobnicate "$W/p1.md" 2>&1)
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "unknown mode -> NOT-GATED"

# 11 — the AM_SELF / BR_AGENT_NAME agent-identity fallback is entirely gone
expect "$(grep -cE 'AM_SELF|BR_AGENT_NAME' "$SCRIPT")" 0 "AM_SELF/BR_AGENT_NAME fallback is gone from the script"

# --- ready mode -----------------------------------------------------------------------

add_polish_keys() {
  # Simulate a polish stamp without running the reader loop: the two keys ready() checks.
  local file="$1"
  sed -i '2a polish_rounds: 2\npolish_fixpoint_sha256: deadbeef' "$file"
}

# 12 — ready refuses not-polished before polish keys exist
mk_plan "$W/r1.md" "- D1 x" "$SETTLED_CARD" "a"
"$SCRIPT" approve "$W/r1.md" "Craig" >/dev/null
OUT=$("$SCRIPT" ready "$W/r1.md" 2>&1)
expect "$(grep -c 'REFUSED not-polished' <<<"$OUT")" 1 "ready before polish -> REFUSED not-polished"

# 13 — ready refuses not-approved when status never reached approved
mk_plan "$W/r2.md" "- D1 x" "$SETTLED_CARD" "a"
add_polish_keys "$W/r2.md"
OUT=$("$SCRIPT" ready "$W/r2.md" 2>&1)
expect "$(grep -c 'REFUSED not-approved' <<<"$OUT")" 1 "ready on a never-approved plan -> REFUSED not-approved"

# 14 — ready with a matching digest -> READY, writes bead-ready + regate: none
mk_plan "$W/r3.md" "- D1 x" "$SETTLED_CARD" "a"
"$SCRIPT" approve "$W/r3.md" "Craig" >/dev/null
add_polish_keys "$W/r3.md"
OUT=$("$SCRIPT" ready "$W/r3.md" 2>&1)
expect "$(grep -c '^READY:' <<<"$OUT")" 1 "matching digest -> READY"
expect "$(grep -c '^status: bead-ready$' "$W/r3.md")" 1 "ready writes status: bead-ready"
expect "$(grep -c '^bead_ready_at:' "$W/r3.md")" 1 "ready writes bead_ready_at"
expect "$(grep -c '^regate: none$' "$W/r3.md")" 1 "ready writes regate: none"

# 15 — ready after an edit INSIDE ## Deliverables -> REFUSED regate Deliverables
mk_plan "$W/r4.md" "- **D1 \`$REAL_PATH\`** — a thing." "$SETTLED_CARD" "$SEAMS_OK"
"$SCRIPT" approve "$W/r4.md" "Craig" >/dev/null
add_polish_keys "$W/r4.md"
sed -i 's/a thing\./a DIFFERENT thing./' "$W/r4.md"
OUT=$("$SCRIPT" ready "$W/r4.md" 2>&1)
expect "$(grep -c '^REFUSED regate Deliverables$' <<<"$OUT")" 1 "edit inside ## Deliverables -> REFUSED regate Deliverables"

# 16 — ready after an edit OUTSIDE every gated section -> READY
mk_plan "$W/r5.md" "- D1 x" "$SETTLED_CARD" "a" "amended_after_stamp: an ungated frontmatter note"
"$SCRIPT" approve "$W/r5.md" "Craig" >/dev/null
add_polish_keys "$W/r5.md"
sed -i 's/an ungated frontmatter note/a DIFFERENT ungated frontmatter note/' "$W/r5.md"
OUT=$("$SCRIPT" ready "$W/r5.md" 2>&1)
expect "$(grep -c '^READY:' <<<"$OUT")" 1 "edit outside every gated section -> READY, no regate"

# --- check mode -------------------------------------------------------------------------

# 17 — check refuses missing-keys before any approval
mk_plan "$W/c1.md" "- D1 x" "$SETTLED_CARD" "a"
OUT=$("$SCRIPT" check "$W/c1.md" 2>&1)
expect "$(grep -c 'REFUSED missing-keys' <<<"$OUT")" 1 "check with no approval keys -> REFUSED missing-keys"

# 18 — check refuses status <status> when approved but not yet ready
mk_plan "$W/c2.md" "- D1 x" "$SETTLED_CARD" "a"
"$SCRIPT" approve "$W/c2.md" "Craig" >/dev/null
OUT=$("$SCRIPT" check "$W/c2.md" 2>&1)
expect "$(grep -c 'REFUSED status approved' <<<"$OUT")" 1 "check on approved-but-not-ready -> REFUSED status approved"

# 19 — check passes OK on a bead-ready plan
mk_plan "$W/c3.md" "- D1 x" "$SETTLED_CARD" "a"
"$SCRIPT" approve "$W/c3.md" "Craig" >/dev/null
add_polish_keys "$W/c3.md"
"$SCRIPT" ready "$W/c3.md" >/dev/null
OUT=$("$SCRIPT" check "$W/c3.md" 2>&1)
expect "$(grep -c '^OK:' <<<"$OUT")" 1 "bead-ready plan -> check OK"

# 20 — check also passes on a retired plan's shape: status: done, keys untouched since ready
mk_plan "$W/c4.md" "- D1 x" "$SETTLED_CARD" "a"
"$SCRIPT" approve "$W/c4.md" "Craig" >/dev/null
add_polish_keys "$W/c4.md"
"$SCRIPT" ready "$W/c4.md" >/dev/null
sed -i 's/^status: bead-ready$/status: done/' "$W/c4.md"
OUT=$("$SCRIPT" check "$W/c4.md" 2>&1)
expect "$(grep -c '^OK:' <<<"$OUT")" 1 "retired (status: done) plan -> check OK"

# 21 — check refuses digest-mismatch when a gated section moved after the approval record
mk_plan "$W/c5.md" "- **D1 \`$REAL_PATH\`** — a thing." "$SETTLED_CARD" "$SEAMS_OK"
"$SCRIPT" approve "$W/c5.md" "Craig" >/dev/null
add_polish_keys "$W/c5.md"
"$SCRIPT" ready "$W/c5.md" >/dev/null
sed -i 's/a thing\./a THIRD thing./' "$W/c5.md"
OUT=$("$SCRIPT" check "$W/c5.md" 2>&1)
expect "$(grep -c 'REFUSED digest-mismatch' <<<"$OUT")" 1 "gated section moved after ready -> REFUSED digest-mismatch"

# 22 — the documented `## Deliverables (artifacts)` prefix-match fixture: approve, then
# ready with no edits -> both succeed against the variant header.
{
  printf -- '---\nstatus: draft\n---\n# Plan\n\n## Vision\n\n%s\n\n## Deliverables (artifacts)\n\n- **D1 `%s`** — a thing.\n\n## Decisions\n\n%s\n\n## Seams\n\n%s\n\n## Out of scope\n\n- nothing\n\n## Success criterion\n\nSome criterion.\n' \
    "$vision_line" "$REAL_PATH" "$SETTLED_CARD" "$SEAMS_OK"
} > "$W/artifacts.md"
OUT=$("$SCRIPT" approve "$W/artifacts.md" "Craig" 2>&1)
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "## Deliverables (artifacts) header -> APPROVED"
add_polish_keys "$W/artifacts.md"
OUT=$("$SCRIPT" ready "$W/artifacts.md" 2>&1)
expect "$(grep -c '^READY:' <<<"$OUT")" 1 "## Deliverables (artifacts) header with no edits -> READY"

# 23 — approve is re-runnable (the re-approve half of the regate flow): approving twice on
# an unchanged plan still succeeds and re-stamps a fresh approved_at.
mk_plan "$W/reapp.md" "- D1 x" "$SETTLED_CARD" "a"
"$SCRIPT" approve "$W/reapp.md" "Craig" >/dev/null
OUT=$("$SCRIPT" approve "$W/reapp.md" "Craig" 2>&1)
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "re-approve on an unchanged plan -> APPROVED again"
expect "$(grep -c '^approved_by: Craig$' "$W/reapp.md")" 1 "re-approve keeps exactly one approved_by line"

# --- gotcha: approved keys survive polish-fixpoint.sh --mode plan -----------------------

mk_plan "$W/pf.md" "- D1 x" "$SETTLED_CARD" "a"
"$SCRIPT" approve "$W/pf.md" "Craig" >/dev/null
BEFORE_KEYS=$(grep '^approved_' "$W/pf.md" | sort)
STATE=$(mktemp -d /tmp/plan-approve-test-pf-XXXXXX)
sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi; }
D1=$(sha "$W/pf.md")
"$PF" --state "$STATE" --artifact "$W/pf.md" --round 1 --pre "$D1" --mode plan >/dev/null 2>&1
D2=$(sha "$W/pf.md")
"$PF" --state "$STATE" --artifact "$W/pf.md" --round 2 --pre "$D2" --findings 0 --mode plan >/dev/null 2>&1
AFTER_KEYS=$(grep '^approved_' "$W/pf.md" | sort)
expect "$([ "$BEFORE_KEYS" = "$AFTER_KEYS" ] && echo same)" "same" "approved_* keys survive polish-fixpoint.sh --mode plan across two rounds"
expect "$(grep -c '^polish_rounds: 2$' "$W/pf.md")" 1 "polish-fixpoint still stamps its own keys on the same file"
rm -rf "$STATE"

rm -rf "$W"
printf 'plan-approve.test: %s cases, %s failures\n' "$CASES" "$FAILURES"
[ "$FAILURES" -eq 0 ]
