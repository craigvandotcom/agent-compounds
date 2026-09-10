# UI Elevate — site mode

The operating procedure for elevating the **public marketing surface**. It reuses the
app-mode craft engine by reference and adds the marketing layer. The cell
(`route × viewport × data-state`) is the unit of done — **no theme axis** unless the
consumer's spec names one.

> **Surface guard, run first.** A route belongs to this mode only if it is listed in
> the manifest named by `routes_public_manifest`. If the target is not listed there,
> it is app mode's surface — switch modes and stop. Key off manifest membership, not
> path geometry: a landing route often sits outside the public directory.

> **No SEO stage.** Search metadata is app-owned. This mode audits craft and
> conversion, not metadata.

> **Not a convergent loop.** Bounded to at most 3 cycles per surface. Findings are
> accepted, rejected, or filed as beads **with the human present**.

---

## Phase 0 — Baseline

1. **Resolve the bindings** from `factory.json`: `design_spec` (the site's design
   spec — its token block and Do's/Don'ts), `routes_public_manifest` (the public
   route list), `ui_audit` (deployed-URL fallback, seed commands, mobile-capture
   quirk, theme-forcing).
2. **Read the spec.** If it is absent or marked a draft, generate a `status: draft`
   from the live tokens — but a spec derived from un-audited code cannot bless itself.
   While it is a draft, the Conformance ledger reads **"N/A — unratified"** and
   elevation binds to `references/critique-polish.md` + `brand-system`, not the draft.
   Surface the draft for human ratification.
3. Read `routes_public_manifest` — never fall back to a directory scan; path geometry
   misclassifies landing and auth routes.

## Phase 0.5 — Seed

Populate realistic data where a page renders data. For a genuinely empty page, the
**live-empty state IS the real visitor state** — audit it as is; do not fabricate
content. Mark routes with no possible instance N/A until content exists.

## Phase 1 — Matrix

Build `route × viewport × data-state` from `routes_public_manifest` (whole-site) or
the named target (scoped). Viewports: desktop-first AND mobile. Data-states: seeded,
empty, long-text/overflow, error/404 where reachable. The cell is the unit of done —
one captured artifact each.

> **Capture hygiene.** Marketing pages often gate sections behind scroll-reveal
> (`opacity:0` + IntersectionObserver), so a single full-page shot renders the middle
> blank. Before capturing, neutralize entrance animations (set `opacity:1`,
> `transform:none`, `animation:none`, `transition:none`, `visibility:visible` on all
> elements). Then capture full-page, or scroll through and capture per section. If the
> blank persists, that is a real defect — investigate, do not assume.

## Phase 2 — Critique

For each cell, score `references/critique-polish.md` (the taste/anti-slop rubric) plus
the **4 site axes** below, with `file:line` evidence. Capture an artifact per cell, and
**refute every "conformant" verdict** — an errored page renders like an empty one.

### The 4 site axes

1. **Conversion & copy hierarchy.** Is the hero promise clear in five seconds (what,
   for whom, why now)? Exactly one primary CTA per viewport, visually dominant,
   repeated at decision points? Social proof near the ask? Scannable headings, no
   wall-of-text? Copy leads with benefit, not feature? Score against
   `references/conversion-craft.md`. Voice and register defer to `brand-system`.
2. **Desktop-responsive craft.** Breakpoint integrity; max line-measure; fluid/clamped
   type; nothing assumes mobile-only. **Hover is a primary affordance** here —
   interactive elements need considered hover/focus states, and no critical info may
   depend on hover.
3. **Link / CTA integrity.** Every CTA and nav link resolves to a real, correct
   destination — no dead links, no links to redirect-only routes, no anchors to missing
   ids. File each break as a conformance defect.
4. **Screenshot freshness.** Embedded screenshots are current, on-brand, correctly
   seeded, and match the live app. When stale, hand the recapture to the app-local
   capture tooling and re-audit the page. For native mockups, use device capture — a
   local web server often renders demo data.

## Phase 3 — Elevate (two ledgers)

- **Conformance ledger** — fix deviations against `design_spec`; while the spec is a
  draft this ledger reads "N/A — unratified". File material deviations as beads.
- **Elevation ledger** — score every surface; change a surface only with a cited gap.
  **"No change = already at the bar" is a passing outcome.** Pull canonical radius /
  shadow / press-scale / easing values from `references/recipes.md`; the app's
  `design_spec` token overrides. Marketing motion (hero/section reveals, proof strips)
  comes from the marketing register in `references/interaction-and-feel.md`.
- While the spec is a draft, bound elevation to the anti-slop rubric + `brand-system`.

## Phase 4 — Inline a11y

Run `ac-polish/references/ui-checklist.md` **after ELEVATE but before the final
re-score**, so any change it triggers is itself re-scored in the same pass.

## Phase 5 — Re-score

Re-run the rubric plus the 4 axes on every changed cell. **Pass = zero sensor fails,
zero Blocker, zero High**, at every viewport and data-state. Inside the 3-cycle budget.

## Phase 6 — Human review and verify

Present the ledgers and artifacts; the human accepts, rejects, or files findings as
beads. Then see it running at every viewport and data-state changed; before/after
artifacts; tests pass; no sibling regressions on adjacent pages.

## Definition of Done

- [ ] Surface guard ran — every audited route is in `routes_public_manifest`.
- [ ] `design_spec` read or a draft bootstrapped; its status gates the Conformance ledger.
- [ ] Matrix complete: every `route × viewport × data-state` cell has an artifact.
- [ ] Both ledgers produced (Conformance — or "N/A unratified"; Elevation with cited gaps).
- [ ] The 4 site axes scored per surface; link/CTA integrity has zero unresolved breaks.
- [ ] A11y ran inline, before the final re-score.
- [ ] Embedded screenshots fresh, or the recapture handed off and re-audited.
- [ ] Re-score clean (zero blocker/high) at every viewport and data-state.
- [ ] Human reviewed the ledgers; findings filed as beads or accepted.
- [ ] Verified running; before/after artifacts; tests pass; no sibling regressions.
