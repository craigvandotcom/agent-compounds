#!/usr/bin/env bash
# swarm-commit.test.sh — proof harness for swarm-commit.sh, the ac2 repo-global commit lane.
#
# Every case builds a REAL git repository with a REAL bare remote and drives the lane
# end-to-end. There is no mock git: the whole point of the lane is that git's own
# behaviour under a shared index, a pre-commit hook and a linked worktree is what bites,
# and a mock would only ever reproduce the author's belief about that behaviour.
#
# The refusal cases are the product. Each asserts BOTH the exit code AND that the output
# NAMES THE RULE — a refusal that does not say which rule fired is a wall, not a control.
#
# Exit 0 = all cases pass · 77 = self-skip (flock(1) absent; the lane cannot be exercised).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LANE="$SCRIPT_DIR/swarm-commit.sh"
CASES=0
FAILURES=0

pass() { CASES=$((CASES+1)); echo "ok   $*"; }
fail() { CASES=$((CASES+1)); FAILURES=$((FAILURES+1)); echo "FAIL $*"; }

command -v flock >/dev/null 2>&1 || {
  echo "SKIP: flock(1) is not installed — the lane cannot be exercised here"; exit 77; }
[ -x "$LANE" ] || { echo "FAIL swarm-commit.sh is missing or not executable at $LANE"; exit 1; }

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/swarm-commit.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# A repo with a bare origin, two tracked files (mine.txt is ours, sib.txt belongs to a
# concurrent session sharing the checkout) and a message file on disk.
new_repo() {
  d="$WORKDIR/$1"
  mkdir -p "$d"
  git init -q "$d"
  git -C "$d" symbolic-ref HEAD refs/heads/main
  git -C "$d" config user.email lane@test.local
  git -C "$d" config user.name "lane-test"
  git -C "$d" config commit.gpgsign false
  git init -q --bare "$d.git"
  git -C "$d" remote add origin "$d.git"
  printf 'mine v1\n' >"$d/mine.txt"
  printf 'sib v1\n'  >"$d/sib.txt"
  git -C "$d" add -- mine.txt sib.txt
  git -C "$d" commit -qm seed
  git -C "$d" push -q origin main
  printf "lane: a body with an apostrophe — don't truncate me\n" >"$d/msg.txt"
  printf 'mine v2\n' >"$d/mine.txt"
  echo "$d"
}

# --- 1. refusal: no identity ---------------------------------------------------------------
R="$(new_repo no-identity)"
out="$(cd "$R" && "$LANE" --message-file msg.txt --path mine.txt --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[no-identity\]'; then
  pass "refuses without an explicit identity, naming no-identity"
else fail "no-identity: rc=$rc out=$out"; fi

# The ambient AGENT_NAME must NOT satisfy it — that static fallback is the measured scar.
out="$(cd "$R" && AGENT_NAME=FoggyCreek "$LANE" --message-file msg.txt --path mine.txt --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[no-identity\]'; then
  pass "an ambient AGENT_NAME does not count as identity"
else fail "ambient AGENT_NAME accepted as identity: rc=$rc out=$out"; fi

# --- 2. refusal: inline message ------------------------------------------------------------
out="$(cd "$R" && "$LANE" --identity t -m "inline body" --path mine.txt --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[inline-message\]'; then
  pass "refuses an inline -m message, naming inline-message"
else fail "inline-message: rc=$rc out=$out"; fi

# --- 3. refusal: unscoped pathspec ---------------------------------------------------------
for bad in "." ":/" "mine.*"; do
  out="$(cd "$R" && "$LANE" --identity t --message-file msg.txt --path "$bad" --no-push 2>&1)"; rc=$?
  if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[unscoped-pathspec\]'; then
    pass "refuses unscoped path '$bad', naming unscoped-pathspec"
  else fail "unscoped-pathspec '$bad': rc=$rc out=$out"; fi
done
out="$(cd "$R" && "$LANE" --identity t --message-file msg.txt --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[unscoped-pathspec\]'; then
  pass "refuses with no --path at all, naming unscoped-pathspec"
else fail "no-path: rc=$rc out=$out"; fi
out="$(cd "$R" && "$LANE" --identity t --message-file msg.txt -A --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[unscoped-pathspec\]'; then
  pass "refuses a whole-tree flag, naming unscoped-pathspec"
else fail "whole-tree flag: rc=$rc out=$out"; fi

# --- 4. refusal: missing / empty message file ----------------------------------------------
out="$(cd "$R" && "$LANE" --identity t --message-file nope.txt --path mine.txt --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[no-message-file\]'; then
  pass "refuses a missing message file, naming no-message-file"
else fail "no-message-file: rc=$rc out=$out"; fi

# --- 5. refusal: running outside the lock --------------------------------------------------
# --_locked is the in-lane phase. Invoked directly, no lock is held, and the lane must
# detect that by PROBING the lock rather than trusting the flag it was handed.
out="$(cd "$R" && "$LANE" --_locked --identity t --message-file msg.txt --path mine.txt --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[outside-lock\]'; then
  pass "refuses a commit taken outside the lock, naming outside-lock"
else fail "outside-lock: rc=$rc out=$out"; fi

# --- 6. happy path: commits, scopes, pushes ------------------------------------------------
R="$(new_repo happy)"
printf 'sib v2\n' >"$R/sib.txt"
git -C "$R" add -- sib.txt                       # a concurrent session's staged work
out="$(cd "$R" && "$LANE" --identity NightlyOne --message-file msg.txt --path mine.txt 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then pass "commits and pushes through the lane"
else fail "happy path: rc=$rc out=$out"; fi
if [ "$(git -C "$R" show HEAD:mine.txt)" = "mine v2" ]; then
  pass "the commit carries our file"
else fail "commit missing our bytes: $(git -C "$R" show HEAD:mine.txt)"; fi
if [ "$(git -C "$R" show HEAD:sib.txt)" = "sib v1" ]; then
  pass "the pathspec is on the COMMIT — a sibling's staged file is not published"
else fail "sibling's staged file was swept into the commit"; fi
if [ "$(git -C "$R" rev-parse HEAD)" = "$(git -C "$R" rev-parse origin/main)" ]; then
  pass "the push landed on the remote"
else fail "push did not land"; fi
if git -C "$R" log -1 --format=%B | grep -q "don't truncate me"; then
  pass "an apostrophe in the message file survives intact (-F, never inline -m)"
else fail "message body truncated: $(git -C "$R" log -1 --format=%B)"; fi

# --- 7. lint-staged repair ------------------------------------------------------------------
# A pre-commit hook that rewrites the worktree WITHOUT re-staging: the commit would carry
# the pre-lint bytes while the worktree carries the post-lint bytes.
R="$(new_repo lint-staged)"
mkdir -p "$R/.git/hooks"
cat >"$R/.git/hooks/pre-commit" <<'HOOK'
#!/bin/sh
printf 'mine LINTED\n' > mine.txt
exit 0
HOOK
chmod +x "$R/.git/hooks/pre-commit"
out="$(cd "$R" && "$LANE" --identity NightlyOne --message-file msg.txt --path mine.txt --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$R" show HEAD:mine.txt)" = "mine LINTED" ]; then
  pass "post-lint-staged bytes are re-added — the commit carries what lint produced"
else fail "lint-staged repair: rc=$rc committed='$(git -C "$R" show HEAD:mine.txt)' out=$out"; fi
if [ -z "$(git -C "$R" status --porcelain -- mine.txt)" ]; then
  pass "the repair leaves no divergence behind for the next writer"
else fail "worktree still diverges after repair: $(git -C "$R" status --porcelain -- mine.txt)"; fi

# --- 8. foreign branch ----------------------------------------------------------------------
R="$(new_repo foreign-branch)"
git -C "$R" checkout -q -b someone-elses-branch
out="$(cd "$R" && "$LANE" --identity t --message-file msg.txt --path mine.txt --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 9 ] && printf '%s' "$out" | grep -q 'foreign-branch'; then
  pass "stops on a foreign branch (exit 9) without committing"
else fail "foreign-branch: rc=$rc out=$out"; fi

# --- 9. push rejected is not fatal -----------------------------------------------------------
R="$(new_repo push-rejected)"
out="$(cd "$R" && "$LANE" --identity t --message-file msg.txt --path mine.txt --remote no-such-remote 2>&1)"; rc=$?
if [ "$rc" -eq 10 ] && printf '%s' "$out" | grep -q 'PUSH_REJECTED'; then
  pass "a rejected push exits 10 and says so — the commit is still local"
else fail "push-rejected: rc=$rc out=$out"; fi
if [ "$(git -C "$R" show HEAD:mine.txt)" = "mine v2" ]; then
  pass "the local commit survives a rejected push"
else fail "commit lost on push rejection"; fi

# --- 10. a rejected commit never reaches the push --------------------------------------------
R="$(new_repo commit-rejected)"
mkdir -p "$R/.git/hooks"
printf '#!/bin/sh\necho "guard: foreign reservation" >&2\nexit 1\n' >"$R/.git/hooks/pre-commit"
chmod +x "$R/.git/hooks/pre-commit"
before="$(git -C "$R" rev-parse origin/main)"
out="$(cd "$R" && "$LANE" --identity t --message-file msg.txt --path mine.txt 2>&1)"; rc=$?
if [ "$rc" -eq 5 ] && [ "$(git -C "$R" rev-parse origin/main)" = "$before" ]; then
  pass "a guard-rejected commit exits 5 and NOTHING is pushed"
else fail "commit-rejected fell through: rc=$rc remote-moved out=$out"; fi

# --- 11. NON-WORKER writer: no worker context at all -----------------------------------------
# A scheduled job invokes the lane directly. No AGENT_NAME, no reservation, no swarm run id,
# no worker environment of any kind — env -i strips the lot. The lane must still work.
R="$(new_repo non-worker)"
out="$(cd "$R" && env -i PATH="$PATH" HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" \
        "$LANE" --identity nightly-ledger-job --message-file msg.txt --path mine.txt 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$R" show HEAD:mine.txt)" = "mine v2" ]; then
  pass "non-worker writer: a scheduled job with NO worker context takes the lane and commits"
else fail "non-worker writer: rc=$rc out=$out"; fi
if git -C "$R" log -1 --format=%an | grep -q lane-test; then
  pass "non-worker writer: the commit landed under the repo's own identity config"
else fail "non-worker commit identity: $(git -C "$R" log -1 --format=%an)"; fi

# --- 12. the lane is a REAL mutex, taken from a second unrelated process ----------------------
# Not a sibling worker and not a child of this harness's lane invocation: a bare flock on
# the same lock file, exactly what a second scheduled job is. The lane must be BUSY.
R="$(new_repo lane-busy)"
COMMON="$(git -C "$R" rev-parse --git-common-dir)"
case "$COMMON" in /*) ;; *) COMMON="$(cd "$R" && cd "$COMMON" && pwd)" ;; esac
LOCKFILE="$COMMON/ac2-swarm-commit.lock"
flock -w 10 "$LOCKFILE" sleep 6 &
HOLDER=$!
sleep 1
out="$(cd "$R" && env -i PATH="$PATH" HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" \
        "$LANE" --identity second-non-worker-job --message-file msg.txt --path mine.txt \
        --timeout 1 --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 4 ] && printf '%s' "$out" | grep -q 'LANE-BUSY'; then
  pass "non-worker second process holding the lane makes the next writer wait, then refuse (exit 4)"
else fail "lane-busy: rc=$rc out=$out"; fi
if [ "$(git -C "$R" rev-parse HEAD)" = "$(git -C "$R" rev-parse origin/main)" ]; then
  pass "a busy lane commits nothing"
else fail "a busy lane committed anyway"; fi
wait "$HOLDER" 2>/dev/null
# and the lane is takeable again once the holder is gone
out="$(cd "$R" && "$LANE" --identity third-job --message-file msg.txt --path mine.txt --no-push 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then pass "the lane is released and takeable again"
else fail "lane not released: rc=$rc out=$out"; fi

# --- 13. the lock is repo-global: git common dir, and .git as a FILE -------------------------
# In a linked worktree `.git` is a FILE, not a directory — the same shape every neoMeta app
# has as a submodule. A literal .git/<name>.lock path never opens there and the mutex
# silently does nothing, so the lane must resolve through --git-common-dir.
R="$(new_repo common-dir)"
git -C "$R" add -- mine.txt >/dev/null 2>&1
git -C "$R" commit -qm "settle worktree"
WT="$WORKDIR/common-dir-wt"
if git -C "$R" worktree add -q -b wtbranch "$WT" >/dev/null 2>&1; then
  if [ -f "$WT/.git" ] && [ ! -d "$WT/.git" ]; then
    pass "linked worktree reproduces the submodule shape (.git is a FILE)"
  else fail "worktree .git is not a file — the scar case was not reproduced"; fi
  printf 'wt v2\n' >"$WT/mine.txt"
  printf 'wt commit\n' >"$WT/msg.txt"
  out="$(cd "$WT" && "$LANE" --identity wt-job --message-file msg.txt --path mine.txt \
          --branch wtbranch --no-push 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then pass "the lane works where .git is a FILE"
  else fail "worktree lane: rc=$rc out=$out"; fi
  if [ -e "$R/.git/ac2-swarm-commit.lock" ]; then
    pass "the lock file lives in the shared git common dir — one lane for the whole repo"
  else fail "lock file is not in the common dir ($R/.git/)"; fi
  if [ ! -e "$WT/.git/ac2-swarm-commit.lock" ]; then
    pass "no per-worktree lock was created"
  else fail "a per-worktree lock exists — the lane is not repo-global"; fi
else
  echo "note: git worktree add unavailable; common-dir shape case not run"
fi
if grep -q 'git-common-dir' "$LANE"; then
  pass "the lane resolves its lock through --git-common-dir"
else fail "the lane does not use --git-common-dir"; fi

# --- 14. assurance declaration at birth --------------------------------------------------------
miss=""
for f in "PROBE:" "SCHEDULE:" "MODE:" "ON-FAILURE:"; do
  grep -q "$f" "$LANE" || miss="$miss $f"
done
if [ -z "$miss" ]; then pass "4-field assurance declaration present"
else fail "assurance declaration missing:$miss"; fi

echo "---"
echo "swarm-commit.test.sh: $CASES case(s), $FAILURES failure(s)"
[ "$FAILURES" -eq 0 ]
