# Refine Skill Workflow

Workflow for improving an existing skill's effectiveness.

---

## Phase 1: Audit Current State

### 1.1 Read the Skill

- Load SKILL.md completely
- Check all supporting files
- Note current structure

### 1.2 Measure Against Standards

| Check | Standard | Current |
|-------|----------|---------|
| Description length | ≤1024 chars | ? |
| SKILL.md size | ≤250 lines | ? |
| Name format | lowercase/hyphens | ? |
| Triggers concrete? | Specific keywords | ? |
| Progressive disclosure? | References not duplicates | ? |

### 1.3 Identify Issues

Common problems:
- Vague description (doesn't trigger correctly)
- Too long (bloats context)
- Missing "when NOT to use"
- Duplicated content (should be references)
- No quick reference section

---

## Phase 2: Description Optimization

**Current description analysis:**
1. Does it say WHAT the skill does?
2. Does it say WHEN to use it?
3. Are trigger terms concrete?
4. Is it under 1024 chars?

**Optimization template:**
```
Use when [specific scenarios with keywords]. Handles [capabilities].
Triggers on [concrete terms users would say].
```

**CSO (Claude Search Optimization):**
- Include problem descriptions, not just solutions
- Add technology context when relevant
- List symptoms that indicate need

---

## Phase 3: Structure Optimization

### 3.1 Size Check

If SKILL.md > 250 lines:
1. Identify content that's not needed for every invocation
2. Move to supporting files
3. Add reference table in SKILL.md

### 3.2 Progressive Disclosure Audit

**Should be in SKILL.md:**
- Core pattern (the main technique)
- When to use / not use
- Quick reference
- Supporting file references

**Should be in supporting files:**
- Detailed procedures (workflows/)
- Full tool documentation (tools/)
- Background knowledge (reference/)

### 3.3 Quick Reference Addition

If missing, add scannable section:
```markdown
## Quick Reference

| Action | Command/Pattern |
|--------|-----------------|
| [Task] | [How] |
```

---

## Phase 4: Testing Improvements

### 4.1 Before/After Comparison

Run test scenarios:
1. Does skill trigger when expected?
2. Does agent follow pattern correctly?
3. Are there false activations?

### 4.2 Edge Case Testing

- Test with ambiguous queries
- Test with similar-but-different scenarios
- Verify "when NOT to use" exclusions work

---

## Phase 5: Documentation Updates

### 5.1 Update Cross-References

If skill structure changed:
- Update any skills that reference this one
- Update agent definitions if applicable
- Update CLAUDE.md if mentioned

### 5.2 Version Note (optional)

Add to bottom of SKILL.md:
```markdown
---
**Last Updated:** YYYY-MM-DD
**Changes:** [Brief description]
```

---

## Output Summary

Document improvements made:
- [ ] Description optimized
- [ ] Size reduced (if over limit)
- [ ] Progressive disclosure applied
- [ ] Quick reference added/improved
- [ ] Testing verified improvements
- [ ] Cross-references updated
