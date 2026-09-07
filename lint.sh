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
# Derivation (ORIGIN, 2026-07-21): the W3.2 pilot dieted+wired ac-loop to a
# live-run-accepted GREEN operating core of 963 lines; the conductor-tier ceiling
# = that measured size + ~15% headroom = 963 x 1.15 ~= 1107 -> 1110 (clean
# round-up). That origin is HISTORY, not the live basis: ac-loop has since shrunk
# and the tier maximum is now ac-review. The constant stands as a cap TIGHTER than
# what the tier would derive today — a MEASURED ceiling, never an aspirational one.
#
# Standard-tier ceiling: PROVISIONAL ratchet (not measured-from-pilot like the
# conductor ceiling above). Basis: the largest standard-tier SKILL.md is
# ac-hygiene at 660 lines; 660 x 1.10 = 726 -> 730 (clean round-up). The x1.10
# multiplier is deliberately TIGHTER than the x1.15 the conductor ceiling above
# uses, so each re-measure is a real tightening rather than a restatement.
# Rule for the next ratchet: ceil_to_10(max(standard-tier SKILL.md line counts)
# x 1.10), and it may only ever move DOWN — do not raise it to accommodate a
# bloated skill, diet the skill instead. The ratchet self-check below enforces
# the half a run-time recompute CAN enforce (constant must not exceed derived).
CONDUCTOR_CEILING=1110
STANDARD_CEILING=730

# Phase-4 cutover 2026-08-28: the roster follows the archive set's "Absorbed by" column;
# updated at the pipeline rename: the former prefixed review skill merged INTO ac-review
# as its post-batch mode, so the roster carries ac-review once.
# ac-review is still the tier max (1063 lines), so CONDUCTOR_CEILING is untouched.
CONDUCTOR_SKILLS=(
  "ac-implement"
  "ac-review"
  "ac-publish"
  "ac-land"
)

echo "--- Check 15: post-pilot line ceilings ---"

# Ratchet self-check — ONE-WAY, by construction.
# Recomputes each tier's derived ceiling from the live SKILL.md line counts and
# FAILS when the hand-set constant EXCEEDS it. It is NOT symmetric: a derived
# value LOOSER than the constant is never licence to raise the constant. Real
# monotonicity needs the committed constant as its own high-water mark, which a
# run-time recompute cannot see — so a raise stays a reviewed edit, and this
# check catches the raise that outruns the measured tier. The constant is a
# CACHE of a derived value that may only ever get tighter.
# Integer form of ceil_to_10(max x mult): truncate max*mult to a whole line count,
# then round that up to the next multiple of 10 (660 x1.10 -> 726 -> 730;
# 591 x1.10 -> 650 -> 650; 1101 x1.15 -> 1266 -> 1270).
ratchet_derived() {   # $1 = tier max lines, $2 = multiplier as a percentage
  local rd_raw=$(( $1 * $2 / 100 ))
  echo $(( (rd_raw + 9) / 10 * 10 ))
}
RATCHET_STD_MAX=0; RATCHET_STD_OWNER="(none)"
RATCHET_CON_MAX=0; RATCHET_CON_OWNER="(none)"
# ONE awk pass derives the whole roster (name|lines|tier|accessory) — the per-skill
# basename/dirname/wc/tr/grep forks this loop used to pay scale with the registry's
# growth axis (~1.1s per lint run at ~100 skills, bead ac-kdtg.3). Empty roster ->
# derived ceiling 0 -> the ratchet assert below fails loudly; awk cannot hang on a
# missing glob because the literal pattern reaches it as an unopenable arg.
SKILL_ROSTER=$(awk -v conductors=" ${CONDUCTOR_SKILLS[*]} " '
  FNR == 1 && NR > 1 { printf "%s|%d|%s|%d\n", pname, plines, ptier, pacc }
  FNR == 1 {
    pname = FILENAME
    sub(/\/SKILL\.md$/, "", pname)
    sub(/.*\//, "", pname)
    ptier = "standard"; pacc = 0; plines = 0
  }
  index(conductors, " " pname " ") { ptier = "conductor" }
  /^accessory: true/ { pacc = 1 }
  { plines = FNR }
  END { printf "%s|%d|%s|%d\n", pname, plines, ptier, pacc }
' "$AC_ROOT"/skills/*/SKILL.md)
while IFS='|' read -r rskill_name rskill_lines rskill_tier rskill_acc; do
  if [ "$rskill_tier" = conductor ]; then
    if [ "$rskill_lines" -gt "$RATCHET_CON_MAX" ]; then
      RATCHET_CON_MAX=$rskill_lines; RATCHET_CON_OWNER=$rskill_name
    fi
  elif [ "$rskill_acc" != 1 ]; then
    if [ "$rskill_lines" -gt "$RATCHET_STD_MAX" ]; then
      RATCHET_STD_MAX=$rskill_lines; RATCHET_STD_OWNER=$rskill_name
    fi
  fi
done <<< "$SKILL_ROSTER"
RATCHET_STD_DERIVED=$(ratchet_derived "$RATCHET_STD_MAX" 110)
RATCHET_CON_DERIVED=$(ratchet_derived "$RATCHET_CON_MAX" 115)
check
if [ "$STANDARD_CEILING" -gt "$RATCHET_STD_DERIVED" ]; then
  fail "Check 15: ratchet violated — STANDARD_CEILING (${STANDARD_CEILING}) exceeds derived ceiling (${RATCHET_STD_DERIVED} = ceil_to_10(${RATCHET_STD_MAX} x 1.10), tier max ${RATCHET_STD_OWNER}) — the ratchet moves DOWN only; diet the skill instead of raising the constant"
else
  printf '  PASS  ratchet         STANDARD_CEILING %s <= derived %s = ceil_to_10(%s x 1.10), tier max %s\n' \
    "$STANDARD_CEILING" "$RATCHET_STD_DERIVED" "$RATCHET_STD_MAX" "$RATCHET_STD_OWNER"
fi
check
if [ "$CONDUCTOR_CEILING" -gt "$RATCHET_CON_DERIVED" ]; then
  fail "Check 15: ratchet violated — CONDUCTOR_CEILING (${CONDUCTOR_CEILING}) exceeds derived ceiling (${RATCHET_CON_DERIVED} = ceil_to_10(${RATCHET_CON_MAX} x 1.15), tier max ${RATCHET_CON_OWNER}) — the ratchet moves DOWN only; diet the skill instead of raising the constant"
else
  printf '  PASS  ratchet         CONDUCTOR_CEILING %s <= derived %s = ceil_to_10(%s x 1.15), tier max %s\n' \
    "$CONDUCTOR_CEILING" "$RATCHET_CON_DERIVED" "$RATCHET_CON_MAX" "$RATCHET_CON_OWNER"
fi

echo "conductor-tier ceiling: ${CONDUCTOR_CEILING} lines (W3.2-pilot measured cap, live-run-accepted 2026-07-21; the live tier max is ac-review — see the ratchet line above)"
check
for cskill in "${CONDUCTOR_SKILLS[@]}"; do
  cskill_path="$AC_ROOT/skills/$cskill/SKILL.md"
  # Line count comes from SKILL_ROSTER (one awk pass, no per-skill wc fork).
  cskill_lines=""
  while IFS='|' read -r lnm lln _ltier _lacc; do
    if [ "$lnm" = "$cskill" ]; then cskill_lines=$lln; break; fi
  done <<< "$SKILL_ROSTER"
  if [ -z "$cskill_lines" ]; then
    fail "Check 15: conductor skill '$cskill' has no SKILL.md at ${cskill_path#$AC_ROOT/}"
    continue
  fi
  if [ "$cskill_lines" -gt "$CONDUCTOR_CEILING" ]; then
    fail "Check 15: conductor '$cskill' SKILL.md is ${cskill_lines} lines > ${CONDUCTOR_CEILING} ceiling (diet it or move content to references/)"
  else
    printf '  PASS  %-16s %5s / %s lines\n' "$cskill" "$cskill_lines" "$CONDUCTOR_CEILING"
  fi
done
echo "standard-tier ceiling: ${STANDARD_CEILING} lines (largest standard skill +10%, ratchet-down only — lower as standard skills get dieted)"
check
# Same roster, no per-skill forks: tier and accessory flag were derived in the
# single awk pass above.
while IFS='|' read -r sskill_name sskill_lines sskill_tier sskill_acc; do
  [ "$sskill_tier" = conductor ] && continue
  [ "$sskill_acc" = 1 ] && continue
  if [ "$sskill_lines" -gt "$STANDARD_CEILING" ]; then
    fail "Check 15: standard skill '$sskill_name' SKILL.md is ${sskill_lines} lines > ${STANDARD_CEILING} ceiling (diet it or move content to references/)"
  else
    printf '  PASS  %-16s %5s / %s lines\n' "$sskill_name" "$sskill_lines" "$STANDARD_CEILING"
  fi
done <<< "$SKILL_ROSTER"

# ---------------------------------------------------------------------------
# Check 17 — dcg-blocked shell idioms in published snippets
# ---------------------------------------------------------------------------
echo "--- Check 17: dcg-blocked dynamic-path redirects ---"

# dcg's `core.filesystem:redirect-truncate-dynamic-path` refuses a TRUNCATING redirect whose
# target is shell-expanded — it cannot prove the path before the file is opened O_TRUNC. A
# published snippet prescribing that shape is UNRUNNABLE on this fleet.
#
# Why this check exists (bd-scjgv): bd-5ndzm was closed as Fixed on 2026-07-30 having scoped
# six skills and mechanically fixed exactly ONE. Nothing re-detected the rest, so the class
# read as "fixed" on the board while three separate published snippets still shipped it and
# kept costing conductors live time in Phase 0. The DETECTOR is the deliverable — without it
# the next snippet reintroduces the class and no one learns until someone loses a run.
#
# The discriminator is literal-vs-variable TARGET, not compound-vs-simple command (probed
# against dcg 0.6.7). NOT matched, because all three are allowed:
#   >> "$VAR/path"      appends never truncate
#   >/dev/null          fully-literal target
#   tee "$VAR/path"     tee is not a redirect
# Escape hatch: put `dcg-allow` in a comment on the same line to document the antipattern
# deliberately (shell-guardrails.md does exactly that).
# The `/` is anchored directly after the variable name ON PURPOSE. An earlier form used
# `[^"[:space:]]*/` and matched NOTHING under macOS grep's leftmost-longest semantics (no
# backtracking) — a detector that silently matches nothing is worse than no detector, so
# this pattern is proved red-then-green against fixtures before being trusted.
DCG_BAD_RE='(^|[[:space:]]|[0-9]|&)>[[:space:]]*"?\$\{?[A-Za-z_][A-Za-z0-9_:%+-]*/'

# SCOPE: markdown PRESCRIPTIONS only, deliberately not `*.sh`. dcg intercepts commands an
# agent submits to its Bash tool; a shell script executed as a FILE (`bash foo.sh`) is never
# inspected, so the same shape inside a committed script is not broken and flagging it would
# be a false positive that erodes trust in the check. The risk this guards is a snippet an
# agent COPIES OUT of a skill and runs inline.
dcg_hits=0
dcg_scanned=0
while IFS= read -r f; do
  # Only lines INSIDE ```bash / ```sh fences are prescriptions. Prose naming the antipattern
  # (shell-guardrails.md, and the rationale comments in board-scan.md) must not trip it.
  body=$(awk '/^[[:space:]]*```(bash|sh)[[:space:]]*$/{inb=1;next}
              /^[[:space:]]*```/{inb=0;next}
              inb{print FILENAME":"FNR":"$0}' "$f" 2>/dev/null)
  dcg_scanned=$(( dcg_scanned + 1 ))
  [ -n "$body" ] || continue
  hits=$(printf '%s\n' "$body" | grep -E -- "$DCG_BAD_RE" | grep -v 'dcg-allow' || true)
  [ -n "$hits" ] || continue
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    fail "Check 17: dcg-blocked truncating redirect to a variable path — ${h#$AC_ROOT/}"
    dcg_hits=$(( dcg_hits + 1 ))
  done <<< "$hits"
done < <(find "$AC_ROOT/skills" -type f -name '*.md' 2>/dev/null | sort)

check
if [ "$dcg_scanned" -eq 0 ]; then
  # Zero files scanned accounts for nothing — a broken find reads identical to a clean sweep.
  fail "Check 17: zero files scanned under skills/ — the sweep is vacuous"
elif [ "$dcg_hits" -eq 0 ]; then
  echo "  dcg redirect shapes: 0 violations across ${dcg_scanned} skill files"
fi

# ---------------------------------------------------------------------------
# Check 19 — bead template conformance (what the registry SHIPS)
# ---------------------------------------------------------------------------
echo "--- Check 19: bead template conformance ---"

# Check 18 proves the runtime guard fires on what an agent TYPES. This proves the templates
# the registry ships are themselves conformant — the two are not the same failure. A stale
# template is worse than a mistyped command: it is copied, so it reproduces the defect on
# every future run, and the agent copying it has no reason to doubt it.
#
# The script imports the guard, so the contract has exactly one implementation. Editing one
# to satisfy the other defeats the point — fix the template.
BTL="$AC_ROOT/scripts/bead-template-lint.py"
check
if [ -r "$BTL" ]; then
  if btl_out=$(python3 "$BTL" 2>&1); then
    echo "  all bead templates carry origin: + readiness"
  else
    printf '%s\n' "$btl_out"
    fail "Check 19: non-conforming bead template(s) — see above"
  fi
else
  fail "Check 19: scripts/bead-template-lint.py missing — template conformance unverified"
fi

# ---------------------------------------------------------------------------
# Check 22 — lean-family ledger: control <-> friction referential integrity (ac-cfn4)
# ---------------------------------------------------------------------------
echo "--- Check 22: family ledger integrity ---"

# Check 21 proves a mechanism declares its failure semantics; this proves the lean family's
# controls and its friction ledger still point at each other — every entry cites a receipt
# and the control that treats it (or is explicitly untreated), every control names the
# failure it prevents, and a friction re-observed AFTER its control landed is surfaced as a
# FAILED CONTROL rather than accruing silently. Fails CLOSED: a missing or empty ledger
# exits non-zero carrying NOT-GATED, because an absent sensor is not a clean one.
ALI="$AC_ROOT/scripts/ac-ledger-integrity.sh"
check
if [ -r "$ALI" ]; then
  if ali_out=$(bash "$ALI" "$AC_ROOT" 2>&1); then
    printf '%s\n' "$ali_out" | sed 's/^/  /'
  else
    printf '%s\n' "$ali_out"
    fail "Check 22: family ledger/control integrity violation(s) — see above"
  fi
else
  fail "Check 22: scripts/ac-ledger-integrity.sh missing — family ledger integrity NOT-GATED"
fi

# ---------------------------------------------------------------------------
# Check 23 — lean-family + loaded-path caps, shape, declarations, references (ac-kdxa)
# ---------------------------------------------------------------------------
echo "--- Check 23: family budget + anti-drift ---"

# The plan's biggest named risk is cultural — the files staying small — and every
# previous "keep it small" rule here was prose, and every one of them lost. This is that
# rule as a check: family <=800 SKILL.md lines, <=1,200 over the LOADED path with the
# mandatory-load set DERIVED from the pointers (a hardcoded list is the measured evasion
# with an extra step), pointed-at canon reported but never capped, and assurance
# declarations for family scripts (Check 21 is hooks.json-scoped and cannot see them).
# The former cross-reference leg retired at the rename: its premise was that the
# old prefixed family was invisible to Check 2's `/ac-[a-z]` pattern, and the rename erased
# that blind spot — Check 2 now sees every invocation the family makes.
ABC="$AC_ROOT/scripts/ac-budget-check.sh"
check
if [ -r "$ABC" ]; then
  if abc_out=$(bash "$ABC" "$AC_ROOT" 2>&1); then
    printf '%s\n' "$abc_out" | sed 's/^/  /'
  else
    printf '%s\n' "$abc_out"
    fail "Check 23: family budget/anti-drift violation(s) — see above"
  fi
else
  fail "Check 23: scripts/ac-budget-check.sh missing — family caps NOT-GATED"
fi

# ---------------------------------------------------------------------------
# Check 24 — skill description length, for cross-harness portability
# ---------------------------------------------------------------------------
echo "--- Check 24: skill description length (cross-harness cap) ---"

# opencode DOCUMENTS a 1-1024 character cap on a skill description and validates
# frontmatter against it. Measured 2026-08-28 on v1.18.0: the cap is NOT enforced at
# load (a 1100-char description loaded and reached the system prompt), so this is
# insurance against an upstream tightening, not a live breakage. It earns its place
# because the registry was already inside 6 characters of the limit
# (ac-site-polish at 1018) with nothing watching, and a skill silently dropped by a
# consumer harness is exactly the failure this repo cannot see from the inside.
#
# The WARN band exists so the cap is not discovered by hitting it.
DESC_HARD=1024
DESC_WARN=950
check
desc_fail=0
for f in "$AC_ROOT"/skills/*/SKILL.md; do
  [ -r "$f" ] || continue
  sname="$(basename "$(dirname "$f")")"
  # python3, not awk: descriptions carry em dashes, and awk's length() counts BYTES —
  # which over-reports a UTF-8 description by ~2 per dash and would fail a skill that is
  # actually inside the cap. opencode measures a JS string length, i.e. characters.
  dlen="$(python3 -c '
import io,sys
lines=io.open(sys.argv[1],encoding="utf-8").read().split("\n")
c=0
for ln in lines:
    if ln.strip()=="---":
        c+=1
        if c==2: break
        continue
    if c==1 and ln.startswith("description:"):
        print(len(ln[len("description:"):].strip())); break
' "$f")"
  [ -n "$dlen" ] || continue
  if [ "$dlen" -gt "$DESC_HARD" ]; then
    echo "  $sname: description $dlen chars, over the $DESC_HARD cap"
    desc_fail=$(( desc_fail + 1 ))
  elif [ "$dlen" -ge "$DESC_WARN" ]; then
    echo "  WARN $sname: description $dlen chars, within $(( DESC_HARD - dlen )) of the $DESC_HARD cap"
  fi
done
if [ "$desc_fail" -gt 0 ]; then
  fail "Check 24: $desc_fail skill description(s) over the $DESC_HARD-char cross-harness cap"
else
  echo "  ok: every skill description is within the $DESC_HARD-char cap"
fi

# ---------------------------------------------------------------------------
# Check 25 — is_test_shaped single-definition sensor (ac-b62c)
# ---------------------------------------------------------------------------
echo "--- Check 25: is_test_shaped drift sensor ---"
check
# flight-check WRITES the verification scope that close-gate READS. is_test_shaped is the
# contract both sides of that handshake interpret; if a second definition appears, the scope
# one records is not the scope the other interprets and the temporal proof silently rests on
# two different contracts. Exactly ONE definition site — close-gate.sh — enforced here, so a
# re-duplication fails instead of drifting.
ITS_SITES=$(grep -rl 'is_test_shaped()' skills/ac-implement/scripts/ 2>/dev/null || true)
ITS_N=$(printf '%s' "$ITS_SITES" | grep -c . || true)
if [ "$ITS_N" -eq 1 ] && printf '%s\n' "$ITS_SITES" | grep -q 'close-gate.sh'; then
  echo "  ok: is_test_shaped() defined once, in close-gate.sh"
else
  fail "Check 25: is_test_shaped() has $ITS_N definition site(s) ($(printf '%s' "$ITS_SITES" | tr '\n' ' ')) — the contract must live in exactly one place, close-gate.sh (ac-b62c drift sensor)"
fi
grep -q 'is_test_shaped' skills/ac-implement/scripts/flight-check.sh \
  && fail "Check 25: flight-check.sh mentions is_test_shaped — it must carry no copy that could drift from close-gate.sh's definition (ac-b62c)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "lint: ${CHECKS} checks, ${FAILURES} failures (un-ported bash blocks)"

# A failing un-ported block ends the run here — a red suite is not a green run.
if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi

# The v2 runner runs AFTER the un-ported blocks and ITS exit becomes the final
# exit. If the runner is absent (mid-port checkout) the legacy verdict stands.
if [ -f "$AC_ROOT/lint/run.py" ]; then
  exec python3 "$AC_ROOT/lint/run.py" --root "$AC_ROOT"
fi

[ "$FAILURES" -eq 0 ]
