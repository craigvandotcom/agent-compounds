#!/usr/bin/env bash
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-proofs.sh (glob-discovered; the CI proofs job runs it)
# commit-msg.test.sh — the commit-msg hook's bookkeeping exemption, end to end. A throwaway
# repository gets the REAL hooks/commit-msg installed as .git/hooks/commit-msg, and real
# `git commit`s run through it. A commit touching only `.compounds/reviews/` names no cause and
# draws no warning; one touching only `.compounds/state/` still warns; both commits succeed
# (the hook is warn-only).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/hooks/commit-msg"
[ -x "$HOOK" ] || { echo "FAIL hooks/commit-msg is missing or not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
R="$T/repo"
git init -q "$R"
git -C "$R" config user.email commit-msg-test@test.local
git -C "$R" config user.name "commit-msg-test"
git -C "$R" config commit.gpgsign false
cp "$HOOK" "$R/.git/hooks/commit-msg"
chmod +x "$R/.git/hooks/commit-msg"
git -C "$R" commit -q --allow-empty --no-verify -m "seed"

fails=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails+1)); }

# commit_only <path> — stage one new file, commit it with a cause-less message through the
# installed hook; prints the commit's stderr and returns the commit's exit status.
commit_only() {
  mkdir -p "$R/$(dirname "$1")"
  printf 'x\n' >"$R/$1"
  git -C "$R" add -- "$1"
  git -C "$R" commit -m "touch $1" 2>&1
}

out="$(commit_only .compounds/reviews/x.md)"; rc=$?
if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q 'names no cause'; then
  ok ".compounds/reviews/ only: commit succeeds and draws no no-cause warning"
else bad ".compounds/reviews/ only: rc=$rc out=$out"; fi

out="$(commit_only .compounds/state/x)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'names no cause'; then
  ok ".compounds/state/ only: commit succeeds and still warns (state is not bookkeeping)"
else bad ".compounds/state/ only: rc=$rc out=$out"; fi

out="$(commit_only .compounds/config/x)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'names no cause'; then
  ok ".compounds/config/ only: commit succeeds and still warns"
else bad ".compounds/config/ only: rc=$rc out=$out"; fi

echo "---"
echo "FAILURES=$fails"
[ "$fails" -eq 0 ]
