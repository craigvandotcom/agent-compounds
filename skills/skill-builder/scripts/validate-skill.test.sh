#!/usr/bin/env bash
# validate-skill.test.sh — single-skill mode proof: a well-formed skill fixture
# validates clean (exit 0), a fixture with a broken markdown-link pointer fails
# (exit 1). --registry mode's rules (budget, >1024 desc, invocation graph) already
# have their own RED cases in lint/checks/13-skill-registry.test.sh, which dispatches
# to this same script; this is single-skill mode's OWN test, closing the test-bar
# decision in _plans/2026-09-23-1446-lint-system-upgrade.md (parity finding P5:
# validate-skill.sh, 482 LOC, had no test).
#
# ASSURANCE
#   PROBE:    bash skills/skill-builder/scripts/validate-skill.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="$HERE/validate-skill.sh"
[ -f "$VALIDATE" ] || { echo "HARNESS FAIL: $VALIDATE missing"; exit 1; }

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

# --- GOOD: a well-formed skill validates clean (exit 0) --------------------------
mkdir -p "$W/good/references"
cat > "$W/good/SKILL.md" <<'EOF'
---
name: good-fixture
description: "Use when proving validate-skill.sh's single-skill mode passes a well-formed skill. Triggers on: validate-skill test fixture."
---

# good-fixture

## When to Use

Testing only.

## Core Pattern

See [the reference](references/note.md) for detail.
EOF
echo "note" > "$W/good/references/note.md"

out="$(bash "$VALIDATE" "$W/good" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "VALIDATION PASSED"; then
  ok "GOOD fixture -> VALIDATION PASSED (exit 0)"
else
  bad "GOOD fixture: expected exit 0 + VALIDATION PASSED, got rc=$rc"; printf '%s\n' "$out"
fi

# --- BAD: a broken markdown-link pointer fails (exit 1) --------------------------
mkdir -p "$W/bad"
cat > "$W/bad/SKILL.md" <<'EOF'
---
name: bad-fixture
description: "Use when proving validate-skill.sh's single-skill mode fails a broken pointer. Triggers on: validate-skill test fixture."
---

# bad-fixture

## When to Use

Testing only.

## Core Pattern

See [the reference](references/missing.md) for detail.
EOF

out="$(bash "$VALIDATE" "$W/bad" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "broken link pointer: references/missing.md"; then
  ok "BAD fixture (broken pointer) -> VALIDATION FAILED (exit 1)"
else
  bad "BAD fixture: expected exit 1 + broken-pointer FAIL, got rc=$rc"; printf '%s\n' "$out"
fi

echo "---"
echo "validate-skill.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
