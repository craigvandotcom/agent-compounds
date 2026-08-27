# Skill Building Best Practices

Compiled from Anthropic documentation, metaskills/skill-builder, and obra/superpowers.

---

## Official Anthropic Guidelines

### Core Principles

1. **Conciseness** - Keep skills focused and scannable
2. **Degrees of Freedom** - Constrain where needed, allow flexibility elsewhere
3. **Progressive Disclosure** - Load only what's needed, when needed

**Registry override:** conciseness and progressive disclosure are subordinate to
determinism here. Enforcement content (run ledgers, explicit branches, point-of-use
repetition) stays inline even when it makes a skill long — a pointer is the weakest
enforcement mechanism. The full framework (token buckets, enforcement hierarchy, hard
budgets): `token-economics.md`. Apply it before cutting anything.

### Description Field (Critical)

The description determines whether Claude activates the skill.

**Requirements:**
- Max 1024 characters
- Third person ("Use when..." not "I help with...")
- Include WHAT it does AND WHEN to use it
- Concrete trigger terms users would actually say

**CRITICAL PRINCIPLE: Focus on WHEN (triggers), NOT HOW (workflow).**

When descriptions summarize workflow, agents follow the summary instead of reading full skill content. This is a common failure mode discovered in obra/superpowers testing.

**Anti-Pattern (Workflow Summary):**
```yaml
description: Helps you write tests first, implement features second, then refactor for quality.
```
Problem: Agent reads the summary and thinks "I know the process" - never loads full skill.

**Correct Pattern (Triggering Conditions):**
```yaml
description: Use when implementing new features, fixing bugs, or adding functionality. Applies when code needs reliability. Triggers on "add feature", "fix bug", "implement", "build".
```
Result: Agent recognizes scenario matches, loads full skill for detailed guidance.

**CSO (Claude Search Optimization):**
- Answer: "Should the agent read this skill NOW?"
- Include problem descriptions, not just solutions
- Add technology context when relevant
- List symptoms that indicate need
- List concrete nouns/verbs users actually say

### SKILL.md Structure

**Target: 200-400 lines** (max 500). Anthropic's actual average is ~2,200 words (1,500-2,000 optimal). Split to reference files if larger.

**Required sections:**
1. YAML frontmatter (name, description)
2. When to Use (triggers)
3. Core Pattern (main technique)
4. Quick Reference (scannable)

**Optional sections:**
- When NOT to Use
- Common Mistakes
- Supporting Documentation table
- Examples

### Name Conventions

- Max 64 characters
- Lowercase letters, numbers, hyphens only
- Gerund form preferred: `processing-pdfs` not `pdf-processor`
- Descriptive: `analyzing-spreadsheets` not `xlsx-skill`

---

## From metaskills/skill-builder

### CLI-First Mindset

Skills should leverage command-line tools and scripting:
- Prefer shell commands over complex code
- Use Node.js for scripting when needed
- Make skills executable, not just instructional

### Intention-Revealing Names

File and folder names should explain purpose:
- `workflows/create-skill.md` not `workflows/cs.md`
- `references/best-practices.md` not `references/bp.md`

### Convert Subagents to Skills

When subagent logic is reusable:
1. Extract the reusable patterns
2. Create skill with those patterns
3. Update agent to reference skill
4. Benefit: model-invoked activation + reusability

---

## From obra/superpowers

### Test-Driven Skill Development

**Iron Law:** No untested skills deploy.

**RED-GREEN-REFACTOR for Skills:**

1. **RED:** Run scenarios without the skill
   - Document actual agent behavior
   - Identify failures and suboptimal results
   - "If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing"

2. **GREEN:** Write minimal skill addressing failures
   - Add only what's needed to fix identified issues
   - Test that agent now succeeds

3. **REFACTOR:** Close loopholes
   - Watch for agent rationalizations ("I thought X was acceptable...")
   - Add explicit guidance to prevent workarounds
   - Build "rationalization tables" for discipline-enforcing skills

### Bulletproofing Against Rationalization

For discipline-enforcing skills:
- State: "Violating the letter IS violating the spirit"
- Create red flags lists for agent self-checking
- Test under "maximum pressure" conditions
- Close every loophole discovered in testing

### New mechanisms declare their assurance AT BIRTH

Any guard, hook, gate, or check you author must ship its four-field declaration in the
same commit — `PROBE` (how you would show it is alive) · `SCHEDULE` (what triggers it) ·
`MODE: blocking|advisory` · `ON-FAILURE: open|closed` — plus the NOT-GATED refusal shape
for anything that can decline to verify. Fail-open is legal only for `advisory`.

Canon (one owner-hosted home, do not restate it here):
**`ac-pipeline/references/assurance-declarations.md`**. Enforced by `lint.sh` Check 21.
No new mechanism ships as prose: "wired" and "working" are different claims.

### What Qualifies as a Skill

**IS a skill:**
- Reusable techniques
- Patterns applicable across contexts
- Tools and reference guides

**NOT a skill:**
- One-off solutions
- Project-specific conventions (put in CLAUDE.md)
- Information that doesn't guide behavior

---

## Progressive Disclosure Architecture

### Three-Stage Loading

| Stage | What Loads | Token Cost |
|-------|------------|------------|
| Discovery | YAML frontmatter only | ~100 tokens |
| Invocation | Full SKILL.md | 500-2000 tokens |
| Resources | Supporting files | On-demand |

### Enables Scaling

With progressive disclosure:
- 50+ skills without context bloat
- Only relevant content loads
- Efficient token usage

### Implementation

**In SKILL.md:**
```markdown
## Supporting Documentation

| File | When to Read |
|------|--------------|
| `workflows/procedure.md` | When executing [task] |
| `references/details.md` | When needing [info] |
```

**NOT in SKILL.md:**
- Full procedures (put in workflows/)
- Complete tool docs (put in tools/)
- Extended background (put in references/)

---

## Common Mistakes

| Mistake | Why It's Bad | Fix |
|---------|--------------|-----|
| Vague description | Won't trigger correctly | Add concrete keywords |
| Long SKILL.md that's sediment, not enforcement | Bloats context without buying reliability | Token-bucket test (`token-economics.md`), then split payload to supporting files |
| Duplicating content across files unmanaged | Copies drift → contradictory instructions | Script it (procedures) or mirror-mark it (prose): `<!-- mirror of x.md — edit there first -->` |
| No "when NOT to use" | False activations | Add exclusions |
| Testing after writing | Miss what skill should teach | Test first (RED) |
| Mixing concerns | Hard to maintain | One skill = one capability |

---

## Evaluation-Driven Development

From Anthropic engineering blog:

1. **Build evaluations first** - What should skill accomplish?
2. **Write minimal instructions** - Just enough to pass evals
3. **Test across models** - Haiku, Sonnet, Opus
4. **Iterate with Claude** - Claude A creates, Claude B tests

---

## Sources

- [Anthropic Skills Documentation](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
- [Anthropic Skills Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [metaskills/skill-builder](https://github.com/metaskills/skill-builder)
- [obra/superpowers](https://github.com/obra/superpowers)
- [Claude Code Best Practices - Engineering Blog](https://www.anthropic.com/engineering/claude-code-best-practices)
