#!/bin/bash
# Initialize new skill from template
# Usage: ./init-skill.sh skill-name "Description here" [--path /custom/path]
#
# Creates skill directory structure with:
# - SKILL.md with YAML frontmatter
# - Empty workflows/ and references/ directories
# - Optional scripts/ directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default paths
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SKILLS_BASE="$REPO_ROOT/.claude/skills"
# Self-contained: scaffold from the inline template below. (For a richer starting
# point, copy references/skill-template.md by hand.)
TEMPLATE_PATH=""

# Parse arguments
SKILL_NAME=""
DESCRIPTION=""
CUSTOM_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --path)
            CUSTOM_PATH="$2"
            shift 2
            ;;
        *)
            if [ -z "$SKILL_NAME" ]; then
                SKILL_NAME="$1"
            elif [ -z "$DESCRIPTION" ]; then
                DESCRIPTION="$1"
            else
                echo -e "${RED}❌ Error: Too many arguments${NC}"
                echo "Usage: $0 skill-name \"Description here\" [--path /custom/path]"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$SKILL_NAME" ]; then
    echo -e "${RED}❌ Error: Skill name required${NC}"
    echo "Usage: $0 skill-name \"Description here\" [--path /custom/path]"
    exit 1
fi

if [ -z "$DESCRIPTION" ]; then
    echo -e "${RED}❌ Error: Description required${NC}"
    echo "Usage: $0 skill-name \"Description here\" [--path /custom/path]"
    exit 1
fi

# Validate skill name format
if ! [[ "$SKILL_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo -e "${RED}❌ Error: Invalid skill name format${NC}"
    echo "Name must use lowercase letters, numbers, and hyphens only"
    echo "Examples: pdf-processing, data-analysis, code-review"
    exit 1
fi

if [ ${#SKILL_NAME} -gt 64 ]; then
    echo -e "${RED}❌ Error: Skill name too long (max 64 characters)${NC}"
    exit 1
fi

# Validate description length
if [ ${#DESCRIPTION} -gt 1024 ]; then
    echo -e "${RED}❌ Error: Description too long (max 1024 characters)${NC}"
    exit 1
fi

# Determine target path
if [ -n "$CUSTOM_PATH" ]; then
    TARGET_PATH="$CUSTOM_PATH/$SKILL_NAME"
else
    TARGET_PATH="$SKILLS_BASE/$SKILL_NAME"
fi

# Check if skill already exists
if [ -d "$TARGET_PATH" ]; then
    echo -e "${YELLOW}⚠️  Warning: Skill directory already exists: $TARGET_PATH${NC}"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    rm -rf "$TARGET_PATH"
fi

# Create directory structure
echo -e "${GREEN}📁 Creating skill directory structure...${NC}"
mkdir -p "$TARGET_PATH/workflows"
mkdir -p "$TARGET_PATH/references"

# Scaffold SKILL.md (inline template unless an external one is provided)
if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "Creating SKILL.md from the built-in template..."

    # Create basic SKILL.md without template
    cat > "$TARGET_PATH/SKILL.md" << EOF
---
name: $SKILL_NAME
description: $DESCRIPTION
---

# ${SKILL_NAME^} Skill

**Purpose:** [One sentence describing what this skill does]
**Domain:** [Area of functionality]
**Status:** MVP

---

## When to Use This Skill

**Intent Triggers:**
- [Specific scenario 1]
- [Specific scenario 2]
- [Specific scenario 3]

**Example Phrases:**
- "[Natural language query 1]"
- "[Natural language query 2]"

**When NOT to Use:**
- [Exclusion 1]
- [Exclusion 2]

---

## Core Pattern

[Describe the main technique or workflow this skill provides]

---

## Quick Reference

| Item | Details |
|------|---------|
| [Key concept 1] | [Brief explanation] |
| [Key concept 2] | [Brief explanation] |

---

## Supporting Documentation

| File | When to Read |
|------|--------------|
| \`workflows/example.md\` | When executing [specific task] |
| \`references/details.md\` | When needing [specific information] |

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| [Common error 1] | [How to avoid/fix] |
| [Common error 2] | [How to avoid/fix] |
EOF
else
    # Use template and replace placeholders
    echo -e "${GREEN}📄 Generating SKILL.md from template...${NC}"

    # Read template and add name field, replace description placeholder
    {
        echo "---"
        echo "name: $SKILL_NAME"
        echo "description: $DESCRIPTION"
        # Read template and skip frontmatter (lines until second ---)
        awk '/^---$/{c++; if(c==2) {next}; if(c>0) next} c==2' "$TEMPLATE_PATH"
    } > "$TARGET_PATH/SKILL.md"
fi

# Create README for guidance
cat > "$TARGET_PATH/README.md" << EOF
# $SKILL_NAME

$DESCRIPTION

## Status: MVP

Created: $(date +%Y-%m-%d)

## Next Steps

1. [ ] Complete SKILL.md sections
2. [ ] Add workflows if needed (multi-step processes)
3. [ ] Add reference docs if needed (deep documentation)
4. [ ] Test with RED-GREEN-REFACTOR:
   - [ ] Document baseline (agent fails without skill)
   - [ ] Verify success (agent succeeds with skill)
   - [ ] Test edge cases and close loopholes
5. [ ] If shared: place in agent-compounds and deploy via deploy.sh

## Structure

\`\`\`
$SKILL_NAME/
├── SKILL.md           # Main skill definition (200-400 lines target)
├── workflows/         # Optional: step-by-step procedures
├── references/         # Optional: deep documentation
└── README.md          # This file
\`\`\`
EOF

echo ""
echo -e "${GREEN}✅ Skill initialized successfully!${NC}"
echo ""
echo "Location: $TARGET_PATH"
echo ""
echo "Next steps:"
echo "1. Edit $TARGET_PATH/SKILL.md"
echo "2. Add workflows to workflows/ if needed"
echo "3. Add reference docs to references/ if needed"
echo "4. Test with verification gate protocol"
echo ""
echo -e "${YELLOW}📋 Remember: Description focuses on WHEN (triggers), not HOW (workflow)${NC}"
