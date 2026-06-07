---
name: ui-elevate
description: Use when elevating already-coded UI to next-level quality — polishing existing screens, components, or flows so they look and feel premium while staying consistent with the app's own design language. Triggers on "polish this UI", "make this feel premium", "level up the design", "this looks like AI slop", "elevate this", "bring it up to standard", "tighten the visuals", "make it production-quality", "improve the feel". Covers appearance (hierarchy, type, spacing, depth, imagery), perceived performance (skeletons, optimistic UI, 60fps motion, no layout shift), and interaction feel (micro-interactions, states, gestures, haptics). Audits against an anti-slop rubric, then applies fixes (the subjective, taste layer). NOT for: objective accessibility/compliance audits (use web-design-guidelines), multi-model design ideation or exploring alternatives (use ui-brainstorm), React data/bundle perf internals (use react-best-practices), visual/CSS defects (use ui-debug), or greenfield generation from scratch.
---

# UI Elevate

**Purpose:** Take already-coded UI and raise it to next-level quality — bring it inline with the app's design language, then push appearance, feel, and perceived performance to a premium standard.
**Domain:** Frontend craft, UX/UI polish, anti-slop critique
**Status:** Complete

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

## When to Use This Skill

**Intent Triggers:**
- "Polish this screen / component / flow"
- "Make this feel premium / high-end / production-quality"
- "Level up the design", "elevate this", "next-level"
- "This looks like AI slop / generic / templated — fix it"
- "Bring this up to the standard of the rest of the app"
- "Tighten the visuals", "the spacing feels off", "it feels janky"

**When NOT to Use:**
- Building a brand-new UI from nothing → that's design/generation work, not elevation
- The bug is a *defect* (style not applying, broken layout) → use `ui-debug`
- The ask is purely brand palette/voice → use `brand-system`
- The ask is data-fetch waterfalls / bundle size / hydration internals → use `react-best-practices`
- The ask is a11y compliance mechanics (ARIA, focus traps, form semantics) → use `web-design-guidelines`

---

## Core workflow

The whole skill runs through one loop. **Read `workflows/audit-and-elevate.md`**
before starting — it is the operating procedure. In short:

```
0. BASELINE   Learn the app's design language (brand-system + app CORE +
              existing tokens/components). Establish the "house style."
1. INVENTORY  Pin down exactly what's in scope (which screens/components).
2. AUDIT      Score the target against the anti-slop rubric across appearance,
              feel, perceived perf, AND consistency-with-app.
3. ELEVATE    Apply fixes — highest impact / lowest risk first. Reuse existing
              tokens & primitives; don't invent new ones without justification.
4. RE-AUDIT   Loop until zero blocker/high findings remain.
5. VERIFY     See it running (run/verify skills); confirm no visual regressions.
```

**Non-negotiable:** never declare UI "elevated" on inspection alone. It must pass
the rubric in `reference/critique-polish.md` AND be seen running.

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
| React/Next perf internals (waterfalls, bundle, data fetching, memoization) | `react-best-practices` |
| Native bridge / cross-platform plumbing | `capacitor` |
| Want multiple independent design opinions / consensus critique | `ui-brainstorm` |
| A style genuinely *isn't applying* / layout is broken (a defect) | `ui-debug` |
| See it running / screenshot / confirm the change | `run`, `verify` |

This skill *orchestrates* — it calls these in, it doesn't duplicate their content.

---

## Supporting Documentation

| File | When to Read |
|------|--------------|
| `workflows/audit-and-elevate.md` | **Always** — the operating procedure |
| `reference/critique-polish.md` | At AUDIT — the anti-slop checklist + scoring rubric |
| `reference/visual-craft.md` | When elevating appearance: type, spacing, depth, imagery, layout |
| `reference/interaction-and-feel.md` | When elevating micro-interactions, states, motion, gestures, haptics |
| `reference/perceived-performance.md` | When the UI feels slow/janky despite being functionally fine |

---

## Quick Reference — the elevation passes

Run these as ordered sweeps over the target (detail in the reference files):

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
| Chasing micro-perf the user can't feel | Optimize *perceived* speed; send real perf work to `react-best-practices` |
