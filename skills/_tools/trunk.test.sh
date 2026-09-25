#!/usr/bin/env bash
#
# trunk.test.sh — hermetic proof for the remote-trunk resolver.
#
# Every fixture uses a local bare remote: the repair path is exercised without network, the
# offline path is forced by replacing the remote URL after cloning, and the final fixture
# has neither a usable remote HEAD nor main/master.  The suite runs from any cwd.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$HERE/trunk.sh"
PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf '  ok   — %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL — %s\n' "$*"; }

[ -x "$SCRIPT" ] || { echo "trunk.test: trunk.sh missing or not executable at $SCRIPT"; exit 1; }
WORK=$(mktemp -d "${TMPDIR:-/tmp}/ac-trunk-test.XXXXXX") || {
  echo "trunk.test: cannot create scratch directory"
  exit 1
}
trap 'rm -rf "$WORK"' EXIT

run_trunk() {
  local dir="$1"
  OUT=$(cd "$dir" && "$SCRIPT" 2>"$WORK/stderr")
  RC=$?
  ERR=$(<"$WORK/stderr")
}

make_seed() {
  local seed="$1" remote="$2" branch="$3"
  mkdir -p "$seed"
  git init -q "$seed"
  git -C "$seed" config user.email trunk@test.invalid
  git -C "$seed" config user.name trunk-test
  printf 'seed\n' >"$seed/seed.txt"
  git -C "$seed" add seed.txt
  git -C "$seed" commit -qm initial
  git -C "$seed" remote add origin "$remote"
  git -C "$seed" push -q origin "HEAD:refs/heads/$branch"
}

clone_and_drop_head() {
  local remote="$1" clone="$2"
  git clone -q "$remote" "$clone" 2>/dev/null || return 1
  git -C "$clone" symbolic-ref -d refs/remotes/origin/HEAD >/dev/null 2>&1 || true
  git -C "$clone" update-ref -d refs/remotes/origin/HEAD >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------------------
printf '%s\n' 'trunk.test: case 1 — a dev-default remote repairs a deleted origin/HEAD'
# ---------------------------------------------------------------------------------------
REMOTE_DEV="$WORK/remote-dev.git"
SEED_DEV="$WORK/seed-dev"
CLONE_DEV="$WORK/clone-dev"
git init --bare -q "$REMOTE_DEV"
git --git-dir="$REMOTE_DEV" symbolic-ref HEAD refs/heads/dev
make_seed "$SEED_DEV" "$REMOTE_DEV" dev
clone_and_drop_head "$REMOTE_DEV" "$CLONE_DEV"
run_trunk "$CLONE_DEV"
[ "$RC" -eq 0 ] && [ "$OUT" = dev ] \
  && ok 'deleted origin/HEAD is repaired and the resolver prints dev' \
  || bad "expected exit 0 and dev, got rc=$RC out='$OUT' err='$ERR'"
[ "$(git -C "$CLONE_DEV" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" = origin/dev ] \
  && ok 'repair leaves origin/HEAD set to origin/dev' \
  || bad 'origin/HEAD was not repaired to origin/dev'

# ---------------------------------------------------------------------------------------
printf '%s\n' 'trunk.test: case 2 — an offline repair falls back to origin/main'
# ---------------------------------------------------------------------------------------
REMOTE_MAIN="$WORK/remote-main.git"
SEED_MAIN="$WORK/seed-main"
CLONE_MAIN="$WORK/clone-main"
git init --bare -q "$REMOTE_MAIN"
git --git-dir="$REMOTE_MAIN" symbolic-ref HEAD refs/heads/main
make_seed "$SEED_MAIN" "$REMOTE_MAIN" main
clone_and_drop_head "$REMOTE_MAIN" "$CLONE_MAIN"
git -C "$CLONE_MAIN" remote set-url origin "$WORK/offline-remote.git"
run_trunk "$CLONE_MAIN"
[ "$RC" -eq 0 ] && [ "$OUT" = main ] \
  && ok 'unreachable origin/HEAD falls back to the local origin/main tracking ref' \
  || bad "expected exit 0 and main, got rc=$RC out='$OUT' err='$ERR'"
printf '%s' "$ERR" | grep -q 'falling back to origin/main, origin/master' \
  && ok 'offline fallback says why it used the tracking refs' \
  || bad "offline warning missing: $ERR"

# ---------------------------------------------------------------------------------------
printf '%s\n' 'trunk.test: case 3 — no origin/HEAD and no main/master exits 2'
# ---------------------------------------------------------------------------------------
REMOTE_EMPTY="$WORK/remote-no-default.git"
SEED_TOPIC="$WORK/seed-topic"
CLONE_EMPTY="$WORK/clone-no-default"
git init --bare -q "$REMOTE_EMPTY"
git --git-dir="$REMOTE_EMPTY" symbolic-ref HEAD refs/heads/missing
make_seed "$SEED_TOPIC" "$REMOTE_EMPTY" topic
clone_and_drop_head "$REMOTE_EMPTY" "$CLONE_EMPTY"
# The local clone still has origin/topic, but no usable remote HEAD and no main/master.
git -C "$CLONE_EMPTY" remote set-url origin "$WORK/offline-remote.git"
run_trunk "$CLONE_EMPTY"
[ "$RC" -eq 2 ] && [ -z "$OUT" ] \
  && ok 'missing HEAD/main/master refuses with exit 2 and no trunk name' \
  || bad "expected exit 2 and empty stdout, got rc=$RC out='$OUT' err='$ERR'"
printf '%s' "$ERR" | grep -q 'tried origin/HEAD, origin/main, origin/master' \
  && ok 'failure names every resolution source it tried' \
  || bad "failure did not name its tried sources: $ERR"

printf 'trunk.test: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$PASS" -gt 0 ] || exit 1
[ "$FAIL" -eq 0 ]
