# Create Skill Workflow

Interactive workflow for creating a new Claude Code skill from scratch.

---

## Phase 1: Discovery

**Ask these questions:**

1. **What problem does this skill solve?**
   - What capability is missing?
   - What tasks would it handle?

2. **What triggers should activate it?**
   - Keywords users would mention
   - Scenarios where it applies
   - When should it NOT activate?

3. **What tools/resources does it need?**
   - MCP servers?
   - External APIs?
   - File access patterns?

4. **Simple or complex?**
   - Self-contained (single SKILL.md)?
   - With workflows (multi-step processes)?
   - With tools (external integrations)?

5. **Have you checked existing implementations?**
   - Review the structure standard: `references/structure-standard.md`
   - Search for similar skills in Fabric/AI Template Library/Composio
   - Study 2-3 examples before writing

---

## Phase 2: Design

### 2.1 Craft the Description

**Template:**
```
Use when [specific scenarios]. Handles [capabilities]. Triggers on [keywords/phrases].
```

**Checklist:**
- [ ] Under 1024 characters
- [ ] Third person ("Use when..." not "I help with...")
- [ ] Concrete trigger terms (not vague)
- [ ] Includes what AND when

### 2.2 Choose the Name

**Rules:**
- Max 64 characters
- Lowercase letters, numbers, hyphens only
- Gerund form preferred: `processing-pdfs` not `pdf-processor`

### 2.3 Outline Structure

**Minimal skill:**
```
skill-name/
└── SKILL.md
```

**With workflows:**
```
skill-name/
├── SKILL.md
└── workflows/
    └── [workflow-name].md
```

**With tools:**
```
skill-name/
├── SKILL.md
├── workflows/
└── tools/
    └── [tool-name].md
```

---

## Phase 3: Implementation

### 3.1 Create Directory

```bash
mkdir -p .claude/skills/[skill-name]/workflows
```

### 3.2 Write SKILL.md

Start from template: `references/skill-template.md`

**Required sections:**
1. YAML frontmatter (name, description)
2. Purpose statement
3. When to Use (triggers + exclusions)
4. Core Pattern (the main technique)
5. Quick Reference (scannable)
6. Supporting Documentation table (if any)

**Size target:** 150-250 lines max

### 3.3 Create Supporting Files (if needed)

- `workflows/*.md` - Step-by-step procedures
- `tools/*.md` - MCP/API documentation
- `references/*.md` - Background knowledge

---

## Phase 4: Testing (RED-GREEN-REFACTOR)

**CRITICAL: You must pass the verification gate before marking skill complete.**

### 4.1 RED: Establish Baseline Failure

Run scenarios WITHOUT the skill:
- What does the agent do?
- Where does it fail or produce suboptimal results?
- Document actual behavior (not hypothetical)
- Capture specific failure modes

**Example documentation:**
```
Scenario: "Add user authentication to the app"
Without skill: Agent writes code directly without tests
Result: Implementation works but has no test coverage
```

### 4.2 GREEN: Verify Skill Success

Run same scenarios WITH the skill:
- Does agent now succeed?
- Does it follow the documented pattern?
- Identify any gaps
- Document what changed

**Example documentation:**
```
Scenario: "Add user authentication to the app"
With skill: Agent writes failing test first, then implementation
Result: Feature implemented with test coverage
```

### 4.3 REFACTOR: Close Loopholes

Look for agent rationalizations:
- "I thought X was acceptable because..."
- "The skill didn't explicitly say..."
- "This seemed like an exception..."

Add explicit guidance to close these loopholes.

### 4.4 Test Natural Language Triggers

Verify skill activates from natural prompts:
- Try 2-3 variations of trigger phrases
- No explicit skill mentions in prompts
- Confirm skill loads automatically
- Test exclusion cases (should NOT trigger)

**Example test cases:**
```
✓ Should trigger: "Build a PDF parser"
✓ Should trigger: "Extract data from this PDF"
✗ Should NOT trigger: "What PDFs are in this folder?" (query only)
```

---

## Phase 5: Integration

### 5.1 Cross-Skill References

If skill uses other skills:
```markdown
**Cross-Skill Usage:**
- Uses `admin` skill for calendar operations
- Uses `researcher` for web lookups
```

### 5.2 Subagent Integration (if applicable)

Update relevant agent definition in `.claude/agents/`:
```markdown
**Skills to Load:**
- `skill-builder` for skill creation tasks
```

---

## Output Checklist

Before marking complete:

- [ ] SKILL.md created with valid YAML frontmatter
- [ ] Description under 1024 chars with concrete triggers
- [ ] **Description focuses on WHEN (triggers) not HOW (workflow summary)**
- [ ] Name follows conventions (lowercase, hyphens, max 64)
- [ ] Size 200-400 lines (supporting files for overflow)
- [ ] **Tested: baseline failure → skill success → loopholes closed**
- [ ] **Natural language trigger testing passed**
- [ ] **Verification gate passed (4 steps documented)**
- [ ] Progressive disclosure: references not duplicates
- [ ] Run `scripts/validate-skill.sh` - all checks pass
- [ ] Writing style: imperative instructions, third-person descriptions
