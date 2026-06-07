# Reference: Perceived Performance

The speed the user *feels* — not the speed a profiler measures. A UI can be fast
on paper and feel slow, or slower on paper and feel instant. This skill owns the
felt layer. **Deep perf work — bundle size, data-fetch waterfalls, hydration,
memoization — belongs to `react-best-practices`; defer there.** The objective
CLS / virtualization / image-dimension *rules* are the authoritative job of
`web-design-guidelines`; this file is the felt layer that assumes those pass.

---

## The core principle

> Responsiveness is a feeling. Acknowledge instantly, show progress honestly,
> never make the user stare at a frozen or jumping screen.

Three levers, in priority order: **instant feedback → no layout shift → smooth
motion.**

## Instant feedback (< 100ms)

- **Respond to input immediately** — press state, disabled-while-pending, inline
  spinner on the acting element. The action must visibly register before the result.
- **Optimistic UI** for high-confidence actions (likes, toggles, adds, reorders):
  update the UI immediately, reconcile when the server responds, roll back on error
  with a clear message. This is the single biggest perceived-speed win.
- **Debounce/throttle perception:** for search-as-you-type, show a subtle pending
  state; don't flash full skeletons on every keystroke.

## Loading states — skeletons over spinners

- **Skeleton screens** that mirror the final layout beat bare spinners: they set
  expectation, reduce perceived wait, and prevent layout shift when content lands.
- **Spinners** only for short, indeterminate, small-area waits. Never a full-page
  spinner for content that has a known shape.
- **Stagger reveal** content as it arrives rather than blocking on the slowest part.
- **Avoid flash-of-loading:** for very fast responses, delay showing a loader
  ~150–200ms so it doesn't flicker in and out.

## Layout stability (CLS — Cumulative Layout Shift)

Content that jumps is the strongest "cheap" tell. Eliminate shift:

- **Reserve space** for async content — images, ads, embeds, late-loading data —
  via fixed dimensions, `aspect-ratio`, or min-heights.
- **Media:** always set width/height or `aspect-ratio` + `object-fit`; use a
  blurred/low-quality placeholder (LQIP) that swaps in place.
- **Fonts:** use `font-display: swap` with a metric-matched fallback to minimize
  reflow; avoid invisible-text (FOIT) and big shift (FOUT). Preload critical fonts.
- **Skeletons must match final dimensions** so the swap causes zero shift.
- **Don't inject banners/toasts** that push content down — overlay them instead.

## Smooth motion (60fps / 120fps)

- **Animate only `transform` and `opacity`.** These run on the compositor and stay
  smooth. Animating `width`, `height`, `top/left`, `margin`, `box-shadow`, or
  anything triggering layout/paint causes jank.
- **`will-change` sparingly** on elements about to animate; remove it after — it's a
  cost, not a free win.
- **Avoid layout thrash:** batch DOM reads then writes; don't read geometry in a
  loop that also mutates it.
- **Off-main-thread heavy work:** keep the main thread free during interaction;
  defer non-urgent work (the *how* of scheduling → `react-best-practices`).
- **Test on real/throttled mid-tier mobile**, not just a fast laptop — that's where
  jank shows.

## Lists & images at scale

- **Virtualize long lists** (windowing) so only visible rows render — keeps scroll
  at 60fps and initial render fast.
- **Lazy-load below-the-fold images** with reserved space; eager/priority-load only
  the above-the-fold hero/LCP image.
- **Right-size assets:** serve appropriately sized, modern-format (WebP/AVIF) images;
  never ship a 3000px image into a 300px slot.

## Navigation & transitions

- **Prefetch likely-next routes/data** on hover/focus/visible so navigation feels
  instant (mechanics → `react-best-practices`).
- **Keep transition shells stable** — animate between screens with the chrome
  persistent so the app never feels like it "reloads."
- **Persist and restore scroll position** on back-navigation.

---

## Quick triage: "it feels slow/janky"

| Symptom | Likely cause | Fix here |
|---------|--------------|----------|
| Tap feels unresponsive | No instant feedback | Press state + optimistic UI |
| Content jumps as it loads | Layout shift (CLS) | Reserve space, aspect-ratio, skeleton-matches-final |
| Animation stutters | Animating layout props | Move to transform/opacity; check on throttled mobile |
| Long list scroll lags | Rendering all rows | Virtualize |
| Spinner flickers | No min-display delay | Delay loader ~150ms; prefer skeleton |
| Genuinely slow data/bundle | Backend / JS payload | **Hand to `react-best-practices`** |
