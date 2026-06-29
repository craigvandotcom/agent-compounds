---
name: screenshot-refresh
description: Use when refreshing, recapturing, or updating landing page screenshots — discovers what's needed, seeds test data, captures via Playwright script or browser agent, then verifies results. Triggers on "refresh screenshots", "update screenshots", "recapture landing page screenshots", "screenshot the app", "landing page images are stale".
---

**You are the screenshot conductor.** Discover what screenshots the landing page needs, ensure the app has compelling data, then capture them.

---

## I/O Contract

|                  |                                                                                     |
| ---------------- | ----------------------------------------------------------------------------------- |
| **Input**        | Running dev server (default `localhost:3000`)                                       |
| **Output**       | Updated screenshot files in their referenced paths, verification report             |
| **Prerequisites**| Dev server running, database/backend accessible                                     |

---

## Phase 1: Discover Screenshot Requirements

### 1a. Check for existing capture script FIRST

```bash
# Look for existing capture/screenshot scripts — prefer these over browser agents
ls scripts/ 2>/dev/null | grep -iE "capture|screenshot"
```

If a dedicated capture script exists (e.g. `scripts/capture-screenshots.ts`), read it to understand:
- What screenshots it captures and in what order
- Auth mechanism (cookie injection, login flow, etc.)
- Viewport, device scale, color scheme settings
- Output paths

**A proven capture script is always preferred over spawning browser agents.** It handles auth, navigation, timing, and ordering reliably.

### 1b. Find landing page files

Search the codebase for landing page / homepage components:

```bash
# Find landing/home page files
grep -rl "landing\|hero\|HomePage\|home-page" src/ app/ components/ pages/ --include="*.tsx" --include="*.ts" -l 2>/dev/null | head -20
# Also look for screenshot references directly
grep -rl '\.png\|\.jpg\|\.webp\|/screenshots/\|/images/' src/ app/ components/ pages/ --include="*.tsx" --include="*.ts" -l 2>/dev/null | head -20
```

### 1c. Extract screenshot manifest

Read each landing page file found above. For every screenshot/image reference, extract:

- **filename**: the path referenced (e.g. `/screenshots/step1-foo.png`, `/images/hero.webp`)
- **context**: what the screenshot depicts — infer from alt text, variable names, adjacent copy text, description strings
- **section**: which part of the landing page uses it (hero, how-it-works step 1, trust section, etc.)
- **appRoute**: which app view/route would produce this screenshot — check the app's routing structure (`app/`, `pages/`, router config) to map context to routes. If uncertain, flag it in the manifest for user confirmation.
- **reuse**: note if the same file is referenced in multiple sections (e.g. hero AND how-it-works)

Read any nearby copy/text files (e.g. `_copy.ts`, `content.ts`, `copy.json`) to enrich context.

Build a manifest table:

```
| # | filename | section(s) | context | appRoute |
|---|----------|------------|---------|----------|
```

### 1d. Check for seed script

```bash
# Look for seed scripts
ls scripts/ 2>/dev/null | grep -i seed
grep -i "seed" package.json 2>/dev/null | head -5
```

Note what seed command is available (or that none exists).

**Report the manifest and seed script findings. Ask the user to confirm before proceeding.**

---

## Phase 2: Seed Test Data

**CRITICAL: Seed data uses relative dates (Day 0 = today).** Previously seeded data becomes stale — "Today" views will show empty state unless re-seeded. **Always re-seed before capture.**

If a seed script was found in Phase 1:

1. Ask the user to confirm it should be run (it may reset data)
2. Run it using the command discovered (e.g. `pnpm exec tsx scripts/seed-test-data.ts`)
3. If the script requires credentials or environment variables, ask the user
4. Verify the seed output — check that today's date has entries

If no seed script exists, skip this phase and note that screenshots will use whatever data is currently in the app.

---

## Phase 3: Capture Screenshots

### Option A: Dedicated Capture Script (preferred)

If a capture script was found in Phase 1a, use it directly:

```bash
pnpm exec tsx scripts/capture-screenshots.ts
```

The script should already handle:
- Auth (cookie injection / login)
- Navigation between app views
- Timing / wait conditions
- Dev indicator hiding and focus ring removal
- Output to correct paths

**Dynamic-path doctrine (do this before trusting an existing script):** a capture script must
resolve the project root **dynamically** — `process.cwd()` (the script runs via
`pnpm exec tsx scripts/...` from the app root, so cwd === app root) or
`git rev-parse --show-toplevel`. **Never hardcode an absolute path** (e.g. `/home/<user>/Repos/...`)
— it silently breaks on any other machine/OS and writes screenshots nowhere useful. Do **not** use
`import.meta.url` for the root — it resolves to the `scripts/` dir, off by one. If you find a
hardcoded path in the script, fix it to `path.join(process.cwd(), ...)` before running.

**After running, skip to Phase 4 (Verify).**

### Option C: Native device capture (when the screenshots are of a NATIVE app)

If the embedded images are screenshots of a **native mobile app** (e.g. landing-page phone mockups
of an iOS app), capture from the **real app on a simulator/device** via `agent-device` — this gives
authentic native rendering, and it is often the *only* path that works:

> **Why the browser script can fail for a native app:** a local `pnpm dev` web server may render
> **demo/mock data** and/or **auto-authenticate a fixed dev user**, so DB seeding has no effect on
> what renders. The native app build hits the real (prod) backend, so a seeded account shows real
> data there. Seed the **account the native app auto-uses**, in the backend the app actually points
> at (usually prod), not whatever the web default is.

Flow: seed the right account → drive the app with `agent-device` (set theme to match the marketing
aesthetic) → `xcrun simctl io <UDID> screenshot` per view → post-process to the embedded format
(crop the OS status bar / notch, resize to the referenced dimensions).

> **Post-process: preserve full width — never cover-crop the sides.** Resize to the target *width*
> and pad top/bottom (the app bg colour) to the target height; do NOT use a cover-fit
> (`-resize WxH^ -extent`) — it trims the sides and eats the app's horizontal padding, so cards run
> edge-to-edge in the mockup frame. The frames are usually `object-contain`, so a few px of dark
> top/bottom letterbox is invisible, but lost side margin is glaring. Verify the inset:
> `magick out.png -fuzz 8% -trim info:` and check the content bbox keeps a sensible left/right offset.

Gotcha: `agent-device click` uses **logical points**, not native pixels (divide native coords by the
device scale, ~3×).
**App-specific recipe (accounts, views, dims, sim) lives in the app's `CORE/ui-audit.md`.**

> This reverses an earlier "no device capture" stance that was correct only for *web* surfaces:
> auditing the marketing *site pages* is browser work, but refreshing the *app-screen mockups*
> embedded in them is native-app work.

### Option B: Browser Agents (fallback)

Only use browser agents if no capture script exists.

First, check for auth details in project files (`.env.local`, `CLAUDE.md`, test fixtures, seed scripts). Then ask the user to confirm or provide:

- **Dev server URL** (default: `http://localhost:3000`)
- **Auth required?** If yes: login URL, test credentials (email + password) — propose any credentials found in project files
- **Viewport** (default: 390px wide × 844px tall — iPhone 15 Pro)
- **Device scale factor** (default: 2 for retina)
- **Color scheme** (default: dark — adjust if the app uses light theme)

**For each screenshot in the Phase 1 manifest**, spawn one `browser-agent` with a targeted prompt. Agents run in parallel — one agent per screenshot.

### Template for every agent prompt

```
Dev server: <URL>
<If auth required:>
  Login page: <login URL>
  Credentials: <email> / <password>
  After login, you'll be at: <post-login route>

Viewport: <width>px × <height>px, deviceScaleFactor <scale>, <color scheme> color scheme.

Before taking any screenshot, execute this cleanup via page.evaluate():
  document.querySelector('nextjs-portal')?.remove()
  document.querySelector('vite-error-overlay')?.remove()
  document.querySelectorAll('[data-dev-indicator],[data-nextjs-toast],[data-testid="dev-tools"]').forEach(el => el.remove())
  // Remove all focus rings for mobile appearance
  const style = document.createElement('style');
  style.textContent = `
    *:focus, *:focus-visible, *:focus-within {
      outline: none !important; box-shadow: none !important;
      --tw-ring-shadow: none !important; --tw-ring-color: transparent !important;
      --tw-ring-offset-shadow: none !important;
    }`;
  document.head.appendChild(style);
  // Blur any focused element
  document.activeElement?.blur();

Wait for network requests to finish, then wait an additional 3 seconds before capturing.

<Natural language description of: what route to navigate to, what interactions to perform,
what should be visible in the screenshot. Derived from the manifest context + appRoute.>

Save the screenshot to: <absolute path to project root>/<filename>
```

**Important:** Resolve the absolute project root path (e.g. `/home/user/project`) before constructing agent prompts. Do NOT pass `$PWD` literally — browser agents don't execute shell variables.

### Guidance for agents

- If a login form shows a loading state, wait for it to appear before submitting
- If already logged in as the wrong user, navigate to settings/profile and sign out first
- Scroll to find content that isn't immediately visible — do not give up if something is off-screen
- If a drawer, modal, or panel needs to be open for the screenshot, interact to open it before capturing
- If the first attempt produces an empty or error state, try once more after a longer wait

---

## Phase 4: Verify

### 4a. File verification

Check each file from the Phase 1 manifest exists and has a reasonable size:

```bash
# Generated from manifest — check each discovered filename
ls -la <output directory>/<screenshot files>
```

Flag any file under 10KB (likely blank/failed) or missing entirely.

### 4b. Visual verification

Use the Read tool to view each screenshot image and confirm:
- Correct app view is shown
- The expected data/content is visible
- No loading spinners, error states, or empty states
- Dev indicators are absent
- **No focus rings or outlines** (screenshots should mimic real mobile appearance)
- Today's composition bar is populated (not empty) if the view includes a timeline

### 4c. Report

Produce a table:

```
Screenshot Refresh Complete:
  <filename>  — <size>kb  PASS / FAIL  — <brief note>
  ...
```

Re-run failed screenshots individually with adjusted instructions.

**Note:** Screenshots overwrite existing files in-place at the paths already referenced by the landing page code. No code changes to `<Image src=...>` tags are needed — the filenames stay the same.

---

## Phase 5: Mobile Appearance Cleanup Reference

Screenshots must mimic real mobile app appearance. All cleanup happens at capture time only — **never modify app component code, global CSS, or framework config.**

### Dev indicators

```js
// Next.js dev toolbar (shadow DOM element — use CSS, not remove())
// CSS: nextjs-portal { display: none !important; }
// Or via JS:
document.querySelector('nextjs-portal')?.remove()

// Vite error overlay
document.querySelector('vite-error-overlay')?.remove()

// Generic dev indicator attributes
document.querySelectorAll('[data-dev-indicator], [data-nextjs-toast]').forEach(el => el.remove())

// React DevTools badge (if visible)
document.querySelector('#react-devtools-backend-installation')?.remove()
```

### Focus rings (Tailwind + native)

Tailwind uses CSS custom properties for ring utilities. Override both native and Tailwind focus styles:

```css
*:focus, *:focus-visible, *:focus-within {
  outline: none !important;
  box-shadow: none !important;
  --tw-ring-shadow: none !important;
  --tw-ring-color: transparent !important;
  --tw-ring-offset-shadow: none !important;
}
```

Also blur the active element before capture: `document.activeElement?.blur()`

### Style injection survival

**`page.addStyleTag()` and `document.querySelector().remove()` do NOT survive `page.goto()` navigations.** If the capture script navigates to a new page (e.g. reloading for a different tab state), re-inject styles after each navigation.

Pattern for Playwright scripts:
```ts
const injectStyles = () => page.addStyleTag({ content: `...` });
await injectStyles();           // initial
await page.goto(url);           // navigates — styles lost
await injectStyles();           // re-inject
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Auth fails | Confirm test user exists in the auth provider; ask user for correct credentials |
| Empty data / empty "Today" bar | **Re-seed** — seed data uses relative dates and goes stale |
| Wrong user's data showing | Agent should sign out first, then sign in as test user |
| Dev indicator visible | Use CSS `nextjs-portal { display: none }` — more reliable than `.remove()` for shadow DOM |
| Focus ring on input | Inject Tailwind ring overrides + `document.activeElement?.blur()` before capture |
| Styles missing after navigation | Re-inject `addStyleTag()` after every `page.goto()` call |
| Screenshot blank or tiny | Increase the post-load wait time; check if app needs longer to hydrate |
| Screenshot shows wrong route | Double-check the `appRoute` in the manifest; adjust agent navigation instructions |
| Food cards not found | Check component selectors — use `role` and CSS class attributes (e.g. `[role="link"].spring-press-subtle`) instead of text matching |
| File not saved | Ensure the output path is absolute — browser agents cannot resolve shell variables like `$PWD` |
| Capture script writes nowhere / `ENOENT` on output dir | The script hardcodes an absolute path from another machine. Replace with `path.join(process.cwd(), ...)` (cwd === app root under `pnpm exec tsx`); do NOT use `import.meta.url` (resolves to `scripts/`). |
