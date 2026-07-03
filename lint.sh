#!/usr/bin/env bash
#
# lint.sh — registry self-lint for agent-compounds.
#
# Mechanizes the 2026-06-11 audit's checkable invariants.
#
# Usage:  ./lint.sh
#
# Exit 0  all checks pass
# Exit 1  one or more checks failed (each reported as FAIL: ...)
#
# Style-matched to deploy.sh (same repo).

set -uo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FAILURES=0
CHECKS=0

# Emit a FAIL line and increment counters.
fail() {
  echo "FAIL: $*"
  FAILURES=$(( FAILURES + 1 ))
}

# Increment check counter.
check() {
  CHECKS=$(( CHECKS + 1 ))
}

# ---------------------------------------------------------------------------
# Check 1 — Dead-pattern grep (zero tolerance in skills/ and agents/)
# ---------------------------------------------------------------------------
echo "--- Check 1: dead patterns ---"

DEAD_PATTERNS=(
  "run /ac-plan first"
  "Run /ac-plan "
  "persona-catalog"
  "craigs-setup"
  "browser-qa-agent"
  "agent-compounds/commands/"
)

for pattern in "${DEAD_PATTERNS[@]}"; do
  check
  # grep -r returns 0 if found (bad), 1 if not found (good), 2 on error
  results=$(grep -rl --include="*.md" -- "$pattern" "$AC_ROOT/skills" "$AC_ROOT/agents" 2>/dev/null || true)
  if [ -n "$results" ]; then
    while IFS= read -r file; do
      fail "dead pattern '$pattern' found in ${file#$AC_ROOT/}"
    done <<< "$results"
  fi
done

# ---------------------------------------------------------------------------
# Check 2 — /ac-skill cross-references resolve
# ---------------------------------------------------------------------------
echo "--- Check 2: /ac-* cross-reference resolution ---"

# Collect all /ac-* tokens from SKILL.md + references/*.md + workflows/*.md
# Uses /ac-[a-z][a-z-]*[a-z] (must start and end with a letter) to avoid
# picking up glob shorthand suffixes (e.g. /ac-plan-refine-* stops correctly
# at the last letter before the trailing -* but still produces ac-plan-refine;
# we additionally filter tokens that appear ONLY as a prefix in glob form by
# checking if the skills dir exists).
ALL_AC_TOKENS=""

# Also collect all raw text to detect glob-style usage (token followed by -*)
ALL_AC_GLOB_PREFIXES=""

for skill_dir in "$AC_ROOT/skills"/*/; do
  for f in "$skill_dir/SKILL.md" "$skill_dir/references/"*.md "$skill_dir/workflows/"*.md; do
    [ -f "$f" ] || continue
    tokens=$(grep -oE '/ac-[a-z][a-z-]*[a-z]' "$f" 2>/dev/null || true)
    if [ -n "$tokens" ]; then
      ALL_AC_TOKENS="${ALL_AC_TOKENS}
${tokens}"
    fi
    # collect tokens that appear as glob prefixes: /ac-<name>-*
    globs=$(grep -oE '/ac-[a-z][a-z-]*[a-z]-\*' "$f" 2>/dev/null | sed 's/-\*$//' || true)
    if [ -n "$globs" ]; then
      ALL_AC_GLOB_PREFIXES="${ALL_AC_GLOB_PREFIXES}
${globs}"
    fi
  done
done

# Deduplicate tokens; strip leading slash
DISTINCT_AC=$(printf '%s\n' "$ALL_AC_TOKENS" \
  | grep -E '^/ac-[a-z]' \
  | sed 's|^/||' \
  | sort -u)

# Deduplicate glob prefixes; strip leading slash
GLOB_PREFIXES=$(printf '%s\n' "$ALL_AC_GLOB_PREFIXES" \
  | grep -E '^/ac-[a-z]' \
  | sed 's|^/||' \
  | sort -u)

while IFS= read -r token; do
  [ -n "$token" ] || continue
  # Skip tokens that only appear as glob shorthands (e.g. /ac-plan-refine-*)
  # A token is a pure glob prefix if it does NOT exist as a skill dir AND
  # it appears in the glob-prefix list. If the skill dir exists, it's fine either way.
  if [ ! -d "$AC_ROOT/skills/$token" ]; then
    if printf '%s\n' "$GLOB_PREFIXES" | grep -qx "$token"; then
      # This token is used only as a glob prefix (e.g. /ac-plan-refine-*) — not a
      # concrete skill invocation; skip without counting as a check.
      continue
    fi
  fi
  check
  if [ ! -d "$AC_ROOT/skills/$token" ]; then
    fail "/$token referenced in skills but skills/$token/ does not exist"
  fi
done <<< "$DISTINCT_AC"

# ---------------------------------------------------------------------------
# Check 3 — Frontmatter conformance
# ---------------------------------------------------------------------------
echo "--- Check 3: frontmatter conformance ---"

# skills/*/SKILL.md must have name: == dir name AND non-empty description:
for skill_dir in "$AC_ROOT/skills"/*/; do
  [ -f "$skill_dir/SKILL.md" ] || continue
  skill_name=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"

  check
  name_val=$(grep -m1 '^name:' "$skill_md" 2>/dev/null | sed 's/^name:[[:space:]]*//')
  if [ "$name_val" != "$skill_name" ]; then
    fail "skills/$skill_name/SKILL.md: name '$name_val' != dir name '$skill_name'"
  fi

  check
  desc_val=$(grep -m1 '^description:' "$skill_md" 2>/dev/null | sed 's/^description:[[:space:]]*//')
  if [ -z "$desc_val" ]; then
    fail "skills/$skill_name/SKILL.md: description is empty or missing"
  fi
done

# agents/*.md must have name: == filename (sans .md)
for agent_file in "$AC_ROOT/agents"/*.md; do
  [ -f "$agent_file" ] || continue
  agent_name=$(basename "$agent_file" .md)

  check
  name_val=$(grep -m1 '^name:' "$agent_file" 2>/dev/null | sed 's/^name:[[:space:]]*//')
  if [ "$name_val" != "$agent_name" ]; then
    fail "agents/$agent_name.md: name '$name_val' != filename '$agent_name'"
  fi
done

# ---------------------------------------------------------------------------
# Check 4 — README <-> disk consistency
# ---------------------------------------------------------------------------
echo "--- Check 4: README <-> disk ---"

README="$AC_ROOT/README.md"

# 4a: every skills/ dir with a SKILL.md is mentioned in README.md
for skill_dir in "$AC_ROOT/skills"/*/; do
  [ -f "$skill_dir/SKILL.md" ] || continue
  skill_name=$(basename "$skill_dir")
  check
  if ! grep -q "$skill_name" "$README" 2>/dev/null; then
    fail "README: skill '$skill_name' (has SKILL.md) not mentioned in README.md"
  fi
done

# 4b: every agents/*.md file is mentioned in README.md
for agent_file in "$AC_ROOT/agents"/*.md; do
  [ -f "$agent_file" ] || continue
  agent_name=$(basename "$agent_file" .md)
  check
  if ! grep -q "$agent_name" "$README" 2>/dev/null; then
    fail "README: agent '$agent_name' not mentioned in README.md"
  fi
done

# 4c: README skill-table rows referencing ](./skills/<name>/) must exist on disk
while IFS= read -r linked_skill; do
  [ -n "$linked_skill" ] || continue
  check
  if [ ! -d "$AC_ROOT/skills/$linked_skill" ]; then
    fail "README: links to ./skills/$linked_skill/ but that directory does not exist"
  fi
done <<< "$(grep -oh '\](./skills/[^/]*/)'  "$README" 2>/dev/null \
  | sed 's|](./skills/||; s|/)||' \
  | sort -u)"

# 4d: README agent rows referencing ](./agents/<name>.md) must exist on disk
while IFS= read -r linked_agent; do
  [ -n "$linked_agent" ] || continue
  check
  if [ ! -f "$AC_ROOT/agents/$linked_agent.md" ]; then
    fail "README: links to ./agents/$linked_agent.md but that file does not exist"
  fi
done <<< "$(grep -oh '\](./agents/[^)]*\.md)' "$README" 2>/dev/null \
  | sed 's|](./agents/||; s|\.md)||' \
  | sort -u)"

# ---------------------------------------------------------------------------
# Check 5 — AGENTS.md diagram paths exist
# ---------------------------------------------------------------------------
echo "--- Check 5: AGENTS.md diagram paths ---"

for path in skills agents deploy.sh templates _plans; do
  check
  if [ ! -e "$AC_ROOT/$path" ]; then
    fail "AGENTS.md diagram path missing: $path"
  fi
done

# ---------------------------------------------------------------------------
# Check 6 — Portability greps (zero in skills/)
# ---------------------------------------------------------------------------
echo "--- Check 6: portability violations ---"

PORTABILITY_PATTERNS=(
  "canonical_ingredients"
  "For Body Compass"
  "127.0.0.1:54321"
  "bd-8nse"
  "bd-9veq"
)

for pattern in "${PORTABILITY_PATTERNS[@]}"; do
  check
  results=$(grep -rl --include="*.md" -- "$pattern" "$AC_ROOT/skills" 2>/dev/null || true)
  if [ -n "$results" ]; then
    while IFS= read -r file; do
      fail "portability violation '$pattern' found in ${file#$AC_ROOT/}"
    done <<< "$results"
  fi
done

# ---------------------------------------------------------------------------
# Check 7 — Consumer symlink health
# ---------------------------------------------------------------------------
echo "--- Check 7: consumer symlink health ---"

# Org-level consumers: fixed repo-root paths, not app deploy targets — stay hardcoded.
ORG_CONSUMER_DIRS=(
  "$HOME/Repos/.claude"
  "$HOME/Repos/neometa/content/.claude"
  "$HOME/Repos/neometa/books/.claude"
  "$HOME/Repos/neometa/software/.claude"
)

# App consumers: sourced from infrastructure/ac-deploy-targets.list — the single source of
# truth infra-sync.sh uses to propagate the full registry (see AGENTS.md "Auto-propagation").
# Reading it here means a newly added deploy target is automatically covered by Check 7 with
# no manual re-stamp of this script. Falls back to the last-known app list if the file is
# unreachable (e.g. a standalone checkout of this repo), so coverage degrades gracefully
# instead of silently dropping to zero.
DEPLOY_TARGETS_LIST="$AC_ROOT/../../../infrastructure/ac-deploy-targets.list"
APP_CONSUMER_DIRS=()
if [ -f "$DEPLOY_TARGETS_LIST" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"                      # strip trailing/whole-line comments
    line="$(printf '%s' "$line" | xargs)"   # trim whitespace; empty if comment/blank
    [ -n "$line" ] || continue
    APP_CONSUMER_DIRS+=("$HOME/Repos/neometa/software/$line/.claude")
  done < "$DEPLOY_TARGETS_LIST"
else
  APP_CONSUMER_DIRS=(
    "$HOME/Repos/neometa/software/body-compass-app/.claude"
    "$HOME/Repos/neometa/software/unsit-app/.claude"
    "$HOME/Repos/neometa/software/art-still-app/.claude"
    "$HOME/Repos/neometa/software/cv-site/.claude"
    "$HOME/Repos/neometa/software/move-free-app/.claude"
    "$HOME/Repos/neometa/software/neometa-app/.claude"
  )
fi

# vitest-affected is DELIBERATELY EXCLUDED from ac-deploy-targets.list (public OSS library,
# self-contained real skills only — see that file's own header comment) but was covered by
# this check before the union existed; keep it explicit so coverage never regresses.
APP_CONSUMER_DIRS+=("$HOME/Repos/neometa/software/vitest-affected/.claude")

# Union, de-duplicated (org-level ∪ app-level).
CONSUMER_DIRS=($(printf '%s\n' "${ORG_CONSUMER_DIRS[@]}" "${APP_CONSUMER_DIRS[@]}" | sort -u))

for dir in "${CONSUMER_DIRS[@]}"; do
  [ -d "$dir" ] || continue   # skip non-existent dirs silently
  check
  broken=$(/usr/bin/find "$dir" -type l ! -exec test -e {} \; -print 2>/dev/null || true)
  if [ -n "$broken" ]; then
    while IFS= read -r link; do
      fail "broken symlink: $link"
    done <<< "$broken"
  fi
done

# ---------------------------------------------------------------------------
# Check 8 — deploy.sh dry-run inertness self-test
# ---------------------------------------------------------------------------
echo "--- Check 8: deploy.sh dry-run inertness ---"

check
FIRST_SKILL=$(/usr/bin/find "$AC_ROOT/skills" -name SKILL.md | head -1 | sed "s|$AC_ROOT/skills/||;s|/SKILL.md||")

if [ -z "$FIRST_SKILL" ]; then
  fail "deploy.sh dry-run self-test: could not find any skill to test with"
else
  DRYRUN_TMP=$(mktemp -d)
  DRYRUN_EXIT=0
  "$AC_ROOT/deploy.sh" "$DRYRUN_TMP" --skills "$FIRST_SKILL" -n >/dev/null 2>&1 || DRYRUN_EXIT=$?
  DRYRUN_CONTENTS=$(ls -A "$DRYRUN_TMP" 2>/dev/null || true)
  # A crash before any write would also leave the dir empty — so check exit code
  # too, or the inertness test passes for a broken deploy.sh.
  if [ "$DRYRUN_EXIT" -ne 0 ]; then
    fail "deploy.sh --dry-run exited $DRYRUN_EXIT (expected 0)"
  fi
  # clean up temp dir (use rmdir on empty or remove files only if truly empty)
  if [ -z "$DRYRUN_CONTENTS" ]; then
    rmdir "$DRYRUN_TMP" 2>/dev/null || true
  else
    # leave it for diagnostics — list what leaked
    fail "deploy.sh --dry-run created files in temp dir (should be inert): $DRYRUN_CONTENTS (tmp: $DRYRUN_TMP)"
  fi
fi

# ---------------------------------------------------------------------------
# Check 9 — No stray alias agents
# ---------------------------------------------------------------------------
echo "--- Check 9: no stray alias agents ---"

check
if [ -f "$AC_ROOT/agents/engineer.md" ]; then
  fail "agents/engineer.md exists — retired alias agent (renamed to implementer 2026-06-11)"
fi

check
if [ -f "$AC_ROOT/agents/reviewer.md" ]; then
  fail "agents/reviewer.md exists — retired alias agent (renamed to validator 2026-06-11)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "lint: ${CHECKS} checks, ${FAILURES} failures"

[ "$FAILURES" -eq 0 ]
