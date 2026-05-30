# Dashboard Journey

View insights, entries, and navigate between tabs.

---

## Prerequisites

- Authenticated (complete `auth.md` login flow first)
- Mobile viewport set (`390 x 844`)

---

## Dashboard Structure

Single page at `/app` with three view states (no route change, uses `?view=` query param):

| Tab          | Query Param      | Content                                   |
| ------------ | ---------------- | ----------------------------------------- |
| **Insights** | `?view=insights` | Streaks, correlations, analytics (28 day) |
| **Entries**  | `?view=entries`  | Daily food/signal log with date nav       |
| **Settings** | `?view=settings` | Account, preferences, logout              |

**Navigation:** Bottom nav bar (mobile) with 3 tabs + FAB

---

## Happy Path: View Insights

### Steps

1. **Navigate to dashboard**

   ```bash
   agent-browser --session dash open "[BASE_URL]/app"
   agent-browser --session dash set viewport 390 844
   agent-browser --session dash wait --load networkidle
   ```

2. **Verify Insights tab is default**

   ```bash
   agent-browser --session dash snapshot -i
   ```

   **Checkpoint:** Insights tab active, showing:
   - Day streak counter
   - Days tracked counter
   - Total foods counter
   - Total signals counter
   - Baseline progress (if applicable)
   - Correlations section (if data exists)

3. **Check for loading states**

   **Checkpoint:** No infinite spinners. Data loads or shows empty state.

---

## Happy Path: View Entries

### Steps

1. **Click Entries tab**

   ```bash
   agent-browser --session dash click @[entries-tab]
   agent-browser --session dash wait --load networkidle
   ```

2. **Verify entries display**

   ```bash
   agent-browser --session dash snapshot -i
   ```

   **Checkpoint:** Shows either:
   - List of food and signal entries for current day
   - Empty state with prompt if no entries today

3. **Date navigation in header**

   ```bash
   # Navigate to previous day
   agent-browser --session dash click @[prev-day-ref]
   agent-browser --session dash wait --load networkidle

   # Click date label to return to today
   agent-browser --session dash click @[date-label-ref]
   agent-browser --session dash wait --load networkidle
   ```

   **Header elements:**
   - `button "Previous day"` (ChevronLeft)
   - Date label (shows "Today", "Yesterday", or abbreviated date)
   - `button "Next day"` (ChevronRight, disabled for today/future)

4. **Verify entry cards are interactive**

   **Checkpoint:** Entry cards clickable, navigate to edit page.

---

## Happy Path: Add Entry via FAB

### Steps

1. **Click FAB to expand**

   ```bash
   agent-browser --session dash click @[fab-ref]
   agent-browser --session dash snapshot -i
   ```

   **Checkpoint:** Two sub-buttons appear:
   - `"Log food entry"` (green, Utensils icon)
   - `"Log symptom signal"` (red, Activity icon)

2. **Click food or signal button**

   ```bash
   agent-browser --session dash click @[log-food-ref]
   agent-browser --session dash wait --load networkidle
   ```

   **Checkpoint:** Navigates to food entry page (`/app/foods/[draftId]`)

---

## Happy Path: Navigate to Settings

### Steps

1. **Click Settings tab**

   ```bash
   agent-browser --session dash click @[settings-tab]
   agent-browser --session dash wait --load networkidle
   ```

2. **Verify settings view**

   ```bash
   agent-browser --session dash snapshot -i
   ```

   **Checkpoint:** Shows Account, Preferences, App Information, Logout button.

---

## Insights Components

When testing insights, verify these sections (if user has data):

### Streak Counter

- Current streak number displayed (flame icon in header)

### Baseline Progress

- Shows progress toward baseline period
- Progress bar or percentage visible

### Red Alert Section

- Foods with strong negative correlations
- Clear visual indicator (red)

### Top Suspects Section

- Foods with moderate negative correlations
- List format with correlation strength

### Safe Foods Section

- Foods with no adverse patterns detected, shown with green tint
- Rendered by `methodology-suspects-list` with `variant="safe"`
- Header: "Safe Foods — no adverse patterns detected"
- Distinct from Top Suspects visually (green container vs. default card list)

### Symptom Correlations

- Correlation data display
- Interactive elements work

---

## Edge Cases

### New User (No Data)

1. Login as user with no entries

**Expected:**

- Insights shows onboarding state
- Entries shows empty state with CTA
- No errors or loading forever

### Lots of Data

1. Login as user with many entries

**Expected:**

- Data loads without timeout
- Scroll works
- No performance issues

### Tab Switching

1. Rapidly switch between tabs

**Expected:**

- No duplicate content
- No stale data
- Loading states show appropriately

---

## Mobile Considerations

- Bottom nav bar accessible (fixed position with safe area padding)
- FAB visible and expandable
- Content scrolls properly in viewport
- Touch targets for tab switches adequate (44px minimum)
- Date navigation arrows accessible in header
- Correlation visualizations readable on small screens

---

## Validation Report

```markdown
DASHBOARD_VALIDATION:
insights_tab:
loads: PASS | FAIL
streak_visible: PASS | FAIL
correlations_load: PASS | FAIL | N/A (no data)
entries_tab:
loads: PASS | FAIL
entries_visible: PASS | FAIL | N/A (no data)
date_navigation: PASS | FAIL
entry_clickable: PASS | FAIL | N/A
fab:
expands: PASS | FAIL
food_button: PASS | FAIL
signal_button: PASS | FAIL
settings_tab:
loads: PASS | FAIL
content_visible: PASS | FAIL
navigation:
tab_switching: PASS | FAIL
no_console_errors: PASS | FAIL
status: PASS | FAIL
```
