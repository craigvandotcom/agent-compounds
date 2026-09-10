---
name: ui-elevate
description: 'Use when raising already-working UI to premium quality — the taste layer above correctness. Two modes: app (the authenticated product surface) and site (the public marketing surface). Triggers on "polish this UI", "elevate this screen", "make it feel premium", "level up the design", "polish the landing page", "elevate the homepage", "the website looks like AI slop", "tighten the visuals", "make it production-quality", "audit the design craft". Covers the elevation manifesto, anti-slop critique, visual craft, interaction and feel, perceived performance, and conversion craft, with every edit bounded to the design spec''s tokens. NOT for: functional or correctness defects (ac-polish ui mode), accessibility mechanics (ac-polish/references/ui-checklist.md), React/Next perf internals (capacitor), visual/CSS bugs (ui-debug), or multi-model design ideation (ui-brainstorm).'
---

# UI Elevate

**Purpose:** Take already-working UI to premium. This is the **taste layer** — the
layer a command cannot judge. It runs after correctness is proven, and it changes
only what a cited design gap justifies.

**Not a convergent loop.** Gains plateau after ~3 elevation cycles per surface, and
the call between "keep going" and "already at the bar" is human judgement. This must
not loop to a machine green: findings become beads or direct edits **with the human
present**. Correctness convergence lives in `ac-polish` ui mode.

> **Generic skill — method only, zero app facts.** App specifics (design tokens,
> routes, seed recipe, deployed URL) come from the consumer manifest and the app's
> `CORE` docs. Never hardcode them here.

---

## Two modes

| Mode | Surface | Route manifest key | Spec key |
|------|---------|--------------------|----------|
| **app** (default) | the authenticated product UI | `routes_manifest` | `design_spec` |
| **site** | the public marketing site | `routes_public_manifest` | `design_spec` (site section) |

A route belongs to the mode whose manifest lists it. Read the **consumer manifest**
(`factory.json`) and resolve the keys — never a literal path. If the named target is
on the other mode's manifest, stop and switch modes; auditing a public route against
the app spec files the wrong findings.

---

## Bindings — read these from `factory.json`

| Key | What it gives this skill |
|-----|--------------------------|
| `design_spec` | the token + Do's/Don'ts anchor every edit is bounded to |
| `routes_manifest` | the authenticated route list (app mode) |
| `routes_public_manifest` | the public route list (site mode) |
| `ui_audit` | runnable facts: theme toggle, seed recipe, deployed URL, auth, viewport set |

Read `factory.json`, resolve each key, then read the file it names. A missing key is a
consumer setup defect — say so, never fall back to a guessed literal.

---

## The loop

```
0. BIND     Resolve factory.json keys. Read the design spec first — it is the
            conformance target and the bound on every change.
1. MATRIX   Build the coverage matrix for the mode. app: route × theme × viewport ×
            data-state. site: route × viewport × data-state (no theme axis).
            The cell is the unit of done — an unrendered route is not audited.
2. SEED     Populate realistic data (app). For a genuinely empty site page, the
            live-empty state IS the visitor state — audit it as is.
3. CRITIQUE Read rendered artifacts against references/critique-polish.md (the
            anti-slop rubric) plus the mode's craft files. Score with file:line and
            a concrete fix. Never a vibe summary.
4. ELEVATE  Apply the cited, impact-ranked fixes — highest impact, lowest risk first.
            "Already at the bar → no change" is a PASSING outcome, not a gap to fill.
5. REVIEW   With the human present: accept, reject, or file each finding as a bead.
6. RE-SCORE The changed cells, bounded to the 3-cycle budget.
```

**Three non-negotiables:** every edit is bounded to the design spec's tokens · every
change cites a specific gap · never change working code just to have a diff.

---

## The manifesto

1. **Consistency beats cleverness.** Conform to the existing system before improving it.
2. **Detail is the product.** Optical alignment, 1px borders, line-height, easing — the gap between "fine" and "premium" lives here.
3. **Motion has meaning or it's noise.** A transition explains a state change or it is cut.
4. **Fast is a feeling.** Optimistic UI, skeletons, instant feedback beat a faster backend.
5. **Kill the AI tells.** Centered-everything, default gradients, emoji bullets, generic imagery, hedge-y copy — all out.
6. **Real content, real states.** Design for empty, loading, error, long-text and overflow, not the happy path.

---

## Delegation map (orchestrate — do not reimplement)

| Need | Defer to |
|------|----------|
| Correctness convergence, sensors, token conformance, a11y mechanics | `ac-polish` ui mode + `ac-polish/references/ui-checklist.md` |
| Brand palette, pillar colour, voice, banned phrases | `brand-system` |
| React/Next perf internals (waterfalls, bundle, hydration) | `capacitor` |
| A style is not applying / layout is broken (a defect) | `ui-debug` |
| Multiple divergent design opinions / cross-model consensus | `ui-brainstorm` |
| Functional QA (native shell, browser journeys) | `ac-qa` |
| Whole-app fan-out across many cells | `workflows/app-fanout.md` |

---

## Supporting documentation

| File | When to read |
|------|--------------|
| `workflows/app.md` | **Always in app mode** — the operating procedure + Definition of Done |
| `workflows/site.md` | **Always in site mode** — the procedure + the 4 site axes |
| `references/critique-polish.md` | At CRITIQUE — the anti-slop checklist + scoring rubric |
| `references/visual-craft.md` | Elevating type, spacing, depth, imagery, layout |
| `references/interaction-and-feel.md` | Elevating micro-interactions, states, motion, gestures |
| `references/perceived-performance.md` | When the UI feels slow despite being functionally fine |
| `references/conversion-craft.md` | Site mode — conversion structure, copy hierarchy, pricing clarity |
| `references/recipes.md` | At ELEVATE — canonical radius / shadow / press-scale / easing / stagger values |
| `references/sensors.md` | Correctness sensors — owned by `ac-polish` ui mode; read only to interpret its findings |

Canonical values come from `references/recipes.md`; the app's `design_spec` token
always overrides.

---

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Redesigning instead of elevating | Conform to the design spec first; change the least that reaches premium |
| Inventing tokens or components | Reuse the app's primitives; add only with explicit, stated justification |
| Changing code to have a diff | "Already at the bar → no change" is a pass |
| Auditing one theme, or an empty account | Every theme and every reachable data-state is a matrix cell |
| Inferring quality without rendering | A route you did not render is not audited |
| Looping for a machine green | Bounded to 3 cycles; the rest is a human call |
