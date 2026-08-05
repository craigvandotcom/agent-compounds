---
name: ac-ui-polish
description: 'Use when polishing already-coded UI to premium quality or checking it conforms to the app''s design spec (CORE/design.md) — one screen or a whole-app crawl. Triggers on "polish this UI", "make this feel premium", "ui polish", "level up the design", "this looks like AI slop", "elevate this", "check design conformance", "tighten the visuals", "make it production-quality". NOT for: the public marketing site (ac-site-polish), accessibility/compliance audits (web-design-guidelines), design ideation (ui-brainstorm), React perf internals (capacitor), visual/CSS defects (ui-debug), greenfield generation.'
---

# UI Polish

**Purpose:** Take already-coded UI and (1) verify it conforms to the app's design spec (`CORE/design.md`), then (2) raise it to premium quality — bounded to that spec so polish never drifts into redesign. Works on one screen or a whole-app crawl.
**Domain:** Frontend craft, design-spec conformance, UX/UI polish, anti-slop critique
**Status:** Complete (the elevation engine, extended with whole-app spec-anchored conformance)

> **The third member of the "verify the built app" triad** — alongside
> `ac-qa-device` (native functional QA) and `ac-qa-browser` (web functional QA).
> Those prove *does it work*; this proves *does it match the spec and look premium*.
> Visual polish is bundle-determined (identical pixels in browser and native
> webview), so this skill runs **once through the browser** — it does NOT split
> into device/browser twins. Device-specific visual breakage (safe-area, splash,
> keyboard overlap) is a functional check owned by `ac-qa-device`.

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (design tokens, component
> library, brand pillar, route structure, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes) and
> the app's local `design-system` skill if present.
> Do not add app-specific facts to this file.

---

## What this skill is (and isn't)

This is an **audit-and-elevate** skill. The default input is **code that already
exists and works**. The job is two axes, in order:

1. **Bring it inline** — conform to the app's *existing* design language (its
   tokens, spacing scale, type ramp, component primitives, motion vocabulary,
   brand pillar). Consistency first: a polished screen that fights the rest of the
   app is a regression.
2. **Elevate it** — once consistent, push it past "fine" to premium: tighter
   typography, real depth, considered micro-interactions, instant-feeling
   performance, zero AI-slop tells.

**Not for:** greenfield generation from a blank file, deep data-fetching/bundle
performance, accessibility *mechanics*, or visual *bug* repro. Those have homes —
see the delegation map. This skill owns the layer the **user perceives**.

---

## Two modes

| Mode | Input | What runs |
|------|-------|-----------|
| **Scoped** (default) | one screen / component / flow named by the user | the elevation loop below, anchored on `design.md` |
| **Whole-app** | "audit the whole app against the design spec" | build the **coverage matrix** (route × theme × viewport × data-state) → **sensors + Phase A conformance** per cell → **Phase B elevation** (two ledgers, per surface) |

**Whole-app mode** crawls the app's **`CORE/journeys/routes.md`** manifest at the app's
viewport set, **in every theme**. This manifest is the **authenticated app + auth surface** only —
the public marketing routes live in `CORE/journeys/routes.public.md` and are owned by `ac-site-polish`
(do not crawl them here). The shared **`_tools/crawl-and-capture`** primitive
can produce a quick static-screenshot index (same captures `ac-qa-browser` uses), but
note it emits PNGs only and has **no theme switch** — the contrast/false-clean sensors
are `eval` on a *live* DOM, so the actual audit drives a live browser per cell (force
theme + cold-navigate + eval). With **explicit multi-agent opt-in**, run it as the
fan-out in `workflows/whole-app-workflow.md` — **one agent per route, each owning that
route's full theme × viewport × data-state sub-matrix** (the cell stays the 4-axis unit;
the agent owns a route's slice of cells), adversarially verified — so coverage is
exhaustive and no "pass" is inferred. Then:

- **Phase A — Conformance (read-only).** For each page, compare the rendered result
  to `CORE/design.md`: token usage (colors/spacing/radius/type off the scale),
  the Do's/Don'ts, required interaction states. File each deviation as a bead
  (`qa-finding`, + `qa-blocker` if it breaks the spec materially). **Be specific:**
  "change X to Y because design.md says Z" — never vague "feels off." This phase
Visual references per `ac-pipeline/references/design-refs.md` (save immediately, cite the path, never prose-only).

  does not edit code; it produces the deviation list. **If `docs/design-refs/` has a
  reference image for the surface under polish, anchor on it explicitly:** do a
  Read-tool visual comparison — Read the rendered screenshot AND the reference image
  and compare them directly (shape, radius, spacing, not just token names) — no
  external vision tooling required. Conformance-to-bead text alone is insufficient;
  this is how the navbar-capsule-vs-rounded-xl drift (wave-050) would have been caught.
- **Phase B — Elevation.** On confirmed-conformant pages, run the elevation loop —
  **bounded to `design.md`'s tokens** (no new fonts/colors/components). Apply the
  highest-impact, lowest-risk fixes first.

Gains plateau after ~3 elevation cycles per surface — don't loop past diminishing returns.

### Run tasks (whole-app mode)

**Not the Conformance/Elevation ledgers above** — those are the audit's *findings* output
(defects + scored surfaces). This is a separate, runtime **progress list** (`TaskCreate` /
`TaskUpdate`) so a glance shows where a long whole-app crawl actually is — call it "run tasks"
here to avoid colliding with the "ledger" term already owned by Conformance/Elevation. One task
per major section, created at the start of the run:

Ledger contract: `ac-pipeline/references/run-ledger.md` — one task per section, advance as you go; ledger = run position, never work items.

```
TaskCreate("Baseline — read design.md + theme siblings + ui-audit.md")
TaskCreate("Seed data — populate realistic account state")
TaskCreate("Build coverage matrix — route × theme × viewport × data-state")
TaskCreate("Sense — sensors per cell (contrast, hardcoded colour, token symmetry)")
TaskCreate("Audit vs design.md — Phase A conformance + rubric, per cell")
TaskCreate("Elevate — Phase B, two ledgers (Conformance + Elevation)")
TaskCreate("Re-audit — re-run sensors + rubric on changed cells")
TaskCreate("Verify — running in every theme/data-state; before/after artifacts; DoD checklist")
```

`TaskUpdate` each to `in_progress` on start and `completed` on finish; carry live detail (cell
counts, finding counts) in the description. **Scoped (single-screen) mode is exempt** — it's a
short, single-context loop where a run-tasks list would be ceremony, not clarity.

## The spec anchor — `CORE/design.md`

The **baseline is the app's `CORE/design.md`** (Google `design.md` format: token
YAML + prose Do's/Don'ts), which itself references the neoMeta-level brand spec.
Read it FIRST, before any audit, and scope every suggestion to it — this is the
guardrail against redesigning instead of polishing.

- If `design.md` is absent (app not yet migrated), fall back to the app's local
  `design-system` skill + `brand-system` + the live tokens — but flag that the app
  lacks a `design.md` so it can be generated.
- On a brand-layer conflict, `brand-system` wins (it's the authority); `design.md`
  owns app-specific implementation.

---

## When to Use This Skill

**Intent Triggers:**
- "Polish this screen / component / flow"
- "Make this feel premium / high-end / production-quality"
- "Level up the design", "elevate this", "next-level"
- "This looks like AI slop / generic / templated — fix it"
- "Bring this up to the standard of the rest of the app"
- "Tighten the visuals", "the spacing feels off", "it feels janky"

**When NOT to Use:**
- The target is a **public marketing/landing route** → use `ac-site-polish` (it owns the public
  surface, anchored on `design.site.md`). **Surface guard (both modes):** a route is ac-site-polish's
  iff it is listed in `CORE/journeys/routes.public.md`. If the named/derived target is in that
  manifest, **stop and redirect to `ac-site-polish`** — do not audit it here (the public site uses a
  different spec; auditing it against `design.md` files the wrong findings). Keyed off manifest
  membership, NOT path geometry (the landing `/` is `app/page.tsx`, outside `app/(public)/`).
- Building a brand-new UI from nothing → that's design/generation work, not elevation
- The bug is a *defect* (style not applying, broken layout) → use `ui-debug`
- The ask is purely brand palette/voice → use `brand-system`
- The ask is data-fetch waterfalls / bundle size / hydration internals → use `capacitor`
- The ask is a11y compliance mechanics (ARIA, focus traps, form semantics) → use `web-design-guidelines`

---

## Core workflow

The whole skill runs through one loop. **Read `workflows/audit-and-elevate.md`**
before starting — it is the operating procedure. In short:

```
0. BASELINE   Read CORE/design.md + its design.<theme>.md siblings + CORE/ui-audit.md
              (theme toggle, seed recipe, deployed URL, auth, component dirs).
0.5 SEED      Populate realistic data (CORE names the script). Empty ≠ audited.
1. MATRIX     Build the coverage matrix: route × theme × viewport × data-state.
              The cell — not the screen — is the unit of "done."
2. SENSE      Run reference/sensors.md FIRST on every cell: contrast sweep (per
              theme), hardcoded-colour grep, token symmetry. Eyes miss these.
3. AUDIT      Then score reference/critique-polish.md per surface (taste layer),
              with file:line. Capture an artifact for every cell.
4. ELEVATE    Two ledgers — Conformance (fix defects) + Elevation (score every
              surface; change ONLY with a cited gap; "no change" is a pass).
5. RE-AUDIT   Re-run sensors + rubric. Pass = zero sensor fails / blocker / high,
              IN EVERY THEME.
6. VERIFY     See it running in every theme + data-state changed; before/after
              artifacts; tests pass; no sibling regressions.
```

**Six non-negotiables (each maps to a real escaped defect — see Common Mistakes):**
**sensors run before eyes** · **audit every theme, never one** · **audit seeded
data, not just empty** · **verify don't infer** (a route you didn't render is not
audited — use the deployed URL when local auth blocks it; cold-navigate, don't
warm-click) · **refute every "conformant" verdict** (empty ≠ clean — an errored
view renders like an empty one) · **never change working code just to have a
diff**. Fill the **Definition of Done** checklist in
`workflows/audit-and-elevate.md` before declaring anything elevated.

---

## The manifesto (apply on every pass)

1. **Consistency beats cleverness.** Conform to the app's existing system before
   improving it. A bespoke flourish that breaks the pattern is slop, not polish.
2. **Detail is the product.** Optical alignment, 1px borders, line-height, the
   easing curve — the gap between "fine" and "premium" lives entirely here.
3. **Motion has meaning or it's noise.** Every transition explains a state change
   or guides attention. Decoration-only animation gets cut.
4. **Fast is a feeling, not a number.** Optimistic UI, skeletons, and instant
   feedback beat a faster backend the user can't perceive.
5. **Kill the AI tells.** Centered-everything, default gradients, emoji bullet
   lists, identical card grids, generic stock/AI imagery, hedge-y copy → all out.
6. **Real content, real states.** Design for empty/loading/error/long-text/
   overflow, not just the happy path with perfect placeholder data.

---

## Delegation map (stay DRY — don't reimplement these)

| Need | Skill to defer to |
|------|-------------------|
| Brand palette, pillar color, voice/copy register, banned phrases | `brand-system` |
| Accessibility *mechanics* (ARIA, focus, form semantics, contrast math) | `web-design-guidelines` |
| React/Next perf internals (waterfalls, bundle, data fetching, memoization) | `capacitor` |
| Native bridge / cross-platform plumbing | `capacitor` |
| Want multiple independent design opinions / consensus critique | `ui-brainstorm` |
| A style genuinely *isn't applying* / layout is broken (a defect) | `ui-debug` |
| Static screenshot index of every route (whole-app mode; PNGs only, single theme, no live eval) | `_tools/crawl-and-capture` + `CORE/journeys/routes.md` |
| Programmatic correctness checks (contrast / hardcoded colour / token symmetry) | `reference/sensors.md` (run before the visual rubric) |
| Functional QA (does it work / native shell / console) | `ac-qa-browser`, `ac-qa-device` |
| See it running / screenshot / confirm the change | `run`, `verify` |
| Surface visual evidence (screenshots) to Craig for sign-off | `ac-pipeline/references/qa-shared.md` § Conductor / worker evidence protocol — UPLOAD the image via `slack-send --file` to #sofi, never a `/tmp` path in a card |

This skill *orchestrates* — it calls these in, it doesn't duplicate their content.

---

## Supporting Documentation

| File | When to Read |
|------|--------------|
| `workflows/audit-and-elevate.md` | **Always** — the operating procedure (+ the Definition of Done) |
| `reference/sensors.md` | **At AUDIT, before eyes** — contrast sweep, hardcoded-colour grep, token symmetry |
| `workflows/whole-app-workflow.md` | Whole-app mode **with multi-agent opt-in** — the fan-out Workflow template |
| `reference/critique-polish.md` | At AUDIT — the anti-slop checklist + scoring rubric (the taste layer) |
| `reference/recipes.md` | **At ELEVATE — the canonical paste-able values** (concentric radius, shadow-as-border, press-scale, icon-swap, enter/exit, image outline, hit-area, transition/will-change). The token-override rule lives here: app token > generic constant. |
| `reference/visual-craft.md` | When elevating appearance: type, spacing, depth, imagery, layout |
| `reference/interaction-and-feel.md` | When elevating micro-interactions, states, motion, gestures, haptics |
| `reference/perceived-performance.md` | When the UI feels slow/janky despite being functionally fine |

---

## Quick Reference — the elevation passes

Run these as ordered sweeps over the target (detail in the reference files). When a
pass calls for a specific value (a radius, press-scale, shadow, easing, stagger
delay), pull the canonical constant from **`reference/recipes.md`** rather than
inventing one — but the app's `design.md` token always overrides it:

1. **Consistency** — does it use the app's tokens, scale, primitives, pillar?
2. **Typography** — ramp, line-height, measure, letter-spacing, weight contrast
3. **Spacing & layout** — one scale, optical alignment, rhythm, density, grid
4. **Depth & color** — elevation logic, shadow realism, restrained color use
5. **Imagery & icons** — real/owned over generic; one icon family, one weight
6. **States** — empty / loading / error / success / disabled / long-content
7. **Micro-interactions** — hover/press/focus feedback, meaningful transitions
8. **Perceived performance** — skeletons, optimistic UI, 60fps, zero layout shift
9. **Copy** — specific, active, brand-voice (defer register to `brand-system`)
10. **Anti-slop final gate** — `reference/critique-polish.md`, zero blockers/high

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Redesigning instead of elevating | Conform to the existing system first; change the least that achieves premium |
| Inventing new tokens/components mid-polish | Reuse the app's primitives; only add with explicit justification |
| Animating for decoration | Cut any motion that doesn't signal state or guide attention |
| "Looks good" without running it | Mandatory: see it running + pass the rubric before declaring done |
| Polishing only the happy path | Design empty/loading/error/overflow states too |
| Re-deriving brand palette/voice here | Defer to `brand-system`; this skill owns craft, not brand law |
| Chasing micro-perf the user can't feel | Optimize *perceived* speed; send real perf work to `capacitor` |
| **Auditing one theme** (dark only) | Every theme is a matrix axis. Hardcoded dark/white values look fine in one theme and break in the other — run the contrast sweep **per theme** (`sensors.md`) |
| **Auditing an empty account** | Seed realistic data first (Phase 0.5). Lists/cards/rows only exist with data — that's where defects hide |
| **Inferring quality without rendering** | A route you didn't see is not audited. Capture it (deployed URL if local auth blocks it) before calling it conformant |
| **Visual-only audit** (no sensors) | Eyes can't see a 3.9:1 ratio or a raw `#0c1014`. Run `sensors.md` *before* the rubric |
| **Changing code to have a diff** | "Already at the bar → no change" is a passing outcome. Elevation needs a cited gap, never churn |
| **Inventing a value** (radius / press-scale / shadow / easing / stagger) when a canonical one exists | Pull the constant from `reference/recipes.md`; deviate only with a cited app `design.md` token |
| **Identical radius on nested padded surfaces** | Concentric: `outer = inner + padding` — the #1 "feels off" tell (`recipes.md` §1, greppable via Sensor 8) |
| **"The brand font is set" without measuring it render** | `document.fonts.check()` and computed `fontFamily` are FALSE-POSITIVE traps — both pass on a silent fallback. Prove the font actually *renders* with the glyph-width test (`sensors.md` Sensor 9). Load via `next/font/local` (self-host), not a CDN `@import`/`<link>` that the build can drop |
