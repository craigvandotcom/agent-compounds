#!/usr/bin/env bash
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-proofs.sh (glob-discovered; the CI proofs job runs it)
# dcg-fail-closed.test.sh — the wrapper passes dcg's decisions, blocks when dcg cannot decide,
# and needs no writable /tmp to do either.
#   PROBE: bash hooks/dcg-fail-closed.test.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
W="$HERE/dcg-fail-closed.sh"
S="$(mktemp -d)"
trap 'rm -rf "$S"' EXIT
fails=0
stub() { printf '#!/bin/sh\n%s\n' "$2" >"$S/$1"; chmod +x "$S/$1"; }
check() { # name expected-rc stub [TMPDIR]
  local rc
  DCG_UNDER_TEST="$S/$3" TMPDIR="${4:-$S}" sh "$W" </dev/null >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq "$2" ]; then echo "PASS $1"; else echo "FAIL $1 (rc $rc, want $2)"; fails=$((fails+1)); fi
}
stub allow 'exit 0'
stub deny 'echo "{\"decision\":\"block\"}"; exit 0'
stub crash 'echo boom >&2; exit 3'
stub garbage 'echo not-json; exit 0'
check "silent allow passes" 0 allow
check "json decision passes" 0 deny
check "crash blocks" 2 crash
check "non-json blocks" 2 garbage
check "missing dcg blocks" 2 absent
check "allow passes with no usable tmp dir" 0 allow /nonexistent
check "crash blocks with no usable tmp dir" 2 crash /nonexistent
grep -q 'mktemp' "$W" && { echo "FAIL wrapper still makes a temp file"; fails=$((fails+1)); } || echo "PASS no temp file"
[ "$fails" -eq 0 ]
