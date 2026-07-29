#!/usr/bin/env bash
# lint-net-growth.test.sh — proof harness for lint.sh Check 14 (bd-oxmsf).
#
# WHY: Check 14 leg 2 judges OTHER repos (deploy targets), so it cannot be exercised
# without a target — and exercising it against a live app repo would mean dirtying
# someone else's checkout. This extracts the LIVE nng_scan + nng_base_of out of
# lint.sh and runs them against a throwaway repo in /tmp: default branch `master`
# (so origin/HEAD resolution is proven, not assumed), unstamped growth, the
# wrong-token near-miss, the exact token, a shrink, and a symlinked skill dir.
#
# Runs under bash AND zsh. Exit 0 = all cases pass.

LINT="$(cd "$(dirname "$0")/.." && pwd)/lint.sh"
NNG_BASE_REF=origin/main
FUNCS=$(awk '/^NNG_VIOLATIONS=\(\)/{f=1} f&&/^check$/{exit} f' "$LINT")
[ -n "$FUNCS" ] || { echo "HARNESS FAIL: could not extract functions"; exit 1; }
eval "$FUNCS"
type nng_scan >/dev/null 2>&1 || { echo "HARNESS FAIL: nng_scan not defined"; exit 1; }

W=/tmp/nng-proof
rm -rf /tmp/nng-proof
mkdir -p /tmp/nng-proof
git init -q --bare "$W/origin.git" -b master        # default branch master, like art-still/unsit
git clone -q "$W/origin.git" "$W/app"
cd "$W/app" || exit 1
git config user.email t@t.t; git config user.name t
mkdir -p .claude/skills/foo
for i in 1 2 3 4 5 6 7 8 9 10; do echo "line $i"; done > .claude/skills/foo/SKILL.md
git add -A; git commit -qm base; git push -q origin master 2>/dev/null
git remote set-head origin master

PASS=0; FAIL=0
expect() { # <name> <want-violation-count>
  local name="$1" want="$2" base got
  NNG_VIOLATIONS=()
  base=$(nng_base_of "$W/app")
  [ -n "$base" ] || { echo "FAIL $name — base ref unresolvable"; FAIL=$((FAIL+1)); return; }
  # NOT piped: a pipeline runs nng_scan in a subshell and the NNG_VIOLATIONS append
  # would be lost (lint.sh calls it unpiped, in the current shell — keep it that way).
  nng_scan "$W/app" "app" "$base" '.claude/skills/*/SKILL.md' > /tmp/nng-out 2>&1
  sed 's/^/    | /' /tmp/nng-out
  got=${#NNG_VIOLATIONS[@]}
  if [ "$got" = "$want" ]; then PASS=$((PASS+1)); printf 'ok   %-42s violations=%s\n' "$name" "$got"
  else FAIL=$((FAIL+1)); printf 'FAIL %-42s violations=%s want=%s  %s\n' "$name" "$got" "$want" "${NNG_VIOLATIONS[*]:-}"; fi
}

echo "shell: ${ZSH_VERSION:+zsh $ZSH_VERSION}${BASH_VERSION:+bash $BASH_VERSION}"
echo "base-ref resolution -> $(nng_base_of "$W/app" | cut -c1-8) (origin/HEAD = master, NOT origin/main)"

expect "clean target (no delta)" 0

echo "line 11" >> .claude/skills/foo/SKILL.md
echo "line 12" >> .claude/skills/foo/SKILL.md
expect "unstamped +2 growth -> FAILS" 1

# the wrong-token near-miss (bd-curate-...xu5tz's AC): must still fail
echo "<!-- evidence: i thought about it -->" >> .claude/skills/foo/SKILL.md
expect "wrong token 'evidence:' -> still FAILS" 1

echo "<!-- net-growth-ok: proven exception -->" >> .claude/skills/foo/SKILL.md
expect "EXACT token stamp -> PASSES" 0

git checkout -q -- .claude/skills/foo/SKILL.md
for i in 1 2 3; do echo "line $i"; done > .claude/skills/foo/SKILL.md
expect "shrink -> PASSES" 0

# a symlinked skill dir must be invisible to the leg (git can't traverse it)
git checkout -q -- .claude/skills/foo/SKILL.md
mkdir -p "$W/registry/bar"
echo x > "$W/registry/bar/SKILL.md"
ln -s "$W/registry/bar" .claude/skills/bar
echo "  symlinked dir present: $(ls -l .claude/skills/bar | sed 's/.*-> //')"
expect "symlinked skill dir -> invisible" 0

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
