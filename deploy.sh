#!/usr/bin/env bash
#
# deploy.sh — stamp a project's .claude/ with agent-compounds tooling.
#
# ROLE (since 2026-07-04): the .claude-LAYER renderer, driven by harness-sync.sh
# (which then mirrors .claude into the Codex/Droid/Pi homes). For full-target syncs
# use ./harness-sync.sh --all; call deploy.sh directly only for selective one-off
# stamps on projects outside ac-deploy-targets.list (e.g. --skills a,b on simil8).
#
# Skills are SYMLINKS (never copies) so the canonical agent-compounds version is the
# single source of truth. Agents are GENERATED (since model tiers, 2026-09): each
# agents/*.md in the registry carries a semantic `tier:` (orchestrator|coordinator|
# worker); deploy.sh resolves it through harnesses.json -> harnesses.claude.agent_models
# and writes .claude/agents/*.md with a concrete `model:` stamped in — so the registry
# never pins a model and every harness maps tiers in its own currency. Generated files
# carry a stamp and are only ever overwritten when stamped; a real file without the
# stamp (or a foreign symlink) is never clobbered. Old inside-AC agent symlinks are
# replaced by the generated file (they are ours).
#
# Refuses to overwrite a real file/dir already present at the target (so an app's
# customized skill is never clobbered) — it only creates or refreshes symlinks that
# already point inside agent-compounds or are dangling.
#
# Usage:
#   ./deploy.sh <target-project-dir> [options]
#
# Options:
#   --skills a,b,c | all    symlink the named skills (or every skill)
#   --agents a,b | all      generate the named agents (or every agent)
#   --all                   all skills + all agents
#   --list                  print what's available and exit
#   --no-prune              keep orphaned symlinks (default: prune them)
#   --require-ignored       refuse to stamp unless the target's git repo ignores
#                           the harness paths this script creates (guard for
#                           PUBLIC repos — symlinks must never be committed/
#                           published; see ac-deploy-targets.list `public` flag)
#   -n, --dry-run           show what would happen, change nothing
#
# Prune (default ON): after linking, any symlink under the target's
# .claude/skills or .claude/agents that points INSIDE agent-compounds but no
# longer resolves (a dangling orphan — e.g. left behind when a skill is renamed
# or removed upstream) is deleted. Always safe: a dangling inside-AC symlink
# points at nothing. This is the fix for the "rename strands a symlink in every
# consumer repo" failure mode. Foreign symlinks and real files are never touched.
#
# Examples:
#   ./deploy.sh ../simil8 --skills supabase,testing,react-best-practices,planning --agents implementer,validator
#   ./deploy.sh ../unsit-app --all
#   ./deploy.sh --list

set -euo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Tier->model config: same manifest deep-merge as harness-sync.sh (harnesses.json
# committed base, harnesses.local.json machine overrides on top).
MANIFEST="$AC_ROOT/harnesses.json"
LOCAL="$AC_ROOT/harnesses.local.json"
if [ -f "$LOCAL" ]; then
  CFG="$(jq -s '.[0] * .[1]' "$MANIFEST" "$LOCAL")"
else
  CFG="$(cat "$MANIFEST")"
fi

# tier_model <harness> <tier> <agent-name> — resolve a tier to a concrete model id.
# Fails loud (exit 2) on a missing map entry: silently inheriting a harness default
# would flatten the tier gradient and look exactly like success.
tier_model() {
  local m
  m="$(printf '%s' "$CFG" | jq -r ".harnesses.$1.agent_models.$2 // empty")"
  if [ -z "$m" ]; then
    echo "error: harnesses.$1.agent_models has no entry for tier '$2' (agent: $3) — add it to harnesses.json" >&2
    exit 2
  fi
  printf '%s' "$m"
}

AGENTS_STAMP="generated-by: deploy.sh"

DRY=0
PRUNE=1
REQ_IGNORED=0
SKILLS_REQ=""
AGENTS_REQ=""
TARGET=""

# Recursive-safe enumeration: a skill is any dir containing SKILL.md; an agent is
# any .md file. Names are paths relative to skills/ or agents/ (e.g. "ac-plan" or,
# if ever nested, "group/sub") so they keep working if assets are grouped into subdirs.
# _-prefixed top-level dirs (e.g. _shared) are shared reference dirs — no SKILL.md,
# but always included so skills that reference them find them at the expected path.
list_skills() {
  (cd "$AC_ROOT/skills" 2>/dev/null && {
    find . -name SKILL.md | sed 's#^\./##;s#/SKILL\.md$##'
    find . -maxdepth 1 -mindepth 1 -type d -name '_*' | sed 's#^\./##'
  } | sort -u)
}
list_agents() { (cd "$AC_ROOT/agents" 2>/dev/null && find . -name '*.md' | sed 's#^\./##;s#\.md$##' | sort); }

list_available() {
  echo "Skills:"; list_skills | sed 's/^/  /'
  echo "Agents:"; list_agents | sed 's/^/  /'
}

# --- parse args ---
while [ $# -gt 0 ]; do
  case "$1" in
    --skills)   SKILLS_REQ="$2"; shift 2 ;;
    --agents)   AGENTS_REQ="$2"; shift 2 ;;
    --all)      SKILLS_REQ="all"; AGENTS_REQ="all"; shift ;;
    --list)     list_available; exit 0 ;;
    --no-prune) PRUNE=0; shift ;;
    --require-ignored) REQ_IGNORED=1; shift ;;
    -n|--dry-run) DRY=1; shift ;;
    -*)         echo "unknown option: $1" >&2; exit 2 ;;
    *)          TARGET="$1"; shift ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "error: target project dir required (or use --list)" >&2; exit 2
fi
[ -d "$TARGET" ] || { echo "error: target dir does not exist: $TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd)"   # absolutize

# --require-ignored: public-repo guard. check-ignore is pure pattern matching, so
# probe paths need not exist — they stand in for anything this script would create.
if [ "$REQ_IGNORED" = 1 ]; then
  git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { echo "error: --require-ignored: $TARGET is not a git repo — cannot verify ignore rules" >&2; exit 3; }
  for p in .claude/skills/__ac_probe__ .claude/agents/__ac_probe__.md; do
    git -C "$TARGET" check-ignore -q "$p" || {
      echo "error: --require-ignored: '$p' would be git-tracked in $TARGET — a public target must gitignore its harness layer before stamping (nothing linked)" >&2
      exit 3
    }
  done
fi

# relpath FROM_DIR TO_PATH  -> relative path usable as a symlink target
relpath() { python3 -c 'import os,sys; print(os.path.relpath(sys.argv[2], sys.argv[1]))' "$1" "$2"; }

# is_inside_ac <path>  -> returns 0 if the resolved path is inside AC_ROOT
is_inside_ac() {
  python3 -c '
import os, sys
target = os.path.realpath(sys.argv[1])
ac = os.path.realpath(sys.argv[2])
# path is inside ac if it starts with ac + separator, or equals ac
sys.exit(0 if (target == ac or target.startswith(ac + os.sep)) else 1)
' "$1" "$AC_ROOT"
}

# link <source-abs> <dest-abs>
link() {
  local src="$1" dest="$2" destdir
  destdir="$(dirname "$dest")"

  # real file/dir present (not a symlink) — never overwrite
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  SKIP (real file present, not overwriting): ${dest#$TARGET/}"
    return
  fi

  # existing symlink — apply overwrite policy
  if [ -L "$dest" ]; then
    local current_target
    current_target="$(readlink "$dest")"
    # Normalize the symlink target to an absolute path WITHOUT requiring it to
    # exist (os.path.normpath + os.path.join handles relative symlinks).
    # We then check whether that normalized path falls inside AC_ROOT.
    # If it resolves outside AC_ROOT, skip regardless of whether it exists.
    # If it resolves inside AC_ROOT (even if dangling), refresh it.
    local resolved
    resolved="$(cd "$destdir" && python3 -c '
import os, sys
t = sys.argv[1]
# make absolute if relative
if not os.path.isabs(t):
    t = os.path.join(os.getcwd(), t)
print(os.path.normpath(t))
' "$current_target")"
    if ! is_inside_ac "$resolved"; then
      echo "  SKIP (foreign symlink, not overwriting): ${dest#$TARGET/} -> $current_target"
      return
    fi
    # falls through: points inside AC_ROOT (possibly dangling) — refresh it
  fi

  local rel; rel="$(relpath "$destdir" "$src")"
  if [ "$DRY" = 1 ]; then
    echo "  link ${dest#$TARGET/} -> $rel"
  else
    mkdir -p "$destdir"
    ln -sfn "$rel" "$dest"
    echo "  linked ${dest#$TARGET/} -> $rel"
  fi
}

# prune_orphans <dir>  -> delete dangling symlinks in <dir> that point inside AC_ROOT
# (orphans from an upstream rename/removal). Real files + foreign symlinks untouched.
prune_orphans() {
  local dir="$1" link current_target resolved
  [ -d "$dir" ] || return 0
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    [ -e "$link" ] && continue   # still resolves → not an orphan
    current_target="$(readlink "$link")"
    resolved="$(cd "$(dirname "$link")" && python3 -c '
import os, sys
t = sys.argv[1]
if not os.path.isabs(t):
    t = os.path.join(os.getcwd(), t)
print(os.path.normpath(t))
' "$current_target")"
    is_inside_ac "$resolved" || continue   # foreign dangling link → leave it
    if [ "$DRY" = 1 ]; then
      echo "  prune (orphan) ${link#$TARGET/} -> $current_target"
    else
      rm "$link"
      echo "  pruned (orphan) ${link#$TARGET/} -> $current_target"
    fi
  done < <(/usr/bin/find "$dir" -maxdepth 1 -type l)
}

# gen_claude_agent <src-md> <dest-md> — render one registry agent into the target's
# .claude/agents/ with its tier resolved to a concrete claude model (from
# harnesses.claude.agent_models). Overwrite policy: a real file WITHOUT our stamp is
# never touched; a stamped file is regenerated; an inside-AC symlink (the pre-tier
# deployment form) is REPLACED by the generated file — but never written through,
# so the registry source is removed from the link path first.
gen_claude_agent() {
  local src="$1" dest="$2" fm body tier model
  fm="$(awk '/^---[[:space:]]*$/{c++; next} c==1{print}' "$src")"
  body="$(awk '/^---[[:space:]]*$/{c++; next} c>=2{print}' "$src")"
  tier="$(printf '%s\n' "$fm" | awk -F': *' '$1=="tier"{print $2; exit}')"
  if [ -z "$tier" ]; then
    echo "error: agents/$(basename "$src"): no 'tier:' in frontmatter — every registry agent must declare one (run lint.sh)" >&2
    exit 2
  fi
  model="$(tier_model claude "$tier" "agents/$(basename "$src")")"

  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    if grep -q "$AGENTS_STAMP" "$dest" 2>/dev/null; then
      :   # ours — regenerate below
    else
      echo "  SKIP (real file present, not overwriting): ${dest#$TARGET/}"
      return
    fi
  fi
  if [ -L "$dest" ]; then
    local destdir current resolved
    destdir="$(dirname "$dest")"
    current="$(readlink "$dest")"
    resolved="$(cd "$destdir" && python3 -c '
import os, sys
t = sys.argv[1]
if not os.path.isabs(t):
    t = os.path.join(os.getcwd(), t)
print(os.path.normpath(t))
' "$current")"
    if ! is_inside_ac "$resolved"; then
      echo "  SKIP (foreign symlink, not overwriting): ${dest#$TARGET/} -> $current"
      return
    fi
    [ "$DRY" = 1 ] || rm -f "$dest"   # write the file, never through the link
  fi

  local content="---
$fm
model: $model
---
<!-- $AGENTS_STAMP (tier: $tier) — do not hand-edit (source: agents/$(basename "$src")) -->

$body"
  # content-diff idempotency: a converged target is not a change
  if [ -f "$dest" ] && [ ! -L "$dest" ] && [ "$(cat "$dest")" = "$content" ]; then
    return
  fi
  if [ "$DRY" = 1 ]; then
    echo "  generate ${dest#$TARGET/} (tier: $tier -> $model)"
  else
    mkdir -p "$(dirname "$dest")"
    printf '%s\n' "$content" > "$dest"
    echo "  generated ${dest#$TARGET/} (tier: $tier -> $model)"
  fi
}

# Fail loud if the source tree is missing — otherwise list_skills/list_agents
# return empty and we'd silently deploy nothing (e.g. AC_ROOT misdetected).
[ -d "$AC_ROOT/skills" ] || { echo "error: $AC_ROOT/skills not found — is AC_ROOT correct?" >&2; exit 2; }
[ -d "$AC_ROOT/agents" ] || { echo "error: $AC_ROOT/agents not found — is AC_ROOT correct?" >&2; exit 2; }

echo "Deploying agent-compounds -> $TARGET"

# --- skills ---
if [ -n "$SKILLS_REQ" ]; then
  echo "Skills:"
  if [ "$SKILLS_REQ" = "all" ]; then
    SKILLS_REQ="$(list_skills | paste -sd, -)"
  fi
  IFS=',' read -ra arr <<< "$SKILLS_REQ"
  for s in "${arr[@]}"; do
    s="${s#"${s%%[![:space:]]*}"}"   # trim leading whitespace
    s="${s%"${s##*[![:space:]]}"}"   # trim trailing whitespace
    if [ -d "$AC_ROOT/skills/$s" ]; then
      link "$AC_ROOT/skills/$s" "$TARGET/.claude/skills/$s"
    else
      echo "  MISSING in agent-compounds: skill '$s'"
    fi
  done
fi

# --- agents ---
if [ -n "$AGENTS_REQ" ]; then
  echo "Agents (generated from tier:):"
  if [ "$AGENTS_REQ" = "all" ]; then
    AGENTS_REQ="$(list_agents | paste -sd, -)"
  fi
  IFS=',' read -ra arr <<< "$AGENTS_REQ"
  for a in "${arr[@]}"; do
    a="${a#"${a%%[![:space:]]*}"}"   # trim leading whitespace
    a="${a%"${a##*[![:space:]]}"}"   # trim trailing whitespace
    if [ -f "$AC_ROOT/agents/$a.md" ]; then
      gen_claude_agent "$AC_ROOT/agents/$a.md" "$TARGET/.claude/agents/$a.md"
    else
      echo "  MISSING in agent-compounds: agent '$a'"
    fi
  done
fi

if [ "$PRUNE" = 1 ]; then
  echo "Prune (orphaned inside-AC symlinks):"
  prune_orphans "$TARGET/.claude/skills"
  prune_orphans "$TARGET/.claude/agents"
fi

# Memory hygiene lint is substrate-global and target-invariant, so it runs ONCE
# per harness-sync.sh invocation (after its target loops), not here — running it
# per-deploy repeated identical full-substrate lints once per target and timed
# out the projection-regeneration check.

echo "Done."
