# Dashboard Validation Flow

Validate dashboard functionality after successful login.

## Dashboard Structure

The dashboard is a **single page at `/app`** with three view states controlled by bottom navigation. Views switch via `?view=` query param (no route change).

- **Insights** (default) - Analytics, streaks, correlations. Header: "Last 28 Days"
- **Entries** - Daily food/signal log with date navigation. Header: prev/next day arrows + date
- **Settings** - Account and preferences. Header: "Settings"

**Navigation (mobile):** Bottom nav bar with three tabs + FAB (floating action button)

## Mobile Viewport Setup (CRITICAL)

```bash
# Always set mobile viewport first — this is a mobile-first PWA
agent-browser --session [name] set viewport 390 844
```

## Quick Smoke Test

```bash
# After login, verify dashboard loads
agent-browser --session [name] snapshot -i
agent-browser --session [name] errors
```

**Expected elements:**

- `button "Insights"` (active by default)
- `button "Entries"`
- `button "Settings"`
- FAB button (`"Open quick actions"` aria-label)
- Streak counter (flame icon + number in header)
- Days tracked counter

**No critical errors** - ignore 404s for favicons/manifest.

---

## FAB (Floating Action Button)

The FAB is the **primary way users add entries**. It's a "+" button that expands to two sub-buttons.

### Test FAB

```bash
# Click FAB to expand
agent-browser --session [name] click @[fab-ref]
agent-browser --session [name] snapshot -i
```

**Expected expanded state:**

- `button "Log food entry"` (green tinted, Utensils icon)
- `button "Log symptom signal"` (red tinted, Activity icon)

### Add Food via FAB

```bash
agent-browser --session [name] click @[log-food-ref]
agent-browser --session [name] wait --load networkidle
```

**Expected:** Navigates to `/app/foods/[draftId]` (creates draft first)

### Add Signal via FAB

```bash
agent-browser --session [name] click @[log-signal-ref]
agent-browser --session [name] wait --url "/app/symptoms/add"
```

**Expected:** Navigates to `/app/symptoms/add`

---

## Tab Navigation

### Switch to Entries Tab

```bash
agent-browser --session [name] click @[entries-ref]
agent-browser --session [name] wait --load networkidle
agent-browser --session [name] snapshot -i
```

**Expected on Entries tab:**

- Food entry cards (if any exist for current day)
- Signal entry cards (if any exist for current day)
- Date navigation in header (prev/next day arrows)
- Empty state with prompt if no entries

### Entries Date Navigation

```bash
# Navigate to previous day
agent-browser --session [name] click @[prev-day-ref]
agent-browser --session [name] wait --load networkidle
agent-browser --session [name] snapshot -i

# Navigate back to today
agent-browser --session [name] click @[date-label-ref]
agent-browser --session [name] wait --load networkidle
```

**Header elements:**

- `button "Previous day"` (ChevronLeft icon)
- Date label button (shows "Today", "Yesterday", or abbreviated date)
- `button "Next day"` (ChevronRight icon, disabled when viewing today/future)

### Switch to Settings Tab

```bash
agent-browser --session [name] click @[settings-ref]
agent-browser --session [name] wait --load networkidle
agent-browser --session [name] snapshot -i
```

**Expected on Settings tab:**

- Account section (email, member since)
- Preferences section (camera-first entry toggle)
- App Information (version, build, platform)
- "Logout" button

---

## Direct Tab Navigation via URL

```bash
# Navigate directly to a specific tab
agent-browser --session [name] open "[BASE_URL]/app?view=entries"
agent-browser --session [name] set viewport 390 844
agent-browser --session [name] wait --load networkidle
```

---

## Insights Tab Validation

```bash
agent-browser --session [name] snapshot -i
```

**Key elements to verify:**

- Day streak display
- Days tracked counter
- Total foods counter
- Total signals counter
- Baseline progress section
- Red Alert section
- Top Suspects section
- Safe Yellows section
- Symptom Correlations section

---

## Dashboard Assertions

### Has No Critical Errors

```bash
agent-browser --session [name] errors
```

Filter out non-critical:

- Manifest errors
- Favicon 404s
- Deprecation warnings

### All Tabs Accessible

```bash
# Click through each tab
agent-browser --session [name] click @[insights-ref]
agent-browser --session [name] wait --load networkidle

agent-browser --session [name] click @[entries-ref]
agent-browser --session [name] wait --load networkidle

agent-browser --session [name] click @[settings-ref]
agent-browser --session [name] wait --load networkidle
```

### Data Loads

After switching tabs, snapshot should show actual content, not loading spinners.
