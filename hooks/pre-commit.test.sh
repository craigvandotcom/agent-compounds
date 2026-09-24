#!/usr/bin/env bash
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-proofs.sh (glob-discovered; the CI proofs job runs it)
# pre-commit.test.sh — the pre-commit gate judges STAGED content: a clean index passes (relative
# or absolute GIT_INDEX_FILE), a staged dangling /ac- citation and a staged undefined Python name
# are refused even when the working tree is clean. Runs the real hook against throwaway indexes;
# the real index and working tree are never touched.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/hooks/pre-commit"
command -v uvx >/dev/null 2>&1 || command -v ruff >/dev/null 2>&1 || { echo "SKIP: no ruff/uvx"; exit 77; }
cd "$ROOT" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails+1)); }
fresh() { cp "$(git rev-parse --git-path index)" "$1"; }
stage() {  # stage <index> <path> <text-to-append>
  local b; b=$( { GIT_INDEX_FILE="$1" git show ":$2"; printf '%s' "$3"; } | git hash-object -w --stdin)
  GIT_INDEX_FILE="$1" git update-index --cacheinfo "$(git ls-files -s -- "$2" | cut -d' ' -f1),$b,$2"
}

fresh "$T/abs.index"
GIT_INDEX_FILE="$T/abs.index" bash "$HOOK" >/dev/null 2>&1 && ok "clean index (absolute path) passes" || bad "clean index (absolute path) refused"

mkdir -p "$ROOT/_scratch"; REL="_scratch/pre-commit-test-$$.index"; fresh "$REL"
GIT_INDEX_FILE="$REL" bash "$HOOK" >/dev/null 2>&1 && ok "clean index (relative path) passes" || bad "clean index (relative path) refused"
rm -f "$REL"

fresh "$T/cite.index"; stage "$T/cite.index" skills/ac-board/SKILL.md $'\nRun `/ac-no-such-skill` next.\n'
out="$(GIT_INDEX_FILE="$T/cite.index" bash "$HOOK" 2>&1)" && bad "staged dangling citation passed" \
  || { echo "$out" | grep -q 'ac-no-such-skill' && ok "staged dangling citation refused, named" || bad "refused, but not for the citation"; }

fresh "$T/py.index"; stage "$T/py.index" skills/ac-board/scripts/render.py $'\nprint(undefined_name_xyz)\n'
out="$(GIT_INDEX_FILE="$T/py.index" bash "$HOOK" 2>&1)" && bad "staged undefined Python name passed" \
  || { echo "$out" | grep -q 'undefined_name_xyz' && ok "staged undefined Python name refused by ruff (working tree clean)" || bad "refused, but not by ruff"; }

echo "pre-commit.test.sh: $fails failure(s)"
[ "$fails" -eq 0 ]
