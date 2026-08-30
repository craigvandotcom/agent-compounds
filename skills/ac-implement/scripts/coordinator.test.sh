#!/usr/bin/env bash
#
# coordinator.test.sh — proof harness for coordinator.sh.
#
# Every refusal must be shown to FIRE, not merely to be absent on a clean repo. The live
# smoke run passed both refusals with an empty board — which proves nothing about either,
# and is exactly the vacuous-pass shape this pipeline exists to catch. `br` is mocked; git
# is REAL, because the staleness question is a real-git question and a mocked answer would
# only echo the author's belief about it.
#
# Exit 0 = all cases pass.
set -uo pipefail

GATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/coordinator.sh"
[ -x "$GATE" ] || { echo "coordinator.test: NOT-GATED — $GATE is not executable"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "coordinator.test: SKIP — no git"; exit 77; }
command -v jq  >/dev/null 2>&1 || { echo "coordinator.test: SKIP — no jq";  exit 77; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   — $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL — $1"; }

W="$(mktemp -d "${TMPDIR:-/tmp}/coord.XXXXXX")"
trap 'rm -rf "$W"' EXIT
BIN="$W/bin"; mkdir -p "$BIN"; PATH="$BIN:$PATH"; export PATH

# Mock `br`: coordination status is driven by AC2_TEST_CLAIMS; sync --flush-only touches the
# ledger unless told to fail. Everything else is a no-op.
cat >"$BIN/br" <<'MOCKBR'
#!/usr/bin/env bash
case "${1:-}" in
  coordination)
    [ "${AC2_TEST_CS_BROKEN:-0}" = "1" ] && { echo "not json"; exit 0; }
    if [ -n "${AC2_TEST_CLAIMS:-}" ]; then printf '%s' "$AC2_TEST_CLAIMS"
    else printf '{"summary":{},"claims":[]}'; fi ;;
  sync)
    [ "${AC2_TEST_FLUSH_FAIL:-0}" = "1" ] && exit 1
    [ -n "${AC2_TEST_LEDGER:-}" ] && printf '{"id":"x","status":"closed"}\n' >>"$AC2_TEST_LEDGER"
    exit 0 ;;
  *) exit 0 ;;
esac
MOCKBR
chmod +x "$BIN/br"

# A real git repo with a real upstream.
mkrepo() {
  local d="$W/$1"; rm -rf "$d" "$W/$1.git"
  git init -q --bare "$W/$1.git"
  git -C "$W/$1.git" symbolic-ref HEAD refs/heads/main
  git init -q -b main "$d"; cd "$d"
  git config user.email t@t; git config user.name t; git config commit.gpgsign false
  mkdir -p .beads skills/ac-implement/scripts
  cp "$GATE" skills/ac-implement/scripts/coordinator.sh
  # a swarm-commit stand-in: the lane itself has its own harness; here it must only be
  # callable and honest about landing, so the LEDGER-WRITE leg has something real to verify.
  cat >skills/ac-implement/scripts/swarm-commit.sh <<'SC'
#!/usr/bin/env bash
[ "${AC2_TEST_COMMIT_REFUSE:-0}" = "1" ] && { echo "swarm-commit: refused (test)"; exit 1; }
[ "${AC2_TEST_COMMIT_NOOP:-0}" = "1" ] && exit 0
p=""; while [ $# -gt 0 ]; do case "$1" in --path) p="$2"; shift 2;; *) shift;; esac; done
git add -- "$p" && git -c user.email=t@t -c user.name=t commit -q -m "ledger" -- "$p"
SC
  chmod +x skills/ac-implement/scripts/swarm-commit.sh
  printf '{"id":"a","status":"open"}\n' >.beads/issues.jsonl
  git add -A >/dev/null; git commit -qm init
  git remote add origin "$W/$1.git"; git push -q -u origin HEAD:main >/dev/null 2>&1
  cd "$W"
}

run() { ( cd "$1" && shift && bash skills/ac-implement/scripts/coordinator.sh "$@" 2>&1 ); }
rc_of() { ( cd "$1" && shift && bash skills/ac-implement/scripts/coordinator.sh "$@" >/dev/null 2>&1 ); echo $?; }

echo "coordinator.test: argument and precondition refusals"
mkrepo r1
[ "$(rc_of "$W/r1")" -eq 2 ] && ok "no --run is NOT-GATED, not a silent default" || bad "missing --run did not exit 2"
[ "$(rc_of "$W/r1" --run x --bogus)" -eq 2 ] && ok "an unknown argument is NOT-GATED" || bad "unknown arg did not exit 2"

echo "coordinator.test: LEDGER-STALE — the refusal that earns the file"
mkrepo r2
# A second clone pushes a ledger change; r2 fetches but does not merge -> upstream ahead.
git clone -q "$W/r2.git" "$W/r2b" && cd "$W/r2b" \
  && git config user.email t@t && git config user.name t \
  && printf '{"id":"b","status":"closed"}\n' >>.beads/issues.jsonl \
  && git commit -qam "other writer closes b" && git push -q origin HEAD:main && cd "$W"
( cd "$W/r2" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
out="$(run "$W/r2" --run R --dry-run)"; rc=$(rc_of "$W/r2" --run R --dry-run)
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'LEDGER-STALE' \
  && ok "an upstream ahead ON THE LEDGER is REFUSED before any flush" \
  || bad "stale upstream was not refused (rc=$rc): $out"
printf '%s' "$out" | grep -q 'sync --import-only' \
  && ok "the refusal names the import that fixes it" || bad "refusal does not name the remedy"

# Level with upstream -> the leg passes.
mkrepo r3
( cd "$W/r3" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
[ "$(rc_of "$W/r3" --run R --dry-run)" -eq 0 ] \
  && ok "level with upstream, the ledger leg passes" || bad "a level repo was refused"

# No upstream at all -> skipped WITH A LINE, never silently treated as clean.
mkrepo r4
( cd "$W/r4" && git branch -q --unset-upstream >/dev/null 2>&1; git remote remove origin >/dev/null 2>&1 )
out="$(run "$W/r4" --run R --dry-run)"
printf '%s' "$out" | grep -q 'LEDGER-STALE skipped' \
  && ok "with no upstream the leg SAYS it skipped rather than passing quietly" \
  || bad "no-upstream case was silent: $out"

echo "coordinator.test: ORPHANS — and it must discriminate between runs"
CLAIM='{"summary":{},"claims":[{"issue":{"id":"ac-1","status":"in_progress","assignee":"swarm-RUNA-Cave"}}]}'
mkrepo r5
( cd "$W/r5" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
out="$(AC2_TEST_CLAIMS="$CLAIM" run "$W/r5" --run RUNA --dry-run)"
rc=$( AC2_TEST_CLAIMS="$CLAIM" rc_of "$W/r5" --run RUNA --dry-run )
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'ORPHANS' && printf '%s' "$out" | grep -q 'ac-1' \
  && ok "a live claim under THIS run's actor is REFUSED and named" \
  || bad "orphan not refused (rc=$rc): $out"
# THE DISCRIMINATING CASE: another run's worker is not this run's orphan.
[ "$( AC2_TEST_CLAIMS="$CLAIM" rc_of "$W/r5" --run RUNB --dry-run )" -eq 0 ] \
  && ok "a claim under a DIFFERENT run's actor is left alone" \
  || bad "the sweep stole a sibling run's live claim"

echo "coordinator.test: a gate that cannot verify says so"
[ "$( AC2_TEST_CS_BROKEN=1 rc_of "$W/r5" --run RUNA --dry-run )" -eq 2 ] \
  && ok "unparseable coordination status is NOT-GATED, never a pass" || bad "broken status did not exit 2"
( cd "$W/r5" && rm -f .beads/issues.jsonl )
[ "$(rc_of "$W/r5" --run RUNA --dry-run)" -eq 2 ] \
  && ok "a missing ledger is NOT-GATED" || bad "missing ledger did not exit 2"

echo "coordinator.test: the write leg"
mkrepo r6
( cd "$W/r6" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
BEFORE=$( cd "$W/r6" && git rev-parse HEAD )
AC2_TEST_LEDGER="$W/r6/.beads/issues.jsonl" run "$W/r6" --run R >/dev/null 2>&1
AFTER=$( cd "$W/r6" && git rev-parse HEAD )
[ "$BEFORE" != "$AFTER" ] && ok "a changed ledger is flushed and committed" || bad "the ledger commit did not land"

mkrepo r7
( cd "$W/r7" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
B7=$( cd "$W/r7" && git rev-parse HEAD )
out="$(run "$W/r7" --run R)"          # no AC2_TEST_LEDGER -> flush changes nothing
[ "$( cd "$W/r7" && git rev-parse HEAD )" = "$B7" ] && printf '%s' "$out" | grep -q 'ledger unchanged' \
  && ok "an unchanged ledger commits NOTHING and says so" || bad "empty flush still moved HEAD: $out"

# A commit that reports success without landing is the silent-write failure this leg exists for.
mkrepo r8
( cd "$W/r8" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
out="$( AC2_TEST_LEDGER="$W/r8/.beads/issues.jsonl" AC2_TEST_COMMIT_NOOP=1 run "$W/r8" --run R )"
rc=$( AC2_TEST_LEDGER="$W/r8/.beads/issues.jsonl" AC2_TEST_COMMIT_NOOP=1 rc_of "$W/r8" --run R )
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'LEDGER-WRITE' \
  && ok "a commit that exits 0 without moving HEAD is REFUSED, not believed" \
  || bad "silent no-op commit was accepted (rc=$rc): $out"

mkrepo r9
( cd "$W/r9" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
[ "$( AC2_TEST_FLUSH_FAIL=1 rc_of "$W/r9" --run R )" -eq 2 ] \
  && ok "a failed flush is NOT-GATED — the disk ledger is not trusted" || bad "failed flush was not NOT-GATED"

echo "coordinator.test: the script declares its own assurance"
miss=""
for f in "PROBE:" "SCHEDULE:" "MODE:" "ON-FAILURE:"; do grep -q "$f" "$GATE" || miss="$miss $f"; done
[ -z "$miss" ] && ok "coordinator.sh carries its 4-field assurance declaration at birth" \
  || bad "coordinator.sh declares no$miss"

echo ""
echo "coordinator.test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
