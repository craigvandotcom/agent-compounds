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
| Description length | ≤1024 chars, strongest trigger first | ? |
| SKILL.md size | 200-400 lines target (enforcement-heavy pipeline skills may exceed — judge by token buckets, not line count) | ? |
| Name format | lowercase/hyphens | ? |
| Triggers concrete? | Specific keywords | ? |
| Progressive disclosure? | References not duplicates — for payload, never for enforcement content | ? |
| Registry budget | `validate-skill.sh --registry` under listing budget | ? |

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

### 3.0 Constraint Inventory (MANDATORY before any cut or move)

This is the mechanism that guarantees a refinement loses zero function. No text is
removed or relocated until its inventory entry exists.

1. **Extract every behavioral rule** from the current skill into a numbered checklist —
   every instruction, gate, branch, completion criterion, exact option set, and
   standing constraint. If a sentence changes agent behavior, it's a rule; list it.
2. **Classify each rule's tokens** by bucket (SKILL.md § Token Economy /
   `references/token-economics.md`): enforcement / discovery / persuasion / sediment.
3. **Rewrite under the cut rule:** enforcement stays inline (or moves UP the hierarchy,
   e.g. prose procedure → bundled script); persuasion compresses to rule + one-clause
   why; only restatements and no-op sentences are truly deleted. Anything moved to a
   reference gets a when-to-read condition on the pointer.
4. **Verify survival:** an independent validator (validator-stance subagent) walks the
   checklist against the rewrite and confirms every rule survives — in the spine, in a
   script, or behind a condition-labeled pointer — and flags any rule that got weaker
   on the enforcement hierarchy. A weakened rule is a FAIL: restore it or move it up.

**For a structural DIET (oversized SKILL.md, section-level extraction — not just rule
polish), use `workflows/hygiene-pass.md` instead** — it adds the section-by-section
CORE/EXTRACT/CUT cartography, the `_shared/` centralization decision, the orchestrator-trap
gate for child-spawn prompts, and a registry-wide batch mode. Phase 3.0 here is the
rule-granularity survival gate; hygiene-pass is the section-granularity diet that calls it.

### 3.1 Size Check

If SKILL.md exceeds its target (and the excess is not enforcement content):
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
- Background knowledge (references/)
- **Blocks used verbatim by ≥2 skills → `_shared/`, not this skill's `references/`** (structure-standard § _shared/). If a rewrite target duplicates a block another skill also carries, promote to `_shared/` and repoint both — don't fork a second copy.

> Progressive disclosure is for **optional payload only**. Never move enforcement content that loads every run behind a pointer (token-economics §3) — and never point a freshly-spawned child at a file (the orchestrator trap): its prompt must be pasted inline. See hygiene-pass A3.

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

### 5.1 Update Cross-References + Pointer Integrity

If skill structure changed:
- Update any skills that reference this one
- Update agent definitions if applicable
- Update CLAUDE.md if mentioned
- **Grep the registry for the moved block's old section title / file path** — sibling skills that
  pointed at it by name are now dangling; fix them in the same commit (coordinated multi-site edit).
- **Re-run `validate-skill.sh <skill-dir>`** — the pointer-integrity check must pass (no reference
  named in the spine is missing; no reference file is orphaned). A half-updated pointer graph is a
  regression, not a refinement.

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
- [ ] Constraint inventory written and every rule verified surviving (Phase 3.0)
- [ ] Description optimized
- [ ] Size reduced (if over limit)
- [ ] Progressive disclosure applied
- [ ] Quick reference added/improved
- [ ] Testing verified improvements
- [ ] Cross-references updated
