# Site Audit-and-Elevate — operating procedure

The single loop `ac-site-polish` runs. Read this fully before starting. It reuses ac-ui-polish's
craft engine by reference and adds the marketing layer. The **cell** (`route × viewport × data-state`)
is the unit of "done" — **no theme axis** for the marketing surface.

---

## Phase 0 — Baseline

1. **Surface guard.** Confirm the target is the public surface: scoped target must be in
   `CORE/journeys/routes.public.md`; if not, **redirect to `ac-ui-polish`** and stop.
2. Read **`CORE/design.site.md`**. If absent, **bootstrap a DRAFT** (`status: draft`) from the live
   tokens + landing sections — but do not let it self-bless (see Phase 4 ledgers).
3. Read **`CORE/ui-audit.md`** for the runnable operational facts (this is where they live, NOT in
   `CORE/SKILL.md`): the **deployed-URL fallback** (audit logged-out/marketing pages against the
   deployed site when local dev is off — often the *more correct* target for a marketing audit), the
   **seed commands**, the **mobile-capture quirk** (`set viewport W H`), and theme-forcing. Read
   `CORE/SKILL.md` only for the high-level surface map. If the app has a `CORE/site-audit.md`, prefer
   it for site-specific facts; otherwise `ui-audit.md`'s logged-out-capture guidance applies.

## Phase 0.5 — Seed

Populate realistic data where a page renders data (e.g. the public foods directory/detail). For pages
that are **genuinely empty today** (e.g. a blog with no published posts), the **live-empty state IS
the real visitor state** — audit it as-is; do **not** fabricate content. Mark routes with no possible
instance (e.g. `[slug]` with zero published items) **N/A until content exists**.

## Phase 1 — Matrix

Build `route × viewport × data-state` from `routes.public.md` (whole-site) or the named target
(scoped). Viewports: desktop-first AND mobile. Data-states per route: seeded vs empty vs long-text /
overflow vs error/404 where reachable. **The cell is the unit of done** — one captured artifact each.

> **Capture hygiene — disable scroll-reveal before capturing (marketing sites animate in).** Landing
> pages commonly gate sections behind scroll-triggered reveal (`opacity:0` + IntersectionObserver),
> so a single **full-page** screenshot renders the middle of the page **blank** — and you will
> misread "animated in" as "missing/broken". Before capturing, neutralize entrance animations (same
> spirit as `screenshot-refresh` killing focus rings):
> ```js
> const s = document.createElement('style');
> s.textContent = `*,*::before,*::after{opacity:1!important;transform:none!important;
>   animation:none!important;transition:none!important;visibility:visible!important;}`;
> document.head.appendChild(s);
> ```
> Then either capture full-page, or **scroll through and capture per section** (more reliable on very
> tall pages). If the blank persists after disabling animations, THAT is a real defect (broken render
> / content-gated-behind-JS) — investigate, don't assume.

## Phase 2 — Sense (before eyes)

Run **`../ac-ui-polish/reference/sensors.md`** on every cell FIRST: contrast sweep, hardcoded-colour
grep, token symmetry. These are programmatic; eyes can't see a 3.9:1 ratio or a raw `#0c1014`.

> **Static grep is a first pass, not the verdict — confirm against the RENDERED DOM.** A source grep
> undercounts multi-line JSX (e.g. an `<Image>` whose `alt=` sits on a later line reads as "no alt"),
> and can't see computed contrast or an accessible name assembled at runtime. For anything that
> depends on rendered output (alt/accessible-name coverage, contrast ratios, focus order), run the
> check **in the live DOM via `page.evaluate`** (e.g. `document.querySelectorAll('img')` → flag those
> with no `alt` AND no `aria-label`/`aria-hidden`). Grep narrows; the DOM decides.

## Phase 3 — Audit

For each cell, score **`../ac-ui-polish/reference/critique-polish.md`** (the taste/anti-slop rubric)
**plus the 4 site axes below**, with `file:line` evidence. Capture an artifact per cell. **Refute
every "conformant" verdict** — an errored page renders like an empty one.

### The 4 site axes (the marketing layer ac-ui-polish lacks)

1. **Conversion & copy hierarchy** — Is the hero promise clear in <5s (what is it, for whom, why
   now)? Is there exactly one primary CTA per viewport, visually dominant, repeated at natural decision
   points? Is social proof present and placed near the ask? Is the page scannable (headings carry the
   argument; no wall-of-text)? Does copy lead with benefit, not feature? (Defer voice/register to
   `brand-system`.)
2. **Desktop-responsive craft** — Breakpoint integrity (no broken layouts between the app's
   breakpoints); max line-measure on long text; fluid/clamped type; nothing assumes mobile-only.
   **Hover is a primary affordance here** (unlike the mobile app) — interactive elements have
   considered hover/focus states; nothing depends on hover for critical info (still keyboard/touch
   reachable).
3. **Link / CTA integrity** — Every CTA and nav link resolves to a real, correct destination. No dead
   links, no links to redirect-only routes (e.g. an `/about` that just `redirect('/')` while nav still
   points to it), no anchors to missing ids. External links open correctly. File each break as a
   conformance defect.
4. **Screenshot freshness** — Embedded app screenshots are current, on-brand, correctly seeded (no
   stale data / empty states / dev chrome), and match the live app. When stale, **hand off to
   `screenshot-refresh`** to reseed + recapture; re-audit the page after.

## Phase 4 — Elevate (two ledgers)

- **Conformance ledger** — fix defects against `design.site.md`. **While the spec is `status: draft`,
  this ledger reads "N/A — unratified"** (do not emit hollow passes); surface the draft for human
  ratification. File material deviations as beads (`qa-finding`, + `qa-blocker` if it breaks the spec).
- **Elevation ledger** — score every surface; change a surface **only** with a cited gap. **"No change
  = already at the bar" is a passing outcome** — never churn working code for a diff. Pull canonical
  values (radius, shadow, press-scale, easing, stagger) from `../ac-ui-polish/reference/recipes.md`;
  the app's `design.site.md` token always overrides.
- **Binding rule:** while the spec is a draft, bound elevation to the anti-slop rubric +
  `brand-system` tokens (not the draft). After ratification, bind to `design.site.md`.

Gains plateau after ~3 elevation cycles per surface — don't loop past diminishing returns.

## Phase 5 — Inline SEO + a11y (BEFORE the final re-audit)

Run as composed stages so a single `/ac-site-polish` pass is genuinely one-stop:
- **`seo-metadata`** — titles, meta description, canonical, OG/Twitter cards, sitemap, robots,
  JSON-LD. On a mature site this *extends* existing metadata, not bootstraps.
- **`web-design-guidelines`** — objective a11y mechanics (ARIA, focus order, form semantics, contrast
  math, motion-reduce). Do not re-wrap — call it directly.

Sequencing: run these **after ELEVATE but before the final RE-AUDIT**, so any code changes they
trigger are themselves re-audited in the same pass (nothing ships un-re-audited).

## Phase 6 — Re-audit

Re-run sensors + rubric + the 4 axes on every changed cell. **Pass = zero sensor fails, zero blocker,
zero high**, at every viewport and data-state.

## Phase 7 — Verify

See it running at every viewport + data-state changed; before/after artifacts; tests pass; no sibling
regressions on adjacent pages.

---

## Definition of Done

- [ ] Surface guard ran — every audited route is in `routes.public.md` (no app routes leaked in).
- [ ] `design.site.md` read or bootstrapped; its `status` (draft/ratified) correctly gates the
      Conformance ledger.
- [ ] **Reference-file contract:** every `../ac-ui-polish/reference/<file>.md` cited resolves on disk
      (sensors, critique-polish, recipes, visual-craft, interaction-and-feel, perceived-performance).
- [ ] Matrix complete: every `route × viewport × data-state` cell has a captured artifact (or a
      documented N/A, e.g. unpublished `[slug]`).
- [ ] Sensors ran before eyes on every cell.
- [ ] Both ledgers produced (Conformance — or "N/A unratified"; Elevation with cited gaps only).
- [ ] The 4 site axes scored per surface; link/CTA integrity has zero unresolved breaks.
- [ ] SEO + a11y ran inline, before the final re-audit.
- [ ] Embedded screenshots fresh (or `screenshot-refresh` handed off + re-audited).
- [ ] Re-audit clean (zero sensor fails / blocker / high) at every viewport + data-state.
- [ ] Verified running; before/after artifacts; tests pass; no sibling regressions.
