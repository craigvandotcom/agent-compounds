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
BR_CALL_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/skills/_tools/br-call.sh"
[ -x "$GATE" ] || { echo "coordinator.test: NOT-GATED — $GATE is not executable"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "coordinator.test: SKIP — no git"; exit 77; }
command -v jq  >/dev/null 2>&1 || { echo "coordinator.test: SKIP — no jq";  exit 77; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   — $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL — $1"; }

W="$(mktemp -d "${TMPDIR:-/tmp}/coord.XXXXXX")"
trap 'rm -rf "$W"' EXIT
BIN="$W/bin"; mkdir -p "$BIN"; PATH="$BIN:$PATH"; export PATH

# Mock `br`: coordination status is driven by AC2_TEST_CLAIMS; AC2_TEST_CS_FAIL makes that
# read exit non-zero (never a zero-exit empty payload — that fail-opens as "no claims").
# sync --flush-only touches the ledger unless told to fail. Everything else is a no-op.
cat >"$BIN/br" <<'MOCKBR'
#!/usr/bin/env bash
case "${1:-}" in
  coordination)
    [ "${AC2_TEST_CS_FAIL:-0}" = "1" ] && exit 2
    [ "${AC2_TEST_CS_BROKEN:-0}" = "1" ] && { echo "not json"; exit 0; }
    if [ -n "${AC2_TEST_CLAIMS:-}" ]; then printf '%s' "$AC2_TEST_CLAIMS"
    else printf '{"summary":{},"claims":[]}'; fi ;;
  list)
    # br 0.1.14 has no `coordination` subcommand at all, so the gate falls back to
    # `br list --json`, whose records carry the holder FLAT at .assignee.
    [ -n "${AC2_TEST_LIST:-}" ] && { printf '%s' "$AC2_TEST_LIST"; exit 0; }
    exit 0 ;;
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
  mkdir -p .beads skills/ac-implement/scripts skills/_tools
  cp "$GATE" skills/ac-implement/scripts/coordinator.sh
  cp "$BR_CALL_SRC" skills/_tools/br-call.sh
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
  cd "$W" || return 1
}

run() { ( cd "$1" && shift && bash skills/ac-implement/scripts/coordinator.sh "$@" 2>&1 ); }
rc_of() { ( cd "$1" && shift && bash skills/ac-implement/scripts/coordinator.sh "$@" >/dev/null 2>&1 ); echo $?; }

echo "coordinator.test: argument and precondition refusals"
mkrepo r1
[ "$(rc_of "$W/r1")" -eq 2 ] && ok "no --run is NOT-GATED, not a silent default" || bad "missing --run did not exit 2"
[ "$(rc_of "$W/r1" --run x --bogus)" -eq 2 ] && ok "an unknown argument is NOT-GATED" || bad "unknown arg did not exit 2"
out="$(run "$W/r1" --run x)"
rc=$(rc_of "$W/r1" --run x)
[ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'NOT-GATED when empty' \
  && ok "no --actor roster is NOT-GATED when empty, never a silent pass — a sweep with no set to select on has not swept" \
  || bad "empty --actor roster was not refused (rc=$rc): $out"
# A trailing bare --actor (no value follows) is refused AT ONCE instead of looping forever
# on `shift 2` against a single remaining argument (ac-4y7l.11). Bounded by timeout so a
# regression fails the suite instead of hanging it.
if command -v timeout >/dev/null 2>&1; then
  ( cd "$W/r1" && timeout 5 bash skills/ac-implement/scripts/coordinator.sh --run p --actor >/dev/null 2>&1 )
  rc=$?
else
  # No `timeout` (stock macOS): run it unbounded. A regression hangs the suite rather than
  # failing it, which is loud enough -- a false RED here would be worse than a slow one.
  ( cd "$W/r1" && bash skills/ac-implement/scripts/coordinator.sh --run p --actor >/dev/null 2>&1 )
  rc=$?
fi
[ "$rc" -eq 2 ] && ok "a trailing bare --actor is refused at once instead of hanging" \
  || bad "trailing bare --actor did not exit 2 (rc=$rc)"
# An explicit empty --actor value is refused NOT-GATED rather than sitting in the roster as
# a blank entry that would match any unassigned claim's blank assignee.
[ "$(rc_of "$W/r1" --run p --actor "" --dry-run)" -eq 2 ] \
  && ok "an empty --actor value is refused NOT-GATED" \
  || bad "empty --actor value was not refused"

echo "coordinator.test: LEDGER-STALE — the refusal that earns the file"
mkrepo r2
# A second clone pushes a ledger change; r2 fetches but does not merge -> upstream ahead.
git clone -q "$W/r2.git" "$W/r2b" && cd "$W/r2b" \
  && git config user.email t@t && git config user.name t \
  && printf '{"id":"b","status":"closed"}\n' >>.beads/issues.jsonl \
  && git commit -qam "other writer closes b" && git push -q origin HEAD:main && cd "$W"
( cd "$W/r2" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
out="$(run "$W/r2" --run R --actor A --dry-run)"; rc=$(rc_of "$W/r2" --run R --actor A --dry-run)
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'LEDGER-STALE' \
  && ok "an upstream ahead ON THE LEDGER is REFUSED before any flush" \
  || bad "stale upstream was not refused (rc=$rc): $out"
printf '%s' "$out" | grep -q 'sync --import-only' \
  && ok "the refusal names the import that fixes it" || bad "refusal does not name the remedy"

# Level with upstream -> the leg passes.
mkrepo r3
( cd "$W/r3" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
[ "$(rc_of "$W/r3" --run R --actor A --dry-run)" -eq 0 ] \
  && ok "level with upstream, the ledger leg passes" || bad "a level repo was refused"

# No upstream at all -> skipped WITH A LINE, never silently treated as clean.
mkrepo r4
( cd "$W/r4" && git branch -q --unset-upstream >/dev/null 2>&1; git remote remove origin >/dev/null 2>&1 )
out="$(run "$W/r4" --run R --actor A --dry-run)"
printf '%s' "$out" | grep -q 'LEDGER-STALE skipped' \
  && ok "with no upstream the leg SAYS it skipped rather than passing quietly" \
  || bad "no-upstream case was silent: $out"

echo "coordinator.test: ORPHANS — selects by actor roster, not a prefix"
# Real shape from a live `br coordination status --json` (br 0.5.12): the holder lives at
# .assessment.assignee — .issue carries NO assignee key at all (ac-4y7l.11). A hand-written
# .issue.assignee fixture would pass while the sweep never fires on a real board.
CLAIM='{"summary":{},"claims":[{"issue":{"id":"ac-1","status":"in_progress"},"assessment":{"assignee":"Cave"}}]}'
mkrepo r5
( cd "$W/r5" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
out="$(AC2_TEST_CLAIMS="$CLAIM" run "$W/r5" --run RUNA --actor Cave --dry-run)"
rc=$( AC2_TEST_CLAIMS="$CLAIM" rc_of "$W/r5" --run RUNA --actor Cave --dry-run )
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'ORPHANS' && printf '%s' "$out" | grep -q 'ac-1' \
  && ok "a rostered actor's claim (real .assessment.assignee shape) is picked up as an orphan and named" \
  || bad "orphan not refused (rc=$rc): $out"
# THE DISCRIMINATING CASE: an unrostered actor's claim is left alone, exact match only.
[ "$( AC2_TEST_CLAIMS="$CLAIM" rc_of "$W/r5" --run RUNA --actor Other --dry-run )" -eq 0 ] \
  && ok "an unrostered actor's claim is left alone" \
  || bad "the sweep selected a claim outside the roster"
# A roster name that is a PREFIX of the real holder must not match — exact match, never a prefix.
[ "$( AC2_TEST_CLAIMS="$CLAIM" rc_of "$W/r5" --run RUNA --actor Cav --dry-run )" -eq 0 ] \
  && ok "a roster name that is a prefix of the holder is not matched" \
  || bad "a prefix name incorrectly matched the holder"
# A two-actor roster: claims held by two different actors, both rostered -> both caught.
CLAIM2='{"summary":{},"claims":[{"issue":{"id":"ac-1","status":"in_progress"},"assessment":{"assignee":"Cave"}},{"issue":{"id":"ac-2","status":"in_progress"},"assessment":{"assignee":"Dale"}}]}'
out="$(AC2_TEST_CLAIMS="$CLAIM2" run "$W/r5" --run RUNA --actor Cave --actor Dale --dry-run)"
rc=$( AC2_TEST_CLAIMS="$CLAIM2" rc_of "$W/r5" --run RUNA --actor Cave --actor Dale --dry-run )
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'ac-1' && printf '%s' "$out" | grep -q 'ac-2' \
  && ok "a two-actor roster catches both actors' orphaned claims" \
  || bad "two-actor roster did not catch both claims (rc=$rc): $out"
# THE REGRESSION THIS FIX EXISTS FOR: no identity must never read as clean. An EMPTY
# --actor-prefix is not an identity source either, so it must not buy past the refusal.
out="$( AC2_TEST_CLAIMS="$CLAIM" run "$W/r5" --run RUNA --dry-run --actor-prefix '' )"
rc=$( AC2_TEST_CLAIMS="$CLAIM" rc_of "$W/r5" --run RUNA --dry-run --actor-prefix '' )
[ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'NOT-GATED' \
  && ok "with no worker identity the sweep is NOT-GATED, never a silent clean" \
  || bad "an unidentifiable sweep did not refuse (rc=$rc): $out"
# Back-compat: an explicit prefix still works for a run that really does share one.
PCLAIM='{"summary":{},"claims":[{"issue":{"id":"ac-2","status":"in_progress"},"assessment":{"assignee":"swarm-RUNA-Cave"}}]}'
[ "$( AC2_TEST_CLAIMS="$PCLAIM" rc_of "$W/r5" --run RUNA --actor-prefix swarm-RUNA --dry-run )" -eq 1 ] \
  && ok "--actor-prefix still sweeps a genuinely shared prefix" \
  || bad "explicit --actor-prefix stopped working"

# THE br-0.1.14 PATH: `br coordination` does not exist there ("unrecognized subcommand"),
# so the gate falls back to `br list --json` and reshapes its FLAT .assignee into the same
# envelope. Without this the whole close-out went NOT-GATED on every 0.1.14 machine.
LCLAIM='[{"id":"ac-7","status":"in_progress","assignee":"CoralGorge"},{"id":"ac-8","status":"open","assignee":"CoralGorge"}]'
out="$( AC2_TEST_CS_FAIL=1 AC2_TEST_LIST="$LCLAIM" run "$W/r5" --run RUNA --actor CoralGorge --dry-run )"
rc=$( AC2_TEST_CS_FAIL=1 AC2_TEST_LIST="$LCLAIM" rc_of "$W/r5" --run RUNA --actor CoralGorge --dry-run )
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'ac-7' \
  && ok "with no 'br coordination' the sweep falls back to 'br list --json' and still fires" \
  || bad "the br-list fallback did not catch the orphan (rc=$rc): $out"
printf '%s' "$out" | grep -q 'ac-8' \
  && bad "the fallback swept a bead that is not in_progress" \
  || ok "the fallback still filters on in_progress"

echo "coordinator.test: a gate that cannot verify says so"
[ "$( AC2_TEST_CS_BROKEN=1 rc_of "$W/r5" --run RUNA --actor Cave --dry-run )" -eq 2 ] \
  && ok "unparseable coordination status is NOT-GATED, never a pass" || bad "broken status did not exit 2"
out="$( AC2_TEST_CS_FAIL=1 run "$W/r5" --run RUNA --actor Cave --dry-run )"
rc=$( AC2_TEST_CS_FAIL=1 rc_of "$W/r5" --run RUNA --actor Cave --dry-run )
[ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q "yielded claim state" \
  && ok "a refused coordination status read is NOT-GATED, never a fabricated orphan verdict" \
  || bad "refused status did not exit 2 naming the read (rc=$rc): $out"
( cd "$W/r5" && rm -f .beads/issues.jsonl )
[ "$(rc_of "$W/r5" --run RUNA --actor Cave --dry-run)" -eq 2 ] \
  && ok "a missing ledger is NOT-GATED" || bad "missing ledger did not exit 2"

echo "coordinator.test: the write leg"
mkrepo r6
( cd "$W/r6" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
BEFORE=$( cd "$W/r6" && git rev-parse HEAD )
AC2_TEST_LEDGER="$W/r6/.beads/issues.jsonl" run "$W/r6" --run R --actor A >/dev/null 2>&1
AFTER=$( cd "$W/r6" && git rev-parse HEAD )
[ "$BEFORE" != "$AFTER" ] && ok "a changed ledger is flushed and committed" || bad "the ledger commit did not land"

mkrepo r7
( cd "$W/r7" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
B7=$( cd "$W/r7" && git rev-parse HEAD )
out="$(run "$W/r7" --run R --actor A)"          # no AC2_TEST_LEDGER -> flush changes nothing
AFTER7=$( cd "$W/r7" && git rev-parse HEAD )
if [ "$AFTER7" = "$B7" ] && printf '%s' "$out" | grep -q 'ledger unchanged'; then
  ok "an unchanged ledger commits NOTHING and says so"
else
  bad "empty flush still moved HEAD: $out"
fi

# A commit that reports success without landing is the silent-write failure this leg exists for.
mkrepo r8
( cd "$W/r8" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
out="$( AC2_TEST_LEDGER="$W/r8/.beads/issues.jsonl" AC2_TEST_COMMIT_NOOP=1 run "$W/r8" --run R --actor A )"
rc=$( AC2_TEST_LEDGER="$W/r8/.beads/issues.jsonl" AC2_TEST_COMMIT_NOOP=1 rc_of "$W/r8" --run R --actor A )
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'LEDGER-WRITE' \
  && ok "a commit that exits 0 without moving HEAD is REFUSED, not believed" \
  || bad "silent no-op commit was accepted (rc=$rc): $out"

mkrepo r9
( cd "$W/r9" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
[ "$( AC2_TEST_FLUSH_FAIL=1 rc_of "$W/r9" --run R --actor A )" -eq 2 ] \
  && ok "a failed flush is NOT-GATED — the disk ledger is not trusted" || bad "failed flush was not NOT-GATED"

echo "coordinator.test: --branch is forwarded to the lane (2026-09-12)"
# Seeded with the passthrough. Before it, coordinator.sh could not name a trunk at all, so on
# any checkout whose trunk is not `main` its own ledger commit was refused unconditionally.
# Case 1 is the fix; case 2 is the regression guard for the bash-3.2 empty-array hazard the
# guarded expansion exists for -- a bare "${BRANCH_ARG[@]}" breaks EVERY default close-out.
mkrepo rb1
( cd "$W/rb1" && git fetch -q origin && git checkout -q -b easy-code )
BB=$( cd "$W/rb1" && git rev-parse HEAD )
out="$(AC2_TEST_LEDGER="$W/rb1/.beads/issues.jsonl" run "$W/rb1" --run RB --actor A --branch easy-code)"
if [ "$( cd "$W/rb1" && git rev-parse HEAD )" != "$BB" ]; then
  ok "--branch reaches the lane, so a non-main trunk closes out"
else bad "--branch was not forwarded; the ledger never committed: $out"; fi

mkrepo rb2
( cd "$W/rb2" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
BB2=$( cd "$W/rb2" && git rev-parse HEAD )
out="$(AC2_TEST_LEDGER="$W/rb2/.beads/issues.jsonl" run "$W/rb2" --run RB2 --actor A)"
if [ "$( cd "$W/rb2" && git rev-parse HEAD )" != "$BB2" ]; then
  ok "omitting --branch still closes out — the empty array never expands unbound"
else bad "default close-out broke without --branch: $out"; fi

echo "coordinator.test: the optional --mirror-artifacts checkpoint (ac-28nm)"
mkrepo r10
( cd "$W/r10" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
mkdir -p "$W/r10/skills/ac-implement/scripts"
cat >"$W/r10/skills/ac-implement/scripts/mirror-run-artifacts.sh" <<'MIR'
#!/usr/bin/env bash
echo "MIRRORED: $*" >> .mirror.log
exit 0
MIR
chmod +x "$W/r10/skills/ac-implement/scripts/mirror-run-artifacts.sh"
AC2_TEST_LEDGER="$W/r10/.beads/issues.jsonl" run "$W/r10" --run RM --actor A --mirror-artifacts >/dev/null 2>&1
grep -q 'MIRRORED: --run RM' "$W/r10/.mirror.log" \
  && ok "--mirror-artifacts invokes the mirror leg after the flush" \
  || bad "--mirror-artifacts did not invoke the mirror leg"

# Non-blocking: a missing mirror script is noted and the close still exits 0.
mkrepo r11
( cd "$W/r11" && git fetch -q origin && git branch -q --set-upstream-to=origin/main >/dev/null 2>&1 )
out="$(AC2_TEST_LEDGER="$W/r11/.beads/issues.jsonl" run "$W/r11" --run RN --actor A --mirror-artifacts)"
rc=$( AC2_TEST_LEDGER="$W/r11/.beads/issues.jsonl" rc_of "$W/r11" --run RN --actor A --mirror-artifacts )
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'mirror skipped' \
  && ok "a missing mirror script is non-blocking — noted, never refused" \
  || bad "missing mirror script was not non-blocking (rc=$rc): $out"

echo "coordinator.test: the script declares its own assurance"
miss=""
for f in "PROBE:" "SCHEDULE:" "MODE:" "ON-FAILURE:"; do grep -q "$f" "$GATE" || miss="$miss $f"; done
[ -z "$miss" ] && ok "coordinator.sh carries its 4-field assurance declaration at birth" \
  || bad "coordinator.sh declares no$miss"

echo ""
echo "coordinator.test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
