#!/usr/bin/env bash
# 28-path-resolution.test.sh — fixture tests for lint/checks/28-path-resolution.py.
#
# Both polarities, always: a check that flags nothing and a check that flags
# everything both satisfy half the contract. Each case builds its own throwaway
# tree so the assertions cannot drift with the live registry's citations.
#
# Run directly:  bash lint/checks/28-path-resolution.test.sh
# Discovered automatically by scripts/run-all-proofs.sh.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
CHECK="$DIR/28-path-resolution.py"

FAILURES=0
# Assertion lines are space-delimited (`PASS <case>` / `FAIL <case>`) and the
# summary carries `N passed` — the grammar close-gate's COVERAGE leg greps for,
# so a harness output no runner can parse cannot wear a green.
pass() { echo "  PASS $1"; }
fail() { echo "  FAIL $1"; FAILURES=$((FAILURES + 1)); }

[ -f "$CHECK" ] || { echo "HARNESS FAIL: missing $CHECK"; exit 1; }

# build_tree <dir> — writes files given as "relpath<<EOF...EOF" is overkill in
# bash; callers use mk + emit below.
new_tree() { mktemp -d "${TMPDIR:-/tmp}/c28-XXXXXX"; }
mk() { mkdir -p "$(dirname "$1")" && cat > "$1"; }
run() { OUT="$(python3 "$CHECK" "$TREE" 2>&1)"; RC=$?; }

T="$(new_tree)"; trap 'rm -rf "$T"' EXIT

# --- Case 1: GREEN — every citation resolves, both grammar forms -------------
TREE="$T/green"; mkdir -p "$TREE"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
Repo-relative: `skills/other/references/guide.md`.
Skill-relative: `other/references/guide.md`.
EOF
mk "$TREE/skills/other/references/guide.md" <<'EOF'
present
EOF
run
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "ok: 28-path-resolution"; then
  pass "Case 1: citations resolving under both grammar forms are clean (exit 0)"
else
  fail "Case 1: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 2: RED — a live file cites a path that does not exist (AC 2) -------
TREE="$T/red"; mkdir -p "$TREE"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `skills/demo/references/missing.md` for the detail.
EOF
mk "$TREE/skills/demo/references/other.md" <<'EOF'
present
EOF
run
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "skills/demo/references/missing.md"; then
  pass "Case 2: a citation to a nonexistent file goes RED naming the path (exit 1)"
else
  fail "Case 2: expected exit 1 naming the missing path, got $RC. Output: $OUT"
fi

# --- Case 3: form-2 resolution — `<skill>/references/<f>` resolves via skills/
TREE="$T/form2"; mkdir -p "$TREE"
mk "$TREE/skills/citer/SKILL.md" <<'EOF'
See `demo/references/real.md`.
EOF
mk "$TREE/skills/demo/references/real.md" <<'EOF'
present
EOF
run
if [ "$RC" -eq 0 ]; then
  pass "Case 3: form-2 citation resolves as skills/<skill>/references/<file>"
else
  fail "Case 3: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 4: allowlist admits a dangling path, dated --------------------------
TREE="$T/allow"; mkdir -p "$TREE/lint/allowlists"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `skills/gone/references/old.md`.
EOF
mk "$TREE/lint/allowlists/28-path-resolution.txt" <<EOF
2026-09-07 skills/gone/references/old.md
EOF
run
if [ "$RC" -eq 0 ]; then
  pass "Case 4: a dated allowlist entry admits its dangling path (exit 0)"
else
  fail "Case 4: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 5: shrink-only — an entry whose path RESOLVES is itself a violation -
TREE="$T/shrink"; mkdir -p "$TREE/lint/allowlists"
mk "$TREE/skills/demo/references/real.md" <<'EOF'
present
EOF
mk "$TREE/lint/allowlists/28-path-resolution.txt" <<EOF
2026-09-07 skills/demo/references/real.md
EOF
run
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "delete the line"; then
  pass "Case 5: a stale allowlist entry (path now resolves) FAILS shrink-only"
else
  fail "Case 5: expected exit 1 with the shrink-only verdict, got $RC. Output: $OUT"
fi

# --- Case 6: substring collisions are not citations --------------------------
TREE="$T/sub"; mkdir -p "$TREE"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
Longer-path form: `.claude/skills/elsewhere/SKILL.md`.
Archive form: `_archive/skills/demo/SKILL.md`.
Full skill-name citation: `ac-demo/references/real.md`.
Dir-only: `skills/other` and bare `lint.sh`.
EOF
mk "$TREE/skills/ac-demo/references/real.md" <<'EOF'
present
EOF
mk "$TREE/skills/demo/references/real.md" <<'EOF'
present
EOF
run
if [ "$RC" -eq 0 ]; then
  pass "Case 6: longer-path, archive, substring and dir-only forms are not citations"
else
  fail "Case 6: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 7: CORPUS is exempt -------------------------------------------------
TREE="$T/corpus"; mkdir -p "$TREE/skills/skill-builder/references"
mk "$TREE/skills/skill-builder/references/trigger-corpus.md" <<'EOF'
Cites `skills/nothing/references/absent.md` freely.
EOF
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `skills/demo/references/real.md`.
EOF
mk "$TREE/skills/demo/references/real.md" <<'EOF'
present
EOF
run
if [ "$RC" -eq 0 ]; then
  pass "Case 7: the trigger corpus is exempt from path resolution"
else
  fail "Case 7: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 8: malformed allowlist line is a defect -----------------------------
TREE="$T/malformed"; mkdir -p "$TREE/lint/allowlists"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `skills/demo/references/real.md`.
EOF
mk "$TREE/skills/demo/references/real.md" <<'EOF'
present
EOF
mk "$TREE/lint/allowlists/28-path-resolution.txt" <<EOF
skills/gone/references/old.md
EOF
run
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "not \`YYYY-MM-DD key"; then
  pass "Case 8: an undated allowlist line is a malformed-entry defect"
else
  fail "Case 8: expected exit 1 naming the malformed line, got $RC. Output: $OUT"
fi

# --- Case 9: NOT-GATED — an empty tree verifies nothing -----------------------
TREE="$T/empty"; mkdir -p "$TREE"
run
if [ "$RC" -eq 2 ]; then
  pass "Case 9: an empty scan is NOT-GATED (exit 2), never a pass"
else
  fail "Case 9: expected exit 2, got $RC. Output: $OUT"
fi

# --- Case 10: form-3 — a root-relative top-level-dir citation resolves --------
TREE="$T/form3-ok"; mkdir -p "$TREE/engine"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `engine/wiring.json` for the manifest.
EOF
mk "$TREE/engine/wiring.json" <<'EOF'
{}
EOF
run
if [ "$RC" -eq 0 ]; then
  pass "Case 10: a root-relative top-level-dir citation (engine/wiring.json) resolves"
else
  fail "Case 10: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 11: RED — a missing root-relative top-level-dir citation fails ------
TREE="$T/form3-red"; mkdir -p "$TREE/engine"
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `engine/missing.json` for the manifest.
EOF
run
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "engine/missing.json"; then
  pass "Case 11: a missing root-relative top-level-dir citation (engine/missing.json) FAILS, named"
else
  fail "Case 11: expected exit 1 naming engine/missing.json, got $RC. Output: $OUT"
fi

# --- Case 12: form-3 latitude — resolves against ANY skill's own subdirectory -
TREE="$T/form3-any-skill"; mkdir -p "$TREE/tools" "$TREE/skills/citer" "$TREE/skills/owner/tools"
mk "$TREE/skills/citer/SKILL.md" <<'EOF'
Run `tools/build.sh` first.
EOF
mk "$TREE/skills/owner/tools/build.sh" <<'EOF'
#!/bin/sh
EOF
run
if [ "$RC" -eq 0 ]; then
  pass "Case 12: a bare top-level-dir citation resolves against any skill's own subdirectory"
else
  fail "Case 12: expected exit 0, got $RC. Output: $OUT"
fi

# --- Case 13: form-3 excludes an ambiguous top-level dir (a `scripts/`-shaped -
# name recurring under >=3 skills means bare mentions are routinely self- or
# consumer-app references, not citations into this repo) -----------------------
TREE="$T/form3-ambiguous"; mkdir -p "$TREE/scripts"
for s in a b c; do mkdir -p "$TREE/skills/$s/scripts"; done
mk "$TREE/skills/demo/SKILL.md" <<'EOF'
See `scripts/does-not-exist-anywhere.sh` for the example.
EOF
run
if [ "$RC" -eq 0 ]; then
  pass "Case 13: a top-level dir recurring under >=3 skills is excluded from form 3 (not flagged)"
else
  fail "Case 13: expected exit 0 (scripts/ excluded, ambiguous), got $RC. Output: $OUT"
fi

if [ "$FAILURES" -eq 0 ]; then
  echo "28-path-resolution.test.sh: 13 passed, 0 failed"
  exit 0
fi
echo "28-path-resolution.test.sh: 0 passed, $FAILURES failed"
exit 1
