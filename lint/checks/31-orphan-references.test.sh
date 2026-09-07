#!/usr/bin/env bash
# 31-orphan-references.test.sh — the contract harness for lint/checks/31-orphan-references.py.
#
#   PROBE: a references/ file nothing points at FAILS with the path named; a
#           scoped pointer (references/x.md) and a full-path pointer from
#           another skill both keep a file alive; an allowlisted orphan PASSES
#           with the seed note; an entry whose file gained a reader is refused
#           (the list only shrinks); an entry ADDED vs the committed base is
#           refused (growth); a tree with no reference dirs is NOT-GATED.
#
# ASSURANCE
#   PROBE:    bash lint/checks/31-orphan-references.test.sh
#   SCHEDULE: scripts/run-all-harnesses.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/31-orphan-references.py"

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

OUT="$(mktemp)"
run_check() { # <tmp-root> -> exit code; output in $OUT
  python3 "$CHECK" "$1" >"$OUT" 2>&1
  echo $?
}

work="$(mktemp -d)"
trap 'rm -rf "$work" "$OUT"' EXIT

build_tree() { # <root> — skill-a points at used.md (scoped); orphan.md points at nothing
  mkdir -p "$1/skills/skill-a/references"
  printf '%s\n' '# skill-a' '' 'Use `references/used.md` for the recipe.' \
    > "$1/skills/skill-a/SKILL.md"
  printf '# used\n' > "$1/skills/skill-a/references/used.md"
  printf '# orphan\n' > "$1/skills/skill-a/references/orphan.md"
}

# --- 1 RED: the unreferenced file fails, named --------------------------------
t="$work/red"; build_tree "$t"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "skills/skill-a/references/orphan.md is an orphan" "$OUT"; then
  ok "RED: orphan reference failed, named"
else
  bad "RED: expected exit 1 naming the orphan, got $rc"; cat "$OUT"
fi

# --- 2 GREEN: scoped AND full-path pointers keep files alive -------------------
t="$work/green"; build_tree "$t"
mkdir -p "$t/skills/skill-b"
printf '%s\n' '# skill-b' '' 'Read skills/skill-a/references/orphan.md for the details.' \
  > "$t/skills/skill-b/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 0 ]; then
  ok "GREEN: full-path pointer from another skill keeps the file alive"
else
  bad "GREEN: expected exit 0, got $rc"; cat "$OUT"
fi

# --- 3 ALLOWLIST: the orphan allowlisted -> exit 0, seed noted -----------------
t="$work/allowlisted"; build_tree "$t"
mkdir -p "$t/lint/allowlists"
{ echo "# dated allowlist"
  echo "skills/skill-a/references/orphan.md"
} > "$t/lint/allowlists/31-orphan-references.txt"
rc=$(run_check "$t")
if [ "$rc" = 0 ] && grep -qE "this is the seed|no resolvable base ref" "$OUT"; then
  ok "ALLOWLIST: allowlisted orphan passes; ratchet notes it is a seed"
else
  bad "ALLOWLIST: expected exit 0 with seed note, got $rc"; cat "$OUT"
fi

# --- 4 SHRINK: entry whose file gained a reader -> refused ---------------------
t="$work/shrink"; build_tree "$t"
mkdir -p "$t/skills/skill-b" "$t/lint/allowlists"
printf '%s\n' '# skill-b' '' 'Read skills/skill-a/references/orphan.md now.' \
  > "$t/skills/skill-b/SKILL.md"
{ echo "# dated allowlist"
  echo "skills/skill-a/references/orphan.md"
} > "$t/lint/allowlists/31-orphan-references.txt"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "no longer an orphan" "$OUT"; then
  ok "SHRINK: entry for a file that gained a reader is refused"
else
  bad "SHRINK: expected exit 1 naming the shrink rule, got $rc"; cat "$OUT"
fi

# --- 5 GROWTH: entry added vs committed base -> refused ------------------------
t="$work/growth"; build_tree "$t"
mkdir -p "$t/lint/allowlists"
echo "# dated allowlist" > "$t/lint/allowlists/31-orphan-references.txt"
git -C "$t" init -q
git -C "$t" -c user.name=h -c user.email=h@x add -A
git -C "$t" -c user.name=h -c user.email=h@x commit -qm base
BASE_SHA=$(git -C "$t" rev-parse HEAD)
git -C "$t" update-ref refs/remotes/origin/main "$BASE_SHA"
{ echo "# dated allowlist"
  echo "skills/skill-a/references/orphan.md"
} > "$t/lint/allowlists/31-orphan-references.txt"
rc=$(run_check "$t")
if [ "$rc" = 1 ] && grep -q "allowlist GREW" "$OUT"; then
  ok "GROWTH: added entry refused against committed base"
else
  bad "GROWTH: expected exit 1 naming growth, got $rc"; cat "$OUT"
fi

# --- 6 NOT-GATED: no reference dirs -> exit 2 ----------------------------------
t="$work/empty"
mkdir -p "$t/skills/skill-a"
printf '%s\n' '# skill-a' '' 'No reference files here.' > "$t/skills/skill-a/SKILL.md"
rc=$(run_check "$t")
if [ "$rc" = 2 ] && grep -qi "NOT-CHECKED" "$OUT"; then
  ok "EMPTY: no reference dirs -> NOT-GATED exit 2"
else
  bad "EMPTY: expected exit 2 NOT-CHECKED, got $rc"; cat "$OUT"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "All 31-orphan-references contract cases passed."
  exit 0
fi
echo "$fails case(s) FAILED."
exit 1
