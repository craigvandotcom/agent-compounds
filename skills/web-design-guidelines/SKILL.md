---
name: web-design-guidelines
description: Use when auditing UI code for objective correctness and compliance during implementation or PR review — accessibility (ARIA, labels, keyboard, semantics, focus states), forms, motion-safety, typography mechanics, image dimensions, hydration safety, touch interactions. A binary best-practices checklist (mirrors vercel-labs/web-interface-guidelines). Triggers on "is this accessible", "a11y", "check this for best practices", "audit this form", "review this UI code", "WCAG", "fix UX issues". NOT for subjective premium polish or anti-slop (use ac-ui-polish), React performance (use capacitor), or multi-model design ideation (use ui-brainstorm).
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Web Design Guidelines

**Purpose:** Audit UI code against 100+ web interface best practices — the **objective, binary** compliance layer
**Source:** [vercel-labs/web-interface-guidelines](https://github.com/vercel-labs/web-interface-guidelines)
**Status:** Complete

This skill answers **"is it correct?"** (a checklist that passes or fails). For
**"is it premium?"** (subjective taste / anti-slop polish of working UI) use
`ac-ui-polish`. The two compose: `ac-ui-polish` runs this skill as its objective gate,
then adds the taste layer on top.

---

## When to Use This Skill

**Intent Triggers:**

- Reviewing UI code for best practices / PR review
- Checking accessibility compliance (ARIA, keyboard, semantics)
- Auditing form implementations
- Reviewing animations and transitions for motion-safety
- Fixing typography mechanics or content/overflow issues
- Improving touch interactions

**When NOT to Use:**

- Subjective premium polish / "make it feel high-end" → `ac-ui-polish`
- React performance (waterfalls, bundle, re-renders) → `capacitor`
- Multi-model design ideation / exploring options → `ui-brainstorm`
- Visual/CSS *defects* (style not applying, broken layout) → `ui-debug`
- Project-specific design tokens → the app's local `design-system`

---

## Quick Audit Checklist

Run through these categories when reviewing UI code. Load the matching reference
file for the detailed patterns + code examples.

- [ ] **Accessibility** — labels, ARIA, keyboard, semantics, heading order → `reference/accessibility-focus.md`
- [ ] **Focus States** — visible focus, focus-visible, focus-within → `reference/accessibility-focus.md`
- [ ] **Forms** — input types, autocomplete, never-block-paste, error placement, submit states → `reference/forms.md`
- [ ] **Animation** — reduced-motion, compositor-friendly (transform/opacity only), no `transition: all` → `reference/animation-typography.md`
- [ ] **Typography** — curly quotes, ellipsis char, tabular-nums, `&nbsp;`, text-balance → `reference/animation-typography.md`
- [ ] **Content** — truncation, line-clamp, `min-w-0` in flex, empty states → `reference/animation-typography.md`
- [ ] **Images** — explicit dimensions (CLS), lazy below-fold, priority above-fold → `reference/performance-images.md`
- [ ] **Performance** — virtualize >50 items, no layout thrashing, preconnect/preload → `reference/performance-images.md`
- [ ] **Navigation & State** — URL reflects state, links are `<a>`/`<Link>`, confirm/undo destructive → `reference/interaction-state.md`
- [ ] **Touch** — touch-action-manipulation, overscroll-contain, drag userSelect, autofocus discipline → `reference/interaction-state.md`
- [ ] **Hydration** — controlled/uncontrolled, guard date/time SSR mismatch → `reference/interaction-state.md`
- [ ] **Dark Mode** — color-scheme, theme-color meta, native select colors → `reference/theming-i18n.md`
- [ ] **i18n** — `Intl` APIs for dates/numbers/currency, detect via Accept-Language → `reference/theming-i18n.md`

---

## Anti-Patterns to Flag

| Pattern                                      | Issue                         |
| -------------------------------------------- | ----------------------------- |
| `user-scalable=no` or `maximum-scale=1`      | Disables zoom (accessibility) |
| `onPaste` with `preventDefault`              | Blocks password managers      |
| `transition: all`                            | Performance hit               |
| `outline-none` without focus replacement     | Removes focus visibility      |
| `<div onClick>` for navigation               | Breaks Cmd/Ctrl+click         |
| `<div onClick>` for actions                  | Should be `<button>`          |
| Images without dimensions                    | Layout shift                  |
| Large arrays `.map()` without virtualization | Performance                   |
| Form inputs without labels                   | Accessibility                 |
| Icon buttons without `aria-label`            | Accessibility                 |
| Hardcoded date/number formats                | i18n issues                   |
| `autoFocus` without justification            | Mobile UX                     |

---

## Content & Copy Guidelines

| Rule                            | Example                                           |
| ------------------------------- | ------------------------------------------------- |
| Active voice                    | "Install the CLI" not "The CLI will be installed" |
| Title Case for headings/buttons | "Save Changes" not "Save changes"                 |
| Numerals for counts             | "8 deployments" not "eight deployments"           |
| Specific button labels          | "Save API Key" not "Continue"                     |
| Error messages include fix      | "Invalid email. Please check the format."         |
| Second person                   | "Your settings" not "My settings"                 |
| `&` over "and" when constrained | "Terms & Conditions"                              |

(Brand *voice register* and banned phrases → `brand-system`.)

---

## Supporting Documentation

| File | When to Read |
|------|--------------|
| `reference/accessibility-focus.md` | A11y patterns, semantic HTML, heading order, focus states |
| `reference/forms.md` | Inputs, autocomplete, paste, labels, submission states, unsaved-changes |
| `reference/animation-typography.md` | Reduced-motion, compositor-friendly motion, typography mechanics, content overflow |
| `reference/performance-images.md` | Image dimensions/loading, virtualization, layout-thrash avoidance |
| `reference/interaction-state.md` | URL state, links, destructive actions, touch, drag, autofocus, hydration |
| `reference/theming-i18n.md` | Dark mode / color-scheme, native control styling, `Intl` locale formatting |
| [Full upstream guidelines](https://github.com/vercel-labs/web-interface-guidelines) | Complete rule reference (source of truth) |
| the app's local `design-system` skill | Project-specific tokens and touch patterns |
