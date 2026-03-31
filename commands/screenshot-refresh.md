---
description: Refresh landing page screenshots — discover what's needed, seed test data, capture via browser agent, verify
---

**You are the screenshot conductor.** Discover what screenshots the landing page needs, ensure the app has compelling data, then delegate capture to browser agents.

---

## I/O Contract

|                  |                                                                                     |
| ---------------- | ----------------------------------------------------------------------------------- |
| **Input**        | Running dev server (default `localhost:3000`)                                       |
| **Output**       | Updated screenshot files in their referenced paths, verification report             |
| **Prerequisites**| Dev server running, database/backend accessible                                     |

---

## Phase 1: Discover Screenshot Requirements

### 1a. Find landing page files

Search the codebase for landing page / homepage components:

```bash
# Find landing/home page files
grep -rl "landing\|hero\|HomePage\|home-page" src/ app/ components/ pages/ --include="*.tsx" --include="*.ts" -l 2>/dev/null | head -20
# Also look for screenshot references directly
grep -rl '\.png\|\.jpg\|\.webp\|/screenshots/\|/images/' src/ app/ components/ pages/ --include="*.tsx" --include="*.ts" -l 2>/dev/null | head -20
```

### 1b. Extract screenshot manifest

Read each landing page file found above. For every screenshot/image reference, extract:

- **filename**: the path referenced (e.g. `/screenshots/step1-foo.png`, `/images/hero.webp`)
- **context**: what the screenshot depicts — infer from alt text, variable names, adjacent copy text, description strings
- **section**: which part of the landing page uses it (hero, how-it-works step 1, trust section, etc.)
- **appRoute**: which app view/route would produce this screenshot (e.g. `/app/insights`, `/dashboard`, `/feed`)

Read any nearby copy/text files (e.g. `_copy.ts`, `content.ts`, `copy.json`) to enrich context.

Build a manifest table:

```
| # | filename | section | context | appRoute |
|---|----------|---------|---------|----------|
```

### 1c. Check for seed script

```bash
# Look for seed scripts
ls scripts/ 2>/dev/null | grep -i seed
grep -i "seed" package.json 2>/dev/null | head -5
```

Note what seed command is available (or that none exists).

**Report the manifest and seed script findings. Ask the user to confirm before proceeding.**

---

## Phase 2: Seed Test Data

If a seed script was found in Phase 1:

1. Ask the user to confirm it should be run (it may reset data)
2. Run it using the command discovered (e.g. `pnpm exec tsx scripts/seed-test-data.ts`)
3. If the script requires credentials or environment variables, ask the user

If no seed script exists, skip this phase and note that screenshots will use whatever data is currently in the app.

---

## Phase 3: Capture Screenshots via Browser Agent

Ask the user to confirm or provide:

- **Dev server URL** (default: `http://localhost:3000`)
- **Auth required?** If yes: login URL, test credentials (email + password)
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

Before taking any screenshot, run this cleanup in the browser console:
  document.querySelector('nextjs-portal')?.remove()
  document.querySelector('vite-error-overlay')?.remove()
  document.querySelectorAll('[data-dev-indicator],[data-nextjs-toast],[data-testid="dev-tools"]').forEach(el => el.remove())

Wait for network requests to finish, then wait an additional 3 seconds before capturing.

<Natural language description of: what route to navigate to, what interactions to perform,
what should be visible in the screenshot. Derived from the manifest context + appRoute.>

Save the screenshot to: $PWD/<filename>
```

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

### 4c. Report

Produce a table:

```
Screenshot Refresh Complete:
  <filename>  — <size>kb  PASS / FAIL  — <brief note>
  ...
```

Re-run failed screenshots individually with adjusted instructions.

---

## Phase 5: Dev Indicator Cleanup Reference

If dev indicators appear in screenshots, include this in the agent prompt (already in the Phase 3 template) or run manually in the browser console before capture:

```js
// Next.js dev toolbar
document.querySelector('nextjs-portal')?.remove()

// Vite error overlay
document.querySelector('vite-error-overlay')?.remove()

// Generic dev indicator attributes
document.querySelectorAll('[data-dev-indicator], [data-nextjs-toast]').forEach(el => el.remove())

// React DevTools badge (if visible)
document.querySelector('#react-devtools-backend-installation')?.remove()
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Auth fails | Confirm test user exists in the auth provider; ask user for correct credentials |
| Empty data | Re-run seed script; if none exists, create test data manually or ask user |
| Wrong user's data showing | Agent should sign out first, then sign in as test user |
| Dev indicator visible | Add/adjust the cleanup script in the agent prompt |
| Screenshot blank or tiny | Increase the post-load wait time; check if app needs longer to hydrate |
| Screenshot shows wrong route | Double-check the `appRoute` in the manifest; adjust agent navigation instructions |
| File not saved | Confirm `$PWD` resolves correctly; use an absolute path as fallback |
