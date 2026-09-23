#!/usr/bin/env bash
# 14-no-net-growth.test.sh — proof harness for the ported no-net-growth check (bd-oxmsf,
# rewritten for the lint v2 port by ac-1p7j.2; before that commit this harness awk-extracted
# the LIVE bash nng_* functions out of lint.sh and eval'd them — a Python check cannot be
# extracted that way, so the harness drives the check binary directly now).
#
# WHY: Check 14 leg 2 judges OTHER repos (deploy targets), so it cannot be exercised
# without a target — and exercising it against a live app repo would mean dirtying
# someone else's checkout. This runs lint/checks/14-no-net-growth.py against throwaway
# repos in a mktemp dir: default branch `master` (so origin/HEAD resolution is proven, not
# assumed), growth, the wrong-token near-miss, the removed `net-growth-ok` token (which
# must NOT exempt — ec5fa64), a shrink, a symlinked skill dir, the two reader states
# (leg 1 unconditional while leg 2 discloses its SKIP, ac-vlje.9), and the ac family's
# creation-vs-growth rule.
#
# Runs under bash AND zsh. Exit 0 = all cases pass.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CHECK="$ROOT/lint/checks/14-no-net-growth.py"
[ -f "$CHECK" ] || { echo "HARNESS FAIL: $CHECK missing — the ported check is gone"; exit 1; }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
git init -q --bare "$W/origin.git" -b master        # default branch master, like some real repos still use
git clone -q "$W/origin.git" "$W/app" 2>/dev/null
cd "$W/app" || exit 1
git config user.email t@t.t; git config user.name t
mkdir -p .claude/skills/foo
for i in 1 2 3 4 5 6 7 8 9 10; do echo "line $i"; done > .claude/skills/foo/SKILL.md
git add -A; git commit -qm base; git push -q origin master 2>/dev/null
git remote set-head origin master

PASS=0; FAIL=0
violations_of() { # <repo> <label> <base> <spec> -> violation count on stdout
  # Count every violation ENTRY the check printed, not just "(+" ones — an
  # ac-family-cap breach prints "(ac-family-cap: ...)" and is equally a violation.
  python3 "$CHECK" --scan "$1" "$2" "$3" "$4" 2>/dev/null \
    | grep '^FAIL ' | sed 's/^FAIL[^:]*: net-positive SKILL.md file(s): //' \
    | tr ',' '\n' | grep -c .
}
expect() { # <name> <want-violation-count> <base> <spec>
  local name="$1" want="$2" base="$3" spec="$4" got
  got=$(violations_of "$W/app" app "$base" "$spec")
  if [ "$got" = "$want" ]; then PASS=$((PASS+1)); printf 'ok   %-46s violations=%s\n' "$name" "$got"
  else FAIL=$((FAIL+1)); printf 'FAIL %-46s violations=%s want=%s\n' "$name" "$got" "$want"; fi
}

echo "base-ref resolution -> $(python3 "$CHECK" --base-of "$W/app" | cut -c1-8) (origin/HEAD = master, NOT origin/main)"

base=$(python3 "$CHECK" --base-of "$W/app")
expect "clean target (no delta)" 0 "$base" '.claude/skills/*/SKILL.md'

echo "line 11" >> .claude/skills/foo/SKILL.md
echo "line 12" >> .claude/skills/foo/SKILL.md
expect "+2 growth -> FAILS" 1 "$base" '.claude/skills/*/SKILL.md'

# the wrong-token near-must-still-fail case (bd-curate-...xu5tz's AC)
echo "<!-- evidence: i thought about it -->" >> .claude/skills/foo/SKILL.md
expect "wrong token 'evidence:' -> still FAILS" 1 "$base" '.claude/skills/*/SKILL.md'

# ec5fa64 removed the `net-growth-ok` escape hatch outright — "growth is bought with
# deletion, not prose". NO comment token exempts growth any more. This case pins the
# ABSENCE of the escape, so reintroducing one cannot pass unnoticed. (Until 2026-08-27
# this case still asserted the removed hatch worked, and stayed red undetected because
# no workflow ran this harness — the defect ac-on0y.1 exists to end.)
echo "<!-- net-growth-ok: proven exception -->" >> .claude/skills/foo/SKILL.md
expect "former 'net-growth-ok' stamp -> STILL FAILS (escape removed, ec5fa64)" 1 "$base" '.claude/skills/*/SKILL.md'

git checkout -q -- .claude/skills/foo/SKILL.md
for i in 1 2 3; do echo "line $i"; done > .claude/skills/foo/SKILL.md
expect "shrink -> PASSES" 0 "$base" '.claude/skills/*/SKILL.md'

# a symlinked skill dir must be invisible to the leg (git can't traverse it)
git checkout -q -- .claude/skills/foo/SKILL.md
mkdir -p "$W/registry/bar"
echo x > "$W/registry/bar/SKILL.md"
ln -s "$W/registry/bar" .claude/skills/bar
echo "  symlinked dir present: $(ls -l .claude/skills/bar | sed 's/.*-> //')"
expect "symlinked skill dir -> invisible" 0 "$base" '.claude/skills/*/SKILL.md'

# --- LEG 1 UNDER TRUNK-DIRECT -------------------------------------------------
# The leg-1 base resolver (nng_leg1_base, ported into the check as --leg1-base) is where
# the trunk-direct self-exemption lived: after a push origin/<default> == HEAD, so
# merge-base is HEAD and the diff is empty by construction. These cases exercise LEG 1's
# resolver specifically.
git checkout -q -- .claude/skills/foo/SKILL.md
echo "line 11" >> .claude/skills/foo/SKILL.md
echo "line 12" >> .claude/skills/foo/SKILL.md
git add .claude/skills/foo/SKILL.md; git commit -qm "grow SKILL.md"; git push -q origin master 2>/dev/null
echo "  after push: merge-base(origin/HEAD,HEAD) == HEAD ? $(python3 "$CHECK" --base-of "$W/app" >/dev/null && [ "$(python3 "$CHECK" --base-of "$W/app")" = "$(git -C "$W/app" rev-parse HEAD)" ] && echo yes || echo no)"
base=$(python3 "$CHECK" --leg1-base "$W/app")
expect "already-pushed growth is still scored (leg-1 base)" 1 "$base" '.claude/skills/*/SKILL.md'

for i in 1 2 3; do echo "line $i"; done > .claude/skills/foo/SKILL.md
git add .claude/skills/foo/SKILL.md; git commit -qm "shrink SKILL.md"; git push -q origin master 2>/dev/null
base=$(python3 "$CHECK" --leg1-base "$W/app")
expect "already-pushed SHRINK is still a pass" 0 "$base" '.claude/skills/*/SKILL.md'

# --- LEAN ac FAMILY: creation defers to the family cap, growth does not (ac-g2v4) ---
# A brand-new SKILL.md always has `del = 0`, so the net is always positive and a
# creation was ALWAYS a violation — which made the ac family uncreatable. Creation now
# answers to the ac family TOTAL instead (the manifest's `_lint` section,
# skills/packages.json, ac-6asz.3). Creation is distinguished
# from a pure-addition EDIT with --diff-filter=A: both print `N 0` on numstat, so
# numstat alone cannot tell them apart.
git checkout -q -- .claude/skills/foo/SKILL.md 2>/dev/null || true
mkdir -p .claude/skills/ac-plan
seq 1 80 | sed 's/^/line /' > .claude/skills/ac-plan/SKILL.md
git add .claude/skills/ac-plan/SKILL.md
base=$(python3 "$CHECK" --leg1-base "$W/app")
expect "NEW ac SKILL.md within family cap -> PASSES" 0 "$base" '.claude/skills/*/SKILL.md'

# A new non-lean-family skill is untouched by the rule: creation is still net growth there.
git reset -q .claude/skills/ac-plan/SKILL.md 2>/dev/null; rm -rf .claude/skills/ac-plan
mkdir -p .claude/skills/ac-other
seq 1 40 | sed 's/^/line /' > .claude/skills/ac-other/SKILL.md
git add .claude/skills/ac-other/SKILL.md
base=$(python3 "$CHECK" --leg1-base "$W/app")
expect "NEW non-ac SKILL.md -> STILL FAILS (rule is lean-family-only)" 1 "$base" '.claude/skills/*/SKILL.md'

# The rule exempts CREATION, not GROWTH. Commit the ac-plan creation and push it first
# — advancing the base past it — so the next case is a pure EDIT of an existing family
# member, not a creation (leg 1 judges HEAD's parent; a creation one commit back is
# still inside the diff range and would be classified as creation, testing nothing).
git add .claude/skills/ac-other/SKILL.md 2>/dev/null || true
rm -rf .claude/skills/ac-other
mkdir -p .claude/skills/ac-plan
seq 1 80 | sed 's/^/line /' > .claude/skills/ac-plan/SKILL.md
git add .claude/skills/ac-plan/SKILL.md
git commit -qm "create ac-plan within cap"; git push -q origin master 2>/dev/null
echo advance > advance.txt; git add -A; git commit -qm advance; git push -q origin master 2>/dev/null
echo "line 81" >> .claude/skills/ac-plan/SKILL.md
base=$(python3 "$CHECK" --leg1-base "$W/app")
expect "net-positive EDIT to EXISTING ac SKILL.md -> STILL FAILS" 1 "$base" '.claude/skills/*/SKILL.md'
git checkout -q -- .claude/skills/ac-plan/SKILL.md 2>/dev/null

# Creation over the family cap is still a violation — the cap is the payment, and
# the exemption is a deferral to it, not an amnesty. (The registry fixture has one
# family file, so the cap breach needs a bigger family; the manifest cap is 800 and
# the created file alone stays under it — over-cap is asserted by 80+700 lines.)
mkdir -p .claude/skills/ac-polish
seq 1 800 | sed 's/^/line /' > .claude/skills/ac-polish/SKILL.md
git add .claude/skills/ac-polish/SKILL.md
base=$(python3 "$CHECK" --leg1-base "$W/app")
expect "NEW ac SKILL.md BREACHING family cap -> FAILS" 1 "$base" '.claude/skills/*/SKILL.md'

# --- NOT-CONFIGURED: leg 1 stays unconditional, leg 2 discloses its SKIP -------------
# The two legs answer the reader's absence differently, and BOTH must still speak.
# Leg 1 audits THIS registry's own skills/ and never consults the machine facts, so a
# grown SKILL.md keeps failing; leg 2 audits the deploy-target union, which is UNKNOWN
# without those facts, so it skips LOUDLY rather than silently ratcheting nothing. A
# version that returned early on the reader's absence would stop the ratchet on exactly
# the machine whose file is missing — the failure this case exists to prevent.
# A full run needs a registry-shaped root (leg 1's spec is skills/*/SKILL.md and the
# check-14 lists come from the manifest), so the throwaway repo gets a copy of the real
# skills/packages.json.
git reset -q
mkdir -p "$W/app/skills/reg-skill"
cp "$ROOT/skills/packages.json" "$W/app/skills/packages.json"
printf 'line 1\n' > "$W/app/skills/reg-skill/SKILL.md"
git add skills/packages.json skills/reg-skill/SKILL.md
git commit -qm "registry-shaped skill, at rest"; git push -q origin master 2>/dev/null
echo "line 2" >> "$W/app/skills/reg-skill/SKILL.md"
out="$(AC_MACHINE_FILE=/nonexistent/machine.json python3 "$CHECK" "$W/app" 2>&1)"; rc=$?
if [ "$rc" = 1 ] \
   && printf '%s\n' "$out" | grep -q 'FAIL 14-no-net-growth' \
   && printf '%s\n' "$out" | grep -q 'reg-skill' \
   && printf '%s\n' "$out" | grep -q 'leg 2 skipped'; then
  PASS=$((PASS+1)); printf 'ok   %-46s leg 1 still fails, leg 2 skipped\n' "not-configured machine facts"
else
  FAIL=$((FAIL+1)); printf 'FAIL %-46s rc=%s want=1\n' "not-configured machine facts" "$rc"
  printf '%s\n' "$out"
fi

echo "---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
