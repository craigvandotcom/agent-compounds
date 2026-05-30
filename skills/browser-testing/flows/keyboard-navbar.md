# Keyboard and Navbar Smoke Flow

Verifies that the bottom navbar stays at the viewport bottom edge and does not translate upward when a text input is focused (the regression introduced before PR #239). Also confirms that scrollable form content has adequate padding-bottom so inputs remain reachable above the keyboard clearance zone.

**Regression target:** PR #239 (merged 2026-04-28) — removed keyboard-driven `translateY` from four form footers. This flow catches any re-introduction of that pattern.

---

## Limitation Note (Read Before Running)

**Chromium does not open a virtual keyboard.** Focusing an input in Chromium puts the field in focus state but does not change the viewport geometry or trigger keyboard-height measurements. As a result, this flow catches **CSS-level regressions only** — for example, someone re-adding `transform: translateY(...)` to the navbar footer, or a style rule that shifts the footer off the viewport bottom edge. It does **not** verify that the navbar stays behind the keyboard on a real device.

For real-device verification (iOS Safari, iOS Capacitor, Android Chrome, Android Capacitor) see the manual checklist in `.claude/skills/design-system/keyboard-and-navbar.md`.

---

## Prerequisites

### 1. Viewport

All assertions assume the **390×844 mobile viewport** (iPhone 15 Pro). Set it immediately after opening any URL — viewport must be set before taking bounding-box measurements.

```bash
agent-browser --session [name] set viewport 390 844
```

### 2. Authentication

Complete the login flow from `flows/login.md` before starting this flow. All pages below require an authenticated session.

```bash
agent-browser --session [name] open "[BASE_URL]/login"
agent-browser --session [name] set viewport 390 844
agent-browser --session [name] wait --load networkidle
agent-browser --session [name] snapshot -i
agent-browser --session [name] fill @[email-ref] "[EMAIL]"
agent-browser --session [name] fill @[password-ref] "[PASSWORD]"
agent-browser --session [name] click @[submit-ref]
agent-browser --session [name] wait --timeout 15000 --url "/app"
```

### 3. Symptoms prerequisite (Edit Signal only)

The Edit Signal step requires at least one existing symptom in the test user's account. If none exist, pre-seed one by completing an Add Signal cycle first (Step 2 below will create one), or skip the Edit Signal step and log a clear note.

---

## Helper: Capture Navbar Bottom Edge

The bounding-box measurements in this flow use `[data-testid="universal-navbar-wrapper"]` — the inner centering div inside the footer (from `bd-zkzf.1`). Measuring the inner element catches regressions where the footer is still fixed to the bottom but its inner content has been translated away from the edge.

> **TODO:** The `eval` primitive shown below is an improvisation — verify it is supported by your installed version of `agent-browser` before relying on it. If `eval` is not available, substitute with `screenshot` diffs: capture before-focus and after-focus screenshots and compare the navbar position visually.

```bash
# Capture the inner wrapper's bottom edge (pixels from top of viewport)
agent-browser --session [name] eval \
  "document.querySelector('[data-testid=\"universal-navbar-wrapper\"]').getBoundingClientRect().bottom"

# Capture the viewport height to compare against
agent-browser --session [name] eval "window.innerHeight"
```

**Pass criteria:** The two values should be equal (or within 1px rounding tolerance). This means the navbar wrapper bottom edge sits at the viewport bottom.

Also confirm the outer footer exists as a stable presence check:

```bash
agent-browser --session [name] snapshot -i
# Verify: [data-testid="universal-navbar-footer"] appears in the element tree
```

---

## Step 1: Add Signal — `/app/symptoms/add`

### 1a. Navigate

```bash
agent-browser --session [name] open "[BASE_URL]/app/symptoms/add"
agent-browser --session [name] set viewport 390 844
agent-browser --session [name] wait --load networkidle
```

### 1b. Verify form loaded

```bash
agent-browser --session [name] snapshot -i
```

**Expected elements:**

- Page heading `"Add Signal"`
- Search input (placeholder: `"Search symptoms..."`)
- `[data-testid="universal-navbar-footer"]` present in element tree
- `[data-testid="universal-navbar-wrapper"]` present in element tree

### 1c. Baseline navbar measurement (before focus)

```bash
agent-browser --session [name] eval \
  "document.querySelector('[data-testid=\"universal-navbar-wrapper\"]').getBoundingClientRect().bottom"
agent-browser --session [name] eval "window.innerHeight"
```

**Assertion — "Navbar bounding box bottom edge equals viewport bottom on each form page":**
Record the two values as `navbarBottom_before` and `viewportHeight`. They must be equal (delta 0, tolerance ±1px).

### 1d. Focus a text input

```bash
agent-browser --session [name] click @[search-input-ref]
agent-browser --session [name] wait --timeout 500
```

The search input ref comes from the `snapshot -i` output in step 1b.

### 1e. Post-focus navbar measurement

```bash
agent-browser --session [name] eval \
  "document.querySelector('[data-testid=\"universal-navbar-wrapper\"]').getBoundingClientRect().bottom"
```

**Assertion — "After focusing a text input, navbar bottom edge unchanged (delta == 0)":**
The value must equal `navbarBottom_before`. Any change indicates a CSS regression (e.g., a translateY re-introduced on the footer).

### 1f. Scroll-content padding assertion

```bash
agent-browser --session [name] eval \
  "getComputedStyle(document.querySelector('.overflow-y-auto, [class*=\"scroll\"], [class*=\"overflow\"]')).paddingBottom"
```

> **TODO:** The selector above targets the first scrollable container heuristically. If the Add Signal page uses a specific scroll container class, replace with the exact selector found via `snapshot -i`. Cross-reference `features/symptoms/` for the scroll container element.

**Assertion — "Scrollable content padding-bottom >= keyboard-clearance value when focused":**
The computed `padding-bottom` value should reflect `var(--bottom-nav-clearance)` (resolves to at least `calc(68px + 1rem + safe-area-inset)` ≈ 84px minimum on a device without safe area). In Chromium without a keyboard, the variable resolves to its base value. Verify the padding-bottom is non-zero and at least 68px.

### 1g. Blur and check errors

```bash
agent-browser --session [name] keyboard Escape
agent-browser --session [name] errors
```

Ignore `"Keyboard" plugin is not implemented on web` — this is a harmless Capacitor stub (see `common.md`).

---

## Step 2: Edit Signal — `/app/symptoms/edit/{id}`

> **Prerequisite:** This step requires at least one existing symptom in the test user's account. If no symptoms exist, log the following and skip to Step 3:
>
> ```
> SKIP: Edit Signal step — no symptoms found for test user. Re-run after completing Step 1 (Add Signal) to seed a symptom.
> ```

### 2a. Navigate to symptoms list

```bash
agent-browser --session [name] open "[BASE_URL]/app/symptoms"
agent-browser --session [name] set viewport 390 844
agent-browser --session [name] wait --load networkidle
```

### 2b. Click first symptom in list

```bash
agent-browser --session [name] snapshot -i
# Identify the first symptom card or list item in the snapshot
agent-browser --session [name] click @[first-symptom-ref]
agent-browser --session [name] wait --load networkidle
```

### 2c. Confirm route

```bash
agent-browser --session [name] eval "window.location.pathname"
```

**Expected:** Path matches `/app/symptoms/edit/[uuid]`. If not on an edit route, check for a redirect and re-run snapshot.

### 2d. Verify form loaded

```bash
agent-browser --session [name] snapshot -i
```

**Expected elements:**

- Page heading `"Edit Signal"` or similar
- At least one text input (date, notes, or search field)
- `[data-testid="universal-navbar-footer"]` present
- `[data-testid="universal-navbar-wrapper"]` present

### 2e. Baseline navbar measurement

```bash
agent-browser --session [name] eval \
  "document.querySelector('[data-testid=\"universal-navbar-wrapper\"]').getBoundingClientRect().bottom"
agent-browser --session [name] eval "window.innerHeight"
```

**Assertion — "Navbar bounding box bottom edge equals viewport bottom on each form page":**
`navbarBottom_before` == `viewportHeight` (tolerance ±1px).

### 2f. Focus a text input

```bash
agent-browser --session [name] click @[notes-or-search-input-ref]
agent-browser --session [name] wait --timeout 500
```

### 2g. Post-focus navbar measurement

```bash
agent-browser --session [name] eval \
  "document.querySelector('[data-testid=\"universal-navbar-wrapper\"]').getBoundingClientRect().bottom"
```

**Assertion — "After focusing a text input, navbar bottom edge unchanged (delta == 0)":**
Value must equal `navbarBottom_before`.

### 2h. Scroll-content padding assertion

```bash
agent-browser --session [name] eval \
  "getComputedStyle(document.querySelector('.overflow-y-auto, [class*=\"scroll\"], [class*=\"overflow\"]')).paddingBottom"
```

**Assertion — "Scrollable content padding-bottom >= keyboard-clearance value when focused":**
padding-bottom >= 68px (base clearance without safe area).

### 2i. Blur and check errors

```bash
agent-browser --session [name] keyboard Escape
agent-browser --session [name] errors
```

---

## Step 3: Food Entry — `/app/foods/new`

The canonical create route. The dashboard FAB redirects here (`app/(protected)/app/page.tsx:345`). The `[id]` segment handles the sentinel `new` to create a draft entry.

> **Do not use `/app/foods/{uuid}` directly** — that route redirects to `/app` for unknown UUIDs (see `food-page-client.tsx` lines 171, 254). Always use `/app/foods/new`.

### 3a. Navigate

```bash
agent-browser --session [name] open "[BASE_URL]/app/foods/new"
agent-browser --session [name] set viewport 390 844
agent-browser --session [name] wait --load networkidle
```

### 3b. Verify form loaded

```bash
agent-browser --session [name] snapshot -i
```

**Expected elements:**

- DateTimePicker at top
- ImageGallery (4-slot photo grid)
- VoiceRecorder
- Ingredient text input (placeholder: `"Type ingredient and press Enter"`)
- Camera button in bottom action bar
- `[data-testid="universal-navbar-footer"]` present
- `[data-testid="universal-navbar-wrapper"]` present

### 3c. Baseline navbar measurement

```bash
agent-browser --session [name] eval \
  "document.querySelector('[data-testid=\"universal-navbar-wrapper\"]').getBoundingClientRect().bottom"
agent-browser --session [name] eval "window.innerHeight"
```

**Assertion — "Navbar bounding box bottom edge equals viewport bottom on each form page":**
`navbarBottom_before` == `viewportHeight` (tolerance ±1px).

### 3d. Focus the ingredient text input

```bash
agent-browser --session [name] click @[ingredient-input-ref]
agent-browser --session [name] wait --timeout 500
```

The ingredient input ref comes from the `snapshot -i` output in step 3b.

### 3e. Post-focus navbar measurement

```bash
agent-browser --session [name] eval \
  "document.querySelector('[data-testid=\"universal-navbar-wrapper\"]').getBoundingClientRect().bottom"
```

**Assertion — "After focusing a text input, navbar bottom edge unchanged (delta == 0)":**
Value must equal `navbarBottom_before`.

### 3f. Scroll-content padding assertion

```bash
agent-browser --session [name] eval \
  "getComputedStyle(document.querySelector('.overflow-y-auto, [class*=\"scroll\"], [class*=\"overflow\"]')).paddingBottom"
```

**Assertion — "Scrollable content padding-bottom >= keyboard-clearance value when focused":**
padding-bottom >= 68px.

### 3g. Blur and check errors

```bash
agent-browser --session [name] keyboard Escape
agent-browser --session [name] errors
```

---

## Step 4: Camera Capture — via food entry bottom action bar

The camera page is reached from the food entry form by clicking the camera button in the bottom action bar. There is no keyboard input on this page (it is a camera viewfinder, not a form), so the focus/blur cycle is skipped. We only verify that the navbar position is correct.

### 4a. Ensure we are on the food entry page

If continuing from Step 3, the session is already on the food entry page. If starting fresh:

```bash
agent-browser --session [name] open "[BASE_URL]/app/foods/new"
agent-browser --session [name] set viewport 390 844
agent-browser --session [name] wait --load networkidle
```

### 4b. Click the camera button in the bottom action bar

```bash
agent-browser --session [name] snapshot -i
# Identify the camera button in the bottom action bar (look for "Camera" label or camera icon button)
agent-browser --session [name] click @[camera-button-ref]
agent-browser --session [name] wait --load networkidle
```

### 4c. Confirm camera route

```bash
agent-browser --session [name] eval "window.location.pathname"
```

**Expected:** Path matches `/app/foods/[id]/camera` where `[id]` is the draft UUID created when `/app/foods/new` was loaded.

### 4d. Verify navbar exists on camera page

```bash
agent-browser --session [name] snapshot -i
```

**Expected elements:**

- Camera viewfinder or permission prompt
- `[data-testid="universal-navbar-footer"]` present
- `[data-testid="universal-navbar-wrapper"]` present

### 4e. Navbar position assertion

```bash
agent-browser --session [name] eval \
  "document.querySelector('[data-testid=\"universal-navbar-wrapper\"]').getBoundingClientRect().bottom"
agent-browser --session [name] eval "window.innerHeight"
```

**Assertion — "Navbar bounding box bottom edge equals viewport bottom on each form page":**
`navbarBottom` == `viewportHeight` (tolerance ±1px).

> **Note:** No focus/blur cycle on this page — the camera page has no text inputs. Skip the "After focusing" and "padding-bottom" assertions for this step.

### 4f. Check errors

```bash
agent-browser --session [name] errors
```

Ignore `"Camera" plugin is not implemented on web` — harmless Capacitor stub on Chromium.

---

## Cleanup

```bash
agent-browser --session [name] close
```

---

## Validation Report

After completing all steps, fill in this report:

```markdown
BROWSER_VALIDATION:
environment: [local | preview | production]
session: [session-name]
viewport: 390x844

keyboard_navbar_smoke:
add_signal:
navbar_at_bottom_before_focus: PASS | FAIL | [measured: Xpx, viewport: 844px]
navbar_unchanged_after_focus: PASS | FAIL | [delta: Xpx]
scroll_padding_adequate: PASS | FAIL | [measured: Xpx, min: 68px]
console_errors: none | [list]

edit_signal:
status: PASS | FAIL | SKIPPED (no symptoms)
navbar_at_bottom_before_focus: PASS | FAIL | [measured: Xpx]
navbar_unchanged_after_focus: PASS | FAIL | [delta: Xpx]
scroll_padding_adequate: PASS | FAIL | [measured: Xpx]
console_errors: none | [list]

food_entry:
navbar_at_bottom_before_focus: PASS | FAIL | [measured: Xpx]
navbar_unchanged_after_focus: PASS | FAIL | [delta: Xpx]
scroll_padding_adequate: PASS | FAIL | [measured: Xpx]
console_errors: none | [list]

camera_capture:
navbar_at_bottom: PASS | FAIL | [measured: Xpx]
console_errors: none | [list]

overall_status: PASS | FAIL | PARTIAL
blocking_issues: [list if any]
screenshots: [list of paths, if captured]
```

---

## Out of Scope

Real-keyboard behavior on physical devices is outside the scope of this Chromium flow. The following rows from the cross-platform matrix are manual-only and are tracked in the checklist in `.claude/skills/design-system/keyboard-and-navbar.md`:

- Android Chrome (real device)
- Android Capacitor native build
- iOS Safari (real device)
- iOS Capacitor native build (Xcode required — Mac only)

---

## Reference Links

- **Cross-platform manual checklist:** `.claude/skills/design-system/keyboard-and-navbar.md` — covers the 4 non-Chromium platform rows (iOS Safari, iOS Capacitor, Android Chrome, Android Capacitor) and documents the full CSS variable chain.
- **Component and data-testid origin:** `bd-zkzf.1` — the refactor that extracted `<UniversalNavbarFooter>` and added `data-testid="universal-navbar-footer"` (outer footer) and `data-testid="universal-navbar-wrapper"` (inner centering div).
- **Regression target:** PR #239 (merged 2026-04-28) — removed keyboard-driven `translateY` from four form footers.
- **Common assertions:** `flows/common.md`
- **Auth flow:** `flows/login.md`
- **Food entry journey:** `journeys/food-entry.md`
- **Signal entry journey:** `journeys/signal-entry.md`
