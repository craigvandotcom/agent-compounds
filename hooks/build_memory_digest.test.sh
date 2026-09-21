#!/usr/bin/env bash
#
# build_memory_digest.test.sh — the proof harness for hooks/build_memory_digest.py.
#
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-proofs.sh (glob-discovered, executed by the registry-lint
#   `harnesses` CI job) and lint.sh Check 21, which audits this declaration. Deliberately
#   UNWIRED in engine/hooks.wiring.json: it is the PROOF for build_memory_digest.py, not
#   a hook itself.
#
# Both states the bead pins:
#   lanes present  — MISSION_ROOT + a MEMORY_HOOK_APPS_LIST fixture resolve per-lane
#                    lines, ordered domain rules > app rules > domain facts
#   no list        — exactly one line saying no memory lanes are configured, exit 0
# plus the transition contract: the old caller's arguments are IGNORED (engine/sync.sh
# still passes them until ac-vlje.5 switches the call sites), and the output is
# deterministic for a given tree (write_generated idempotence).
#
# All state lives in one temp dir; no real ~/mission, ~/infrastructure or apps.list is read.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIGEST="$HERE/build_memory_digest.py"
[ -f "$DIGEST" ] || { echo "build_memory_digest.test.sh: $DIGEST missing"; exit 2; }

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

# --- fixture substrate ---------------------------------------------------------------
mkdir -p "$W/mission/memory/auto" \
         "$W/mission/software/app-one/memory/auto" \
         "$W/mission/software/app-two/memory/auto" \
         "$W/infra"

memory() { # <path> <name> <type> <description>
  printf -- '---\nname: %s\ndescription: %s\ntype: %s\n---\nbody\n' "$2" "$4" "$3" > "$1"
}
memory "$W/mission/memory/auto/domain-rule.md"  fixture-domain-rule  rule "A domain rule."
memory "$W/mission/memory/auto/domain-fact.md"  fixture-domain-fact  fact "A domain fact."
memory "$W/mission/software/app-one/memory/auto/app-rule.md" fixture-app-rule "rule" "An app rule."
memory "$W/mission/software/app-two/memory/auto/other-rule.md" fixture-other-rule "rule" "Another app rule."
# A lane named with no memory dir at all must not error.
printf 'app-one\napp-two\napp-three\n' > "$W/infra/apps.list"

run_digest() { # <apps-list-path> [extra args...]
  local list="$1"; shift
  MISSION_ROOT="$W/mission" INFRA_ROOT="$W/infra" MEMORY_HOOK_APPS_LIST="$list" \
    python3 "$DIGEST" "$@" 2>&1
}

# --- lanes present: per-lane lines, ordered ------------------------------------------
out="$(run_digest "$W/infra/apps.list")"; rc=$?
if [ "$rc" = 0 ]; then
  for expect in \
    "- **fixture-domain-rule** (mission)" \
    "- **fixture-app-rule** (app-one)" \
    "- **fixture-other-rule** (app-two)" \
    "- **fixture-domain-fact** (mission)"; do
    printf '%s\n' "$out" | grep -qF -- "$expect" \
      && ok "lanes: emitted '$expect'" \
      || { bad "lanes: missing '$expect'"; printf '%s\n' "$out"; }
  done
  printf '%s\n' "$out" > "$W/out1"
  d=$(grep -nF -- 'fixture-domain-rule' "$W/out1" | cut -d: -f1)
  a=$(grep -nF -- 'fixture-app-rule' "$W/out1" | cut -d: -f1)
  f=$(grep -nF -- 'fixture-domain-fact' "$W/out1" | cut -d: -f1)
  if [ -n "$d" ] && [ -n "$a" ] && [ -n "$f" ] && [ "$d" -lt "$a" ] && [ "$a" -lt "$f" ]; then
    ok "lanes: ordered domain rules > app rules > domain facts"
  else
    bad "lanes: order wrong (domain=$d app=$a fact=$f)"; printf '%s\n' "$out"
  fi
else
  bad "lanes: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- determinism: same tree, same bytes ----------------------------------------------
run_digest "$W/infra/apps.list" > "$W/out2"
if cmp -s "$W/out1" "$W/out2"; then
  ok "determinism: two runs over one tree are byte-identical"
else
  bad "determinism: two runs differ"
fi

# --- transition: the old caller's arguments are ignored ------------------------------
out="$(run_digest "$W/infra/apps.list" "$W/mission" "$W/mission/software/app-one")"; rc=$?
if [ "$rc" = 0 ] && [ "$out" = "$(cat "$W/out1")" ]; then
  ok "transition: old positional arguments are ignored, output unchanged"
else
  bad "transition: arguments changed the output or exit (rc=$rc)"
fi

# --- no list: one line, exit 0 -------------------------------------------------------
out="$(run_digest "$W/missing.list")"; rc=$?
lines="$(printf '%s\n' "$out" | grep -c . || true)"
if [ "$rc" = 0 ] && [ "$lines" = 1 ] && printf '%s' "$out" | grep -q 'no memory lanes are configured'; then
  ok "no list: exactly one line, exit 0"
else
  bad "no list: expected 1 line and exit 0, got $lines line(s) rc=$rc"; printf '%s\n' "$out"
fi

# --- empty list: same state ----------------------------------------------------------
: > "$W/empty.list"
out="$(run_digest "$W/empty.list")"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'no memory lanes are configured'; then
  ok "empty list: one no-lanes line, exit 0"
else
  bad "empty list: expected the no-lanes line and 0, got rc=$rc"; printf '%s\n' "$out"
fi

echo "build_memory_digest.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
