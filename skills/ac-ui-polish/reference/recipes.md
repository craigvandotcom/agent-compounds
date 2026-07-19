# Reference: Recipes — canonical, paste-able values

The other reference files say *what* to elevate toward (principles for a taste
judge). This file says *what to write* (constants for a code author). It exists
because the gap between "fine" and "premium" is often a specific number — and an
agent that has to invent that number mid-elevation reintroduces the mediocrity we
came to remove. These are the numbers.

> **Token-override rule (read first).** Where the app's `CORE/design.md` defines a
> token for one of these — a radius scale, a motion duration/easing, a shadow
> elevation, a press-scale — **the token wins**. Consistency beats a generic
> constant (manifesto #1). The values below are the **fallback** for when the spec
> is silent, and the **default** a new token should usually adopt. Never let a
> recipe here introduce a value that fights the app's existing scale.

> **Framework conditionals.** Motion/Framer snippets apply **only if** `motion` or
> `framer-motion` is already in `package.json`. Never add a motion dependency for
> these — every recipe has a dependency-free CSS form. Check first.

---

## 1. Concentric border radius

When rounded elements nest, the outer radius must equal the inner radius plus the
padding between them — or the corners visibly drift and the whole component reads
as "off." This is the single most common cause of that feeling.

```
outerRadius = innerRadius + padding
```

```tsx
// Good — outer accounts for padding
<div className="rounded-2xl p-2">     {/* 16px radius, 8px padding */}
  <div className="rounded-lg">…</div> {/* 8px = 16 − 8 ✓ */}
</div>

// Bad — same radius on both → corners drift
<div className="rounded-xl p-2"><div className="rounded-xl">…</div></div>
```

- Most useful when layers sit **close** together. If padding > ~24px, treat them
  as separate surfaces and choose each radius independently — don't force the math.
- Map the result onto the app's radius token scale; don't invent an off-scale value
  to satisfy the formula. If the scale can't express it, the padding is the thing
  to adjust.

## 2. Shadow-as-border (depth without a hard line)

For buttons / cards / containers that use a border for *elevation* (not layout
separation), a layered transparent `box-shadow` reads premium and adapts to any
background; a solid border doesn't. **Do not** apply to dividers / hairline
separators / input outlines — those stay borders.

```css
/* Light — layer 1 = 1px ring, layer 2 = lift, layer 3 = ambient */
--shadow-border:
  0 0 0 1px rgba(0,0,0,.06),
  0 1px 2px -1px rgba(0,0,0,.06),
  0 2px 4px 0 rgba(0,0,0,.04);
--shadow-border-hover:
  0 0 0 1px rgba(0,0,0,.08),
  0 1px 2px -1px rgba(0,0,0,.08),
  0 2px 4px 0 rgba(0,0,0,.06);

/* Dark — collapse to a single white ring; depth layers are invisible on dark */
--shadow-border:       0 0 0 1px rgba(255,255,255,.08);
--shadow-border-hover: 0 0 0 1px rgba(255,255,255,.13);
```

```css
.card { box-shadow: var(--shadow-border);
  transition: box-shadow 150ms ease-out; }
.card:hover { box-shadow: var(--shadow-border-hover); }
```

Light-direction stays consistent across the screen (visual-craft → Depth). Higher
elements get softer/larger/lower-opacity shadows.

## 3. Image outline

A `1px` low-opacity outline gives images consistent depth alongside bordered/shadowed
peers. **Colour rule is non-negotiable: pure black or pure white, never tinted.**

```tsx
<img className="outline outline-1 -outline-offset-1 outline-black/10 dark:outline-white/10" … />
```

- Light: `rgba(0,0,0,.10)`. Dark: `rgba(255,255,255,.10)`. Exactly those.
- **Never** a near-neutral from the palette (`outline-slate-*`, `outline-zinc-*`,
  `#0a0a0a`, `#111827`) and **never** the accent/ink colour. A tinted outline picks
  up the surface beneath it and reads as **dirt on the image edge**.
- `outline` (not `border`) + `outline-offset: -1px` keeps it inset so it adds zero
  layout size.

## 4. Scale on press

A subtle scale-down on press is tactile feedback. **Default `0.96`; never below
`0.95`** (anything smaller feels exaggerated). Use a *transition* so a mid-press
release reverses smoothly. If the app defines a press-scale token, use it.

```tsx
// CSS / Tailwind — note: only the scale transitions, not `all`
<button className="transition-transform duration-150 ease-out active:scale-[0.96]">

// Motion (only if installed)
<motion.button whileTap={{ scale: 0.96 }} />
```

Not every button wants it — give the shared Button a `static` prop that drops the
class where motion would distract (form-submit, destructive confirm).

## 5. Enter / exit animations (split, stagger, asymmetric)

Don't animate one big container. Split into semantic chunks (title / body /
actions), stagger, and combine `opacity + translateY + blur`.

```tsx
// Motion (only if installed) — staggered enter
<motion.div initial="hidden" animate="visible"
  variants={{ visible: { transition: { staggerChildren: 0.1 } } }}>
  {/* each child: */}
  variants={{ hidden:{opacity:0,y:12,filter:"blur(4px)"},
              visible:{opacity:1,y:0,filter:"blur(0px)"} }}
</motion.div>
```

```css
/* CSS-only stagger */
.stagger-item { opacity:0; transform:translateY(12px); filter:blur(4px);
  animation: fadeInUp 400ms ease-out forwards; }
.stagger-item:nth-child(1){animation-delay:0ms}
.stagger-item:nth-child(2){animation-delay:100ms}
.stagger-item:nth-child(3){animation-delay:200ms}
@keyframes fadeInUp { to { opacity:1; transform:translateY(0); filter:blur(0) } }
```

- **Groups** stagger ~`100ms`; **title words** (if split) ~`80ms`.
- **Exits are softer than enters**: small fixed `translateY(-12px)` (not full
  height), and **shorter** (~`150ms` exit vs ~`300–400ms` enter) — the user's focus
  is already moving on. Don't remove the exit entirely (it preserves spatial context).
- **Skip on page load:** `AnimatePresence initial={false}` stops default-state
  elements (icon swaps, tabs, toggles) animating in on first render. **Don't** use
  it where a component relies on `initial` for a real first-paint entrance (page
  hero, loading) — it would skip the entrance. Verify on a hard refresh.

## 6. Contextual icon swap (play↔pause, like↔liked)

Animate swaps with `opacity + scale + blur`, not a visibility toggle. **Use exactly
these values** (they're tuned; deviating looks wrong):

- `scale` `0.25 → 1` · `opacity` `0 → 1` · `filter` `blur(4px) → blur(0)`
- Motion transition: `{ type:"spring", duration:0.3, bounce:0 }` — **bounce is
  always `0`.**

```tsx
// Motion (only if installed)
<AnimatePresence initial={false} mode="popLayout">
  <motion.span key={active ? "on" : "off"}
    initial={{opacity:0,scale:0.25,filter:"blur(4px)"}}
    animate={{opacity:1,scale:1,filter:"blur(0px)"}}
    exit={{opacity:0,scale:0.25,filter:"blur(4px)"}}
    transition={{type:"spring",duration:0.3,bounce:0}}><Icon/></motion.span>
</AnimatePresence>
```

No motion lib? Keep **both** icons mounted (one `absolute`), cross-fade with CSS
`transition-[opacity,filter,scale] duration-300` and easing `cubic-bezier(0.2,0,0,1)`
— both enter *and* exit animate because neither unmounts.

## 7. Optical alignment heuristics

Geometric centring often looks wrong; correct by eye, with these rules of thumb:

- **Text+icon button:** icon-side padding = text-side − `2px` (e.g. `pl-4 pr-3.5`).
- **Play triangle:** `margin-left: 2px` — its visual centre sits right of its box.
- **Asymmetric icons (star/arrow/caret):** fix the **SVG/viewBox** first so no
  component-level margin is needed; `ml-px` only as a fallback.

## 8. Interruptible motion — transition vs keyframe

| | CSS transition | CSS keyframe |
|---|---|---|
| Interruptible | **Yes** — retargets mid-flight | No — restarts from frame 0 |
| Use for | interactive state (hover, toggle, open/close) | one-shot sequences (enter, loading) |

A drawer driven by `transition: transform 200ms` reverses smoothly when re-clicked
mid-slide; the same drawer on a keyframe `animation` snaps/restarts and feels
broken. **Interactive → transition. One-shot → keyframe.**

## 9. Transition specificity — never `transition: all`

Name the properties. `transition: all` (and Tailwind's bare `transition`) forces
the browser to watch everything and fires unintended transitions on colour/padding/
shadow when they change.

```tsx
// Good
<button className="transition-[scale,opacity] duration-150 ease-out">
// Bad
<button className="transition duration-150">      {/* = transition-property: all */}
```

Note: Tailwind `transition-transform` = `transform, translate, scale, rotate` (fine
when you only animate transforms). For mixed non-transform props use the bracket form.

## 10. `will-change` — sparingly, compositor-only

Pre-promotes an element to its own GPU layer, avoiding a first-frame stutter when it
starts animating. Only worth it for **compositable** properties, and only when you
actually observe stutter (Safari benefits most). Each layer costs memory — never
blanket it.

| Property | Composite? | `will-change`? |
|---|---|---|
| `transform` / `opacity` / `filter` / `clip-path` | yes | yes |
| `top/left/width/height` / `background/border/color` | no | no |

`will-change: all` is always wrong.

## 11. Typography micro-rules

- **Font smoothing (macOS):** `-webkit-font-smoothing: antialiased; -moz-osx-font-smoothing:
  grayscale;` **once at the root** (`<html className="antialiased">`). macOS renders
  text heavier by default; other platforms ignore it, so it's safe universally.
- **Tabular numerals:** `font-variant-numeric: tabular-nums` (`className="tabular-nums"`)
  on **dynamically updating** numbers — counters, timers, prices, scoreboards, table
  columns — to kill width jitter / layout shift. Not for static or decorative
  numbers, phone numbers, version strings. *(Inter caveat: `1` widens/centres — that's
  expected and desirable for alignment; eyeball it.)*
- **`text-wrap: balance`** on headings (`text-balance`) — but it's **silently ignored
  past ~6 lines** (Chromium) / ~10 (Firefox); it's for short text only.
  **`text-wrap: pretty`** (`text-pretty`) is the default for short-to-medium body —
  kills last-line orphans at any length. **Long text (10+ lines): neither.**
- **Load the app font via `next/font/local`** (self-hosted woff2), not a CDN
  `@import`/`<link>`: a second bare `@import` is silently dropped from the compiled
  bundle, an App-Router `<head>` `<link>` isn't reliably emitted, and a CDN fails
  offline in a Capacitor shell. Expose it as a CSS var, set it as the Tailwind `sans`
  family, and **verify it actually renders** with the glyph-width test (`sensors.md`
  Sensor 9) — never trust `fonts.check()` / computed `fontFamily` (both pass on a
  fallback).

## 12. Minimum hit area

Interactive targets ≥ `40×40px` (`44×44` is the WCAG/HIG comfort target). When the
*visible* control is smaller, expand the **hit area** with a pseudo-element — don't
inflate the visual.

```tsx
<button className="relative size-5
  after:absolute after:top-1/2 after:left-1/2 after:size-10 after:-translate-1/2">
  <CheckIcon/>
</button>
```

**Collision rule:** two interactive elements must never have overlapping hit areas —
if the expansion would collide, shrink it to the largest size that doesn't.

> **§§13–15 are distilled from [MengTo/Skills](https://github.com/MengTo/Skills)
> (MIT)** — `glass-dark-ui`, `beautiful-shadows`, `progressive-blur` — rewritten in
> our vocabulary and brand-filtered (neutral shadows, no purple/blue gradient tint).
> This file is consumed by **light-mode** apps, so theme-sensitive recipes ship a
> light form inline (token-override rule still applies — the app's `design.md` wins).

## 13. Glass surface (frosted panel)

A frosted, semi-transparent panel over a busy or image background — the premium
alternative to a flat card on a hero. **Only worth it when there is real content
*behind* the panel to blur:** `backdrop-filter` blurs what sits behind it, so over a
flat fill it costs GPU and shows nothing. Always ship the non-blur fallback (a
stronger solid fill) so it degrades cleanly.

> **Surface caveat.** A glass hover/focus glow is a **web/marketing** affordance —
> there is no `:hover` inside a native `/app` shell, so use press/active feedback
> (§4) there instead. Keep glow radius restrained: readability first.

**Dark surface** — the fill is a **deep navy/charcoal alpha, never a pure-black
overlay over blur** (`rgba(0,0,0,…)` over a blur reads muddy — tint it):

```css
.glass-dark {
  background-color: rgba(15, 23, 42, 0.45);            /* slate-900 @ 45% — NOT black */
  background-image: linear-gradient(180deg, rgba(255,255,255,.08), rgba(255,255,255,.02));
  backdrop-filter: blur(18px) saturate(140%);
  -webkit-backdrop-filter: blur(18px) saturate(140%);
  border-radius: 24px;
  box-shadow: 0 20px 48px rgba(2,6,23,.45), inset 0 1px 0 rgba(255,255,255,.12);
}
/* Non-blur fallback: stronger opaque fill so text stays readable */
@supports not (backdrop-filter: blur(1px)) { .glass-dark { background-color: rgba(15,23,42,.62); } }
```

- **Body text ≥ `#cbd5e1`** on dark glass (the translucent fill eats contrast);
  muted text no lighter than `#94a3b8`.

**Light surface** — the frosted look on a light page is a **white** alpha fill, not a
dark one:

```css
.glass-light {
  background-color: rgba(255, 255, 255, 0.55);
  background-image: linear-gradient(180deg, rgba(255,255,255,.5), rgba(255,255,255,.2));
  backdrop-filter: blur(16px) saturate(120%);
  -webkit-backdrop-filter: blur(16px) saturate(120%);
  border-radius: 24px;
  box-shadow: 0 8px 24px rgba(15,23,42,.10), inset 0 1px 0 rgba(255,255,255,.6);
}
```

**Gradient hairline border** (optional — reads as edge refraction). The `::before`
mask-composite trick works over any background; keep the stops **neutral and
low-opacity** — no purple/blue tint (that's the AI-gradient tell, `critique-polish.md`
§D/§I):

```css
.glass-dark, .glass-light { position: relative; }
.glass-dark::before, .glass-light::before {
  content: ""; position: absolute; inset: 0; border-radius: inherit; padding: 1px;
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor; mask-composite: exclude; pointer-events: none;
  background: linear-gradient(160deg,
    rgba(148,163,184,.28) 0%, rgba(148,163,184,.10) 50%, rgba(148,163,184,.28) 100%);
}
```

## 14. Elevation shadows — one strength per state, named

When a surface lifts off the page (card, popover, hero media, modal), a single
**layered neutral** shadow reads premium where a default `shadow-lg` reads blunt.
Three tiers, exact Tailwind arbitrary values — copy verbatim:

**`sm`** — compact cards, form controls, pills, quieter surfaces:

```txt
shadow-[0px_2px_3px_-1px_rgba(0,0,0,0.1),0px_1px_0px_0px_rgba(25,28,33,0.02),0px_0px_0px_1px_rgba(25,28,33,0.08)]
```

**`md`** — cards, panels, popovers, the default elevated surface:

```txt
shadow-[0px_0px_0px_1px_rgba(0,0,0,0.06),0px_1px_1px_-0.5px_rgba(0,0,0,0.06),0px_3px_3px_-1.5px_rgba(0,0,0,0.06),_0px_6px_6px_-3px_rgba(0,0,0,0.06),0px_12px_12px_-6px_rgba(0,0,0,0.06),0px_24px_24px_-12px_rgba(0,0,0,0.06)]
```

**`lg`** — hero media, feature callouts, modal-like containers, the strongest lift:

```txt
shadow-[0_2.8px_2.2px_rgba(0,_0,_0,_0.034),_0_6.7px_5.3px_rgba(0,_0,_0,_0.048),_0_12.5px_10px_rgba(0,_0,_0,_0.06),_0_22.3px_17.9px_rgba(0,_0,_0,_0.072),_0_41.8px_33.4px_rgba(0,_0,_0,_0.086),_0_100px_80px_rgba(0,_0,_0,_0.12)]
```

**One shadow strength per component state.** Pick the tier that matches the surface
and stop; raise a tier only when an interaction *genuinely* changes elevation
(rest → hover on a lifting card). Otherwise the shadow is a constant, not an animation.

- **Never stack multiple shadow utilities on one element** — two arbitrary
  `shadow-[…]` strings (or a named tier plus a default `shadow-lg`) double-render and
  muddy the edge. One utility, one state (grep-enforced: `sensors.md` Sensor 10).
- **Keep them neutral** — no coloured/tinted glow; these are `rgba(0,0,0,…)` /
  `rgba(25,28,33,…)` by design. For depth *without* a hard line (buttons/inputs) use
  the shadow-as-border recipe (§2), not these.
- **Dark surfaces:** black-alpha shadows are invisible on dark — don't stack a light
  tier there; collapse to the §2 white-ring elevation (or lift via the glass border).
- Map onto the app's elevation token scale where one exists (token-override rule).

## 15. Progressive (gradient) blur — web/site only, perf-gated

A stack of `backdrop-filter` + `mask` layers that fades a viewport edge from sharp to
blurred, so content scrolls "under" a soft top/bottom fade. Premium on a marketing
hero or a scroll-edge — but **GPU-heavy**.

> **Admissibility (binding).** **Web / marketing surfaces only — NEVER inside
> `/app`**: the stacked `backdrop-filter` layers blow the native-shell perf budget.
> **Cap the layers at ≤ 6** blur steps (the ramp below is the ceiling, not a target)
> and drop steps on low-end devices. `backdrop-filter` needs real content behind it —
> it will not blur a flat background.

```html
<div class="gradient-blur" aria-hidden="true">
  <div></div><div></div><div></div><div></div><div></div><div></div>
</div>
```

```css
.gradient-blur { position: fixed; inset: 0 0 auto 0; height: 12%; z-index: 5; pointer-events: none; }
.gradient-blur > div, .gradient-blur::before, .gradient-blur::after { position: absolute; inset: 0; }
/* doubling blur ramp 0.5→64px, each layer masked to a moving band up the edge */
.gradient-blur::before             { z-index:1; backdrop-filter: blur(0.5px); mask: linear-gradient(to top, transparent 0%,    #000 12.5%, #000 25%,   transparent 37.5%); }
.gradient-blur > div:nth-of-type(1){ z-index:2; backdrop-filter: blur(1px);   mask: linear-gradient(to top, transparent 12.5%, #000 25%,   #000 37.5%, transparent 50%); }
.gradient-blur > div:nth-of-type(2){ z-index:3; backdrop-filter: blur(2px);   mask: linear-gradient(to top, transparent 25%,   #000 37.5%, #000 50%,   transparent 62.5%); }
.gradient-blur > div:nth-of-type(3){ z-index:4; backdrop-filter: blur(4px);   mask: linear-gradient(to top, transparent 37.5%, #000 50%,   #000 62.5%, transparent 75%); }
.gradient-blur > div:nth-of-type(4){ z-index:5; backdrop-filter: blur(8px);   mask: linear-gradient(to top, transparent 50%,   #000 62.5%, #000 75%,   transparent 87.5%); }
.gradient-blur > div:nth-of-type(5){ z-index:6; backdrop-filter: blur(16px);  mask: linear-gradient(to top, transparent 62.5%, #000 75%,   #000 87.5%, transparent 100%); }
.gradient-blur > div:nth-of-type(6){ z-index:7; backdrop-filter: blur(32px);  mask: linear-gradient(to top, transparent 75%,   #000 87.5%, #000 100%); }
.gradient-blur::after              { z-index:8; backdrop-filter: blur(64px);  mask: linear-gradient(to top, transparent 87.5%, #000 100%); }
```

- **Direction:** flip every `to top` → `to bottom` for a bottom-edge fade.
- **Height / strength:** the `.gradient-blur` height % and the blur ramp are the two
  knobs; fewer steps = cheaper and coarser.
- Keep `pointer-events: none` so it never blocks clicks; place it above content but
  below modals.

---

## How this file is used

- **ELEVATE phase:** when applying a fix, pull the exact value from here instead of
  inventing one — *after* confirming the app has no token for it (token-override rule).
- **AUDIT phase:** several of these are machine-checkable. The greppable ones
  (`transition: all`, `will-change: all`, tinted/missing image outline, sub-`0.95`
  press-scale, stacked shadow utilities) are wired as **Sensors 5–8 and 10** in
  `sensors.md` — they run before eyes.
- These are **defaults, not dogma.** A cited reason to deviate (a design.md token, a
  brand motion spec) overrides any constant here. "Conform to the app" always wins.
