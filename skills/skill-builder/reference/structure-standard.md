# Skill Structure Standard (spine + references)

The canonical structure for non-trivial skills, distilled from Anthropic's
authoring docs and the production patterns in EveryInc/compound-engineering-plugin
(`ce-plan`, `ce-code-review`). This is the rulebook for writing new skills **and**
for refactoring oversized ones.

## The three loading tiers (why structure matters)

| Tier | What loads | Cost | Holds |
| --- | --- | --- | --- |
| 1 Discovery | `name` + `description` only | ~80 tok, always on | trigger metadata |
| 2 Activation | full SKILL.md body | loaded on trigger | the **spine** |
| 3 On-demand | `references/`, `scripts/` | only when read/executed | everything else |

Tier-3 content is effectively free until used. So the goal is a **lean Tier-2 spine** that *routes* to Tier-3, not a wall of everything.

## The spine (stays in SKILL.md)

SKILL.md keeps only what the **orchestrator itself** needs to run the flow:

- Workflow phases and their sequencing
- Decision trees / branching logic (`if X then Y`)
- **The routing rules that decide which reference to load**
- Operating principles and hard constraints
- Argument parsing / mode switching
- The compact fallback version of an output shape
- Anything needed on *every* invocation

Target **≤ 500 lines**. It's a target, not a law: a genuine orchestrator may exceed it (compound-engineering's `ce-plan` is ~790) when the *flow itself* is that big. But if lines come from content a sub-agent or single stage consumes, that's not spine — extract it.

## references/ (one level deep — loaded on demand)

Move to `references/` anything only a sub-agent or one stage needs:

- **Sub-agent prompt templates** (the biggest win — the inline `## Your Task / ## Method / ## Output` blocks)
- Output/report templates used at a single stage
- JSON schemas / structured data (`findings-schema.json`)
- Mutually-exclusive variants (only one path fires — e.g. `markdown-rendering.md` vs `html-rendering.md`)
- Sub-workflow state machines that branch off the main flow
- Domain-specific carve-outs (e.g. `non-code-execution.md`)

Rules:
- **One level deep.** All reference files link directly from SKILL.md. Don't nest references that point to further references.
- **ToC at the top of any reference file > 100 lines** so a partial read still reveals scope.
- Co-locate with the skill: `skills/<name>/references/<file>.md`.

## scripts/ (executed, not read)

Python/bash utilities that get **run**, not loaded — validators, analyzers, generators. Only their *output* costs tokens. Put the heavy mechanics here and have SKILL.md invoke them.

## Pointer syntax (portable form)

Use plain markdown links and imperative prose. Do **not** use `@./references/x.md` — that auto-inline syntax is a compound-engineering *plugin* extension, not the Anthropic spec, and won't behave portably in a symlink-deployed skill.

```markdown
# Always-relevant supporting doc:
**Persona catalog**: see [references/persona-catalog.md](references/persona-catalog.md)

# Demand-loaded at a specific stage (preferred for stage-specific detail):
When the review reaches Stage 6, read `references/review-output-template.md` for the report skeleton.

# Sub-agent dispatch:
Spawn the reviewer with the prompt in `references/reviewers/correctness.md`,
substituting <DIFF> and <SCOPE>.
```

## The discriminator (apply to every section)

> **Does the orchestrator itself need this to decide what to do next — or does only a spawned sub-agent / one stage consume it?**
> Orchestrator → spine. Sub-agent / single-stage → `references/`.

## Refactoring an oversized skill (extraction, not rewrite)

To protect functionality, **move text, don't rewrite logic**:

1. Identify the inline sub-agent prompt blocks, templates, and schemas.
2. Cut each to `references/<descriptive>.md` (add a ToC if >100 lines).
3. In the spine, replace the cut block with a one-line imperative pointer + the variable substitutions the sub-agent needs.
4. Keep all decision/routing logic in the spine.
5. **Verify:** the union of (slim spine + references) must preserve the original content — diff the moved text; the only spine changes should be deletions + pointer lines.
6. Fix any stale cross-references while you're in the file.

## Quick checklist

- [ ] SKILL.md spine ≤ ~500 lines (or justified as a true orchestrator)
- [ ] Every sub-agent prompt / large template lives in `references/`, not inline
- [ ] references are one level deep; >100-line files have a ToC
- [ ] Pointers are plain markdown links / imperative prose (no `@./`)
- [ ] Executable mechanics live in `scripts/` (run, not read)
- [ ] Refactors verified by diff — content preserved, only pointers changed
</content>
