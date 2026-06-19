# Workflow: Whole-app polish as a multi-agent fan-out

Whole-app mode covers route × theme × viewport × data-state — dozens of cells.
A single context degrades across that many cells (the "ran out of steam after 15
dark screens, declared the rest good without looking" failure). When the user has
**explicitly opted into multi-agent orchestration**, run whole-app mode as a
`Workflow` so coverage is exhaustive and every "pass" is independently re-checked.

> **Opt-in only.** Author/run a `Workflow` for this *only* when the user has asked
> for multi-agent orchestration (the keyword, an on session, or "use a workflow").
> Otherwise run the single-context procedure in `audit-and-elevate.md`. Whole-app
> fan-out spawns many agents — it must be the user's choice.

## Why a workflow fits

- **Exhaustive coverage** — one agent per cell; no cell silently dropped.
- **Sensors are deterministic** — perfect for parallel agents returning structured
  findings, then a synthesis pass.
- **Adversarial verification** — a validator agent re-checks each "conformant"
  claim against the captured artifact. This structurally kills *verify-don't-infer*
  violations: an agent cannot pass a route it didn't actually render.

## Prerequisites (do these in the main context first — cheap, scoping)

1. **Seed** realistic data (Phase 0.5) — once, shared by all cells.
2. **Capture** all routes × themes × viewports up front via the shared
   `_tools/crawl-and-capture` primitive (`--themes light,dark`), incl. the
   deployed URL for auth-blocked routes. Produces the artifact index the workflow
   consumes — capture once, consume many.
3. Build the **cell list** from the route manifest × themes × viewports.

## Phase structure (pipeline, not barriers)

```
phase('Sense')    static sensors over the codebase (color grep, token symmetry) — once
phase('Audit')    one agent per cell: run contrast sweep on its artifact + score
                  critique-polish.md → structured findings {cell, sensorFails, rubric}
phase('Verify')   adversarial validator per "conformant" claim: re-open the artifact,
                  try to REFUTE the pass (default to fail-if-uncertain). Kills inferred passes.
phase('Synthesize') dedupe findings across cells; AGGREGATE recurrence — the same
                  issue on ≥2 cells is systemic → elevate to High, fix at source;
                  produce the two ledgers + the Definition-of-Done checklist
```

Use `pipeline()` so each cell flows Audit→Verify independently; reserve a barrier
only for the final cross-cell dedupe/synthesis.

## Script skeleton (adapt; pass real cells via args)

```js
export const meta = {
  name: 'ui-polish-whole-app',
  description: 'Audit every route×theme cell with sensors+rubric, adversarially verify, synthesize ledgers',
  phases: [{ title: 'Audit' }, { title: 'Verify' }, { title: 'Synthesize' }],
}
const CELLS = args.cells // [{route, theme, viewport, artifact}] built in the main context
const FINDING = { type:'object', properties:{ cell:{type:'string'}, contrastFails:{type:'number'},
  blockers:{type:'array'}, highs:{type:'array'}, score:{type:'number'}, conformant:{type:'boolean'} },
  required:['cell','conformant','score'] }
const VERDICT = { type:'object', properties:{ upheld:{type:'boolean'}, why:{type:'string'} }, required:['upheld','why'] }

const results = await pipeline(CELLS,
  c => agent(
    `Audit cell ${c.route} [${c.theme}/${c.viewport}], artifact ${c.artifact}.
     Run the contrast sweep + false-clean check from ac-ui-polish/reference/sensors.md
     on it, then score ac-ui-polish/reference/critique-polish.md.
     You COMPETE with the agents auditing other cells — only evidence-backed findings
     with file:line + a concrete fix count. Top 5 findings; skip Low. Return findings.`,
    { label: `audit:${c.route}:${c.theme}`, phase: 'Audit', schema: FINDING }),
  (f, c) => f?.conformant
    ? agent(
        `Adversarially verify the PASS for ${c.route} [${c.theme}] against artifact ${c.artifact}.
         Try to refute it (contrast, hardcoded color on a flipping surface, slop). Default upheld=false if unsure.`,
        { label: `verify:${c.route}:${c.theme}`, phase: 'Verify', schema: VERDICT })
        .then(v => ({ ...f, verified: v }))
    : f
)
// Barrier here is legitimate: dedupe needs ALL cells.
const all = results.filter(Boolean)
return { all } // synthesize the two ledgers + DoD from this in the main context
```

## After the workflow

The workflow **finds and verifies**; it does not blanket-edit files in parallel
(that risks conflicting diffs). Bring its synthesized ledgers back to the main
context (or a focused implementer pass) and apply fixes under the **anti-churn
law** in `audit-and-elevate.md` — conformance first, elevation only where it
clears the impact bar. Then re-run sensors on the changed cells.
