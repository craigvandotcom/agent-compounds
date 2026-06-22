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

---

## How this file is used

- **ELEVATE phase:** when applying a fix, pull the exact value from here instead of
  inventing one — *after* confirming the app has no token for it (token-override rule).
- **AUDIT phase:** several of these are machine-checkable. The greppable ones
  (`transition: all`, `will-change: all`, tinted/missing image outline, sub-`0.95`
  press-scale) are wired as **Sensors 5–8** in `sensors.md` — they run before eyes.
- These are **defaults, not dogma.** A cited reason to deviate (a design.md token, a
  brand motion spec) overrides any constant here. "Conform to the app" always wins.
