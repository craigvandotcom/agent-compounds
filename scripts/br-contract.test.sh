#!/usr/bin/env bash
# br-contract.test.sh — live probe of the br behaviours the canon asserts (ac-heyt.2).
#
# The registry's canon (beads-standards/SKILL.md § br gotchas, bead-schema.md) asserts a
# set of `br` behaviours — JSON envelope shapes, exit codes, the `-f`-beside-a-title
# refusal, verbatim comment bodies. Nothing executed them; this harness probes the real
# binary on its OWN scratch workspace (`br init` under `mktemp -d`) and NEVER touches the
# live board.
#
# EXPECTED VERSION (case 7): 0.5.12 — a different installed binary is ONE fail line naming
# both versions, never a silent adaptation.
#
# Exit 0 = all cases pass · 77 = self-skip (br or jq missing — a precondition this runner
# cannot provision; exit 0 on a host without br would read as coverage that never happened).
set -uo pipefail

EXPECT_VERSION="0.5.12"
CASES=0
FAILURES=0

pass() { CASES=$((CASES+1)); echo "ok   $*"; }
fail() { CASES=$((CASES+1)); FAILURES=$((FAILURES+1)); echo "FAIL $*"; }

command -v br >/dev/null 2>&1 || { echo "SKIP: br is not on PATH — the contract cannot be probed"; exit 77; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq is not installed — the envelopes cannot be read"; exit 77; }

# --- C7: the binary matches the version this harness expects -------------------------------
BR_VERSION="$(br --version 2>/dev/null)"
if [ "$BR_VERSION" = "br $EXPECT_VERSION" ]; then
  pass "C7: br --version is 'br $EXPECT_VERSION'"
else
  fail "C7: br --version is '$BR_VERSION', expected 'br $EXPECT_VERSION'"
fi

# --- scratch workspace: the live board is never the subject ---------------------------------
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/br-contract.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT
cd "$WORKDIR" || { echo "FAIL: cannot enter scratch workspace $WORKDIR"; exit 1; }
br init >/dev/null 2>&1 || { echo "FAIL: br init failed in scratch workspace"; exit 1; }

# The capture guard demands probe-bearing, origin-carrying bodies.
cat > body.txt <<'EOF'
## Intent
scratch probe.

## Acceptance Criteria
- probe.
  Probe: `test -f /tmp/x` — tier: none

## Delivers
- scratch

## Consumes
none
EOF

NEW_BODY="$(cat body.txt)"
make_issue() { # <title> -> id
  br create "$1" -t task -p 2 --labels "origin:manual,unrefined" -d "$NEW_BODY" --json 2>/dev/null \
    | jq -r '.id'
}

# --- C1: JSON envelope shapes, read from the tool, not hard-coded -----------------------------
LIST_SHAPE="$(br schema commands --format json | jq -r '.commands.list.shape')"
READY_SHAPE="$(br schema commands --format json | jq -r '.commands.ready.shape')"
SHOW_SHAPE="$(br schema commands --format json | jq -r '.commands.show.shape')"
SHOW_ERR_STDERR="$(br schema commands --format json | jq -r '.commands.show.error_envelope_on_stderr')"

A="$(make_issue "issue A")"
[ -n "$A" ] || { echo "FAIL: C1 setup — could not create issue A"; exit 1; }

if [ "$LIST_SHAPE" = "object" ] && br list --json | jq -e '.issues | type == "array"' >/dev/null 2>&1; then
  pass "C1: br list --json is a paginated object with .issues (schema shape: $LIST_SHAPE)"
else
  fail "C1: br list --json shape (schema says '$LIST_SHAPE') or .issues missing"
fi

if [ "$READY_SHAPE" = "array" ] && br ready --json | jq -e 'type == "array"' >/dev/null 2>&1; then
  pass "C1: br ready --json is a bare array (schema shape: $READY_SHAPE)"
else
  fail "C1: br ready --json shape (schema says '$READY_SHAPE')"
fi

if [ "$SHOW_SHAPE" = "array" ] && br show "$A" --json | jq -e 'type == "array" and length == 1' >/dev/null 2>&1; then
  pass "C1: br show --json is a one-element array (schema shape: $SHOW_SHAPE)"
else
  fail "C1: br show --json shape (schema says '$SHOW_SHAPE')"
fi

# --- C2: exit codes, read from capabilities, not hard-coded -----------------------------------
EXIT_ISSUE="$(br capabilities --format json | jq -r '.exit_codes[] | select(.category=="issue") | .code')"
EXIT_VALIDATION="$(br capabilities --format json | jq -r '.exit_codes[] | select(.category=="validation") | .code')"
EXIT_DEPENDENCY="$(br capabilities --format json | jq -r '.exit_codes[] | select(.category=="dependency") | .code')"

br label add br-no-such-issue --label x >/dev/null 2>&1; RC=$?
if [ "$RC" -eq "$EXIT_ISSUE" ]; then
  pass "C2: br label add on an unknown id exits $EXIT_ISSUE (capabilities: issue category)"
else
  fail "C2: br label add unknown id exits $RC, expected $EXIT_ISSUE"
fi

br label add "$A" alpha beta >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 0 ] && br show "$A" --json | jq -e '[.[0].labels[]] | index("alpha") and index("beta")' >/dev/null 2>&1; then
  pass "C2: positional multi-label applies every label, rc 0"
else
  fail "C2: positional multi-label rc $RC (expected 0) or a label missing"
fi

br label add "$A" gamma --label delta >/dev/null 2>&1; RC=$?
if [ "$RC" -eq "$EXIT_VALIDATION" ]; then
  pass "C2: bare label mixed with -l exits $EXIT_VALIDATION (capabilities: validation category)"
else
  fail "C2: bare label beside -l exits $RC, expected $EXIT_VALIDATION"
fi

C="$(make_issue "issue C")"
br dep add "$A" "$C" >/dev/null 2>&1
br dep add "$C" "$A" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq "$EXIT_DEPENDENCY" ]; then
  pass "C2: br dep add closing a cycle exits $EXIT_DEPENDENCY (capabilities: dependency category)"
else
  fail "C2: cycle-closing dep add exits $RC, expected $EXIT_DEPENDENCY"
fi

# --- C3: br create -f beside a title is refused -------------------------------------------------
printf '## Title\nsome bulk import\n' > bulk.md
br create "T" -f bulk.md >/dev/null 2>&1; RC=$?
if [ "$RC" -eq "$EXIT_VALIDATION" ]; then
  pass "C3: br create -f beside a title is refused, rc $EXIT_VALIDATION"
else
  fail "C3: br create -f beside a title exits $RC, expected $EXIT_VALIDATION"
fi

# --- C4: br comments add -f stores hostile body text VERBATIM -----------------------------------
printf 'backtick ` here <angle> $(echo pwned) stays' > comment.txt
br comments add "$A" -f comment.txt >/dev/null 2>&1; RC=$?
STORED="$(br comments list "$A" --json 2>/dev/null | jq -r 'map(select(.text | contains("backtick"))) | .[0].text' | sed 's/[[:space:]]*$//')"
if [ "$RC" -eq 0 ] && [ "$STORED" = 'backtick ` here <angle> $(echo pwned) stays' ]; then
  pass "C4: br comments add -f stores backticks, angle brackets and \$() VERBATIM"
else
  fail "C4: verbatim comment body (rc $RC, stored '$STORED')"
fi

# --- C5: br show --json on a missing id: exit 3, envelope on STDOUT, EMPTY stderr -----------------
if [ "$SHOW_ERR_STDERR" = "false" ]; then
  br show br-no-such-issue --json >out.json 2>err.txt; RC=$?
  if [ "$RC" -eq "$EXIT_ISSUE" ] && jq -e '.error' out.json >/dev/null 2>&1 && [ ! -s err.txt ]; then
    pass "C5: br show missing id exits $EXIT_ISSUE with the error envelope on STDOUT and an empty stderr (schema: error_envelope_on_stderr=$SHOW_ERR_STDERR)"
  else
    fail "C5: br show missing id rc $RC, envelope-on-stdout or empty-stderr violated"
  fi
else
  fail "C5: schema declares error_envelope_on_stderr=$SHOW_ERR_STDERR, expected false — the D9 helper premise broke"
fi

# --- C6: br list --json with no --limit: limit 0, has_more false on a small board -----------------
LIST_ENV="$(br list --json)"
LIMIT="$(printf '%s' "$LIST_ENV" | jq -r '.limit')"
HAS_MORE="$(printf '%s' "$LIST_ENV" | jq -r '.has_more')"
N_ISSUES="$(printf '%s' "$LIST_ENV" | jq '.issues | length')"
if [ "$LIMIT" = "0" ] && [ "$HAS_MORE" = "false" ] && [ "$N_ISSUES" -eq 2 ]; then
  pass "C6: br list --json with no --limit reports limit: 0, has_more: false ($N_ISSUES issues on the scratch board)"
else
  fail "C6: br list --json default (limit=$LIMIT has_more=$HAS_MORE issues=$N_ISSUES)"
fi

# --- A7 (rides along): policy.yaml absent on scratch; print the live repo's state ------------------
if [ ! -f .beads/policy.yaml ]; then
  pass "A7: no .beads/policy.yaml on the scratch board"
else
  fail "A7: scratch board carries .beads/policy.yaml — the harness workspace is dirty"
fi
LIVE_REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "$(dirname "$(command -v br)")")")"
if [ -f "$LIVE_REPO/.beads/policy.yaml" ]; then
  echo "note: the live repo at $LIVE_REPO carries a .beads/policy.yaml (gates closes/transitions)"
else
  echo "note: the live repo at $LIVE_REPO carries no .beads/policy.yaml"
fi

# --- verdict ---------------------------------------------------------------------------------------
echo "br-contract: $CASES case(s), $FAILURES failure(s)"
[ "$FAILURES" -eq 0 ] || exit 1
exit 0