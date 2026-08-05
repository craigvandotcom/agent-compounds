---
name: ac-site-polish
description: 'Use when polishing the PUBLIC marketing website (landing page + public routes) to premium quality and/or checking it conforms to the site''s design spec — one page or a whole-site crawl. The public twin of ac-ui-polish (which owns the authenticated app); this one anchors on CORE/design.site.md. Triggers on "polish the website", "site polish", "ac-site-polish", "polish the landing page", "marketing page polish", "elevate the homepage", "the website looks like AI slop", "make the marketing site premium", "audit the public site". Covers conversion/copy hierarchy, desktop+mobile responsive craft, link/CTA integrity, and embedded-screenshot freshness, then design-spec conformance + elevation — runs SEO and a11y inline. NOT for: the authenticated app (use ac-ui-polish — anchored on design.md), pure SEO alone (use seo-metadata), accessibility audits alone (use web-design-guidelines), React data/bundle perf (use capacitor), visual/CSS defects (use ui-debug), or multi-model design ideation (use ui-brainstorm).'
---

# Site Polish

**Purpose:** Take the already-coded **public marketing website** and (1) verify it conforms to
`CORE/design.site.md`, then (2) raise it to premium quality — **bounded to that spec so polish never
drifts into redesign**. Adds the marketing axes ac-ui-polish lacks (conversion, copy hierarchy,
desktop responsive, link integrity, screenshot freshness) and runs SEO + a11y inline. One page or a
whole-site crawl.

> **The public twin of `ac-ui-polish`.** ac-ui-polish owns the **authenticated app** (anchored on
> `CORE/design.md`); this skill owns the **public marketing** surface (anchored on
> `CORE/design.site.md`). Same craft engine, different surface + spec + matrix. The marketing site is
> browser-only (the native build ignores public pages) — run **through the browser**; no
> device/native twin.

> **Generic skill — method only, zero app facts** (symlinked from agent-compounds across apps; do not
> add app-specific facts to this file). **App specifics:** the spec → `CORE/design.site.md`; routes →
> `CORE/journeys/routes.public.md`; the **runnable operational facts (deployed URL, seed commands,
> capture quirks) → `CORE/ui-audit.md`** (or `CORE/site-audit.md` if present), NOT `CORE/SKILL.md`
> (which holds only the surface map).

> **Reuses ac-ui-polish's craft engine — never fork it** (the visual-craft, interaction, perceived-
> performance, sensors, anti-slop rubric, and recipes are identical for a webpage). This skill is a
> **thin spine** pointing into ac-ui-polish's reference files, adding only the marketing layer.

---

## Surface ownership — the boundary with ac-ui-polish

`CORE/journeys/routes.public.md` is the **single ownership oracle**: a route belongs to this skill
**iff it is listed there**. The authenticated app + auth routes live in `routes.md` (ac-ui-polish's).

**In-body surface guard (run first, both modes):** if the target route is **NOT listed in
`routes.public.md`**, this is ac-ui-polish's surface — **stop and redirect to `ac-ui-polish`**. Key
off manifest membership, **not path geometry** (the landing `/` is `app/page.tsx`, outside
`app/(public)/`; auth routes live in `(auth)`). ac-ui-polish carries the symmetric guard.

---

## The spec anchor — `CORE/design.site.md`

The baseline is the app's `CORE/design.site.md` — the site twin of `design.md`, same two-part format,
**hand-authored** (there is **no** `designmd-gen`/linter for it):

1. **Token YAML block** — colors, spacing, radius, type ramp the marketing surface uses.
2. **Do's/Don'ts prose** — plus the **marketing-only sections** ac-ui-polish's `design.md` lacks:
   conversion hierarchy (hero promise, CTA priority, social-proof placement), copy register (defer
   voice to `brand-system`), desktop-responsive breakpoints, hover-as-primary-affordance rules, and a
   single-theme caveat where applicable (e.g. "site authored dark-only — no theme axis").

Plus a frontmatter field: **`status: draft | ratified`**.

**Bootstrap without self-blessing.** If `design.site.md` is **absent**, generate a **DRAFT** (write
`status: draft`) from the live tokens + the landing sections — but a spec derived from un-audited code
cannot bless itself. So while `status: draft`:
- The **Conformance ledger reads "N/A — unratified"** (no hollow pass).
- **ELEVATE + the 4 site axes + SEO/a11y still run**, but bounded to **the anti-slop rubric
  (`../ac-ui-polish/reference/critique-polish.md`) + `brand-system` tokens** — NOT the draft (else
  you entrench current styling).
- Surface the draft for a human to review; once they flip it to `status: ratified`, Conformance
  turns on and ELEVATE binds to `design.site.md` as ac-ui-polish does.

If `design.site.md` is missing entirely and you cannot bootstrap, fall back to `design.md` +
`brand-system` and flag the absence.

---

## Two modes

| Mode | Input | What runs |
|------|-------|-----------|
| **Scoped** (default) | one page / section named by the user | the loop in `workflows/audit-and-elevate-site.md`, anchored on `design.site.md` |
| **Whole-site** | "audit the whole site" / "polish the marketing site" | build the coverage matrix from `routes.public.md` → sensors + conformance per cell → elevation → inline SEO/a11y → final re-audit |

**Coverage matrix = `route × viewport × data-state`** — **no theme axis** (marketing surfaces are
typically single-theme; confirm in `design.site.md`). Viewport set = **desktop-first AND mobile**
(state defaults in `CORE`; marketing is desktop-primary, unlike the mobile-first app). The **cell** is
the unit of "done" — capture an artifact for every cell; a route you didn't render is not audited.

Whole-site mode discovers routes **from `routes.public.md`** (Phase 1 of the build). If that manifest
is absent, **halt and prompt** — do not fall back to a directory scan (path geometry mis-classifies
`/` and the auth routes).

### Run tasks (whole-site mode)

A runtime **progress list** (`TaskCreate`/`TaskUpdate`) — distinct from the Conformance/Elevation
ledgers below, which are the audit's *findings* output — so a glance shows where a long whole-site
crawl actually is. One task per major section, created at the start of the run:

Ledger contract: `ac-pipeline/references/run-ledger.md` — one task per section, advance as you go; ledger = run position, never work items.

```
TaskCreate("Baseline — read design.site.md (or bootstrap DRAFT) + ui-audit.md")
TaskCreate("Seed data — populate realistic state where pages have data")
TaskCreate("Build coverage matrix — route (routes.public.md) × viewport × data-state")
TaskCreate("Sense — sensors per cell (contrast, hardcoded colour, token symmetry)")
TaskCreate("Audit vs design.site.md — rubric + the 4 site axes, per cell")
TaskCreate("Elevate — two ledgers (Conformance + Elevation)")
TaskCreate("SEO + a11y — seo-metadata + web-design-guidelines, inline")
TaskCreate("Re-audit — re-run sensors + rubric + axes on changed cells")
TaskCreate("Verify — running at every viewport/data-state; before/after artifacts; DoD checklist")
```

`TaskUpdate` each to `in_progress` on start and `completed` on finish; carry live detail (cell
counts, finding counts) in the description. **Scoped (single-page) mode is exempt** — a short
single-context loop where run tasks would be ceremony.

---

## Core workflow

The whole skill runs through one loop. **Read `workflows/audit-and-elevate-site.md` before starting** —
it is the operating procedure (loop, the 4 site axes, inline SEO/a11y sequencing, Definition of Done).
In short:

```
0. BASELINE  Read CORE/design.site.md (or bootstrap a DRAFT). Read CORE/ui-audit.md for the
             RUNNABLE facts (deployed-URL fallback, seed cmds, mobile-capture quirk); CORE/SKILL.md
             only for the surface map + routes.public.md pointer.
0.5 SEED     Populate realistic data where pages have data (foods). For genuinely empty
             pages (e.g. an empty blog), the LIVE-EMPTY state IS the real visitor state —
             audit it as-is; don't fabricate content.
1. MATRIX    route (routes.public.md) × viewport × data-state. The cell is the unit of done.
2. SENSE     Run ../ac-ui-polish/reference/sensors.md FIRST on every cell (contrast,
             hardcoded colour, token symmetry) — eyes miss these.
3. AUDIT     Score ../ac-ui-polish/reference/critique-polish.md (taste) + the 4 SITE AXES
             (conversion/copy, desktop-responsive, link/CTA integrity, screenshot freshness)
             — with file:line. Capture an artifact per cell.
4. ELEVATE   Two ledgers — Conformance (fix defects; "N/A" while spec is draft) + Elevation
             (score every surface; change ONLY with a cited gap; "no change" is a pass).
5. SEO+A11Y  Run seo-metadata + web-design-guidelines INLINE (before the final re-audit).
6. RE-AUDIT  Re-run sensors + rubric + axes. Pass = zero sensor fails / blocker / high.
7. VERIFY    See it running at every viewport + data-state; before/after artifacts;
             tests pass; no sibling regressions; Definition of Done complete.
```

**Six non-negotiables** (adapted from ac-ui-polish; each maps to a real escaped defect):
**sensors run before eyes** · **audit every data-state, never just the happy path** (no theme axis
here, so data-state is the matrix axis that catches escaped defects) · **audit seeded/real data, not
a blank page** · **verify don't infer** (render every route — use the deployed URL if local blocks
it; cold-navigate, don't warm-click) · **refute every "conformant" verdict** (empty ≠ clean — an
errored page renders like an empty one) · **never change working code just to have a diff**.

---

## Reuse-by-reference — the craft engine

The craft layer lives in **ac-ui-polish's reference files**, reused **by reference, never copied**.

- **Literal path:** reference shared craft as **`../ac-ui-polish/reference/<file>.md`** — per-skill
  symlinks make this sibling-dir offset resolve in both the canonical tree and each app's symlinked
  `.claude/skills/`.
- **Two-namespace rule:** bare `<file>` = this skill's own files (`workflows/...`);
  `../ac-ui-polish/<file>` = shared craft.
- **Required ac-ui-polish reference files** (this skill breaks if any is renamed/removed):
  `sensors.md`, `critique-polish.md`, `recipes.md`, `visual-craft.md`, `interaction-and-feel.md`,
  `perceived-performance.md`. Confirm each resolves before relying on it (see the workflow's DoD).
- **Site-specific adaptations** when reading those files: `interaction-and-feel.md`'s native sections
  (gestures/haptics/safe-area) are **N/A** for a webpage; **hover flips from forbidden (mobile app)
  to a primary affordance** on desktop site surfaces.

---

## Delegation map (orchestrate — don't reimplement)

Pass selection defers to `ac-pipeline/references/verification-gate.md` — one selection brain, never re-decided locally.

| Need | Defer to |
|------|----------|
| Visual craft, perceived performance, interaction feel, anti-slop rubric, recipes, sensors | `../ac-ui-polish/reference/*.md` (reuse) |
| Conversion structure, copy hierarchy, pricing clarity (the marketing layer) | `reference/conversion-craft.md` (this skill's own) |
| SEO / metadata / OG + Twitter cards / sitemap / robots / JSON-LD | `seo-metadata` — **run inline** as a composed stage |
| Accessibility *mechanics* (ARIA, focus, form semantics, contrast math) | `web-design-guidelines` — **run inline** |
| Refreshing embedded app screenshots (seed → capture → verify) | `screenshot-refresh` |
| Brand palette, pillar colour, voice/copy register, banned phrases | `brand-system` |
| React/Next perf internals (waterfalls, bundle, hydration) | `capacitor` |
| A style genuinely isn't applying / layout broken (a defect) | `ui-debug` |
| Static screenshot index of every route | `_tools/crawl-and-capture` + `CORE/journeys/routes.public.md` |
| The authenticated app surface | `ac-ui-polish` |

---

## Supporting documentation

| File | When to read |
|------|--------------|
| `workflows/audit-and-elevate-site.md` | **Always** — the operating procedure + the 4 site axes + Definition of Done |
| `reference/conversion-craft.md` | At AUDIT (site axis 1) + ELEVATE — landing-structure presence rubric, copy elevation vocabulary, pricing "reduce uncertainty" checklist |
| `../ac-ui-polish/reference/sensors.md` | **At SENSE, before eyes** — contrast / hardcoded-colour / token symmetry |
| `../ac-ui-polish/reference/critique-polish.md` | At AUDIT — the anti-slop checklist + scoring rubric |
| `../ac-ui-polish/reference/recipes.md` | At ELEVATE — canonical paste-able values (radius, shadow, press-scale, easing) |
| `../ac-ui-polish/reference/visual-craft.md` | Elevating appearance: type, spacing, depth, imagery, layout |
| `../ac-ui-polish/reference/interaction-and-feel.md` | Elevating micro-interactions (hover = primary on desktop; native sections N/A) |
| `../ac-ui-polish/reference/perceived-performance.md` | When the page feels slow/janky despite being functional |

---

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Auditing a public route against `design.md` | Public routes anchor on `design.site.md`; if the route isn't in `routes.public.md`, it's ac-ui-polish's — redirect |
| Letting a freshly-bootstrapped draft "bless" the current site | While `status: draft`, Conformance = N/A; ELEVATE binds to the rubric + brand-system, not the draft |
| Treating it like the mobile app (mobile-only, no hover) | Marketing is desktop-primary; hover is a primary affordance; audit desktop AND mobile |
| Fabricating content for an empty page | The live-empty state IS the real visitor state — audit it as-is; mark routes with no instances (e.g. unpublished `[slug]`) N/A |
| Copying ac-ui-polish's reference files in | Reuse by `../ac-ui-polish/reference/<file>.md`; never fork the craft engine |
| Skipping SEO/a11y or running them after the final re-audit | Run them inline, **before** the final re-audit, so changes they trigger get re-audited |
| Redesigning instead of elevating | Conform to `design.site.md` first; change the least that achieves premium |
