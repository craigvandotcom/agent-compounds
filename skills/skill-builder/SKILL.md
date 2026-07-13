---
name: skill-builder
description: Use when creating new Claude Code skills, editing existing skills, refactoring oversized SKILL.md files, optimizing skill token cost or descriptions, or converting documentation/subagents to skills. Triggers on "create a skill", "build a skill", "refactor this skill", "convert to a skill", "improve this skill's description", "make skills token efficient", "trim this skill", "description budget".
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
- Max 1024 characters, strongest trigger first (truncation happens at the tail)

Descriptions are paid in EVERY session of every consuming app, and the total across all
visible skills must fit the listing budget (default ~15k chars; this registry deploys
`skillListingBudgetFraction: 0.02` ≈ 30k to its apps) — over budget, least-invoked
skills lose their descriptions first and natural-language triggering degrades. Check
with `validate-skill.sh --registry`; budget mechanics in
`references/token-economics.md`.

**The invocation-graph rule decides `disable-model-invocation` — never memory or budget
pressure.** If ANY other skill invokes a skill (`/name` or "run `name`" in its body),
it MUST stay model-invocable; only zero-inbound entry points (fired solely by a human
or a `prompt_file` job) may flip. New skills default to model-invocable (the safe,
cheap direction); flipping is an optimization ratified later. The graph is computed
from the files by `validate-skill.sh --registry` every run — a flipped skill with
inbound references is a hard FAIL.

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

Full rulebook (spine vs references, pointer syntax, ToC rule, refactor procedure): **[references/structure-standard.md](references/structure-standard.md)**. Read it before writing a large skill or refactoring an oversized one.

### 5. Token Economy — determinism first

**Predictability is the virtue; token cost is a symptom.** Never ask "can this be
shorter?" Ask: **what failure does this token prevent, and does an equally strong or
stronger mechanism exist for fewer tokens?** Cut only when the answer is yes.

Enforcement hierarchy (strongest → weakest): **script/hook > inline instruction at
point of use > checkable completion criterion > repetition at decision points > prose
rule at a distance > pointer to another file.** A token may move down this hierarchy
only when its job passes to something at the same level or higher. Pointers are the
*weakest* mechanism — so progressive disclosure is right for payload only some runs
need, wrong for enforcement content every run needs. Pipeline skills legitimately run
long: their length IS the enforcement.

Classify before cutting:

| Bucket | Action |
|---|---|
| **Enforcement** (run-ledger lines, explicit branches, exact option sets, point-of-use repetition, completion criteria, Remember blocks) | Keep. Replace only with something *stronger* (script/hook), never merely cheaper |
| **Discovery** (frontmatter description) | Trigger-only, front-loaded, hard-pruned — cutting here *increases* reliability |
| **Persuasion** (rationale, anecdotes) | Compress to rule + one-clause why; full stories → `references/incidents.md` or memory |
| **Sediment** (same content twice in one file, dead paths, stale layers, redundant syntax) | Pure cut, no tradeoff |

Sentence-level: the **no-op test** — does it change behavior vs. the default? If not,
delete the sentence, don't trim its words. Full payload (loading model, hard budgets
incl. the ~15k-char registry listing cliff, evidence, sources):
**[references/token-economics.md](references/token-economics.md)** — read it when
writing/refining descriptions, cutting from a skill, or auditing registry footprint.

---

## Commands are skills now

Anthropic merged custom commands into skills: a `.claude/commands/x.md` and a `.claude/skills/x/SKILL.md` both create `/x`. So:

- A **task skill** the user triggers like a slash command → set `disable-model-invocation: true` (manual-only, behaves exactly like the old command, plus `references/`) — **but ONLY if no other skill invokes it**; the invocation-graph rule (§ Description is Critical) overrides this heuristic, and `validate-skill.sh --registry` enforces it.
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
| references/*.md | varies | Keep focused on single topic |

**Note:** Anthropic's actual average is ~2,200 words (1,500-2,000 optimal). Target 200-400 lines for balance between completeness and context efficiency.

**Exception — enforcement-heavy pipeline skills:** a multi-phase orchestrator whose
length is enforcement (run ledgers, explicit branches, point-of-use repetition) may
legitimately exceed these targets. Judge it by the token-bucket test (§ Token Economy),
not the line count: over-target is fine only if what remains is enforcement, not
sediment.

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
- Empty workflows/ and references/ directories
- README.md with next steps checklist

**validate-skill.sh** checks:
- YAML frontmatter format
- Name/description constraints
- Size limits (warns >400 and >500 lines — see enforcement-heavy exception above)
- Trigger phrase presence
- Workflow summary anti-patterns
- `--registry <skills-dir>`: sums all descriptions against the ~15k-char listing budget

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
| `references/structure-standard.md` | **The spine+references rulebook** — read before writing/refactoring a large skill |
| `references/token-economics.md` | **Loading model, hard budgets, determinism framework** — read before writing/refining descriptions or cutting content |
| `references/skill-template.md` | Copy-paste starting template for a new SKILL.md |
| `references/best-practices.md` | Anthropic + community patterns (description, naming, progressive disclosure) |
| `references/testing-patterns.md` | RED-GREEN-REFACTOR testing methodology |

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

This tree decides placement *within the skill layer*. Whether something is a skill at
all (vs memory, hook, CORE, AGENTS.md) and at what directory altitude — that's the
`context-engineering` skill's PLACEMENT ladder + ALTITUDE rule; run that first.

---

## Procedure lives in `workflows/`

**`workflows/` inside a skill is the canonical home for that skill's owned
procedure** — multi-step processes a session or a scheduled job runs (a weekly review,
a seed/garden/distill cadence, an interactive create/refine flow). Level-scoped
**operating cadences** (a domain's daily heartbeat, weekly review) route to
`CORE/workflows/` at that level if no domain skill owns the topic yet, or to the owning
skill's `workflows/` if one does (e.g. `neometa/wiki/`'s garden cadence lives in the
`wiki` skill's `workflows/`, not a standalone home) — never a parallel `_agent-*/workflows/`
directory (decided 2026-07-13, `infrastructure/plans/memory-wiki-upgrade.md` Phase 2c:
the per-level persistent-agent homes that pattern came from are retired). See
`context-engineering` PLACEMENT rung 1/2 for the full routing logic; this section only
fixes *where inside the skill layer* procedure goes once PLACEMENT has already said
"skill."

**Agent construction is stances + skills, never a persistent home.** An agent is a
**stance** (researcher/implementer/validator — tool boundary + model tier, defined in
`agents/*.md`) that loads **skills** for domain knowledge at runtime; see
`context-engineering` § Subagents. There is no third category of "build a persistent
`_agent-name/` identity home" — that pattern is deprecated (the `agent-builder` skill
is scheduled for a stances+skills rewrite, bead `org-um4`). If you're tempted to give a
new agent its own directory of `memory/`/`workflows/`/`soul.md`, route each piece
through the taxonomy instead: identity → the level's `CORE`, procedure → a skill's
`workflows/`, memory → the domain substrate.

---

## Quick Checklist

Before deploying a skill:

- [ ] Placement determined using decision tree above
- [ ] Description under 1024 chars with concrete triggers, strongest first
- [ ] **Description focuses on WHEN (triggers) not HOW (workflow)**
- [ ] Registry description budget still fits (`validate-skill.sh --registry`); manual-only skills use `disable-model-invocation: true`
- [ ] Any content cut/moved passed the token-bucket test (no enforcement tokens weakened)
- [ ] Name uses lowercase/numbers/hyphens only (max 64 chars)
- [ ] SKILL.md between 200-400 lines (under 500 max)
- [ ] **Tested: natural prompts trigger skill without explicit mentions**
- [ ] **Verification gate passed (fail → success → edge cases)**
- [ ] Supporting files referenced, not duplicated
- [ ] Progressive disclosure: load on-demand, not upfront
- [ ] Symlinks created if shared across projects
- [ ] Writing style: imperative instructions, third-person descriptions
