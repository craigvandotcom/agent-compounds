#!/usr/bin/env bash
# plan-approve.test.sh — RED/GREEN over every plan-approve.sh verdict, all three modes
# (ac-ympj.1, hardened ac-zug5.2). Every verdict case asserts the EXIT CODE as well as
# the token, so weakening a refusal (or zeroing an exit) turns a case red. Decision
# fixtures use the one card grammar decisions.md prescribes — a top-level `-` bullet
# plus `-` or `+` sub-bullets (both shapes pinned: ac-zug5.13), plain `settled:`,
# `vision:` quoting the ## Vision line on its own sub-bullet — because the shipped
# parser groups a card as one top-level bullet block; a one-line bold card is a
# shape the grammar never prescribes. Coverage: a
# failing polarity for every gated section (Vision, Deliverables, Decisions, Out of
# scope, Success criterion, Seams, Human gates) and every refusal token (needs-human,
# no-decisions, no-seams, seams-incomplete, uncited-decision, no-approver,
# not-polished, not-approved, regate, digest-mismatch, NOT-GATED); a `## Success
# Criteria` (capital-C) fixture proving the SuccessCriterion digest leg hashes real
# content instead of empty; a no-sha-tool case asserting exit 2; and the whole suite
# runs from any cwd (it parks itself in TMPDIR before the first case).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/plan-approve.sh"
PF="$HERE/polish-fixpoint.sh"
BASH_BIN="$(command -v bash)"
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

# cap runs the script, banking stdout in $OUT and the exit code in $RC: every
# verdict case then asserts BOTH, so a refusal that prints right but exits
# wrong (or vice versa) still goes red.
cap() {
  OUT=$("$@" 2>&1); RC=$?
}

W=$(mktemp -d /tmp/plan-approve-test-XXXXXX)

# The suite never depends on the invoking cwd: everything it touches travels by
# absolute path, and it parks itself in TMPDIR before the first case.
cd "${TMPDIR:-/tmp}" || exit 2

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

# The prescribed card: top-level `-` bullet, `+` sub-bullets, plain `settled:`,
# `vision:` quoting the ## Vision line on its own sub-bullet.
SETTLED_CARD="- **A fork?**
  + options: a, b.
  + settled: a (Alex).
  + vision: \"$vision_line\""
OPEN_CARD="- **A fork?**
  + options: a, b.
  + needs-human"
NOVISION_CARD="- **A fork?**
  + options: a, b.
  + settled: a (Alex)."
# needs-human beats settled: a card carrying both the open token and a settled
# line is refused as open — settled+needs-human never settles silently.
BOTH_CARD="- **A fork?**
  + options: a, b.
  + needs-human
  + settled: a (Alex).
  + vision: \"$vision_line\""
# The prescribed `-` sub-bullet shape (ac-zug5.13): same grammar as above with the
# `-` sub-bullet marker decisions.md prescribes — the parser used to split every
# `-` line into its own block and false-refuse the card as uncited-decision.
SETTLED_DASH_CARD="- **A fork?**
  - options: a, b.
  - settled: a (Alex).
  - vision: \"$vision_line\""
OPEN_DASH_CARD="- **A fork?**
  - options: a, b.
  - needs-human"
NOVISION_DASH_CARD="- **A fork?**
  - options: a, b.
  - settled: a (Alex)."
SEAMS_OK="| object | finding | disposition |
| --- | --- | --- |
| \`$REAL_PATH\` | some finding | -> D1 |"

# 1 — approve on a clean plan -> APPROVED (exit 0), identity keys + ledger written
mk_plan "$W/p1.md" "- **D1 \`$REAL_PATH\`** — a thing." "$SETTLED_CARD" "$SEAMS_OK"
cap "$SCRIPT" approve "$W/p1.md" "Alex"
expect "$RC" 0 "clean plan -> exit 0"
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "clean plan -> APPROVED"
expect "$(grep -c '^status: approved$' "$W/p1.md")" 1 "approve writes status: approved"
expect "$(grep -c '^approved_by: Alex$' "$W/p1.md")" 1 "approve writes approved_by"
expect "$(grep -c '^approved_at:' "$W/p1.md")" 1 "approve writes approved_at"
expect "$(grep -c '^approved_sha256:' "$W/p1.md")" 1 "approve writes approved_sha256"
expect "$(grep -c '^approved_section_digest:' "$W/p1.md")" 1 "approve writes the internal section ledger"

# 2 — approve refuses an open Decision card (exit 1)
mk_plan "$W/p2.md" "- D1 x" "$OPEN_CARD" "a"
cap "$SCRIPT" approve "$W/p2.md" "Alex"
expect "$RC" 1 "open Decision card -> exit 1"
expect "$(grep -c 'REFUSED needs-human 1' <<<"$OUT")" 1 "open Decision card -> REFUSED needs-human 1"
expect "$(grep -c '^status: draft$' "$W/p2.md")" 1 "refused plan is not re-stamped"

# 3 — a card carrying both needs-human and settled: is refused as OPEN (exit 1)
mk_plan "$W/p2b.md" "- D1 x" "$BOTH_CARD" "a"
cap "$SCRIPT" approve "$W/p2b.md" "Alex"
expect "$RC" 1 "needs-human + settled card -> exit 1"
expect "$(grep -c 'REFUSED needs-human 1' <<<"$OUT")" 1 "needs-human beats settled: both-tokens card -> REFUSED needs-human 1"
expect "$(grep -c '^status: draft$' "$W/p2b.md")" 1 "both-tokens plan is not re-stamped"

# 3b — the prescribed `-` sub-bullet card approves (ac-zug5.13)
mk_plan "$W/p1dash.md" "- D1 x" "$SETTLED_DASH_CARD" "a"
cap "$SCRIPT" approve "$W/p1dash.md" "Alex"
expect "$RC" 0 "dash sub-bullet card -> exit 0"
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "dash sub-bullet card -> APPROVED"

# 3c — a dash open card is still refused as open: the grouping fix must not swallow needs-human
mk_plan "$W/p2dash.md" "- D1 x" "$OPEN_DASH_CARD" "a"
cap "$SCRIPT" approve "$W/p2dash.md" "Alex"
expect "$RC" 1 "dash open card -> exit 1"
expect "$(grep -c 'REFUSED needs-human 1' <<<"$OUT")" 1 "dash open card -> REFUSED needs-human 1"

# 3d — a dash settled card with no vision quote is still refused as uncited
mk_plan "$W/p6dash.md" "- D1 x" "$NOVISION_DASH_CARD" "a"
cap "$SCRIPT" approve "$W/p6dash.md" "Alex"
expect "$RC" 1 "dash settled card with no vision quote -> exit 1"
expect "$(grep -c 'REFUSED uncited-decision 1' <<<"$OUT")" 1 "dash settled card with no vision quote -> REFUSED uncited-decision 1"

# 4 — approve refuses a missing ## Decisions section (exit 1)
{
  printf -- '---\nstatus: draft\n---\n# Plan\n\n## Vision\n\nv\n\n## Deliverables\n\n- D1 x\n\n## Seams\n\na\n\n## Out of scope\n\nn\n\n## Success criterion\n\ns\n'
} > "$W/p3.md"
cap "$SCRIPT" approve "$W/p3.md" "Alex"
expect "$RC" 1 "no ## Decisions -> exit 1"
expect "$(grep -c 'REFUSED no-decisions' <<<"$OUT")" 1 "no ## Decisions -> REFUSED no-decisions"

# 5 — approve refuses a missing ## Seams section (exit 1)
{
  printf -- '---\nstatus: draft\n---\n# Plan\n\n## Vision\n\nv\n\n## Deliverables\n\n- D1 x\n\n## Decisions\n\n%s\n\n## Out of scope\n\nn\n\n## Success criterion\n\ns\n' "$SETTLED_CARD"
} > "$W/p4.md"
cap "$SCRIPT" approve "$W/p4.md" "Alex"
expect "$RC" 1 "no ## Seams -> exit 1"
expect "$(grep -c 'REFUSED no-seams' <<<"$OUT")" 1 "no ## Seams -> REFUSED no-seams"

# 6 — approve refuses an existing Deliverable path with no ## Seams row (exit 1)
mk_plan "$W/p5.md" "- **D1 \`$REAL_PATH\`** — a thing." "$SETTLED_CARD" "| object | finding | disposition |
| --- | --- | --- |
| \`unrelated-name\` | x | -> D1 |"
cap "$SCRIPT" approve "$W/p5.md" "Alex"
expect "$RC" 1 "existing path with no Seams row -> exit 1"
expect "$(grep -c "REFUSED seams-incomplete $REAL_PATH" <<<"$OUT")" 1 "existing path with no Seams row -> REFUSED seams-incomplete"

# 6a — a ROOT-LEVEL and a +-bearing Deliverable with no ## Seams row are both refused
# (ac-wszw): the pre-widening extractor here required a slash and stopped a match at a
# `+`, so both paths extracted to NOTHING and seams-incomplete APPROVED a plan whose
# Deliverables had no Seams rows — the fail-open this fixture pins. Both paths sort
# (artifact.txt before skills/...), so the refusal names them in that order.
ROOTLEVEL_PATH="artifact.txt"
PLUSBARING_PATH="skills/demo/pl+us.txt"
mk_plan "$W/p5root.md" "- **D1 \`$ROOTLEVEL_PATH\`** — a root-level thing.
- **D2 \`$PLUSBARING_PATH\`** — a plus-bearing thing." "$SETTLED_CARD" "| object | finding | disposition |
| --- | --- | --- |
| \`unrelated-name\` | x | -> D1 |"
cap "$SCRIPT" approve "$W/p5root.md" "Alex"
expect "$RC" 1 "root-level / +-bearing Deliverable with no Seams row -> exit 1"
expect "$(grep -c "REFUSED seams-incomplete $ROOTLEVEL_PATH $PLUSBARING_PATH" <<<"$OUT")" 1 "root-level / +-bearing Deliverable with no Seams row -> REFUSED seams-incomplete"
expect "$(grep -c '^status: draft$' "$W/p5root.md")" 1 "refused root-level plan is not re-stamped"

# 6a2 — the same two paths WITH matching ## Seams rows approve (exit 0): the widened
# extractor reads them, and the Seams match is by FULL path, so the refusal above is the
# missing rows, not an over-broad pattern.
mk_plan "$W/p5root-ok.md" "- **D1 \`$ROOTLEVEL_PATH\`** — a root-level thing.
- **D2 \`$PLUSBARING_PATH\`** — a plus-bearing thing." "$SETTLED_CARD" "| object | finding | disposition |
| --- | --- | --- |
| \`$ROOTLEVEL_PATH\` | x | -> D1 |
| \`$PLUSBARING_PATH\` | y | -> D2 |"
cap "$SCRIPT" approve "$W/p5root-ok.md" "Alex"
expect "$RC" 0 "root-level / +-bearing Deliverables with Seams rows -> exit 0"
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "root-level / +-bearing Deliverables with Seams rows -> APPROVED"

# 6a3 — the shape-equality pin (ac-wszw): the Delivers-path token pattern is ONE shape in
# three homes, and this test fails the moment one drifts. Extract the `grep -oE` pattern line
# from each home, strip indentation and the trailing continuation backslash, and compare.
TOUCHERS="$HERE/touchers.sh"
CLOSE_GATE="$HERE/../ac-implement/scripts/close-gate.sh"
shape_line() { grep -m1 -F "(\./)?[][A-Za-z0-9_@.()" "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*\\$//'; }
PA_SHAPE=$(shape_line "$SCRIPT")
TOUCHERS_SHAPE=$(shape_line "$TOUCHERS")
CLOSE_GATE_SHAPE=$(shape_line "$CLOSE_GATE")
expect "$([ -n "$PA_SHAPE" ] && echo present)" "present" "plan-approve carries the Delivers-path shape"
expect "$TOUCHERS_SHAPE" "$PA_SHAPE" "touchers.sh carries the same shape as plan-approve"
expect "$CLOSE_GATE_SHAPE" "$PA_SHAPE" "close-gate.sh carries the same shape as plan-approve"

# 6b — a seams-mode hand-off's reader-diagnosis header ("## Seams — seen by more than one
# lens" and its kin) must never satisfy the no-seams refusal by PREFIX (ac-4y7l.3): a plan
# carrying only a look-alike header, and no exact ## Seams section, is still refused.
{
  printf -- '---\nstatus: draft\n---\n# Plan\n\n## Vision\n\nv\n\n## Deliverables\n\n- D1 x\n\n## Decisions\n\n%s\n\n## Seams — seen by more than one lens\n\nsome reader evidence, never the real Seams table\n\n## Out of scope\n\nn\n\n## Success criterion\n\ns\n' "$SETTLED_CARD"
} > "$W/p5b.md"
cap "$SCRIPT" approve "$W/p5b.md" "Alex"
expect "$RC" 1 "look-alike Seams header -> REFUSED no-seams exit 1"
expect "$(grep -c 'REFUSED no-seams' <<<"$OUT")" 1 "look-alike Seams header -> REFUSED no-seams"

# 7 — approve refuses a settled card with no vision: quote (exit 1)
mk_plan "$W/p6.md" "- D1 x" "$NOVISION_CARD" "a"
cap "$SCRIPT" approve "$W/p6.md" "Alex"
expect "$RC" 1 "settled card with no vision quote -> exit 1"
expect "$(grep -c 'REFUSED uncited-decision 1' <<<"$OUT")" 1 "settled card with no vision quote -> REFUSED uncited-decision 1"

# 8 — approve refuses an explicitly empty approver (exit 1)
mk_plan "$W/p7.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/p7.md" ""
expect "$RC" 1 "empty approver -> exit 1"
expect "$(grep -c 'REFUSED no-approver' <<<"$OUT")" 1 "empty approver -> REFUSED no-approver"

# 9 — approve with no second arg defaults to git config user.name; the value is injected
#     through git's env config so the case does not depend on the host (CI has none set)
mk_plan "$W/p8.md" "- D1 x" "$SETTLED_CARD" "a"
OUT=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=ci-tester "$SCRIPT" approve "$W/p8.md" 2>&1); RC=$?
expect "$RC" 0 "omitted approver falls back to git config user.name -> exit 0"
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "omitted approver falls back to git config user.name"
expect "$(grep -c '^approved_by: ci-tester$' "$W/p8.md")" 1 "the git user.name is what gets written"

# 10 — no second arg AND no git user.name anywhere -> REFUSED no-approver (exit 1)
mk_plan "$W/p8b.md" "- D1 x" "$SETTLED_CARD" "a"
OUT=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0= "$SCRIPT" approve "$W/p8b.md" 2>&1); RC=$?
expect "$RC" 1 "empty git user.name and no arg -> exit 1"
expect "$(grep -c 'REFUSED no-approver' <<<"$OUT")" 1 "empty git user.name and no arg -> REFUSED no-approver"
expect "$(grep -c '^approved_by:' "$W/p8b.md")" 0 "a refused approve writes no approver"

# 10b — a polluted environment cannot smuggle an approver past the git default:
# any env fallback re-added under another name would land its sentinel here.
mk_plan "$W/p8c.md" "- D1 x" "$SETTLED_CARD" "a"
OUT=$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=ci-tester APPROVER=env-sentinel APPROVED_BY=env-sentinel PLAN_APPROVER=env-sentinel AGENT_NAME=env-sentinel AGENT_IDENTITY=env-sentinel "$SCRIPT" approve "$W/p8c.md" 2>&1); RC=$?
expect "$RC" 0 "polluted env with no arg -> exit 0"
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "polluted env with no arg -> APPROVED via git user.name"
expect "$(grep -c '^approved_by: ci-tester$' "$W/p8c.md")" 1 "polluted env leaves the git user.name as approver"
expect "$(grep -c 'env-sentinel' "$W/p8c.md")" 0 "no env value leaks into the approval record"

# 11 — missing plan file -> NOT-GATED (exit 2, never a refusal)
cap "$SCRIPT" approve "$W/absent.md" "Alex"
expect "$RC" 2 "missing plan -> exit 2"
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "missing plan -> NOT-GATED"

# 12 — the bare positional form (no mode) refuses; so does an unknown mode (exit 2)
cap "$SCRIPT" "$W/p1.md" "Alex"
expect "$RC" 2 "bare positional form (no mode) -> exit 2"
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "bare positional form (no mode) -> NOT-GATED"
cap "$SCRIPT" frobnicate "$W/p1.md"
expect "$RC" 2 "unknown mode -> exit 2"
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "unknown mode -> NOT-GATED"

# 13 — the AM_SELF / BR_AGENT_NAME agent-identity fallback is entirely gone
expect "$(grep -cE 'AM_SELF|BR_AGENT_NAME' "$SCRIPT")" 0 "AM_SELF/BR_AGENT_NAME fallback is gone from the script"

# 14 — a ## Success Criteria (capital-C) fixture: approve then ready succeed, so the
# SuccessCriterion digest leg is proven hashing real content instead of empty.
{
  printf -- '---\nstatus: draft\n---\n# Plan\n\n## Vision\n\n%s\n\n## Deliverables\n\n- D1 x\n\n## Decisions\n\n%s\n\n## Seams\n\na\n\n## Out of scope\n\nn\n\n## Success Criteria\n\nSome criterion.\n' \
    "$vision_line" "$SETTLED_CARD"
} > "$W/capc.md"
cap "$SCRIPT" approve "$W/capc.md" "Alex"
expect "$RC" 0 "## Success Criteria plan -> exit 0"
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "## Success Criteria plan -> APPROVED"

# --- ready mode -----------------------------------------------------------------------

add_polish_keys() {
  # Simulate a polish stamp without running the reader loop: the two keys ready() checks.
  local file="$1"
  sed -i '2a polish_rounds: 2\npolish_fixpoint_sha256: deadbeef' "$file"
}

# 15 — ready refuses not-polished before polish keys exist (exit 1)
mk_plan "$W/r1.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/r1.md" "Alex"
expect "$RC" 0 "setup: approve r1"
cap "$SCRIPT" ready "$W/r1.md"
expect "$RC" 1 "ready before polish -> exit 1"
expect "$(grep -c 'REFUSED not-polished' <<<"$OUT")" 1 "ready before polish -> REFUSED not-polished"

# 16 — ready refuses not-approved when status never reached approved (exit 1)
mk_plan "$W/r2.md" "- D1 x" "$SETTLED_CARD" "a"
add_polish_keys "$W/r2.md"
cap "$SCRIPT" ready "$W/r2.md"
expect "$RC" 1 "ready on a never-approved plan -> exit 1"
expect "$(grep -c 'REFUSED not-approved' <<<"$OUT")" 1 "ready on a never-approved plan -> REFUSED not-approved"

# 17 — ready with a matching digest -> READY (exit 0), writes bead-ready + regate: none
mk_plan "$W/r3.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/r3.md" "Alex"
expect "$RC" 0 "setup: approve r3"
add_polish_keys "$W/r3.md"
cap "$SCRIPT" ready "$W/r3.md"
expect "$RC" 0 "matching digest -> exit 0"
expect "$(grep -c '^READY:' <<<"$OUT")" 1 "matching digest -> READY"
expect "$(grep -c '^status: bead-ready$' "$W/r3.md")" 1 "ready writes status: bead-ready"
expect "$(grep -c '^bead_ready_at:' "$W/r3.md")" 1 "ready writes bead_ready_at"
expect "$(grep -c '^regate: none$' "$W/r3.md")" 1 "ready writes regate: none"

# 18 — ready on the capital-C fixture with no edits -> READY (exit 0)
add_polish_keys "$W/capc.md"
cap "$SCRIPT" ready "$W/capc.md"
expect "$RC" 0 "## Success Criteria plan with no edits -> exit 0"
expect "$(grep -c '^READY:' <<<"$OUT")" 1 "## Success Criteria plan with no edits -> READY"

# 19 — ready after an edit INSIDE ## Deliverables -> REFUSED regate Deliverables (exit 1)
mk_plan "$W/r4.md" "- **D1 \`$REAL_PATH\`** — a thing." "$SETTLED_CARD" "$SEAMS_OK"
cap "$SCRIPT" approve "$W/r4.md" "Alex"
expect "$RC" 0 "setup: approve r4"
add_polish_keys "$W/r4.md"
sed -i 's/a thing\./a DIFFERENT thing./' "$W/r4.md"
cap "$SCRIPT" ready "$W/r4.md"
expect "$RC" 1 "edit inside ## Deliverables -> exit 1"
expect "$(grep -c '^REFUSED regate Deliverables$' <<<"$OUT")" 1 "edit inside ## Deliverables -> REFUSED regate Deliverables"

# 20 — ready after an edit INSIDE ## Vision names only that section (exit 1)
mk_plan "$W/v.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/v.md" "Alex"
expect "$RC" 0 "setup: approve v"
add_polish_keys "$W/v.md"
sed -i '/^## Vision$/,/^## / s/plain prose/plain PROSE/' "$W/v.md"
cap "$SCRIPT" ready "$W/v.md"
expect "$RC" 1 "edit inside ## Vision -> exit 1"
expect "$(grep -c '^REFUSED regate Vision$' <<<"$OUT")" 1 "edit inside ## Vision -> REFUSED regate Vision"

# 21 — ready after an edit INSIDE ## Decisions names only that section (exit 1)
mk_plan "$W/d.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/d.md" "Alex"
expect "$RC" 0 "setup: approve d"
add_polish_keys "$W/d.md"
sed -i 's/options: a, b\./options: a, b, c./' "$W/d.md"
cap "$SCRIPT" ready "$W/d.md"
expect "$RC" 1 "edit inside ## Decisions -> exit 1"
expect "$(grep -c '^REFUSED regate Decisions$' <<<"$OUT")" 1 "edit inside ## Decisions -> REFUSED regate Decisions"

# 22 — ready after an edit INSIDE ## Out of scope names only that section (exit 1)
mk_plan "$W/o.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/o.md" "Alex"
expect "$RC" 0 "setup: approve o"
add_polish_keys "$W/o.md"
sed -i 's/^- nothing$/- everything else/' "$W/o.md"
cap "$SCRIPT" ready "$W/o.md"
expect "$RC" 1 "edit inside ## Out of scope -> exit 1"
expect "$(grep -c '^REFUSED regate OutOfScope$' <<<"$OUT")" 1 "edit inside ## Out of scope -> REFUSED regate OutOfScope"

# 23 — ready after an edit INSIDE ## Success Criteria names only that section (exit 1):
# the capital-C leg hashes content, so moving the section regates instead of staying READY.
{
  printf -- '---\nstatus: draft\n---\n# Plan\n\n## Vision\n\n%s\n\n## Deliverables\n\n- D1 x\n\n## Decisions\n\n%s\n\n## Seams\n\na\n\n## Out of scope\n\nn\n\n## Success Criteria\n\nSome criterion.\n' \
    "$vision_line" "$SETTLED_CARD"
} > "$W/capc-reg.md"
cap "$SCRIPT" approve "$W/capc-reg.md" "Alex"
expect "$RC" 0 "setup: approve capc-reg"
add_polish_keys "$W/capc-reg.md"
sed -i 's/Some criterion\./Some amended criterion./' "$W/capc-reg.md"
cap "$SCRIPT" ready "$W/capc-reg.md"
expect "$RC" 1 "edit inside ## Success Criteria -> exit 1"
expect "$(grep -c '^REFUSED regate SuccessCriterion$' <<<"$OUT")" 1 "edit inside ## Success Criteria -> REFUSED regate SuccessCriterion"

# 24 — ready after an edit INSIDE ## Seams names only that section (exit 1)
mk_plan "$W/s.md" "- **D1 \`$REAL_PATH\`** — a thing." "$SETTLED_CARD" "$SEAMS_OK"
cap "$SCRIPT" approve "$W/s.md" "Alex"
expect "$RC" 0 "setup: approve s"
add_polish_keys "$W/s.md"
sed -i 's/some finding/some OTHER finding/' "$W/s.md"
cap "$SCRIPT" ready "$W/s.md"
expect "$RC" 1 "edit inside ## Seams -> exit 1"
expect "$(grep -c '^REFUSED regate Seams$' <<<"$OUT")" 1 "edit inside ## Seams -> REFUSED regate Seams"

# 24b — a plan carrying BOTH an exact ## Seams section and a look-alike (## Seams — seen
# by more than one lens) digests only the exact one (ac-4y7l.3): an edit made INSIDE the
# look-alike section does not regate Seams, or anything else.
{
  printf -- '---\nstatus: draft\ncreated: 2026-09-05\n---\n# Plan\n\n## Vision\n\n%s\n\n## Deliverables\n\n%s\n\n## Decisions\n\n%s\n\n## Seams\n\n%s\n\n## Seams — seen by more than one lens\n\nsome reader evidence, never the real Seams table\n\n## Out of scope\n\n- nothing\n\n## Success criterion\n\nSome criterion.\n' \
    "$vision_line" "- **D1 \`$REAL_PATH\`** — a thing." "$SETTLED_CARD" "$SEAMS_OK"
} > "$W/s-lookalike.md"
cap "$SCRIPT" approve "$W/s-lookalike.md" "Alex"
expect "$RC" 0 "setup: approve s-lookalike"
add_polish_keys "$W/s-lookalike.md"
sed -i 's/some reader evidence/some OTHER reader evidence/' "$W/s-lookalike.md"
cap "$SCRIPT" ready "$W/s-lookalike.md"
expect "$RC" 0 "edit inside look-alike Seams section does not regate -> exit 0"
expect "$(grep -c '^READY:' <<<"$OUT")" 1 "edit inside look-alike Seams section does not regate -> READY"

# 25 — ready after adding a Human gates: line names only that section (exit 1):
# the line lives in frontmatter, outside every ## body, so only its own leg moves.
mk_plan "$W/h.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/h.md" "Alex"
expect "$RC" 0 "setup: approve h"
add_polish_keys "$W/h.md"
sed -i '2a Human gates: none' "$W/h.md"
cap "$SCRIPT" ready "$W/h.md"
expect "$RC" 1 "added Human gates: line -> exit 1"
expect "$(grep -c '^REFUSED regate HumanGates$' <<<"$OUT")" 1 "added Human gates: line -> REFUSED regate HumanGates"

# 26 — ready after an edit OUTSIDE every gated section -> READY (exit 0)
mk_plan "$W/r5.md" "- D1 x" "$SETTLED_CARD" "a" "amended_after_stamp: an ungated frontmatter note"
cap "$SCRIPT" approve "$W/r5.md" "Alex"
expect "$RC" 0 "setup: approve r5"
add_polish_keys "$W/r5.md"
sed -i 's/an ungated frontmatter note/a DIFFERENT ungated frontmatter note/' "$W/r5.md"
cap "$SCRIPT" ready "$W/r5.md"
expect "$RC" 0 "edit outside every gated section -> exit 0"
expect "$(grep -c '^READY:' <<<"$OUT")" 1 "edit outside every gated section -> READY, no regate"

# --- check mode -------------------------------------------------------------------------

# 27 — check refuses missing-keys before any approval (exit 1)
mk_plan "$W/c1.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" check "$W/c1.md"
expect "$RC" 1 "check with no approval keys -> exit 1"
expect "$(grep -c 'REFUSED missing-keys' <<<"$OUT")" 1 "check with no approval keys -> REFUSED missing-keys"

# 28 — check refuses status <status> when approved but not yet ready (exit 1)
mk_plan "$W/c2.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/c2.md" "Alex"
expect "$RC" 0 "setup: approve c2"
cap "$SCRIPT" check "$W/c2.md"
expect "$RC" 1 "check on approved-but-not-ready -> exit 1"
expect "$(grep -c 'REFUSED status approved' <<<"$OUT")" 1 "check on approved-but-not-ready -> REFUSED status approved"

# 29 — check passes OK on a bead-ready plan (exit 0)
mk_plan "$W/c3.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/c3.md" "Alex"
expect "$RC" 0 "setup: approve c3"
add_polish_keys "$W/c3.md"
cap "$SCRIPT" ready "$W/c3.md"
expect "$RC" 0 "setup: ready c3"
cap "$SCRIPT" check "$W/c3.md"
expect "$RC" 0 "bead-ready plan -> exit 0"
expect "$(grep -c '^OK:' <<<"$OUT")" 1 "bead-ready plan -> check OK"

# 30 — check also passes on a retired plan's shape: status: done, keys untouched (exit 0)
mk_plan "$W/c4.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/c4.md" "Alex"
expect "$RC" 0 "setup: approve c4"
add_polish_keys "$W/c4.md"
cap "$SCRIPT" ready "$W/c4.md"
expect "$RC" 0 "setup: ready c4"
sed -i 's/^status: bead-ready$/status: done/' "$W/c4.md"
cap "$SCRIPT" check "$W/c4.md"
expect "$RC" 0 "retired (status: done) plan -> exit 0"
expect "$(grep -c '^OK:' <<<"$OUT")" 1 "retired (status: done) plan -> check OK"

# 31 — check refuses digest-mismatch when a gated section moved after ready (exit 1)
mk_plan "$W/c5.md" "- **D1 \`$REAL_PATH\`** — a thing." "$SETTLED_CARD" "$SEAMS_OK"
cap "$SCRIPT" approve "$W/c5.md" "Alex"
expect "$RC" 0 "setup: approve c5"
add_polish_keys "$W/c5.md"
cap "$SCRIPT" ready "$W/c5.md"
expect "$RC" 0 "setup: ready c5"
sed -i 's/a thing\./a THIRD thing./' "$W/c5.md"
cap "$SCRIPT" check "$W/c5.md"
expect "$RC" 1 "gated section moved after ready -> exit 1"
expect "$(grep -c 'REFUSED digest-mismatch' <<<"$OUT")" 1 "gated section moved after ready -> REFUSED digest-mismatch"

# 32 — the documented `## Deliverables (artifacts)` prefix-match fixture: approve, then
# ready with no edits -> both succeed against the variant header (exit 0).
{
  printf -- '---\nstatus: draft\n---\n# Plan\n\n## Vision\n\n%s\n\n## Deliverables (artifacts)\n\n- **D1 `%s`** — a thing.\n\n## Decisions\n\n%s\n\n## Seams\n\n%s\n\n## Out of scope\n\n- nothing\n\n## Success criterion\n\nSome criterion.\n' \
    "$vision_line" "$REAL_PATH" "$SETTLED_CARD" "$SEAMS_OK"
} > "$W/artifacts.md"
cap "$SCRIPT" approve "$W/artifacts.md" "Alex"
expect "$RC" 0 "## Deliverables (artifacts) header -> exit 0"
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "## Deliverables (artifacts) header -> APPROVED"
add_polish_keys "$W/artifacts.md"
cap "$SCRIPT" ready "$W/artifacts.md"
expect "$RC" 0 "## Deliverables (artifacts) header with no edits -> exit 0"
expect "$(grep -c '^READY:' <<<"$OUT")" 1 "## Deliverables (artifacts) header with no edits -> READY"

# 33 — approve is re-runnable (the re-approve half of the regate flow): approving twice on
# an unchanged plan still succeeds (exit 0) and re-stamps a fresh approved_at.
mk_plan "$W/reapp.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/reapp.md" "Alex"
expect "$RC" 0 "setup: first approve reapp"
cap "$SCRIPT" approve "$W/reapp.md" "Alex"
expect "$RC" 0 "re-approve on an unchanged plan -> exit 0"
expect "$(grep -c '^APPROVED:' <<<"$OUT")" 1 "re-approve on an unchanged plan -> APPROVED again"
expect "$(grep -c '^approved_by: Alex$' "$W/reapp.md")" 1 "re-approve keeps exactly one approved_by line"

# 34 — with no shasum or sha256sum on PATH every mode refuses closed: NOT-GATED (exit 2),
# never a digest over empty input.
NOSHADIR=$(mktemp -d /tmp/plan-approve-test-nosha-XXXXXX)
mk_plan "$W/nosha.md" "- D1 x" "$SETTLED_CARD" "a"
OUT=$(PATH="$NOSHADIR" "$BASH_BIN" "$SCRIPT" approve "$W/nosha.md" "Alex" 2>&1); RC=$?
expect "$RC" 2 "approve with no sha tool -> exit 2"
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "approve with no sha tool -> NOT-GATED"
OUT=$(PATH="$NOSHADIR" "$BASH_BIN" "$SCRIPT" ready "$W/nosha.md" 2>&1); RC=$?
expect "$RC" 2 "ready with no sha tool -> exit 2"
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "ready with no sha tool -> NOT-GATED"
OUT=$(PATH="$NOSHADIR" "$BASH_BIN" "$SCRIPT" check "$W/nosha.md" 2>&1); RC=$?
expect "$RC" 2 "check with no sha tool -> exit 2"
expect "$(grep -c 'NOT-GATED' <<<"$OUT")" 1 "check with no sha tool -> NOT-GATED"
rm -rf "$NOSHADIR"

# --- gotcha: approved keys survive polish-fixpoint.sh --mode plan -----------------------

mk_plan "$W/pf.md" "- D1 x" "$SETTLED_CARD" "a"
cap "$SCRIPT" approve "$W/pf.md" "Alex"
expect "$RC" 0 "setup: approve pf"
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
