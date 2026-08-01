# Decision Framework — what to settle in Phase 2

The questions to resolve *with the user* before designing a workflow. Loaded on demand from
`../SKILL.md`. **Principle: ask, don't assume — assumptions cause rework.** (This is the
general form of `ac-pipeline`'s *humans own intent* axiom.)

---

## Quick Composability Pattern (skip the rest for simple workflows)

For a simple, single-user, reversible, or exploratory workflow, don't run the full framework:

1. **Define the outcome** in plain language ("I want X to happen").
2. **List the tools/skills** the agent may use.
3. **Let the agent compose** the steps dynamically.

**Use the full framework when:** multiple stakeholders, complex quality gates, the workflow
will be reused by others, or high-stakes/irreversible actions. **Use the quick pattern when:**
single user, clear outcome, low-stakes/reversible, speed over documentation.

---

## What to ask vs what to decide

| Always **ask** the user | **Decide** yourself (with rationale) | Offer **2-3 options** for |
| --- | --- | --- |
| Purpose / intent | Phase count | Naming conventions |
| Structure & required sections | Parallel vs sequential | Section structures |
| Organization & consolidation | Which skill a stance loads | Quality thresholds |
| Where the run pauses for approval | Classifier-gate composition | |
| What gets deferred vs blocks | | |

---

## The eight categories

**1 · Purpose** — What is this for? The outcome and the transformation it delivers. Standalone
vs part of a chain. (Content: standalone value vs teaser vs sub-value. Code: a one-off vs a
recurring pipeline.) *The single most expensive thing to assume wrong.*

**2 · Structure & format** — Required sections/steps; length or scope target; format and
quality constraints (brand/voice for content; correctness/tests/perf budget for code);
supporting artifacts.

**3 · Organization & output** — Per-folder vs flat; single consolidated record (`plan.md` /
bead board) vs separate files; naming convention; archival strategy. *The second most expensive
thing to assume wrong.*

**4 · Agents & execution** — Which stances (researcher / implementer / validator), each doing
what, loading which skill. Which steps parallelize (independent) vs sequence (dependent).
Never a per-workflow agent.

**5 · Skills & knowledge** — Which existing skills apply; whether new durable knowledge needs a
skill (→ `skill-builder`) vs living inline in the command. Knowledge placement routes via
`context-engineering`.

**6 · Quality assurance** — What "good" means here; which gates **block** vs **warn**; what can
be a **classifier-gate** (run only what's warranted) vs a fixed battery; which checks are
independent (parallel) and which are automatable.

**7 · User interaction** — What input the user provides and how; where the run pauses for
approval; what the user can override; **which decisions get deferred** (a deferred-decision
record) rather than blocking a long run.

**8 · Output & delivery** — Primary deliverable (type, location, format); supporting outputs;
metadata (titles, descriptions, tags); the "ready for" state (publish / review / merge /
schedule) and the next steps documented.

---

## Decision template (fill during Phase 2)

```markdown
# Workflow Decisions: <name>

## Purpose          intent · transformation · standalone-or-chain
## Structure        sections/steps · length/scope · format/quality constraints
## Organization     folder model · consolidation · naming · archival
## Agents           stances + tasks · parallel set · sequential chain
## Skills           existing to load · new skill needed? · knowledge placement
## Quality          "good" = … · blocking gates · warning gates · classifier-gate scope
## Interaction      inputs · approval pauses · overrides · deferred decisions
## Output           primary deliverable · supporting · metadata · ready-for + next steps
```

---

## Anti-patterns

- Assuming purpose (standalone vs teaser; one-off vs recurring) → **ask**.
- Proposing folder/file structure before asking the preference → **offer options**.
- Silently choosing quality thresholds or which gates block → **ask**.
- Creating a default structure without naming it → **state it, invite override**.
- Converting an open-ended decision into a blocking mid-run question → **defer it**.
