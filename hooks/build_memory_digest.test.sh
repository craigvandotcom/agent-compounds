#!/usr/bin/env bash
#
# build_memory_digest.test.sh — the proof harness for hooks/build_memory_digest.py.
#
# ASSURANCE-ROLE: test-harness
# CALLER: scripts/run-all-proofs.sh (glob-discovered, executed by the registry-lint
#   `proofs` CI job) and lint.sh Check 21, which audits this declaration. Deliberately
#   UNWIRED in engine/hooks.wiring.json: it is the PROOF for build_memory_digest.py, not
#   a hook itself.
#
# The states this suite pins:
#   lanes present      — MISSION_ROOT + a MEMORY_HOOK_APPS_LIST fixture resolve per-lane
#                        lines, ordered domain rules > app rules > domain facts
#   list ABSENT        — the DOMAIN lane still renders, and one line says no apps list is
#                        there, naming the path it looked for
#   list EMPTY         — the domain lane still renders, and the disclosure says the list
#                        is EMPTY — never that the file is missing (it exists)
#   default resolution — with MEMORY_HOOK_APPS_LIST unset the list resolves under
#                        INFRA_ROOT (the only path production takes)
#   domain repo        — MISSION_ROOT falls back to this checkout's own location when the
#                        env leaves it unset, and a disagreement between the env value and
#                        that location WARNS on stderr instead of rendering empty
# plus the transition contract: the old caller's arguments are IGNORED (engine/sync.sh
# still passes them until ac-vlje.5 switches the call sites), and the output is
# deterministic for a given tree (write_generated idempotence).
#
# All fixture state lives in one temp dir. The derived-location cases read this checkout's
# real domain lane (nothing is written there); every other case is hermetic.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIGEST="$HERE/build_memory_digest.py"
[ -f "$DIGEST" ] || { echo "build_memory_digest.test.sh: $DIGEST missing"; exit 2; }

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

# The domain repo the digest derives from its own location: hooks -> <repo> -> <parent> -> domain.
DERIVED="$(cd "$HERE/../../.." && pwd)"

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

run_digest() { # <apps-list-path> [extra args...] -> stdout only
  local list="$1"; shift
  MISSION_ROOT="$W/mission" INFRA_ROOT="$W/infra" MEMORY_HOOK_APPS_LIST="$list" \
    python3 "$DIGEST" "$@" 2>/dev/null
}
run_digest_err() { # <mission-root> <apps-list-path> -> stderr only
  MISSION_ROOT="$1" INFRA_ROOT="$W/infra" MEMORY_HOOK_APPS_LIST="$2" \
    python3 "$DIGEST" 2>&1 >/dev/null
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
  if printf '%s\n' "$out" | grep -q 'no memory lanes are configured'; then
    bad "lanes: a configured list still printed the no-lanes disclosure"
  else
    ok "lanes: no disclosure when the list resolved"
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

# --- list ABSENT: the domain lane renders anyway, and the path is named ---------------
out="$(run_digest "$W/missing.list")"; rc=$?
if [ "$rc" = 0 ] \
   && printf '%s\n' "$out" | grep -qF -- '- **fixture-domain-rule** (mission)' \
   && printf '%s\n' "$out" | grep -qF -- '- **fixture-domain-fact** (mission)' \
   && printf '%s\n' "$out" | grep -q 'no memory lanes are configured' \
   && printf '%s\n' "$out" | grep -qF "no apps list at $W/missing.list" \
   && ! printf '%s\n' "$out" | grep -qF -- '**fixture-app-rule**'; then
  ok "absent list: domain lane renders, disclosure names the missing path, no app lanes"
else
  bad "absent list: domain lane or disclosure wrong (rc=$rc)"; printf '%s\n' "$out"
fi

# --- list EMPTY: the domain lane renders, and the file is not called missing ----------
: > "$W/empty.list"
out="$(run_digest "$W/empty.list")"; rc=$?
if [ "$rc" = 0 ] \
   && printf '%s\n' "$out" | grep -qF -- '- **fixture-domain-rule** (mission)' \
   && printf '%s\n' "$out" | grep -q 'is empty' \
   && ! printf '%s\n' "$out" | grep -qF 'no apps list at'; then
  ok "empty list: domain lane renders, disclosure says empty (not missing)"
else
  bad "empty list: expected the domain lane and an empty-not-missing disclosure (rc=$rc)"; printf '%s\n' "$out"
fi

# --- default resolution: no MEMORY_HOOK_APPS_LIST -> INFRA_ROOT/apps.list --------------
out="$(MISSION_ROOT="$W/mission" INFRA_ROOT="$W/infra" env -u MEMORY_HOOK_APPS_LIST \
       python3 "$DIGEST" 2>/dev/null)"; rc=$?
if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qF -- '- **fixture-app-rule** (app-one)'; then
  ok "default list: MEMORY_HOOK_APPS_LIST unset resolves INFRA_ROOT/apps.list"
else
  bad "default list: expected the INFRA_ROOT/apps.list lanes, got rc=$rc"; printf '%s\n' "$out"
fi

# --- domain repo: a disagreeing env value warns, naming both --------------------------
err="$(run_digest_err "$W/other-mission" "$W/missing.list")"
if printf '%s\n' "$err" | grep -q 'WARNING' \
   && printf '%s\n' "$err" | grep -qF "$W/other-mission" \
   && printf '%s\n' "$err" | grep -qF "$DERIVED"; then
  ok "domain repo: a disagreeing MISSION_ROOT warns, naming both paths"
else
  bad "domain repo: expected a warning naming both paths, got: $err"
fi

# --- domain repo: unset -> the fallback is this checkout's own location ----------------
out="$(env -u MISSION_ROOT INFRA_ROOT="$W/infra" \
       MEMORY_HOOK_APPS_LIST="$W/missing.list" python3 "$DIGEST" 2>/dev/null)"
if printf '%s\n' "$out" | grep -qF "resolved under $DERIVED/software"; then
  ok "domain repo: unset MISSION_ROOT falls back to this checkout's own location"
else
  bad "domain repo: expected the fallback to name $DERIVED/software"
fi

echo "build_memory_digest.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
