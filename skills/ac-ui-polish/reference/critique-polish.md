# Reference: Critique & Polish — the anti-slop gate

The scoring rubric and checklist used at the AUDIT and RE-AUDIT phases. Derived
from Meng To-style frontend critique and hardened for cross-platform (web +
Capacitor) work. **A target is not "elevated" until it passes this gate.**

## Severity & pass condition

| Severity | Meaning |
|----------|---------|
| **Blocker** | Looks broken, off-brand, or unmistakably AI-generated. Ships embarrassment. |
| **High** | Clearly sub-premium or inconsistent with the app. A discerning user notices. |
| **Medium** | Polish gap. Noticeable on close inspection. |
| **Low** | Nitpick / nice-to-have. |

**Pass = zero Blocker AND zero High.** Mediums/lows are logged with a fix
recommendation and shipped or deferred per the user.

---

## The checklist

Score each item. Cite `file:line` and a concrete fix.

> **Objective vs. subjective.** Sections A–E and the AI-tell sweep are this skill's
> own taste layer. The mechanical items in **F (states/a11y)** and **G (perceived
> perf)** are authoritatively covered by `web-design-guidelines` (compliance) and
> `react-best-practices` (perf engineering) — run those for the binary pass/fail,
> and use this rubric to judge whether the *felt* result is premium. Don't
> re-derive their rules here; cite them.

### A. Consistency with the app (any deviation is ≥ High)
- [ ] Uses the app's spacing scale (no ad-hoc `13px`, `27px` values)
- [ ] Uses existing type ramp, radii, shadow/elevation tokens
- [ ] Uses existing component primitives, not one-off reinventions
- [ ] Color stays within the brand pillar + neutrals (per `brand-system`)
- [ ] Motion matches the app's existing durations/easing vocabulary

### B. Typography (the #1 slop tell)
- [ ] Clear hierarchy — distinct, intentional sizes; not 3 near-identical sizes
- [ ] Line-height tuned to size (tighter for headings, ~1.5 for body)
- [ ] Line length (measure) ~45–75ch for body text, not full-bleed paragraphs
- [ ] Letter-spacing: slightly negative on large headings, normal/positive on
      small caps/labels — not default everywhere
- [ ] Weight contrast carries hierarchy; not everything semibold or everything regular
- [ ] No orphans/widows in headings; no awkward wrapping of key phrases
- [ ] Numerals/tabular figures used where columns of numbers align

### C. Spacing, layout & alignment
- [ ] Consistent rhythm from a single scale; related items grouped by proximity
- [ ] Optical alignment (icons/text visually centered, not just box-centered)
- [ ] Not everything centered — deliberate left-alignment for scannable content
- [ ] Generous, intentional whitespace; not cramped, not aimlessly sparse
- [ ] Grid/columns align across sections; no 1–2px misalignments
- [ ] Density appropriate to the surface (dashboard ≠ marketing hero)

### D. Depth, color & surface
- [ ] Elevation is logical and consistent (shadows imply a real light source)
- [ ] Shadows soft and realistic, not harsh default `box-shadow`
- [ ] Restrained color — accent used with intent, not rainbow
- [ ] No default-template gradient (the purple/blue 45° AI-default look)
- [ ] Borders/dividers subtle (low-contrast hairlines), not heavy black lines
- [ ] Sufficient contrast for text (defer the math to `web-design-guidelines`)

### E. Imagery & iconography
- [ ] Real / owned imagery over generic stock or obviously-AI images
- [ ] No mismatched art styles mixed in one view
- [ ] Single icon family at a consistent weight/size; no mixed sets
- [ ] Icons carry meaning, optically aligned with their labels
- [ ] Images have correct aspect ratios; no squish/stretch/blurry upscaling

### F. Interaction & states (see `interaction-and-feel.md`)
- [ ] Interactive elements have hover/press/focus feedback
- [ ] Empty, loading, error, success states all designed (not just happy path)
- [ ] Transitions explain state changes; nothing pops in/out abruptly
- [ ] Touch targets ≥ 44×44px; adequate spacing between tap targets
- [ ] Disabled states clearly distinct; destructive actions clearly marked

### G. Perceived performance (see `perceived-performance.md`)
- [ ] Skeletons/placeholders instead of bare spinners on content load
- [ ] Optimistic UI for user actions; feedback < 100ms
- [ ] Animations run at 60fps (transform/opacity only)
- [ ] No layout shift (CLS): space reserved for async content & media
- [ ] Long lists virtualized; images lazy-loaded with reserved space

### H. Copy (defer voice register to `brand-system`)
- [ ] Specific over generic ("Save 3 hours a week" not "Boost productivity")
- [ ] Active voice; short; scannable
- [ ] No lorem ipsum, no hedge-y filler, no em-dash-soup AI cadence
- [ ] Microcopy on buttons/errors/empties is helpful and human
- [ ] No banned phrases (per `brand-system`)

### I. The AI-tell sweep (any hit is ≥ High)
- [ ] Not everything centered with a gradient hero
- [ ] No emoji used as bullet points / section markers
- [ ] Cards aren't all identical cookie-cutter tiles in a uniform grid
- [ ] No default component-library look shipped untouched
- [ ] No three-feature-card row with generic icons and vague headers
- [ ] Spacing/sizing isn't suspiciously uniform-everywhere (real design has rhythm & contrast)

---

## Self-audit prompt template

Use this to run the gate in one shot (yourself or via `ui-brainstorm`):

```
Audit this UI against ac-ui-polish/reference/critique-polish.md.
Context — house style: <paste Phase-0 house-style note + brand pillar>.
For every issue: severity (blocker/high/medium/low), axis (consistency/
appearance/feel/perf/copy/ai-tell), location (file:line), and a concrete fix.
Be ruthless — assume Meng To is reviewing. Only approve when zero blocker
and zero high findings remain. End with the score and a pass/fail verdict.
```
