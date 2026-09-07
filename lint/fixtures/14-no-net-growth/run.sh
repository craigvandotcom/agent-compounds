#!/usr/bin/env bash
# run.sh — the RED case for lint/checks/14-no-net-growth.py. The ratchet's RED is
# a git STATE, not a static tree, so this builds a throwaway repo where a NEW
# non-family SKILL.md is created (a creation is always net-positive) and exits 0
# only when the real check reports exactly that violation.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECK="$ROOT/lint/checks/14-no-net-growth.py"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
git init -q --bare "$W/origin.git" -b master
git clone -q "$W/origin.git" "$W/app" 2>/dev/null
cd "$W/app" || exit 2
git config user.email t@t.t; git config user.name t
mkdir -p .claude/skills/foo
for i in 1 2 3 4 5; do echo "line $i"; done > .claude/skills/foo/SKILL.md
git add -A; git commit -qm base; git push -q origin master 2>/dev/null
git remote set-head origin master
mkdir -p .claude/skills/grown
for i in $(seq 1 20); do echo "line $i"; done > .claude/skills/grown/SKILL.md
git add -A; git commit -qm "create grown"; git push -q origin master 2>/dev/null
base="$(python3 "$CHECK" --leg1-base "$W/app")"
[ -n "$base" ] || { echo "fixture: base unresolvable"; exit 2; }
out="$(python3 "$CHECK" --scan "$W/app" fixture "$base" '.claude/skills/*/SKILL.md' 2>&1)"; rc=$?
echo "$out" | sed 's/^/  | /'
if [ "$rc" -ne 1 ]; then echo "fixture: expected RED (exit 1) for a created SKILL.md, got $rc"; exit "$rc"; fi
printf '%s' "$out" | grep -qE 'skills/grown/SKILL\.md \(\+20\)' || { echo "fixture: the created SKILL.md was not the violation"; exit 1; }
exit 0
