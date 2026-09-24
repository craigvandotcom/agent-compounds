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
#   every other refusal -> 2: an unknown argument; a non-absolute org_root; targets that
#     are not an array; a targets[] entry with no path, non-array packages, or a
#     non-boolean public; a non-absolute target path
#   a failed --targets validation prints no roster lines (never half a roster)
#   --lit: a path under $HOME renders `$HOME/...`, a path outside it is unchanged,
#          `~` and `~/...` expand first; no operand -> 2 naming the flag, promptly
#   `~` expansion in a configured org_root
#   public and packages round-trip through --targets
#   --harnesses: the committed base alone (exit 0) with no file; an omitted harness
#     still reads enabled; an agent_models override survives the merge; a non-object
#     `harnesses` value -> 2 naming the key; the merge carries no org_root/targets
#     (only the `harnesses` value is merged, never the whole machine file)
#   the DEPTH case's reader leg: the engine copied to a path of a different depth,
#     AC_MACHINE_FILE at a fixture, and --targets resolving exactly the fixture's
#     targets. engine/checks/{consumer-symlinks,deployed-app-conformance}.py (née
#     lint checks 07/12, moved to sync.sh --check in W4 of the lint-system upgrade)
#     and `sync.sh --all -n` legs cannot be green here — those readers switch in
#     ac-vlje.8 and ac-vlje.5 — so they join this case at the epic's own pick.
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

# A failed validation prints NOTHING. The first target here is valid and the second is
# not: before this bead the valid one was printed before the refusal, handing half a
# roster to the installer.
printf '{"org_root": "%s/org", "targets": [{"path": "%s/org/software/app-one"}, {"path": "%s/org/software/ghost"}]}\n' \
  "$W" "$W" "$W" > "$W/partial-roster.json"
out="$(AC_MACHINE_FILE="$W/partial-roster.json" "$MACHINE" --targets 2>/dev/null)"; rc=$?
if [ "$rc" = 2 ] && [ -z "$out" ]; then
  ok "wrong: a failed --targets validation prints no roster lines"
else
  bad "partial roster: expected rc=2 and no stdout, got rc=$rc"; printf '%s\n' "$out"
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

# --- every other refusal -> 2 (type checks and absolute-path refusals) --------------------
# Each of these branches was deletable with the suite green before this bead.
printf '{"org_root": "relative/org", "targets": []}\n' > "$W/org-relative.json"
out="$(AC_MACHINE_FILE="$W/org-relative.json" "$MACHINE" --org-root 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'not an absolute path'; then
  ok "wrong: non-absolute org_root -> 2"
else
  bad "wrong org-relative: expected 2, got $rc"; printf '%s\n' "$out"
fi

printf '{"org_root": "%s/org", "targets": {}}\n' "$W" > "$W/targets-not-array.json"
out="$(AC_MACHINE_FILE="$W/targets-not-array.json" "$MACHINE" --targets 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'malformed'; then
  ok "wrong: targets not an array -> 2"
else
  bad "wrong targets-not-array: expected 2, got $rc"; printf '%s\n' "$out"
fi

printf '{"org_root": "%s/org", "targets": [{"public": true}]}\n' "$W" > "$W/target-no-path.json"
out="$(AC_MACHINE_FILE="$W/target-no-path.json" "$MACHINE" --targets 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'no path'; then
  ok "wrong: a targets[] entry with no path -> 2"
else
  bad "wrong target-no-path: expected 2, got $rc"; printf '%s\n' "$out"
fi

printf '{"org_root": "%s/org", "targets": [{"path": "%s/org/software/app-one", "packages": "x"}]}\n' \
  "$W" "$W" > "$W/target-bad-packages.json"
out="$(AC_MACHINE_FILE="$W/target-bad-packages.json" "$MACHINE" --targets 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'must be an array'; then
  ok "wrong: non-array packages -> 2"
else
  bad "wrong target-bad-packages: expected 2, got $rc"; printf '%s\n' "$out"
fi

printf '{"org_root": "%s/org", "targets": [{"path": "%s/org/software/app-one", "public": "yes"}]}\n' \
  "$W" "$W" > "$W/target-bad-public.json"
out="$(AC_MACHINE_FILE="$W/target-bad-public.json" "$MACHINE" --targets 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'must be a boolean'; then
  ok "wrong: non-boolean public -> 2"
else
  bad "wrong target-bad-public: expected 2, got $rc"; printf '%s\n' "$out"
fi

printf '{"org_root": "%s/org", "targets": [{"path": "relative/app"}]}\n' "$W" > "$W/target-relative.json"
out="$(AC_MACHINE_FILE="$W/target-relative.json" "$MACHINE" --targets 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'not absolute'; then
  ok "wrong: a non-absolute target path -> 2"
else
  bad "wrong target-relative: expected 2, got $rc"; printf '%s\n' "$out"
fi

out="$("$MACHINE" --bogus 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'unknown argument'; then
  ok "wrong: an unknown argument -> 2"
else
  bad "wrong unknown-arg: expected 2, got $rc"; printf '%s\n' "$out"
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

# No operand: exit 2 naming the flag, and PROMPTLY — before this bead the parse loop
# span forever on `shift 2` with one argument left (rc 124 under timeout).
out="$(timeout 3 "$MACHINE" --lit 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q -- '--lit'; then
  ok "lit: no operand -> 2 naming the flag"
else
  bad "lit no-operand: expected 2 naming --lit, got $rc"; printf '%s\n' "$out"
fi

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
# (engine/checks/{consumer-symlinks,deployed-app-conformance}.py — née lint checks
#  07/12 — and `sync.sh --all -n` join this case at the epic's pick — ac-vlje.8 and
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

# A `harnesses` value that is not an object must be refused naming the key, not leak jq's
# own exit 5 out of the merge.
printf '{"harnesses": []}\n' > "$W/harnesses-array.json"
out="$(AC_MACHINE_FILE="$W/harnesses-array.json" "$MACHINE" --harnesses 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'harnesses'; then
  ok "harnesses: a non-object harnesses value -> 2 naming the key"
else
  bad "harnesses non-object: expected 2 naming harnesses, got $rc"; printf '%s\n' "$out"
fi

printf '[]\n' > "$W/harnesses-file-array.json"
out="$(AC_MACHINE_FILE="$W/harnesses-file-array.json" "$MACHINE" --harnesses 2>&1)"; rc=$?
if [ "$rc" = 2 ]; then
  ok "harnesses: a non-object machine file -> 2 (never jq's exit 5)"
else
  bad "harnesses non-object file: expected 2, got $rc"; printf '%s\n' "$out"
fi

# Only the `harnesses` value is merged: org_root and targets must not reach a harness.
printf '{"org_root": "%s/org", "targets": [], "harnesses": {"droid": {"enabled": true}}}\n' \
  "$W" > "$W/harnesses-scoped.json"
out="$(AC_MACHINE_FILE="$W/harnesses-scoped.json" "$MACHINE" --harnesses 2>&1)"; rc=$?
leak="$(printf '%s' "$out" | jq -r 'has("org_root") or has("targets")' 2>/dev/null)"
if [ "$rc" = 0 ] && [ "$leak" = "false" ] && ! printf '%s' "$out" | grep -q 'org_root'; then
  ok "harnesses: the merge carries no org_root/targets"
else
  bad "harnesses leak: expected 0 with no org_root/targets, got rc=$rc leak=$leak"
fi

# --- --memory: lane/link lines, the memory key alone validated ---------------------------
printf '{"memory": {"lanes": ["~/lane-a", "/lane-b"], "link_roots": ["/wiki"]}}\n' > "$W/memory.json"
out="$(AC_MACHINE_FILE="$W/memory.json" "$MACHINE" --memory 2>&1)"; rc=$?
want="$(printf 'lane\t%s/lane-a\nlane\t/lane-b\nlink\t/wiki' "$HOME")"
if [ "$rc" = 0 ] && [ "$out" = "$want" ]; then
  ok "memory: lane and link lines, ~ expanded, existence not checked"
else
  bad "memory: expected rc 0 and the three lines, got rc=$rc"; printf '%s\n' "$out"
fi

printf '{"org_root": "/nowhere"}\n' > "$W/memory-absent.json"
out="$(AC_MACHINE_FILE="$W/memory-absent.json" "$MACHINE" --memory 2>&1)"; rc=$?
if [ "$rc" = 0 ] && [ -z "$out" ]; then
  ok "memory: absent key -> 0 and nothing printed (org_root not validated)"
else
  bad "memory absent: expected 0 and no output, got rc=$rc"; printf '%s\n' "$out"
fi

printf '{"memory": {"link_roots": "/wiki"}}\n' > "$W/memory-bad.json"
out="$(AC_MACHINE_FILE="$W/memory-bad.json" "$MACHINE" --memory 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'link_roots'; then
  ok "memory: a non-array key -> 2 naming it"
else
  bad "memory bad: expected 2 naming link_roots, got $rc"; printf '%s\n' "$out"
fi

printf '{"memory": {"lanes": ["relative/lane"]}}\n' > "$W/memory-rel.json"
out="$(AC_MACHINE_FILE="$W/memory-rel.json" "$MACHINE" --memory 2>/dev/null)"; rc=$?
if [ "$rc" = 2 ] && [ -z "$out" ]; then
  ok "memory: a relative lane -> 2 and no lines printed"
else
  bad "memory relative: expected 2 and no stdout, got rc=$rc"; printf '%s\n' "$out"
fi

rc=0; AC_MACHINE_FILE="$W/does-not-exist.json" "$MACHINE" --memory >/dev/null 2>&1 || rc=$?
if [ "$rc" = 4 ]; then ok "not-configured: --memory -> 4"; else bad "not-configured --memory: expected 4, got $rc"; fi

echo "machine.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
