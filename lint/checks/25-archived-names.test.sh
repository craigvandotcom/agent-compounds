#!/usr/bin/env bash
# 25-archived-names.test.sh — the contract harness for lint/checks/25-archived-names.py.
#
#   PROBE: an archived skill's name in live text outside the allowlist is
#           FAILED with the carrier named; an allowlisted carrier PASSES; a
#           stale allowlist entry is refused (the list only shrinks); an entry
#           ADDED to a committed allowlist is refused (growth); the standing
#           exclusions and archived-v1 survivors stay legal; a stale survivor
#           declaration fails; an empty population is NOT-GATED (exit 2).
#
# ASSURANCE
#   PROBE:    bash lint/checks/25-archived-names.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/25-archived-names.py"
ROOT="$(cd "$HERE/../.." && pwd)"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

# run <tmp-root> -> prints exit code, output captured in $work/out
OUT="$(mktemp)"
run_check() {
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

build_tree() { # <root> — archived dir + one live carrier + clean live skill
  mkdir -p "$1/_archive/skills/ac-loop" "$1/skills/red-skill" "$1/skills/clean-skill"
  printf '# retired\n' > "$1/_archive/skills/ac-loop/SKILL.md"
  printf '%s\n' '# red-skill' '' 'Run ac-loop before closing.' > "$1/skills/red-skill/SKILL.md"
  printf '%s\n' '# clean-skill' '' 'Nothing retired here.' > "$1/skills/clean-skill/SKILL.md"
}

# --- 1 RED: carrier, no allowlist -> exit 1, carrier named -------------------
t="$work/red"; build_tree "$t"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "skills/red-skill/SKILL.md" "$OUT"; then
  ok "RED: unallowlisted carrier failed, named"
else
  bad "RED: expected exit 1 naming the carrier, got $rc"; cat "$OUT"
fi

# --- 2 GREEN: the same carrier allowlisted -> exit 0 --------------------------
t="$work/green"; build_tree "$t"
mkdir -p "$t/lint/allowlists"
{ echo "# dated allowlist"
  echo "skills/red-skill/SKILL.md"
} > "$t/lint/allowlists/25-archived-names.txt"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: allowlisted carrier passes"
else
  bad "GREEN: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 3 SHRINK: cleaned file keeps its entry -> exit 1, shrink named -----------
t="$work/stale"; build_tree "$t"
mkdir -p "$t/lint/allowlists"
{ echo "# dated allowlist"
  echo "skills/red-skill/SKILL.md"
  echo "skills/clean-skill/SKILL.md"
} > "$t/lint/allowlists/25-archived-names.txt"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "only shrinks: remove the entry" "$OUT"; then
  ok "SHRINK: stale entry refused, removal demanded"
else
  bad "SHRINK: expected exit 1 naming the shrink rule, got $rc"; cat "$OUT"
fi

# --- 4 GROWTH: entry added vs committed base -> exit 1, growth named ----------
t="$work/growth"
build_tree "$t"
mkdir -p "$t/lint/allowlists"
echo "# dated allowlist" > "$t/lint/allowlists/25-archived-names.txt"
git -C "$t" init -q
git -C "$t" -c user.name=h -c user.email=h@x add -A
git -C "$t" -c user.name=h -c user.email=h@x commit -qm base
BASE_SHA=$(git -C "$t" rev-parse HEAD)
git -C "$t" update-ref refs/remotes/origin/main "$BASE_SHA"
{ echo "# dated allowlist"
  echo "skills/red-skill/SKILL.md"
  echo "skills/clean-skill/SKILL.md"
} > "$t/lint/allowlists/25-archived-names.txt"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "allowlist GREW" "$OUT"; then
  ok "GROWTH: added entry refused against committed base"
else
  bad "GROWTH: expected exit 1 naming growth, got $rc"; cat "$OUT"
fi

# --- 5 SEED: first landing (no committed allowlist) is exempt -----------------
t="$work/seed"; build_tree "$t"
git -C "$t" init -q
git -C "$t" -c user.name=h -c user.email=h@x add -A
git -C "$t" -c user.name=h -c user.email=h@x commit -qm base
BASE_SHA=$(git -C "$t" rev-parse HEAD)
git -C "$t" update-ref refs/remotes/origin/main "$BASE_SHA"
mkdir -p "$t/lint/allowlists"
{ echo "# dated allowlist"
  echo "skills/red-skill/SKILL.md"
} > "$t/lint/allowlists/25-archived-names.txt"
rc=$(run_check "$t")
if [ "$rc" = 0 ] && grep -q "this is the seed" "$OUT"; then
  ok "SEED: first landing passes, ratchet notes it starts"
else
  bad "SEED: expected exit 0 with seed note, got $rc"; cat "$OUT"
fi

# --- 6 EXCLUSIONS: standing words + survivor names stay legal -----------------
t="$work/excl"
mkdir -p "$t/_archive/skills/ac-implement" "$t/_archive/skills/ac-merge" \
  "$t/skills/ac-implement" "$t/skills/words"
printf '# v1\n' > "$t/_archive/skills/ac-implement/SKILL.md"
printf '# retired\n' > "$t/_archive/skills/ac-merge/SKILL.md"
printf '%s\n' '# ac-implement' '' 'For the audit, planning uses openrouter.' > "$t/skills/ac-implement/SKILL.md"
printf '%s\n' '# words' '' 'audit planning openrouter — all legal.' > "$t/skills/words/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "EXCLUSIONS: standing words and survivor names pass"
else
  bad "EXCLUSIONS: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 7 STALE DECLARATION: survivor no longer live -> exit 1 -------------------
t="$work/stale-decl"
mkdir -p "$t/_archive/skills/ac-implement" "$t/skills/other"
printf '# v1\n' > "$t/_archive/skills/ac-implement/SKILL.md"
printf '%s\n' '# other' '' 'clean' > "$t/skills/other/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "stale declaration" "$OUT"; then
  ok "STALE-DECL: dead survivor declaration refused"
else
  bad "STALE-DECL: expected exit 1 naming the stale declaration, got $rc"; cat "$OUT"
fi

# --- 8 NOT-GATED: archived names derived but zero live text -> exit 2 --------
t="$work/empty"
mkdir -p "$t/_archive/skills/ac-loop"
printf '# retired\n' > "$t/_archive/skills/ac-loop/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no live text -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 25-archived-names contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
