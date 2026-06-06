# Skill Builder Scripts

Command-line utilities for creating and validating Claude Code skills.

---

## init-skill.sh

Initialize new skill from template with proper structure and frontmatter.

### Usage

```bash
./init-skill.sh skill-name "Description here" [--path /custom/path]
```

### Arguments

- `skill-name` - Name in lowercase-hyphen format (required)
- `"Description"` - Description focusing on WHEN to use (required)
- `--path` - Custom path (optional, defaults to `~/.claude/skills/`)

### Examples

```bash
# Create in default location
./init-skill.sh pdf-processing "Use when extracting text, tables, or forms from PDF files"

# Create in custom location
./init-skill.sh pdf-processing "Use when..." --path /path/to/project/.claude/skills

# Create for specific project
./init-skill.sh body-compass "Use when analyzing movement patterns" --path /path/to/your-project/.claude/skills
```

### Creates

```
skill-name/
├── SKILL.md           # With YAML frontmatter pre-filled
├── workflows/         # Empty directory for step-by-step processes
├── reference/         # Empty directory for deep documentation
└── README.md          # Next steps checklist
```

### Validation

- Name must be lowercase, numbers, hyphens only (max 64 chars)
- Description max 1024 chars
- Warns if directory already exists (prompts to overwrite)

---

## validate-skill.sh

Validate skill meets standards and best practices.

### Usage

```bash
./validate-skill.sh /path/to/skill/
```

### Arguments

- Path to skill directory (defaults to current directory)

### Checks

**YAML Frontmatter:**
- Presence of frontmatter delimiters (`---`)
- `name` field present and valid format
- `description` field present and within limits

**Name Validation:**
- Lowercase, numbers, hyphens only
- Max 64 characters
- Examples: `pdf-processing`, `data-analysis`, `code-review`

**Description Validation:**
- Max 1024 characters
- Contains trigger phrases ("Use when", "Triggers on", "Applies to")
- Not workflow summary (no "first...then", "step 1", etc.)

**Size Constraints:**
- SKILL.md under 500 lines (warns if >400)
- Recommends moving content to workflows/ or reference/ if too large

**Recommended Sections:**
- "When to Use" section
- "Core Pattern" or "Core Principle" section
- "Quick Reference" section

### Exit Codes

- `0` - Validation passed (may have warnings)
- `1` - Validation failed (has errors)

### Examples

```bash
# Validate skill in current directory
./validate-skill.sh .

# Validate specific skill
./validate-skill.sh ~/.claude/skills/pdf-processing

# Validate during CI/CD
./validate-skill.sh /path/to/skill && echo "Deployment approved"
```

### Output

```
🔍 Validating skill at: /path/to/skill

✓ PASS: YAML frontmatter detected
✓ PASS: Name field present: skill-name
✓ PASS: Name uses valid format (lowercase, numbers, hyphens)
✓ PASS: Description includes trigger phrases
✓ PASS: SKILL.md size OK (245/500 lines)

📋 Checking recommended sections...
✓ Found: 'When to Use' section
✓ Found: 'Core Pattern' section

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ VALIDATION PASSED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Workflow Integration

### Creating New Skill

```bash
# 1. Initialize
./scripts/init-skill.sh my-skill "Use when..."

# 2. Edit SKILL.md
vim .claude/skills/my-skill/SKILL.md

# 3. Validate
./scripts/validate-skill.sh .claude/skills/my-skill

# 4. Test (RED-GREEN-REFACTOR)
# - Run scenario without skill (document failure)
# - Add skill to system
# - Run scenario with skill (document success)
# - Test edge cases

# 5. Deploy
# (Skill is ready when validation passes and testing complete)
```

### Pre-commit Hook (Recommended)

```bash
# .git/hooks/pre-commit
#!/bin/bash

# Validate any changed skills
for skill_dir in .claude/skills/*/; do
    if git diff --cached --name-only | grep -q "^$skill_dir"; then
        echo "Validating $skill_dir..."
        .claude/skills/skill-builder/scripts/validate-skill.sh "$skill_dir" || exit 1
    fi
done
```

---

## Troubleshooting

### "Name field missing in frontmatter"

Check SKILL.md starts with:
```yaml
---
name: skill-name
description: Use when...
---
```

### "Description too long"

Keep under 1024 chars. Move detailed explanation to SKILL.md body.

### "Description may be workflow summary"

Avoid sequential language:
- ❌ "First...then...finally"
- ❌ "Step 1, Step 2, Step 3"
- ✅ "Use when user mentions..."
- ✅ "Triggers on keywords..."

### "SKILL.md too large"

Move content to:
- `workflows/*.md` for step-by-step procedures
- `reference/*.md` for deep documentation
- `tools/*.md` for MCP/API details

---

## Cross-Platform Compatibility

Both scripts support:
- macOS (tested)
- Linux (compatible)
- Windows (via Git Bash or WSL)

Requirements:
- Bash 3.2+
- Standard Unix utilities (sed, awk, grep)
- No external dependencies

---

## See Also

- `../SKILL.md` - Main skill-builder documentation
- `../workflows/create-skill.md` - Interactive creation workflow
- `../reference/best-practices.md` - Skill design patterns
- `../reference/testing-patterns.md` - RED-GREEN-REFACTOR methodology
