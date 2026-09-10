# ui-checklist — objective UI-compliance audit (the correctness half of the archived skill)

The objective, binary compliance layer for audited UI. **Every item names its eval oracle** —
`agent-browser … eval` in the live DOM, `axe` when available, the sensors in
`ac-ui-polish/reference/sensors.md`, or a source grep. A cell no oracle can fill is
`unmeasured`, never a guess. The taste layer on top is `ac-ui-polish`; this file never judges
premium — only correct.

Oracles: `sensor-1` contrast sweep · `sensor-2` hardcoded-colour grep · `sensor-3` token
symmetry · `sensor-5` transition specificity (all in `ac-ui-polish/reference/sensors.md`) ·
`DOM` = `agent-browser eval` / `page.evaluate` on the rendered page · `axe` = the a11y engine
when wired in the app. Static grep narrows; the DOM decides.

## A11y — labels, ARIA, semantics, keyboard, heading order

- **Alt/accessible name on every image**: `DOM` — `document.querySelectorAll('img')`, flag any
  with no `alt` and no `aria-label`/`aria-hidden` (a source grep undercounts multi-line JSX).
- **Every icon-only button carries `aria-label`** (decorative icons `aria-hidden`): `axe`
  button-name rule; fallback `DOM` — buttons whose text content is empty.
- **Form controls labelled** — `<label htmlFor>`/wrapping label/`aria-label`, never bare
  placeholders: `axe` label rule; fallback `DOM`.
- **No interactive `<div onClick>`**: `rg -n '<div[^>]*onClick'` — a div that navigates or acts
  must be `<a>`/`<button>` (Cmd/Ctrl+click + keyboard).
- **Semantic landmarks** — `nav`/`main`/`article` where they read naturally: `axe`
  landmark rule; fallback `DOM`.
- **Heading order sequential, no skipped levels, skip-link present**: `DOM` —
  `document.querySelectorAll('h1,h2,h3,…')` mapped in order.
- **`user-scalable=no` / `maximum-scale=1` absent**: `rg -n 'user-scalable|maximum-scale'`.
- **Async updates announced**: `aria-live` on status regions: `axe` live-region rule.

## Focus states

- **Visible focus everywhere, never `outline-none` without replacement**: `DOM` — tab through
  every interactive element, focus must be visibly painted; `rg -n 'outline-none|outline:\s*none'`
  as the first pass.
- **`focus-visible`, not `focus`, for rings** (no ring on click): `rg -n 'focus:'`.
- **`scroll-margin-top` on `[id]` anchors** so fixed headers don't cover targets: `rg -n
  'scroll-margin-top'`.

## Forms

- **Correct input types + `autoComplete` + `inputMode`** (email/tel/url/number show the right
  keyboard): `DOM` — `document.querySelectorAll('input')`, type/autoComplete/inputMode audit.
- **`onPaste` with `preventDefault` absent on password fields** (blocks password managers):
  `rg -n 'onPaste'`.
- **`spellCheck={false}` on codes/usernames**: `rg -n 'spellCheck'`.
- **Submit button disables during request, shows progress, never blocks**: `DOM` — trigger
  submit, button must show submitting state.
- **Inline errors next to fields, `aria-invalid` + `aria-describedby`, first error focused on
  submit**: `DOM` — submit an invalid form; `rg -n 'aria-invalid|aria-describedby'`.
- **Unsaved-changes warning** when a dirty form unloads: `rg -n 'beforeunload|preventDefault'`.

## Motion & typography

- **`prefers-reduced-motion` honored** (CSS `@media` or `motion-reduce:`): `rg -n
  'prefers-reduced-motion|motion-reduce'`.
- **No `transition: all`** (compositor-friendly transform/opacity only): `sensor-5`.
- **No layout-triggering animation** (`left:`/`top:`/`width:` animation): `rg -n 'transition-all|transition-all'` plus `DOM` — animate a hover, devtools must show no layout paint.
- **Curly quotes + ellipsis char, loading states end with `…`**: `rg -n '"|\.\.\.'` over UI copy.
- **`&nbsp;` on unit/name pairs, `tabular-nums` on number columns, `text-balance`/`text-pretty`
  on headings**: `rg -n '&nbsp;|tabular-nums|text-balance|text-pretty'`.

## Content & images

- **Truncation/overflow handled** — `truncate`/`line-clamp`/`break-words`, flex children carry
  `min-w-0`: `rg -n 'truncate|line-clamp|break-words'`; empty states rendered, empty strings
  fall back: `DOM` — render with empty data.
- **Images carry explicit dimensions** (no CLS): `DOM` — every `img`/`Image` with
  `width`/`height` or aspect-ratio; `rg -n '<img(?!.*width)' -P` as first pass.
- **Below-fold images lazy, above-fold `priority`/`fetchPriority=high`**: `rg -n 'loading=|priority|fetchPriority'`.

## Performance & interaction

- **Lists > 50 items virtualized** (or `content-visibility: auto`): `rg -n 'content-visibility|VList|virtua'`.
- **No layout thrashing** (interleaved read/write, layout read in render): `rg -n
  'offsetHeight|offsetWidth|getBoundingClientRect'` — reads must be batched, none in render.
- **Critical origins `preconnect`/`preload`**: `rg -n 'preconnect|preload'`.
- **URL reflects state** (filters/pagination/tabs in the URL, not only local state): `DOM` —
  change state, the URL must change.
- **Links are `<a>`/`<Link>`**: covered by the a11y `<div onClick>` item; `axe` link-name rule.
- **Destructive actions confirm or undo, never immediate**: `rg -n 'delete|remove'` over
  handlers — each must be gated by a confirm/undo path.
- **Touch** — `touch-action: manipulation`, `overscroll-behavior: contain` in modals, drag sets
  `user-select: none`: `rg -n 'touch-action|overscroll-behavior|userSelect'`.
- **`autoFocus` desktop-only, single primary input**: `rg -n 'autoFocus'`.

## Hydration

- **Controlled inputs always carry `onChange`** (or use `defaultValue`): `rg -n 'value='` —
  every `value=` paired with `onChange`.
- **Date/time guarded against server/client mismatch** (`mounted` gate or
  `suppressHydrationWarning`): `rg -n 'suppressHydrationWarning|setMounted'`.

## Theming & i18n

- **`color-scheme` + `theme-color` meta present**, native selects themed explicitly: `rg -n
  'colorScheme|theme-color'`.
- **No hardcoded date/number formats** — `Intl` APIs (`Intl.DateTimeFormat` /
  `Intl.NumberFormat`) used: `rg -n 'toFixed|getMonth|getDate|getFullYear'`.
- **Locale from `Accept-Language`/`navigator.languages`, never IP**: `rg -n 'Accept-Language|navigator.languages'`.