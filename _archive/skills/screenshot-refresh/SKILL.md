---
name: screenshot-refresh
description: Use when refreshing or updating landing page (marketing website) screenshots. Triggers on "refresh screenshots", "update screenshots", "recapture landing page screenshots", "screenshot the app" (landing-page/marketing context), "landing page images are stale". NOT for ad-hoc native simulator screenshots/recordings (use device-testing); NOT for App Store listing assets (use app-store-screenshots).
---

**You are the screenshot conductor.** Discover what screenshots the landing page needs, ensure the app has compelling data, then capture them.

## I/O Contract

|                  |                                                                                     |
| ---------------- | ----------------------------------------------------------------------------------- |
| **Input**        | Running dev server (default `localhost:3000`)                                       |
| **Output**       | Updated screenshot files in their referenced paths, verification report             |
| **Prerequisites**| Dev server running, database/backend accessible                                     |

## Phase 1: Discover Screenshot Requirements

### 1a. Check for existing capture script FIRST

```bash
# Look for existing capture/screenshot scripts — prefer these over browser agents
ls scripts/ 2>/dev/null | grep -iE "capture|screenshot"
```

**A proven capture script is always preferred over spawning browser agents** — it handles auth, navigation, timing, and ordering reliably. If one exists (e.g. `scripts/capture-screenshots.ts`), read it to understand:
- What screenshots it captures and in what order
- Auth mechanism (cookie injection, login flow, etc.)
- Viewport, device scale, color scheme settings
- Output paths

### 1b. Find landing page files

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

## Phase 2: Seed Test Data

**CRITICAL: Seed data uses relative dates (Day 0 = today).** Previously seeded data becomes stale — "Today" views will show empty state unless re-seeded. **Always re-seed before capture.**

If a seed script was found in Phase 1:

1. Ask the user to confirm it should be run (it may reset data)
2. Run it using the command discovered (e.g. `pnpm exec tsx scripts/seed-test-data.ts`)
3. If the script requires credentials or environment variables, ask the user
4. Verify the seed output — check that today's date has entries

If no seed script exists, skip this phase and note that screenshots will use whatever data is currently in the app.

## Phase 3: Capture Screenshots

Pick the path explicitly:
- **Option A — capture script** (preferred, whenever one exists)
- **Option B — native device capture** (when the embedded images are screenshots of a NATIVE app)
- **Option C — browser agents** (fallback, only when no capture script exists)

**Standing rule for every path: all mobile-appearance cleanup happens at capture time only — never modify app component code, global CSS, or framework config.**

### Option A: Dedicated Capture Script (preferred)

```bash
pnpm exec tsx scripts/capture-screenshots.ts
```

The script should already handle: auth (cookie injection / login), navigation between app views, timing / wait conditions, dev indicator hiding and focus ring removal, output to correct paths.

**Dynamic-path doctrine (do this before trusting an existing script):** a capture script must resolve the project root **dynamically** — `process.cwd()` (the script runs via `pnpm exec tsx scripts/...` from the app root, so cwd === app root) or `git rev-parse --show-toplevel`. **Never hardcode an absolute path** (e.g. `/home/<user>/Repos/...`) — it silently breaks on any other machine/OS and writes screenshots nowhere useful. Do **not** use `import.meta.url` for the root — it resolves to the `scripts/` dir, off by one. If you find a hardcoded path in the script, fix it to `path.join(process.cwd(), ...)` before running.

**After running, skip to Phase 4 (Verify).**

### Option B: Native device capture (when the screenshots are of a NATIVE app)

If the embedded images are screenshots of a **native mobile app** (e.g. landing-page phone mockups of an iOS app), capture from the **real app on a simulator/device** via `agent-device` — authentic native rendering, and often the *only* path that works: a local `pnpm dev` web server may render demo/mock data and/or auto-authenticate a fixed dev user, so DB seeding has no effect on what renders there. **Seed the account the native app auto-uses, in the backend the app actually points at (usually prod), not whatever the web default is.** (Marketing *site pages* are browser work; the *app-screen mockups* embedded in them are native-app work.)

> **MANDATORY protocol (each maps to a real escaped defect):**
> 1. **Seed FIRST, always** — relative-date seed data goes stale; re-seed before every capture run.
> 2. **Verify data is CURRENT *in the app* before capturing** — seeding the DB is not enough: the app
>    may show a cached/pre-seed state (e.g. recent days blank, wrong streak count). After seeding,
>    **relaunch/refresh the app** and confirm the latest data is visible (timeline/bars populated
>    through *today*, no blank recent stretch) BEFORE taking the shot. A capture taken before the
>    fresh data loads ships blank recent days.
> 3. **Capture EVERY screenshot in the Phase-1 manifest — never skip a slot.** "This one's awkward to
>    reach" is not a reason to leave a stale image; find the right screen (each landing slot maps to a
>    specific app view — honour that mapping) and refresh all of them in one run.

Flow: seed the right account → drive the app with `agent-device` (set theme to match the marketing aesthetic) → `xcrun simctl io <UDID> screenshot` per view → post-process to the embedded format (crop the OS status bar / notch, resize to the referenced dimensions).

> **Post-process: preserve full width — never cover-crop the sides.** Resize to the target *width*
> and pad top/bottom (the app bg colour) to the target height; do NOT use a cover-fit
> (`-resize WxH^ -extent`) — it trims the sides and eats the app's horizontal padding, so cards run
> edge-to-edge in the mockup frame. The frames are usually `object-contain`, so a few px of dark
> top/bottom letterbox is invisible, but lost side margin is glaring. Verify the inset:
> `magick out.png -fuzz 8% -trim info:` and check the content bbox keeps a sensible left/right offset.

Gotcha: `agent-device click` uses **logical points**, not native pixels (divide native coords by the device scale, ~3×).
**App-specific recipe (accounts, views, dims, sim) lives in the app's `CORE/ui-audit.md`.**

### Option C: Browser Agents (fallback)

Only use browser agents if no capture script exists. Full procedure — defaults matrix, per-agent prompt template (with capture-time cleanup JS), agent guidance, style-injection survival: **read `references/browser-capture.md` before spawning any agent.**

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
- **Data is CURRENT, not just present** — for any time-series view (daily bars, streak, timeline),
  the data must run **through today with no blank recent stretch**. Blank trailing days = a stale
  pre-seed/cached capture (re-seed, relaunch, re-verify, re-capture). This is the #1 silent defect.
- **Every manifest slot was refreshed** — cross-check the captured set against the Phase-1 manifest;
  no referenced screenshot left stale.

### 4c. Report

Produce a table:

```
Screenshot Refresh Complete:
  <filename>  — <size>kb  PASS / FAIL  — <brief note>
  ...
```

Re-run failed screenshots individually with adjusted instructions.

**Note:** Screenshots overwrite existing files in-place at the paths already referenced by the landing page code. No code changes to `<Image src=...>` tags are needed — the filenames stay the same.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Auth fails | Confirm test user exists in the auth provider; ask user for correct credentials |
| Empty data / empty "Today" bar | **Re-seed** — seed data uses relative dates and goes stale |
| Wrong user's data showing | Agent should sign out first, then sign in as test user |
| Screenshot blank or tiny | Increase the post-load wait time; check if app needs longer to hydrate |
| Screenshot shows wrong route | Double-check the `appRoute` in the manifest; adjust agent navigation instructions |
| Capture script writes nowhere / `ENOENT` on output dir | The script hardcodes an absolute path from another machine. Replace with `path.join(process.cwd(), ...)` (cwd === app root under `pnpm exec tsx`); do NOT use `import.meta.url` (resolves to `scripts/`). |

Browser-agent-specific issues (dev indicators, focus rings, style loss after navigation, `$PWD` paths, selector misses): see the troubleshooting table in `references/browser-capture.md`.
