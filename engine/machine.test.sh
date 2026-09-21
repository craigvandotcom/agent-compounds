#!/usr/bin/env bash
#
# machine.test.sh — the executable contract of engine/machine.sh, the one reader of
# machine.json.
#
# Every case drives the reader through the AC_MACHINE_FILE fixture seam and builds all
# its state inside one temp dir: nothing outside $W is read or written, so the suite is
# safe in a shared checkout and on any machine.
#
# Pinned here:
#   not-configured -> 4 (both --org-root and --targets)
#   malformed JSON, org_root missing, a missing target, a target equal to org_root,
#     a non-directory org_root -> 2, naming the key and the path
#   --lit: a path under $HOME renders `$HOME/...`, a path outside it is unchanged,
#          `~` and `~/...` expand first
#   `~` expansion in a configured org_root
#   public and packages round-trip through --targets
#   --harnesses: the committed base alone (exit 0) with no file; an omitted harness
#     still reads enabled; an agent_models override survives the merge
#   the DEPTH case's reader leg: the engine copied to a path of a different depth,
#     AC_MACHINE_FILE at a fixture, and --targets resolving exactly the fixture's
#     targets. The checks 07/12 and `sync.sh --all -n` legs cannot be green here —
#     those readers switch in ac-vlje.8 and ac-vlje.5 — so they join this case at the
#     epic's own pick.
#
# ASSURANCE
#   PROBE:    bash engine/machine.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh + CI harness job
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MACHINE="$HERE/machine.sh"
[ -x "$MACHINE" ] || { echo "machine.test.sh: $MACHINE is missing or not executable"; exit 2; }

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

# The targets these fixtures name, and the space every case stays inside.
mkdir -p "$W/org/software/app-one" "$W/org/software/app-public" "$W/org/not-a-target"

# --- not-configured -> 4 -----------------------------------------------------------------
rc=0; AC_MACHINE_FILE="$W/does-not-exist.json" "$MACHINE" --org-root >/dev/null 2>&1 || rc=$?
if [ "$rc" = 4 ]; then ok "not-configured: --org-root -> 4"; else bad "not-configured --org-root: expected 4, got $rc"; fi
rc=0; AC_MACHINE_FILE="$W/does-not-exist.json" "$MACHINE" --targets >/dev/null 2>&1 || rc=$?
if [ "$rc" = 4 ]; then ok "not-configured: --targets -> 4"; else bad "not-configured --targets: expected 4, got $rc"; fi

# --- configured-but-wrong -> 2, naming the key and the path ------------------------------
printf 'this is not json\n' > "$W/malformed.json"
out="$(AC_MACHINE_FILE="$W/malformed.json" "$MACHINE" --org-root 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'JSON' && printf '%s' "$out" | grep -q 'malformed.json'; then
  ok "wrong: malformed JSON -> 2 naming the file"
else
  bad "wrong malformed: expected 2 naming the file, got $rc"; printf '%s\n' "$out"
fi

printf '{"targets": []}\n' > "$W/no-org.json"
out="$(AC_MACHINE_FILE="$W/no-org.json" "$MACHINE" --org-root 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'org_root'; then
  ok "wrong: org_root missing -> 2 naming the key"
else
  bad "wrong no-org: expected 2 naming org_root, got $rc"; printf '%s\n' "$out"
fi

printf '{"org_root": "%s/org", "targets": [{"path": "%s/org/software/ghost", "public": false}]}\n' "$W" "$W" > "$W/missing-target.json"
out="$(AC_MACHINE_FILE="$W/missing-target.json" "$MACHINE" --targets 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'ghost'; then
  ok "wrong: missing target -> 2 naming the path"
else
  bad "wrong missing-target: expected 2 naming the path, got $rc"; printf '%s\n' "$out"
fi

printf '{"org_root": "%s/org", "targets": [{"path": "%s/org", "public": false}]}\n' "$W" "$W" > "$W/target-is-org.json"
out="$(AC_MACHINE_FILE="$W/target-is-org.json" "$MACHINE" --org-root 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'org_root'; then
  ok "wrong: a target equal to org_root -> 2 naming the key"
else
  bad "wrong target-is-org: expected 2 naming org_root, got $rc"; printf '%s\n' "$out"
fi

printf '{"org_root": "%s/harnesses.json", "targets": []}\n' "$ROOT" > "$W/org-not-dir.json"
out="$(AC_MACHINE_FILE="$W/org-not-dir.json" "$MACHINE" --org-root 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'not a directory'; then
  ok "wrong: org_root not a directory -> 2"
else
  bad "wrong org-not-dir: expected 2, got $rc"; printf '%s\n' "$out"
fi

# --- --lit -------------------------------------------------------------------------------
check_lit() { # <input> <expected> <label>
  local got; got="$("$MACHINE" --lit "$1" 2>&1)"; local rc=$?
  if [ "$rc" = 0 ] && [ "$got" = "$2" ]; then ok "lit: $3 -> $2"
  else bad "lit $3: expected '$2' (0), got '$got' ($rc)"; fi
}
check_lit "$HOME/x/y" '$HOME/x/y' 'under $HOME'
check_lit "$HOME" '$HOME' 'exactly $HOME'
check_lit "/opt/elsewhere" '/opt/elsewhere' 'outside $HOME unchanged'
check_lit '~' '$HOME' 'bare tilde'
check_lit '~/z' '$HOME/z' 'tilde-slash'

# --- `~` expansion in a configured path ---------------------------------------------------
printf '{"org_root": "~", "targets": []}\n' > "$W/tilde-org.json"
got="$(AC_MACHINE_FILE="$W/tilde-org.json" "$MACHINE" --org-root 2>&1)"; rc=$?
if [ "$rc" = 0 ] && [ "$got" = "$HOME" ]; then
  ok "tilde: org_root '~' expands to \$HOME"
else
  bad "tilde org_root: expected '$HOME' (0), got '$got' ($rc)"
fi

# --- public and packages round-trip -------------------------------------------------------
printf '{"org_root": "%s/org", "targets": [\n  {"path": "%s/org/software/app-one", "public": true},\n  {"path": "%s/org/software/app-public", "public": false, "packages": ["factory-core", "substrate"]}\n]}\n' \
  "$W" "$W" "$W" > "$W/roster.json"
out="$(AC_MACHINE_FILE="$W/roster.json" "$MACHINE" --targets 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  printf '%s\n' "$out" | grep -qF "$W/org/software/app-one"$'\t''public' \
    && ok "targets: public round-trips" \
    || { bad "targets: public did not round-trip"; printf '%s\n' "$out"; }
  printf '%s\n' "$out" | grep -qF "$W/org/software/app-public"$'\t''packages=factory-core,substrate' \
    && ok "targets: packages round-trip" \
    || { bad "targets: packages did not round-trip"; printf '%s\n' "$out"; }
  [ "$(printf '%s\n' "$out" | wc -l | tr -d '[:space:]')" = 2 ] \
    && ok "targets: exactly the two targets, one line each" \
    || { bad "targets: expected 2 lines"; printf '%s\n' "$out"; }
else
  bad "targets round-trip: expected 0, got $rc"; printf '%s\n' "$out"
fi

# --- the depth case's reader leg -----------------------------------------------------------
# The engine copied to a path of a different DEPTH. The reader derives its own root, so it
# must still resolve exactly the fixture's targets wherever it lives.
#
# (checks 07/12 and `sync.sh --all -n` join this case at the epic's pick — ac-vlje.8 and
#  ac-vlje.5 switch those readers; neither is switched yet.)
DEEP="$W/deep/one/two/three/registry"
mkdir -p "$DEEP"
cp -R "$HERE" "$DEEP/engine"
cp "$ROOT/harnesses.json" "$DEEP/harnesses.json"
expect="$(printf '%s\t%s\n%s\t%s\n' \
  "$W/org/software/app-one" 'public' \
  "$W/org/software/app-public" 'packages=factory-core,substrate')"
got="$(AC_MACHINE_FILE="$W/roster.json" "$DEEP/engine/machine.sh" --targets 2>&1)"; rc=$?
if [ "$rc" = 0 ] && [ "$got" = "$expect" ]; then
  ok "depth: the engine at a different depth resolves exactly the fixture's targets"
else
  bad "depth case: expected the fixture's targets (0), got rc=$rc"; printf '%s\n' "$got"
fi

# --- --harnesses ---------------------------------------------------------------------------
base="$W/no-file-base.json"
out="$(AC_MACHINE_FILE="$base" "$MACHINE" --harnesses 2>&1)"; rc=$?
if [ "$rc" = 0 ] && [ "$out" = "$(cat "$ROOT/harnesses.json")" ]; then
  ok "harnesses: no file -> the committed base alone, exit 0"
else
  bad "harnesses base-alone: expected harnesses.json (0), got rc=$rc"
fi

printf '{"org_root": "%s/org", "targets": [], "harnesses": {"claude": {"agent_models": {"worker": "custom-worker"}}, "droid": {"enabled": true}}}\n' \
  "$W" > "$W/overrides.json"
out="$(AC_MACHINE_FILE="$W/overrides.json" "$MACHINE" --harnesses 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  got="$(printf '%s' "$out" | jq -r '.harnesses.claude.agent_models.worker')"
  [ "$got" = "custom-worker" ] \
    && ok "harnesses: an agent_models override survives the merge" \
    || bad "harnesses: agent_models override lost (got '$got')"
  got="$(printf '%s' "$out" | jq -r '.harnesses.codex.enabled')"
  [ "$got" = "true" ] \
    && ok "harnesses: an omitted harness still reads enabled" \
    || bad "harnesses: omitted codex read '$got', not true"
else
  bad "harnesses merge: expected 0, got $rc"; printf '%s\n' "$out"
fi

echo "machine.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
