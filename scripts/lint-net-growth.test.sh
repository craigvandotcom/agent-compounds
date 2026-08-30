#!/usr/bin/env bash
# lint-net-growth.test.sh — proof harness for lint.sh Check 14 (bd-oxmsf).
#
# WHY: Check 14 leg 2 judges OTHER repos (deploy targets), so it cannot be exercised
# without a target — and exercising it against a live app repo would mean dirtying
# someone else's checkout. This extracts the LIVE nng_scan + nng_base_of out of
# lint.sh and runs them against a throwaway repo in /tmp: default branch `master`
# (so origin/HEAD resolution is proven, not assumed), growth, the wrong-token
# near-miss, the removed `net-growth-ok` token (which must NOT exempt — ec5fa64),
# a shrink, and a symlinked skill dir.
#
# Runs under bash AND zsh. Exit 0 = all cases pass.

LINT="$(cd "$(dirname "$0")/.." && pwd)/lint.sh"
NNG_BASE_REF=origin/main
FUNCS=$(awk '/^NNG_VIOLATIONS=\(\)/{f=1} f&&/^check$/{exit} f' "$LINT")
[ -n "$FUNCS" ] || { echo "HARNESS FAIL: could not extract functions"; exit 1; }
eval "$FUNCS"
type nng_scan >/dev/null 2>&1 || { echo "HARNESS FAIL: nng_scan not defined"; exit 1; }
# LEG 1's own base resolver must be inside the extraction window too — the trunk-direct
# self-exemption lived in leg 1's CALL SITE, which the window could not reach, so a fix
# to nng_base_of alone would have proved nothing about leg 1.
type nng_leg1_base >/dev/null 2>&1 || { echo "HARNESS FAIL: nng_leg1_base not defined — leg 1's base resolver is outside the extraction window"; exit 1; }

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
expect "+2 growth -> FAILS" 1

# the wrong-token near-miss (bd-curate-...xu5tz's AC): must still fail
echo "<!-- evidence: i thought about it -->" >> .claude/skills/foo/SKILL.md
expect "wrong token 'evidence:' -> still FAILS" 1

# ec5fa64 removed the `net-growth-ok` escape hatch outright — "growth is bought with
# deletion, not prose". NO comment token exempts growth any more. This case pins the
# ABSENCE of the escape, so reintroducing one cannot pass unnoticed. (Until 2026-08-27
# this case still asserted the removed hatch worked, and stayed red undetected because
# no workflow ran this harness — the defect ac-on0y.1 exists to end.)
echo "<!-- net-growth-ok: proven exception -->" >> .claude/skills/foo/SKILL.md
expect "former 'net-growth-ok' stamp -> STILL FAILS (escape removed, ec5fa64)" 1

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

# --- LEG 1 UNDER TRUNK-DIRECT -------------------------------------------------
# expect() above resolves the base with nng_base_of (leg 2's resolver). Leg 1 has its
# own, nng_leg1_base, and that is where the self-exemption lived: after a push
# origin/<default> == HEAD, so merge-base is HEAD and the diff is empty by
# construction. These two cases exercise LEG 1's resolver specifically.
expect_leg1() { # <name> <want-violation-count>
  local name="$1" want="$2" base got
  NNG_VIOLATIONS=()
  base=$(nng_leg1_base "$W/app")
  [ -n "$base" ] || { echo "FAIL $name — leg-1 base unresolvable"; FAIL=$((FAIL+1)); return; }
  nng_scan "$W/app" "app" "$base" '.claude/skills/*/SKILL.md' > /tmp/nng-out 2>&1
  sed 's/^/    | /' /tmp/nng-out
  got=${#NNG_VIOLATIONS[@]}
  if [ "$got" = "$want" ]; then PASS=$((PASS+1)); printf 'ok   %-42s violations=%s\n' "$name" "$got"
  else FAIL=$((FAIL+1)); printf 'FAIL %-42s violations=%s want=%s  %s\n' "$name" "$got" "$want" "${NNG_VIOLATIONS[*]:-}"; fi
}

git checkout -q -- .claude/skills/foo/SKILL.md
echo "line 11" >> .claude/skills/foo/SKILL.md
echo "line 12" >> .claude/skills/foo/SKILL.md
git add .claude/skills/foo/SKILL.md; git commit -qm "grow SKILL.md"; git push -q origin master 2>/dev/null
echo "  after push: merge-base(origin/HEAD,HEAD) == HEAD ? $([ "$(nng_base_of "$W/app")" = "$(git rev-parse HEAD)" ] && echo yes || echo no)"
expect_leg1 "already-pushed growth is still scored" 1

for i in 1 2 3; do echo "line $i"; done > .claude/skills/foo/SKILL.md
git add .claude/skills/foo/SKILL.md; git commit -qm "shrink SKILL.md"; git push -q origin master 2>/dev/null
expect_leg1 "already-pushed SHRINK is still a pass" 0

# --- LEAN ac FAMILY: creation defers to the family cap, growth does not (ac-g2v4) ---
# A brand-new SKILL.md always has `del = 0`, so `nng_net = add - del` is always
# positive and a creation was ALWAYS a violation — which made the ac family
# uncreatable. Creation now answers to the ac family TOTAL instead. Creation is
# distinguished from a pure-addition EDIT with `--diff-filter=A`: both print `N 0`
# on numstat, so numstat alone cannot tell them apart.
git checkout -q -- .claude/skills/foo/SKILL.md 2>/dev/null || true
mkdir -p .claude/skills/ac-plan
seq 1 80 | sed 's/^/line /' > .claude/skills/ac-plan/SKILL.md
git add -A; git commit -qm "create ac-plan"; git push -q origin master 2>/dev/null
echo "  ac family total: $(cat .claude/skills/ac-*/SKILL.md | wc -l | tr -d ' ') lines (cap ${AC_FAMILY_CAP:-800})"
expect_leg1 "NEW ac SKILL.md within family cap -> PASSES" 0

# A new non-lean-family skill is untouched by the rule: creation is still net growth there.
mkdir -p .claude/skills/ac-other
seq 1 40 | sed 's/^/line /' > .claude/skills/ac-other/SKILL.md
git add -A; git commit -qm "create ac-other"; git push -q origin master 2>/dev/null
expect_leg1 "NEW non-ac SKILL.md -> STILL FAILS (rule is lean-family-only)" 1

# The rule exempts CREATION, not GROWTH. Advance the base past BOTH creations first
# — leg 1 judges HEAD's parent, so a creation one commit back is still inside the diff
# range and would be classified as creation, testing nothing.
echo advance > advance.txt
git add -A; git commit -qm "advance base"; git push -q origin master 2>/dev/null
echo "line 81" >> .claude/skills/ac-plan/SKILL.md
expect_leg1 "net-positive EDIT to EXISTING ac SKILL.md -> STILL FAILS" 1
git checkout -q -- .claude/skills/ac-plan/SKILL.md

# Creation over the family cap is still a violation — the cap is the payment, and
# the exemption is a deferral to it, not an amnesty.
mkdir -p .claude/skills/ac-polish
seq 1 800 | sed 's/^/line /' > .claude/skills/ac-polish/SKILL.md
git add -A; git commit -qm "create ac-polish"; git push -q origin master 2>/dev/null
echo "  ac family total: $(cat .claude/skills/ac-*/SKILL.md | wc -l | tr -d ' ') lines (cap ${AC_FAMILY_CAP:-800})"
expect_leg1 "NEW ac SKILL.md BREACHING family cap -> FAILS" 1

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
