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

# --- 1. a dirty tracked file does NOT refuse: it is named, never pushed, never touched ----
R="$(new_repo dirty-tree)"
printf 'uncommitted edit\n' >>"$R/tracked.txt"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q 'REFUSED' \
   && printf '%s' "$out" | grep -q 'NOT part of this push' \
   && printf '%s' "$out" | grep -q 'tracked.txt' \
   && [ "$(tail -1 "$R/tracked.txt")" = "uncommitted edit" ]; then
  pass "a dirty tracked file no longer refuses: named in the output, left untouched on disk"
else fail "dirty-tree: rc=$rc out=$out"; fi
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
# The SAME repo's tracked SOURCE file is not exempt — a declared prefix exempts only what it
# names, never code paths — so it is still reported (and still triggers the clean export).
printf 'uncommitted source edit\n' >>"$R/tracked.txt"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'NOT part of this push' \
   && printf '%s' "$out" | grep -q 'tracked.txt' && ! printf '%s' "$out" | grep -q 'memory/x.md'; then
  pass "a declared live-state allowlist never exempts a tracked SOURCE file — still reported, naming it"
else fail "dirty-declared-allow-code-still-reported: rc=$rc out=$out"; fi
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
# The proof is dispatched exactly once, at publish, by ac-publish's prove step — never per push. push.sh
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
  pass "green: pushed, and no quality-gate dispatch is attempted (gh never invoked; the proof is ac-publish's, at publish)"
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

# 5d. --check-only run directly: a dirty tree is noted, not refused; a green tree is never
# pushed or merged.
R="$(new_repo check-only-direct)"
printf 'uncommitted edit\n' >>"$R/tracked.txt"
out="$(cd "$R" && "$PUSH" --check-only 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'NOT part of this push'; then
  pass "--check-only notes a dirty tree and passes (exit 0, file named)"
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

# --- 7. a dirty tree does not hold committed work back -------------------------------------
lint_rejects_BAD() {  # a committed whole-tree check that goes red when tracked.txt holds BAD
  cat >"$1/lint.sh" <<'EOF'
#!/usr/bin/env bash
echo "lint.sh: ran in $PWD"
grep -q BAD tracked.txt && { echo "lint.sh: BAD found"; exit 1; }
exit 0
EOF
  chmod +x "$1/lint.sh"
  git -C "$1" add -- lint.sh
  git -C "$1" commit -qm "add lint.sh"
}
worktrees_of() { git -C "$1" worktree list | wc -l | tr -d ' '; }

# 7a. committed work lands although UNRELATED tracked files are modified; the checks saw the
# committed tree (not the dirty one) and the export is gone afterwards.
R="$(new_repo dirty-unrelated)"
printf 'other\n' >"$R/other.txt"; git -C "$R" add -- other.txt; git -C "$R" commit -qm "other"; git -C "$R" push -q origin main
lint_rejects_BAD "$R"
printf 'committed work\n' >"$R/work.txt"; git -C "$R" add -- work.txt; git -C "$R" commit -qm "committed work"
printf 'BAD edit nobody committed\n' >>"$R/other.txt"
printf 'BAD uncommitted\n' >>"$R/tracked.txt"        # would turn lint.sh red if it ran in place
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git --git-dir="$R.git" rev-parse main)" = "$HEAD_SHA" ] \
   && printf '%s' "$out" | grep -q 'lint.sh: ran in .*push-sh-export' \
   && ! printf '%s' "$out" | grep -q 'BAD found' \
   && ! printf '%s' "$out" | grep -q 'also touched by an unpushed commit' \
   && [ "$(worktrees_of "$R")" = "1" ] \
   && grep -q 'BAD edit nobody committed' "$R/other.txt" && grep -q 'BAD uncommitted' "$R/tracked.txt"; then
  pass "dirty unrelated files: committed work pushes, checks ran in a clean export, export removed, dirty edits untouched"
else fail "dirty-unrelated: rc=$rc worktrees=$(worktrees_of "$R") out=$out"; fi

# 7b. the protection is kept: a red check on the COMMITTED tree still refuses and pushes
# nothing, dirty tree or not.
R="$(new_repo dirty-committed-red)"
lint_rejects_BAD "$R"
printf 'BAD but committed\n' >>"$R/tracked.txt"; git -C "$R" commit -qam "commit a red tree"
printf 'unrelated dirt\n' >>"$R/lint.sh"
BEFORE="$(git --git-dir="$R.git" rev-parse main)"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'REFUSED \[red-check\]' \
   && printf '%s' "$out" | grep -q 'BAD found' && [ "$BEFORE" = "$(git --git-dir="$R.git" rev-parse main)" ] \
   && [ "$(worktrees_of "$R")" = "1" ]; then
  pass "a red check on the committed tree still refuses (exit 1) with a dirty tree, pushes nothing, leaves no export"
else fail "dirty-committed-red: rc=$rc out=$out"; fi

# 7c. a dirty file that an unpushed commit ALSO touches is named; the commit still pushes.
R="$(new_repo dirty-overlap)"
printf 'commit edit\n' >>"$R/tracked.txt"; git -C "$R" commit -qam "edit tracked.txt"
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"
printf 'second, uncommitted edit\n' >>"$R/tracked.txt"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git --git-dir="$R.git" rev-parse main)" = "$HEAD_SHA" ] \
   && printf '%s' "$out" | grep -q 'also touched by an unpushed commit' \
   && [ "$(tail -1 "$R/tracked.txt")" = "second, uncommitted edit" ]; then
  pass "a dirty file an unpushed commit also touches is named; the commit pushes as committed, the edit stays local"
else fail "dirty-overlap: rc=$rc out=$out"; fi

# 7d. an origin merge that would overwrite a dirty file is still refused, and loses nothing.
R="$(new_repo dirty-merge-overlap)"
CLONE="$WORKDIR/dirty-merge-overlap-clone"
git clone -q "$R.git" "$CLONE"
git -C "$CLONE" config user.email push-test@test.local; git -C "$CLONE" config user.name "push-sh-test"
git -C "$CLONE" config commit.gpgsign false
printf 'origin edit\n' >>"$CLONE/tracked.txt"; git -C "$CLONE" commit -qam "origin edits tracked.txt"; git -C "$CLONE" push -q origin main
printf 'mine\n' >"$R/mine.txt"; git -C "$R" add -- mine.txt; git -C "$R" commit -qm "mine"
printf 'dirty edit of the file origin changed\n' >>"$R/tracked.txt"
BEFORE="$(git --git-dir="$R.git" rev-parse main)"
out="$(cd "$R" && "$PUSH" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'REFUSED \[merge-conflict\]' \
   && [ "$BEFORE" = "$(git --git-dir="$R.git" rev-parse main)" ] \
   && [ "$(tail -1 "$R/tracked.txt")" = "dirty edit of the file origin changed" ]; then
  pass "a merge that would overwrite a dirty file is still refused (exit 1), nothing pushed, the dirty edit intact"
else fail "dirty-merge-overlap: rc=$rc out=$out"; fi

# 7e. through a pre-push hook (--check-only), a dirty tree does not block the plain push.
R="$(new_repo hook-dirty)"
install_hook "$R" "--check-only"
printf 'v2\n' >"$R/work.txt"; git -C "$R" add -- work.txt; git -C "$R" commit -qm "a green change"
printf 'unrelated dirt\n' >>"$R/tracked.txt"
out="$(cd "$R" && git push origin main 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git --git-dir="$R.git" rev-parse main)" = "$(git -C "$R" rev-parse HEAD)" ] \
   && [ "$(worktrees_of "$R")" = "1" ]; then
  pass "pre-push hook (--check-only) with a dirty tree: the plain push exits 0, origin equals HEAD, no export left"
else fail "hook-dirty: rc=$rc out=$out"; fi

echo "---"
echo "CASES=$CASES FAILURES=$FAILURES"
exit $([ "$FAILURES" -eq 0 ] && echo 0 || echo 1)
