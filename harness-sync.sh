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
#   - Subagents: .claude/agents/*.md is canon. Codex gets GENERATED .codex/agents/
#     *.toml (symlinked TOMLs unsupported upstream); Droid gets GENERATED
#     .factory/droids/*.md. Generated files carry a "generated-by: harness-sync"
#     stamp and are only ever overwritten when stamped — hand-written files are
#     never touched. Pi has no declarative agent surface: skipped with a warning.
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

set -euo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY=0; CHECK=0; PRUNE=1; DO_ROOT=0; DO_ALL=0; TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --root)      DO_ROOT=1; shift ;;
    --all)       DO_ALL=1; DO_ROOT=1; shift ;;
    -n|--dry-run) DRY=1; shift ;;
    --check)     DRY=1; CHECK=1; shift ;;
    --no-prune)  PRUNE=0; shift ;;
    -*)          echo "unknown option: $1" >&2; exit 2 ;;
    *)           TARGETS+=("$1"); shift ;;
  esac
done
[ "$DO_ROOT" = 1 ] || [ ${#TARGETS[@]} -gt 0 ] || { echo "error: need --root, --all, or a target dir" >&2; exit 2; }

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
CODEX_SKILLS_DIR="$(cfg '.harnesses.codex.skills_mirror_dir')"
CODEX_AGENTS_DIR="$(cfg '.harnesses.codex.agents_gen_dir')"
DROID_SKILLS_DIR="$(cfg '.harnesses.droid.skills_mirror_dir')"
DROID_AGENTS_DIR="$(cfg '.harnesses.droid.agents_gen_dir')"
DROID_HOME="$(expand_tilde "$(cfg '.harnesses.droid.home')")"
DROID_FARM_SKILLS="$REPOS_ROOT/$(cfg '.harnesses.droid.tracked_farm_skills')"
DROID_FARM_DROIDS="$REPOS_ROOT/$(cfg '.harnesses.droid.tracked_farm_droids')"
PI_HOME_ENV="$(cfg '.harnesses.pi.home_env')"
PI_HOME="${!PI_HOME_ENV:-$(expand_tilde "$(cfg '.harnesses.pi.home_default')")}"

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

parse_agent() { # <file> — sets A_NAME A_DESC A_BODY
  A_NAME="$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$1")"
  A_DESC="$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$1")"
  A_BODY="$(awk '/^---[[:space:]]*$/{c++; next} c>=2{print}' "$1")"
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
    echo "  -- droid hooks (tools/droid/hooks.json -> ~/.factory/hooks.json)"
    obj="$(build_hooks_obj droid org)"
    content="$(jq -n --argjson h "$obj" '{hooks: $h}')"
    write_file_if_changed "$REPOS_ROOT/tools/droid/hooks.json" "$content"
    ensure_home_link "$DROID_HOME/hooks.json" "$REPOS_ROOT/tools/droid/hooks.json"
  fi
  if [ "$EN_PI" = "true" ]; then
    echo "  NOTE: pi hooks skipped by design (TS-extension surface only)"
  fi
  render_hooks_grok
  render_context_grok
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
# canonical payloads the other harnesses receive via hook stdout injection.
render_context_grok() {
  [ "$EN_GROK" = "true" ] || return 0
  [ -d "$GROK_HOME" ] || return 0
  echo "  -- grok global rules ($GROK_HOME/AGENTS.md, generated)"
  local ss dr content
  ss="$(cat "$AC_ROOT/hooks/session-start.md")"
  dr="$(cat "$AC_ROOT/hooks/delegation-reminder.manual-recall.md")"
  content="<!-- $STAMP — do not hand-edit (sources: hooks/session-start.md, hooks/delegation-reminder.manual-recall.md) -->

# Machine-global rules (Repos fleet)

Other harnesses receive this context via per-prompt hook injection; Grok discards
hook stdout, so this file carries the same canon statically. It applies when
working anywhere under ~/Repos.

$ss

---

$dr"
  write_generated "$GROK_HOME/AGENTS.md" "$content"
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
    echo "  -- droid MCP (tools/droid/mcp.json -> ~/.factory/mcp.json)"
    content="$(jq '{mcpServers: (.mcpServers | with_entries(.value |= (if .command then ({type:"stdio"} + .) else . end)))}' "$src")"
    write_file_if_changed "$REPOS_ROOT/tools/droid/mcp.json" "$content"
    ensure_home_link "$DROID_HOME/mcp.json" "$REPOS_ROOT/tools/droid/mcp.json"
  fi
  if [ "$EN_PI" = "true" ]; then
    echo "  NOTE: pi MCP skipped by design (no MCP support in harness)"
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

  if [ "$EN_CODEX" = "true" ] || [ "$EN_PI" = "true" ]; then
    echo "  -- codex+pi skills ($CODEX_SKILLS_DIR)"
    mirror_skills "$base/.claude/skills" "$base/$CODEX_SKILLS_DIR" "$base"
  fi
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

  if [ "$EN_CODEX" = "true" ] || [ "$EN_PI" = "true" ]; then
    echo "  -- codex+pi skills (.agents/skills mirror of .claude/skills)"
    mirror_skills "$base/.claude/skills" "$base/$CODEX_SKILLS_DIR" "$base"
  fi
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

  if [ "$EN_PI" = "true" ]; then
    if [ -d "$PI_HOME" ]; then
      echo "  -- pi home skills ($PI_HOME/skills)"
      mirror_skills "$base/.claude/skills" "$PI_HOME/skills" "$base"
      echo "  NOTE: pi has no declarative agents/hooks/MCP — skipped by design (see harnesses.json)"
    else
      echo "  WARN: pi home $PI_HOME missing — skipping (set $PI_HOME_ENV or harnesses.local.json)"
    fi
  fi

  render_hooks_root
  render_mcp_root
}

# --- run ---------------------------------------------------------------------------
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

echo "Done. changes=$CHANGES$([ "$DRY" = 1 ] && echo ' (dry-run)')"
if [ "$FAILURES" -gt 0 ]; then
  echo "ERROR: $FAILURES target(s) skipped by the public-target guard — fix their .gitignore and re-run" >&2
  exit 1
fi
if [ "$CHECK" = 1 ] && [ "$CHANGES" -gt 0 ]; then
  echo "DRIFT: projections out of sync — run harness-sync.sh to converge" >&2
  exit 1
fi
