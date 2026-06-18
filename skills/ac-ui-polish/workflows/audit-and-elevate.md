# Workflow: Audit & Elevate

The operating procedure for `ac-ui-polish`. Input is **existing, working UI**.
Output is the same UI brought inline with the app and pushed to premium quality,
proven against the rubric and seen running.

> Two axes, in order: **(1) bring inline** with the app's design language, then
> **(2) elevate** to premium. Never elevate before you've conformed.

---

## Phase 0 — Establish the baseline (the "house style")

You cannot make something "consistent with the app" until you know the app. Do
not skip this even under time pressure — it is what separates polish from a
rogue redesign.

Gather, in this order:
1. **Brand law** → invoke `brand-system` for this app's pillar color, voice
   register, and banned phrases. This is non-negotiable law, not preference.
2. **App design facts** → read this app's `.claude/skills/CORE/SKILL.md` (and its
   `AGENTS.md` index) and any local `design-system` skill. Capture: design tokens,
   spacing scale, type ramp, radii, shadow/elevation system, motion durations.
3. **Existing primitives** → grep the codebase for the component library in use
   (e.g. shared `components/ui/*`, Tailwind config `theme.extend`, CSS variables).
   Note the patterns already in production — buttons, cards, inputs, modals.

Write a short **house-style note** (a few bullets): the scale, the type ramp, the
elevation logic, the motion vocabulary, the pillar. This is your conformance
target for Phase 3.

---

## Phase 1 — Inventory the target

Pin the scope precisely. Vague scope ("polish the app") produces shallow work.
- Which exact screens / components / flows are in scope?
- What are their **states**? (default, empty, loading, error, success, disabled,
  long-content/overflow, offline). List them — most slop hides in unhandled states.
- What real data will flow through? (Not lorem — realistic worst cases: long
  names, missing avatars, huge numbers, zero items.)

---

## Phase 2 — Audit (score, don't vibe)

Run `reference/critique-polish.md` across the target. Score every finding by
severity (**blocker / high / medium / low**) and tag its axis:

- **Consistency** — deviates from the house style (wrong scale, ad-hoc color,
  one-off component, off-pillar). *Consistency breaks are at least `high`.*
- **Appearance** — `reference/visual-craft.md` (type, spacing, depth, imagery, layout)
- **Feel** — `reference/interaction-and-feel.md` (states, micro-interactions, motion, gestures)
- **Perceived performance** — `reference/perceived-performance.md` (skeletons, optimistic UI, 60fps, layout shift)

Produce a findings table: `severity | axis | location (file:line) | issue | fix`.
If you want independent perspectives on subjective calls, fan out via
`ui-brainstorm` and reconcile.

---

## Phase 3 — Elevate (apply fixes)

Order: **highest impact / lowest risk first.** Conformance fixes (Phase 0
violations) come before net-new flourishes.

Rules of engagement:
- **Reuse the app's tokens and primitives.** Do not introduce a new spacing value,
  shadow, color, or component when an existing one fits. New primitives require an
  explicit, stated justification (and ideally belong in the design-system, not here).
- **Change the least that achieves premium.** Elevation is surgical, not a rewrite.
- **One axis at a time** per component when practical — easier to verify, easier to revert.
- For brand-voice copy edits, stay within `brand-system`'s register and banned list.
- Defer real perf work (bundle, data fetch) to `react-best-practices`; here you
  only fix *perceived* speed.

---

## Phase 4 — Re-audit (loop to clean)

Re-run `reference/critique-polish.md` on the changed UI. **Pass = zero `blocker`
and zero `high` findings.** Mediums/lows are logged with a recommendation; ship or
defer per the user. If a fix introduced a new finding, loop back to Phase 3.

---

## Phase 5 — Verify (see it, don't assume it)

- See it **running** — use the `run` skill (or `verify`) to launch the app and
  view the actual rendered result, including the non-happy states from Phase 1.
- If anything renders wrong (style not applying, layout broken), that's a defect →
  hand to `ui-debug`, fix, return here.
- Check responsive breakpoints and, for Capacitor builds, native concerns (safe
  areas, momentum scroll, touch targets) per `reference/interaction-and-feel.md`.
- Confirm **no regressions** elsewhere — elevation must not break sibling screens
  that share the touched primitives.

Only after a clean re-audit **and** a real running view do you report the work as
elevated. State what changed and what the before/after rubric scores were.
