Child-spawn contract: `ac-pipeline/references/delegation-contract.md` — verbatim preamble, bounded waits, structured returns. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

# Beadify Validators (3 parallel agents)

Spawn all three in a **single message** (parallel). Each writes to
`$ARTIFACTS_DIR/validation-{role}.md`. Payloads point, contracts paste
(`ac-pipeline/references/delegation-contract.md` § Payloads point): substitute
only `{ARTIFACTS_DIR}` and `{PLAN_PATH}` (the literal plan-file path identified
at Phase 0 § Identify Plan File) into the step-1 payload-read lines below — validators read the plan
and `proposed-structure.md` from disk; nothing is pasted inline.

---

## Validator 1: Completeness Checker

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are validating a proposed bead structure against its source plan. You compete with 2 other validators — only evidence-backed findings count.

## Your Task

Cross-reference every section of the plan against the proposed beads. Flag anything dropped, oversimplified, or missing.

## Inputs

1. Read {PLAN_PATH}
2. Read {ARTIFACTS_DIR}/proposed-structure.md

## Check

For each plan section/feature:
- Is it fully represented in at least one proposed bead?
- Were any details, edge cases, or requirements lost?
- Are test requirements from the plan captured?

## Output

Write findings to {ARTIFACTS_DIR}/validation-completeness.md

First line: `**Payload read:** <the literal path(s) from your step-1 read list>`

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Plan section:** <which section>
**Problem:** What's missing or oversimplified
**Fix:** Add bead X, or expand bead Y to include Z

Limit: top 5 issues. Under 400 words. If nothing missing, say so.
""")
```

## Validator 2: Dependency Checker

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are validating the dependency structure of a proposed bead breakdown. You compete with 2 other validators — only evidence-backed findings count.

## Your Task

Check the proposed dependency graph for correctness — missing links, wrong ordering, potential cycles.

## Inputs

1. Read {ARTIFACTS_DIR}/proposed-structure.md

## Check

Trace the dependency graph for correctness: are links genuine? Are any missing or unnecessary? Could reordering unblock more parallel work? Any cycles? Is the critical path reasonable? **Is the commit order safe** — applied in dependency order, does every bead leave the branch green + shippable (add-new-before-remove-old, migrations additive-first)? Flag any ordering that would leave `main` broken between beads.

You have codebase access. Read referenced files to verify what actually exists vs what needs to be created. Use your judgment on what matters most for a sound dependency structure.

## Output

Write findings to {ARTIFACTS_DIR}/validation-dependencies.md

First line: `**Payload read:** <the literal path(s) from your step-1 read list>`

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Bead(s):** <which beads>
**Problem:** Missing/wrong/unnecessary dependency
**Fix:** Add dep X->Y, remove dep A->B, reorder C before D

Limit: top 5 issues. Under 400 words. If structure is sound, say so.
""")
```

## Validator 3: Granularity Reviewer

```
Task(subagent_type: "general-purpose", model: "sonnet", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are validating the granularity and sizing of a proposed bead breakdown. You compete with 2 other validators — only evidence-backed findings count.

## Your Task

Check that each bead is right-sized for a single agent session — not too big (needs splitting), and rich enough to be self-contained. Bias toward MORE detail per bead, not less. Thin beads that lack context force agents back to the plan — that's a failure.

## Inputs

1. Read {ARTIFACTS_DIR}/proposed-structure.md

## Check

For each proposed bead:
1. Can an agent implement this in one focused session? (If >5 files or >2 concerns -> split)
2. Is it self-contained? (Must include enough context, acceptance criteria, and reasoning that an agent NEVER needs the original plan)
3. Does it mix backend + frontend work? (-> split candidate)
4. Is the acceptance criteria clear enough for mechanical implementation?
5. Are priorities (P0/P1/P2) assigned correctly? (P0 = critical path, P2 = deferrable)
6. Does it include test requirements? (Every bead should specify what to test)

## Output

Write findings to {ARTIFACTS_DIR}/validation-granularity.md

First line: `**Payload read:** <the literal path(s) from your step-1 read list>`

For each issue:
## Issue N: Title
**Severity:** Critical | High | Medium
**Bead(s):** <which beads>
**Problem:** Too big / too thin (lacking context) / mixed concerns / wrong priority
**Fix:** Split into X+Y, enrich A with missing context, reassign priority

Limit: top 5 issues. Under 400 words. If granularity is good, say so.
""")
```
</content>
