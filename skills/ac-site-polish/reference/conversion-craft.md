# Reference: Conversion Craft (marketing-site audit + elevation)

The marketing layer `ac-ui-polish` lacks: conversion structure, copy hierarchy, and pricing
clarity — the axes that decide whether a *correct-looking* page actually converts.

> **AUDIT + ELEVATE only — this skill never GENERATES pages.** ac-site-polish takes
> already-coded marketing pages and (1) checks conformance, then (2) elevates the least that
> reaches premium. So this file is a **presence rubric + elevation vocabulary**, not a build
> workflow. The upstream generation scaffolding — the intake questionnaire ("gather if
> missing…"), the from-scratch section-writing workflow, and the output-format templates — is
> **deliberately NOT distilled**; importing it would push polish into redesign (the skill's
> cardinal "never drifts into redesign" rule).

> Distilled from [MengTo/Skills](https://github.com/MengTo/Skills) (MIT) — `landing-page`,
> `pricing-page` — rewritten in our vocabulary; the structural rules carry, the prose does not.

---

## 1. Landing-structure presence rubric (audit axis)

A high-conversion page wins **one intent: one offer → one audience → one primary action**.
Audit for the presence AND placement of each element — a missing or misplaced element is a
conversion defect; file it like any other. Do NOT rewrite the page to add missing pieces —
flag the gap.

**Above the fold**
- **Hero promise** — headline states the outcome + who it's for; readable in <5s.
- **Subheadline** — clarifies the "how" + adds specificity (1–2 sentences).
- **Primary CTA** — exactly one, visually dominant, verb + what they get.
- **One proof signal** — logo strip / stat / short testimonial near the promise.

**Mid page (the argument)**
- **Problem → solution** — one section naming the pain before the fix.
- **Outcome benefits** — 3–5, each led by the *benefit*, not the feature.
- **How it works** — ~3 steps.
- **Social proof placed near the ask** — testimonials/case study adjacent to the claim they
  support, never only in the footer.

**Bottom (objection handling)**
- **FAQ** — the objection section, not a footer afterthought; pull it earlier for
  high-friction offers.
- **Risk reversal** — at least one: free trial, free plan, no-card, cancel-anytime, guarantee.
- **Final CTA** — same offer + verb as the hero.

## 2. Copy elevation vocabulary

When elevating (a cited gap exists), reach for these — never a rewrite for its own sake:

- **Headline formulas** (elevation vocabulary, not mandatory templates): "{Outcome} without
  {pain}" · "The {category} for {audience}" · "Ship {result} in {time}".
- **Specificity over vagueness** — replace "save time / streamline / optimize" with a
  concrete, measurable claim ("cut weekly reporting from 4 hours to 15 minutes"). A vague
  value-prop is the single most common conversion tell.
- **CTA-verb consistency** — every CTA across the page uses ONE verb family; never mix "Get
  started" / "Try now" / "Sign up" on the same page. Avoid weak CTAs ("Learn more", "Submit").
- **Outcome bullets** — write feature bullets as outcomes: ❌ "Unlimited projects" →
  ✅ "Ship unlimited client sites without extra fees". Format: **Benefit** — proof/detail.

(Voice, register, and banned phrases defer to `brand-system` — this file is structure only.)

## 3. Pricing "reduce uncertainty" checklist (audit axis)

A pricing page's job is not to *show prices* — it is to **reduce uncertainty**. Audit for:

- **Monthly/annual toggle** with an explicit "Save X%" callout on annual.
- **3–6 plans max** — analysis paralysis past that; one plan marked *Recommended* (subtly).
- **3–6 key limits + 3–6 included items visible** per plan — not a spreadsheet dump.
- **Consistent CTA verb** under every plan (see §2).
- **Outcome-phrased bullets** (see §2) — grouped Core / Collaboration / Admin / Support when a
  comparison matrix is genuinely needed.
- **Mobile: stacked cards**, never a horizontal-scroll table.
- **FAQ handles the buy-objections** — cancel, limits, discounts, who-it's-for, security.

## 4. Section-by-section elevation discipline

Elevate **one section at a time**, in reading order (hero → benefits → how → proof → FAQ →
final CTA) — never rebuild the whole page for one gap. This mirrors ac-site-polish's Phase-4
Elevation ledger: change a surface only with a cited gap; "no change = already at the bar" is a
passing outcome. Gains plateau after ~3 elevation cycles per section — stop there.

For the motion that carries these surfaces (hero/section reveals, marquee proof strips), the
numeric bands + easing live in the **Marketing-surface motion register** in
`../ac-ui-polish/reference/interaction-and-feel.md` — this file stays copy/structure only.
