# UI Elevate — app mode

The operating procedure for elevating the **authenticated product UI**. The job is the
taste layer: bring the UI inline with the app's design language, then push it past
"fine" to premium. Input is existing, working UI.

> **Correctness first.** Sensor failures, contrast, token conformance and a11y
> mechanics are `ac-polish` ui mode's job. Run that loop first, or confirm it is
> clean. Elevation edits taste on top of a correct surface; it does not paper over a
> defect.

> **Not a convergent loop.** Bounded to at most 3 cycles per surface. Findings are
> accepted, rejected, or filed as beads **with the human present** — a machine green
> is not the exit.

---

## Phase 0 — Baseline

1. **Resolve the bindings** from `factory.json`: `design_spec` (the conformance
   target), `routes_manifest` (the authenticated route list), `ui_audit` (theme
   toggle, seed recipe, deployed URL, auth, viewport set, component dirs).
2. **Read the design spec first.** It is the bound on every change: no new fonts,
   colours, radii, or components unless the spec (or an explicit human call) says so.
3. **Note the house style** — scale, type ramp, elevation logic, motion vocabulary,
   pillar, and the list of themes. That note is the conformance target.
4. Brand law (pillar colour, voice, banned phrases) → `brand-system`.

## Phase 0.5 — Seed realistic data

Empty states are one cell of the matrix, not the matrix. Run the seed recipe named by
`ui_audit` to populate a realistic account. If you cannot seed, say so loudly —
"populated states UNVERIFIED" — and treat every populated surface as un-audited.

## Phase 1 — Coverage matrix (the unit of done)

```
cell = route × theme × viewport × data-state
       route:      every entry in routes_manifest (incl. auth + dynamic)
       theme:      EVERY theme, never one
       viewport:   the app's set (ui_audit)
       data-state: { empty, seeded }, plus error/loading where reachable
```

List the cells. A cell is not audited until it has a captured artifact. For routes
blocked locally, capture against the deployed URL named in `ui_audit` — reading code
is not auditing. A cell captured only by warm in-app navigation carries
`UNVERIFIED: cold-navigate`.

Capture each route by **direct-navigating** to its URL, not by clicking through: a
component can inherit a token from a parent that only happens to be mounted during
warm navigation and break on a cold deep-link.

## Phase 2 — Critique each cell

For every cell, read the captured artifact and score `references/critique-polish.md`
(the anti-slop rubric) — consistency, typography, spacing, depth, imagery, states,
feel, perceived performance, copy, AI tells. Score every item with `file:line` and a
concrete fix. A vibe summary is not a score.

Want independent taste opinions → fan out via `ui-brainstorm`.

Produce a findings table: `severity | axis | cell | location | issue | fix`.

## Phase 3 — Elevate

Keep two ledgers, both required in the report:

- **Conformance ledger** — spec deviations inherited from the correctness loop. Fix
  the highest-impact, lowest-risk first; do not weaken a correct surface to chase taste.
- **Elevation ledger** — the premium axis. For every surface, record a rubric score and
  a decision: *elevate* or *leave as-is*.

Anti-churn law:

- An elevation entry is valid only if it cites a specific rubric gap with `file:line`.
- **"Already at the bar → no change" is a passing outcome**, reported as success.
- Elevation proposals are impact-ranked and capped. Never edit working code merely to
  produce a diff.

Rules of engagement: reuse the app's tokens and primitives; change the least that
reaches premium; one axis at a time where practical; pull canonical radius / shadow /
press-scale / easing / stagger values from `references/recipes.md` (the app's
`design_spec` token overrides); real perf (bundle, data fetch) → `capacitor`.

## Phase 4 — Human review

Present the two ledgers and the artifact set. The human accepts, rejects, or files each
finding as a bead. This step is why ui-elevate has no machine stamp: taste does not
converge, it is decided.

## Phase 5 — Re-score

Re-run the rubric on every changed cell. **Pass = zero Blocker, zero High, in every
theme.** Mediums and lows are logged with a recommendation. A fix that introduces a
new finding loops back to Phase 3, inside the 3-cycle budget.

**Refute every "conformant" verdict** (empty ≠ clean). A cell marked "no findings"
must survive a deliberate second look that tries to disprove it; default to "fails"
if uncertain. The same issue recurring on ≥2 cells is systemic → fix at the source.

## Phase 6 — Verify

- See it running in every theme and data-state you changed; capture before/after
  artifacts for every elevation claim.
- A style not applying / layout broken is a defect → `ui-debug`, fix, return.
- Confirm no regressions on sibling screens sharing touched primitives; re-run the
  app's tests for changed components.

## Definition of Done

- [ ] Bindings resolved from `factory.json`; design spec read before any edit.
- [ ] Coverage matrix built; every cell has an artifact (or explicit `UNVERIFIED`).
- [ ] Both themes captured for every route; seeded data used (or `UNVERIFIED` declared).
- [ ] Every route cold-navigated; no cell left `UNVERIFIED: cold-navigate`.
- [ ] `critique-polish.md` scored per surface with `file:line` (not a vibe summary).
- [ ] Every "no-change" verdict survived an adversarial refute.
- [ ] Conformance ledger: zero Blocker/High remaining.
- [ ] Elevation ledger: every surface scored + a decision; each change cites a gap.
- [ ] Human reviewed the ledgers; findings filed as beads or accepted.
- [ ] Before/after artifacts exist for every change; tests pass; no sibling regressions.
