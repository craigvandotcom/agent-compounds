#!/usr/bin/env bash
# 38-machine-file-untracked.test.sh — the proof harness for Check 38's contract.
#
#   PROBE: a committed machine.json is RED naming TRACKED; a force-added (staged,
#           uncommitted) machine.json is RED naming STAGED; a file tracked in HEAD whose
#           removal is STAGED (`git rm --cached`, still uncommitted) is GREEN with a
#           disclosed amnesty, and the commit that lands it clears the amnesty; an ignored
#           machine.json sitting untracked on disk is GREEN; a checkout with no
#           machine.json is GREEN; a non-git root is NOT-GATED (2); the declared fixture's
#           run.sh demonstrates its own RED; the real registry is GREEN.
#
# ASSURANCE
#   PROBE:    bash lint/checks/38-machine-file-untracked.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/38-machine-file-untracked.py"
ROOT="$(cd "$HERE/../.." && pwd)"
FIXTURE="$ROOT/lint/fixtures/38-machine-file-untracked"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# The check must judge the fixture repo, never an inherited GIT_* redirection.
run_check() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE python3 "$CHECK" "$1" 2>&1; }

new_repo() { # -> prints the temp repo path
  local w
  w="$(mktemp -d)"
  git init -q -b main "$w"
  git -C "$w" config user.email fixture@example.invalid
  git -C "$w" config user.name fixture
  printf 'machine.json\n' > "$w/.gitignore"
  printf '#!/usr/bin/env python3\n' > "$w/keep.py"
  git -C "$w" add .gitignore keep.py
  git -C "$w" commit -qm base
  printf '%s\n' "$w"
}

# --- RED: machine.json committed (tracked) ---------------------------------------
w="$(new_repo)"
printf '{"org_root": "/x"}\n' > "$w/machine.json"
git -C "$w" add -f machine.json
git -C "$w" commit -qm "committed by accident"
out="$(run_check "$w")"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'TRACKED'; then
  ok "RED: committed machine.json -> exit 1 naming TRACKED"
else
  bad "tracked case: expected 1 naming TRACKED, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- RED: machine.json staged but not committed ----------------------------------
w="$(new_repo)"
printf '{"org_root": "/x"}\n' > "$w/machine.json"
git -C "$w" add -f machine.json
out="$(run_check "$w")"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'STAGED'; then
  ok "RED: staged machine.json -> exit 1 naming STAGED"
else
  bad "staged case: expected 1 naming STAGED, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN + AMNESTY: still in HEAD, removal staged (`git rm --cached`) -----------
# The state the check's own printed remediation leaves behind: `git rm --cached` keeps the
# file in HEAD's tree until that commit lands, and this check gates that very commit. So
# it passes with a DISCLOSED amnesty — and only while the removal is genuinely staged: the
# staged-but-not-committed case above stays RED, which is what keeps this narrow.
w="$(new_repo)"
printf '{"org_root": "/x"}\n' > "$w/machine.json"
git -C "$w" add -f machine.json
git -C "$w" commit -qm "committed by accident"
git -C "$w" rm --cached -q machine.json
out="$(run_check "$w")"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'amnesty'; then
  ok "AMNESTY: tracked in HEAD, removal staged -> exit 0, amnesty disclosed"
else
  bad "amnesty case: expected 0 naming amnesty, got $rc"; printf '%s\n' "$out"
fi
# The amnesty is one commit long: once the removal lands, the run is plainly green.
git -C "$w" commit -qm "untrack the machine file"
out="$(run_check "$w")"; rc=$?
if [ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q 'amnesty'; then
  ok "AMNESTY: the untracking commit clears it — the next run is plain green"
else
  bad "post-amnesty case: expected plain exit 0 with no amnesty, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: ignored machine.json on disk, never added ----------------------------
w="$(new_repo)"
printf '{"org_root": "/x"}\n' > "$w/machine.json"
out="$(run_check "$w")"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: ignored, untracked machine.json on disk -> exit 0"
else
  bad "untracked case: expected 0, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- GREEN: no machine.json at all -----------------------------------------------
w="$(new_repo)"
out="$(run_check "$w")"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: checkout with no machine.json -> exit 0"
else
  bad "absent case: expected 0, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- NOT-GATED: not a git checkout ------------------------------------------------
w="$(mktemp -d)"
out="$(run_check "$w")"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'NOT-CHECKED'; then
  ok "NOT-GATED: non-git root -> exit 2, verified nothing"
else
  bad "not-gated case: expected 2, got $rc"; printf '%s\n' "$out"
fi
rm -rf "$w"

# --- the declared fixture demonstrates its own RED ---------------------------------
if [ -x "$FIXTURE/run.sh" ]; then
  out="$(bash "$FIXTURE/run.sh" 2>&1)"; rc=$?
  if [ "$rc" = 0 ]; then
    ok "fixture: run.sh demonstrated the RED (exit 0)"
  else
    bad "fixture case: run.sh expected 0, got $rc"; printf '%s\n' "$out"
  fi
else
  bad "fixture case: $FIXTURE/run.sh is missing or not executable"
fi

# --- GREEN: the real registry ------------------------------------------------------
out="$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE python3 "$CHECK" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "GREEN: the real registry is clean"
else
  bad "real-tree case: expected 0, got $rc"; printf '%s\n' "$out"
fi

echo "38-machine-file-untracked.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
