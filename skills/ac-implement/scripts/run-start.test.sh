#!/usr/bin/env bash
# run-start.test.sh — the run-start branch recorder over real repos and a linked worktree.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$DIR/run-start.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
REPO="$WORK/repo"
LINKED="$WORK/linked"

PASSES=0
FAILURES=0
pass() { echo "  PASS: $1"; PASSES=$((PASSES + 1)); }
fail() { echo "  FAIL: $1"; [ -z "${2:-}" ] || printf '     %s\n' "$2"; FAILURES=$((FAILURES + 1)); }

if [ ! -x "$SCRIPT" ]; then
  fail "run-start.sh is executable" "$SCRIPT missing or not executable"
else
  pass "run-start.sh is executable"
fi

git init -q -b main "$REPO"
git -C "$REPO" config user.name test
git -C "$REPO" config user.email test@example.com
printf 'seed\n' >"$REPO/file.txt"
git -C "$REPO" add file.txt
git -C "$REPO" commit -qm init
git -C "$REPO" checkout -q -b dev
MAIN_COMMON="$(git -C "$REPO" rev-parse --git-common-dir)"
case "$MAIN_COMMON" in /*) ;; *) MAIN_COMMON="$REPO/$MAIN_COMMON" ;; esac

git -C "$REPO" checkout -q --detach
DETACH_OUT=$(bash -c 'cd "$1" && bash "$2" --run detached' _ "$REPO" "$SCRIPT" 2>&1); DETACH_RC=$?
DETACH_FILE="$MAIN_COMMON/ac-flight/detached/branch"
if [ "$DETACH_RC" -ne 0 ] && [ ! -e "$DETACH_FILE" ]; then
  pass "detached HEAD exits non-zero and writes nothing"
else
  fail "detached HEAD" "rc=$DETACH_RC file=$DETACH_FILE out=$DETACH_OUT"
fi

git -C "$REPO" checkout -q dev
DEV_OUT=$(bash -c 'cd "$1" && bash "$2" --run dev-run' _ "$REPO" "$SCRIPT" 2>&1); DEV_RC=$?
DEV_FILE="$MAIN_COMMON/ac-flight/dev-run/branch"
if [ "$DEV_RC" -eq 0 ] && [ -f "$DEV_FILE" ] && [ "$(<"$DEV_FILE")" = dev ]; then
  pass "a run started on dev writes dev"
else
  fail "dev branch" "rc=$DEV_RC out=$DEV_OUT"
fi
if printf '%s\n' "$DEV_OUT" | grep -qx 'this run will publish dev to origin'; then
  pass "a branch absent on origin prints the publish line"
else
  fail "unpublished branch line" "$DEV_OUT"
fi

git -C "$REPO" worktree add -q -b linked "$LINKED"
LINK_OUT=$(bash -c 'cd "$1" && bash "$2" --run linked-run' _ "$LINKED" "$SCRIPT" 2>&1); LINK_RC=$?
MAIN_FILE="$MAIN_COMMON/ac-flight/linked-run/branch"
LINK_FILE="$(git -C "$LINKED" rev-parse --git-common-dir)/ac-flight/linked-run/branch"
if [ "$LINK_RC" -eq 0 ] && [ -f "$MAIN_FILE" ] && [ -f "$LINK_FILE" ] \
    && [ "$(<"$MAIN_FILE")" = linked ] && [ "$(<"$LINK_FILE")" = linked ]; then
  pass "a linked worktree writes the same run record in the main repo's common dir"
else
  fail "linked worktree" "rc=$LINK_RC main=$MAIN_FILE link=$LINK_FILE out=$LINK_OUT"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "$PASSES passed, $FAILURES failed — all run-start tests passed."
  exit 0
fi
echo "$FAILURES run-start test(s) FAILED."
exit 1
