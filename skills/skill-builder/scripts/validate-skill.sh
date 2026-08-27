#!/bin/bash
# Validate skill meets standards
# Usage: ./validate-skill.sh /path/to/skill/            (single-skill checks)
#        ./validate-skill.sh --registry /path/to/skills/ (budget + dup-fingerprint audit)
#        ./validate-skill.sh --diff /path/to/skill/ <git-ref>  (enforcement-regression backstop)
#
# Checks (single skill):
# - YAML frontmatter exists with name and description
# - Name is lowercase-hyphen format, max 64 chars
# - Description under 1024 chars
# - SKILL.md under 500 lines (warning if over 400)
# - Description contains trigger phrases (not just purpose)
# - POINTER INTEGRITY: every references/|workflows/|tools/|_shared/ file named in the
#   skill's .md files exists (hard fail if missing); reference files never pointed to
#   are flagged as orphans (warn). _shared/ resolves against the parent skills dir.
#
# Checks (--registry):
# - Sum of all model-invocable descriptions vs the skill-listing budget
#   (default ~15,000 chars; raise via skillListingBudgetFraction in settings —
#   over budget, least-invoked skills lose their descriptions first, degrading
#   natural-language triggering — see skill-builder references/token-economics.md).
#   Skills with disable-model-invocation: true are excluded (zero standing cost).
# - INVOCATION-GRAPH RULE (hard fail): no skill flagged disable-model-invocation
#   may be referenced as an invocation (/name, or run/invoke `name`) from another
#   skill's files — a flipped skill is unreachable by the model, so such a
#   reference is a broken chain. The graph is computed from the files every run;
#   never classify a skill's flag from memory.
# - CROSS-SKILL DUPLICATE FINGERPRINT (advisory): long content lines appearing verbatim
#   in ≥2 skills — candidates to promote into skills/_shared/ (see structure-standard.md).
#
# Checks (--diff <ref>): enforcement-regression backstop for a diet/refactor. Flags
# enforcement-shaped lines (TaskUpdate, Remember, MANDATORY, exact gates, MUST/NEVER/ALWAYS)
# present at <git-ref> but absent from the CURRENT skill (any .md) — i.e. removed and NOT
# relocated. A move is fine; a disappearance is a FAIL. Heuristic — verify hits against the
# hygiene-pass CORE/EXTRACT/CUT ledger.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Extract the description value (handles single-line and block-scalar YAML) from a
# SKILL.md's first frontmatter block; prints it as one line.
extract_description() {
    awk '
        NR==1 && /^---[[:space:]]*$/ {f=1; next}
        f && /^---[[:space:]]*$/ {exit}
        f && /^description:/ {
            d=$0; sub(/^description:[[:space:]]*/, "", d)
            if (d ~ /^[>|]/) { block=1; next }   # block scalar: value on following indented lines
            print d; exit
        }
        block && /^[[:space:]]+/ { s=$0; sub(/^[[:space:]]+/, "", s); out = out (out?" ":"") s; next }
        block { print out; exit }
        END { if (block && out) print out }
    ' "$1"
}

# is_accessory SKILL.md -> exit 0 if frontmatter has `accessory: true`. Accessory skills are
# low-change, on-demand-only tools (ideation/brainstorm) — excluded from routine hygiene dup
# scans so they don't generate noise every run. They STILL count toward the description budget
# (their descriptions still load every session).
is_accessory() {
    awk 'NR==1 && /^---[[:space:]]*$/ {f=1; next} f && /^---[[:space:]]*$/ {exit}
         f && /^accessory:[[:space:]]*true[[:space:]]*$/ {found=1; exit} END{exit !found}' "$1"
}

# --registry mode: audit the always-loaded description budget across a skills dir
if [ "$1" = "--registry" ]; then
    SKILLS_DIR="${2:-skills}"
    if [ ! -d "$SKILLS_DIR" ]; then
        echo -e "${RED}❌ Error: Directory not found: $SKILLS_DIR${NC}"
        exit 1
    fi
    # MUST track the deployed budget: skillListingBudgetFraction: 0.02 in every
    # ac-deploy-target's .claude/settings.json (~2x the ~15k default). If an app
    # lacks that setting, its real budget is ~15k — deploy the setting, don't
    # shrink here. Raise both together, deliberately.
    #
    # ac2 CUTOVER — the archive-before-use ordering ruling (Craig, 2026-08-27, bead
    # ac-g2v4). The ac2 pipeline family must be WRITTEN before the twelve legacy ac-*
    # skills it absorbs can be archived, so both families sit on disk for the length of
    # the build. Measured with this script across that lifecycle: 29,637 before the
    # build, 33,214 at the overlap peak (over BUDGET_FAIL), 28,243 post-archival with
    # 1,757 chars free — archiving the absorbed skills frees ~4,971 and ac2 needs
    # ~3,577, so the END STATE fits and no per-skill ceiling is required. The overlap
    # breach is therefore EXPECTED, and it EXPIRES the moment the absorbed ac-* skills
    # move to _archive/skills/. The rule is an ORDERING one: build ac2, archive the
    # legacy skills, and only then route work to ac2 — a breach that is still standing
    # after the archival step is a real breach and must be dieted, not tolerated.
    BUDGET_FAIL=30000
    BUDGET_WARN=24000
    TOTAL=0; MANUAL=0; COUNT=0; OVER_1024=0
    ROWS=""
    for md in "$SKILLS_DIR"/*/SKILL.md; do
        [ -f "$md" ] || continue
        name=$(basename "$(dirname "$md")")
        desc=$(extract_description "$md")
        len=${#desc}
        fm=$(awk 'NR==1 && /^---[[:space:]]*$/ {f=1; next} f && /^---[[:space:]]*$/ {exit} f {print}' "$md")
        if echo "$fm" | grep -q "^disable-model-invocation:[[:space:]]*true"; then
            MANUAL=$((MANUAL + len))
        else
            TOTAL=$((TOTAL + len))
            COUNT=$((COUNT + 1))
            ROWS="$ROWS$len $name\n"
        fi
        if [ "$len" -gt 1024 ]; then
            echo -e "${RED}❌ $name: description $len chars (>1024 hard limit)${NC}"
            OVER_1024=$((OVER_1024 + 1))
        fi
    done
    # --- Invocation-graph check: flipped skills must have zero inbound invocation refs ---
    GRAPH_VIOLATIONS=0
    MANUAL_SKILLS=""
    for md in "$SKILLS_DIR"/*/SKILL.md; do
        [ -f "$md" ] || continue
        fm=$(awk 'NR==1 && /^---[[:space:]]*$/ {f=1; next} f && /^---[[:space:]]*$/ {exit} f {print}' "$md")
        if echo "$fm" | grep -q "^disable-model-invocation:[[:space:]]*true"; then
            MANUAL_SKILLS="$MANUAL_SKILLS $(basename "$(dirname "$md")")"
        fi
    done
    for name in $MANUAL_SKILLS; do
        # invocation forms: /name (boundary-guarded), or run/invoke/use `name`
        hits=$(grep -rnE "(/$name([^a-z0-9-]|\$))|([Rr]un(ning)? \`$name\`)|([Ii]nvoke \`$name\`)|([Uu]se \`$name\`)" \
               "$SKILLS_DIR" --include="*.md" 2>/dev/null | grep -v "/$name/" || true)
        if [ -n "$hits" ]; then
            echo -e "${RED}❌ GRAPH: '$name' is flagged disable-model-invocation but is invoked from other skills:${NC}"
            echo "$hits" | head -5 | sed 's/^/    /'
            n_hits=$(echo "$hits" | wc -l | tr -d ' ')
            [ "$n_hits" -gt 5 ] && echo "    ... and $((n_hits - 5)) more"
            echo "    Fix: remove the flag (the graph says other skills reach it), or remove the references."
            GRAPH_VIOLATIONS=$((GRAPH_VIOLATIONS + 1))
        fi
    done

    # --- Cross-skill duplicate-block fingerprint (advisory: _shared/ promotion candidates) ---
    DUP_TMP=$(mktemp)
    ACCESSORY_SKIPPED=0
    for md in "$SKILLS_DIR"/*/SKILL.md; do
        [ -f "$md" ] || continue
        is_accessory "$md" && { ACCESSORY_SKIPPED=$((ACCESSORY_SKIPPED + 1)); continue; }
        sname=$(basename "$(dirname "$md")")
        # normalized content lines only: strip ws, skip blanks/headings/fences/list-markers/short lines
        awk -v s="$sname" 'NR>1 { l=$0; gsub(/^[ \t]+|[ \t]+$/,"",l);
            if (length(l) >= 40 && l !~ /^[#|>*_+-]/ && l !~ /^```/ && l !~ /^[0-9]+\./) print s "\t" l }' "$md"
    done > "$DUP_TMP"
    DUP_OUT=$(sort -t"$(printf '\t')" -k2 "$DUP_TMP" | awk -F"$(printf '\t')" '
        function emit(){ n=0; for(k in sk) n++; if (prev!="" && n>=2) printf "%d  %s\n", n, substr(prev,1,78) }
        { if ($2==prev) { sk[$1]=1 } else { emit(); delete sk; sk[$1]=1; prev=$2 } }
        END{ emit() }' | sort -rn | head -12)
    rm -f "$DUP_TMP"
    echo -e "${BLUE}🧬 Cross-skill duplicated lines (≥2 skills) — _shared/ promotion candidates${NC}"
    if [ -n "$DUP_OUT" ]; then
        echo "$DUP_OUT" | awk '{ printf "    %s\n", $0 }'
        echo "  (verbatim lines shared across skills → consider skills/_shared/; see structure-standard.md)"
    else
        echo "  none — no long content lines shared verbatim across skills"
    fi
    [ "$ACCESSORY_SKIPPED" -gt 0 ] && echo "  ($ACCESSORY_SKIPPED accessory skill(s) excluded from dup scans — on-demand hygiene only)"
    echo ""

    # --- Fuzzy near-duplicate detection (advisory): skill PAIRS sharing many 5-word shingles.
    #     Catches reworded/synonym-swapped blocks the exact-line matcher misses (e.g. batch→wave).
    #     Emits candidate pairs; a human/model makes the semantic call. Threshold tunable. ---
    SHNG_TMP=$(mktemp)
    for md in "$SKILLS_DIR"/*/SKILL.md; do
        [ -f "$md" ] || continue
        is_accessory "$md" && continue
        sname=$(basename "$(dirname "$md")")
        awk -v s="$sname" '{ line=tolower($0); gsub(/[^a-z0-9 ]/," ",line); n=split(line,w," ");
            for(i=1;i+4<=n;i++) print s "\t" w[i]" "w[i+1]" "w[i+2]" "w[i+3]" "w[i+4] }' "$md"
    done | sort -u > "$SHNG_TMP"   # unique (skill, 5-gram) pairs
    NEARDUP=$(sort -t"$(printf '\t')" -k2 "$SHNG_TMP" | awk -F"$(printf '\t')" '
        function flush(){ delete A; m=0; for(k in S) A[m++]=k;
            for(i=0;i<m;i++) for(j=i+1;j<m;j++){ p=(A[i]<A[j])?A[i]" ~ "A[j]:A[j]" ~ "A[i]; C[p]++ }
            delete S }
        { if($2!=psh){ flush(); psh=$2 } S[$1]=1 }
        END{ flush(); for(p in C) if(C[p]>=8) printf "%d\t%s\n", C[p], p }' | sort -rn | head -10)
    rm -f "$SHNG_TMP"
    echo -e "${BLUE}🧪 Near-duplicate skill pairs (shared 5-word shingles ≥8) — reworded-block candidates${NC}"
    if [ -n "$NEARDUP" ]; then
        echo "$NEARDUP" | awk -F"$(printf '\t')" '{ printf "    %4d shingles  %s\n", $1, $2 }'
        echo "  (high overlap = likely reworded/duplicated block; verify semantically, route real dups to _shared/)"
    else
        echo "  none above threshold"
    fi
    echo ""

    echo -e "${BLUE}📊 Registry description budget — $SKILLS_DIR${NC}"
    echo "  Model-invocable skills: $COUNT, total description chars: $TOTAL"
    echo "  (excluded manual-only skills: $MANUAL chars carry zero standing cost)"
    echo "  Top consumers:"
    printf "$ROWS" | sort -rn | head -10 | awk '{printf "    %6d  %s\n", $1, $2}'
    echo ""
    if [ "$TOTAL" -gt "$BUDGET_FAIL" ]; then
        echo -e "${RED}❌ FAIL: $TOTAL chars exceeds the ~$BUDGET_FAIL listing budget — least-invoked skills lose descriptions (degraded triggering) in consuming sessions.${NC}"
        echo "  Fix: trigger-only descriptions; flip zero-inbound entry points; or raise skillListingBudgetFraction (and this threshold) deliberately."
        # Machine-greppable, colour-free marker. This script exits 1 for a budget breach,
        # an over-1024 description and an invocation-graph violation alike, so a caller
        # reading only the exit status cannot tell them apart — and lint.sh's Check 13
        # collapsed all three into one line, behind which a NEW budget breach could land
        # invisibly while an unrelated graph violation already held the check red. lint.sh
        # greps for this token to give the budget its own failure line. Keep it verbatim.
        echo "registry-description-budget: BREACH $TOTAL > $BUDGET_FAIL chars"
        exit 1
    elif [ "$TOTAL" -gt "$BUDGET_WARN" ]; then
        echo -e "${YELLOW}⚠️  WARNING: $TOTAL chars — within budget but close to the ~$BUDGET_FAIL threshold.${NC}"
        [ "$OVER_1024" -gt 0 ] && exit 1
        [ "$GRAPH_VIOLATIONS" -gt 0 ] && exit 1
        exit 0
    else
        echo -e "${GREEN}✅ OK: $TOTAL chars within listing budget (~$BUDGET_FAIL threshold)${NC}"
        [ "$OVER_1024" -gt 0 ] && exit 1
        [ "$GRAPH_VIOLATIONS" -gt 0 ] && exit 1
        exit 0
    fi
fi

# --diff mode: enforcement-regression backstop vs a git ref (diet/refactor guard)
if [ "$1" = "--diff" ]; then
    SKILL_PATH="${2:?usage: --diff <skill-dir> <git-ref>}"
    REF="${3:?usage: --diff <skill-dir> <git-ref>}"
    SKILL_MD="$SKILL_PATH/SKILL.md"
    [ -f "$SKILL_MD" ] || { echo -e "${RED}❌ SKILL.md not found in $SKILL_PATH${NC}"; exit 1; }
    RELMD=$(git -C "$SKILL_PATH" ls-files --full-name -- SKILL.md 2>/dev/null | head -1)
    if [ -z "$RELMD" ]; then
        echo -e "${YELLOW}⚠️  $SKILL_MD is not git-tracked (or no repo) — cannot diff${NC}"; exit 0
    fi
    OLD=$(git -C "$SKILL_PATH" show "$REF:$RELMD" 2>/dev/null || true)
    if [ -z "$OLD" ]; then
        echo -e "${YELLOW}⚠️  cannot read $REF:$RELMD — bad ref?${NC}"; exit 0
    fi
    echo -e "${BLUE}🛡️  Enforcement-regression check: $SKILL_PATH vs $REF${NC}"
    # A removed enforcement line is only a regression if it appears NOWHERE it could have
    # legitimately moved: the skill's own dir OR the sibling _shared/ (extraction target).
    DIFF_PARENT=$(dirname "$SKILL_PATH")
    DIFF_SEARCH="$SKILL_PATH"
    [ -d "$DIFF_PARENT/_shared" ] && DIFF_SEARCH="$SKILL_PATH $DIFF_PARENT/_shared"
    # enforcement-shaped patterns; a removed match that no longer appears anywhere = regression
    ENF_PAT='TaskUpdate|TaskCreate|Remember|MANDATORY|--limit 0|AskUserQuestion|\bMUST\b|\bNEVER\b|\bALWAYS\b|VERDICT|GUARD-RAIL|HARD STOP|Rule 0'
    REGRESS=0
    while IFS= read -r line; do
        norm=$(printf '%s' "$line" | sed 's/^[ \t]*//; s/[ \t]*$//')
        [ ${#norm} -lt 12 ] && continue
        if ! grep -rqF -- "$norm" $DIFF_SEARCH --include="*.md" 2>/dev/null; then
            echo -e "${RED}❌ removed, not relocated:${NC} ${norm:0:88}"
            REGRESS=$((REGRESS + 1))
        fi
    done < <(printf '%s\n' "$OLD" | grep -iE "$ENF_PAT" || true)
    echo ""
    if [ "$REGRESS" -eq 0 ]; then
        echo -e "${GREEN}✅ no enforcement-line regressions vs $REF (moves OK, nothing lost)${NC}"; exit 0
    else
        echo -e "${RED}❌ $REGRESS enforcement line(s) removed without relocation — check the diet ledger${NC}"; exit 1
    fi
fi

# Parse arguments
SKILL_PATH="${1:-.}"

# Normalize path
if [ ! -d "$SKILL_PATH" ]; then
    echo -e "${RED}❌ Error: Directory not found: $SKILL_PATH${NC}"
    exit 1
fi

SKILL_MD="$SKILL_PATH/SKILL.md"

# Check SKILL.md exists
if [ ! -f "$SKILL_MD" ]; then
    echo -e "${RED}❌ Error: SKILL.md not found in $SKILL_PATH${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Validating skill at: $SKILL_PATH${NC}"
echo ""

# Track validation results
ERRORS=0
WARNINGS=0

# Extract YAML frontmatter
if ! grep -q "^---$" "$SKILL_MD"; then
    echo -e "${RED}❌ FAIL: No YAML frontmatter found${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ PASS: YAML frontmatter detected${NC}"

    # Extract frontmatter content (FIRST --- ... --- block only; body may contain --- rules)
    FRONTMATTER=$(awk 'NR==1 && /^---[[:space:]]*$/ {f=1; next} f && /^---[[:space:]]*$/ {exit} f {print}' "$SKILL_MD")

    # Check for name field
    if echo "$FRONTMATTER" | grep -q "^name:"; then
        SKILL_NAME=$(echo "$FRONTMATTER" | grep -m1 "^name:" | sed 's/name: *//' | tr -d '"' | tr -d "'")
        echo -e "${GREEN}✓ PASS: Name field present: $SKILL_NAME${NC}"

        # Validate name format
        if [[ "$SKILL_NAME" =~ ^[a-z0-9-]+$ ]]; then
            echo -e "${GREEN}✓ PASS: Name uses valid format (lowercase, numbers, hyphens)${NC}"
        else
            echo -e "${RED}❌ FAIL: Invalid name format. Use lowercase letters, numbers, and hyphens only${NC}"
            echo "  Current: $SKILL_NAME"
            echo "  Examples: pdf-processing, data-analysis, code-review"
            ERRORS=$((ERRORS + 1))
        fi

        # Check name length
        if [ ${#SKILL_NAME} -le 64 ]; then
            echo -e "${GREEN}✓ PASS: Name length OK (${#SKILL_NAME}/64 chars)${NC}"
        else
            echo -e "${RED}❌ FAIL: Name too long (${#SKILL_NAME}/64 chars max)${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "${RED}❌ FAIL: Name field missing in frontmatter${NC}"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for description field
    if echo "$FRONTMATTER" | grep -q "^description:"; then
        DESCRIPTION=$(extract_description "$SKILL_MD")
        DESC_LENGTH=${#DESCRIPTION}
        echo -e "${GREEN}✓ PASS: Description field present${NC}"

        # Check description length
        if [ $DESC_LENGTH -le 1024 ]; then
            if [ $DESC_LENGTH -lt 50 ]; then
                echo -e "${YELLOW}⚠️  WARNING: Description very short ($DESC_LENGTH chars). Add more trigger phrases.${NC}"
                WARNINGS=$((WARNINGS + 1))
            else
                echo -e "${GREEN}✓ PASS: Description length OK ($DESC_LENGTH/1024 chars)${NC}"
            fi
        else
            echo -e "${RED}❌ FAIL: Description too long ($DESC_LENGTH/1024 chars max)${NC}"
            ERRORS=$((ERRORS + 1))
        fi

        # Check for trigger phrases
        TRIGGER_KEYWORDS=0
        if echo "$DESCRIPTION" | grep -iq "use when"; then
            TRIGGER_KEYWORDS=$((TRIGGER_KEYWORDS + 1))
        fi
        if echo "$DESCRIPTION" | grep -iq "triggers on\|trigger on\|triggers:"; then
            TRIGGER_KEYWORDS=$((TRIGGER_KEYWORDS + 1))
        fi
        if echo "$DESCRIPTION" | grep -iq "applies to\|applies when"; then
            TRIGGER_KEYWORDS=$((TRIGGER_KEYWORDS + 1))
        fi
        if echo "$DESCRIPTION" | grep -iq "mention"; then
            TRIGGER_KEYWORDS=$((TRIGGER_KEYWORDS + 1))
        fi

        if [ $TRIGGER_KEYWORDS -ge 1 ]; then
            echo -e "${GREEN}✓ PASS: Description includes trigger phrases${NC}"
        else
            echo -e "${YELLOW}⚠️  WARNING: Description may lack clear trigger phrases${NC}"
            echo "  Consider adding: 'Use when...', 'Triggers on...', 'Applies when...'"
            echo "  Focus on WHEN to use (triggers), not HOW it works (workflow)"
            WARNINGS=$((WARNINGS + 1))
        fi

        # Check if description is workflow summary (anti-pattern)
        WORKFLOW_WORDS=0
        if echo "$DESCRIPTION" | grep -iq "first.*then\|then.*then"; then
            WORKFLOW_WORDS=$((WORKFLOW_WORDS + 1))
        fi
        if echo "$DESCRIPTION" | grep -iq "step 1\|step 2\|step-by-step"; then
            WORKFLOW_WORDS=$((WORKFLOW_WORDS + 1))
        fi

        if [ $WORKFLOW_WORDS -gt 0 ]; then
            echo -e "${YELLOW}⚠️  WARNING: Description may be workflow summary (anti-pattern)${NC}"
            echo "  Agents follow summaries instead of reading full skill content"
            echo "  Rewrite to focus on triggering conditions, not process steps"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo -e "${RED}❌ FAIL: Description field missing in frontmatter${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# NOTE: the old absolute-size WARN-only check (SKILL.md line count vs a static
# 400/500 threshold) lived here. Removed 2026-07-20 (skill-diet WS2, bead
# ac-q6e.2) — it was INERT (WARN-only, never blocked anything) and judged a
# file in isolation rather than the change. Superseded by lint.sh Check 14
# (no-net-growth): a diff-aware HARD gate that fails on net SKILL.md line
# growth vs origin/main unless stamped `<!-- net-growth-ok: <reason> -->`.

# Check for common required sections
echo ""
echo -e "${BLUE}📋 Checking recommended sections...${NC}"

SECTIONS_FOUND=0
if grep -q "^## When to Use" "$SKILL_MD"; then
    echo -e "${GREEN}✓ Found: 'When to Use' section${NC}"
    SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
else
    echo -e "${YELLOW}⚠️  Missing: 'When to Use' section (recommended)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if grep -q "^## Core Pattern\|^## Core Principle" "$SKILL_MD"; then
    echo -e "${GREEN}✓ Found: 'Core Pattern' or 'Core Principle' section${NC}"
    SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
else
    echo -e "${YELLOW}⚠️  Missing: 'Core Pattern' section (recommended)${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if grep -q "^## Quick Reference" "$SKILL_MD"; then
    echo -e "${GREEN}✓ Found: 'Quick Reference' section${NC}"
    SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
fi

# Check pointer integrity: every referenced support file exists; flag orphaned references
echo ""
echo -e "${BLUE}🔗 Checking pointer integrity...${NC}"
SKILLS_PARENT=$(dirname "$SKILL_PATH")
POINTER_MISSING=0
# Two-tier, and always EXCLUDING fenced code blocks (which hold illustrative example paths).
# Scope = SKILL.md spine only. A deliberate markdown-link pointer [text](path) is an unambiguous
# claim the file exists → HARD FAIL if missing. A backtick/bare mention (`references/x.md`) is
# often illustrative ("→ references/<topic>.md or memory") or cross-skill shorthand
# ("ac-prove/workflows/scheduled.md") → WARN only, for a human to judge.
resolve_ref() { case "$1" in _shared/*) echo "$SKILLS_PARENT/$1" ;; *) echo "$SKILL_PATH/$1" ;; esac; }
SKILL_BODY=$(awk '/^```/{f=!f; next} !f' "$SKILL_MD")
LINK_REFS=$(printf '%s\n' "$SKILL_BODY" \
    | grep -oE '\]\((references|workflows|tools|_shared)/[A-Za-z0-9._/-]+\.(md|json|txt|py|sh)\)' \
    | sed -E 's/^\]\(//; s/\)$//' | sort -u || true)
ALL_REFS=$(printf '%s\n' "$SKILL_BODY" \
    | grep -oE '(references|workflows|tools|_shared)/[A-Za-z0-9._/-]+\.(md|json|txt|py|sh)' \
    | sort -u || true)
for ref in $LINK_REFS; do
    if [ ! -f "$(resolve_ref "$ref")" ]; then
        echo -e "${RED}❌ FAIL: broken link pointer: $ref${NC}"
        POINTER_MISSING=$((POINTER_MISSING + 1)); ERRORS=$((ERRORS + 1))
    fi
done
for ref in $ALL_REFS; do
    printf '%s\n' "$LINK_REFS" | grep -qxF "$ref" && continue   # already reported as a link error
    if [ ! -f "$(resolve_ref "$ref")" ]; then
        echo -e "${YELLOW}⚠️  mentioned support file not found (illustrative or cross-skill? verify): $ref${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
done
[ "$POINTER_MISSING" -eq 0 ] && echo -e "${GREEN}✓ PASS: all markdown-link pointers resolve${NC}"
# Orphan check: reference files never pointed to from any .md (warn — a stale/dead reference)
if [ -d "$SKILL_PATH/references" ]; then
    for f in "$SKILL_PATH"/references/*.md; do
        [ -f "$f" ] || continue
        base=$(basename "$f")
        [ "$base" = "MAINTENANCE.md" ] && continue   # sidecar ledger: intentionally not pointed-to
        [ "$base" = "FRICTIONS.md" ] && continue     # per-skill sensor log: intentionally not pointed-to (references/friction-capture.md)
        if ! grep -rqF "references/$base" "$SKILL_PATH" --include="*.md" 2>/dev/null; then
            echo -e "${YELLOW}⚠️  Orphaned reference (never pointed to): references/$base${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
fi

# Final summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ VALIDATION PASSED${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $WARNINGS warning(s) - consider addressing${NC}"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo -e "${RED}❌ VALIDATION FAILED${NC}"
    echo "$ERRORS error(s), $WARNINGS warning(s)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
