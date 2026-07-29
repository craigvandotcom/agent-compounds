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
check
[ -f "$README" ] || fail "README: $README is missing — Check 4c/4d's link-existence sub-checks silently no-op without it"

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
    line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"   # trim whitespace; empty if comment/blank
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
# Check 10 — pipeline conformance (D-series doctrine landings)
# ---------------------------------------------------------------------------
echo "--- Check 10: pipeline conformance (D-series) ---"

# D2: ac-pipeline-builder conformance checklist has both ticked items with their
# "(this sweep, 2026-07-03)" annotation — content match, not line numbers.
check
D2_COUNT=$(grep -c "this sweep, 2026-07-03" "$AC_ROOT/skills/ac-pipeline-builder/SKILL.md" 2>/dev/null || echo 0)
if [ "$D2_COUNT" -lt 2 ]; then
  fail "D2: skills/ac-pipeline-builder/SKILL.md expected >=2 '(this sweep, 2026-07-03)' ticks, found $D2_COUNT"
fi

# D3: zero _backlog/{version} occurrences in ac-plan-init/SKILL.md
check
if grep -q '_backlog/{version}' "$AC_ROOT/skills/ac-plan-init/SKILL.md" 2>/dev/null; then
  fail "D3: skills/ac-plan-init/SKILL.md still contains '_backlog/{version}'"
fi

# D4: ac-beadify plan-status gate — allowed-status set (approved/loop-ready/refined)
# AND a STOP semantic for anything else.
check
BEADIFY_MD="$AC_ROOT/skills/ac-beadify/SKILL.md"
if ! { grep -q '`approved`' "$BEADIFY_MD" 2>/dev/null \
    && grep -q '`loop-ready`' "$BEADIFY_MD" 2>/dev/null \
    && grep -q '`refined`' "$BEADIFY_MD" 2>/dev/null \
    && grep -qi 'STOP condition' "$BEADIFY_MD" 2>/dev/null; }; then
  fail "D4: skills/ac-beadify/SKILL.md missing the approved/loop-ready/refined status gate or its STOP semantic"
fi

# D5: ac-plan-lab (merged genius+alien plan skill, 2026-07-20) carries the write-back
# section (Write Back header, or the genius_reviewed/transcended frontmatter flags).
for d5_skill in ac-plan-lab; do
  check
  d5_target="$AC_ROOT/skills/$d5_skill/SKILL.md"
  if ! grep -qE "Write Back|genius_reviewed|transcended" "$d5_target" 2>/dev/null; then
    fail "D5: skills/$d5_skill/SKILL.md missing write-back section (Write Back / genius_reviewed / transcended)"
  fi
done

# D6: zero stale "pre-merge gate" claims ABOUT LAND in ac-implement + ac-merge.
# "pre-merge gate" legitimately appears describing review as the sole gate — filter
# those out (lines with "NOT a pre-merge gate" or "sole pre-merge gate" nearby) and
# only fail on a leftover line that mentions land AND pre-merge gate unqualified.
check
D6_BAD=$(grep -hn "pre-merge gate" "$AC_ROOT/skills/ac-implement/SKILL.md" "$AC_ROOT/skills/ac-merge/SKILL.md" 2>/dev/null \
  | grep -i "land" \
  | grep -vi "NOT a pre-merge gate\|sole pre-merge gate\|review is the pre-merge gate\|runs AFTER" || true)
if [ -n "$D6_BAD" ]; then
  fail "D6: stale 'land is a pre-merge gate' claim found: $D6_BAD"
fi

# D7: zero "Version bump scans commits" in ac-merge/SKILL.md
check
if grep -q "Version bump scans commits" "$AC_ROOT/skills/ac-merge/SKILL.md" 2>/dev/null; then
  fail "D7: skills/ac-merge/SKILL.md still contains stale 'Version bump scans commits' claim"
fi

# D8: version-bump.md contains the sole-owner statement AND ac-distribute defers to it.
check
if ! grep -qi "sole.*owner" "$AC_ROOT/skills/ac-merge/references/version-bump.md" 2>/dev/null; then
  fail "D8: skills/ac-merge/references/version-bump.md missing the sole-owner statement"
fi
check
if ! grep -qi "defer" "$AC_ROOT/skills/ac-distribute/SKILL.md" 2>/dev/null; then
  fail "D8: skills/ac-distribute/SKILL.md missing defer-to-ac-merge language"
fi

# D9 retired (trunk-direct migration, epic bd-u2lo1, bd-u2lo1.3): the allocator
# script (`_shared/scripts/allocate-wave-branch.sh`) it checked is deleted —
# ac-implement no longer allocates wave branches (bd-u2lo1.6) and ac-loop no
# longer calls the allocator either (bd-u2lo1.7). D9b (below) is the surviving
# check for stale `wave/` branch-naming assumptions.

# D9b: zero startswith("wave/") in ac-loop/SKILL.md
check
if grep -q 'startswith("wave/")' "$AC_ROOT/skills/ac-loop/SKILL.md" 2>/dev/null; then
  fail "D9b: skills/ac-loop/SKILL.md still contains stale 'startswith(\"wave/\")' pattern"
fi

# D10 (WS6, bd-brv39.6): ac-human-session Phase 4 Three Tiers render documents
# tier-first, then oldest-within-tier ordering (age dimension). Discriminating
# phrase — bare "oldest|age|created_at" substring-false-matches tri-AGE/st-AGE-d.
check
if ! grep -qE "oldest-first|oldest-within|oldest-bead-first" "$AC_ROOT/skills/ac-human-session/SKILL.md" 2>/dev/null; then
  fail "D10: skills/ac-human-session/SKILL.md missing the tier-first/oldest-within-tier age-ordering note (Phase 4 render)"
fi

# ---------------------------------------------------------------------------
# Check 11 — pipeline conformance (G-series doctrine landings)
# ---------------------------------------------------------------------------
echo "--- Check 11: pipeline conformance (G-series) ---"

# G1: cross-cadence schedule table present in ac-pipeline-builder
check
if ! grep -qE "23:00|Cross-cadence" "$AC_ROOT/skills/ac-pipeline-builder/SKILL.md" 2>/dev/null; then
  fail "G1: skills/ac-pipeline-builder/SKILL.md missing the cross-cadence schedule table"
fi

# G2: reverse shape-check present in ac-bead-capture (routing-to-backlog language)
check
if ! grep -qi "backlog" "$AC_ROOT/skills/ac-bead-capture/SKILL.md" 2>/dev/null; then
  fail "G2: skills/ac-bead-capture/SKILL.md missing the reverse shape-check routing-to-backlog language"
fi

# G4: QA-freshness equivalence rule present in ac-distribute
check
if ! grep -q "fast-forward-equivalent" "$AC_ROOT/skills/ac-distribute/SKILL.md" 2>/dev/null; then
  fail "G4: skills/ac-distribute/SKILL.md missing the fast-forward-equivalent QA-freshness rule"
fi

# G5: VERDICT-read step present in ac-loop (moved there by the universal-merge
# refactor 432517e — the loop reads ac-review's VERDICT before invoking ac-merge;
# ac-merge itself no longer performs the read)
check
if ! grep -q "VERDICT" "$AC_ROOT/skills/ac-loop/SKILL.md" 2>/dev/null; then
  fail "G5: skills/ac-loop/SKILL.md missing the VERDICT read step (review->merge gate)"
fi

# G6 (Wave-B bd-brv39.2): ac-land's inline Apply-Approved-Upgrades path EMITS a
# skill-hotfix:-prefixed commit for the approved-upgrade case (conditional; routine
# compound stays chore:), so dream's Phase 5 dedupe can grep it across target classes.
check
if ! grep -q "skill-hotfix:" "$AC_ROOT/skills/ac-land/SKILL.md" 2>/dev/null; then
  fail "G6: skills/ac-land/SKILL.md missing the skill-hotfix: emit instruction for the approved-upgrade apply case"
fi

# G7 (Wave-B bd-brv39.5): ac-land 1c UI suite RETIRED; ac-implement deferral re-pointed to
# BOTH owners; ac-pipeline-builder ledger reconciled (doctrine-honesty — 1b test:all stays live).
# G7a: the 1c UI Validation Suite block is gone from ac-land.
check
if grep -qF "1c. UI Validation Suite" "$AC_ROOT/skills/ac-land/SKILL.md" 2>/dev/null; then
  fail "G7a: skills/ac-land/SKILL.md still contains the retired '1c. UI Validation Suite' block"
fi
# G7b: ac-implement's UI-validation deferral names BOTH new owners (batch-close smoke + qa-browser crawl).
check
if ! { grep -qF "ac-batch-close" "$AC_ROOT/skills/ac-implement/SKILL.md" 2>/dev/null \
    && grep -qF "ac-qa-browser" "$AC_ROOT/skills/ac-implement/SKILL.md" 2>/dev/null; }; then
  fail "G7b: skills/ac-implement/SKILL.md UI-validation deferral must name both owners (ac-batch-close + ac-qa-browser)"
fi
# G7c: ac-pipeline-builder QA-placement checkbox marked DONE.
check
if ! grep -qF "[x] **QA placement**" "$AC_ROOT/skills/ac-pipeline-builder/SKILL.md" 2>/dev/null; then
  fail "G7c: skills/ac-pipeline-builder/SKILL.md QA-placement checkbox not marked DONE ([x])"
fi
# G7d (doctrine-honesty): the 1b test:all land-refocus sub-item stays LIVE — NOT marked done/retired.
check
if ! grep -qF "STILL-LIVE" "$AC_ROOT/skills/ac-pipeline-builder/SKILL.md" 2>/dev/null; then
  fail "G7d: skills/ac-pipeline-builder/SKILL.md 1b test:all must remain a live/pending land-refocus item (not marked done/retired)"
fi

# ---------------------------------------------------------------------------
# Check 12 — deployed-app conformance (C-series)
# ---------------------------------------------------------------------------
echo "--- Check 12: deployed-app conformance (C-series) ---"

# Probes deployed apps' every-prompt context (hook files + AGENTS.md) for dead
# pipeline/skill/tool names left behind by the doctrine-landing sweep. Reuses the
# CONSUMER_DIRS union Check 7 built above (org-level dirs ∪ ac-deploy-targets.list
# apps) — still in scope, not recomputed. Each consumer dir IS the app's .claude/
# (or org-level .claude/); app root = its parent. Scope is deliberately narrow —
# only the three named every-prompt files — so this never fires on documentation
# (lint.sh's own dead-pattern lists, BCA's _plans/research write-ups, etc.) that
# legitimately mentions these strings as history/examples rather than live guidance.
C1_PATTERN='/ac/bead-work|/ac/wave-merge|/ac/backlog-add|/ac/bead-land|/ac/work-review'
C2_PATTERN='cass search'
C3_PATTERN='bead-work|wave-merge'

for dir in "${CONSUMER_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  app_root="$(dirname "$dir")"

  # C1 + C2: hook files under the consumer's own hooks/ dir, and its .codex/hooks/
  # twin where present (synced alongside .claude/ for some consumers, e.g. BCA).
  for hooks_dir in "$dir/hooks" "$app_root/.codex/hooks"; do
    wr="$hooks_dir/workflow-reminder.md"
    if [ -f "$wr" ]; then
      check
      if grep -qE "$C1_PATTERN" "$wr" 2>/dev/null; then
        fail "C1: ${wr#$HOME/} still contains dead pipeline command name(s)"
      fi
    fi

    dr="$hooks_dir/delegation-reminder.md"
    if [ -f "$dr" ]; then
      check
      if grep -qE "$C2_PATTERN" "$dr" 2>/dev/null; then
        fail "C2: ${dr#$HOME/} still contains dead delegation tool name(s)"
      fi
    fi
  done

  # C3: AGENTS.md at the app root (parent of .claude/).
  agents_md="$app_root/AGENTS.md"
  if [ -f "$agents_md" ]; then
    check
    if grep -qE "$C3_PATTERN" "$agents_md" 2>/dev/null; then
      fail "C3: ${agents_md#$HOME/} still contains dead pipeline stage name(s)"
    fi
  fi
done

# ---------------------------------------------------------------------------
# Check 13 — Skill registry: description budget + invocation-graph rule
# (validate-skill.sh --registry: total vs the deployed skillListingBudgetFraction
#  budget, per-skill 1024-char cap, and the hard rule that no skill flagged
#  disable-model-invocation is invoked from another skill's body. The graph is
#  recomputed from the files on every run — never maintained by memory.)
# ---------------------------------------------------------------------------
echo "--- Check 13: skill registry (budget + invocation graph) ---"
check
if ! bash "$AC_ROOT/skills/skill-builder/scripts/validate-skill.sh" --registry "$AC_ROOT/skills" > /tmp/ac-lint-registry.out 2>&1; then
  fail "Check 13: skill-registry validation (budget / >1024 desc / invocation-graph) — details: /tmp/ac-lint-registry.out"
fi

# ---------------------------------------------------------------------------
# Check 14 — no-net-growth (diff-aware, HARD, PER-FILE) on skills/**/SKILL.md
# (skill-diet WS2, bead ac-q6e.2: the enforcement chokepoint that makes shrinkage
#  the default for SKILL.md content — see skills/skill-builder/references/
#  promotion-ladder.md + token-economics.md. This is the PRIMARY shrink
#  mechanism (Check 15's line ceilings are a coarse backstop, not the ratchet).
#  Judged PER FILE, not as a corpus sum: each skills/*/SKILL.md's own net line
#  delta vs a base ref must be <=0 (neutral/shrinking) to PASS. A file's own
#  net growth PASSes only if THAT file's own diff carries an added-line
#  `<!-- net-growth-ok: <reason> -->` stamp, else HARD FAILs. Per-file scoping
#  closes the corpus-sum loophole where a big file's shrink could offset a
#  small file's unstamped growth ("rob Peter to pay Paul") — every file holds
#  or shrinks on its own, or proves its own exception. Supersedes the old
#  WARN-only absolute-size check removed from validate-skill.sh — that check
#  judged a file in isolation-at-a-point-in-time and never blocked; this one
#  judges the CHANGE per file and blocks it.
#
#  TWO LEGS (bd-oxmsf, 2026-07-29). Leg 1 = this registry. Leg 2 = every deploy
#  target's own REAL (non-symlink) `.claude/skills/*/SKILL.md`, judged in that
#  target's own repo against that repo's own default branch. Rationale: a skill
#  that reaches an app as a symlink into here is covered by leg 1, but a
#  target-LOCAL skill directory was covered by NOTHING — no app has a net-growth
#  check of its own (no .husky/, package.json or workflow carries one). The blind
#  spot sat exactly where local customisation happens, and it reported green:
#  body-compass-app's local curate-foods/SKILL.md reached 611 lines across three
#  unstamped growth events before a manual demotion caught it. Same judge
#  (nng_scan) for both legs by construction — a second copy of the loop would
#  drift from the first, which is how leg 2 came to be missing in the first place.
#  Proof harness: scripts/lint-net-growth.test.sh — run it after editing either leg.)
# ---------------------------------------------------------------------------
echo "--- Check 14: no-net-growth (SKILL.md — registry + deploy-target-local) ---"

# The per-file judge, used by BOTH legs. Appends "<label>/<path> (+net)" to
# NNG_VIOLATIONS for every net-positive file whose own diff lacks the stamp.
# Args: <repo root> <label> <merge base> <pathspec>
# `--no-optional-locks` throughout: leg 2 reads OTHER live app checkouts, and a
# lint run must never touch another repo's index (a sibling agent may be mid-edit).
NNG_VIOLATIONS=()
nng_scan() {
  local nng_repo="$1" nng_label="$2" nng_base="$3" nng_spec="$4"
  local nng_add nng_del nng_path nng_net nng_file_diff nng_stamp nng_seen=0
  while IFS=$'\t' read -r nng_add nng_del nng_path; do
    [ -n "$nng_add" ] || continue
    [ "$nng_add" = "-" ] && continue   # binary numstat marker; SKILL.md is never binary
    nng_seen=1
    nng_net=$(( nng_add - nng_del ))
    if [ "$nng_net" -le 0 ]; then
      echo "no-net-growth: $nng_label/$nng_path net $nng_net line(s) vs $nng_base — PASS (neutral or shrinking)"
      continue
    fi
    nng_file_diff=$(git --no-optional-locks -C "$nng_repo" diff "$nng_base" -- "$nng_path" 2>/dev/null || true)
    nng_stamp=$(printf '%s\n' "$nng_file_diff" | grep -E '^\+[^+].*net-growth-ok:' || true)
    if [ -n "$nng_stamp" ]; then
      echo "no-net-growth: $nng_label/$nng_path net +$nng_net line(s) but carries its OWN net-growth-ok stamp — PASS"
      printf '%s\n' "$nng_stamp" | sed 's/^/  /'
    else
      NNG_VIOLATIONS+=("$nng_label/$nng_path (+$nng_net)")
    fi
  done < <(git --no-optional-locks -C "$nng_repo" diff --numstat "$nng_base" -- "$nng_spec" 2>/dev/null || true)
  # Name the pathspec, not just the repo: one repo can hold several consumer dirs
  # ($HOME/Repos holds four), and a bare repo label would print an identical line for
  # each — indistinguishable, so a silently mis-scoped leg would look like coverage.
  [ "$nng_seen" -eq 1 ] || echo "no-net-growth: $nng_label — no changes under '$nng_spec' vs $nng_base — PASS (nothing to check)"
}

# Resolve a repo's own default-branch ref: origin/HEAD first (art-still-app and
# unsit-app default to master, and $HOME/Repos carries BOTH origin/main and a
# stale origin/master), then the explicit candidates. Empty = unresolvable.
nng_base_of() {
  local nng_r="$1" nng_ref nng_c
  nng_ref=$(git --no-optional-locks -C "$nng_r" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)
  if [ -z "$nng_ref" ]; then
    for nng_c in "$NNG_BASE_REF" origin/main origin/master; do
      if git --no-optional-locks -C "$nng_r" rev-parse --verify --quiet "$nng_c" >/dev/null 2>&1; then
        nng_ref="$nng_c"; break
      fi
    done
  fi
  [ -n "$nng_ref" ] || return 0
  git --no-optional-locks -C "$nng_r" merge-base "$nng_ref" HEAD 2>/dev/null || true
}

check

NNG_BASE_REF="${NNG_BASE_REF:-origin/main}"
NNG_MERGE_BASE=""
if git -C "$AC_ROOT" rev-parse --verify --quiet "$NNG_BASE_REF" >/dev/null 2>&1; then
  NNG_MERGE_BASE=$(git -C "$AC_ROOT" merge-base "$NNG_BASE_REF" HEAD 2>/dev/null || true)
fi

if [ -z "$NNG_MERGE_BASE" ]; then
  # Degrade gracefully: a shallow CI checkout (actions/checkout@v4 default
  # fetch-depth: 1) or a standalone clone may not have this ref locally. A
  # false-green here is safer than a broken CI leg — Check 13's absolute
  # budget total still bounds unbounded growth regardless of diff
  # availability; this check adds diff-awareness on top when it can resolve
  # a base, never blocks the whole lint leg when it can't.
  echo "NOTICE: Check 14 leg 1 skipped — base ref '$NNG_BASE_REF' unresolvable (shallow checkout, standalone clone, or no fetch of it) — no-net-growth not enforced for the registry this run."
else
  nng_scan "$AC_ROOT" "agent-compounds" "$NNG_MERGE_BASE" 'skills/*/SKILL.md'
fi

# Leg 2 — deploy-target-LOCAL skills. CONSUMER_DIRS (built in Check 7) is the same
# org-dirs ∪ ac-deploy-targets.list union, so a newly added target is covered with no
# re-stamp here. A git pathspec can never traverse a symlinked dir, so this leg sees
# ONLY real local SKILL.md files — exactly the blind spot, and no double-counting of
# the symlinked majority leg 1 already judges.
for dir in "${CONSUMER_DIRS[@]}"; do
  [ -d "$dir/skills" ] || continue
  nng_local=$(/usr/bin/find "$dir/skills" -maxdepth 2 -name SKILL.md -type f 2>/dev/null || true)
  [ -n "$nng_local" ] || continue           # all skills symlinked here → leg 1 covers them
  nng_repo=$(git --no-optional-locks -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)
  [ -n "$nng_repo" ] || continue            # not a git checkout → nothing to diff
  [ "$nng_repo" = "$AC_ROOT" ] && continue  # the registry itself — leg 1 already did it
  check
  nng_label="${nng_repo##*/}"
  nng_rel="${dir#$nng_repo/}"
  nng_base=$(nng_base_of "$nng_repo")
  if [ -z "$nng_base" ]; then
    echo "NOTICE: Check 14 leg 2 skipped for $nng_label — no resolvable default-branch ref — its local SKILL.md files are NOT net-growth checked this run."
    continue
  fi
  nng_scan "$nng_repo" "$nng_label" "$nng_base" "$nng_rel/skills/*/SKILL.md"
  # A real-but-UNTRACKED local skill is invisible to a diff (public targets gitignore
  # their whole harness layer — AGENTS.md § Public repos). Name it rather than let the
  # leg read green over a file it structurally cannot see.
  while IFS= read -r nng_f; do
    [ -n "$nng_f" ] || continue
    nng_rf="${nng_f#$nng_repo/}"
    git --no-optional-locks -C "$nng_repo" ls-files --error-unmatch -- "$nng_rf" >/dev/null 2>&1 && continue
    echo "NOTICE: no-net-growth: $nng_label/$nng_rf is UNTRACKED/gitignored ($(( $(wc -l < "$nng_f") )) lines) — real local skill, not diff-checkable there."
  done <<< "$nng_local"
done

# One verdict over BOTH legs. The message names the EXACT token, because the
# near-miss is real: bd-curate-…xu5tz's own AC asked for an `evidence:` comment, and
# implementing it literally would have produced a "stamp" this grep does not see.
if [ "${#NNG_VIOLATIONS[@]}" -gt 0 ]; then
  fail "no-net-growth: net-positive SKILL.md file(s) without their OWN net-growth-ok stamp: $(IFS=', '; echo "${NNG_VIOLATIONS[*]}") — move content to references/, or add an ADDED line to the growing file's own diff carrying the EXACT token <!-- net-growth-ok: <reason> --> (the literal string 'net-growth-ok:' is what is grepped: an 'evidence:'/'why:' comment does NOT count, and a shrink in another file does NOT offset it)."
fi

# ---------------------------------------------------------------------------
# Check 15 — post-pilot line ceilings (skill-diet WS2b, bead ac-q6e.5)
# ---------------------------------------------------------------------------
# These are a COARSE BACKSTOP for outliers and brand-new large skills —
# SECONDARY to Check 14's per-file no-net-growth ratchet, which is the
# PRIMARY control (every SKILL.md holds-or-shrinks, or proves its own
# exception). A ceiling only catches a skill that was already too big when it
# first crossed the line (or one whose growth is stamped-exempt from Check
# 14); it does nothing to stop incremental creep in an already-under-ceiling
# file — Check 14 is what does that, on every single change.
#
# Conductor-tier ceiling: each of the 6 ratified pipeline-conductor skills'
# SKILL.md must be <= CONDUCTOR_CEILING lines. HARD FAIL if any exceeds.
#
# Derivation: the W3.2 pilot dieted+wired ac-loop to a live-run-accepted GREEN
# operating core of 963 lines. The conductor-tier ceiling = that measured size
# + ~15% headroom = 963 x 1.15 ~= 1107 -> 1110 (clean round-up). Post-W3.2-pilot,
# live-run-accepted 2026-07-21. This is a MEASURED ceiling (from a shipped skill),
# not an aspirational one — it locks in the pilot's proven size as the cap.
#
# Standard-tier ceiling: PROVISIONAL ratchet (not measured-from-pilot like the
# conductor ceiling above). Derived as: largest standard-tier skill today
# (ac-hygiene, 664 lines) x 1.15 headroom ~= 764 -> 770 (clean round-up). This
# locks in "no worse than today's largest standard skill" as a floor-first
# ratchet; lower it as standard skills get dieted post-pilot (do not raise it
# to accommodate a bloated skill — diet the skill instead).
CONDUCTOR_CEILING=1110
STANDARD_CEILING=770

CONDUCTOR_SKILLS=(
  "ac-loop"
  "ac-implement"
  "ac-review"
  "ac-batch-close"
  "ac-merge"
  "ac-land"
)

echo "--- Check 15: post-pilot line ceilings ---"
echo "conductor-tier ceiling: ${CONDUCTOR_CEILING} lines (ac-loop 963 +15%, post-W3.2-pilot, live-run-accepted 2026-07-21)"
check
for cskill in "${CONDUCTOR_SKILLS[@]}"; do
  cskill_path="$AC_ROOT/skills/$cskill/SKILL.md"
  if [ ! -f "$cskill_path" ]; then
    fail "Check 15: conductor skill '$cskill' has no SKILL.md at ${cskill_path#$AC_ROOT/}"
    continue
  fi
  cskill_lines=$(wc -l < "$cskill_path" | tr -d ' ')
  if [ "$cskill_lines" -gt "$CONDUCTOR_CEILING" ]; then
    fail "Check 15: conductor '$cskill' SKILL.md is ${cskill_lines} lines > ${CONDUCTOR_CEILING} ceiling (diet it or move content to references/)"
  else
    printf '  PASS  %-16s %5s / %s lines\n' "$cskill" "$cskill_lines" "$CONDUCTOR_CEILING"
  fi
done
echo "standard-tier ceiling: ${STANDARD_CEILING} lines (ac-hygiene 664 +15%, provisional ratchet — lower as standard skills get dieted)"
check
for sskill_path in "$AC_ROOT"/skills/*/SKILL.md; do
  [ -f "$sskill_path" ] || continue
  sskill_name=$(basename "$(dirname "$sskill_path")")

  is_conductor=false
  for cskill in "${CONDUCTOR_SKILLS[@]}"; do
    if [ "$sskill_name" = "$cskill" ]; then
      is_conductor=true
      break
    fi
  done
  [ "$is_conductor" = true ] && continue

  if grep -q '^accessory: true' "$sskill_path" 2>/dev/null; then
    continue
  fi

  sskill_lines=$(wc -l < "$sskill_path" | tr -d ' ')
  if [ "$sskill_lines" -gt "$STANDARD_CEILING" ]; then
    fail "Check 15: standard skill '$sskill_name' SKILL.md is ${sskill_lines} lines > ${STANDARD_CEILING} ceiling (diet it or move content to references/)"
  else
    printf '  PASS  %-16s %5s / %s lines\n' "$sskill_name" "$sskill_lines" "$STANDARD_CEILING"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "lint: ${CHECKS} checks, ${FAILURES} failures"

[ "$FAILURES" -eq 0 ]
