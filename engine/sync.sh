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
#   idempotent · never clobber a real file · never touch a live foreign symlink ·
#   prune DANGLING symlinks that point inside managed roots, and dangling symlinks
#   under a configured retired root (a migration leftover, not a user link) ·
#   relative links ·
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
#   ./harness-sync.sh --report            # render _reports/factory-matrix.html
#                                         # (read-only: targets x packages x harnesses)
#   Options: -n/--dry-run · --check (dry-run; exit 1 if anything would change) · --no-prune
#            --verify-antigravity (sensor: did Antigravity actually LOAD what we wrote?)

set -euo pipefail

# The engine lives in engine/; AC_ROOT stays the REPO root, one level up. Content
# (skills/, hooks/, agents/) deliberately did NOT move — 4,201 symlinks across the
# deploy targets resolve through it, and dangling links after a big move are the
# recurring failure here (ac-ys8f).
ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC_ROOT="$(cd "$ENGINE_DIR/.." && pwd)"

DRY=0; CHECK=0; PRUNE=1; DO_ROOT=0; DO_ALL=0; VERIFY_AGY=0; REPORT=0; OPENCODE_HOME_OVERRIDE=""; PRINT_OPENCODE_EDIT_PERM=0; PRINT_OPENCODE_EDIT_TOOLS=""; RECLAIM_RETIRED_DIR=""; TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --verify-antigravity) VERIFY_AGY=1; shift ;;
    --root)      DO_ROOT=1; shift ;;
    --all)       DO_ALL=1; DO_ROOT=1; shift ;;
    --report)    REPORT=1; shift ;;
    --opencode-home) OPENCODE_HOME_OVERRIDE="${2:-}"; shift 2 ;;
    --print-opencode-edit-perm)
      PRINT_OPENCODE_EDIT_PERM=1
      PRINT_OPENCODE_EDIT_TOOLS="${2-}"
      shift 2
      ;;
    --reclaim-retired-dangling)
      RECLAIM_RETIRED_DIR="${2:-}"
      shift 2
      ;;
    -n|--dry-run) DRY=1; shift ;;
    --check)     DRY=1; CHECK=1; shift ;;
    --no-prune)  PRUNE=0; shift ;;
    -*)          echo "unknown option: $1" >&2; exit 2 ;;
    *)           TARGETS+=("$1"); shift ;;
  esac
done
# A bare --check/-n means "check the engine's own render": default it to --root
# rather than erroring. Without this `sync.sh --check` exits 2 having rendered
# nothing, which reads as a failing regeneration check when nothing was checked.
if [ "$DRY" = 1 ] && [ "$DO_ROOT" = 0 ] && [ ${#TARGETS[@]} -eq 0 ] && [ "$VERIFY_AGY" = 0 ] && [ "$REPORT" = 0 ]; then
  DO_ROOT=1
fi
[ "$DO_ROOT" = 1 ] || [ ${#TARGETS[@]} -gt 0 ] || [ "$VERIFY_AGY" = 1 ] || [ "$REPORT" = 1 ] || [ "$PRINT_OPENCODE_EDIT_PERM" = 1 ] || [ -n "$RECLAIM_RETIRED_DIR" ] || { echo "error: need --root, --all, --report, a target dir, or --verify-antigravity" >&2; exit 2; }

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

# --- layout manifest (ac-9ahd) -------------------------------------------------
# The engine SELF-LOCATES rather than reading a root key. ORG_ROOT is AC_ROOT's third
# parent, which is correct in every supported layout — e.g. a repos-collection layout at
# <collection-root>/<org>/software/agent-compounds -> <collection-root>, or a split-repo
# layout at <home>/<org>/software/agent-compounds -> <home>. This was already the idiom
# below for the memory-lint path; ac-9ahd generalized it and deleted the `repos_root`
# key, which hard-failed the engine on any layout but one specific machine's and was the
# root cause of the rendered-path 404s in every deploy target.
ORG_ROOT="$(cd "$AC_ROOT/../../.." && pwd)"

# The machine-global floor: doctrine every harness loads into EVERY session on this
# machine, regardless of which of the three repos (infrastructure/mission/personal) it
# is working in. Tracked once in infrastructure/harness-config/claude/, never generated
# here — the harness projections below (Claude symlink, opencode/grok/pi static reads)
# all read it through floor_body() so there is exactly one copy to edit. A missing or
# empty floor fails the whole sync loudly rather than rendering every harness's context
# down to nothing silently.
FLOOR="$ORG_ROOT/infrastructure/harness-config/claude/CLAUDE.md"
floor_body() {
  [ -s "$FLOOR" ] || { echo "ERROR: floor missing: $FLOOR" >&2; exit 1; }
  cat "$FLOOR"
}

LAYOUT="$AC_ROOT/harness.config.json"
[ -f "$LAYOUT" ] || { echo "error: $LAYOUT missing" >&2; exit 2; }
lcfg() { jq -r "$1" "$LAYOUT"; }

# The DOMAIN repo is AC_ROOT's second parent (<domain-repo>/software/agent-compounds),
# which names itself differently per layout — hence derived, never spelled. Its basename
# is also the scope label the memory digest prints.
DOMAIN_REPO="$(cd "$AC_ROOT/../.." && pwd)"

# Resolved target dirs from the layout manifest's search globs. build_memory_digest.py
# takes these on argv rather than a root: it used to glob a hardcoded domain-repo segment
# that only existed on the Mac, so it collected nothing elsewhere while still exiting 0.
resolved_targets() {
  local g d
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    for d in $AC_ROOT/$g; do
      [ -d "$d/memory/auto" ] && (cd "$d" && pwd)
    done
  done < <(lcfg '.targets[]')
}

# A harness runs here only if the MACHINE enables it (layout manifest) AND its own detail
# config enables it (harnesses.json). Two questions, two homes: "is this harness installed
# on this box" is machine fact, "how is it wired" is harness detail. Absent from the layout
# map means yes, so adding a harness to harnesses.json does not silently disable it.
harness_on() { # <name> <detail-enabled>
  local m; m="$(jq -r --arg h "$1" '.harnesses[$h] // true' "$LAYOUT")"
  if [ "$m" = "false" ] || [ "$2" != "true" ]; then echo false; else echo true; fi
}
EN_CLAUDE="$(harness_on claude "$(cfg '.harnesses.claude.enabled')")"
EN_CODEX="$(harness_on codex "$(cfg '.harnesses.codex.enabled')")"
EN_DROID="$(harness_on droid "$(cfg '.harnesses.droid.enabled')")"
EN_PI="$(harness_on pi "$(cfg '.harnesses.pi.enabled')")"
EN_GROK="$(harness_on grok "$(cfg '.harnesses.grok.enabled // false')")"
GROK_HOME="$(expand_tilde "$(cfg '.harnesses.grok.home // "~/.grok"')")"
EN_OPENCODE="$(harness_on opencode "$(cfg '.harnesses.opencode.enabled // false')")"
OPENCODE_HOME="$(expand_tilde "$(cfg '.harnesses.opencode.home // "~/.config/opencode"')")"
[ -n "$OPENCODE_HOME_OVERRIDE" ] && OPENCODE_HOME="$OPENCODE_HOME_OVERRIDE"
CODEX_SKILLS_DIR="$(cfg '.harnesses.codex.skills_mirror_dir')"
CODEX_AGENTS_DIR="$(cfg '.harnesses.codex.agents_gen_dir')"
DROID_SKILLS_DIR="$(cfg '.harnesses.droid.skills_mirror_dir')"
DROID_AGENTS_DIR="$(cfg '.harnesses.droid.agents_gen_dir')"
DROID_HOME="$(expand_tilde "$(cfg '.harnesses.droid.home')")"
DROID_FARM_SKILLS="$ORG_ROOT/$(cfg '.harnesses.droid.tracked_farm_skills')"
DROID_FARM_DROIDS="$ORG_ROOT/$(cfg '.harnesses.droid.tracked_farm_droids')"
PI_HOME_ENV="$(cfg '.harnesses.pi.home_env')"
PI_HOME="${!PI_HOME_ENV:-$(expand_tilde "$(cfg '.harnesses.pi.home_default')")}"
EN_AGY="$(harness_on antigravity "$(cfg '.harnesses.antigravity.enabled // false')")"
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
           "$ORG_ROOT/.claude/skills" "$ORG_ROOT/.claude/agents" "$ORG_ROOT/infrastructure"; do
    case "$p" in "$r"|"$r"/*) return 0 ;; esac
  done
  return 1
}

# Retired canons. A dangling symlink under one is a migration leftover, never a
# deliberate user link. A live link under the same prefix stays foreign.
# RETIRED_ROOTS (colon-separated) wins, so a test can name a fixture root.
# Otherwise the merged manifest's retired_roots array — a machine records a canon
# it migrated off in harnesses.local.json, not in this file (a spelled home path
# here is the layout bug check 37 exists to catch). The historical Mac canon was
# ~/Repos/.claude.
retired_roots() {
  local p
  if [ -n "${RETIRED_ROOTS:-}" ]; then
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      expand_tilde "$p"
    done <<EOF
$(printf '%s\n' "$RETIRED_ROOTS" | tr ':' '\n')
EOF
    return
  fi
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    expand_tilde "$p"
  done < <(echo "$CFG" | jq -r '.retired_roots // [] | .[]')
}

is_retired_root() { # <normalized-path>
  local p="$1" r
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    case "$p" in "$r"|"$r"/*) return 0 ;; esac
  done < <(retired_roots)
  return 1
}

# link <src-abs> <dest-abs> <target-base>  — create/refresh a relative symlink
link() {
  local src="$1" dest="$2" base="$3" destdir rel tgt
  destdir="$(dirname "$dest")"
  rel="$(relpath "$destdir" "$src")"

  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  SKIP (real file present): ${dest/#$HOME/~}"
    return
  fi
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$rel" ]; then return; fi   # already aligned
    tgt="$(norm_link_target "$dest")"
    # Live foreign links stay. A dangling link into a retired canon is replaced.
    if ! is_managed "$tgt" "$base"; then
      if [ -e "$dest" ] || ! is_retired_root "$tgt"; then
        echo "  SKIP (foreign symlink): ${dest/#$HOME/~} -> $(readlink "$dest")"
        return
      fi
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
  local dir="$1" base="$2" l tgt
  [ "$PRUNE" = 1 ] || return 0
  [ -d "$dir" ] || return 0
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    [ -e "$l" ] && continue
    tgt="$(norm_link_target "$l")"
    if ! is_managed "$tgt" "$base"; then
      is_retired_root "$tgt" || continue
    fi
    if [ "$DRY" = 1 ]; then
      echo "  prune (dangling) ${l/#$HOME/~} -> $(readlink "$l")"
    else
      rm "$l"
      echo "  pruned (dangling) ${l/#$HOME/~} -> $(readlink "$l")"
    fi
    note_change
  done < <(/usr/bin/find "$dir" -maxdepth 1 -type l)
}

# Query path for engine/retired-root.test.sh: prune one directory and stop
# before any projection. The directory is seeded by the caller.
if [ -n "$RECLAIM_RETIRED_DIR" ]; then
  [ -d "$RECLAIM_RETIRED_DIR" ] || { echo "error: not a directory: $RECLAIM_RETIRED_DIR" >&2; exit 2; }
  DRY=0
  PRUNE=1
  prune_dangling "$RECLAIM_RETIRED_DIR" "$(dirname "$RECLAIM_RETIRED_DIR")"
  exit 0
fi

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

# tier_model <harness> <tier> <agent-name> — resolve an agent to a harness model id
# from the merged config: the agent's own override key first (agent_models.validator
# style — a quality gate must never run on the same weights that built what it gates),
# then its tier, then fail loud (exit 2): inheriting a harness default silently would
# flatten the gradient and look like success.
tier_model() {
  local m
  m="$(cfg ".harnesses.$1.agent_models.\"$3\" // .harnesses.$1.agent_models.$2 // empty")"
  if [ -z "$m" ]; then
    echo "error: harnesses.$1.agent_models has no entry for agent '$3' (tier '$2') — add it to harnesses.json" >&2
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

# prune_orphan_projections <src-agents-dir> <dest-dir> — delete STAMPED generated
# agent projections whose source agent no longer exists. Deleting a registry agent
# otherwise strands its projection in every harness home — a phantom subagent the
# harness still offers (the exact failure mode 25-archived-names' RETIRED_NAMES
# leg guards in the registry, mirrored here at every projection boundary).
# Unstamped (hand-written) files are never touched.
prune_orphan_projections() { # <src-agents-dir> <dest-dir>
  local src="$1" dest="$2" g name
  [ -d "$dest" ] || return 0
  for g in "$dest"/*; do
    [ -e "$g" ] || continue
    grep -q "$STAMP" "$g" 2>/dev/null || continue   # hand-written files are never touched
    name="$(basename "$g")"; name="${name%.*}"
    [ -f "$src/$name.md" ] && continue
    if [ "$DRY" = 1 ]; then
      echo "  prune (orphan projection) ${g/#$HOME/~}"
    else
      rm "$g"
      echo "  pruned (orphan projection) ${g/#$HOME/~}"
    fi
    note_change
  done
}

gen_codex_agents() { # <src-agents-dir> <dest-dir>
  local src="$1" dest="$2" f name relsrc
  [ -d "$src" ] || return 0
  for f in "$src"/*.md; do
    [ -e "$f" ] || continue
    parse_agent "$f"
    name="${A_NAME:-$(basename "$f" .md)}"
    relsrc="${f/#$ORG_ROOT\//}"
    write_generated "$dest/$name.toml" "$(printf '%s' \
"# $STAMP — do not hand-edit (source: $relsrc)
name = \"$name\"
description = \"$(printf '%s' "$A_DESC" | sed 's/"/\\"/g')\"
developer_instructions = \"\"\"
$A_BODY
\"\"\"")"
  done
  prune_orphan_projections "$src" "$dest"
}

gen_droid_droids() { # <src-agents-dir> <dest-dir>
  local src="$1" dest="$2" f name relsrc
  [ -d "$src" ] || return 0
  for f in "$src"/*.md; do
    [ -e "$f" ] || continue
    parse_agent "$f"
    name="${A_NAME:-$(basename "$f" .md)}"
    relsrc="${f/#$ORG_ROOT\//}"
    write_generated "$dest/$name.md" "$(printf '%s' \
"---
name: $name
description: $A_DESC
model: inherit
---
<!-- $STAMP — do not hand-edit (source: $relsrc) -->

$A_BODY")"
  done
  prune_orphan_projections "$src" "$dest"
}

# gen_opencode_agents <src-agents-dir> <dest-dir>
# opencode reads NEITHER .claude/agents nor any Claude-compat agent path — verified
# 2026-08-28: `opencode agent list` showed only its built-ins, and
# `opencode debug agent researcher` returned "not found". So the stances have to
# be GENERATED, the same posture as Codex TOMLs and Droid droids.
#
# Deliberately the FIVE core stances ONLY (orchestrator/coordinator/researcher/
# implementer/validator, the canonical delegation model). The other agent defs lean
# on Claude-side tools/MCP that opencode does not carry; generating them would
# advertise subagents that cannot do their job — the phantom-registry failure mode
# already on record.
#
# The agent's `tier:` (from the registry, carried through the .claude layer) is
# RESOLVED here against harnesses.opencode.agent_models and stamped as `model:`.
# Since the tier map landed (2026-09) the old "omit model, inherit the default"
# posture is gone: opencode now runs a real 3-level gradient (orchestrator =
# opencode.jsonc's "model" default; coordinator/worker stamped below).
#
# `tools:` is deprecated upstream in favour of `permission:`. OpenCode's edit
# key covers the write, edit, and patch tools together — it does not separate
# creating a file from changing one — and its path rules expand only ~ and
# $HOME, not $TMPDIR or $CLAUDE_JOB_DIR (https://opencode.ai/docs/permissions).
# A Write-without-Edit stance (validator: report and scratch only, never the
# reviewed tree) therefore cannot be projected as "allow scratch, deny the
# tree". Decision (ac-oqfe): edit=allow only when the source tools line lists
# Edit as its own tool. Write alone is edit=deny, which holds the read-only
# contract on those tools. The report then leaves through bash (already
# allow), bounded by the stance text to tests and scratch — the same prose
# bound Claude uses, because OpenCode cannot name the scratch path. Add a
# stance and it still maps itself; the mapping is this decision, not an
# alternation that treats Write and Edit as the same grant.
# opencode_edit_perm <tools-line> — prints allow or deny.
opencode_edit_perm() {
  if printf '%s' "$1" | grep -qE '(^|[^A-Za-z0-9_])Edit([^A-Za-z0-9_]|$)'; then
    printf '%s\n' allow
  else
    printf '%s\n' deny
  fi
}
# Query path for scripts/opencode-edit-perm.test.sh: print the decision and
# stop before any projection. The tools line is the argument, which may be empty.
if [ "$PRINT_OPENCODE_EDIT_PERM" = 1 ]; then
  opencode_edit_perm "$PRINT_OPENCODE_EDIT_TOOLS"
  exit 0
fi
gen_opencode_agents() { # <src-agents-dir> <dest-dir>
  local src="$1" dest="$2" f name relsrc tools edit_perm omodel
  [ -d "$src" ] || { echo "  WARN: agent source missing: $src"; return 0; }
  for name in orchestrator coordinator researcher implementer validator; do
    f="$src/$name.md"
    [ -f "$f" ] || { echo "  WARN: stance $name.md missing in $src (skipped)"; continue; }
    parse_agent "$f"
    omodel="$(tier_model opencode "${A_TIER:-}" "$name")"
    relsrc="${f/#$ORG_ROOT\//}"
    tools="$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^tools:/{print; exit}' "$f")"
    # ac-oqfe: Edit listed -> allow; Write without Edit -> deny (opencode_edit_perm).
    edit_perm="$(opencode_edit_perm "$tools")"
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
  prune_orphan_projections "$src" "$dest"
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

HOOKS_MANIFEST="$ENGINE_DIR/hooks.wiring.json"
# Literal-$HOME path so rendered configs stay portable: the consuming harness expands
# $HOME itself, so one rendered file works for any user. DERIVED from AC_ROOT rather
# than hardcoded — the old constant named the Mac's monorepo path, so on every other
# layout the rendered UserPromptSubmit entry pointed at a file that does not exist and
# the recall hook 404'd on EVERY prompt in EVERY deploy target (measured: 7 targets,
# 31 drift failures, ac-vh7k's baseline receipt). Keep the $HOME prefix unexpanded.
HOOKS_PATH_LIT='$HOME'"${AC_ROOT#$HOME}/hooks"
# Same treatment for the infrastructure repo: {INFRA} in the wiring manifest. Those
# commands used to spell the Mac's monorepo path inline, so every rendered guard and
# logger pointed at a file that does not exist off that machine — the PostToolUse
# activity logger failed on EVERY tool call here until this landed.
INFRA_PATH_LIT='$HOME'"${ORG_ROOT#$HOME}/infrastructure"

# ONE definition of the placeholder substitution, shared by both renderers below.
# It lived twice — build_hooks_obj and the opencode wiring render — and the copies
# drifted the moment {INFRA} was added to one: the opencode render emitted a literal
# "{INFRA}/hooks/am-edit-guard.py" and its own assert caught it. Constitution
# Invariant 5, one engine per pattern.
SUBST_JQ='def subst: (if type == "object" then .[$h] else . end)
      | gsub("\\{HOOKS\\}"; $hooks)
      | gsub("\\{INFRA\\}"; $infra)
      | gsub("\\{HOME\\}"; "$HOME");'

# build_hooks_obj <harness> <scope> — manifest -> harness's hooks object for one
# placement scope (machine|org|app; entries default to org). The scope field on each
# wiring entry is the single source of hook placement (plan: hooks-scopes-grok Phase 3).
build_hooks_obj() {
  jq --arg h "$1" --arg s "$2" --arg hooks "$HOOKS_PATH_LIT" --arg infra "$INFRA_PATH_LIT" "$SUBST_JQ"'
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
  local obj content settings="$ORG_ROOT/.claude/settings.json"

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
    write_file_if_changed "$ORG_ROOT/.codex/hooks.json" "$content"
    [ "$CHANGES" -gt "$before" ] && [ "$DRY" = 0 ] && \
      echo "  NOTE: codex hooks.json changed — re-trust once via /hooks in the Codex TUI"
  fi
  if [ "$EN_DROID" = "true" ]; then
    echo "  -- droid hooks (infrastructure/harness-config/droid/hooks.json -> ~/.factory/hooks.json)"
    obj="$(build_hooks_obj droid org)"
    content="$(jq -n --argjson h "$obj" '{hooks: $h}')"
    write_file_if_changed "$ORG_ROOT/infrastructure/harness-config/droid/hooks.json" "$content"
    ensure_home_link "$DROID_HOME/hooks.json" "$ORG_ROOT/infrastructure/harness-config/droid/hooks.json"
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
# org-29d, option a — decided 2026-07-17; superseded 2026-09: the floor moved to
# infrastructure/harness-config/claude/CLAUDE.md as the single tracked copy read by
# every harness, so this is now a SYMLINK, not a generated projection). Claude loads
# this file into EVERY session on the machine, including sessions launched outside
# any of the three repos. A stale copy generated by an older version of this function
# (recognised by the write_generated stamp on its first line) is removed so the link
# can take its place; a real hand-written file is left alone with a loud SKIP — never
# clobbered.
render_context_claude_global() {
  echo "  -- claude machine-global floor (~/.claude/CLAUDE.md -> symlink to \$FLOOR)"
  local dest="$HOME/.claude/CLAUDE.md"
  if [ -f "$dest" ] && [ ! -L "$dest" ]; then
    if head -1 "$dest" 2>/dev/null | grep -q "$STAMP"; then
      if [ "$DRY" = 1 ]; then
        echo "  would remove stale generated file, then link: ${dest/#$HOME/~} -> $FLOOR"
        note_change
        return 0
      fi
      rm -f "$dest"
      echo "  removed stale generated file: ${dest/#$HOME/~}"
    else
      echo "  SKIP (hand-written, no stamp): ${dest/#$HOME/~}"
      return 0
    fi
  fi
  ensure_home_link "$dest" "$FLOOR"
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
  local why="$1" dr digest
  dr="$(cat "$AC_ROOT/hooks/delegation-reminder.manual-recall.md")"
  if ! digest="$(python3 "$AC_ROOT/hooks/build_memory_digest.py" "$DOMAIN_REPO" $(resolved_targets))"; then
    echo "  WARN: memory digest generation failed — rendering rules without it"
    digest="*(digest generation failed on last sync — search qmd directly)*"
  fi
  BMGR_CONTENT="<!-- $STAMP — do not hand-edit (sources: infrastructure/harness-config/claude/CLAUDE.md, hooks/delegation-reminder.manual-recall.md, hooks/build_memory_digest.py) -->

# Machine-global rules

$why

$(floor_body)

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
working anywhere in the workspace repos."
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
It applies when working anywhere in the workspace repos."
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

# render_hooks_antigravity — <config_dir>/hooks.json (GLOBAL customization root) carries
# NAMED hooks bound to EVENTS. VERIFIED 2026-09-07 (ac-antigravity-close-hook-loop-j6xw):
# the on-disk format is Antigravity's own hooks contract — hooks.json lives in a
# customization root (~/.gemini/config/ globally, or <workspace>/.agents/ per project);
# each TOP-LEVEL key is a hook NAME mapping to per-EVENT arrays: PreToolUse/PostToolUse
# are GROUPED ({matcher: <regex over tool name>, hooks: [{type: command, command, timeout}]}),
# PreInvocation/PostInvocation/Stop are FLAT handler lists; `enabled: false` disables.
# Source: the embedded hooks guide (language_server strings + builtin skill
# agy-customizations/docs/hooks.md), CONFIRMED empirically: a hooks.json in this exact
# shape at ~/.gemini/config/hooks.json produced the app's own load line
# "loaded 1 named hooks from 1 hooks.json file(s)" (hooks_manager.go) on the next CLI
# session. Matcher target is the AGENT's tool name (snake_case: run_command,
# view_file, browser_*); our manifest's matchers name Claude tool names, so a
# Claude-shaped matcher can never fire here — wired with the declared matchers and
# flagged in the comment; payload shape (camelCase protojson) is a guard-compat
# follow-up. The load line is the sensor: `--verify-antigravity`.
render_hooks_antigravity() {
  [ "$EN_AGY" = "true" ] || return 0
  [ -f "$HOOKS_MANIFEST" ] || return 0
  [ -d "$AGY_CONFIG_DIR" ] || return 0
  echo "  -- antigravity hooks ($AGY_CONFIG_DIR/hooks.json, named hooks bound to events — VERIFIED format, see --verify-antigravity)"
  local obj content
  # machine scope, same as grok; reshape claude-style event arrays into the named-hook
  # format: one named hook per event entry, grouped matcher wrapper for *ToolUse events.
  obj="$(build_hooks_obj antigravity machine)"
  content="$(printf '%s' "$obj" | jq '
    def slug: gsub("[^A-Za-z0-9]+"; "-") | ascii_downcase | sub("^-";"") | sub("-$";"");
    def grouped: (. == "PreToolUse") or (. == "PostToolUse");
    reduce (to_entries[] | .key as $ev | .value[] | {ev:$ev, m:(.matcher // ""), h:.hooks}) as $e ({};
      . + { (("ac-" + ($e.ev | ascii_downcase) + "-" + (($e.h[0].command | split("/") | last | split(" ") | last) // "hook")) | slug):
              { ($e.ev): (if ($e.ev | grouped)
                          then [ {matcher: (if $e.m == "" then "*" else $e.m end), hooks: $e.h} ]
                          else $e.h end) } })')"
  write_file_if_changed "$AGY_CONFIG_DIR/hooks.json" "$content"
}

# gen_antigravity_agents — DERIVED FACT (ac-antigravity-close-hook-loop-j6xw, 2026-09-07):
# there is NO on-disk subagent-definition format for this build. The customization system
# documents exactly five types — Rules, Skills, Plugins, Hooks, MCP (the binary's embedded
# guide + the builtin agy-customizations skill); `agents.json`/`agent.json` names in the
# binary are registration/path manifests, not agent definitions; `agent.md` is a
# RUNTIME-SAVED agent script (SaveAgentScriptCommandSpec RPC), never a discovery-mounted
# definition; markdown agents are gated behind the enable-markdown-agents experiment and
# "JSON agents are not allowed". So there is nothing to render: a written subagent config
# cannot be made live because the product reads none from disk. Stated, not skipped —
# this is an answered question, not an unverified guess.
gen_antigravity_agents() {
  [ "$EN_AGY" = "true" ] || return 0
  [ -d "$AGY_HOME" ] || return 0
  echo "  NOTE: antigravity subagents — no on-disk definition format exists in this build (customizations = rules/skills/plugins/hooks/mcp only; agent scripts are runtime-saved; markdown agents experiment-gated). Nothing to render."
}

# verify_antigravity — the FEEDBACK LOOP for everything above. Antigravity's hooks manager
# logs its own "loaded N named hooks from M hooks.json file(s)" line (hooks_manager.go) at
# session start — in the IDE's ~/Library/Logs/Antigravity/*.log and the CLI's
# ~/.gemini/antigravity-cli/cli.log — so those logs are the sensor: they report what the
# app ACTUALLY read, not what we wrote. The load fires at SESSION start (a conversation),
# never at server boot — a bare app launch with no session verifies nothing. Also checks
# the CLI shim on PATH, which the Jun-2026 app update left dangling.
verify_antigravity() {
  local rc=0 hit
  local ide_logdir="$HOME/Library/Logs/Antigravity"
  local session_logdir="$HOME/Library/Application Support/Antigravity/logs"
  local cli_log="$HOME/.gemini/antigravity-cli/cli.log"
  echo "== antigravity verification"
  echo "-- what we wrote"
  for f in "$AGY_HOME/AGENTS.md" "$AGY_CONFIG_DIR/hooks.json" "$AGY_CONFIG_DIR/mcp_config.json"; do
    if [ -f "$f" ]; then echo "  present  ${f/#$HOME/~}"; else echo "  MISSING  ${f/#$HOME/~}"; rc=1; fi
  done
  if [ -d "$AGY_HOME/skills" ]; then
    echo "  present  ~/.gemini/antigravity/skills ($(/usr/bin/find "$AGY_HOME/skills" -maxdepth 1 -type l | wc -l | tr -d ' ') skills)"
  else echo "  MISSING  ~/.gemini/antigravity/skills"; rc=1; fi

  echo "-- what antigravity actually loaded (its own logs)"
  # `|| true`: no match is the normal not-yet-launched case, not a script failure
  hit="$(grep -rhoE 'loaded [0-9]+ named hooks from [0-9]+ hooks\.json file\(s\)' \
          "$ide_logdir" "$session_logdir" 2>/dev/null | tail -3 || true)"
  if [ -n "$hit" ]; then printf '  %s\n' "$hit"
  elif [ -f "$cli_log" ]; then
    hit="$(grep -oE 'loaded [0-9]+ named hooks from [0-9]+ hooks\.json file\(s\)' "$cli_log" 2>/dev/null | tail -3 || true)"
    if [ -n "$hit" ]; then printf '  %s\n' "$hit"; fi
  fi
  if [ -z "$hit" ]; then
    echo "  NO LOAD LINE FOUND — hooks.json has not been read by an Antigravity session yet."
    echo "  The hooks manager loads at SESSION start, never at server boot: run one CLI"
    echo "  conversation (agy -p '...' works headless) or open a workspace in the IDE,"
    echo "  then re-run: engine/sync.sh --verify-antigravity"
    rc=1
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
# engine/hooks.wiring.json stays the single canon (verified 2026-08-28: a plugin receives Bun's
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
  wiring="$(jq --arg h opencode --arg s machine --arg hooks "$HOOKS_PATH_LIT" --arg infra "$INFRA_PATH_LIT" "$SUBST_JQ"'
    { _doc: "generated-by: engine/sync.sh from agent-compounds/engine/hooks.wiring.json — do not hand-edit",
      wiring: [ .wiring[]
        | select((.harnesses | index($h)) and ((.scope // ["org"]) | index($s)))
        | { id, event, matcher: (.matcher // null), command: (.command | subst),
            timeout: (.timeout // 10) } ] }' "$HOOKS_MANIFEST")"

  # THE RENDER ASSERTS WHAT IT WROTE (ac-heyt.12). Three checks, any mismatch aborts the
  # sync naming it: the wiring parses; its entry count equals the manifest's opencode-
  # AND-machine entries (both conjuncts — the render's own filter); and every rendered
  # command path exists on disk after {HOOKS}/{HOME} substitution — the assumption the
  # manifest rests on that nothing else ever asserts.
  if ! printf '%s' "$wiring" | jq -e . >/dev/null 2>&1; then
    echo "  FAIL: rendered opencode wiring does not parse — the render is broken; fix engine/sync.sh" >&2
    exit 1
  fi
  local expect_count got_count
  expect_count="$(jq --arg h opencode --arg s machine '[.wiring[] | select((.harnesses | index($h)) and ((.scope // ["org"]) | index($s)))] | length' "$HOOKS_MANIFEST")"
  got_count="$(printf '%s' "$wiring" | jq '.wiring | length')"
  if [ "$got_count" != "$expect_count" ]; then
    echo "  FAIL: rendered opencode wiring entry count $got_count != manifest opencode+machine count $expect_count — the render's filter drifted from the manifest" >&2
    exit 1
  fi
  if ! printf '%s' "$wiring" | jq -r '.wiring[].command' | while IFS= read -r cmd; do
    for tok in $cmd; do
      case "$tok" in
        *=*) continue ;;
        */bin/*|python3|python|bash|sh|node|cat) continue ;;
        */*)
          p="${tok//\$HOME/$HOME}"
          if [ ! -e "$p" ]; then echo "  FAIL: rendered command path missing: $p (from: $cmd)" >&2; exit 1; fi
          ;;
      esac
    done
  done; then
    exit 1
  fi

  write_file_if_changed "$OPENCODE_HOME/ac-hooks.wiring.json" "$wiring"
  if [ "$DRY" = 0 ] && ! jq -e . "$OPENCODE_HOME/ac-hooks.wiring.json" >/dev/null 2>&1; then
    echo "  FAIL: written $OPENCODE_HOME/ac-hooks.wiring.json does not parse — the file on disk disagrees with the render" >&2
    exit 1
  fi

  content="$(cat <<'ACJS'
// generated-by: harness-sync — do not hand-edit
// Source of truth: agent-compounds/engine/hooks.wiring.json (wiring) + engine/sync.sh
// (this dispatcher). Regenerate with ./engine/sync.sh --root.
//
// Wraps the canonical hook scripts for opencode, which has no shell-command hook
// dialect. FAIL-CLOSED on an unreadable wiring (ac-heyt.12, decision D-1): a missing,
// renamed or unparseable wiring file means the ENTIRE hook layer is gone — that is
// not a guard failing open, that is the guard disappearing, so every tool call is
// denied with the repair message instead of running unguarded. Individual hook
// failures (a script that errors, times out, or cannot spawn) still fail open —
// fail-closed is for the disappearance of the layer, never for one hook's hiccup.

import { spawn } from "node:child_process"
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const HERE = dirname(fileURLToPath(import.meta.url))
const WIRING_PATH = join(HERE, "..", "ac-hooks.wiring.json")

let WIRING = []
let WIRING_ERROR = null
try {
  WIRING = JSON.parse(readFileSync(WIRING_PATH, "utf8")).wiring || []
} catch (e) {
  WIRING_ERROR = "ac-hooks: wiring unreadable at " + WIRING_PATH + " — run engine/sync.sh"
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
//   exit 0 + stdout hookSpecificOutput  dcg (third-party, machine scope)
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

export const server = async ({ directory, client }) => {
  const cwd = directory || process.cwd()
  // A subagent runs in a CHILD session (`parentID` set). Memoised so each session is
  // looked up once, not per tool call. Any failure (client absent, unknown shape) reads
  // as "not a subagent" — the marker fails OPEN, never locks a session out.
  const subCache = new Map()
  async function isSubagent(sessionID) {
    if (!sessionID) return false
    if (subCache.has(sessionID)) return subCache.get(sessionID)
    let val = false
    try {
      const r = await client.session.get({ path: { id: sessionID } })
      const s = r && (r.data || r)
      val = !!(s && s.parentID)
    } catch (e) {
      val = false
    }
    subCache.set(sessionID, val)
    return val
  }

  return {
    // UserPromptSubmit: memory-recall + the delegation reminder. Their stdout is
    // appended as an extra text part, which is how the other harnesses inject context.
    "chat.message": async (input, output) => {
      if (WIRING_ERROR) {
        const base = (output.parts || [])[0] || {}
        output.parts.push({ ...base, id: (base.id || "ac") + "-achooks", type: "text", text: WIRING_ERROR })
        return
      }
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

    // PreToolUse: bead-capture-guard, skill-edit-guard, dcg. A throw is
    // opencode's deny, and the message reaches the model (verified 2026-08-28).
    "tool.execute.before": async (input, output) => {
      if (WIRING_ERROR) throw new Error(WIRING_ERROR)
      const entries = forEvent("PreToolUse")
      if (!entries.length) return
      const name = TOOL_ALIAS[input.tool] || input.tool
      const payload = JSON.stringify({
        hook_event_name: "PreToolUse",
        tool_name: name,
        tool_input: output.args || {},
        session_id: input.sessionID || "",
        // A child session IS a subagent — the marker bead-capture-guard refuses on.
        agent_id: (await isSubagent(input.sessionID)) ? (input.sessionID || "") : "",
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
  local digest content
  if ! digest="$(python3 "$AC_ROOT/hooks/build_memory_digest.py" "$DOMAIN_REPO" $(resolved_targets))"; then
    echo "  WARN: memory digest generation failed — rendering rules without it"
    digest="*(digest generation failed on last sync — search qmd directly)*"
  fi
  content="<!-- $STAMP — do not hand-edit (sources: infrastructure/harness-config/claude/CLAUDE.md, hooks/build_memory_digest.py) -->

# Machine-global rules

This is the machine-global floor, loaded in every opencode session on this machine.
Project-level AGENTS.md (the doctrine L0) loads natively from the cwd tree alongside
it, and skills load natively from .claude/skills.

The per-prompt lane (memory recall + the delegation reminder) is NOT carried here: since
2026-08-28 it arrives per prompt via the generated ac-hooks plugin, the same canon the
other harnesses receive through hook stdout. Only session-start context is static.

$(floor_body)

---

## Memory digest (pointer index — refreshed daily by infra-sync)

One line per high-value memory in the substrate. This is the FLOOR, not the
substrate: pull full detail with the qmd MCP tools (or \`qmd search\`/\`qmd query\`)
before acting on anything listed here.

$digest"
  write_generated "$OPENCODE_HOME/AGENTS.md" "$content"
}

render_mcp_root() {
  local src body content
  # CANON is mcp/*.json — one file per server, filename = server name (ac-jjwx). Merged
  # here into the single {mcpServers:{...}} object every harness dialect below renders
  # from, so adding a server is adding a file and never editing this function.
  # $ORG_ROOT/.mcp.json is an OUTPUT (the claude projection below), never a source.
  src="$(mktemp)"
  if compgen -G "$AC_ROOT/mcp/*.json" >/dev/null; then
    python3 - "$AC_ROOT/mcp" "$src" <<'PY'
import json, os, sys
d, out = sys.argv[1], sys.argv[2]
servers = {}
for name in sorted(os.listdir(d)):
    if not name.endswith(".json"):
        continue
    with open(os.path.join(d, name)) as fh:
        body = json.load(fh)
    body.pop("_doc", None)          # documentation is canon for humans, not for the harness
    servers[name[:-5]] = body
with open(out, "w") as fh:
    json.dump({"mcpServers": servers}, fh, indent=2)
PY
  else
    rm -f "$src"
    echo "  WARN: no mcp/*.json canon — MCP projection skipped"
    return 0
  fi

  if [ "$EN_CLAUDE" = "true" ]; then
    # Discovered up-tree from any cwd under $ORG_ROOT, across nested-repo boundaries —
    # one file covers every room and app. Claude defers MCP tool schemas, so the old
    # reason to scope this to software/ only (cold-boot tokens) no longer holds.
    echo "  -- claude MCP ($ORG_ROOT/.mcp.json, from mcp/*.json)"
    content="$(jq '{mcpServers: (.mcpServers | with_entries(.value |= (if .url then ({type:"http"} + .) else . end)))}' "$src")"
    write_file_if_changed "$ORG_ROOT/.mcp.json" "$content"
  fi
  if [ "$EN_OPENCODE" = "true" ]; then
    if [ -d "$OPENCODE_HOME" ]; then
      # opencode.json is shared with opencode's own keys — merge the `mcp` key only.
      echo "  -- opencode MCP ($OPENCODE_HOME/opencode.json .mcp, from mcp/*.json)"
      [ -f "$OPENCODE_HOME/opencode.json" ] && body="$(cat "$OPENCODE_HOME/opencode.json")" || body='{"$schema":"https://opencode.ai/config.json"}'
      content="$(jq --slurpfile c "$src" '.mcp = ((.mcp // {}) + ($c[0].mcpServers | with_entries(.value |=
        (if .url then {type:"remote", url} + (if .headers then {headers} else {} end)
         else {type:"local", command: ([.command] + (.args // []))} + (if .env then {environment: .env} else {} end) end)
        + {enabled:true})))' <<<"$body")"
      write_file_if_changed "$OPENCODE_HOME/opencode.json" "$content"
    else
      echo "  WARN: opencode home $OPENCODE_HOME missing — MCP skipped"
    fi
  fi
  if [ "$EN_GROK" = "true" ]; then
    if command -v grok >/dev/null 2>&1; then
      # grok rewrites its own config.toml, so it writes the entry itself: `grok mcp add`
      # is add-or-update. Called only for a server whose entry differs from the canon.
      echo "  -- grok MCP ($GROK_HOME/config.toml [mcp_servers], via grok mcp add)"
      # captured, not piped: a piped while-loop would lose note_change in a subshell
      content="$(python3 - "$GROK_HOME/config.toml" "$src" <<'PY'
import json, sys, tomllib
try:
    have = tomllib.load(open(sys.argv[1], "rb")).get("mcp_servers", {})
except OSError:
    have = {}
for name, s in json.load(open(sys.argv[2]))["mcpServers"].items():
    want = {k: s[k] for k in ("url", "command", "args") if k in s}
    if {k: have.get(name, {}).get(k) for k in want} != want:
        cmd = [name, s["url"]] if "url" in s else [name, s["command"], "--", *s.get("args", [])]
        print("\t".join(cmd))   # tab-separated argv, read into an array below
PY
)"
      local -a argv
      while IFS=$'\t' read -r -a argv; do
        [ "${#argv[@]}" -gt 0 ] || continue
        if [ "$DRY" = 1 ]; then echo "  grok mcp add ${argv[*]}"
        else grok mcp add -s user "${argv[@]}" >/dev/null && echo "  added grok MCP: ${argv[0]}"; fi
        note_change
      done <<<"$content"
    else
      echo "  WARN: grok binary missing — MCP skipped"
    fi
  fi
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
    write_generated "$ORG_ROOT/.codex/config.toml" "$content"
  fi
  if [ "$EN_DROID" = "true" ]; then
    echo "  -- droid MCP (infrastructure/harness-config/droid/mcp.json -> ~/.factory/mcp.json)"
    content="$(jq '{mcpServers: (.mcpServers | with_entries(.value |= (if .command then ({type:"stdio"} + .) else . end)))}' "$src")"
    write_file_if_changed "$ORG_ROOT/infrastructure/harness-config/droid/mcp.json" "$content"
    ensure_home_link "$DROID_HOME/mcp.json" "$ORG_ROOT/infrastructure/harness-config/droid/mcp.json"
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
#
# Line format: `<dir-name> [public] [packages=a,b]`. The optional `packages=`
# token (WS3) names the deploy packages deploy.sh stamps for that target;
# ABSENT means every package — the full-set policy (every app gets the entire
# registry unless a line says otherwise). sync_target honours it by passing
# `deploy.sh --package <pkgs> --agents all` instead of `--all` (agents are
# global stances, owned by no package, so they always deploy whole).
# AC_TARGETS_LIST overrides the default sibling path (same override engine/exceptions.sh
# honours) — for an adopter whose org root holds the roster under a differently named
# directory. Unset keeps the documented default.
TARGETS_LIST="${AC_TARGETS_LIST:-$ORG_ROOT/infrastructure/ac-deploy-targets.list}"
# An override that names no file is a typo, never "no roster": falling through reads every
# target as non-public and guard_public never runs.
if [ -n "${AC_TARGETS_LIST:-}" ] && [ ! -f "$AC_TARGETS_LIST" ]; then
  echo "error: AC_TARGETS_LIST='$AC_TARGETS_LIST' is not a file" >&2; exit 2
fi

is_public_target() { # <basename>
  [ -f "$TARGETS_LIST" ] || return 1
  grep -Eq "^[[:space:]]*$1[[:space:]]+public([[:space:]]|#|$)" "$TARGETS_LIST"
}

target_packages() { # <basename> -> packages csv on stdout, empty when the line names none
  [ -f "$TARGETS_LIST" ] || return 0
  # `|| true`: the trailing grep exits 1 when the line carries no packages= column,
  # which is the COMMON case (absent means the full set). Under `set -euo pipefail`
  # that non-zero propagated out of the pkgs="$(...)" assignment and killed the whole
  # --all run after the first target. It was masked while TARGETS_LIST resolved to a
  # path that did not exist, because the guard above returned first.
  { grep -E "^[[:space:]]*$1([[:space:]#]|$)" "$TARGETS_LIST" | head -1 \
    | sed -E 's/^[^[:space:]]+//' | tr ' ' '\n' \
    | grep -E '^packages=' | head -1 | sed 's/^packages=//'; } || true
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

# --- ac-lint pre-commit chain entry (bead ac-1p7j.10) ------------------------------
# Installs hooks/pre-commit as chain entry 60-ac-lint beside the mcp-agent-mail
# runner's 50-agent-mail.py, in each repo's RESOLVED hooks dir: every repo here is
# a submodule (`.git` is a FILE, no `.git/hooks/`), so the dir comes from
# `resolve_hooks_dir` (git-path made ABSOLUTE — `git rev-parse --git-path hooks`
# on its own returns a path relative to the repo, not to sync.sh's own cwd; the
# three installers below used to build `$hooks_dir/...` straight off that and
# silently inspect/write agent-compounds' own .git/hooks for every consumer app
# instead), which also honours a target's core.hooksPath (a Husky `_`
# dir is one common example). Never clobbers the chain runner or a real
# pre-commit file — refuses loudly, like deploy.sh does for skills.
# Hook symlinks are RELATIVE, always. An absolute target bakes one machine's layout
# into a link that could be committed in some repos (a Husky `_` dir, e.g.) and would be
# a dead path on any other host — the same spell-the-path defect ac-9ahd removed from the
# engine itself. install_commit_msg_hook used to link absolutely while install_lint_hook's
# committed form was relative, so the installer and the tree disagreed and every sync
# printed "SKIP (symlink points elsewhere)" at the one it did not write.
# Accepts either form when deciding whether a link is OURS, so an existing absolute link
# from an older sync is adopted and rewritten rather than skipped forever.
hook_link_target() { # <dest> <canon-path> -> the relative target to write
  relpath "$(dirname "$1")" "$2"
}
hook_link_is_ours() { # <dest> <canon-path>
  local have; have="$(readlink "$1")"
  [ "$have" = "$(hook_link_target "$1" "$2")" ] || [ "$have" = "$2" ]
}

# resolve_hooks_dir <repo-root> -> absolute hooks dir on stdout (honours
# core.hooksPath, e.g. a Husky `_` dir), or empty + non-zero when unresolvable.
# `git rev-parse --git-path hooks` returns a path RELATIVE TO THE REPO, not to
# sync.sh's own cwd — every installer here used to build `$hooks_dir/...` and
# read/write it directly, which silently resolved against agent-compounds' own
# cwd instead of the target repo for every consumer app. Prefer
# git's own `--path-format=absolute` (2.31+); fall back to joining with $repo
# when an older git hands back a relative path.
resolve_hooks_dir() { # <repo-root>
  local repo="$1" hd
  hd="$(git -C "$repo" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)" \
    && [ -n "$hd" ] && { printf '%s\n' "$hd"; return 0; }
  hd="$(git -C "$repo" rev-parse --git-path hooks 2>/dev/null)" || return 1
  [ -n "$hd" ] || return 1
  case "$hd" in
    /*) printf '%s\n' "$hd" ;;
    *) printf '%s\n' "$repo/$hd" ;;
  esac
}

# ensure_scratch_ignored <repo-root> — `_scratch/` is the stances' in-tree scratch home
# (a spawned subagent cannot write outside the project on claude). One idempotent
# .gitignore line per target, so no repo ever tracks a worker's scratch.
ensure_scratch_ignored() {
  local repo="$1" gi="$1/.gitignore"
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  grep -qxE '_scratch/?' "$gi" 2>/dev/null && return 0
  if [ "$DRY" = 1 ]; then echo "  ignore  _scratch/ -> ${gi/#$HOME/~}"; else
    printf '_scratch/\n' >> "$gi"; echo "  ignored _scratch/ in ${gi/#$HOME/~}"
  fi
  note_change
}

install_lint_hook() { # <repo-root>
  local repo="$1" hooks_dir chain_dir dest want
  hooks_dir="$(resolve_hooks_dir "$repo")"
  if [ -z "$hooks_dir" ]; then
    echo "  WARN: no hooks dir resolvable for $repo — ac-lint hook not installed"
    return 0
  fi
  chain_dir="$hooks_dir/hooks.d/pre-commit"
  dest="$chain_dir/60-ac-lint"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  SKIP (real file present — refusing to overwrite): $dest"
    return 0
  fi
  if [ -L "$dest" ] && ! hook_link_is_ours "$dest" "$AC_ROOT/hooks/pre-commit"; then
    echo "  SKIP (symlink points elsewhere): $dest -> $(readlink "$dest")"
    return 0
  fi
  if [ "$DRY" = 1 ]; then
    if [ ! -e "$dest" ] || [ "$(readlink "$dest")" != "$(hook_link_target "$dest" "$AC_ROOT/hooks/pre-commit")" ]; then
      echo "  link $dest -> $(hook_link_target "$dest" "$AC_ROOT/hooks/pre-commit")"; note_change; fi
    return 0
  fi
  mkdir -p "$chain_dir"
  want="$(hook_link_target "$dest" "$AC_ROOT/hooks/pre-commit")"
  # Only write when it differs. `ln -sfn` always rewrites, so the unconditional form
  # re-linked every hook on every run and counted each as a change — 16 per --all with
  # nothing actually changing, which inflates the drift signal the --check leg reads.
  if [ "$(readlink "$dest" 2>/dev/null)" != "$want" ]; then
    ln -sfn "$want" "$dest"
    note_change
    echo "  linked $dest -> $want"
  fi
}

# --- ac commit-msg hook (warn-only cause line) -------------------------------------
# Installs hooks/commit-msg directly: there is no chain runner for commit-msg the way
# 60-ac-lint uses hooks.d/pre-commit, and one advisory hook needs none. Same refusal
# discipline as install_lint_hook — never clobber a real file or a foreign symlink.
install_commit_msg_hook() { # <repo-root>
  local repo="$1" hooks_dir dest want
  hooks_dir="$(resolve_hooks_dir "$repo")"
  if [ -z "$hooks_dir" ]; then
    echo "  WARN: no hooks dir resolvable for $repo — commit-msg hook not installed"
    return 0
  fi
  dest="$hooks_dir/commit-msg"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  SKIP (real file present — refusing to overwrite): $dest"
    return 0
  fi
  if [ -L "$dest" ] && ! hook_link_is_ours "$dest" "$AC_ROOT/hooks/commit-msg"; then
    echo "  SKIP (symlink points elsewhere): $dest -> $(readlink "$dest")"
    return 0
  fi
  if [ "$DRY" = 1 ]; then
    if [ ! -e "$dest" ] || [ "$(readlink "$dest")" != "$(hook_link_target "$dest" "$AC_ROOT/hooks/commit-msg")" ]; then
      echo "  link $dest -> $(hook_link_target "$dest" "$AC_ROOT/hooks/commit-msg")"; note_change; fi
    return 0
  fi
  want="$(hook_link_target "$dest" "$AC_ROOT/hooks/commit-msg")"
  # Only write when it differs. `ln -sfn` always rewrites, so the unconditional form
  # re-linked every hook on every run and counted each as a change — 16 per --all with
  # nothing actually changing, which inflates the drift signal the --check leg reads.
  if [ "$(readlink "$dest" 2>/dev/null)" != "$want" ]; then
    ln -sfn "$want" "$dest"
    note_change
    echo "  linked $dest -> $want"
  fi
}

# install_precommit_chain <repo-root> — installs hooks/pre-commit-chain (the actual
# runner git invokes) as <hooks-dir>/pre-commit. Was hand-copied into every repo;
# this is the one place that keeps it converged. Same refusal discipline as
# install_lint_hook/install_commit_msg_hook, with one addition for THIS exact
# filename: a real (non-symlink) `pre-commit` predates this installer in every repo
# here, so a real file byte-identical to the canon (a hand-copy of it, not a
# script the user wrote) converges to a managed symlink; a real file whose content
# differs IS the "pre-commit the user wrote" case and is reported, never touched.
install_precommit_chain() { # <repo-root>
  local repo="$1" hooks_dir dest want
  hooks_dir="$(resolve_hooks_dir "$repo")"
  if [ -z "$hooks_dir" ]; then
    echo "  WARN: no hooks dir resolvable for $repo — pre-commit chain runner not installed"
    return 0
  fi
  dest="$hooks_dir/pre-commit"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    if ! cmp -s "$AC_ROOT/hooks/pre-commit-chain" "$dest"; then
      echo "  SKIP (real pre-commit present and not the chain runner — refusing to overwrite): $dest"
      return 0
    fi
    # content-identical real file: a hand-copy of the canon, safe to converge below
  fi
  if [ -L "$dest" ] && ! hook_link_is_ours "$dest" "$AC_ROOT/hooks/pre-commit-chain"; then
    echo "  SKIP (symlink points elsewhere): $dest -> $(readlink "$dest")"
    return 0
  fi
  want="$(hook_link_target "$dest" "$AC_ROOT/hooks/pre-commit-chain")"
  if [ "$DRY" = 1 ]; then
    if [ "$(readlink "$dest" 2>/dev/null)" != "$want" ]; then
      echo "  link $dest -> $want"; note_change
    fi
    return 0
  fi
  mkdir -p "$hooks_dir"
  if [ "$(readlink "$dest" 2>/dev/null)" != "$want" ]; then
    ln -sfn "$want" "$dest"
    note_change
    echo "  linked $dest -> $want"
  fi
}

# precommit_chain_unmanaged <repo-root> — 0 when the repo's pre-commit entry is
# PRESENT on disk but is not the managed chain runner (a real file differing from
# the canon, or a foreign symlink), so nothing will invoke 60-ac-lint there. An
# ABSENT pre-commit is not this case: install_precommit_chain installs the runner
# first. Used by sync_target to refuse a dead 60-ac-lint link and fail loudly.
precommit_chain_unmanaged() { # <repo-root>
  local repo="$1" hooks_dir dest
  hooks_dir="$(resolve_hooks_dir "$repo")" || return 1
  [ -n "$hooks_dir" ] || return 1
  dest="$hooks_dir/pre-commit"
  if [ -L "$dest" ]; then
    ! hook_link_is_ours "$dest" "$AC_ROOT/hooks/pre-commit-chain"
    return
  fi
  [ -e "$dest" ] && ! cmp -s "$AC_ROOT/hooks/pre-commit-chain" "$dest"
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

  # 60-ac-lint is installed in EVERY repo, consumer apps included: in a consumer
  # (no lint.sh) hooks/pre-commit runs the registry's check 35 against that
  # repo's own board at commit time (ac-4hpn) — one shared implementation, no
  # vendoring. In the registry checkout the same entry runs the full suite. Same
  # refusal discipline everywhere: never clobber a real file or a foreign symlink,
  # and core.hooksPath is honoured via resolve_hooks_dir.
  #
  # A repo whose pre-commit is NOT the managed chain runner can never invoke
  # 60-ac-lint, so installing it there would leave a dead link and a gate that
  # silently never runs. Refuse that instead — BOARD NOT GATED, a failed target.
  install_precommit_chain "$base"
  if precommit_chain_unmanaged "$base"; then
    echo "  BOARD NOT GATED: pre-commit is not the managed chain runner (real file or foreign symlink) — 60-ac-lint NOT installed, check 35 will not run at commit time" >&2
    FAILURES=$((FAILURES + 1))
  else
    install_lint_hook "$base"
  fi
  install_commit_msg_hook "$base"
  ensure_scratch_ignored "$base"

  if [ "$mode" = "app" ] && [ "$EN_CLAUDE" = "true" ]; then
    local dep_flags="$dep_extra" deploy_status dep_scope="--all" pkgs
    pkgs="$(target_packages "$(basename "$base")")"
    # Per-target packages from ac-deploy-targets.list (WS3): a named subset
    # deploys package-filtered skills with whole agents; absent honours the
    # full-set policy by keeping --all.
    [ -n "$pkgs" ] && dep_scope="--package $pkgs --agents all"
    [ "$DRY" = 1 ] && dep_flags="$dep_flags -n"
    # deploy.sh output counts as change signal only in --check via its own diff-noise;
    # it is idempotent, so re-running is always safe.
    # `|| true` guards against grep's own exit 1 when it filters out every line
    # (no real diff noise) — that is not a failure. But PIPESTATUS[0] still holds
    # deploy.sh's own exit code regardless of the trailing `|| true`, so check it
    # explicitly instead of silently discarding a genuine deploy.sh crash.
    "$ENGINE_DIR/deploy.sh" "$base" $dep_scope $dep_flags | sed 's/^/  [deploy.sh] /' | grep -v '^  \[deploy.sh\] $' || true
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
  local base="$ORG_ROOT"
  echo "== root: $base"

  if [ "$EN_CLAUDE" = "true" ]; then
    echo "  -- claude layer (deploy.sh: skills symlinks + generated agents)"
    local dep_flags="" deploy_status
    [ "$DRY" = 1 ] && dep_flags="-n"
    "$ENGINE_DIR/deploy.sh" "$base" --all $dep_flags | sed 's/^/  [deploy.sh] /' || true
    deploy_status="${PIPESTATUS[0]}"
    [ "$deploy_status" -eq 0 ] || { echo "  ERROR: deploy.sh failed (exit $deploy_status) for $base" >&2; exit "$deploy_status"; }

    # Machine skills: infrastructure/skills/* are org-wide (not agent-compounds
    # registry) skills — symlink each into the global .claude/skills home alongside
    # the registry mirror deploy.sh just placed there. is_managed already accepts
    # anything under $ORG_ROOT/infrastructure, so these links survive prune_dangling
    # everywhere it runs on this dir. A real directory already at the destination is
    # never overwritten (link()'s own loud SKIP).
    local msrc="$ORG_ROOT/infrastructure/skills" mdest="$base/.claude/skills" mentry
    if [ -d "$msrc" ]; then
      echo "  -- machine skills (infrastructure/skills -> .claude/skills)"
      for mentry in "$msrc"/*; do
        [ -d "$mentry" ] || continue
        link "$mentry" "$mdest/$(basename "$mentry")" "$base"
      done
    fi
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
      echo "  -- pi home floor ($PI_HOME/AGENTS.md, generated)"
      # Pi has no session-start/hook context-injection surface, so — like grok and
      # opencode — its context has to travel statically. $FLOOR is the doctrine;
      # infrastructure/harness-config/pi/agent/PI.md (if present) is Pi's OWN
      # hand-written section, appended after a separator — it may not exist yet.
      local pi_own="$ORG_ROOT/infrastructure/harness-config/pi/agent/PI.md" pi_srcs pi_content
      pi_srcs="infrastructure/harness-config/claude/CLAUDE.md"
      pi_content="$(floor_body)"
      if [ -f "$pi_own" ]; then
        pi_srcs="$pi_srcs, infrastructure/harness-config/pi/agent/PI.md"
        pi_content="$pi_content

---

$(cat "$pi_own")"
      fi
      pi_content="<!-- $STAMP — do not hand-edit (sources: $pi_srcs) -->

$pi_content"
      write_generated "$PI_HOME/AGENTS.md" "$pi_content"
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

# --- --report: the static factory matrix (WS3, ac-6asz.4) ---------------------------
# harness-sync.sh --report renders _reports/factory-matrix.html (at the end of
# the run, after any sync work, so the page shows the files as they stand).
# Zero infrastructure, read-only: the files stay the truth and the page only
# shows them. Rows = deploy targets from ac-deploy-targets.list; columns = the
# harness homes sync_target projects into (.claude/skills + generated agents,
# the .agents/skills codex+pi+antigravity mirror, the .factory/skills droid
# mirror); the package dimension comes from skills/packages.json plus each
# line's optional packages= token (absent = every package, the full-set
# policy). A listed target whose dir is absent on this machine reads `missing`,
# never a guess; a missing targets list leaves the targets table a notice —
# the packages section always renders, because the manifest is always here.
report_html_esc() { # stdin -> stdout
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

report_pkg_ok() { # <name> -> 0 iff a real package with a skills array
  jq -e --arg p "$1" '.[$p] | type == "object" and (.skills | type == "array")' \
    "$AC_ROOT/skills/packages.json" >/dev/null 2>&1
}

report_expected() { # <pkgs-csv> -> newline skill names (manifest expansion, or all)
  if [ -z "$1" ]; then
    (cd "$AC_ROOT/skills" 2>/dev/null && {
      find . -name SKILL.md | sed 's#^\./##;s#/SKILL\.md$##'
      find . -maxdepth 1 -mindepth 1 -type d -name '_*' | sed 's#^\./##'
    } | sort -u)
  else
    local m="$AC_ROOT/skills/packages.json" p got
    [ -f "$m" ] || return 0
    IFS=',' read -ra arr <<< "$1"
    for p in "${arr[@]}"; do
      got="$(jq -r --arg p "$p" '.[$p].skills[]? // empty' "$m" 2>/dev/null)" \
        && [ -n "$got" ] && printf '%s\n' "$got"
    done
    (cd "$AC_ROOT/skills" 2>/dev/null \
      && find . -maxdepth 1 -mindepth 1 -type d -name '_*' | sed 's#^\./##')
  fi | sort -u
}

report_managed() { # <dir> -> newline names of symlinks resolving inside AC_ROOT
  # The managed surface only: real files/dirs and foreign symlinks are the
  # app's own (deploy.sh never clobbers them), so they never count as drift.
  # Resolution is FULL-chain (realpath): mirrors deliberately point at the
  # target's own .claude/skills, which in turn points into AC_ROOT — a
  # one-hop read would misclassify every chained mirror link as foreign.
  # realpath is non-strict on the final component, so a DANGLING inside-AC
  # link still reports as managed (a dangling foreign link stays the app's).
  local d="$1" l t
  [ -d "$d" ] || return 0
  for l in "$d"/*; do
    [ -L "$l" ] || continue
    t="$(cd "$(dirname "$l")" && python3 -c '
import os, sys
t = sys.argv[1]
print(os.path.realpath(os.path.join(os.getcwd(), t) if not os.path.isabs(t) else t))
' "$(readlink "$l")")"
    case "$t" in "$AC_ROOT"|"$AC_ROOT"/*) basename "$l" ;; esac
  done | sort -u
}

report_mirror_cell() { # <mirror-dir> <claude-dir> -> ok | drift (+a -b) | no mirror dir
  local mhere mthere mextra mmiss
  [ -d "$1" ] || { printf 'no mirror dir'; return; }
  mhere="$(report_managed "$1")"
  mthere="$(report_managed "$2")"
  mextra="$(comm -23 <(printf '%s\n' "$mhere") <(printf '%s\n' "$mthere") | grep -c . || true)"
  mmiss="$(comm -13 <(printf '%s\n' "$mhere") <(printf '%s\n' "$mthere") | grep -c . || true)"
  if [ "$mextra" = 0 ] && [ "$mmiss" = 0 ]; then printf 'ok'; else printf 'drift (+%s -%s)' "$mextra" "$mmiss"; fi
}

report_target_row() { # <name> — prints one <tr>
  # NOTE: `name` and `base` ride separate `local` commands on purpose — one
  # `local` line expands every word before any binding takes effect, so
  # `local name="$1" base="$AC_ROOT/../$name"` would read the OUTER (empty)
  # $name and silently score the parent dir instead of the target.
  local name="$1" pkgs exp s
  local base="$AC_ROOT/../$name"
  local present=0 miss=0 dang=0 status="ok" details=""
  if [ ! -d "$base" ]; then
    printf '<tr><td>%s</td><td colspan="6">missing on this machine</td></tr>\n' "$name"
    return
  fi
  pkgs="$(target_packages "$name")"
  [ -n "$pkgs" ] || pkgs="all"
  if [ "$pkgs" != "all" ]; then
    IFS=',' read -ra arr <<< "$pkgs"
    for s in "${arr[@]}"; do
      report_pkg_ok "$s" || { status="unknown-package"; details="line names unknown package '$s'"; }
    done
  fi
  exp="$(report_expected "$([ "$pkgs" = "all" ] && printf '' || printf '%s' "$pkgs")")"
  for s in $exp; do
    if [ -e "$base/.claude/skills/$s" ]; then present=$((present + 1)); else miss=$((miss + 1)); fi
  done
  for s in $(report_managed "$base/.claude/skills"); do
    [ -e "$base/.claude/skills/$s" ] || dang=$((dang + 1))
  done
  local total=0; total="$(printf '%s\n' "$exp" | grep -c . || true)"
  [ "$miss" = 0 ] && [ "$dang" = 0 ] || { [ "$status" = "ok" ] && status="drift"; details="missing=$miss dangling=$dang"; }
  local mirror droid
  mirror="$(report_mirror_cell "$base/.agents/skills" "$base/.claude/skills")"
  droid="$(report_mirror_cell "$base/.factory/skills" "$base/.claude/skills")"
  case "$mirror/$droid" in
    ok/ok|ok/"no mirror dir"|"no mirror dir"/ok|"no mirror dir"/"no mirror dir") ;;
    *) [ "$status" = "ok" ] && status="drift" ;;
  esac
  local nagents=0
  [ -d "$base/.claude/agents" ] && nagents="$(ls "$base"/.claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')"
  [ "$status" = "ok" ] && details="converged"
  name="$(printf '%s' "$name" | report_html_esc)"
  details="$(printf '%s' "$details" | report_html_esc)"
  printf '<tr><td>%s</td><td>%s</td><td>%s/%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s (%s)</td></tr>\n' \
    "$name" "$pkgs" "$present" "$total" "$mirror" "$droid" "$nagents" "$status" "$details"
}

render_report() {
  local out="$AC_ROOT/_reports/factory-matrix.html" now machine
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  machine="$(hostname 2>/dev/null || echo unknown)"
  mkdir -p "$AC_ROOT/_reports"
  {
    printf '<!DOCTYPE html>\n<html><head><meta charset="utf-8">\n'
    printf '<title>factory matrix</title></head><body>\n'
    printf '<!-- generated by engine/sync.sh --report — do not hand-edit -->\n'
    printf '<h1>factory matrix</h1>\n<p>generated %s on %s from files on disk; regenerating re-reads them.</p>\n' "$now" "$machine"
    printf '<h2>packages (skills/packages.json)</h2>\n<table border="1">\n'
    printf '<tr><th>package</th><th>blurb</th><th>skills</th><th>requires</th></tr>\n'
    jq -r 'to_entries[] | select(.key | startswith("_") | not)
      | "<tr><td>\(.key | @html)</td><td>\(.value.blurb // "" | @html)</td><td>\(.value.skills | length)</td><td>\(((.value.requires // []) | join(", ")) | @html)</td></tr>"' \
      "$AC_ROOT/skills/packages.json"
    printf '</table>\n<h2>targets x harnesses (ac-deploy-targets.list)</h2>\n<table border="1">\n'
    printf '<tr><th>target</th><th>packages</th><th>claude skills present/expected</th><th>.agents/skills mirror</th><th>.factory/skills mirror</th><th>claude agents</th><th>status</th></tr>\n'
    if [ -f "$TARGETS_LIST" ]; then
      while IFS= read -r line; do
        line="${line%%#*}"; line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
        [ -n "$line" ] || continue
        report_target_row "${line%%[[:space:]]*}"
      done < "$TARGETS_LIST"
    else
      printf '<tr><td colspan="7">targets list absent on this machine (%s) — packages above still render</td></tr>\n' "$TARGETS_LIST"
    fi
    printf '</table>\n</body></html>\n'
  } > "$out"
  echo "rendered $out"
}

# --- run ---------------------------------------------------------------------------
if [ "$VERIFY_AGY" = 1 ] && [ "$DO_ROOT" = 0 ] && [ ${#TARGETS[@]} -eq 0 ]; then
  verify_antigravity; exit $?
fi

[ "$DO_ROOT" = 1 ] && sync_root

# The registry's OWN pre-commit — agent-compounds is not a line in the targets
# list, so a targets-only install would leave every WS1/WS2 commit ungated.
install_lint_hook "$AC_ROOT"
install_commit_msg_hook "$AC_ROOT"
install_precommit_chain "$AC_ROOT"
ensure_scratch_ignored "$AC_ROOT"

if [ "$DO_ALL" = 1 ]; then
  [ -f "$TARGETS_LIST" ] || { echo "error: $TARGETS_LIST missing" >&2; exit 2; }
  # Two sources, INTERSECTED, because they answer different questions: the layout
  # manifest's `targets` globs say where on this machine to look, and the roster in
  # ac-deploy-targets.list says which of those are deploy targets (plus their `public`
  # flag and `packages` column). Intersecting means neither can silently widen the other
  # — a glob cannot add a target the roster never named, and a roster line cannot reach
  # outside the declared search path. It also replaces the old hardcoded "$AC_ROOT/../"
  # assumption that targets are always siblings.
  CANDIDATES=()
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    for d in $AC_ROOT/$g; do
      [ -d "$d" ] && CANDIDATES+=("$(cd "$d" && pwd)")
    done
  done < <(lcfg '.targets[]')
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [ -n "$line" ] || continue
    name="${line%%[[:space:]]*}"   # first token = dir; rest = flags (e.g. `public`)
    match=""
    for c in ${CANDIDATES[@]+"${CANDIDATES[@]}"}; do
      [ "$(basename "$c")" = "$name" ] && { match="$c"; break; }
    done
    if [ -n "$match" ]; then
      sync_target "$match" app
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

# --- stance spawn probe. A projected stance is only proven by spawning it; the probe
# runs when the stances or a harness CLI changed since its last green run, and re-runs
# while red. Visibility only, never blocks a sync.
STANCE_PROBE="$AC_ROOT/scripts/stance-spawn.test.sh"
if [ "$DRY" = 0 ] && [ -f "$STANCE_PROBE" ]; then
  echo
  bash "$STANCE_PROBE" --if-changed || \
    echo "# WARNING: stance spawn probe red (non-blocking) — a stance cannot spawn or write scratch on a harness above"
fi

echo "Done. changes=$CHANGES$([ "$DRY" = 1 ] && echo ' (dry-run)')"
if [ "$FAILURES" -gt 0 ]; then
  echo "ERROR: $FAILURES target(s) failed a sync guard (public-target ignore rules, an unparseable app settings file, or a board that cannot be gated) — see the errors above and re-run" >&2
  exit 1
fi
if [ "$CHECK" = 1 ] && [ "$CHANGES" -gt 0 ]; then
  echo "DRIFT: projections out of sync — run engine/sync.sh to converge" >&2
  exit 1
fi

# --report renders last, after any sync work above, so the page always shows
# the files as they stand when the run ends. Opt-in only: --all never renders.
if [ "$REPORT" = 1 ]; then
  render_report
fi
