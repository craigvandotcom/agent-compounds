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
#   --commands              symlink the jef command pack (the flywheel is now skills/ac-*)
#   --skills a,b,c | all    symlink the named skills (or every skill)
#   --agents a,b | all      symlink the named agents (or every agent)
#   --all                   commands + all skills + all agents
#   --list                  print what's available and exit
#   -n, --dry-run           show what would happen, change nothing
#
# Examples:
#   ./deploy.sh ../simil8 --commands --skills supabase,testing,react-best-practices,planning --agents engineer,reviewer
#   ./deploy.sh ../unsit-app --all
#   ./deploy.sh --list

set -euo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY=0
DO_COMMANDS=0
SKILLS_REQ=""
AGENTS_REQ=""
TARGET=""

list_available() {
  echo "Skills:"; (cd "$AC_ROOT/skills" && ls -1d */ 2>/dev/null | sed 's#/##;s/^/  /')
  echo "Agents:"; (cd "$AC_ROOT/agents" && ls -1 *.md 2>/dev/null | sed 's/\.md$//;s/^/  /')
  echo "Command packs:  jef"
}

# --- parse args ---
while [ $# -gt 0 ]; do
  case "$1" in
    --commands) DO_COMMANDS=1; shift ;;
    --skills)   SKILLS_REQ="$2"; shift 2 ;;
    --agents)   AGENTS_REQ="$2"; shift 2 ;;
    --all)      DO_COMMANDS=1; SKILLS_REQ="all"; AGENTS_REQ="all"; shift ;;
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

# --- commands ---
if [ "$DO_COMMANDS" = 1 ]; then
  echo "Commands (jef pack):"
  link "$AC_ROOT/commands/jef" "$TARGET/.claude/commands/jef"
fi

# --- skills ---
if [ -n "$SKILLS_REQ" ]; then
  echo "Skills:"
  if [ "$SKILLS_REQ" = "all" ]; then
    SKILLS_REQ="$(cd "$AC_ROOT/skills" && ls -1d */ | sed 's#/##' | paste -sd, -)"
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
    AGENTS_REQ="$(cd "$AC_ROOT/agents" && ls -1 *.md | sed 's/\.md$//' | paste -sd, -)"
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
