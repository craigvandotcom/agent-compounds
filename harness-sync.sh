#!/usr/bin/env bash
#
# harness-sync.sh — project the canonical context stack into every harness home.
#
# Phase 1 scope (plan: _plans/2026-07-04-1500-harness-sync.md): SKILLS + SUBAGENTS.
# Identity files, hooks, and MCP are later phases. deploy.sh remains the renderer
# for the .claude/ layer; harness-sync drives it and adds the other harnesses.
#
# Model: one canon, N regenerable projections (context-engineering directives #1/#3).
#   - A target's .claude/skills is the per-target skill SET (registry symlinks +
#     target-local real skills). Other harnesses MIRROR that set as relative
#     symlinks: .agents/skills (Codex + Pi), .factory/skills (Droid).
#   - Subagents: registry agents/*.md carry only a semantic `tier:`
#     (orchestrator|coordinator|worker). deploy.sh RENDERS .claude/agents/*.md as
#     generated files with the claude model stamped in (harnesses.claude.agent_models);
#     the generators below read tier: from that layer and stamp each harness's OWN
#     resolution: Codex gets GENERATED .codex/agents/*.toml (symlinked TOMLs
#     unsupported upstream), Droid gets GENERATED .factory/droids/*.md (model:
#     inherit — no droid tier map yet), opencode gets GENERATED stances with the
#     opencode-go model stamped in. Generated files carry a "generated-by:" stamp
#     and are only ever overwritten when stamped — hand-written files are never
#     touched. Pi has no declarative agent surface: skipped with a warning.
#
# Invariants (inherited from deploy.sh):
#   idempotent · never clobber a real file · never touch foreign symlinks ·
#   prune only DANGLING symlinks that point inside managed roots · relative links ·
#   unattended-safe (no service restarts, no interactive prompts).
#
# Config: harnesses.json (committed, portable) deep-merged with
# harnesses.local.json (gitignored, machine-specific; template *.example).
# Env beats config where documented (PI_CODING_AGENT_DIR).
#
# Usage:
#   ./harness-sync.sh --root              # root repo + machine homes (~/.factory, pi home)
#   ./harness-sync.sh <app-dir>           # one app target
#   ./harness-sync.sh --all               # --root + every app in ac-deploy-targets.list
#   Options: -n/--dry-run · --check (dry-run; exit 1 if anything would change) · --no-prune
#            --verify-antigravity (sensor: did Antigravity actually LOAD what we wrote?)

set -euo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY=0; CHECK=0; PRUNE=1; DO_ROOT=0; DO_ALL=0; VERIFY_AGY=0; TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --verify-antigravity) VERIFY_AGY=1; shift ;;
    --root)      DO_ROOT=1; shift ;;
    --all)       DO_ALL=1; DO_ROOT=1; shift ;;
    -n|--dry-run) DRY=1; shift ;;
    --check)     DRY=1; CHECK=1; shift ;;
    --no-prune)  PRUNE=0; shift ;;
    -*)          echo "unknown option: $1" >&2; exit 2 ;;
    *)           TARGETS+=("$1"); shift ;;
  esac
done
[ "$DO_ROOT" = 1 ] || [ ${#TARGETS[@]} -gt 0 ] || [ "$VERIFY_AGY" = 1 ] || { echo "error: need --root, --all, a target dir, or --verify-antigravity" >&2; exit 2; }

CHANGES=0
note_change() { CHANGES=$((CHANGES + 1)); }
FAILURES=0

# --- manifest -----------------------------------------------------------------
MANIFEST="$AC_ROOT/harnesses.json"
LOCAL="$AC_ROOT/harnesses.local.json"
[ -f "$MANIFEST" ] || { echo "error: $MANIFEST missing" >&2; exit 2; }
if [ -f "$LOCAL" ]; then
  CFG="$(jq -s '.[0] * .[1]' "$MANIFEST" "$LOCAL")"
else
  CFG="$(cat "$MANIFEST")"
fi
cfg() { echo "$CFG" | jq -r "$1"; }
expand_tilde() { case "$1" in "~"|"~/"*) echo "${HOME}${1#\~}" ;; *) echo "$1" ;; esac; }

REPOS_ROOT="$(expand_tilde "$(cfg '.repos_root')")"
[ -d "$REPOS_ROOT" ] || { echo "error: repos_root $REPOS_ROOT missing" >&2; exit 2; }

EN_CLAUDE="$(cfg '.harnesses.claude.enabled')"
EN_CODEX="$(cfg '.harnesses.codex.enabled')"
EN_DROID="$(cfg '.harnesses.droid.enabled')"
EN_PI="$(cfg '.harnesses.pi.enabled')"
EN_GROK="$(cfg '.harnesses.grok.enabled // false')"
GROK_HOME="$(expand_tilde "$(cfg '.harnesses.grok.home // "~/.grok"')")"
EN_OPENCODE="$(cfg '.harnesses.opencode.enabled // false')"
OPENCODE_HOME="$(expand_tilde "$(cfg '.harnesses.opencode.home // "~/.config/opencode"')")"
CODEX_SKILLS_DIR="$(cfg '.harnesses.codex.skills_mirror_dir')"
CODEX_AGENTS_DIR="$(cfg '.harnesses.codex.agents_gen_dir')"
DROID_SKILLS_DIR="$(cfg '.harnesses.droid.skills_mirror_dir')"
DROID_AGENTS_DIR="$(cfg '.harnesses.droid.agents_gen_dir')"
DROID_HOME="$(expand_tilde "$(cfg '.harnesses.droid.home')")"
DROID_FARM_SKILLS="$REPOS_ROOT/$(cfg '.harnesses.droid.tracked_farm_skills')"
DROID_FARM_DROIDS="$REPOS_ROOT/$(cfg '.harnesses.droid.tracked_farm_droids')"
PI_HOME_ENV="$(cfg '.harnesses.pi.home_env')"
PI_HOME="${!PI_HOME_ENV:-$(expand_tilde "$(cfg '.harnesses.pi.home_default')")}"
EN_AGY="$(cfg '.harnesses.antigravity.enabled // false')"
AGY_HOME="$(expand_tilde "$(cfg '.harnesses.antigravity.home // "~/.gemini/antigravity"')")"
AGY_CONFIG_DIR="$(expand_tilde "$(cfg '.harnesses.antigravity.config_dir // "~/.gemini/config"')")"
AGY_SKILLS_DIR="$(cfg '.harnesses.antigravity.skills_mirror_dir // ".agents/skills"')"

# --- helpers --------------------------------------------------------------------
relpath() { python3 -c 'import os,sys; print(os.path.relpath(sys.argv[2], sys.argv[1]))' "$1" "$2"; }

# normalize a symlink's target (possibly relative) against its containing dir,
# without requiring it to resolve
norm_link_target() { # <link-path>
  local dir tgt
  dir="$(dirname "$1")"; tgt="$(readlink "$1")"
  python3 -c '
import os, sys
d, t = sys.argv[1], sys.argv[2]
if not os.path.isabs(t):
    t = os.path.join(d, t)
print(os.path.normpath(t))' "$dir" "$tgt"
}

# managed roots: symlinks resolving under these may be refreshed/pruned; all else untouched
is_managed() { # <normalized-path> <target-base>
  local p="$1" base="$2" r
  for r in "$AC_ROOT" "$base/.claude/skills" "$base/.claude/agents" \
           "$REPOS_ROOT/.claude/skills" "$REPOS_ROOT/.claude/agents" "$REPOS_ROOT/infrastructure"; do
    case "$p" in "$r"|"$r"/*) return 0 ;; esac
  done
  return 1
}

# link <src-abs> <dest-abs> <target-base>  — create/refresh a relative symlink
link() {
  local src="$1" dest="$2" base="$3" destdir rel
  destdir="$(dirname "$dest")"
  rel="$(relpath "$destdir" "$src")"

  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  SKIP (real file present): ${dest/#$HOME/~}"
    return
  fi
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$rel" ]; then return; fi   # already aligned
    if ! is_managed "$(norm_link_target "$dest")" "$base"; then
      echo "  SKIP (foreign symlink): ${dest/#$HOME/~} -> $(readlink "$dest")"
      return
    fi
  fi
  if [ "$DRY" = 1 ]; then
    echo "  link ${dest/#$HOME/~} -> $rel"
  else
    mkdir -p "$destdir"
    ln -sfn "$rel" "$dest"
    echo "  linked ${dest/#$HOME/~} -> $rel"
  fi
  note_change
}

# prune_dangling <dir> <target-base> — remove dangling managed symlinks
prune_dangling() {
  local dir="$1" base="$2" l
  [ "$PRUNE" = 1 ] || return 0
  [ -d "$dir" ] || return 0
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    [ -e "$l" ] && continue
    is_managed "$(norm_link_target "$l")" "$base" || continue
    if [ "$DRY" = 1 ]; then
      echo "  prune (dangling) ${l/#$HOME/~} -> $(readlink "$l")"
    else
      rm "$l"
      echo "  pruned (dangling) ${l/#$HOME/~} -> $(readlink "$l")"
    fi
    note_change
  done < <(/usr/bin/find "$dir" -maxdepth 1 -type l)
}

# mirror_skills <src-skills-dir> <dest-dir> <target-base>
# every skill in src (dir with SKILL.md, or _-prefixed shared dir) -> relative symlink in dest
mirror_skills() {
  local src="$1" dest="$2" base="$3" entry name
  [ -d "$src" ] || { echo "  WARN: skill source missing: $src"; return 0; }
  for entry in "$src"/*; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    if [ -f "$entry/SKILL.md" ] || [[ "$name" == _* && -d "$entry" ]]; then
      link "$entry" "$dest/$name" "$base"
    fi
  done
  prune_dangling "$dest" "$base"
}

# --- generated agent projections -------------------------------------------------
STAMP="generated-by: harness-sync"

parse_agent() { # <file> — sets A_NAME A_DESC A_TIER A_BODY
  A_NAME="$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$1")"
  A_DESC="$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$1")"
  A_TIER="$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^tier:/{sub(/^tier:[[:space:]]*/,""); print; exit}' "$1")"
  A_BODY="$(awk '/^---[[:space:]]*$/{c++; next} c>=2{print}' "$1")"
}

# tier_model <harness> <tier> <agent-name> — resolve a tier to a harness model id
# from the merged config. Fails loud (exit 2) on a missing entry: inheriting a
# harness default silently would flatten the tier gradient and look like success.
tier_model() {
  local m
  m="$(cfg ".harnesses.$1.agent_models.$2 // empty")"
  if [ -z "$m" ]; then
    echo "error: harnesses.$1.agent_models has no entry for tier '$2' (agent: $3) — add it to harnesses.json" >&2
    exit 2
  fi
  printf '%s' "$m"
}

# write_generated <dest> <content> — stamped-only overwrite, content-diff idempotent
write_generated() {
  local dest="$1" content="$2"
  if [ -f "$dest" ] && ! grep -q "$STAMP" "$dest"; then
    echo "  SKIP (hand-written, no stamp): ${dest/#$HOME/~}"
    return
  fi
  if [ -f "$dest" ] && [ "$(cat "$dest")" = "$content" ]; then return; fi
  if [ "$DRY" = 1 ]; then
    echo "  generate ${dest/#$HOME/~}"
  else
    mkdir -p "$(dirname "$dest")"
    printf '%s\n' "$content" > "$dest"
    echo "  generated ${dest/#$HOME/~}"
  fi
  note_change
}

gen_codex_agents() { # <src-agents-dir> <dest-dir>
  local src="$1" dest="$2" f name relsrc
  [ -d "$src" ] || return 0
  for f in "$src"/*.md; do
    [ -e "$f" ] || continue
    parse_agent "$f"
    name="${A_NAME:-$(basename "$f" .md)}"
    relsrc="${f/#$REPOS_ROOT\//}"
    write_generated "$dest/$name.toml" "$(printf '%s' \
"# $STAMP — do not hand-edit (source: $relsrc)
name = \"$name\"
description = \"$(printf '%s' "$A_DESC" | sed 's/"/\\"/g')\"
developer_instructions = \"\"\"
$A_BODY
\"\"\"")"
  done
}

gen_droid_droids() { # <src-agents-dir> <dest-dir>
  local src="$1" dest="$2" f name relsrc
  [ -d "$src" ] || return 0
  for f in "$src"/*.md; do
    [ -e "$f" ] || continue
    parse_agent "$f"
    name="${A_NAME:-$(basename "$f" .md)}"
    relsrc="${f/#$REPOS_ROOT\//}"
    write_generated "$dest/$name.md" "$(printf '%s' \
"---
name: $name
description: $A_DESC
model: inherit
---
<!-- $STAMP — do not hand-edit (source: $relsrc) -->

$A_BODY")"
  done
}

# gen_opencode_agents <src-agents-dir> <dest-dir>
# opencode reads NEITHER .claude/agents nor any Claude-compat agent path — verified
# 2026-08-28: `opencode agent list` showed only its built-ins, and
# `opencode debug agent researcher` returned "not found". So the three stances have to
# be GENERATED, the same posture as Codex TOMLs and Droid droids.
#
# Deliberately the three stances ONLY (researcher/implementer/validator, the canonical
# delegation model). The other agent defs lean on Claude-side tools/MCP that opencode
# does not carry; generating them would advertise subagents that cannot do their job —
# the phantom-registry failure mode already on record.
#
# The agent's `tier:` (from the registry, carried through the .claude layer) is
# RESOLVED here against harnesses.opencode.agent_models and stamped as `model:`.
# Since the tier map landed (2026-09) the old "omit model, inherit the default"
# posture is gone: opencode now runs a real 3-level gradient (orchestrator =
# opencode.jsonc's "model" default; coordinator/worker stamped below).
#
# `tools:` is deprecated upstream in favour of `permission:`, so write-capability is
# DERIVED from the source tools line (Write or Edit present yields edit=allow, else
# edit=deny) rather than hardcoded per agent name: add a stance and it maps itself.
gen_opencode_agents() { # <src-agents-dir> <dest-dir>
  local src="$1" dest="$2" f name relsrc tools edit_perm omodel
  [ -d "$src" ] || { echo "  WARN: agent source missing: $src"; return 0; }
  for name in researcher implementer validator; do
    f="$src/$name.md"
    [ -f "$f" ] || { echo "  WARN: stance $name.md missing in $src (skipped)"; continue; }
    parse_agent "$f"
    omodel="$(tier_model opencode "${A_TIER:-}" "$name.md")"
    relsrc="${f/#$REPOS_ROOT\//}"
    tools="$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^tools:/{print; exit}' "$f")"
    if printf '%s' "$tools" | grep -qE 'Write|Edit'; then edit_perm="allow"; else edit_perm="deny"; fi
    write_generated "$dest/$name.md" "$(printf '%s' \
"---
description: $A_DESC
mode: subagent
model: $omodel
permission:
  edit: $edit_perm
  bash: allow
  task: deny
---
<!-- $STAMP — do not hand-edit (source: $relsrc, tier: $A_TIER) -->

$A_BODY")"
  done
}

# --- hooks + MCP projections (root-level, Phase 2/3) -------------------------------
# write_file_if_changed <dest> <content> — for wholesale-projection files (wiring
# dialects declared regenerable by doctrine; unlike write_generated, no stamp gate)
write_file_if_changed() {
  local dest="$1" content="$2"
  if [ -f "$dest" ] && [ "$(cat "$dest")" = "$content" ]; then return; fi
  if [ "$DRY" = 1 ]; then
    echo "  render ${dest/#$HOME/~}"
  else
    mkdir -p "$(dirname "$dest")"
    printf '%s\n' "$content" > "$dest"
    echo "  rendered ${dest/#$HOME/~}"
  fi
  note_change
}

HOOKS_MANIFEST="$AC_ROOT/hooks/hooks.json"
# literal-$HOME path so rendered configs stay portable across machines
HOOKS_PATH_LIT='$HOME/Repos/neometa/software/agent-compounds/hooks'

# build_hooks_obj <harness> <scope> — manifest -> harness's hooks object for one
# placement scope (machine|org|app; entries default to org). The scope field on each
# wiring entry is the single source of hook placement (plan: hooks-scopes-grok Phase 3).
build_hooks_obj() {
  jq --arg h "$1" --arg s "$2" --arg hooks "$HOOKS_PATH_LIT" '
    def subst: (if type == "object" then .[$h] else . end)
      | gsub("\\{HOOKS\\}"; $hooks)
      | gsub("\\{HOME\\}"; "$HOME");
    reduce (.wiring[]
            | select((.harnesses | index($h)) and ((.scope // ["org"]) | index($s)))) as $e ({};
      .[$e.event] += [
        (if $e.matcher then {matcher: $e.matcher} else {} end)
        + {hooks: [({type: "command", command: ($e.command | subst)}
                    + (if $e.timeout then {timeout: $e.timeout} else {} end))]}
      ])' "$HOOKS_MANIFEST"
}

render_hooks_root() {
  [ -f "$HOOKS_MANIFEST" ] || { echo "  WARN: $HOOKS_MANIFEST missing — hooks skipped"; return 0; }
  local obj content settings="$REPOS_ROOT/.claude/settings.json"

  if [ "$EN_CLAUDE" = "true" ] && [ -f "$settings" ]; then
    echo "  -- claude hooks (.claude/settings.json#hooks)"
    obj="$(build_hooks_obj claude org)"
    # assignment form (not inline in the call) so a jq failure trips `set -e`
    # instead of silently writing empty content over the real settings file.
    content="$(jq --argjson h "$obj" '.hooks = $h' "$settings")"
    write_file_if_changed "$settings" "$content"
  fi
  if [ "$EN_CODEX" = "true" ]; then
    echo "  -- codex hooks (.codex/hooks.json)"
    obj="$(build_hooks_obj codex org)"
    local before=$CHANGES
    content="$(jq -n --argjson h "$obj" '{hooks: $h}')"
    write_file_if_changed "$REPOS_ROOT/.codex/hooks.json" "$content"
    [ "$CHANGES" -gt "$before" ] && [ "$DRY" = 0 ] && \
      echo "  NOTE: codex hooks.json changed — re-trust once via /hooks in the Codex TUI"
  fi
  if [ "$EN_DROID" = "true" ]; then
    echo "  -- droid hooks (infrastructure/harness-config/droid/hooks.json -> ~/.factory/hooks.json)"
    obj="$(build_hooks_obj droid org)"
    content="$(jq -n --argjson h "$obj" '{hooks: $h}')"
    write_file_if_changed "$REPOS_ROOT/infrastructure/harness-config/droid/hooks.json" "$content"
    ensure_home_link "$DROID_HOME/hooks.json" "$REPOS_ROOT/infrastructure/harness-config/droid/hooks.json"
  fi
  if [ "$EN_PI" = "true" ]; then
    echo "  NOTE: pi hooks skipped by design (TS-extension surface only)"
  fi
  render_hooks_opencode
  render_hooks_grok
  render_hooks_antigravity
  render_context_grok
  render_context_opencode
  render_context_claude_global
}

# render_context_claude_global — machine-global floor at ~/.claude/CLAUDE.md (bead
# org-29d, option a — decided 2026-07-17). Claude loads this file into EVERY session
# on the machine, including sessions launched outside ~/Repos (which otherwise get no
# context at all). Deliberately a few lines: recall stack + pointers — ~/Repos/AGENTS.md
# stays the doctrine; growing this file grows every session's context.
render_context_claude_global() {
  echo "  -- claude machine-global shim (~/.claude/CLAUDE.md, generated)"
  local body content
  body="$(cat "$AC_ROOT/hooks/machine-global-shim.md")"
  content="<!-- $STAMP — do not hand-edit (source: hooks/machine-global-shim.md) -->

$body"
  write_generated "$HOME/.claude/CLAUDE.md" "$content"
}

# render_hooks_app <target-base-dir> — app-scope stamped hooks block (plan:
# _plans/2026-07-12-harness-sync-hooks-scopes-grok.md Phase 1). The whole `hooks`
# key of <app>/.claude/settings.json is a managed projection regenerated from the
# canon; every other key (env, skillListingBudgetFraction, …) is preserved
# untouched. A malformed target file fails THIS target loudly and the run
# continues (guard_public posture) — never write over a file we cannot parse.
render_hooks_app() {
  local base="$1" settings obj content
  settings="$base/.claude/settings.json"
  [ -f "$HOOKS_MANIFEST" ] || { echo "  WARN: $HOOKS_MANIFEST missing — app hooks skipped"; return 0; }
  echo "  -- claude app hooks (.claude/settings.json#hooks, stamped block)"
  obj="$(build_hooks_obj claude app)"
  if [ -f "$settings" ]; then
    if ! content="$(jq --argjson h "$obj" '.hooks = $h' "$settings" 2>/dev/null)"; then
      echo "  ERROR: $settings is not valid JSON — app hooks block NOT rendered" >&2
      FAILURES=$((FAILURES + 1))
      return 0
    fi
  else
    content="$(jq -n --argjson h "$obj" '{hooks: $h}')"
  fi
  write_file_if_changed "$settings" "$content"
}

# render_hooks_grok — machine-scope native hooks file (plan Phase 2). Grok discards
# passive-event stdout (verified 2026-07-12, v0.2.93), so only the PreToolUse guard
# and fire-and-forget loggers are rendered; context travels via render_context_grok.
# Pairs with the REQUIRED machine setup `[compat.claude] hooks = false` in
# <grok home>/config.toml — without it these hooks double-fire via compat scanning.
render_hooks_grok() {
  [ "$EN_GROK" = "true" ] || return 0
  [ -f "$HOOKS_MANIFEST" ] || return 0
  [ -d "$GROK_HOME" ] || { echo "  WARN: grok home $GROK_HOME missing — skipping (grok not installed?)"; return 0; }
  echo "  -- grok hooks ($GROK_HOME/hooks/00-ac.json, machine scope)"
  local obj content
  obj="$(build_hooks_obj grok machine)"
  content="$(jq -n --argjson h "$obj" '{hooks: $h}')"
  write_file_if_changed "$GROK_HOME/hooks/00-ac.json" "$content"
}

# render_context_grok — Grok's context stack as a generated machine-global rules
# file (Grok loads ~/.grok/AGENTS.md in every session). Projection of the same
# canonical payloads the other harnesses receive via hook stdout injection, plus
# the memory-digest static floor (minimal pointer index; detail is pulled via the
# qmd MCP server). Digest failure degrades to a warning line, never breaks sync.
# build_machine_global_rules <why-static> — the shared static-context payload for any
# harness with no working context-injection hook (grok discards hook stdout; antigravity
# has no session-start/pre-prompt event at all). Same canon the hook-fed harnesses get.
# Sets BMGR_CONTENT. Digest failure degrades to a warning line, never breaks sync.
build_machine_global_rules() {
  local why="$1" ss dr shim digest
  ss="$(cat "$AC_ROOT/hooks/session-start.md")"
  dr="$(cat "$AC_ROOT/hooks/delegation-reminder.manual-recall.md")"
  shim="$(cat "$AC_ROOT/hooks/machine-global-shim.md")"
  if ! digest="$(python3 "$AC_ROOT/hooks/build_memory_digest.py" "$REPOS_ROOT")"; then
    echo "  WARN: memory digest generation failed — rendering rules without it"
    digest="*(digest generation failed on last sync — search qmd directly)*"
  fi
  BMGR_CONTENT="<!-- $STAMP — do not hand-edit (sources: hooks/session-start.md, hooks/machine-global-shim.md, hooks/delegation-reminder.manual-recall.md, hooks/build_memory_digest.py) -->

# Machine-global rules (Repos fleet)

$why

$ss

---

$shim

---

$dr

---

## Memory digest (pointer index — refreshed daily by infra-sync)

One line per high-value memory in the substrate. This is the FLOOR, not the
substrate: pull full detail with the qmd MCP tools (or \`qmd search\`/\`qmd query\`)
before acting on anything listed here.

$digest"
}

render_context_grok() {
  [ "$EN_GROK" = "true" ] || return 0
  [ -d "$GROK_HOME" ] || return 0
  echo "  -- grok global rules ($GROK_HOME/AGENTS.md, generated)"
  build_machine_global_rules "Other harnesses receive this context via per-prompt hook injection; Grok discards
hook stdout, so this file carries the same canon statically. It applies when
working anywhere under ~/Repos."
  write_generated "$GROK_HOME/AGENTS.md" "$BMGR_CONTENT"
}

# --- antigravity (Google Antigravity) -----------------------------------------------
# Customization model reverse-engineered from the app's language_server binary — see the
# long _doc in harnesses.json. Two roots: WORKSPACE '.agents' (already carries the skills
# mirror for codex+pi, so skills are free) and GLOBAL <home> (= ~/.gemini/antigravity).

# render_context_antigravity — global rules. Antigravity reads AGENTS.md in each
# customization root; no session-start or pre-prompt hook event exists, so context has
# to travel statically, exactly as it does for grok.
render_context_antigravity() {
  [ "$EN_AGY" = "true" ] || return 0
  [ -d "$AGY_HOME" ] || { echo "  WARN: antigravity home $AGY_HOME missing — skipping (antigravity not installed?)"; return 0; }
  echo "  -- antigravity global rules ($AGY_HOME/AGENTS.md, generated)"
  build_machine_global_rules "Antigravity exposes no session-start or pre-prompt hook event, so
this file carries statically the canon that hook-fed harnesses receive per prompt.
It applies when working anywhere under ~/Repos."
  write_generated "$AGY_HOME/AGENTS.md" "$BMGR_CONTENT"
}

# ensure_agy_workspace_rules <target-base> — the WORKSPACE customization root is
# '.agents', so Antigravity looks for '.agents/AGENTS.md', not the repo-root AGENTS.md
# that Codex/Droid/Pi read. Symlink rather than copy: one canon, zero drift.
ensure_agy_workspace_rules() {
  [ "$EN_AGY" = "true" ] || return 0
  local base="$1"
  [ -f "$base/AGENTS.md" ] || { echo "  NOTE: $base/AGENTS.md absent — antigravity workspace rules skipped"; return 0; }
  link "$base/AGENTS.md" "$base/$(dirname "$AGY_SKILLS_DIR")/AGENTS.md" "$base"
}

# render_hooks_antigravity — <home>/hooks.json carries NAMED handlers only
# (jsonhook.JSONHookSpec = {command, matcher, if, prompts}; matcher is a regex over the
# tool name; ~ expands via jsonhook.expandHome).
#
# UNVERIFIED BY CONSTRUCTION: writing this file does NOT wire the hooks up. Binding a
# named handler to an event happens in the agent/customization config
# (pre_tool_hook_names / post_tool_hook_names / stop_hook_names / *_invocation_hook_names)
# whose on-disk format we have not located, and enable_json_hooks may gate the surface
# entirely. So this renders the handlers and says plainly that they are inert until
# `--verify-antigravity` sees Antigravity's own load line. A claim without a loop is
# decoration — this one is labelled, not asserted.
render_hooks_antigravity() {
  [ "$EN_AGY" = "true" ] || return 0
  [ -f "$HOOKS_MANIFEST" ] || return 0
  [ -d "$AGY_HOME" ] || return 0
  echo "  -- antigravity hooks ($AGY_HOME/hooks.json, named handlers — UNVERIFIED, see --verify-antigravity)"
  local obj content
  # machine scope, same as grok; reshape claude-style event arrays into named handlers
  obj="$(build_hooks_obj antigravity machine)"
  content="$(printf '%s' "$obj" | jq '
    def slug: gsub("[^A-Za-z0-9]+"; "-") | ascii_downcase | sub("^-";"") | sub("-$";"");
    { hooks: (
        reduce (to_entries[] | .key as $ev | .value[] | {ev:$ev, m:(.matcher // ""), h:.hooks[]}) as $e ({};
          . + { (($e.ev + "-" + (($e.h.command | split("/") | last | split(" ") | last) // "hook")) | slug):
                ( {command: $e.h.command}
                  + (if $e.m != "" then {matcher: $e.m} else {} end) ) }) ) }')"
  write_file_if_changed "$AGY_HOME/hooks.json" "$content"
}

# gen_antigravity_agents — Antigravity HAS a subagent surface (custom_agent_spec /
# agent_script, plus the built-in `owl` orchestrator), but no on-disk format for it was
# located in the binary. Skipped LOUDLY, never silently (the Pi precedent).
gen_antigravity_agents() {
  [ "$EN_AGY" = "true" ] || return 0
  [ -d "$AGY_HOME" ] || return 0
  echo "  NOTE: antigravity subagents skipped — custom_agent_spec/agent_script exist but no on-disk format located (see harnesses.json _doc)"
}

# verify_antigravity — the FEEDBACK LOOP for everything above. Antigravity logs its own
# "Loaded hooks.json from <path>: N named hooks, M total handlers" line, so that log is
# the sensor: it reports what the app ACTUALLY read, not what we wrote. Also checks the
# CLI shim on PATH, which the Jun-2026 app update left dangling.
verify_antigravity() {
  local rc=0 logdir="$HOME/Library/Application Support/Antigravity/logs" hit
  echo "== antigravity verification"
  echo "-- what we wrote"
  for f in "$AGY_HOME/AGENTS.md" "$AGY_HOME/hooks.json" "$AGY_CONFIG_DIR/mcp_config.json"; do
    if [ -f "$f" ]; then echo "  present  ${f/#$HOME/~}"; else echo "  MISSING  ${f/#$HOME/~}"; rc=1; fi
  done
  if [ -d "$AGY_HOME/skills" ]; then
    echo "  present  ~/.gemini/antigravity/skills ($(/usr/bin/find "$AGY_HOME/skills" -maxdepth 1 -type l | wc -l | tr -d ' ') skills)"
  else echo "  MISSING  ~/.gemini/antigravity/skills"; rc=1; fi

  echo "-- what antigravity actually loaded (its own logs)"
  if [ -d "$logdir" ]; then
    # `|| true`: no match is the normal not-yet-launched case, not a script failure
    hit="$(grep -rhoE 'Loaded hooks\.json from [^:]+: [0-9]+ named hooks, [0-9]+ total handlers' "$logdir" 2>/dev/null | tail -3 || true)"
    if [ -n "$hit" ]; then printf '  %s\n' "$hit"
    else
      echo "  NO LOAD LINE FOUND — hooks.json has not been read by Antigravity."
      echo "  This is expected until Antigravity is launched at least once after a sync."
      echo "  Launch Antigravity, then re-run: harness-sync.sh --verify-antigravity"
      rc=1
    fi
  else
    echo "  no log dir at ${logdir/#$HOME/~} — launch Antigravity once, then re-run"; rc=1
  fi

  echo "-- CLI shim on PATH"
  local shim="$HOME/.antigravity/antigravity/bin/antigravity"
  if [ -e "$shim" ]; then echo "  OK       $shim resolves"
  elif [ -L "$shim" ]; then echo "  DANGLING $shim -> $(readlink "$shim")"; rc=1
  else echo "  absent   $shim"; rc=1; fi
  return $rc
}

# render_hooks_opencode — opencode has NO shell-command hook dialect; its only
# extension surface is a JS/TS plugin. Rather than fork the hook logic, we generate a
# thin wrapper plugin that shells out to the SAME scripts every other harness runs, so
# hooks/hooks.json stays the single canon (verified 2026-08-28: a plugin receives Bun's
# `$` and node:child_process, and a probe plugin blocked a bash call and injected a
# prompt part end-to-end).
#
# Two generated files, deliberately split:
#   <home>/ac-hooks.wiring.json   the DATA (regenerated from hooks.json every sync)
#   <home>/plugins/ac-hooks.js    the STATIC dispatcher (reads the wiring at load)
# The wiring lives OUTSIDE plugins/ because opencode treats every file in that dir as a
# plugin module. Splitting also keeps the JS free of generated interpolation.
#
# Event mapping (machine scope only — opencode has no org/app hook layer):
#   UserPromptSubmit  chat.message         stdout injected as an extra text part
#   PreToolUse        tool.execute.before  a throw denies the call
#   PostToolUse       tool.execute.after   fire-and-forget, never awaited
# SessionStart and SubagentStop have no opencode equivalent: SessionStart is already
# carried statically by the generated AGENTS.md, and SubagentStop is simply dropped.
render_hooks_opencode() {
  [ "$EN_OPENCODE" = "true" ] || return 0
  [ -d "$OPENCODE_HOME" ] || { echo "  WARN: opencode home $OPENCODE_HOME missing — skipping (opencode not installed?)"; return 0; }
  [ -f "$HOOKS_MANIFEST" ] || { echo "  WARN: $HOOKS_MANIFEST missing — opencode hooks skipped"; return 0; }
  echo "  -- opencode hooks (plugins/ac-hooks.js + ac-hooks.wiring.json, generated)"

  local wiring content
  wiring="$(jq --arg h opencode --arg s machine --arg hooks "$HOOKS_PATH_LIT" '
    def subst: (if type == "object" then .[$h] else . end)
      | gsub("\\{HOOKS\\}"; $hooks)
      | gsub("\\{HOME\\}"; "$HOME");
    { _doc: "generated-by: harness-sync from agent-compounds/hooks/hooks.json — do not hand-edit",
      wiring: [ .wiring[]
        | select((.harnesses | index($h)) and ((.scope // ["org"]) | index($s)))
        | { id, event, matcher: (.matcher // null), command: (.command | subst),
            timeout: (.timeout // 10) } ] }' "$HOOKS_MANIFEST")"
  write_file_if_changed "$OPENCODE_HOME/ac-hooks.wiring.json" "$wiring"

  content="$(cat <<'ACJS'
// generated-by: harness-sync — do not hand-edit
// Source of truth: agent-compounds/hooks/hooks.json (wiring) + harness-sync.sh
// (this dispatcher). Regenerate with ./harness-sync.sh --root.
//
// Wraps the canonical hook scripts for opencode, which has no shell-command hook
// dialect. Fail-open everywhere: a hook that errors, times out, or cannot spawn must
// never wedge a session — the same posture the other harnesses run.

import { spawn } from "node:child_process"
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const HERE = dirname(fileURLToPath(import.meta.url))

let WIRING = []
try {
  WIRING = JSON.parse(readFileSync(join(HERE, "..", "ac-hooks.wiring.json"), "utf8")).wiring || []
} catch (e) {
  WIRING = []
}

// opencode tool ids are lowercase; our matchers and hook scripts speak Claude names.
const TOOL_ALIAS = {
  bash: "Bash", edit: "Edit", write: "Write", read: "Read", grep: "Grep",
  glob: "Glob", list: "Glob", webfetch: "WebFetch", websearch: "WebSearch",
  task: "Task", todowrite: "TodoWrite", skill: "Skill",
}

const forEvent = (ev) => WIRING.filter((w) => w.event === ev)

function matches(entry, toolName) {
  if (!entry.matcher) return true
  try {
    return new RegExp("^(?:" + entry.matcher + ")$").test(toolName)
  } catch (e) {
    return false
  }
}

// Run one hook command with the Claude-shaped JSON payload on stdin.
function run(command, payload, timeoutMs) {
  return new Promise((resolve) => {
    let settled = false
    const done = (r) => {
      if (!settled) {
        settled = true
        resolve(r)
      }
    }
    let child
    try {
      child = spawn("bash", ["-c", command], { stdio: ["pipe", "pipe", "pipe"] })
    } catch (e) {
      return done({ code: 0, stdout: "", stderr: "" })
    }
    let out = ""
    let err = ""
    const timer = setTimeout(() => {
      try { child.kill("SIGKILL") } catch (e) {}
      done({ code: 0, stdout: "", stderr: "" })
    }, timeoutMs)
    child.stdout.on("data", (d) => { out += d.toString() })
    child.stderr.on("data", (d) => { err += d.toString() })
    child.on("error", () => { clearTimeout(timer); done({ code: 0, stdout: "", stderr: "" }) })
    child.on("close", (code) => { clearTimeout(timer); done({ code: code == null ? 0 : code, stdout: out, stderr: err }) })
    try {
      child.stdin.write(payload)
      child.stdin.end()
    } catch (e) {}
  })
}

// Our guards do NOT agree on how they signal a block, so honour both dialects:
//   exit 2 + stderr                     bead-capture-guard, skill-edit-guard
//   exit 0 + stdout hookSpecificOutput  trauma_guard (Claude dialect)
// Honouring only one of these silently fails open on the others.
function denialReason(r) {
  if (r.code === 2) return (r.stderr || "blocked by hook").trim()
  const t = (r.stdout || "").trim()
  if (t.startsWith("{")) {
    try {
      const j = JSON.parse(t)
      const h = j.hookSpecificOutput
      if (h && h.permissionDecision === "deny") return h.permissionDecisionReason || "blocked by hook"
      if (j.decision === "deny") return j.reason || "blocked by hook"
    } catch (e) {}
  }
  return null
}

export const server = async ({ directory }) => {
  const cwd = directory || process.cwd()

  return {
    // UserPromptSubmit: memory-recall + the delegation reminder. Their stdout is
    // appended as an extra text part, which is how the other harnesses inject context.
    "chat.message": async (input, output) => {
      const entries = forEvent("UserPromptSubmit")
      if (!entries.length) return
      const parts = output.parts || []
      const prompt = parts.filter((p) => p.type === "text").map((p) => p.text || "").join("\n")
      const payload = JSON.stringify({
        hook_event_name: "UserPromptSubmit",
        prompt,
        session_id: input.sessionID || "",
        cwd,
      })
      const chunks = []
      for (const e of entries) {
        const r = await run(e.command, payload, (e.timeout || 10) * 1000)
        if (r.stdout && r.stdout.trim()) chunks.push(r.stdout.trim())
      }
      if (!chunks.length) return
      const base = parts[0] || {}
      parts.push({
        ...base,
        id: (base.id || "ac") + "-achooks",
        type: "text",
        text: chunks.join("\n\n"),
      })
    },

    // PreToolUse: trauma-guard, bead-capture-guard, skill-edit-guard. A throw is
    // opencode's deny, and the message reaches the model (verified 2026-08-28).
    "tool.execute.before": async (input, output) => {
      const entries = forEvent("PreToolUse")
      if (!entries.length) return
      const name = TOOL_ALIAS[input.tool] || input.tool
      const payload = JSON.stringify({
        hook_event_name: "PreToolUse",
        tool_name: name,
        tool_input: output.args || {},
        session_id: input.sessionID || "",
        cwd,
      })
      for (const e of entries) {
        if (!matches(e, name)) continue
        const reason = denialReason(await run(e.command, payload, (e.timeout || 10) * 1000))
        if (reason) throw new Error(reason)
      }
    },

    // PostToolUse: the activity logger. Advisory — deliberately not awaited, so a slow
    // logger never delays a tool result.
    "tool.execute.after": async (input, output) => {
      const name = TOOL_ALIAS[input.tool] || input.tool
      const entries = forEvent("PostToolUse").filter((e) => matches(e, name))
      if (!entries.length) return
      const payload = JSON.stringify({
        hook_event_name: "PostToolUse",
        tool_name: name,
        tool_input: input.args || {},
        tool_response: { output: (output && output.output) || "" },
        session_id: input.sessionID || "",
        cwd,
      })
      for (const e of entries) run(e.command, payload, (e.timeout || 10) * 1000)
    },
  }
}
ACJS
)"
  write_file_if_changed "$OPENCODE_HOME/plugins/ac-hooks.js" "$content"
}

# render_context_opencode — opencode's machine-global rules floor as a generated
# ~/.config/opencode/AGENTS.md (opencode loads a home-dir AGENTS.md in every session,
# plus project AGENTS.md up the cwd tree natively). Like grok, opencode's hook surface
# is a JS/TS plugin dialect, not the shell-command context-injection the other harnesses
# run — so the same canon that reaches them via hook stdout is carried here statically.
# Skills load natively from .claude/skills (no projection). Same degrade-not-fail posture
# as render_context_grok: a memory-digest hiccup warns, never breaks the run.
render_context_opencode() {
  [ "$EN_OPENCODE" = "true" ] || return 0
  [ -d "$OPENCODE_HOME" ] || { echo "  WARN: opencode home $OPENCODE_HOME missing — skipping (opencode not installed?)"; return 0; }
  echo "  -- opencode global rules ($OPENCODE_HOME/AGENTS.md, generated)"
  local ss shim digest content
  ss="$(cat "$AC_ROOT/hooks/session-start.md")"
  shim="$(cat "$AC_ROOT/hooks/machine-global-shim.md")"
  if ! digest="$(python3 "$AC_ROOT/hooks/build_memory_digest.py" "$REPOS_ROOT")"; then
    echo "  WARN: memory digest generation failed — rendering rules without it"
    digest="*(digest generation failed on last sync — search qmd directly)*"
  fi
  content="<!-- $STAMP — do not hand-edit (sources: hooks/session-start.md, hooks/machine-global-shim.md, hooks/build_memory_digest.py) -->

# Machine-global rules (Repos fleet)

This is the machine-global floor, loaded in every opencode session. It applies when
working anywhere under ~/Repos. Project-level AGENTS.md (the doctrine L0) loads natively
from the cwd tree alongside it, and skills load natively from .claude/skills.

The per-prompt lane (memory recall + the delegation reminder) is NOT carried here: since
2026-08-28 it arrives per prompt via the generated ac-hooks plugin, the same canon the
other harnesses receive through hook stdout. Only session-start context is static.

$ss

---

$shim

---

## Memory digest (pointer index — refreshed daily by infra-sync)

One line per high-value memory in the substrate. This is the FLOOR, not the
substrate: pull full detail with the qmd MCP tools (or \`qmd search\`/\`qmd query\`)
before acting on anything listed here.

$digest"
  write_generated "$OPENCODE_HOME/AGENTS.md" "$content"
}

render_mcp_root() {
  local src="$REPOS_ROOT/.mcp.json" body content
  [ -f "$src" ] || { echo "  WARN: $src missing — MCP projection skipped"; return 0; }

  if [ "$EN_CODEX" = "true" ]; then
    echo "  -- codex MCP (.codex/config.toml [mcp_servers], generated)"
    # assignment form (not inline in the call) so a jq failure trips `set -e`
    # instead of silently generating a truncated/empty config.toml.
    body="$(jq -r '.mcpServers | to_entries[] |
  "[mcp_servers.\(.key)]"
  + (if .value.command then "\ncommand = \(.value.command | tojson)" else "" end)
  + (if .value.args then "\nargs = \(.value.args | tojson)" else "" end)
  + (if .value.url then "\nurl = \(.value.url | tojson)" else "" end)
  + (if .value.env then "\n[mcp_servers.\(.key).env]\n"
      + (.value.env | to_entries | map("\(.key) = \(.value | tojson)") | join("\n")) else "" end)
  + "\n"' "$src")"
    content="$(printf '%s\n%s' \
"# $STAMP — do not hand-edit (source: .mcp.json). Loaded only when this project is trusted in ~/.codex/config.toml." \
"$body")"
    write_generated "$REPOS_ROOT/.codex/config.toml" "$content"
  fi
  if [ "$EN_DROID" = "true" ]; then
    echo "  -- droid MCP (infrastructure/harness-config/droid/mcp.json -> ~/.factory/mcp.json)"
    content="$(jq '{mcpServers: (.mcpServers | with_entries(.value |= (if .command then ({type:"stdio"} + .) else . end)))}' "$src")"
    write_file_if_changed "$REPOS_ROOT/infrastructure/harness-config/droid/mcp.json" "$content"
    ensure_home_link "$DROID_HOME/mcp.json" "$REPOS_ROOT/infrastructure/harness-config/droid/mcp.json"
  fi
  if [ "$EN_PI" = "true" ]; then
    echo "  NOTE: pi MCP skipped by design (no MCP support in harness)"
  fi
  if [ "$EN_AGY" = "true" ]; then
    # <home>/mcp_config.json is Antigravity's OWN symlink into config_dir — render the
    # canon at the symlink's target and leave the link itself alone.
    if [ -d "$AGY_CONFIG_DIR" ]; then
      echo "  -- antigravity MCP ($AGY_CONFIG_DIR/mcp_config.json, from .mcp.json)"
      content="$(jq '{mcpServers: .mcpServers}' "$src")"
      write_file_if_changed "$AGY_CONFIG_DIR/mcp_config.json" "$content"
    else
      echo "  WARN: antigravity config dir $AGY_CONFIG_DIR missing — MCP skipped"
    fi
  fi
}

# ensure_home_link <link> <target-abs> — machine-local absolute symlink (setup.sh pattern)
ensure_home_link() {
  local dest="$1" target="$2"
  [ -d "$(dirname "$dest")" ] || { echo "  WARN: $(dirname "$dest") missing — skipping link"; return 0; }
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  SKIP (real file present): ${dest/#$HOME/~}"; return 0
  fi
  [ "$(readlink "$dest" 2>/dev/null)" = "$target" ] && return 0
  if [ "$DRY" = 1 ]; then echo "  link ${dest/#$HOME/~} -> $target";
  else ln -sfn "$target" "$dest"; echo "  linked ${dest/#$HOME/~} -> $target"; fi
  note_change
}

# --- public-target guard ------------------------------------------------------------
# A `public` flag on a target's ac-deploy-targets.list line means the repo is
# published: the harness layer must be gitignored so stamped symlinks are never
# committed (dangling links for external cloners + internal-structure leak).
# check-ignore is pure pattern matching — probe paths need not exist; they stand
# in for anything sync_target would create.
TARGETS_LIST="$REPOS_ROOT/infrastructure/ac-deploy-targets.list"

is_public_target() { # <basename>
  [ -f "$TARGETS_LIST" ] || return 1
  grep -Eq "^[[:space:]]*$1[[:space:]]+public([[:space:]]|#|$)" "$TARGETS_LIST"
}

guard_public() { # <target-base-dir> — 0 if every stamped harness path is gitignored
  local base="$1" p
  git -C "$base" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { echo "  ERROR: public target is not a git repo — cannot verify ignore rules" >&2; return 1; }
  for p in ".claude/skills/__ac_probe__" ".claude/agents/__ac_probe__.md" \
           "$CODEX_SKILLS_DIR/__ac_probe__" "$CODEX_AGENTS_DIR/__ac_probe__.toml" \
           "$DROID_SKILLS_DIR/__ac_probe__" "$DROID_AGENTS_DIR/__ac_probe__.md"; do
    git -C "$base" check-ignore -q "$p" || {
      echo "  ERROR: '$p' would be git-tracked — a public target must gitignore its harness layer" >&2
      return 1
    }
  done
}

# --- target renderers -------------------------------------------------------------
sync_target() { # <target-base-dir> ("app" mode: also runs deploy.sh for .claude layer)
  local base="$1" mode="${2:-app}" dep_extra=""
  base="$(cd "$base" && pwd)"
  echo "== $base"

  if is_public_target "$(basename "$base")"; then
    echo "  -- public target: verifying harness layer is gitignored"
    if ! guard_public "$base"; then
      echo "  SKIP target (public guard failed, nothing stamped): $base" >&2
      FAILURES=$((FAILURES + 1))
      return 0
    fi
    dep_extra="--require-ignored"
  fi

  if [ "$mode" = "app" ] && [ "$EN_CLAUDE" = "true" ]; then
    local dep_flags="$dep_extra" deploy_status
    [ "$DRY" = 1 ] && dep_flags="$dep_flags -n"
    # deploy.sh output counts as change signal only in --check via its own diff-noise;
    # it is idempotent, so re-running is always safe.
    # `|| true` guards against grep's own exit 1 when it filters out every line
    # (no real diff noise) — that is not a failure. But PIPESTATUS[0] still holds
    # deploy.sh's own exit code regardless of the trailing `|| true`, so check it
    # explicitly instead of silently discarding a genuine deploy.sh crash.
    "$AC_ROOT/deploy.sh" "$base" --all $dep_flags | sed 's/^/  [deploy.sh] /' | grep -v '^  \[deploy.sh\] $' || true
    deploy_status="${PIPESTATUS[0]}"
    [ "$deploy_status" -eq 0 ] || { echo "  ERROR: deploy.sh failed (exit $deploy_status) for $base" >&2; exit "$deploy_status"; }
    render_hooks_app "$base"
  fi

  if [ "$EN_CODEX" = "true" ] || [ "$EN_PI" = "true" ] || [ "$EN_AGY" = "true" ]; then
    echo "  -- codex+pi+antigravity skills ($CODEX_SKILLS_DIR)"
    mirror_skills "$base/.claude/skills" "$base/$CODEX_SKILLS_DIR" "$base"
  fi
  ensure_agy_workspace_rules "$base"
  if [ "$EN_CODEX" = "true" ]; then
    echo "  -- codex agents ($CODEX_AGENTS_DIR, generated)"
    gen_codex_agents "$base/.claude/agents" "$base/$CODEX_AGENTS_DIR"
  fi
  if [ "$EN_DROID" = "true" ]; then
    echo "  -- droid skills ($DROID_SKILLS_DIR) + droids ($DROID_AGENTS_DIR, generated)"
    mirror_skills "$base/.claude/skills" "$base/$DROID_SKILLS_DIR" "$base"
    gen_droid_droids "$base/.claude/agents" "$base/$DROID_AGENTS_DIR"
  fi
}

sync_root() {
  local base="$REPOS_ROOT"
  echo "== root: $base"

  if [ "$EN_CLAUDE" = "true" ]; then
    echo "  -- claude layer (deploy.sh: skills symlinks + generated agents)"
    local dep_flags="" deploy_status
    [ "$DRY" = 1 ] && dep_flags="-n"
    "$AC_ROOT/deploy.sh" "$base" --all $dep_flags | sed 's/^/  [deploy.sh] /' || true
    deploy_status="${PIPESTATUS[0]}"
    [ "$deploy_status" -eq 0 ] || { echo "  ERROR: deploy.sh failed (exit $deploy_status) for $base" >&2; exit "$deploy_status"; }
  fi

  if [ "$EN_CODEX" = "true" ] || [ "$EN_PI" = "true" ] || [ "$EN_AGY" = "true" ]; then
    echo "  -- codex+pi+antigravity skills (.agents/skills mirror of .claude/skills)"
    mirror_skills "$base/.claude/skills" "$base/$CODEX_SKILLS_DIR" "$base"
  fi
  ensure_agy_workspace_rules "$base"
  if [ "$EN_CODEX" = "true" ]; then
    echo "  -- codex agents (.codex/agents, generated)"
    gen_codex_agents "$base/.claude/agents" "$base/$CODEX_AGENTS_DIR"
  fi

  if [ "$EN_DROID" = "true" ]; then
    echo "  -- droid tracked farm ($DROID_FARM_SKILLS)"
    mirror_skills "$base/.claude/skills" "$DROID_FARM_SKILLS" "$base"
    gen_droid_droids "$base/.claude/agents" "$DROID_FARM_DROIDS"
    if [ -d "$DROID_HOME" ]; then
      echo "  -- droid home ($DROID_HOME/skills -> tracked farm)"
      if [ -e "$DROID_HOME/skills" ] && [ ! -L "$DROID_HOME/skills" ]; then
        echo "  SKIP (real dir present): $DROID_HOME/skills"
      elif [ "$(readlink "$DROID_HOME/skills" 2>/dev/null)" != "$DROID_FARM_SKILLS" ]; then
        if [ "$DRY" = 1 ]; then echo "  link ~/.factory/skills -> $DROID_FARM_SKILLS";
        else ln -sfn "$DROID_FARM_SKILLS" "$DROID_HOME/skills"; echo "  linked ~/.factory/skills -> $DROID_FARM_SKILLS"; fi
        note_change
      fi
    else
      echo "  WARN: droid home $DROID_HOME missing — skipping (droid not installed?)"
    fi
  fi

  if [ "$EN_OPENCODE" = "true" ]; then
    if [ -d "$OPENCODE_HOME" ]; then
      echo "  -- opencode agents ($OPENCODE_HOME/agents, generated: the 3 stances)"
      gen_opencode_agents "$base/.claude/agents" "$OPENCODE_HOME/agents"
    else
      echo "  WARN: opencode home $OPENCODE_HOME missing — agents skipped (opencode not installed?)"
    fi
  fi

  if [ "$EN_PI" = "true" ]; then
    if [ -d "$PI_HOME" ]; then
      echo "  -- pi home skills ($PI_HOME/skills)"
      mirror_skills "$base/.claude/skills" "$PI_HOME/skills" "$base"
      echo "  NOTE: pi has no declarative agents/hooks/MCP — skipped by design (see harnesses.json)"
    else
      echo "  WARN: pi home $PI_HOME missing — skipping (set $PI_HOME_ENV or harnesses.local.json)"
    fi
  fi

  if [ "$EN_AGY" = "true" ]; then
    if [ -d "$AGY_HOME" ]; then
      echo "  -- antigravity global skills ($AGY_HOME/skills, auto-discovered by the global root)"
      mirror_skills "$base/.claude/skills" "$AGY_HOME/skills" "$base"
      gen_antigravity_agents
    else
      echo "  WARN: antigravity home $AGY_HOME missing — skipping (antigravity not installed?)"
    fi
    render_context_antigravity
  fi

  render_hooks_root
  render_mcp_root
}

# --- run ---------------------------------------------------------------------------
if [ "$VERIFY_AGY" = 1 ] && [ "$DO_ROOT" = 0 ] && [ ${#TARGETS[@]} -eq 0 ]; then
  verify_antigravity; exit $?
fi

[ "$DO_ROOT" = 1 ] && sync_root

if [ "$DO_ALL" = 1 ]; then
  [ -f "$TARGETS_LIST" ] || { echo "error: $TARGETS_LIST missing" >&2; exit 2; }
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [ -n "$line" ] || continue
    name="${line%%[[:space:]]*}"   # first token = dir; rest = flags (e.g. `public`)
    if [ -d "$AC_ROOT/../$name" ]; then
      sync_target "$AC_ROOT/../$name" app
    else
      echo "WARN: target missing on this machine: $name"
    fi
  done < "$TARGETS_LIST"
fi

for t in ${TARGETS[@]+"${TARGETS[@]}"}; do
  [ -d "$t" ] || { echo "error: target dir missing: $t" >&2; exit 2; }
  sync_target "$t" app
done

# --- memory hygiene (hoisted from deploy.sh: substrate-global + target-invariant,
# so once per invocation, not once per target — per-target runs timed out the
# projection-regeneration check at target 2 of ~10). Visibility only, never blocks;
# the nightly drift-check run is the enforcement point.
MEMORY_LINT="$(cd "$AC_ROOT/../../.." && pwd)/infrastructure/scripts/health/memory-lint.py"
if [ -f "$MEMORY_LINT" ]; then
  echo
  ML_LOG="$(mktemp)"
  if ! /usr/bin/python3 "$MEMORY_LINT" --check > "$ML_LOG" 2>&1; then
    echo "############################################################"
    echo "# WARNING: memory hygiene drift detected (non-blocking)     #"
    echo "# nightly drift-check enforces this — see the report there  #"
    echo "############################################################"
    tail -5 "$ML_LOG"
    echo "############################################################"
  else
    echo "Memory hygiene: clean"
    tail -1 "$ML_LOG"
  fi
  rm -f "$ML_LOG"
fi

echo "Done. changes=$CHANGES$([ "$DRY" = 1 ] && echo ' (dry-run)')"
if [ "$FAILURES" -gt 0 ]; then
  echo "ERROR: $FAILURES target(s) skipped by the public-target guard — fix their .gitignore and re-run" >&2
  exit 1
fi
if [ "$CHECK" = 1 ] && [ "$CHANGES" -gt 0 ]; then
  echo "DRIFT: projections out of sync — run harness-sync.sh to converge" >&2
  exit 1
fi
