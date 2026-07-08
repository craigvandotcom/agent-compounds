#!/bin/bash
# Validate skill meets standards
# Usage: ./validate-skill.sh /path/to/skill/
#        ./validate-skill.sh --registry /path/to/skills/   (description-budget audit)
#
# Checks (single skill):
# - YAML frontmatter exists with name and description
# - Name is lowercase-hyphen format, max 64 chars
# - Description under 1024 chars
# - SKILL.md under 500 lines (warning if over 400)
# - Description contains trigger phrases (not just purpose)
#
# Checks (--registry):
# - Sum of all model-invocable descriptions vs the skill-listing budget
#   (~15,000 chars measured; beyond it, least-used skills are SILENTLY DROPPED
#   from Claude's awareness — see skill-builder references/token-economics.md).
#   Skills with disable-model-invocation: true are excluded (zero standing cost).

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

# --registry mode: audit the always-loaded description budget across a skills dir
if [ "$1" = "--registry" ]; then
    SKILLS_DIR="${2:-skills}"
    if [ ! -d "$SKILLS_DIR" ]; then
        echo -e "${RED}❌ Error: Directory not found: $SKILLS_DIR${NC}"
        exit 1
    fi
    BUDGET_FAIL=15000   # measured listing cliff (chars)
    BUDGET_WARN=12000
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
    echo -e "${BLUE}📊 Registry description budget — $SKILLS_DIR${NC}"
    echo "  Model-invocable skills: $COUNT, total description chars: $TOTAL"
    echo "  (excluded manual-only skills: $MANUAL chars carry zero standing cost)"
    echo "  Top consumers:"
    printf "$ROWS" | sort -rn | head -10 | awk '{printf "    %6d  %s\n", $1, $2}'
    echo ""
    if [ "$TOTAL" -gt "$BUDGET_FAIL" ]; then
        echo -e "${RED}❌ FAIL: $TOTAL chars exceeds the ~$BUDGET_FAIL listing cliff — skills are likely being SILENTLY DROPPED in consuming sessions.${NC}"
        echo "  Fix: trigger-only descriptions; disable-model-invocation: true on name-invoked skills."
        exit 1
    elif [ "$TOTAL" -gt "$BUDGET_WARN" ]; then
        echo -e "${YELLOW}⚠️  WARNING: $TOTAL chars — within budget but close to the ~$BUDGET_FAIL cliff.${NC}"
        [ "$OVER_1024" -gt 0 ] && exit 1
        exit 0
    else
        echo -e "${GREEN}✅ OK: $TOTAL chars within listing budget (~$BUDGET_FAIL cliff)${NC}"
        [ "$OVER_1024" -gt 0 ] && exit 1
        exit 0
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

# Check SKILL.md size
LINE_COUNT=$(wc -l < "$SKILL_MD")
# Size is a TARGET, not a hard law: ≤500 is optimal (Anthropic), but a genuine
# multi-phase orchestrator may justifiably exceed it (see references/structure-standard.md).
# So >500 warns (strongly) rather than fails — move sub-agent prompts/templates to references/.
if [ $LINE_COUNT -le 400 ]; then
    echo -e "${GREEN}✓ PASS: SKILL.md size OK ($LINE_COUNT/500 lines)${NC}"
elif [ $LINE_COUNT -le 500 ]; then
    echo -e "${YELLOW}⚠️  WARNING: SKILL.md getting large ($LINE_COUNT lines). Aim for ≤400; push detail to references/.${NC}"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${YELLOW}⚠️  WARNING: SKILL.md over the 500-line target ($LINE_COUNT lines).${NC}"
    echo "  OK only if it's a genuine orchestrator whose flow needs the length."
    echo "  Otherwise move sub-agent prompts/templates/schemas to references/ (see structure-standard.md)."
    WARNINGS=$((WARNINGS + 1))
fi

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
