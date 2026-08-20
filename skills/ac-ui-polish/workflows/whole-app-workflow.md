# Workflow: Whole-app polish as a multi-agent fan-out

Whole-app mode covers route × theme × viewport × data-state — dozens of cells.
A single context degrades across that many cells (the "ran out of steam after 15
dark screens, declared the rest good without looking" failure). When the user has
**explicitly opted into multi-agent orchestration**, run whole-app mode as a
`Workflow` so coverage is exhaustive and every "pass" is independently re-checked.

## Fan-out granularity — one agent per route, owning that route's full sub-matrix

The **cell stays the 4-axis unit** (`route × theme × viewport × data-state`) — that
definition is fixed in `audit-and-elevate.md` and does not change here. What the fan-out
chooses is *how cells are grouped onto agents*: **the default is one agent per route, and
that agent owns every cell of its route** — all themes, all viewports in the app's set,
and all reachable data-states (empty / seeded / error / overflow). Theme/viewport/
data-state are **folded into the agent's mandatory sweep, not dropped** — the agent must
exercise each combination it owns, not just the seeded happy path in one theme at one
width. (`data-state ≠ just empty` is a stated non-negotiable; this is where it gets
structurally enforced — it's in the agent's prompt and its returned schema, not only in
prose.)

**Escape hatch — promote an axis to its own cell (split a route across agents) when:**
- a route is heavy (many components / long page) and one agent would steam out across
  its full sub-matrix — the very failure the fan-out exists to prevent;
- a data-state needs **distinct setup** the shared Phase-0.5 seed can't produce
  (e.g. an error or empty state requires per-cell DB manipulation);
- theme is a **shared/global** setting (not per-session emulation), so two themes can't
  coexist in one browser session — then split per-theme cells (see prerequisite 3).

When you split, make the `slug` unique per sub-cell so browser sessions don't collide.

> **Opt-in only — two authorization channels.** Author/run a `Workflow` for this when
> (a) the user has asked for multi-agent orchestration (the keyword, an on session, or
> "use a workflow"), **or** (b) `ac-pipeline/references/verification-gate.md` selected ui-polish at
> `full`/`exhaustive` depth in a conductor-driven verify pass — that gate selection is
> standing authorization (decision 2026-07-12; at `full`, scope the route list to the
> wave's touched routes). Otherwise run the single-context procedure in
> `audit-and-elevate.md`. Whole-app fan-out spawns many agents — outside a gate-selected
> verify pass it must be the user's choice.

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
3. Build the **per-route work list** from the route manifest — one entry per route,
   each carrying the axes its agent must sweep: `themes`, `viewports` (the app's set),
   and the `states` actually **reachable** for that route (`seeded`, plus `empty`/`error`
   wherever the route can show them). Then decide the **theme axis** specifically: if the
   app gives each browser session its own theme (e.g. `prefers-color-scheme` emulation),
   one agent covers **both themes** in its sweep; if theme is a shared/global setting,
   two themes can't coexist in one session — split into per-theme entries (unique `slug`)
   or sequence the themes. Likewise, if a route is heavy or a data-state needs distinct
   setup the shared seed can't give, **split that route across agents** (the escape hatch
   above). (See the app's CORE UI-audit doc for the exact theme / viewport / auth /
   data-state mechanisms.)

## Phase structure (pipeline, not barriers)

```
phase('Sense')    static sensors over the CODEBASE (color grep, token symmetry) — once
phase('Audit')    one agent per route, owning that route's sub-matrix: for EACH
                  theme × viewport × reachable data-state it owns, drive a live browser
                  session (force theme, set viewport, reach the data-state,
                  cold-navigate), run the contrast + false-clean evals from sensors.md
                  on the LIVE page, screenshot, then score critique-polish.md from the
                  screenshot → structured findings (carrying which combos it covered).
                  ALSO run Sensor 2 (hardcoded colour) over THIS ROUTE's own component
                  files and return the triaged count as `themeBlindHits` — a run-level
                  codebase grep has no per-cell verdict to block on.
phase('Verify')   adversarial validator per "conformant" claim: re-navigate + re-run
                  the eval (and read the screenshot) for a SAMPLE of the agent's
                  combos — including a non-seeded data-state — try to REFUTE the pass
                  (default fail-if-uncertain). Kills inferred passes.
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
// Each ROUTE carries the axes its agent must sweep. Build these in the main context from
// CORE/journeys/routes.md + CORE/ui-audit.md (theme list, viewport set, reachable states).
// themes:['light','dark']  viewports:[390,1280]  states:['seeded','empty','error'] (only reachable ones)
const CELLS = Array.isArray(_a) ? _a : _a.cells // [{route, base, slug, themes, viewports, states}]
const FINDING = { type:'object', properties:{ route:{type:'string'},
  covered:{type:'array', items:{type:'string'}}, // e.g. "dark·390·empty" — the combos actually rendered
  contrastFails:{type:'number'},
  // Sensor 2 hits on THIS route's own components, AFTER triage (sensors.md § Sensor 2).
  // REQUIRED, so a route cannot silently omit it — the theme-blind-surface class was
  // detected by the grep but had nowhere to be reported, so it never reached a verdict.
  themeBlindHits:{type:'number'},
  themeBlindFiles:{type:'array', items:{type:'string'}}, // file:line for each counted hit
  blockers:{type:'array'}, highs:{type:'array'},
  score:{type:'number'}, conformant:{type:'boolean'} },
  required:['route','covered','conformant','score','themeBlindHits'] }
const VERDICT = { type:'object', properties:{ upheld:{type:'boolean'}, why:{type:'string'} }, required:['upheld','why'] }

const results = await pipeline(CELLS,
  c => agent(
    `Audit route ${c.route} (base ${c.base}) across its FULL sub-matrix. Use --session ui-${c.slug}.
     Themes: ${JSON.stringify(c.themes)}. Viewports: ${JSON.stringify(c.viewports)}.
     Data-states: ${JSON.stringify(c.states)} (only the ones reachable for this route).
     FIRST read the app recipe (theme toggle + viewport set + how to reach each data-state + auth +
     cold-navigate + the sensor eval) and ac-ui-polish/reference/sensors.md + reference/critique-polish.md.
     For EVERY theme × viewport × data-state combination: force the theme, set the viewport, reach the
     data-state, COLD-navigate to the route on a LIVE browser, confirm theme+state actually applied,
     run the contrast + false-clean evals on the live DOM, screenshot, then READ the screenshot and
     score critique-polish.md. (Static screenshots can't be eval'd — drive the browser yourself.)
     ALSO run sensors.md Sensor 2 (hardcoded colour) over THIS ROUTE's OWN component files only, triage
     every hit by its § Triage rules, and return the surviving count as \`themeBlindHits\` with
     \`themeBlindFiles\` as file:line. \`themeBlindHits > 0\` FORBIDS \`conformant: true\` — a
     theme-blind structural surface is a conformance failure, list it under blockers.
     Empty/seeded are DIFFERENT cells — a list only shows its defects with data; an errored view looks
     like an empty one (false-clean sensor catches that). Return \`covered\` listing every combo you
     actually rendered — a combo you didn't render is NOT audited. You COMPETE with agents on other
     routes — only evidence-backed findings with file:line + a concrete fix count. Top 5; skip Low.`,
    { label: `audit:${c.slug}`, phase: 'Audit', schema: FINDING }),
  (f, c) => f?.conformant
    ? agent(
        `Adversarially verify the PASS for ${c.route} (base ${c.base}). The audit claims it covered:
         ${JSON.stringify(f.covered)}. Re-navigate a SAMPLE LIVE (--session vfy-${c.slug}) — pick at
         least one non-seeded data-state and both extremes of the viewport set — and re-run the
         contrast eval yourself; read the screenshots. Try to refute it (a missed contrast fail, a
         hardcoded color on a flipping surface, an errored view passed as empty, a combo claimed in
         \`covered\` but clearly not rendered, slop). Default upheld=false if unsure.
         REFUTE UNCONDITIONALLY (upheld=false) if the audit returned \`themeBlindHits\` > 0 alongside
         \`conformant: true\` — that combination is self-contradictory. Also re-run Sensor 2 over this
         route's components yourself: if you find a triaged hit the audit reported as 0, upheld=false.`,
        { label: `verify:${c.slug}`, phase: 'Verify', schema: VERDICT })
        .then(v => ({ ...f, verified: v }))
    : f
)
// Barrier here is legitimate: dedupe needs ALL cells.
// Structural refutation: a `conformant: true` carrying Sensor 2 hits is rewritten to a
// failure here, in code, so the verdict does not depend on an agent honouring a prompt.
const all = results.filter(Boolean).map(f =>
  (f.conformant && (f.themeBlindHits ?? 0) > 0)
    ? { ...f, conformant: false,
        blockers: [...(f.blockers ?? []),
          `theme-blind surfaces (Sensor 2): ${(f.themeBlindFiles ?? []).join(', ') || f.themeBlindHits}`] }
    : f)
return { all } // synthesize the two ledgers + DoD from this in the main context
```

## After the workflow

The workflow **finds and verifies**; it does not blanket-edit files in parallel
(that risks conflicting diffs). Bring its synthesized ledgers back to the main
context (or a focused implementer pass) and apply fixes under the **anti-churn
law** in `audit-and-elevate.md` — conformance first, elevation only where it
clears the impact bar. Then re-run sensors on the changed cells.
