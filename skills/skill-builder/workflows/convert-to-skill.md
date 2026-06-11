# Convert to Skill Workflow

Convert existing documentation, subagents, or workflows into proper skill format.

---

## Source Types

### A. Converting Subagent to Skill

**When to convert:**
- Subagent has reusable patterns
- Logic could benefit other agents
- Want model-invoked activation (vs explicit delegation)

**Process:**
1. Read agent definition from `.claude/agents/[agent].md`
2. Extract reusable instructions (not agent-specific)
3. Create skill with those patterns
4. Update agent to reference skill

### B. Converting Documentation to Skill

**When to convert:**
- Docs contain procedural knowledge
- Patterns are reusable across contexts
- Want Claude to auto-apply the knowledge

**Process:**
1. Identify actionable patterns (not just reference info)
2. Extract "when to use" triggers
3. Structure as skill with workflows

### C. Converting Workflow to Skill

**When to convert:**
- Workflow is standalone (not skill-dependent)
- Could be triggered automatically
- Reusable across projects

**Process:**
1. Create skill wrapper with description
2. Move workflow to skill's workflows/ folder
3. Add triggers and pattern summary to SKILL.md

---

## Phase 1: Analysis

### 1.1 Read Source Material

- Load all relevant files
- Identify core patterns/procedures
- Note dependencies

### 1.2 Extract Key Elements

| Element | Source Location | Skill Destination |
|---------|-----------------|-------------------|
| Purpose | [where] | SKILL.md header |
| Triggers | [where] | YAML description |
| Pattern | [where] | Core Pattern section |
| Steps | [where] | workflows/*.md |
| Tools | [where] | tools/*.md or references |

### 1.3 Determine Skill Type

**Self-contained:** Single SKILL.md, no supporting files
- Use when: Simple pattern, <250 lines total

**With workflows:** SKILL.md + workflows/
- Use when: Multi-step procedures needed

**With tools:** SKILL.md + tools/
- Use when: MCP/API documentation needed

---

## Phase 2: Structure Creation

### 2.1 Create Directory

```bash
mkdir -p .claude/skills/[skill-name]/workflows
```

### 2.2 Draft YAML Frontmatter

From source material, construct:
```yaml
---
name: [extracted-name]
description: Use when [triggers from source]. Handles [capabilities].
---
```

### 2.3 Map Content to Sections

| Source Content | Maps To |
|---------------|---------|
| "What it does" | Purpose statement |
| "When to use" | Intent Triggers |
| "How it works" | Core Pattern |
| Step-by-step | workflows/*.md |
| Tool details | tools/*.md |
| Background info | references/*.md |

---

## Phase 3: Content Migration

### 3.1 Write SKILL.md

**Include:**
- YAML frontmatter
- Purpose (1 sentence)
- When to Use (triggers + exclusions)
- Core Pattern (condensed how-to)
- Quick Reference (scannable)
- Supporting Documentation table

**Exclude from SKILL.md:**
- Full step-by-step procedures → workflows/
- Complete tool documentation → tools/
- Extended background → references/

### 3.2 Create Supporting Files

Only if needed:
- `workflows/[name].md` - Detailed procedures
- `tools/[name].md` - Tool documentation
- `references/[name].md` - Background knowledge

### 3.3 Add References

In SKILL.md:
```markdown
## Supporting Documentation

| File | When to Read |
|------|--------------|
| `workflows/procedure.md` | [Trigger condition] |
```

---

## Phase 4: Source Cleanup

### 4.1 Update Original Source

**If converting subagent:**
```markdown
# [Agent Name]

...

**Skills to Load:**
- `[new-skill-name]` for [capability]
```

**If converting docs:**
- Add pointer to new skill location
- Or delete if fully migrated

### 4.2 Update Cross-References

Search for references to original:
```bash
grep -r "[original-name]" .claude/
```

Update to reference new skill.

---

## Phase 5: Validation

### 5.1 Structure Check

- [ ] SKILL.md has valid YAML frontmatter
- [ ] Description under 1024 chars
- [ ] Name follows conventions
- [ ] Size under 250 lines
- [ ] Supporting files properly referenced

### 5.2 Functionality Check

- [ ] Skill triggers on expected scenarios
- [ ] Pattern is correctly extracted
- [ ] No broken references
- [ ] Original source updated/removed

---

## Output Summary

| Item | Status |
|------|--------|
| Source analyzed | ✓ |
| Skill created | `[path]` |
| Workflows migrated | `[count]` |
| Source updated | ✓ |
| Cross-refs fixed | ✓ |
