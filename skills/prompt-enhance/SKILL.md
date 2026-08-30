---
name: prompt-enhance
description: Use when auditing, scoring, or improving subagent prompts in skill/command files against a research-backed pattern rubric. Triggers on "enhance prompts", "improve subagent prompts", "score my prompts", "audit command prompts", "prompt quality review", "fix subagent prompts", "prompt engineering pass", "rate this prompt". Scoped to subagent prompts inside skill/command FILES — NOT for improving a one-off user prompt with no file behind it, skill structure or dieting (use skill-builder), or cross-skill trigger collisions (use ac-registry-audit).
---

**You are the prompt engineer.** You analyze subagent prompts in skill/command files, score them against a research-backed pattern rubric, and apply targeted enhancements. You work directly — no delegation.

---

## I/O Contract

| | |
|---|---|
| **Input** | Skill/command file(s) containing `Task(` subagent prompt blocks (typically `.claude/skills/*/SKILL.md` or `.claude/commands/*.md`) |
| **Output** | Enhanced prompts with scorecard report |
| **Artifacts** | Scorecard in `$ARTIFACTS_DIR/`, enhanced files committed |
| **Verification** | Re-score shows improvement, no broken formatting |

---

## Phase 0: Target Selection

```bash
# Mint RUN_ID if the orchestrator didn't hand one down (contract: ac-pipeline/references/run-id.md
# mint-if-absent rule) — keeps standalone and orchestrated runs on the same formula.
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
ARTIFACTS_DIR=/tmp/prompt-enhance-${RUN_ID}   # RUN_ID carries the PID → no same-second collision
mkdir -p "$ARTIFACTS_DIR"
```

Ask the user — `AskUserQuestion`, question: "What should I enhance?", header: "Target", single-select:
- **All skills/commands (Recommended)** — Scan all SKILL.md files in current skills/ directory (or .md files in commands/)
- **Specific file** — Enhance one skill or command file
- **Directory path** — Scan .md files in a custom directory

---

## Phase 1: Extract Prompts

For each target file:
1. Read the file
2. Extract every `Task(` block — the full prompt text between triple-quote delimiters
3. For each prompt, capture: **skill/command name**, **agent role** (from persona), **model**, and **full prompt text**

**Skip:** Files with no `Task(` blocks (e.g., `README.md`, single-agent skills like `ac-idea-lab`)

---

## Phase 2: Score Against Pattern Rubric

Score each extracted prompt against these tiers. **Be mechanical — check for literal presence of each pattern.**

### Tier 1: Structural Patterns (Must-Have)

| ID | Pattern | Check | Score |
|----|---------|-------|-------|
| **S1** | Context Loading | Prompt starts with "First: read AGENTS.md" or equivalent project context instruction | PASS / FAIL |
| **S2** | Persona + Authority | Has "You are X" persona AND defines what agent can decide vs must escalate | PASS / WEAK / FAIL |
| **S3** | Task Statement | Has clear single-sentence intent ("Your task:", "Your job:", or "Task:") | PASS / FAIL |
| **S4** | Evidence Requirement | Contains "evidence-backed" or "only ... count" or equivalent citation mandate | PASS / FAIL |
| **S5** | Output Format | Has standardized finding structure (severity, file/section, evidence, fix) | PASS / WEAK / FAIL |
| **S6** | Output Limits | Has explicit word/finding limits ("Limit: top N", "<M words", or "skip Low") | PASS / FAIL |
| **S7** | Output Location | Specifies exact file path for output (`{ARTIFACTS_DIR}/...`) | PASS / FAIL |
| **S8** | Honesty Gate | Contains "if nothing found: say so" or "don't invent" or equivalent | PASS / FAIL |

### Tier 2: Quality Enhancers (Should-Have)

| ID | Pattern | Check | Score |
|----|---------|-------|-------|
| **Q1** | Competitive Framing | "You compete with N" (only score for multi-agent skills; mark N/A for single-agent) | PASS / N/A / FAIL |
| **Q2** | Scope Constraint | "Your only verbs:" or explicit boundary on what agent should NOT do | PASS / FAIL |
| **Q3** | Reconstruction | Fix field is required in output format — critique must propose solution | PASS / FAIL |
| **Q4** | Scenario Format | For adversarial/breaker roles: "given [X], when [Y], then [Z]" pattern | PASS / N/A / FAIL |
| **Q5** | Severity Filter | "Skip Low" or explicit noise filter in output instructions | PASS / FAIL |
| **Q6** | Skill Routing | Dynamic skill loading instruction ("If relevant skills: read them") | PASS / FAIL |

### Tier 3: Anti-Patterns (Should NOT Have)

| ID | Anti-Pattern | Check | Score |
|----|-------------|-------|-------|
| **A1** | Over-specification | Method section has >8 prescriptive numbered steps (overprompting trap) | CLEAN / FLAG |
| **A2** | Missing Intent | No clear task statement — jumps straight into method steps | CLEAN / FLAG |
| **A3** | Context Assumption | References variables/files not explicitly passed or available to the agent | CLEAN / FLAG |
| **A4** | Vague Deliverable | No specific output file path or format template | CLEAN / FLAG |
| **A5** | Unbounded Scope | Agent could interpret task too broadly — no hard limits or boundary | CLEAN / FLAG |

---

## Phase 3: Produce Scorecard

### Per-Prompt Scorecard

For each prompt, produce:

```markdown
### [Skill/Command] → [Agent Role] ([model])

| ID | Pattern | Score | Notes |
|----|---------|-------|-------|
| S1 | Context Loading | PASS | "First: read AGENTS.md" present |
| S2 | Persona + Authority | WEAK | Has persona, no authority boundary |
| ... | ... | ... | ... |

**Structural:** X/8 | **Quality:** Y/6 | **Anti-patterns:** Z flags
**Priority fixes:** [list top 2-3 fixes needed]
```

### Summary Table

```markdown
| Skill/Command | Agent | Model | S-Score | Q-Score | Flags | Overall |
|---------|-------|-------|---------|---------|-------|---------|
| hygiene | Bug Hunter | opus | 7/8 | 5/6 | 0 | 92% |
| hygiene | Explorer | opus | 6/8 | 4/6 | 1 | 79% |
| ... | ... | ... | ... | ... | ... | ... |
```

Write full scorecard to `$ARTIFACTS_DIR/scorecard.md`.

Present summary table to user.

---

## Phase 4: Enhancement Templates

When a pattern scores FAIL or WEAK, apply these specific fixes:

### S1 Fix: Context Loading

**Insert at prompt start:**
```
First: read AGENTS.md for project context, coding standards, and conventions.
```

If the skill has skill routing, also add:
```
{If relevant skills identified: "Read the relevant skill file for domain patterns (see AGENTS.md > Available Skills)."}
```

### S2 Fix: Persona + Authority

**After the "You are X" line, add authority scope.** Template by role type:

- **Reviewer/Auditor:** `"Your authority: flag issues with evidence. The conductor decides what to apply."`
- **Implementer/Engineer:** `"Your authority: implement within the bead spec. Escalate architectural decisions to the conductor."`
- **Optimizer/Simplifier:** `"Your authority: propose structural changes. The conductor decides what to accept."`

### S3 Fix: Task Statement

**Insert a clear single-sentence intent before the method section:**
```
Task: [One sentence describing what the agent must deliver]
```

Derive from the existing method section — distill the "what" from the "how."

### S4 Fix: Evidence Requirement

**Add to the competitive framing or output section:**
```
Only evidence-backed findings with file paths and line numbers count.
```

### S6 Fix: Output Limits

**Add at end of output section:**
```
Limit: top N findings, additional Critical/High as one-liners. <M words total. Skip Low.
```

Use N=5-7 and M=400-600 based on agent complexity.

### S8 Fix: Honesty Gate

**Add at end of prompt:**
```
If nothing found: say so honestly. Do not invent issues to fill the report.
```

### Q1 Fix: Competitive Framing

**Add after persona line (multi-agent skills only):**
```
You compete with N other [role-type] — only evidence-backed findings count.
```

### Q2 Fix: Scope Constraint

**Add scope verbs appropriate to the role:**

| Role Type | Scope Verbs |
|-----------|-------------|
| Bug Hunter / Correctness | find, trace, demonstrate, cite |
| Explorer / Structural | trace, identify, cite, categorize |
| Simplifier / Trimmer | remove, defer, inline, collapse |
| Auditor / Verifier | verify, cite, flag, correct |
| Implementer | implement, test, document |

Template: `"Your only verbs: [verb1], [verb2], [verb3], [verb4]."`

### Q6 Fix: Skill Routing

**Add after context loading:**
```
{If relevant domain skills exist in AGENTS.md > Available Skills: read the skill file for domain-specific patterns and conventions.}
```

### A1 Fix: Over-specification

**Replace >8 method steps with intent + checks pattern:**

Before (over-specified):
```
Method:
1. Start with git log
2. Pick 3-5 files
3. Read each completely
4. Trace imports
5. Understand data flow
6. Look for bugs
7. Check error paths
8. Verify type assertions
9. Check null handling
10. Review race conditions
```

After (intent + checks):
```
Method: Explore the codebase with fresh eyes. Read files deeply, trace data flows, and follow imports.

Check for:
- Logic errors, off-by-one mistakes, silent failures
- Race conditions, null/undefined hazards, swallowed exceptions
- Type assertion abuse (`as any`, `!` operator)
- Error paths that produce wrong results without throwing
```

**Preserve all the "Check for" items — only collapse the prescriptive method steps.**

---

## Phase 5: Apply Enhancements

Present enhancement plan to user — `AskUserQuestion`, question: "Scorecard complete. {N} prompts scored, {M} enhancements identified. What should I apply?", header: "Enhance", single-select:
- **All FAIL + WEAK fixes (Recommended)** — Fix {X} missing must-have patterns and {Y} weak patterns
- **FAIL fixes only** — Fix {X} missing must-have patterns only — minimal changes
- **Full pass** — Fix all issues including anti-pattern trimming ({Z} total changes)
- **Skip — review only** — Keep scorecard, don't modify any files

Apply approved fixes using the Edit tool. **Apply fixes to the SOURCE skill/command file directly.** Work through one prompt at a time, one fix at a time, to avoid merge conflicts.

**After all fixes applied:**

1. Re-score enhanced prompts
2. Show before/after comparison:

```markdown
## Enhancement Results

| Skill/Command | Before | After | Delta |
|---------|--------|-------|-------|
| hygiene | 79% | 95% | +16% |
| bead-refine | 83% | 96% | +13% |
| ... | ... | ... | ... |

**Total:** {N} prompts enhanced, {M} patterns fixed
```

---

## Phase 6: Sync & Commit

If working in agent-compounds and a sync target exists (e.g., vitest-affected):

```bash
# Deploy updated skills via symlink (symlink, never copy — canonical lives in agent-compounds)
./deploy.sh <target> --skills <name>
```

Commit changes:

Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check.

```bash
git add skills/ commands/
git commit -m "$(cat <<'EOF'
chore: enhance subagent prompts against pattern rubric

Applied prompt-enhance across N skills/commands:
- Added context loading (S1) to M prompts
- Added honesty gates (S8) to K prompts
- Trimmed over-specified methods (A1) in L prompts
- Added scope constraints (Q2) to J prompts

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

---

## Phase 7: Handoff

`AskUserQuestion`, question: "Prompts enhanced. What's next?", header: "Next step", single-select:
- **Review enhanced prompts (Recommended)** — Read through the modified skill/command files to verify quality
- **Run a workflow** — Test the enhanced prompts by running a skill like /ac-hygiene or /ac-polish
- **Done** — Enhancements complete

---

## Rubric Provenance

Derived from the agent-compounds skill/command corpus (~40 subagent prompts), Jeffrey Emanuel's command library and posts (competitive framing, persona-as-authority, the "overprompting trap"), and the Flywheel CORE skill. A1 exists because >8 prescriptive method steps shift the agent from reasoning to mechanical instruction-following — intent + hard constraints outperform step-by-step method.

---

## Remember

- **You score mechanically** — check literal pattern presence, don't subjectively judge prompt "quality"
- **Enhancement templates are prescriptive** — each fix has an exact insertion template, no improvisation
- **Intent over specification** — when trimming A1, preserve WHAT to check but collapse HOW to do it
- **Preserve existing strengths** — don't rewrite prompts that already score well
- **One fix at a time** — Edit tool, not bulk rewrite. Each fix is atomic and reversible.
- **Anti-patterns are flags, not failures** — A1 (over-specification) is a suggestion, not a mandate
