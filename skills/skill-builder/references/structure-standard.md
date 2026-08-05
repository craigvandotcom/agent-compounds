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

## Skill archetypes — classify FIRST, then apply the right bias

Two archetypes need **opposite** diet biases. Misclassifying one as the other is the most
common structural error. Classify a skill before dieting it (hygiene-pass step A0).

| | **Orchestrator / workflow** | **Knowledge / reference** |
|---|---|---|
| Examples | `ac-*`, `curate`, `dream` | `capacitor`, `supabase`, `testing`, `brand`, `writing-guidelines` |
| The SKILL.md body IS… | a program — phases, gates, run-ledgers, spawned sub-agents, exact option sets | a **routing index** — a table of contents + when-to-read triggers into `references/` |
| "Loads every run" content | large and real — length IS the enforcement | almost none — nothing runs "every turn" beyond the index |
| The diet **risk** | **over-extraction** — pulling enforcement behind a pointer and weakening the spine | **under-disclosure** — dumping all knowledge into SKILL.md so it all loads; and duplicating the memory substrate |
| The diet **bias** | protect the enforcement spine; extract only templates/prompts/schemas/state-machines | push aggressively to `references/`; keep SKILL.md a thin index; enrich triggers (knowledge skills fail by *under*-triggering) |
| The decay mode | contract drift (behavior goes stale) | freshness (facts rot vs the code) + duplication vs qmd/memory |
| Size expectation | may legitimately run long (enforcement) | should be *short* — a fat knowledge SKILL.md is the bug, not an exception |

**Hybrid / task skills** (e.g. `beads-standards`, a manual `/command`) are mostly one archetype
with a few rules of the other — classify by the dominant body and treat the minority section by its own kind.

The rest of this doc's spine/references machinery is shared; only the *bias you apply* forks by archetype.

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

- **Sub-agent prompt templates** (usually the biggest win — the inline `## Your Task / ## Method / ## Output` blocks) — *except the orchestrator-trap case below*
- Output/report templates used at a single stage
- JSON schemas / structured data (`findings-schema.json`)
- Mutually-exclusive variants (only one path fires — e.g. `markdown-rendering.md` vs `html-rendering.md`)
- Sub-workflow state machines that branch off the main flow
- Domain-specific carve-outs (e.g. `non-code-execution.md`)

Rules:
- **One level deep.** All reference files link directly from SKILL.md. Don't nest references that point to further references.
- **ToC at the top of any reference file > 100 lines** so a partial read still reveals scope.
- Co-locate with the skill: `skills/<name>/references/<file>.md` — *unless the block is consumed by two or more skills, in which case it belongs in its OWNING domain skill’s `references/` (§ Owner-hosted canon, next section).*

### The orchestrator trap (sub-agent prompts that must NOT extract)

A sub-agent prompt template is the default "biggest win" to extract — **but not when the
skill spawns a fresh child that acts before it reads.** If the conductor pastes the prompt
*into* the child's context at spawn time (the child never opens the skill's files), then a
pointer in the spine that says "read `references/x.md`" reaches nobody: the child already
has only what was pasted. Extracting such a prompt to `references/` and leaving a pointer
**silently breaks the spawn** — the documented failure mode behind `ac-pipeline/references/delegation-contract.md`
("a fresh child acts before it reads; a pointer is NOT sufficient").

The carve-out: a child-delegation prompt body may move to a reference **only if** the spine
keeps an explicit *"read this reference and paste it verbatim into the child prompt before
spawning — never point the child at the file"* instruction at the spawn site. If you can't
guarantee that inlining step, the prompt stays in the spine. This is the one case where a
sub-agent template is legitimately spine content.

## Owner-hosted canon (cross-skill centralization — one copy, in the OWNING skill)

_(`skills/_shared/` is RETIRED — ac-znk.7, 2026-08-01. Every canon it held moved into
its owning domain skill's `references/` or `scripts/`.)_ A block **used verbatim by two
or more skills** lives ONCE, in the `references/` of the skill that OWNS its domain
(litmus below + § The workflow/domain litmus): beads contracts →
`beads-standards/reference/` · coordination → `agent-mail/references/` · pipeline
contracts (git discipline, delegation, run-ledger/run-id, verification selection,
board-scan, risk/consensus/disposition, shell guardrails) →
`ac-pipeline/references/`. Centralizing beats per-skill copies because divergent
copies give contradictory instructions — the worst kind of nondeterminism; owner-hosting
beats a shared directory because the owner's spine indexes the whole domain and adds no
listing-budget cost.

**Promotion rule:** the moment a block is needed *verbatim* by a second skill, move it to
its owner's `references/` and have every consumer point at (or inline-from) the single
copy — do not duplicate. A block used by exactly one skill stays in that skill's own
`references/`; owner-hosting is earned by a second consumer, not by anticipation. A new
domain with a real task surface earns a new skill; otherwise the pipeline's contracts
belong to `ac-pipeline`.

**Consuming an owner-hosted block:** two legal forms — (a) a plain pointer at point of
use (`load <owner>/references/x.md` when the flow reaches stage N), for payload a stage
reads; or (b) the orchestrator-trap inline form for child-spawn prompts (read the file,
paste verbatim before spawning). If a skill must restate a block in prose, mark the copy
`<!-- mirror: <owner>/references/x.md — edit there first -->` so drift is managed, per
token-economics § cross-file duplication.

## scripts/ (executed, not read)

Python/bash utilities that get **run**, not loaded — validators, analyzers, generators. Only their *output* costs tokens. Put the heavy mechanics here and have SKILL.md invoke them.

## Pointer syntax (portable form)

Use a backticked path in imperative prose, as the examples below do. Never `[path](path)` — a link whose text repeats its target pays twice for one path, and nothing clicks it. Do **not** use `@./references/x.md` — that auto-inline syntax is a compound-engineering *plugin* extension, not the Anthropic spec, and won't behave portably in a symlink-deployed skill.

```markdown
# Demand-loaded at a specific stage (preferred for stage-specific detail):
When the review reaches Stage 6, read `references/review-output-template.md` for the report skeleton.

# Sub-agent dispatch:
Spawn the reviewer with the prompt in `references/reviewers/correctness.md`,
substituting <DIFF> and <SCOPE>.
```

## The discriminator (apply to every section)

> **Does the orchestrator itself need this to decide what to do next — or does only a spawned sub-agent / one stage consume it?**
> Orchestrator → spine. Sub-agent / single-stage → `references/`.

## Provenance never lives in skill text (the third discriminator)

Skill text carries only what changes the next executor's behavior. The story of an
edit — who directed it, which bead/pass/date, what it was promoted from, why it is
correct — lives in the channels built for it: the commit message, the bead's close
reason, MAINTENANCE/FRICTIONS ledgers, git history. A provenance tail in an artifact is
reviewer-anxiety, not content, and it is fluff the moment the commit lands.

Exemptions, kept MINIMAL: machine-read tokens (`diet:`/`mirror:` markers), and a bare
rule-ID **only when other files grep it as a name**. A date, a director, or a narrative
clause is never exempt.

## Rule voice (how skill text is written)

**State the rule. Not its cause, its discovery, or who learned it.**

- **Imperative, present tense.** "Classify staleness on CODEISH." Never "we found
  that…", "measured on 2026-08-04…", "this exists because…".
- **One idea per line.** A rule that needs a paragraph to be believed is not yet well
  stated. Sharpen it instead of defending it.
- **Minimum necessary change, in the optimal location.** Prefer deleting to adding.
  Before adding a line, name what it replaces.

## The workflow/domain litmus (the second discriminator — ratified 2026-07-30, ac-znk.4)

> **Would this sentence be true in ANY workflow?** → it is DOMAIN CANON: it lives in the
> domain's OWNING skill's references/ (beads → `beads-standards` +
> `beads-standards/reference/bead-conventions.md` · git → `ac-pipeline/references/commit-discipline.md` · agent mail →
> `agent-mail/references/session-procedure.md` · verification → `ac-pipeline/references/verification-gate.md`), never in a
> workflow skill's text.
> **Is it about THIS workflow's ordering, actors, or parameters?** → it is a WORKFLOW
> BINDING: it stays in the workflow's SKILL.md as a one-liner naming the *when/who*,
> with a `§` pointer to the canon for the *what/how*.

A workflow file describes the workflow — phases, spawns, and the contracts at the
joints. A domain rule restated inside one is drift debt (the SINGLE-HOME rule the
skill-edit-guard reminds about); a domain rule with no canon home yet is a finding —
create the home first, then bind to it. Defensive restatement ("the child might not
load the canon") is solved by delivery (preamble line / tripwire / validator — see
`hooks/hooks.json` patterns), never by copying the rule in.

## The move-out decision — when content leaves SKILL.md, where does it go?

Every block that leaves the spine has exactly one of three destinations. Decide deliberately:

1. **KEEP inline** — needed on *every* run (enforcement). Doesn't leave. (Orchestrators have much
   of this; knowledge skills almost none.)
2. **EXTRACT** → `references/` (the OWNING domain skill's, when ≥2 skills consume it
   verbatim — § Owner-hosted canon) — still true and
   needed, but only a sub-agent, one stage, or a conditional path uses it. Moves, leaves a pointer.
3. **DELETE** — and this splits, which is the part people get wrong:
   - **Hard delete** — pure sediment: a verbatim duplicate whose twin survives elsewhere, or content
     that is dead / stale / superseded (no longer true). Nothing of value is lost. Git preserves history.
   - **Relocate-then-delete** — the content has residual value but not *here*: a rationale, a
     decision record. It goes to the **memory substrate** or the **diet commit message** *first*;
     only the inline copy is removed. An incident story has no destination in a skill — the
     commit message holds it, and `FRICTIONS.md` is what decides whether a rule is needed at all.

**The discriminator between the two delete kinds:** *if this vanished entirely, would we lose a fact
or lesson not recoverable anywhere else?* No → hard delete. Yes → relocate first. **Never vaporize a
hard-won lesson** — demote it to its proper home, don't destroy it.

**Churn guard (before any delete):** run `git log -S "<distinctive snippet>" -- <file>`. If the block
has been added-and-removed before, it is *sticky sediment* — someone keeps re-injecting it. Do not
just cut it again: either it is genuinely wanted (home it properly — promote to enforcement or
the owner skill’s references/) or there is a process leak re-adding it (fix that). Record the churn in the skill's
`MAINTENANCE.md` cut-log so the next pass sees the history.

## Refactoring an oversized skill (extraction, not rewrite)

To protect functionality, **move text, don't rewrite logic**. The full callable procedure
(single-skill diet + registry-wide batch sweep) is `workflows/hygiene-pass.md`; the essentials:

1. **Cartography first — classify every section CORE / EXTRACT / CUT** by the discriminator:
   - **CORE** (stays inline): the orchestrator needs it on *every* run — routing, branches,
     run-ledger/gate lines, stop conditions, standing constraints. Enforcement length is legitimate.
   - **EXTRACT** (→ `references/` — own or owning skill’s): only a sub-agent, one stage, or a conditional
     sub-path consumes it — templates, schemas, single-stage output shapes, off-main state machines.
   - **CUT**: duplicate / dead / stale (see token-economics § Sediment).
   Produce an explicit per-section ledger before touching anything — a line-count pass alone
   mislabels enforcement-by-repetition (e.g. a bug-lane rule re-checked every selection) as bloat.
2. **Apply the token-bucket + enforcement-hierarchy test to each EXTRACT candidate** (token-economics §3):
   never move enforcement every run needs behind a pointer. Persuasion/incident narrative riding
   inside a CORE block compresses *in place* to rule + one-clause why — it does not move.
3. **Route each EXTRACT by consumer count:** one skill → its own `references/`; two or more skills
   (verbatim) → the owning skill’s `references/`. Check the **orchestrator trap** before extracting any child-spawn
   prompt (see § references/ above) — if it fails the carve-out, it stays inline.
4. Cut each to its target file (add a ToC if >100 lines); in the spine replace with a one-line
   imperative pointer + the variable substitutions the consumer needs. Keep all decision/routing in the spine.
5. **Verify content-preservation:** the union of (slim spine + references + `_shared/`) must
   preserve the original content — diff the moved text; the only spine changes are deletions + pointer lines.
6. **Fix pointers as a coordinated multi-site edit:** update every cross-reference the move touched
   — including *sibling skills* that pointed at the moved block by section name — then re-run
   `validate-skill.sh` (pointer-integrity + budget). A half-updated pointer graph is worse than no move.

## Quick checklist

- [ ] SKILL.md spine ≤ ~500 lines (or justified as a true orchestrator, by token buckets not line count)
- [ ] Every sub-agent prompt / large template lives in `references/`, not inline — *except orchestrator-trap child-spawn prompts (stay inline with a "paste verbatim" guardrail)*
- [ ] Blocks used verbatim by ≥2 skills live in the owning skill’s `references/`, not duplicated per skill
- [ ] references are one level deep; >100-line files have a ToC
- [ ] Pointers are plain markdown links / imperative prose (no `@./`)
- [ ] Executable mechanics live in `scripts/` (run, not read)
- [ ] Refactors verified by diff — content preserved, only pointers changed
- [ ] Pointer integrity re-checked across the skill AND sibling skills that referenced moved blocks (`validate-skill.sh`)
</content>
