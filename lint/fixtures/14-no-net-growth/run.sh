#!/usr/bin/env bash
# run.sh — the RED case for lint/checks/14-no-net-growth.py. The ratchet's RED is
# a git STATE, not a static tree, so this builds a throwaway repo where a NEW
# non-family SKILL.md is created (a creation is always net-positive) and exits 0
# only when the real check reports exactly that violation.
#
# Drives the check through its normal entry (root arg) — the two parity-only CLI flags
# this fixture used to call directly (a single-repo-scan mode and a print-the-leg-1-base
# mode) are gone (the port they served, ac-1p7j.2, is finished; lint/parity.sh is
# deleted). AC_MACHINE_FILE points at a path that cannot exist so leg 2 takes its
# documented disclosed skip instead of needing a real deploy-target union.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK="$ROOT/lint/checks/14-no-net-growth.py"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
git init -q --bare "$W/origin.git" -b master
git clone -q "$W/origin.git" "$W/app" 2>/dev/null
cd "$W/app" || exit 2
git config user.email t@t.t; git config user.name t
mkdir -p skills/foo
for i in 1 2 3 4 5; do echo "line $i"; done > skills/foo/SKILL.md
cp "$ROOT/skills/packages.json" skills/packages.json
git add -A; git commit -qm base; git push -q origin master 2>/dev/null
git remote set-head origin master
# a second commit so leg1_base() has a real HEAD^ to fall back to (the trunk-direct
# self-exemption escape) rather than the base collapsing onto HEAD after the next push
echo settle > SETTLE.txt; git add -A; git commit -qm settle; git push -q origin master 2>/dev/null
mkdir -p skills/grown
for i in $(seq 1 20); do echo "line $i"; done > skills/grown/SKILL.md
git add -A; git commit -qm "create grown"; git push -q origin master 2>/dev/null
out="$(AC_MACHINE_FILE=/nonexistent/machine.json python3 "$CHECK" "$W/app" 2>&1)"; rc=$?
echo "$out" | sed 's/^/  | /'
if [ "$rc" -ne 1 ]; then echo "fixture: expected RED (exit 1) for a created SKILL.md, got $rc"; exit "$rc"; fi
printf '%s' "$out" | grep -qE 'skills/grown/SKILL\.md \(\+20\)' || { echo "fixture: the created SKILL.md was not the violation"; exit 1; }
exit 0
