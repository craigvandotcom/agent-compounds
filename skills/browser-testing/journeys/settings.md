# Settings Journey

User preferences and account management.

Settings is a **tab within the dashboard** at `/app?view=settings`, not a separate route.

---

## Prerequisites

- Authenticated (complete `auth.md` login flow first)
- On dashboard (`/app`)
- Mobile viewport set (`390 x 844`)

---

## Happy Path: View Settings

### Steps

1. **Navigate to settings**

   ```bash
   agent-browser --session settings open "[BASE_URL]/app?view=settings"
   agent-browser --session settings set viewport 390 844
   agent-browser --session settings wait --load networkidle
   ```

   Or click the Settings tab from dashboard:

   ```bash
   agent-browser --session settings click @[settings-tab]
   agent-browser --session settings wait --load networkidle
   ```

2. **Verify settings view**

   ```bash
   agent-browser --session settings snapshot -i
   ```

   **Checkpoint:** Settings view contains these sections:

---

## Settings Sections (Actual)

### 1. Account (User icon)

- **Email** - Displays user's email address
- **Member Since** - Formatted date of account creation

### 2. Preferences (Settings icon)

- **Camera-first entry** toggle (Switch component)
  - Description: "Open camera immediately when adding food"
  - Default: off

### 3. AI Model Settings (Admin only)

- Only visible if `isAdminUser(user.email)` returns true
- Not visible for regular test accounts

### 4. App Information (Smartphone icon)

- **Version** - App version number
- **Build** - Build identifier
- **Platform** - Current platform

### 5. Logout (LogOut icon)

- Button label: **"Logout"** (not "Sign Out")
- Loading state: **"Logging out..."** with spinner
- Redirects to `/` (home page) on success

---

## Happy Path: Toggle Camera-First Preference

### Steps

1. **Navigate to settings**
2. **Find camera-first toggle**

   ```bash
   agent-browser --session settings snapshot -i
   # Find switch for "Camera-first entry"
   ```

3. **Toggle the switch**

   ```bash
   agent-browser --session settings click @[camera-toggle-ref]
   ```

4. **Verify change persisted**

   Navigate away and return:

   ```bash
   agent-browser --session settings click @[insights-tab]
   agent-browser --session settings wait --load networkidle
   agent-browser --session settings click @[settings-tab]
   agent-browser --session settings wait --load networkidle
   agent-browser --session settings snapshot -i
   ```

   **Checkpoint:** Toggle state preserved after navigation.

---

## Happy Path: Logout

See `auth.md` logout flow.

---

## Edge Cases

### Settings Persistence

1. Toggle camera-first preference
2. Navigate to different tab
3. Return to settings

**Expected:** Toggle state persisted

### Logout While Offline

1. Go offline
2. Attempt logout

**Expected:** Either works locally or shows appropriate error

---

## Mobile Considerations

- All settings sections stack vertically
- Toggle switch has adequate touch target
- Logout button clearly visible
- No horizontal scroll required

---

## Validation Report

```markdown
SETTINGS_VALIDATION:
page_loads: PASS | FAIL
account_visible: PASS | FAIL
email_displayed: PASS | FAIL
preferences_toggle: PASS | FAIL
app_info_visible: PASS | FAIL
logout_visible: PASS | FAIL
status: PASS | FAIL
```
