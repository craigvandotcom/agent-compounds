---
name: skill-builder
description: Use when creating new Claude Code skills, editing existing skills, refactoring oversized SKILL.md files, or converting documentation/subagents to skills. Guides SKILL.md structure, the spine+references split, YAML frontmatter, progressive disclosure, and RED-GREEN testing. Triggers on "create a skill", "build a skill", "refactor this skill", "convert to a skill", "improve this skill's description".
---

> **Shared skill (agent-compounds).** Symlinked into projects via `deploy.sh` — this is the single source of truth; edit here, not in a consumer copy. Method-only and portable (no project facts).

# Skill Builder

**Purpose:** Meta-skill for creating, editing, refining, and refactoring Claude Code skills
**Status:** Complete

---

## When to Use This Skill

**Intent Triggers:**
- Creating a new skill from scratch
- Improving an existing skill's structure or description
- Converting subagent definitions to skill format
- Organizing skill workflows and reference files
- Applying progressive disclosure to documentation

**Example Phrases:**
- "Create a skill for X"
- "Help me build a skill that does Y"
- "Convert this workflow to a skill"
- "Improve this skill's description"

---

## Core Principles

### 1. Test-Driven Skill Development (RED-GREEN-REFACTOR)

**From obra/superpowers:** "If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing."

1. **RED:** Run scenarios without the skill, document actual behavior
2. **GREEN:** Write minimal skill addressing identified failures
3. **REFACTOR:** Close loopholes from agent rationalizations

### 2. Progressive Disclosure

**Three-stage loading for token efficiency:**
- **Stage 1 (Discovery):** Only YAML frontmatter (~100 tokens)
- **Stage 2 (Invocation):** Full SKILL.md when activated (500-2000 tokens)
- **Stage 3 (Resources):** Supporting files loaded on-demand

### 3. Description is Critical

The YAML `description` determines skill discovery. Must include:
- What the skill does (specific capabilities)
- When to use it (trigger terms users would mention)
- Max 1024 characters

**CRITICAL: Descriptions must focus on WHEN (triggering conditions), NOT HOW (workflow summary).**

When descriptions summarize workflow, agents follow the summary instead of reading full content. This bypasses the skill's detailed guidance.

**Bad (workflow summary):**
```yaml
description: Helps write tests first, then implement features, then refactor code for quality.
```
Agent reads this and thinks "I know the workflow" - never reads the full skill content.

**Good (triggering conditions):**
```yaml
description: Use when implementing new features, fixing bugs, or adding functionality. Applies when writing code that needs reliability. Triggers on "add feature", "fix bug", "implement X".
```
Agent recognizes the scenario matches and loads the full skill for detailed guidance.

### 4. Spine + References Structure

A non-trivial skill is a **lean spine that routes to references**, not a wall of everything. The SKILL.md spine holds what the *orchestrator* needs (workflow phases, decision trees, routing rules, constraints); everything only a *sub-agent or single stage* consumes (sub-agent prompts, output templates, schemas, mode variants) goes to `references/`, loaded on demand.

**The discriminator:** *Does the orchestrator itself need this to decide what to do next, or does only a spawned sub-agent / one stage consume it?* Orchestrator → spine. Sub-agent/stage → `references/`.

Full rulebook (spine vs references, pointer syntax, ToC rule, refactor procedure): **[reference/structure-standard.md](reference/structure-standard.md)**. Read it before writing a large skill or refactoring an oversized one.

---

## Commands are skills now

Anthropic merged custom commands into skills: a `.claude/commands/x.md` and a `.claude/skills/x/SKILL.md` both create `/x`. So:

- A **task skill** the user triggers like a slash command → set `disable-model-invocation: true` (manual-only, behaves exactly like the old command, plus `references/`).
- A **reference skill** Claude should auto-apply when relevant → omit that field so the model can invoke it.

Don't author new `.claude/commands/*.md` files — author skills.

---

## SKILL.md Structure

```yaml
---
name: skill-name          # Max 64 chars, lowercase/numbers/hyphens only
description: Use when...  # Max 1024 chars, third-person, concrete triggers
---

# Skill Name

**Purpose:** [One sentence]
**Domain:** [Area of functionality]
**Status:** [MVP / Complete / Planned]

---

## When to Use This Skill

**Intent Triggers:**
- [Specific scenarios]

**When NOT to Use:**
- [Exclusions]

---

## Core Pattern

[Main technique or workflow - the "how"]

---

## Quick Reference

[Scannable table or bullets for fast lookup]

---

## Supporting Documentation

| File | When to Read |
|------|--------------|
| `file.md` | [Trigger condition] |

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| [Problem] | [Solution] |
```

---

## Size Constraints

| File Type | Target Size | Action if Exceeded |
|-----------|-------------|-------------------|
| SKILL.md | 200-400 lines | Split to supporting files |
| workflows/*.md | <500 lines | Break into smaller workflows |
| tools/*.md | <1000 lines | Split by tool group |
| reference/*.md | varies | Keep focused on single topic |

**Note:** Anthropic's actual average is ~2,200 words (1,500-2,000 optimal). Target 200-400 lines for balance between completeness and context efficiency.

---

## Skill Testing Protocol

**CRITICAL: Skills must be tested before deployment.**

### RED-GREEN-REFACTOR for Skills

From obra/superpowers: "If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing."

**1. RED: Establish Baseline Failure**
- Run scenario without skill installed
- Document actual agent behavior
- Identify what goes wrong
- Capture specific failure modes

**2. GREEN: Verify Skill Success**
- Add skill to system
- Run same scenario again
- Verify agent now succeeds
- Document what changed

**3. REFACTOR: Close Rationalization Loopholes**
- Watch for agent workarounds ("I thought X was acceptable...")
- Add explicit guidance to prevent shortcuts
- Test edge cases
- Tighten descriptions if skill isn't triggering

### Natural Language Trigger Testing

**Test that skills activate from natural prompts without explicit mentions.**

**Example test cases:**
```
Skill: test-driven-development
✓ "Add login feature to the app"
✓ "Fix the payment processing bug"
✗ "Review this code for me" (reading only, not implementing)

Skill: skill-builder
✓ "Create a skill for processing PDFs"
✓ "Help me organize this workflow into a skill"
✗ "What are all the skills available?" (query, not creation)
```

### Common Rationalization Loopholes

| Agent Says | What It Means | Fix |
|------------|---------------|-----|
| "Too simple to need skill" | Avoiding proper workflow | Add "even simple tasks" to description |
| "I'll test after implementation" | Skipping verification | Make testing mandatory in workflow |
| "This is just a quick fix" | Bypassing standards | Add "all changes require..." constraint |
| "Already manually verified" | Avoiding documented verification | Require specific commands run |

---

## Verification Gate

**Before claiming skill is complete, you must pass this gate:**

**Step 1: Demonstrate Failure**
- [ ] Run scenario without skill
- [ ] Document what agent does wrong
- [ ] Capture specific failure (not hypothetical)

**Step 2: Demonstrate Success**
- [ ] Install skill
- [ ] Run exact same scenario
- [ ] Agent now succeeds
- [ ] Document what skill enabled

**Step 3: Test Edge Cases**
- [ ] Try 2-3 variations of trigger phrases
- [ ] Verify skill activates from natural language
- [ ] Confirm skill does NOT activate on exclusions
- [ ] Close any rationalization loopholes discovered

**Step 4: Evidence Review**
- [ ] Show before/after comparison
- [ ] Explain what changed
- [ ] Confirm skill teaching the right thing

**You cannot skip this gate. No rationalizations accepted:**
- ✗ "Testing would be redundant"
- ✗ "The skill is too simple to test"
- ✗ "I'll verify it works in production"
- ✗ "Manual testing is sufficient"

**Only acceptable outcome:** Documented evidence of failure → success → edge cases covered.

---

## Writing Style Guide

### Voice and Tone

**For Instructions (imperative):**
- "Validate input before processing"
- "Load reference documentation when needed"
- "Test scenarios without skill first"

**For Descriptions (third-person):**
- "Use when user needs validation"
- "Applies to scenarios requiring X"
- "Triggers on mentions of Y"

**For Explanations (active voice):**
- "This pattern enables X"
- "The verification step catches Y"
- "Progressive disclosure reduces context bloat"

### Trigger Phrase Specificity

**Vague (low activation accuracy):**
```yaml
description: Helps with task management and organization.
```

**Specific (high activation accuracy):**
```yaml
description: Use when user mentions tasks, todos, deadlines, reminders, calendar events, scheduling, or daily planning. Handles task creation, prioritization, and time blocking.
```

**Pattern:** List concrete nouns/verbs users actually say, not abstract purposes.

---

## Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/init-skill.sh` | Initialize new skill from template | `./init-skill.sh skill-name "Description"` |
| `scripts/validate-skill.sh` | Validate skill meets standards | `./validate-skill.sh /path/to/skill/` |

**init-skill.sh** creates:
- SKILL.md with YAML frontmatter pre-filled
- Empty workflows/ and reference/ directories
- README.md with next steps checklist

**validate-skill.sh** checks:
- YAML frontmatter format
- Name/description constraints
- Size limits (warns >400 lines, fails >500)
- Trigger phrase presence
- Workflow summary anti-patterns

---

## Available Workflows

| Workflow | Purpose |
|----------|---------|
| `workflows/create-skill.md` | Interactive skill creation |
| `workflows/refine-skill.md` | Improve existing skill |
| `workflows/convert-to-skill.md` | Convert docs/subagents to skill |

---

## Reference Documentation

| File | Contents |
|------|----------|
| `reference/structure-standard.md` | **The spine+references rulebook** — read before writing/refactoring a large skill |
| `reference/skill-template.md` | Copy-paste starting template for a new SKILL.md |
| `reference/best-practices.md` | Anthropic + community patterns (description, naming, progressive disclosure) |
| `reference/testing-patterns.md` | RED-GREEN-REFACTOR testing methodology |

---

## Skill Placement Decision

Before creating a skill, decide where it lives:

```
Is it generic/portable (method-only, no project facts)?
├─ YES → agent-compounds/skills/<name>/ (the shared collection)
│         Deploy into consuming projects with deploy.sh (relative symlinks).
│         Edit the canonical copy in agent-compounds; never the symlinked copy.
│
└─ NO → Is it app/brand/identity-specific?
         ├─ YES → the app's own .claude/skills/<name>/ (REAL, never symlinked).
         │         App facts (schema, routes, domain rules, brand voice) belong here,
         │         typically under the app's CORE skill — not in a shared skill.
         │
         └─ ONE-OFF → don't make a skill; put it in CLAUDE.md / AGENTS.md.
```

**Rule of thumb:** a shared skill teaches the *how* (technique, portable across apps); per-app CORE holds the *what* (this app's specific facts). If you're tempted to bake an app fact into a shared skill, that fact belongs in the app's CORE instead.

---

## Quick Checklist

Before deploying a skill:

- [ ] Placement determined using decision tree above
- [ ] Description under 1024 chars with concrete triggers
- [ ] **Description focuses on WHEN (triggers) not HOW (workflow)**
- [ ] Name uses lowercase/numbers/hyphens only (max 64 chars)
- [ ] SKILL.md between 200-400 lines (under 500 max)
- [ ] **Tested: natural prompts trigger skill without explicit mentions**
- [ ] **Verification gate passed (fail → success → edge cases)**
- [ ] Supporting files referenced, not duplicated
- [ ] Progressive disclosure: load on-demand, not upfront
- [ ] Symlinks created if shared across projects
- [ ] Writing style: imperative instructions, third-person descriptions
