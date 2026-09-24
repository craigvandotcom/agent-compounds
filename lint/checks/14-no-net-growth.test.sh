#!/usr/bin/env bash
# 14-no-net-growth.test.sh — proof harness for lint/checks/14-no-net-growth.py.
#
# Drives the check through its NORMAL entry point (the root arg, run_full()) — no
# side-door CLI flag — leg1_base()'s trunk-direct HEAD^ fallback is exercised the
# same way every real invocation exercises it.
#
# Leg 1 (the per-file ratchet) is exercised in a throwaway repo in a mktemp dir:
# default branch `master` (so falling through to HEAD^ when the manifest's literal
# `origin/main` does not resolve is proven, not assumed), growth, the wrong-token
# near-miss, the removed `net-growth-ok` token (which must NOT exempt), a shrink, a
# symlinked skill dir, already-committed-and-pushed growth (leg1_base's trunk-direct
# HEAD^ fallback), and the lean family's creation-vs-growth rule. The fixture repo
# uses `skills/*/SKILL.md` — leg 1's own hardcoded spec — throughout, and carries a
# real copy of this registry's skills/packages.json so require_config() reads real
# base_ref/lean_family/lean_family_cap values (also exercising leg 2, the per-package
# spine/loaded budget, harmlessly PASSing throughout since the fixture's skill dirs
# are a few dozen lines against thousand-line package budgets — leg 2's own RED and
# NOTGATED cases get dedicated fixtures further down). AC_MACHINE_FILE is set to a
# nonexistent path throughout — inert now that leg 1 no longer shells to other repos,
# kept only so a future re-add of a cross-repo leg fails closed by default.
#
# Runs under bash AND zsh. Exit 0 = all cases pass.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CHECK="$ROOT/lint/checks/14-no-net-growth.py"
[ -f "$CHECK" ] || { echo "HARNESS FAIL: $CHECK missing"; exit 1; }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
git init -q --bare "$W/origin.git" -b master        # default branch master, like some real repos still use
git clone -q "$W/origin.git" "$W/app" 2>/dev/null
cd "$W/app" || exit 1
git config user.email t@t.t; git config user.name t
mkdir -p skills/foo
for i in 1 2 3 4 5 6 7 8 9 10; do echo "line $i"; done > skills/foo/SKILL.md
cp "$ROOT/skills/packages.json" skills/packages.json
git add -A; git commit -qm base; git push -q origin master 2>/dev/null
git remote set-head origin master
# A second commit so leg1_base() has a real HEAD^ to fall back to (the trunk-direct
# self-exemption escape) instead of hitting run_full's "base collapsed onto HEAD" FAIL
# on the very first invocation, which only a single-commit history would trigger.
echo settle > SETTLE.txt; git add -A; git commit -qm settle; git push -q origin master 2>/dev/null

PASS=0; FAIL=0
run_check() { AC_MACHINE_FILE=/nonexistent/machine.json python3 "$CHECK" "$W/app"; }
run_and_count() {  # sets LAST_OUT, LAST_RC, LAST_VIOL (no `local` — expect()/the tail
                    # "not-configured" assertion both read the last run's state)
  LAST_OUT="$(run_check 2>&1)"; LAST_RC=$?
  LAST_VIOL=$(printf '%s\n' "$LAST_OUT" | grep '^FAIL 14-no-net-growth: net-positive' \
    | sed -E 's/^FAIL[^:]*: net-positive SKILL\.md file\(s\): (.*) — core is loaded.*/\1/' \
    | tr ',' '\n' | sed '/^[[:space:]]*$/d' | grep -c .)
}
expect() { # <name> <want-violation-count>
  local name="$1" want="$2"
  run_and_count
  if [ "$LAST_VIOL" = "$want" ]; then PASS=$((PASS+1)); printf 'ok   %-46s violations=%s\n' "$name" "$LAST_VIOL"
  else FAIL=$((FAIL+1)); printf 'FAIL %-46s violations=%s want=%s\n' "$name" "$LAST_VIOL" "$want"
    printf '%s\n' "$LAST_OUT" | sed 's/^/  | /'
  fi
}

expect "clean target (no delta)" 0

echo "line 11" >> skills/foo/SKILL.md
echo "line 12" >> skills/foo/SKILL.md
expect "+2 growth -> FAILS" 1

# a wrong-token near-miss: a similar but non-matching comment must not exempt growth
echo "<!-- evidence: i thought about it -->" >> skills/foo/SKILL.md
expect "wrong token 'evidence:' -> still FAILS" 1

# NO comment token exempts growth: it is paid for with deletion, never prose. This
# case pins the ABSENCE of a `net-growth-ok` escape, so reintroducing one cannot
# pass unnoticed.
echo "<!-- net-growth-ok: proven exception -->" >> skills/foo/SKILL.md
expect "former 'net-growth-ok' stamp -> STILL FAILS (no prose exemption)" 1

git checkout -q -- skills/foo/SKILL.md
for i in 1 2 3; do echo "line $i"; done > skills/foo/SKILL.md
expect "shrink -> PASSES" 0

# a symlinked skill dir must be invisible to the leg (untracked, so `git diff` can't see it)
git checkout -q -- skills/foo/SKILL.md
mkdir -p "$W/registry/bar"
echo x > "$W/registry/bar/SKILL.md"
ln -s "$W/registry/bar" skills/bar
echo "  symlinked dir present: $(ls -l skills/bar | sed 's/.*-> //')"
expect "symlinked skill dir -> invisible" 0
rm -f skills/bar

# --- ALREADY-COMMITTED-AND-PUSHED GROWTH: leg1_base's trunk-direct fallback ----------
# Every case above left its change UNCOMMITTED (run_full diffs the base commit against
# the working tree either way, so a dirty file is already covered). This one commits
# AND pushes the growth, so origin/HEAD collapses onto HEAD exactly like it did right
# after the very first "base" push — proving leg1_base()'s HEAD^ fallback still catches
# it through the check's normal entry, not a self-vs-self empty diff.
git checkout -q -- skills/foo/SKILL.md
echo "line 11" >> skills/foo/SKILL.md
echo "line 12" >> skills/foo/SKILL.md
git add skills/foo/SKILL.md; git commit -qm "grow SKILL.md"; git push -q origin master 2>/dev/null
expect "already-pushed growth is still scored (leg-1 base)" 1

for i in 1 2 3; do echo "line $i"; done > skills/foo/SKILL.md
git add skills/foo/SKILL.md; git commit -qm "shrink SKILL.md"; git push -q origin master 2>/dev/null
expect "already-pushed SHRINK is still a pass" 0

# --- LEAN ac FAMILY: creation defers to the family cap, growth does not -------------
# A brand-new SKILL.md always has `del = 0`, so the net is always positive and a
# creation was ALWAYS a violation — which made the ac family uncreatable. Creation now
# answers to the ac family TOTAL instead (the manifest's `_lint` section,
# skills/packages.json). Creation is distinguished
# from a pure-addition EDIT with --diff-filter=A: both print `N 0` on numstat, so
# numstat alone cannot tell them apart.
mkdir -p skills/ac-plan
seq 1 80 | sed 's/^/line /' > skills/ac-plan/SKILL.md
git add skills/ac-plan/SKILL.md
expect "NEW ac SKILL.md within family cap -> PASSES" 0

# A new non-lean-family skill is untouched by the rule: creation is still net growth there.
git reset -q skills/ac-plan/SKILL.md 2>/dev/null; rm -rf skills/ac-plan
mkdir -p skills/ac-other
seq 1 40 | sed 's/^/line /' > skills/ac-other/SKILL.md
git add skills/ac-other/SKILL.md
expect "NEW non-ac SKILL.md -> STILL FAILS (rule is lean-family-only)" 1

# The rule exempts CREATION, not GROWTH. Commit the ac-plan creation and push it first
# — advancing the base past it — so the next case is a pure EDIT of an existing family
# member, not a creation (leg 1 judges HEAD's parent; a creation one commit back is
# still inside the diff range and would be classified as creation, testing nothing).
git reset -q skills/ac-other/SKILL.md 2>/dev/null; rm -rf skills/ac-other
mkdir -p skills/ac-plan
seq 1 80 | sed 's/^/line /' > skills/ac-plan/SKILL.md
git add skills/ac-plan/SKILL.md
git commit -qm "create ac-plan within cap"; git push -q origin master 2>/dev/null
echo advance > advance.txt; git add -A; git commit -qm advance; git push -q origin master 2>/dev/null
echo "line 81" >> skills/ac-plan/SKILL.md
expect "net-positive EDIT to EXISTING ac SKILL.md -> STILL FAILS" 1
git checkout -q -- skills/ac-plan/SKILL.md

# Creation over the family cap is still a violation — the cap is the payment, and
# the exemption is a deferral to it, not an amnesty. (ac-plan alone stays under the
# manifest cap of 800, so the breach needs a bigger family: 80+800.)
mkdir -p skills/ac-polish
seq 1 800 | sed 's/^/line /' > skills/ac-polish/SKILL.md
git add skills/ac-polish/SKILL.md
run_and_count
if [ "$LAST_RC" = 1 ] && [ "$LAST_VIOL" = 1 ] && printf '%s\n' "$LAST_OUT" | grep -q 'ac-family-cap'; then
  PASS=$((PASS+1)); printf 'ok   %-46s violations=%s\n' "NEW ac SKILL.md BREACHING family cap -> FAILS" "$LAST_VIOL"
else
  FAIL=$((FAIL+1)); printf 'FAIL %-46s violations=%s want=1 (ac-family-cap)\n' "NEW ac SKILL.md BREACHING family cap -> FAILS" "$LAST_VIOL"
  printf '%s\n' "$LAST_OUT" | sed 's/^/  | /'
fi

git reset -q skills/ac-polish/SKILL.md 2>/dev/null; rm -rf skills/ac-polish

# --- LEG 2: per-package spine/loaded budget (ported from Check 23 leg 7) ------------
# A dedicated throwaway root: leg 2 reads the CURRENT tree directly (no git diff), so
# no commit history is needed. member skill dirs are named to match the package entry
# under test — the rest of the registry's package members (absent here) just contribute
# zero, harmlessly.
pkg_check() { AC_MACHINE_FILE=/nonexistent/machine.json python3 "$CHECK" "$1"; }

P="$(mktemp -d)"
mkdir -p "$P/skills/over-budget-skill"
seq 1 50 | sed 's/^/line /' > "$P/skills/over-budget-skill/SKILL.md"
cat > "$P/skills/packages.json" <<'EOF'
{
  "_lint": {"base_ref": "origin/main", "lean_family": [], "lean_family_cap": 800},
  "tiny-pkg": {"skills": ["over-budget-skill"], "budget": {"spine": 10, "loaded": 10}}
}
EOF
OUT="$(pkg_check "$P" 2>&1)"; RC=$?
if [ "$RC" = 1 ] && printf '%s\n' "$OUT" | grep -q "package 'tiny-pkg' over budget — spine 50 > 10"; then
  PASS=$((PASS+1)); printf 'ok   %-46s\n' "leg 2: package over spine budget -> FAILS, named"
else
  FAIL=$((FAIL+1)); printf 'FAIL %-46s rc=%s\n' "leg 2: package over spine budget -> FAILS, named" "$RC"
  printf '%s\n' "$OUT" | sed 's/^/  | /'
fi
rm -rf "$P"

P="$(mktemp -d)"
mkdir -p "$P/skills/some-skill"
echo "l" > "$P/skills/some-skill/SKILL.md"
cat > "$P/skills/packages.json" <<'EOF'
{
  "_lint": {"base_ref": "origin/main", "lean_family": [], "lean_family_cap": 800},
  "no-budget-pkg": {"skills": ["some-skill"]}
}
EOF
OUT="$(pkg_check "$P" 2>&1)"; RC=$?
if [ "$RC" = 1 ] && printf '%s\n' "$OUT" | grep -q "package 'no-budget-pkg' carries no spine/loaded budget"; then
  PASS=$((PASS+1)); printf 'ok   %-46s\n' "leg 2: package with no budget key -> FAILS, named"
else
  FAIL=$((FAIL+1)); printf 'FAIL %-46s rc=%s\n' "leg 2: package with no budget key -> FAILS, named" "$RC"
  printf '%s\n' "$OUT" | sed 's/^/  | /'
fi
rm -rf "$P"

# --- LIVE: the real registry satisfies both legs --------------------------------------
OUT="$(pkg_check "$ROOT" 2>&1)"; RC=$?
if [ "$RC" = 0 ]; then
  PASS=$((PASS+1)); printf 'ok   %-46s\n' "LIVE: the real registry passes leg 1 + leg 2"
else
  FAIL=$((FAIL+1)); printf 'FAIL %-46s rc=%s\n' "LIVE: the real registry passes leg 1 + leg 2" "$RC"
  printf '%s\n' "$OUT" | sed 's/^/  | /'
fi

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
