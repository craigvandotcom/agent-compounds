# Workflow: Audit & Elevate

The operating procedure for `ac-ui-polish`. Input is **existing, working UI**.
Output is the same UI brought inline with the app and pushed to premium quality,
proven by **sensors + rubric + captured evidence** — not by inspection alone.

> Two axes, in order: **(1) bring inline** with the app's design language, then
> **(2) elevate** to premium. Never elevate before you've conformed.

> **Hard lessons baked into this procedure** (do not skip — each maps to a real
> escaped defect): audit **both themes**, audit **seeded (not empty) data**, run
> **sensors before eyes**, **verify don't infer** (a route you didn't render is
> not audited), and **never change code just to have something to change**.

---

## Phase 0 — Establish the baseline (the "house style")

You cannot make something "consistent with the app" until you know the app.

1. **Brand law** → `brand-system` for pillar colour, voice, banned phrases.
2. **App design facts** → the app's `CORE/design.md` (the spec) **and its
   `design.<theme>.md` siblings** (every theme is first-class), plus the app's
   `CORE/ui-audit.md` (or equivalent) for the **operational facts you will need
   below**: how to toggle each theme, how to seed realistic data, the deployed
   URL, auth/login, and which dirs hold components + the CSS token file.
3. **Existing primitives** → the component library, tokens, `theme.extend`, CSS
   variables. Note the production patterns (buttons, cards, inputs, modals).

Write a short **house-style note**: scale, type ramp, elevation logic, motion
vocabulary, pillar, **and the list of themes**. This is your conformance target.

## Phase 0.5 — Seed realistic data (precondition, not optional)

Empty states are **one cell** of the audit, not the audit. Most UI (lists, cards,
populated rows, long names, overflow) only exists with data, and that is where
defects hide. Before capturing anything:

- Run the app's seed recipe (CORE names the script) to populate a realistic
  account: foods/ingredients, entries, signals, whatever the app's domain is.
- If you genuinely cannot seed, **say so loudly** — "populated states UNVERIFIED"
  — and treat every populated surface as un-audited. Do not let an empty-account
  pass masquerade as coverage.

## Phase 1 — Build the coverage matrix (the unit of "done")

Pin scope as an explicit **matrix**, not a vague "the app." The cell, not the
screen, is the unit of work:

```
cell = route × theme × viewport × data-state
       route:      every entry in the route manifest (incl. auth + dynamic)
       theme:      EVERY theme (light AND dark — never one)
       viewport:   the app's set (e.g. 320 / 390 / 428 for mobile-only)
       data-state: { empty, seeded }  (and error/loading where reachable)
```

List the cells. **A cell is not audited until it has a captured artifact.**
For routes blocked locally (auth redirect, dev auto-login), capture against the
**deployed URL** (CORE documents it) — *code-reading a route does not count as
auditing it.* If a cell cannot be captured anywhere, mark it `UNVERIFIED`, never
"pass."

**Cold-navigate, don't warm-click.** Capture each route by direct-navigating to
its URL (`open <base>/<route>`), not by clicking through from another in-scope
page. A component can resolve a token (e.g. `var(--surface)`) inherited from a
parent that only happens to be mounted during warm navigation, and break on a
cold deep-link with a different theme/state. Any cell captured only via warm
in-app nav carries `UNVERIFIED: cold-navigate` until re-captured cold.

Also list each surface's **states**: default / empty / loading / error / success /
disabled / long-content / offline.

## Phase 2 — Audit each cell: SENSORS FIRST, then the rubric

For every cell, in this order:

1. **Sensors** (`reference/sensors.md`) — run *before* you look:
   - **Contrast sweep** per theme (catches "text too light to see").
   - **Hardcoded-colour grep** over components (catches raw `#hex`/`rgba`/
     `text-white`/`bg-black` on theme-flipping surfaces).
   - **Token-symmetry** check (catches a token defined in only one theme).
   Sensor hits are findings (correctness, usually ≥ High) and they point at exact
   lines before you render anything.
2. **Visual rubric** (`reference/critique-polish.md`) — now judge *taste* on the
   captured artifact: consistency, typography, spacing, depth, imagery, states,
   feel, perceived perf, copy, AI-tells. Score every item with `file:line` + a
   concrete fix. Do not summarise "looks good" — answer the checklist.

Produce a **findings table**: `severity | axis | cell | location (file:line) |
issue | fix`. Severity per `critique-polish.md` (consistency/contrast/hardcoded
breaks are ≥ High). Want independent taste opinions → fan out via `ui-brainstorm`.

## Phase 3 — Elevate (apply fixes) — two ledgers, zero churn

Keep **two ledgers**, both required in the report:

- **Conformance ledger** — defects: sensor failures + rubric blockers/highs.
  Fix these, highest-impact / lowest-risk first.
- **Elevation ledger** — the premium axis. For **every surface**, record a rubric
  **score** and a decision: *elevate* or *leave as-is*.

**Anti-churn law (non-negotiable):**
- An elevation entry is valid **only** if it cites a specific rubric gap or named
  premium principle it violates, with `file:line`. "Tweak something" is not valid.
- **"Already at the bar → no change" is a PASSING outcome**, reported as success.
  A surface that needs nothing is a good result, not a gap to fill.
- Elevation proposals are **impact-ranked and capped**; below the impact bar,
  leave it alone. Never edit working code merely to produce a diff.

Rules of engagement:
- **Reuse the app's tokens and primitives.** A new spacing/shadow/colour/component
  needs explicit, stated justification (and usually belongs in the design system).
- **Change the least that achieves premium.** Elevation is surgical.
- **One axis at a time** per component when practical — easier to verify/revert.
- Brand-voice copy stays within `brand-system`'s register + banned list.
- Real perf (bundle, data fetch) → `capacitor`; here, only *perceived* speed.

## Phase 4 — Re-audit (loop to clean)

Re-run **sensors + rubric** on every changed cell. **Pass = zero sensor failures,
zero Blocker, zero High, in every theme.** A fix that introduces a new finding
loops back to Phase 3. Mediums/lows are logged with a recommendation.

**Refute every "conformant" verdict** (adversarial pass — empty ≠ clean). A cell
marked "no findings / no change" must survive a *deliberate second look that tries
to disprove the pass*: re-open the artifact, run Sensor 4, default to "fails" if
uncertain. A single tired pass writing "looks fine" is not a pass. (In whole-app
mode this is the `Verify` agent in `whole-app-workflow.md`.)

**Aggregate recurring findings across cells.** A medium that appears on one cell is
a medium; the *same* issue (same token misused, same pattern) recurring across ≥2
cells is **systemic → elevate to High** and fix at the source, not per-cell. Don't
report the same root cause as N isolated mediums.

## Phase 5 — Verify (see it, don't assume it)

- See it **running** in **every theme and data-state you changed** (`run`/`verify`),
  including the non-happy states from Phase 1. Capture before/after artifacts for
  every elevation claim.
- Style not applying / layout broken → defect → `ui-debug`, fix, return.
- Check responsive breakpoints and (Capacitor) native concerns — but device-only
  visual breakage (safe-area, splash, keyboard) is `ac-qa-device`'s job, not this.
- Confirm **no regressions** on sibling screens sharing touched primitives, and
  re-run the app's tests for changed components.
- **Compound the session.** If the run hit real friction or exposed a rubric/sensor
  gap (a defect class no sensor caught, a false-clean that slipped through), route
  that lesson via `reflect` / `ac-land` — evidence-gated, user-approved. Refine the
  skill, don't append to it; context bloat is the enemy.

## Definition of Done (machine-checkable — print and fill)

Do not report "elevated" until ALL are true:

- [ ] Coverage matrix built; **every cell has a captured artifact** (or explicit `UNVERIFIED`).
- [ ] **Both themes** captured for every route; logged-out/auth routes captured (deployed URL if needed).
- [ ] Every route **cold-navigated**; no cell left `UNVERIFIED: cold-navigate`.
- [ ] **Seeded data** used; populated states audited (or `UNVERIFIED` declared loudly).
- [ ] Sensor 1 (contrast) clean in **every theme**.
- [ ] Sensor 2 (hardcoded colour) triaged; no raw colour on a theme-flipping surface.
- [ ] Sensor 3 (token symmetry) clean.
- [ ] Sensor 4 (false-clean) run on every empty/zero-count cell; no errored view passed as "empty".
- [ ] Every "conformant / no-change" verdict survived an **adversarial refute** (not a single tired pass).
- [ ] `critique-polish.md` scored **per surface** with `file:line` (not a vibe summary).
- [ ] Conformance ledger: zero Blocker/High remaining.
- [ ] Elevation ledger: every surface scored + a decision; each change cites a gap; "no change" allowed.
- [ ] Before/after artifacts exist for every elevation change; tests pass; no sibling regressions.

Only then state the work as elevated, with the before/after rubric scores.
