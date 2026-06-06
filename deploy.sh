#!/usr/bin/env bash
#
# deploy.sh — stamp a project's .claude/ with agent-compounds tooling via symlinks.
#
# Symlinks (never copies) so the canonical agent-compounds version is the single
# source of truth. Refuses to overwrite a real file/dir already present at the
# target (so an app's customized skill is never clobbered) — it only creates or
# refreshes symlinks.
#
# Usage:
#   ./deploy.sh <target-project-dir> [options]
#
# Options:
#   --skills a,b,c | all    symlink the named skills (or every skill)
#   --agents a,b | all      symlink the named agents (or every agent)
#   --all                   all skills + all agents
#   --list                  print what's available and exit
#   -n, --dry-run           show what would happen, change nothing
#
# Note: the old `--commands` flag is retired — the jef prompt pack is now the
# `jef-prompts` skill, deployed like any other skill (--skills jef-prompts).
#
# Examples:
#   ./deploy.sh ../simil8 --skills supabase,testing,react-best-practices,planning --agents engineer,reviewer
#   ./deploy.sh ../unsit-app --all
#   ./deploy.sh --list

set -euo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY=0
SKILLS_REQ=""
AGENTS_REQ=""
TARGET=""

# Recursive-safe enumeration: a skill is any dir containing SKILL.md; an agent is
# any .md file. Names are paths relative to skills/ or agents/ (e.g. "ac-plan" or,
# if ever nested, "group/sub") so they keep working if assets are grouped into subdirs.
list_skills() { (cd "$AC_ROOT/skills" 2>/dev/null && find . -name SKILL.md | sed 's#^\./##;s#/SKILL\.md$##' | sort); }
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
    --commands) echo "note: --commands is retired; jef is now the 'jef-prompts' skill (--skills jef-prompts)" >&2; shift ;;
    --list)     list_available; exit 0 ;;
    -n|--dry-run) DRY=1; shift ;;
    -*)         echo "unknown option: $1" >&2; exit 2 ;;
    *)          TARGET="$1"; shift ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "error: target project dir required (or use --list)" >&2; exit 2
fi
TARGET="$(cd "$TARGET" && pwd)"   # absolutize; errors if missing

# relpath FROM_DIR TO_PATH  -> relative path usable as a symlink target
relpath() { python3 -c 'import os,sys; print(os.path.relpath(sys.argv[2], sys.argv[1]))' "$1" "$2"; }

# link <source-abs> <dest-abs>
link() {
  local src="$1" dest="$2" destdir
  destdir="$(dirname "$dest")"
  mkdir -p "$destdir"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  SKIP (real file present, not overwriting): ${dest#$TARGET/}"
    return
  fi
  local rel; rel="$(relpath "$destdir" "$src")"
  if [ "$DRY" = 1 ]; then
    echo "  link ${dest#$TARGET/} -> $rel"
  else
    ln -sfn "$rel" "$dest"
    echo "  linked ${dest#$TARGET/} -> $rel"
  fi
}

echo "Deploying agent-compounds -> $TARGET"

# --- skills ---
if [ -n "$SKILLS_REQ" ]; then
  echo "Skills:"
  if [ "$SKILLS_REQ" = "all" ]; then
    SKILLS_REQ="$(list_skills | paste -sd, -)"
  fi
  IFS=',' read -ra arr <<< "$SKILLS_REQ"
  for s in "${arr[@]}"; do
    if [ -d "$AC_ROOT/skills/$s" ]; then
      link "$AC_ROOT/skills/$s" "$TARGET/.claude/skills/$s"
    else
      echo "  MISSING in agent-compounds: skill '$s'"
    fi
  done
fi

# --- agents ---
if [ -n "$AGENTS_REQ" ]; then
  echo "Agents:"
  if [ "$AGENTS_REQ" = "all" ]; then
    AGENTS_REQ="$(list_agents | paste -sd, -)"
  fi
  IFS=',' read -ra arr <<< "$AGENTS_REQ"
  for a in "${arr[@]}"; do
    if [ -f "$AC_ROOT/agents/$a.md" ]; then
      link "$AC_ROOT/agents/$a.md" "$TARGET/.claude/agents/$a.md"
    else
      echo "  MISSING in agent-compounds: agent '$a'"
    fi
  done
fi

echo "Done."
