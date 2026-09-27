#!/usr/bin/env bash
#
# sync-machine.test.sh — sync.sh against a machine that is NOT the layout it grew up on:
# a flat <home>/code/{agent-compounds,app} checkout, no infrastructure repo, apps that
# are public repos tracking their own .claude/settings.json. Found syncing a real app
# on 2026-09-27; every leg below was a defect on that machine.
#
#   - ORG ROOT: machine.json's org_root is the root (`machine.sh --org-root`), not the
#     engine's third parent. A present-but-wrong machine.json stops the run (exit 2).
#   - FLOOR: a missing machine-global floor SKIPS the floor-carrying steps with a WARN;
#     the run reaches "Done." instead of aborting midway through the root pass.
#   - {INFRA}: a wiring entry whose script is absent under <org>/infrastructure is
#     dropped from the rendered app hooks; present, it renders $HOME-relative.
#   - PUBLIC + TRACKED: a target machine.json marks public keeps its tracked
#     .claude/settings.json and .gitignore byte-identical; the ignore lines go to the
#     clone-local info/exclude.
#   - --no-app-hooks: a private target's settings.json gets no hooks block.
#   - OPENCODE APP SCOPE: a target that has .opencode/ gets the five stances generated
#     into .opencode/agent/; a target without one gets no .opencode/ at all.
#
# Fixture seams: AC_MACHINE_FILE (machine.sh's own), a throwaway HOME so no machine
# harness home is read or written, AC_SYNC_NO_STANCE_PROBE=1 so no live session spawns.
# AC_SYNC_UNDER_TEST overrides the sync.sh under test, as in sync-hooks.test.sh.
#
# ASSURANCE
#   PROBE:    bash engine/sync-machine.test.sh
#   SCHEDULE: scripts/run-all-proofs.sh
#   MODE:     blocking
#   ON-FAILURE: closed
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC="${AC_SYNC_UNDER_TEST:-$HERE/sync.sh}"
[ -f "$SYNC" ] || { echo "sync-machine.test.sh: $SYNC is missing"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "HARNESS FAIL: jq not on PATH"; exit 1; }

fails=0
ok()  { echo "  ok    $1"; }
bad() { echo "  FAIL  $1"; fails=$((fails + 1)); }

W="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$W"' EXIT
export HOME="$W/home"
export AC_SYNC_NO_STANCE_PROBE=1
export AC_MACHINE_FILE="$W/machine.json"
ORG="$HOME/org"
mkdir -p "$ORG"

new_repo() { # <dir>
  mkdir -p "$1"
  git init -q "$1"
  git -C "$1" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
}

# A public app shaped like the one this was found on: harness layer ignored, only
# .claude/settings.json tracked, plus an .opencode/ dir.
PUB="$HOME/code/pub-app"
new_repo "$PUB"
printf '.claude/*\n!.claude/settings.json\n.agents/\n.codex/\n.opencode/\n.factory/\n' > "$PUB/.gitignore"
mkdir -p "$PUB/.claude" "$PUB/.opencode"
printf '{\n  "skillListingBudgetFraction": 0.02\n}\n' > "$PUB/.claude/settings.json"
git -C "$PUB" add .gitignore .claude/settings.json
git -C "$PUB" -c user.email=t@example.com -c user.name=t commit -q -m base

PRIV="$HOME/code/priv-app"
new_repo "$PRIV"
mkdir -p "$PRIV/.claude"
printf '{\n  "skillListingBudgetFraction": 0.02\n}\n' > "$PRIV/.claude/settings.json"

jq -n --arg org "$ORG" --arg pub "$PUB" --arg priv "$PRIV" \
  '{org_root: $org, targets: [{path: $pub, public: true}, {path: $priv}]}' > "$AC_MACHINE_FILE"

# --- org root from machine.json; missing floor is a skipped step, not an abort -----------
out="$(bash "$SYNC" -n --root 2>&1)"; rc=$?
if printf '%s\n' "$out" | grep -qxF "== root: $ORG"; then
  ok "org root: --root works on machine.json's org_root ($ORG)"
else
  bad "org root: expected '== root: $ORG'"; printf '%s\n' "$out" | head -5
fi
if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'WARN: floor missing: .* skipped' \
   && printf '%s\n' "$out" | grep -q '^Done\.'; then
  ok "floor: missing floor WARNs and skips; the run reaches Done (rc=0)"
else
  bad "floor: expected WARN + Done + rc=0, got rc=$rc"; printf '%s\n' "$out" | tail -8
fi

# --- a present-but-wrong machine.json stops the run --------------------------------------
cp "$AC_MACHINE_FILE" "$W/machine.good.json"
printf '{"org_root": "%s/nope"}\n' "$W" > "$AC_MACHINE_FILE"
out="$(bash "$SYNC" -n --root 2>&1)"; rc=$?
if [ "$rc" = 2 ] && printf '%s\n' "$out" | grep -q 'machine.json is present but invalid'; then
  ok "org root: an invalid machine.json exits 2, never falls back to the derived root"
else
  bad "org root: invalid machine.json expected exit 2, got rc=$rc"; printf '%s\n' "$out" | tail -4
fi
cp "$W/machine.good.json" "$AC_MACHINE_FILE"

# --- public target: tracked files untouched, ignores to info/exclude, opencode stances ----
gi_before="$(cat "$PUB/.gitignore")"
st_before="$(cat "$PUB/.claude/settings.json")"
out="$(bash "$SYNC" "$PUB" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "public: real sync exits 0"
else
  bad "public: real sync expected 0, got $rc"; printf '%s\n' "$out" | grep -v '\[deploy.sh\]' | tail -15
fi
if [ "$(cat "$PUB/.claude/settings.json")" = "$st_before" ] \
   && printf '%s\n' "$out" | grep -q 'app hooks: skipped (public target'; then
  ok "public: tracked .claude/settings.json left byte-identical, skip announced"
else
  bad "public: tracked settings.json was rewritten"; cat "$PUB/.claude/settings.json"
fi
if [ "$(cat "$PUB/.gitignore")" = "$gi_before" ] && [ -z "$(git -C "$PUB" status --porcelain)" ]; then
  ok "public: tracked .gitignore unchanged and the tree is clean after sync"
else
  bad "public: tracked tree dirty after sync"; git -C "$PUB" status --porcelain
fi
exclude="$PUB/.git/info/exclude"
if grep -qxF '_scratch/' "$exclude" && grep -qxF '.compounds/' "$exclude"; then
  ok "public: _scratch/ and .compounds/ ignored via info/exclude"
else
  bad "public: info/exclude lacks _scratch/ or .compounds/"; cat "$exclude"
fi
n=0
for s in orchestrator coordinator researcher implementer validator; do
  grep -q 'generated-by: harness-sync' "$PUB/.opencode/agent/$s.md" 2>/dev/null && n=$((n + 1))
done
if [ "$n" = 5 ]; then
  ok "opencode: a target with .opencode/ gets the five stances in .opencode/agent/"
else
  bad "opencode: expected 5 generated stances in $PUB/.opencode/agent, found $n"; ls -la "$PUB/.opencode" 2>&1
fi
out="$(bash "$SYNC" --check "$PUB" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "public: --check after sync reports no drift"
else
  bad "public: --check expected 0, got $rc"; printf '%s\n' "$out" | grep -v '\[deploy.sh\]' | tail -10
fi

# --- private target, no infrastructure: {INFRA} entries dropped ---------------------------
out="$(bash "$SYNC" "$PRIV" 2>&1)"; rc=$?
hooks="$(jq -c '.hooks // empty' "$PRIV/.claude/settings.json" 2>/dev/null)"
if [ "$rc" = 0 ] && [ -n "$hooks" ] && ! printf '%s' "$hooks" | grep -q 'infrastructure\|{INFRA}'; then
  ok "infra absent: app hooks rendered with every {INFRA} entry dropped"
else
  bad "infra absent: expected hooks without infrastructure paths (rc=$rc): $hooks"
fi
if printf '%s\n' "$out" | grep -q 'NOTE: claude app hooks: {INFRA} hook(s) skipped'; then
  ok "infra absent: the drop is announced"
else
  bad "infra absent: no NOTE naming the skipped {INFRA} hooks"
fi
if [ ! -e "$PRIV/.opencode" ]; then
  ok "opencode: a target without .opencode/ gets none created"
else
  bad "opencode: .opencode/ was created in a target that had none"
fi

# --- infrastructure present: the {INFRA} entry renders, $HOME-relative ---------------------
mkdir -p "$ORG/infrastructure/tools/src/lib"
: > "$ORG/infrastructure/tools/src/lib/activity_logger.py"
bash "$SYNC" "$PRIV" >/dev/null 2>&1
want='python3 $HOME/org/infrastructure/tools/src/lib/activity_logger.py'
if jq -r '.. | .command? // empty' "$PRIV/.claude/settings.json" | grep -qxF "$want"; then
  ok "infra present: the {INFRA} entry renders as '$want'"
else
  bad "infra present: no command '$want'"; jq -r '.. | .command? // empty' "$PRIV/.claude/settings.json"
fi

# --- --no-app-hooks: a private target's settings.json keeps no hooks block -----------------
PRIV2="$HOME/code/priv-app2"
new_repo "$PRIV2"
mkdir -p "$PRIV2/.claude"
printf '{\n  "skillListingBudgetFraction": 0.02\n}\n' > "$PRIV2/.claude/settings.json"
jq --arg p "$PRIV2" '.targets += [{path: $p}]' "$AC_MACHINE_FILE" > "$W/m.json" && mv "$W/m.json" "$AC_MACHINE_FILE"
out="$(bash "$SYNC" --no-app-hooks "$PRIV2" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && [ "$(jq 'has("hooks")' "$PRIV2/.claude/settings.json")" = false ] \
   && printf '%s\n' "$out" | grep -q 'app hooks: skipped (--no-app-hooks)'; then
  ok "--no-app-hooks: settings.json gets no hooks block"
else
  bad "--no-app-hooks: expected no hooks key (rc=$rc)"; cat "$PRIV2/.claude/settings.json"
fi

echo "sync-machine.test.sh: ${fails} failure(s)"
[ "$fails" -eq 0 ]
