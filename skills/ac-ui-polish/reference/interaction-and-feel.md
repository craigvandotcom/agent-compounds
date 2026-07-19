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
- **Active / pressed** — immediate visual response (press-scale `0.96`, never below
  `0.95`; darken) → **`recipes.md` §4** (use the app's press-scale token if defined)
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
- **Duration (App surfaces — default):** UI micro-transitions 150–250ms; larger transitions
  250–400ms. Too slow feels sluggish; instant feels broken. Use the app's duration tokens. An
  in-app "hero" (onboarding/splash) is still an app surface — keep the 250–400ms ceiling and a
  ~100ms group stagger; the longer marketing bands in the register below are for public
  marketing pages ONLY, never inside `/app`.
- **Easing:** ease-out for entrances (fast→settle), ease-in for exits, standard/
  ease-in-out for moves. Avoid linear for UI (feels robotic). Springs for playful,
  physical interactions (keep `bounce: 0` unless the surface is genuinely playful).
- **Interruptible by default.** Interactive state changes (hover, toggle, open/close)
  use **CSS transitions** — they retarget mid-flight so a reversed intent stays
  smooth. Reserve **keyframes** for one-shot sequences (enter, loading); a keyframe on
  an interactive element snaps/restarts and feels broken → **`recipes.md` §8**.
- **Choreograph, don't cascade chaos.** Split enters into semantic chunks and stagger
  (~100ms groups, ~80ms words) with `opacity+translateY+blur`; **exits are softer and
  shorter** than enters (small fixed `translateY`, ~150ms). Don't animate everything
  at once or with conflicting curves → **`recipes.md` §5**. Icon swaps (play↔pause,
  like↔liked) cross-fade with scale+blur, not a visibility toggle → **§6**.
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
  to prevent mis-taps. When the *visible* control is smaller (a 20px checkbox/icon),
  **expand the hit area with a pseudo-element**, not the visual — and never let two
  targets' hit areas overlap → **`recipes.md` §12**.
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

---

## Marketing-surface motion register (site/marketing pages ONLY — never inside /app)

Marketing pages (the public Vercel web build; `ac-site-polish`'s surface) get a wider, more
cinematic motion vocabulary than the app: desktop hover is a primary affordance, and reveals
can run longer because there is no native-perf budget or 60fps-under-gesture constraint. This
register applies to those surfaces alone — inside `/app` the App-surface defaults above hold.

> **Precedence:** on any conflict, the surface's own `CORE/design.site.md` (or an existing
> project recipe) wins over this register — these are defaults for a marketing page that has
> not specified its own, not overrides.

> Distilled from [MengTo/Skills](https://github.com/MengTo/Skills) (MIT) — `animation-systems`,
> `marquee-loop`, and the scroll-reveal skills — rewritten in our vocabulary.

**Duration bands** (every band carries its scope tag):
- micro / hover-press (marketing): 120–200ms
- UI state change — toggle/select (marketing): 180–260ms
- section entrance (marketing): 400–800ms
- hero sequence (marketing only): 800–1600ms, with internal beats

**Stagger:** 40–90ms per element (text lines / cards); smaller on mobile.

**Easing:** ease-out for entrances (fast→settle), ease-in for exits (faster); reuse a small
set (the library's `power3.out` / `expo.out` family). No elastic/bounce unless the brand is
genuinely playful. Linear only for continuous loops (marquee, scrub).

**Primitives:** *fade + rise* (opacity 0→1, Y 12–24px→0) is the default entrance;
*scale + fade* (0.98→1) for popovers/toasts/selected states. Transform + opacity only.

**Scroll-reveal taxonomy** — ONE reveal concept, two implementations (pick by stack):
- *mask-based* (GSAP variant): words rise through an `overflow:hidden` mask
  (`yPercent 110→0`), trigger `top 82%`, `once: true`, stagger by word — premium editorial feel.
- *opacity-based* (no-lib variant): IntersectionObserver (`threshold 0.2`,
  `rootMargin -10%`) toggles a class; `opacity + translateY + blur` transition, reveal once.
Both keep no-JS content visible and expose the full text to screen readers via `aria-label`.

**Marquee (logo/testimonial strips):** duplicate the sequence, translate 0→-50% linear, fade
the edges with a mask, pause-on-hover only when reading matters; never marquee content the user
must read carefully.

**Perf rules (non-negotiable):** animate `transform` / `opacity` (and short-lived
`clip-path`) only — never layout props; drive scroll effects off IntersectionObserver, not raw
scroll listeners; clamp device-pixel-ratio (1–2) in any heavy canvas; `filter: blur()` on text
/ small elements only.

**Still governed by the app-wide rules above:** motion is **interruptible by default** (CSS
transitions retarget mid-flight; reserve keyframes for one-shot enters) and **respects
`prefers-reduced-motion`** — keep content visible, replace motion with an instant/opacity state,
disable scroll-scrub and pinning.
