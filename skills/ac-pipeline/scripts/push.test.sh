#!/usr/bin/env bash
# push.test.sh — proof harness for push.sh, the one push step that gates the whole
# committed tree (ac-ftfz.7).
#
# Every case builds a REAL git repository with a REAL bare remote and drives push.sh
# end-to-end — no mock git. Each refusal case asserts BOTH the exit code AND that the
# output NAMES what refused it.
#
# Exit 0 = all cases pass.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUSH="$SCRIPT_DIR/push.sh"
CASES=0
FAILURES=0

pass() { CASES=$((CASES+1)); echo "ok   $*"; }
fail() { CASES=$((CASES+1)); FAILURES=$((FAILURES+1)); echo "FAIL $*"; }

[ -x "$PUSH" ] || { echo "FAIL push.sh is missing or not executable at $PUSH"; exit 1; }

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/push-sh-test.XXXXXX")"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# A repo with a bare origin and one tracked, already-pushed file.
new_repo() {
  d="$WORKDIR/$1"
  mkdir -p "$d"
  git init -q "$d"
  git -C "$d" symbolic-ref HEAD refs/heads/main
  git -C "$d" config user.email push-test@test.local
  git -C "$d" config user.name "push-sh-test"
  git -C "$d" config commit.gpgsign false
  git init -q --bare "$d.git"
  git -C "$d" remote add origin "$d.git"
  printf 'seed v1\n' >"$d/tracked.txt"
  git -C "$d" add -- tracked.txt
  git -C "$d" commit -qm seed
  git -C "$d" push -q origin main
  echo "$d"
}

# --- 1. refusal: dirty tracked source, naming the file ------------------------------------
R="$(new_repo dirty-tree)"
printf 'uncommitted edit\n' >>"$R/tracked.txt"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[dirty-tree\]' \
   && printf '%s' "$out" | grep -q 'tracked.txt'; then
  pass "refuses a dirty tracked file, naming it"
else fail "dirty-tree: rc=$rc out=$out"; fi
if [ -z "$(git -C "$R" diff)" ]; then :; else :; fi   # working tree left untouched either way
git -C "$R" checkout -- tracked.txt

# --- 1b. .beads/ is EXEMPT from the dirty-tree refusal (the ledger's own committer lane) --
R="$(new_repo dirty-beads)"
mkdir -p "$R/.beads"
printf '{"id":"seed"}\n' >"$R/.beads/issues.jsonl"
git -C "$R" add -- .beads/issues.jsonl
git -C "$R" commit -qm "seed the ledger"
git -C "$R" push -q origin main
printf '{"id":"mid-batch-edit"}\n' >>"$R/.beads/issues.jsonl"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$R" rev-parse origin/main)" = "$(git -C "$R" rev-parse HEAD)" ]; then
  pass "a dirty tracked .beads/issues.jsonl does NOT refuse the push — the ledger has its own committer lane"
else fail "dirty-beads-exempt: rc=$rc out=$out"; fi

# --- 1c. a repo-declared extra allow (.push-dirty-allow) exempts ITS prefixes only --------
R="$(new_repo dirty-declared-allow)"
mkdir -p "$R/memory"
printf '# comment (ignored)\nmemory/\n' >"$R/.push-dirty-allow"
printf 'seed note\n' >"$R/memory/x.md"
git -C "$R" add -- .push-dirty-allow memory/x.md
git -C "$R" commit -qm "declare memory/ as live-state"
git -C "$R" push -q origin main
printf 'a live edit\n' >>"$R/memory/x.md"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$R" rev-parse origin/main)" = "$(git -C "$R" rev-parse HEAD)" ]; then
  pass "a repo's own .push-dirty-allow declaration (memory/) exempts a dirty tracked file under it"
else fail "dirty-declared-allow: rc=$rc out=$out"; fi
# The SAME repo's tracked SOURCE file is still refused — a declared prefix exempts only
# what it names, never code paths.
printf 'uncommitted source edit\n' >>"$R/tracked.txt"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[dirty-tree\]' \
   && printf '%s' "$out" | grep -q 'tracked.txt'; then
  pass "a declared live-state allowlist never exempts a tracked SOURCE file — still refused, naming it"
else fail "dirty-declared-allow-code-still-refuses: rc=$rc out=$out"; fi
git -C "$R" checkout -- tracked.txt

# --- 2. origin ahead: merged, never a history-discarding rewrite --------------------------
R="$(new_repo merge-not-rewrite)"
CLONE="$WORKDIR/merge-not-rewrite-clone"
git clone -q "$R.git" "$CLONE"
git -C "$CLONE" config user.email push-test@test.local
git -C "$CLONE" config user.name "push-sh-test"
git -C "$CLONE" config commit.gpgsign false
printf 'from the other clone\n' >"$CLONE/other.txt"
git -C "$CLONE" add -- other.txt
git -C "$CLONE" commit -qm "other clone's commit"
git -C "$CLONE" push -q origin main
# Meanwhile R makes its OWN local commit, not yet pushed — origin now has commits R lacks.
printf 'from this repo\n' >"$R/mine.txt"
git -C "$R" add -- mine.txt
git -C "$R" commit -qm "this repo's own commit"
MINE_SHA="$(git -C "$R" rev-parse HEAD)"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] \
   && git -C "$R" cat-file -e "$MINE_SHA" 2>/dev/null \
   && git -C "$R" log --oneline | grep -q "other clone's commit" \
   && [ "$(git -C "$R" rev-parse HEAD)" = "$(git -C "$R" rev-parse origin/main)" ]; then
  pass "origin ahead: brought in with a merge, the prior local commit object is untouched, both histories land"
else
  fail "merge-not-rewrite: rc=$rc mine_sha=$MINE_SHA out=$out"
fi

# --- 3. a failing whole-tree check: exit 1, nothing pushed --------------------------------
R="$(new_repo failing-check)"
cat >"$R/lint.sh" <<'EOF'
#!/usr/bin/env bash
echo "lint.sh: deliberately red for the test"
exit 1
EOF
chmod +x "$R/lint.sh"
git -C "$R" add -- lint.sh
git -C "$R" commit -qm "add a red lint.sh"
BEFORE="$(git -C "$R" rev-parse origin/main)"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
AFTER="$(git -C "$R" rev-parse origin/main)"
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'REFUSED \[red-check\]' \
   && printf '%s' "$out" | grep -q 'NEXT: fix-forward' && [ "$BEFORE" = "$AFTER" ]; then
  pass "a failing whole-tree check refuses (exit 1), names NEXT: fix-forward, and pushes nothing"
else
  fail "failing-check: rc=$rc before=$BEFORE after=$AFTER out=$out"
fi

# --- 4. green: pushed, and NO quality-gate dispatch is attempted (bd-fugib.8) -------------
# The proof is dispatched exactly once, at publish, by ac-prove — never per push. push.sh
# must not even look at quality-gate.yml: a fake gh on PATH records every invocation and
# the case asserts the log is EMPTY (gh untouched proves nothing was dispatched).
R="$(new_repo green-no-dispatch)"
mkdir -p "$R/.github/workflows"
: >"$R/.github/workflows/quality-gate.yml"
FAKEBIN="$WORKDIR/fakebin"
mkdir -p "$FAKEBIN"
GHLOG="$WORKDIR/gh.invocations"
: >"$GHLOG"
cat >"$FAKEBIN/gh" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$GHLOG"
exit 0
EOF
chmod +x "$FAKEBIN/gh"
printf 'v2\n' >>"$R/tracked.txt"
git -C "$R" add -- tracked.txt
git -C "$R" commit -qm "a green change"
GREEN_SHA="$(git -C "$R" rev-parse HEAD)"
out="$(cd "$R" && PATH="$FAKEBIN:$PATH" "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] \
   && [ "$(git -C "$R" rev-parse origin/main)" = "$GREEN_SHA" ] \
   && printf '%s' "$out" | grep -q 'push.sh: pushed' \
   && ! printf '%s' "$out" | grep -q 'dispatched' \
   && [ ! -s "$GHLOG" ] ; then
  pass "green: pushed, and no quality-gate dispatch is attempted (gh never invoked; the proof is ac-prove's, at publish)"
else
  fail "green-no-dispatch: rc=$rc out=$out ghlog=$(cat "$GHLOG" 2>/dev/null)"
fi

# --- 5. pre-push hook wiring: a hook that calls push.sh, the outer push exits 0 -------------
# A hook that runs the FULL push.sh lets push.sh's own step-4 push land; the OUTER `git push`
# that fired the hook then updates origin from its pre-hook SHA and is rejected ("cannot lock
# ref ... expected Y") — non-zero though it landed. `--check-only` makes the hook run the gate
# alone, so the outer push does the one transfer.
install_hook() {  # $1 repo, $2 extra push.sh args
  cat >"$1/.git/hooks/pre-push" <<EOF
#!/usr/bin/env sh
# the nested push re-enters this hook; the guard is the app's own recursion workaround
[ "\${AC_PRE_PUSH_NESTED:-0}" = "1" ] && exit 0
AC_PRE_PUSH_NESTED=1 "$PUSH" $2
EOF
  chmod +x "$1/.git/hooks/pre-push"
}

# 5a. the double push, pinned: a hook calling the FULL script makes a landed push exit non-zero.
R="$(new_repo hook-full-mode)"
install_hook "$R" ""
printf 'v2\n' >>"$R/tracked.txt"
git -C "$R" add -- tracked.txt
git -C "$R" commit -qm "a green change"
out="$(cd "$R" && git push origin main 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ "$(git --git-dir="$R.git" rev-parse main)" = "$(git -C "$R" rev-parse HEAD)" ]; then
  pass "a hook running the full push.sh lands the push AND the outer push exits non-zero (the double push)"
else fail "hook-full-mode: rc=$rc out=$out"; fi

# 5b. the fix: the hook runs --check-only; the plain push exits 0 and origin equals HEAD.
R="$(new_repo hook-check-only)"
install_hook "$R" "--check-only"
printf 'v2\n' >>"$R/tracked.txt"
git -C "$R" add -- tracked.txt
git -C "$R" commit -qm "a green change"
out="$(cd "$R" && git push origin main 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git --git-dir="$R.git" rev-parse main)" = "$(git -C "$R" rev-parse HEAD)" ] \
   && printf '%s' "$out" | grep -q 'check-only'; then
  pass "hook running push.sh --check-only: a plain git push exits 0 and origin/main equals local HEAD"
else fail "hook-check-only: rc=$rc out=$out"; fi

# 5c. a gate failure through the hook: the plain push exits non-zero, nothing pushed.
R="$(new_repo hook-check-only-red)"
install_hook "$R" "--check-only"
cat >"$R/lint.sh" <<'EOF'
#!/usr/bin/env bash
echo "lint.sh: deliberately red for the test"
exit 1
EOF
chmod +x "$R/lint.sh"
git -C "$R" add -- lint.sh
git -C "$R" commit -qm "add a red lint.sh"
BEFORE="$(git --git-dir="$R.git" rev-parse main)"
out="$(cd "$R" && git push origin main 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'REFUSED \[red-check\]' \
   && [ "$BEFORE" = "$(git --git-dir="$R.git" rev-parse main)" ]; then
  pass "hook running push.sh --check-only: a failing whole-tree check exits non-zero and pushes nothing"
else fail "hook-check-only-red: rc=$rc before=$BEFORE out=$out"; fi

# 5d. --check-only run directly: the dirty-tree refusal holds; a green tree is never pushed
# or merged.
R="$(new_repo check-only-direct)"
printf 'uncommitted edit\n' >>"$R/tracked.txt"
out="$(cd "$R" && "$PUSH" --check-only 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$out" | grep -q 'REFUSED \[dirty-tree\]'; then
  pass "--check-only keeps the dirty-tree refusal (exit 3, file named)"
else fail "check-only-dirty: rc=$rc out=$out"; fi
git -C "$R" checkout -- tracked.txt
printf 'unpushed\n' >>"$R/tracked.txt"
git -C "$R" add -- tracked.txt
git -C "$R" commit -qm "unpushed change"
BEFORE="$(git --git-dir="$R.git" rev-parse main)"
HEAD_BEFORE="$(git -C "$R" rev-parse HEAD)"
out="$(cd "$R" && "$PUSH" --check-only 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$BEFORE" = "$(git --git-dir="$R.git" rev-parse main)" ] \
   && [ "$HEAD_BEFORE" = "$(git -C "$R" rev-parse HEAD)" ]; then
  pass "--check-only on a green tree exits 0 and neither pushes nor moves local HEAD"
else fail "check-only-green: rc=$rc out=$out"; fi

# --- 6. detached worktree: HEAD lands on origin, the diverged local branch is untouched ----
# A detached worktree shares refs with the live checkout, so `main` there is the LIVE main.
# Pushing the branch ref pushed (or was rejected for) another session's commits, never the
# worktree's HEAD. Local main here is ahead 1 / behind 1; the worktree HEAD is origin/main + 1.
R="$(new_repo detached-worktree)"
printf 'unpushed live work\n' >"$R/live.txt"
git -C "$R" add -- live.txt
git -C "$R" commit -qm "live checkout's unpushed commit"
LIVE_MAIN="$(git -C "$R" rev-parse main)"
CLONE="$WORKDIR/detached-worktree-clone"
git clone -q "$R.git" "$CLONE"
git -C "$CLONE" config user.email push-test@test.local
git -C "$CLONE" config user.name "push-sh-test"
git -C "$CLONE" config commit.gpgsign false
printf 'from the other clone\n' >"$CLONE/other.txt"
git -C "$CLONE" add -- other.txt
git -C "$CLONE" commit -qm "other clone's commit"
git -C "$CLONE" push -q origin main
git -C "$R" fetch -q origin
WT="$WORKDIR/detached-worktree-wt"
git -C "$R" worktree add -q --detach "$WT" origin/main
printf 'tidy result\n' >"$WT/tidy.txt"
git -C "$WT" add -- tidy.txt
git -C "$WT" commit -qm "detached tidy commit"
WT_HEAD="$(git -C "$WT" rev-parse HEAD)"
out="$(cd "$WT" && "$PUSH" --branch main 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] \
   && [ "$(git --git-dir="$R.git" rev-parse main)" = "$WT_HEAD" ] \
   && [ "$(git -C "$R" rev-parse main)" = "$LIVE_MAIN" ]; then
  pass "detached worktree: push.sh lands HEAD on origin/main and leaves the diverged local main untouched"
else fail "detached-worktree: rc=$rc live=$LIVE_MAIN wt=$WT_HEAD origin=$(git --git-dir="$R.git" rev-parse main) out=$out"; fi

echo "---"
echo "CASES=$CASES FAILURES=$FAILURES"
exit $([ "$FAILURES" -eq 0 ] && echo 0 || echo 1)
