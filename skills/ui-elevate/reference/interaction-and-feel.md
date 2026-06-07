# Reference: Interaction & Feel

The feel axis — micro-interactions, state design, motion, gestures, and haptics.
This is what makes a UI feel *alive* and considered rather than static and
templated. Cross-platform: web + Capacitor (iOS/Android) builds.

> **Delegation — don't re-audit mechanics here.** Objective compliance (focus
> rings, ARIA, `prefers-reduced-motion`, touch-target *minimums*,
> compositor-friendly props) is the authoritative job of `web-design-guidelines`.
> Capacitor safe-area / haptics / gesture *plumbing* lives in `capacitor`. This
> file is the subjective *feel* layer that sits on top of those — assume they pass.

---

## State design (most slop hides in unhandled states)

Every interactive surface needs all of its states designed, not just the default:

- **Default / rest** — the baseline
- **Hover** (pointer devices) — subtle elevation, tint, or cursor affordance
- **Focus** — visible, on-brand focus ring (never `outline: none` with no
  replacement; a11y mechanics → `web-design-guidelines`)
- **Active / pressed** — immediate visual response (scale down ~0.97, darken)
- **Disabled** — clearly distinct, reduced affordance, no hover/press response
- **Loading** — inline spinner/skeleton on the element acting (not a full-page block)
- **Empty** — designed empty states with guidance + a primary action, not blank space
- **Error** — specific, recoverable messaging near the cause
- **Success** — confirmation feedback (checkmark, toast, state change)
- **Long-content / overflow** — truncation, wrapping, or scroll handled gracefully

A screen that only handles the happy path with perfect data is unfinished.

## Micro-interactions

- **Feedback on every action within 100ms.** Press states, ripples, subtle scale,
  or color shift confirm the tap registered — even before the result arrives.
- **Transitions explain change.** When something appears, moves, or updates, animate
  the transition so the user tracks what happened. No abrupt pop-in/pop-out.
- **Hover is enrichment, not requirement.** Touch devices have no hover — never hide
  essential affordance behind it.
- **Delight sparingly.** A considered spring on a primary action is premium; the
  same flourish on everything is noise.

## Motion & choreography

- **Meaning or cut.** Every animation either signals a state change or directs
  attention. Decoration-only motion gets removed.
- **Duration:** UI micro-transitions 150–250ms; larger transitions 250–400ms.
  Too slow feels sluggish; instant feels broken. Use the app's duration tokens.
- **Easing:** ease-out for entrances (fast→settle), ease-in for exits, standard/
  ease-in-out for moves. Avoid linear for UI (feels robotic). Springs for playful,
  physical interactions.
- **Choreograph, don't cascade chaos.** Stagger related elements subtly; don't
  animate everything at once or with conflicting curves.
- **Respect `prefers-reduced-motion`** — provide a calm fallback.
- **Animate the cheap properties** (`transform`, `opacity`) — see
  `perceived-performance.md`. Animating layout properties causes jank.

## Gestures (mobile / Capacitor)

- **Honor platform conventions:** swipe-back (iOS edge), pull-to-refresh, swipe
  actions on list rows, long-press for context. Don't fight OS gestures.
- **Momentum & overscroll:** native-feeling inertial scroll; bounce on iOS, glow on
  Android where appropriate. Avoid hijacking scroll.
- **Drag/swipe affordances** should be discoverable (peek, handle, hint).
- **Gesture conflicts:** ensure custom gestures don't block system navigation gestures.

## Touch & ergonomics

- **Touch targets ≥ 44×44px** (iOS HIG) / ~48dp (Android); spacing between targets
  to prevent mis-taps.
- **Thumb reachability:** primary actions within comfortable thumb zones on mobile;
  avoid critical actions in hard-to-reach top corners.
- **Safe areas:** respect notches, dynamic island, home indicator, and status bar
  via safe-area insets. Content must not sit under system UI.

## Haptics (Capacitor)

- Use the Capacitor **Haptics** plugin to reinforce key moments: light impact on
  selection/toggle, success/warning/error notification haptics on outcomes, medium
  impact on significant actions.
- **Restraint:** haptics on everything desensitizes. Reserve for meaningful
  confirmation. Always degrade gracefully where unsupported (web).

## Scroll & navigation feel

- **Scroll-linked effects** (sticky headers shrinking, parallax) must stay at 60fps
  and never block scrolling — drive them off `transform`, throttle work.
- **Navigation transitions** orient the user (push/pop direction, shared-element
  where it adds clarity). Instant hard-cuts between screens feel cheap on mobile.
- **Preserve scroll position** on back-navigation; don't reset to top unexpectedly.
