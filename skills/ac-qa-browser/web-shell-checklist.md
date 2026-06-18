# Web-shell checklist — what ONLY the browser plane surfaces

The native twin has `native-shell-checklist.md`; this is its mirror. These are the
concerns that live in the web shell — routing, storage, the service worker, the
network origin, console hygiene, hydration, responsiveness. DOM logic/layout that is
identical to the native webview is covered here too (it's the cheap plane); this list
is what's *web-specific*. Check the relevant subset at `full`, all of it at `exhaustive`.

## Routing (SPA)

- [ ] **Cold deep-link to every route** — `open "<BASE>/<route>"` directly (not just
      in-app nav). Guards, redirects, and first-paint data-fetch only break on cold load.
- [ ] **Protected routes** redirect to login when unauthenticated; return to the
      intended route after auth.
- [ ] **Back / forward** buttons restore the right view + scroll position.
- [ ] **Unknown route** renders the app's 404, not a blank screen or a crash.
- [ ] **Trailing-slash / case** variants don't dead-end.

## Storage & session persistence

- [ ] **Reload mid-session** — auth/session survives a hard refresh (token in the
      right store; no surprise logout).
- [ ] **localStorage / IndexedDB** state persists across reload where intended.
- [ ] **Cleared-storage cold start** (incognito / fresh profile) — app boots to the
      correct unauthenticated state, no stuck spinner waiting on missing state.
- [ ] **Multi-tab** — no cross-tab corruption of shared state.

## Service worker / PWA

- [ ] **Registration** succeeds (check `errors`/`console` for SW failures).
- [ ] **Update flow** — a new deploy is picked up (no permanently stale cached bundle);
      the app's update prompt (if any) fires.
- [ ] **Offline behavior** matches intent (offline page / cached shell vs. graceful fail).
- [ ] **No stale-cache false-clean** — confirm you're testing the current bundle, not
      a SW-cached old one (hard-reload / bypass SW when verifying a fix).

## Network & CORS

- [ ] API calls hit the **correct origin** for the environment (local vs preview vs prod).
- [ ] **Zero CORS errors** in the console on any route.
- [ ] **Failed-request handling** — a 4xx/5xx surfaces a user-visible error state, not a
      silent blank or an infinite spinner.

## Console hygiene (run `errors` per route)

- [ ] **Zero console errors** on every route load and after every mutation.
- [ ] **No React hydration mismatch** warnings (SSR/CSR divergence — Next.js).
- [ ] **No missing-`key` / controlled-input** warnings.
- [ ] **No unhandled promise rejections.**

## Hydration & SSR (Next.js)

- [ ] First paint matches post-hydration (no flash of wrong content / layout jump).
- [ ] Interactive elements work immediately after hydration (no dead clicks during it).

## Responsive (the app's declared viewport set)

- [ ] No **horizontal scroll** at any width (320 / 390 / 428, + desktop if supported).
- [ ] Layout holds at each breakpoint; nav/menu adapts; nothing clipped or overlapping.
- [ ] Tap targets stay ≥ 44×44px at mobile widths.
- [ ] Text scales / wraps without truncation-by-accident.

## Forms

- [ ] Validation fires + clears correctly; error messages are reachable and labelled.
- [ ] Keyboard: Tab order is logical, Enter submits, paste works in each field.
- [ ] Autofill doesn't break controlled-input state.

## Per-route states

- [ ] **Loading** — skeleton/spinner shows, no layout shift on resolve.
- [ ] **Empty** — empty state renders (distinct from an error).
- [ ] **Error** — error boundary / retry path renders on forced failure.

## A11y quick pass (deep audit → `web-design-guidelines`)

- [ ] Keyboard navigation reaches every interactive control; focus is visible.
- [ ] Focus traps correctly inside modals and releases on close.
- [ ] Images have alt text; icon-only buttons have accessible names.

> Anything checked here that fails is a **bead** (`qa-finding`, + `qa-blocker` if it
> traps the user or breaks a primary journey). Console errors and CORS failures are
> always at least `qa-finding`.
