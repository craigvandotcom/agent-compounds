#!/usr/bin/env bash
#
# sync-hooks.test.sh — the executable contract of sync.sh's three hook installers
# (install_lint_hook, install_commit_msg_hook, install_precommit_chain) against a
# real CONSUMER APP repo, outside agent-compounds.
#
# Guards: each installer resolves the hooks dir INSIDE the target repo — a
# repo-relative path used from sync's own cwd would hit agent-compounds' hooks.
#
#   - `--check` on a fresh, never-synced app repo reports DRIFT (exit 1) and
#     the hook-install lines it prints name a path INSIDE the app repo, not AC's.
#   - a real (non-dry) sync lands hooks/pre-commit (the chain runner) and
#     hooks/commit-msg as relative symlinks resolving into THIS repo's hooks/,
#     inside the APP's resolved hooks dir — honouring a custom core.hooksPath
#     (a Husky `_` dir stands in for one) exactly as a plain .git/hooks.
#   - 60-ac-lint (hooks.d/pre-commit/60-ac-lint) is installed ONLY in
#     agent-compounds itself — never in a consumer app, where hooks/pre-commit's
#     own "not the registry checkout" guard makes it dead weight.
#   - agent-compounds' OWN hooks/hooks.d/pre-commit/60-ac-lint is untouched by
#     syncing an unrelated app target.
#   - `--check` after the real sync reports no drift (exit 0).
#
# This is a slow harness (drives the full sync_target "app" path: deploy.sh's
# whole skill/agent render, both hook flavours, memory-lint) — a few seconds
# per invocation, four invocations. That cost buys end-to-end fidelity: this is
# the exact code path ac-deploy-targets.list drives against real apps.
#
# AC_SYNC_UNDER_TEST overrides the sync.sh path under test (defaults to this
# repo's own engine/sync.sh) — the fixture seam used to prove this harness was
# RED against the pre-fix script (`git show <pre-fix-rev>:engine/sync.sh` to a
# temp file, then AC_SYNC_UNDER_TEST=<that file> bash engine/sync-hooks.test.sh).
#
# ASSURANCE
#   PROBE:    bash engine/sync-hooks.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SYNC="${AC_SYNC_UNDER_TEST:-$HERE/sync.sh}"
[ -f "$SYNC" ] || { echo "sync-hooks.test.sh: $SYNC is missing"; exit 2; }

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

# A consumer "app" repo, standing well outside agent-compounds — a plain
# .git/hooks (the common case).
APP="$W/consumer-app"
mkdir -p "$APP"
git init -q "$APP"
git -C "$APP" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init

# agent-compounds' OWN hook state, captured before touching the app at all, so
# a change caused by syncing an UNRELATED target would show up as a diff here.
ac_lint_before=""
if [ -L "$ROOT/hooks/hooks.d/pre-commit/60-ac-lint" ]; then
  ac_lint_before="$(readlink "$ROOT/hooks/hooks.d/pre-commit/60-ac-lint")"
fi

# --- --check on a never-synced app: DRIFT, naming a path INSIDE the app -------------------
out="$(bash "$SYNC" --check "$APP" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'DRIFT'; then
  ok "check (pre-install): fresh app repo reports DRIFT, exit 1"
else
  bad "check (pre-install): expected DRIFT and exit 1, got rc=$rc"; printf '%s\n' "$out"
fi
if printf '%s\n' "$out" | grep -qF "$APP/.git/hooks/commit-msg ->"; then
  ok "check (pre-install): commit-msg hook line names a path INSIDE the app repo"
else
  bad "check (pre-install): no commit-msg install line naming $APP/.git/hooks/commit-msg"
  printf '%s\n' "$out"
fi
if printf '%s\n' "$out" | grep -qF "$APP/.git/hooks/pre-commit ->"; then
  ok "check (pre-install): pre-commit chain-runner line names a path INSIDE the app repo"
else
  bad "check (pre-install): no pre-commit install line naming $APP/.git/hooks/pre-commit"
  printf '%s\n' "$out"
fi
if printf '%s\n' "$out" | grep -F "$APP" | grep -q '60-ac-lint'; then
  bad "check (pre-install): 60-ac-lint was proposed for a consumer app (should never be)"
  printf '%s\n' "$out"
else
  ok "check (pre-install): 60-ac-lint not proposed for the consumer app"
fi

# --- real (non-dry) sync of the app repo ---------------------------------------------------
out="$(bash "$SYNC" "$APP" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "real sync of the app repo: exit 0"
else
  bad "real sync of the app repo: expected exit 0, got $rc"; printf '%s\n' "$out"
fi

# The chain runner and commit-msg hook must land INSIDE the app's resolved hooks dir,
# as relative symlinks resolving into THIS repo's hooks/ — not AC's own .git/hooks.
if [ -L "$APP/.git/hooks/commit-msg" ] \
   && [ "$(readlink -f "$APP/.git/hooks/commit-msg")" = "$ROOT/hooks/commit-msg" ]; then
  ok "commit-msg hook installed as a symlink into the app's OWN .git/hooks"
else
  bad "commit-msg hook missing or resolves wrong: $(readlink -f "$APP/.git/hooks/commit-msg" 2>&1)"
fi
if [ -L "$APP/.git/hooks/pre-commit" ] \
   && [ "$(readlink -f "$APP/.git/hooks/pre-commit")" = "$ROOT/hooks/pre-commit-chain" ]; then
  ok "pre-commit chain runner installed as a symlink into the app's OWN .git/hooks"
else
  bad "pre-commit chain runner missing or resolves wrong: $(readlink -f "$APP/.git/hooks/pre-commit" 2>&1)"
fi

# 60-ac-lint must NOT exist anywhere under the app's hooks dir.
if [ -e "$APP/.git/hooks/hooks.d/pre-commit/60-ac-lint" ]; then
  bad "60-ac-lint was installed in the consumer app — must never be"
else
  ok "60-ac-lint absent from the consumer app"
fi

# agent-compounds' own hooks must be untouched by syncing an unrelated target.
ac_lint_after=""
if [ -L "$ROOT/hooks/hooks.d/pre-commit/60-ac-lint" ]; then
  ac_lint_after="$(readlink "$ROOT/hooks/hooks.d/pre-commit/60-ac-lint")"
fi
if [ "$ac_lint_before" = "$ac_lint_after" ]; then
  ok "agent-compounds' own 60-ac-lint hook is untouched by syncing the app target"
else
  bad "agent-compounds' own 60-ac-lint hook CHANGED (before='$ac_lint_before' after='$ac_lint_after')"
fi

# --- --check after the real sync: no drift left -------------------------------------------
out="$(bash "$SYNC" --check "$APP" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && ! printf '%s\n' "$out" | grep -q 'DRIFT'; then
  ok "check (post-install): no drift left, exit 0"
else
  bad "check (post-install): expected exit 0 and no DRIFT, got rc=$rc"; printf '%s\n' "$out"
fi

# --- a target with a custom core.hooksPath (Husky `_`, e.g.) ------------------------------
# resolve_hooks_dir must honour it — same as a plain .git/hooks, but at that path.
HAPP="$W/husky-app"
mkdir -p "$HAPP/.husky/_"
git init -q "$HAPP"
git -C "$HAPP" config core.hooksPath .husky/_
git -C "$HAPP" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init

out="$(bash "$SYNC" "$HAPP" 2>&1)"; rc=$?
if [ "$rc" = 0 ] \
   && [ -L "$HAPP/.husky/_/commit-msg" ] \
   && [ "$(readlink -f "$HAPP/.husky/_/commit-msg")" = "$ROOT/hooks/commit-msg" ] \
   && [ -L "$HAPP/.husky/_/pre-commit" ] \
   && [ "$(readlink -f "$HAPP/.husky/_/pre-commit")" = "$ROOT/hooks/pre-commit-chain" ]; then
  ok "core.hooksPath honoured: hooks land in the app's custom hooks dir (.husky/_)"
else
  bad "core.hooksPath not honoured (rc=$rc)"; printf '%s\n' "$out"
fi
if [ -e "$HAPP/.git/hooks/commit-msg" ] || [ -e "$HAPP/.git/hooks/pre-commit" ]; then
  bad "a hook also landed in the app's PLAIN .git/hooks despite core.hooksPath"
else
  ok "nothing written to the app's plain .git/hooks when core.hooksPath is set"
fi

echo "sync-hooks.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
