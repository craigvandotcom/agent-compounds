#!/usr/bin/env bash
#
# lint.sh — registry self-lint for agent-compounds. The front door every caller
# runs (ruled 2026-09-06: redesigned, never deleted).
#
# Mechanizes the 2026-06-11 audit's checkable invariants.
#
# Usage:  ./lint.sh                 full scan: every un-ported bash block, then
#                                   the v2 runner (lint/run.py) over lint/checks/
#         ./lint.sh --check <id>    ONLY the named v2 check (repeatable)
#         ./lint.sh --changed       only v2 checks whose scope touches the diff
#         ./lint.sh --json          v2 results as JSON
#         ./lint.sh --help
#
# Flags select the RUNNER ONLY — they skip the un-ported bash blocks, so a
# scoped run stays scoped (and a probe on --check <id> cannot be forged by a
# sibling's uncommitted edit elsewhere in the shared tree). A bare invocation
# runs everything: the full bash suite first, then the runner.
#
# Exit 0  all executed checks pass
# Exit 1  one or more checks failed (each reported as FAIL: ...)
# Exit 2  NOT-GATED — a check scanned zero files (verified nothing), or the
#         interpreter is below Python 3.12. Never a pass.
#
# Style-matched to deploy.sh (same repo).

set -uo pipefail

AC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

require_py312() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "NOT-GATED: python3 not found — the lint runner cannot run, so nothing can be verified" >&2
    exit 2
  fi
  if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' 2>/dev/null; then
    echo "NOT-GATED: python3 3.12+ required (found $(python3 -V 2>&1)) — the lint runner refuses to run on an older interpreter" >&2
    exit 2
  fi
}

# --- front-door flag parsing -------------------------------------------------
RUNNER_ARGS=()
RUNNER_MODE=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    --changed|--json) RUNNER_ARGS+=("$1"); RUNNER_MODE=1; shift ;;
    --check)    [ $# -ge 2 ] || { echo "lint.sh: --check requires an id" >&2; exit 2; }
                RUNNER_ARGS+=("$1" "$2"); RUNNER_MODE=1; shift 2 ;;
    --check=*)  RUNNER_ARGS+=("--check" "${1#--check=}"); RUNNER_MODE=1; shift ;;
    *)          echo "lint.sh: unknown argument '$1' (usage: ./lint.sh --help)" >&2; exit 2 ;;
  esac
done

require_py312

# Repo-root check: the front door resolves its own checkout, and the runner the
# exec hands to must exist there — a partial checkout would silently scan nothing.
if [ ! -f "$AC_ROOT/lint/run.py" ]; then
  echo "NOT-GATED: $AC_ROOT/lint/run.py missing — this checkout is incomplete; the v2 runner cannot verify anything" >&2
  if [ "$RUNNER_MODE" = 1 ]; then exit 2; fi
fi

if [ "$RUNNER_MODE" = 1 ]; then
  exec python3 "$AC_ROOT/lint/run.py" "${RUNNER_ARGS[@]}" --root "$AC_ROOT"
fi

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
  # `run /ac-plan first` / `Run /ac-plan ` were dead while the planner was ac-plan-init. After
  # the ac2->ac rename, ac-plan IS the planner and those strings are correct. Retired 2026-09-02.
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

# SCOPE: this pattern is `/ac-[a-z]...`. Since the pipeline rename it matches the WHOLE
# pipeline family — the former blind spot (invocations of the old prefixed family,
# invisible here and resolved by Check 23 instead) no longer exists. Do not widen the
# regex without re-reading that history — one engine per pattern.

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
    # An INVOCATION is `/ac-<name>` at line start or after a non-path character (space,
    # quote, backtick, bracket). Preceded by a letter, digit, dot or slash it is a PATH
    # SEGMENT — `/tmp/ac-claim.txt`, `scripts/ac-budget-check.sh`, `_archive/skills/ac-loop/`
    # — and naming a file is not invoking a skill. The earlier fix stripped one known prefix;
    # that enumerated a false positive instead of stating the rule, and six more appeared.
    # ...and it is TERMINAL: never followed by `/` or `:`. `/ac-example-bead:start` is a sed
    # address, `<git-common-dir>/ac-flight/` is a directory. Match one trailing char and strip it.
    tokens=$(grep -oE '(^|[^A-Za-z0-9_./-])/ac-[a-z][a-z-]*[a-z]([^A-Za-z0-9_/:-]|$)' "$f" 2>/dev/null \
             | sed -E 's|^[^/]||; s|[^a-z]$||' || true)
    if [ -n "$tokens" ]; then
      ALL_AC_TOKENS="${ALL_AC_TOKENS}
${tokens}"
    fi
    # collect tokens that appear as glob prefixes: /ac-<name>-*
    globs=$(grep -oE '(^|[^A-Za-z0-9_./-])/ac-[a-z][a-z-]*[a-z]-\*' "$f" 2>/dev/null \
             | sed -E 's|^[^/]||; s/-\*$//' || true)
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

# Every column-0 frontmatter key the registry actually uses. Census over all
# SKILL.md at the time of writing: name (58) · description (58) ·
# disable-model-invocation (3) · tools (2) · accessory (2). Nothing else.
# Escape hatch for a genuinely new key: add it HERE, in the same commit that
# introduces it — a reviewable one-line diff instead of a silent widening.
FM_ALLOWED_KEYS="name description accessory tools disable-model-invocation"

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

  # Frontmatter BLOCK INTEGRITY. The two presence greps above are blind to
  # corruption INSIDE the block: a prose sentence mis-inserted between name: and
  # description: is invalid YAML but still leaves both greps green.
  # Invariant: SKILL.md is a regular file (never a symlink — a symlinked SKILL.md
  # would have an out-of-tree target's content scanned and echoed into a failure
  # message); the block opens with `---` on line 1, closes at the next `---`; every
  # non-blank line between is a YAML mapping entry (`key:` at column 0) or an
  # indented continuation/list line BELOW a mapping entry. Key COUNT and IDENTITY
  # are deliberately NOT constrained — six skills legitimately carry extra keys
  # (accessory:, disable-model-invocation:, tools:), and in ac-idea-lab those extra
  # keys sit BETWEEN name: and description(:) — the same position the real
  # corruption took — so line position is not a valid discriminator.
  # Key-shape-vs-prose is, PROVIDED the test is an ALLOWLIST (FM_ALLOWED_KEYS
  # above) rather than a shape regex. A shape test admits any single lowercase
  # word plus a colon — `todo: fix this`, `note: see below` — which is the same
  # prose-corruption class this check exists to catch; the allowlist fails those
  # closed. It is also fork-free: a shell `case` membership test, not a
  # `printf | grep` pipeline per frontmatter line (Check 3 was ~360 forks/run).
  check
  fm_err=""
  fm_closed=false
  fm_seen_key=false
  if [ -L "$skill_md" ]; then
    fm_err="SKILL.md is a symlink — must be a regular file"
  elif [ "$(sed -n '1p' "$skill_md")" != "---" ]; then
    fm_err="line 1 is not '---' — no frontmatter block"
  else
    fm_lineno=1
    # `|| [ -n "$fm_line" ]` — a final line with no trailing newline is still a
    # line; a bare `read` returns 1 there and would drop it silently.
    while IFS= read -r fm_line || [ -n "$fm_line" ]; do
      fm_lineno=$(( fm_lineno + 1 ))
      if [ "$fm_line" = "---" ]; then
        fm_closed=true
        break
      fi
      # blank / whitespace-only: skip
      [ -z "${fm_line//[[:space:]]/}" ] && continue
      # indented continuation or list item: legal YAML only BELOW a mapping entry
      case "$fm_line" in
        [[:space:]]*)
          if [ "$fm_seen_key" != true ]; then
            fm_err="line ${fm_lineno} is indented with no mapping entry above it: ${fm_line:0:80}"
            break
          fi
          continue
          ;;
      esac
      case "$fm_line" in
        *:*) : ;;
        *)
          fm_err="line ${fm_lineno} is not a YAML mapping entry: ${fm_line:0:80}"
          break
          ;;
      esac
      # Membership, not shape. `${fm_line%%:*}` is the text left of the first
      # colon; a prefix of a real key (`tool:` vs `tools:`) fails closed.
      case " $FM_ALLOWED_KEYS " in
        *" ${fm_line%%:*} "*)
          fm_seen_key=true
          ;;
        *)
          fm_err="line ${fm_lineno} is not a known frontmatter key (allowed: ${FM_ALLOWED_KEYS}): ${fm_line:0:80}"
          break
          ;;
      esac
    done < <(tail -n +2 "$skill_md")
    if [ -z "$fm_err" ] && [ "$fm_closed" != true ]; then
      fm_err="frontmatter block opened at line 1 is never closed by a '---'"
    fi
  fi
  if [ -n "$fm_err" ]; then
    fail "skills/$skill_name/SKILL.md: frontmatter block integrity — $fm_err"
  fi
done

# agents/*.md must have name: == filename (sans .md), a valid model tier, and no
# concrete model: (tier is the canon — models are stamped per harness by deploy.sh /
# harness-sync.sh generators from harnesses.*.agent_models)
VALID_TIERS="orchestrator coordinator worker"
for agent_file in "$AC_ROOT/agents"/*.md "$AC_ROOT/agents"/review/*.md; do
  [ -f "$agent_file" ] || continue
  agent_name=$(basename "$agent_file" .md)

  check
  name_val=$(grep -m1 '^name:' "$agent_file" 2>/dev/null | sed 's/^name:[[:space:]]*//')
  if [ "$name_val" != "$agent_name" ]; then
    fail "agents/$agent_name.md: name '$name_val' != filename '$agent_name'"
  fi

  check
  tier_val=$(grep -m1 '^tier:' "$agent_file" 2>/dev/null | sed 's/^tier:[[:space:]]*//')
  if [ -z "$tier_val" ]; then
    fail "agents/$agent_name.md: no 'tier:' — every registry agent must declare one"
  elif ! printf '%s\n' $VALID_TIERS | grep -qx "$tier_val"; then
    fail "agents/$agent_name.md: tier '$tier_val' not in {$VALID_TIERS}"
  fi

  check
  if grep -q '^model:' "$agent_file"; then
    fail "agents/$agent_name.md: 'model:' is forbidden in the registry — declare 'tier:' and let harnesses.json agent_models resolve it per harness"
  fi
done

# every tier an agent uses must be resolvable in each harness's agent_models map —
# otherwise deploy.sh / gen_opencode_agents fail loud at sync time instead of lint time
for h in claude opencode; do
  check
  for t in $VALID_TIERS; do
    v=$(jq -r ".harnesses.$h.agent_models.$t // empty" "$AC_ROOT/harnesses.json" 2>/dev/null)
    [ -n "$v" ] || fail "harnesses.json: harnesses.$h.agent_models.$t missing (tier maps must be complete per harness)"
  done
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
    # Gitignored diagram paths (_plans — local-only by design, public repo) exist on
    # working machines but NOT in a bare CI clone: absence there is expected, not a
    # failure (ac-3jy: this exact check held registry-lint CI red on every main push
    # since 07-30 while local runs stayed green).
    # Try both forms: a dir-only ignore rule (`_plans/`) does NOT match the bare name
    # when the directory is absent (CI clone) — the explicit trailing-slash form does.
    if git -C "$AC_ROOT" check-ignore -q "$path" 2>/dev/null || git -C "$AC_ROOT" check-ignore -q "$path/" 2>/dev/null; then
      echo "NOTICE: diagram path '$path' is gitignored (local-only) and absent here — skipped"
    else
      fail "AGENTS.md diagram path missing: $path"
    fi
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
# Check 13 — Skill registry: description budget + invocation-graph rule
# (validate-skill.sh --registry: total vs the deployed skillListingBudgetFraction
#  budget, per-skill 1024-char cap, and the hard rule that no skill flagged
#  disable-model-invocation is invoked from another skill's body. The graph is
#  recomputed from the files on every run — never maintained by memory.)
#
#  The BUDGET leg gets its OWN failure line (bead ac-g2v4). validate-skill.sh exits 1
#  for a budget breach, an over-1024 description and an invocation-graph violation
#  alike, and one generic line cannot tell them apart — so while ANY of the three holds
#  Check 13 red, a newly-introduced budget breach lands silently behind it. The cutover
#  made that concrete: the overlap breach is tolerated by ruling and expires at
#  archival (see validate-skill.sh's archive-before-use note), which only stays safe if a
#  POST-archival breach is still visible as a breach. Grep for the marker, name it
#  separately, and let the generic line follow.
# ---------------------------------------------------------------------------
echo "--- Check 13: skill registry (budget + invocation graph) ---"
check
if ! bash "$AC_ROOT/skills/skill-builder/scripts/validate-skill.sh" --registry "$AC_ROOT/skills" > /tmp/ac-lint-registry.out 2>&1; then
  if grep -q '^registry-description-budget: BREACH' /tmp/ac-lint-registry.out; then
    fail "Check 13 budget: $(grep -m1 '^registry-description-budget: BREACH' /tmp/ac-lint-registry.out) — the always-loaded skill-listing budget is over. Diet descriptions or archive absorbed skills; raising skillListingBudgetFraction is a deliberate, separate decision."
  fi
  fail "Check 13: skill-registry validation (budget / >1024 desc / invocation-graph) — details: /tmp/ac-lint-registry.out"
fi
