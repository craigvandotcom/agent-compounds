# Skill Testing Patterns

Patterns for testing skills using RED-GREEN-REFACTOR methodology from obra/superpowers.

---

## The Iron Law

**"If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing."**

This principle prevents:
- Skills that teach what agents already know
- Assumptions about what's needed
- Missing critical failure modes
- Untested documentation

---

## Test-Driven Skill Development

### Phase 1: RED (Baseline Failure)

**Goal:** Document what actually goes wrong without the skill.

**Process:**
1. Remove skill from system (or test in clean environment)
2. Run realistic scenario using natural language
3. Observe agent behavior WITHOUT intervening
4. Document specific failures (not hypotheticals)
5. Capture agent outputs, decisions, rationalizations

**Example Documentation:**
```markdown
## Baseline Test: Feature Implementation

Prompt: "Add user login feature with email/password"

Agent Behavior:
- Jumped straight to implementation
- No tests written
- Created auth.js with login function
- Added basic validation
- Stopped without verification

Result: Code written, no test coverage, no verification run
```

### Phase 2: GREEN (Skill Success)

**Goal:** Verify skill teaches agent the correct behavior.

**Process:**
1. Add skill to system
2. Run EXACT same scenario again
3. Observe agent behavior WITH skill
4. Document changes in behavior
5. Confirm skill guidance was followed

**Example Documentation:**
```markdown
## With test-driven-development Skill

Prompt: "Add user login feature with email/password"

Agent Behavior:
- Loaded test-driven-development skill
- Created auth.test.js first
- Wrote failing test for login function
- Ran test, verified failure
- Implemented auth.js
- Ran test, verified pass
- Committed with test

Result: Feature implemented with test coverage, verification documented
```

### Phase 3: REFACTOR (Close Loopholes)

**Goal:** Close rationalization loopholes and edge cases.

**Process:**
1. Test variations and edge cases
2. Look for agent workarounds
3. Document rationalizations
4. Strengthen skill guidance
5. Re-test to confirm loophole closed

**Common Loopholes:**

| Agent Rationalization | Indicates | Fix |
|----------------------|-----------|-----|
| "This is too simple to test" | Avoiding test discipline | Add "even simple features require tests" |
| "I'll add tests after confirming it works" | Reversing TDD order | Make RED phase mandatory |
| "Manual testing showed it works" | Avoiding documented verification | Require specific test commands |
| "Tests would be redundant here" | Finding exceptions | Add "no exceptions" constraint |

**Example Refinement:**
```markdown
Before:
"Write tests for your code"

After:
"Write failing test BEFORE implementation. No exceptions.
Even for simple features. Manual testing does not replace test files."
```

---

## Natural Language Trigger Testing

**Goal:** Verify skill activates from realistic prompts without explicit mentions.

### Test Case Format

```markdown
## Trigger Test: [Skill Name]

Should Activate:
✓ "[Natural prompt 1]"
✓ "[Natural prompt 2]"
✓ "[Natural prompt 3]"

Should NOT Activate:
✗ "[Exclusion prompt 1]"
✗ "[Exclusion prompt 2]"

Results:
- [Document which prompts triggered skill]
- [Document false positives/negatives]
- [Refine description if needed]
```

### Example Test Cases

**Skill: test-driven-development**

```markdown
Should Activate:
✓ "Add login feature to the app"
✓ "Fix the bug in payment processing"
✓ "Implement user profile editing"
✓ "Build the search functionality"

Should NOT Activate:
✗ "Review this code for me" (reading only)
✗ "What does this function do?" (analysis only)
✗ "Explain how authentication works" (educational)

Results:
- All implementation prompts triggered skill ✓
- Analysis-only prompts did not trigger ✓
- Description accurately distinguishes scenarios ✓
```

**Skill: pdf-processing**

```markdown
Should Activate:
✓ "Extract text from this PDF"
✓ "Parse data from quarterly_report.pdf"
✓ "Pull the tables out of this document"
✓ "Read the invoice PDF and get line items"

Should NOT Activate:
✗ "List all PDFs in this folder" (file system query)
✗ "Which PDF has the contract?" (search only)
✗ "Send this PDF to accounting" (email task)

Results:
- Processing/extraction prompts triggered ✓
- File operations did not trigger ✓
- One false negative: "Get data from PDF" didn't trigger
  → Added "get data" to description triggers
```

---

## Verification Gate Protocol

Four-step gate that must be passed before skill is complete.

### Step 1: Demonstrate Failure

**Required Evidence:**
- [ ] Scenario description (natural language prompt)
- [ ] Agent behavior without skill (actual, not theoretical)
- [ ] Specific failure modes identified
- [ ] Screenshots or output logs

**Minimum Standard:** Real test run, documented behavior, clear failure.

### Step 2: Demonstrate Success

**Required Evidence:**
- [ ] Same scenario run with skill
- [ ] Agent behavior changed
- [ ] Skill guidance followed
- [ ] Success confirmed

**Minimum Standard:** Before/after comparison shows skill made difference.

### Step 3: Test Edge Cases

**Required Evidence:**
- [ ] 2-3 trigger phrase variations tested
- [ ] Natural language activation confirmed
- [ ] Exclusion cases tested (should NOT activate)
- [ ] Rationalization loopholes identified and closed

**Minimum Standard:** Multiple scenarios, both positive and negative cases.

### Step 4: Evidence Review

**Required Evidence:**
- [ ] Clear before/after comparison
- [ ] Explanation of what changed
- [ ] Confirmation skill teaches right thing
- [ ] No rationalizations or skipped steps

**Minimum Standard:** Complete documentation, honest assessment.

---

## Common Testing Mistakes

| Mistake | Why It's Bad | Fix |
|---------|--------------|-----|
| Hypothetical failures | Don't know what actually breaks | Run real tests |
| Testing after writing | Confirms bias, misses issues | Test first (RED) |
| Single scenario | Miss edge cases and loopholes | Test variations |
| Skipping exclusions | False positive activations | Test negative cases |
| Accepting rationalizations | Loopholes remain open | Document and close |
| Testing with skill mentions | Not realistic usage | Natural language only |

---

## Testing Workflow Summary

```
1. RED: Remove skill
   ↓
2. Run scenario with natural language
   ↓
3. Document actual failure
   ↓
4. GREEN: Add skill
   ↓
5. Run same scenario
   ↓
6. Document success
   ↓
7. REFACTOR: Test variations
   ↓
8. Close loopholes
   ↓
9. Test edge cases
   ↓
10. Verify triggers work
    ↓
11. Test exclusions
    ↓
12. Pass verification gate
    ↓
13. Deploy skill
```

---

## Resources

- **obra/superpowers:** Originated RED-GREEN-REFACTOR for skills
- **obra/superpowers/tests/skill-triggering:** Example test suite
- **Anthropic Skills Spec:** Progressive disclosure, trigger optimization
- **skill-builder/SKILL.md:** Verification gate section

---

## When to Use This Reference

Load this file when:
- Testing a new skill
- Debugging skill activation issues
- Closing rationalization loopholes
- Verifying trigger phrases work
- Passing verification gate
