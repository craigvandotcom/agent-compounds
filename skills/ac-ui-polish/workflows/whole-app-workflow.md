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
  claim by re-rendering the cell (re-navigate + re-run the eval) and reading its
  screenshot. This structurally kills *verify-don't-infer* violations: an agent
  cannot pass a route it didn't actually render.

## Prerequisites (do these in the main context first — cheap, scoping)

1. **Seed** realistic data (Phase 0.5) — once, shared by all cells.
2. **Prove the capture recipe on ONE cell first** (theme toggle, auth, cold-navigate,
   the eval sensor, screenshot). All agents inherit it — a broken recipe fails them
   identically. The contrast / false-clean sensors are `eval` on a **live DOM**, so a
   static screenshot is NOT enough: each audit agent drives its own browser session.
   `_tools/crawl-and-capture` emits static PNGs only and does **not** theme-switch
   (there is no `--themes` flag) — use it for a quick screenshot index if you like, but
   the live eval has to happen in the agent.
3. Build the **cell list** from the route manifest. Decide the theme axis: if the app
   gives each browser session its own theme (e.g. `prefers-color-scheme` emulation),
   one agent can cover **both themes** per route; if theme is a shared/global setting,
   split into per-theme cells or sequence the themes. (See the app's CORE UI-audit doc
   for the exact theme + auth mechanism.)

## Phase structure (pipeline, not barriers)

```
phase('Sense')    static sensors over the CODEBASE (color grep, token symmetry) — once
phase('Audit')    one agent per cell: drive a live browser session (force theme +
                  cold-navigate to the route), run the contrast + false-clean evals
                  from sensors.md on the LIVE page, screenshot, then score
                  critique-polish.md from the screenshot → structured findings
phase('Verify')   adversarial validator per "conformant" claim: re-navigate + re-run
                  the eval (and read the screenshot), try to REFUTE the pass (default
                  fail-if-uncertain). Kills inferred passes.
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
// `args` can arrive as a JSON STRING, not the parsed object — guard or pipeline() throws.
const _a = typeof args === 'string' ? JSON.parse(args) : args
const CELLS = Array.isArray(_a) ? _a : _a.cells // [{route, base, slug}] built in the main context
const FINDING = { type:'object', properties:{ cell:{type:'string'}, contrastFails:{type:'number'},
  blockers:{type:'array'}, highs:{type:'array'}, score:{type:'number'}, conformant:{type:'boolean'} },
  required:['cell','conformant','score'] }
const VERDICT = { type:'object', properties:{ upheld:{type:'boolean'}, why:{type:'string'} }, required:['upheld','why'] }

const results = await pipeline(CELLS,
  c => agent(
    `Audit route ${c.route} (base ${c.base}) in BOTH themes. Use --session ui-${c.slug} (unique to you).
     FIRST read the app recipe (theme toggle + auth + cold-navigate + the sensor eval) and
     ac-ui-polish/reference/sensors.md + reference/critique-polish.md.
     For each theme: force it, COLD-navigate to the route on a LIVE browser, confirm the theme
     actually applied, run the contrast + false-clean evals on the live DOM, screenshot, then READ
     the screenshot and score critique-polish.md. (Static screenshots can't be eval'd — drive the
     browser yourself.) You COMPETE with agents auditing other routes — only evidence-backed findings
     with file:line + a concrete fix count. Top 5 findings; skip Low. Return findings.`,
    { label: `audit:${c.slug}`, phase: 'Audit', schema: FINDING }),
  (f, c) => f?.conformant
    ? agent(
        `Adversarially verify the PASS for ${c.route} (base ${c.base}). Re-navigate it LIVE in both
         themes (--session vfy-${c.slug}) and re-run the contrast eval yourself; read the screenshots.
         Try to refute it (a missed contrast fail, a hardcoded color on a flipping surface, an errored
         view passed as empty, slop). Default upheld=false if unsure.`,
        { label: `verify:${c.slug}`, phase: 'Verify', schema: VERDICT })
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
