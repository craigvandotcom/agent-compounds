# Authentication Journey

Login, logout, and session handling flows.

---

## Prerequisites

- Dev server running (`pnpm dev`) for local
- Valid test credentials (see `../environments.md`)

---

## Happy Path: Login

### Steps

1. **Navigate to login page**

   ```bash
   agent-browser --session auth open "[BASE_URL]/login"
   agent-browser --session auth wait --load networkidle
   ```

2. **Verify login form loaded**

   ```bash
   agent-browser --session auth snapshot -i
   ```

   **Checkpoint:** Form contains:
   - `textbox "Email"`
   - `textbox "Password"`
   - `button "Continue Your Journey"`

3. **Fill credentials**

   ```bash
   agent-browser --session auth fill @[email-ref] "[EMAIL]"
   agent-browser --session auth fill @[password-ref] "[PASSWORD]"
   ```

4. **Submit login**

   ```bash
   agent-browser --session auth click @[submit-ref]
   agent-browser --session auth wait --timeout 15000 --url "/app"
   ```

5. **Verify dashboard loaded**

   ```bash
   agent-browser --session auth snapshot -i
   ```

   **Checkpoint:** Dashboard contains:
   - `button "Insights"`
   - `button "Entries"`
   - `button "Settings"`

---

## Happy Path: Logout

### Steps

1. **Navigate to settings tab**

   ```bash
   agent-browser --session auth click @[settings-ref]
   agent-browser --session auth wait --load networkidle
   ```

   Settings is a tab within `/app`, not a separate route. Can also navigate via `[BASE_URL]/app?view=settings`.

2. **Find and click logout**

   ```bash
   agent-browser --session auth snapshot -i
   # Find "Logout" button (label is "Logout", not "Sign Out")
   agent-browser --session auth click @[logout-ref]
   ```

3. **Verify redirected to home**

   ```bash
   agent-browser --session auth wait --url "/"
   agent-browser --session auth snapshot -i
   ```

   **Checkpoint:** On landing page (redirects to `/`, not `/login`).

---

## Edge Cases

### Invalid Credentials

**Steps:**

1. Enter wrong email/password
2. Submit form

**Expected:**

- Stays on `/login`
- Error message displayed
- Form fields remain filled

**Checkpoint:** `snapshot -i` shows error text.

### Session Expired

**Steps:**

1. Navigate to protected route after session expires

**Expected:**

- Redirected to `/login`
- No error, just redirect

### Supabase Environment Mismatch

**Symptom:** Login fails silently or shows "Invalid credentials"

**Cause:** Local credentials used on preview/prod (different Supabase instances)

**Solution:** Check `environments.md` for correct credentials per environment.

---

## Mobile Considerations

- Touch targets for form fields are adequately sized
- Keyboard appears when focusing inputs
- "Continue Your Journey" button visible without scrolling on smaller viewports

---

## Validation Report

```markdown
AUTH_VALIDATION:
login_flow:
form_loads: PASS | FAIL
credentials_accepted: PASS | FAIL
redirect_to_app: PASS | FAIL
logout_flow:
logout_button_visible: PASS | FAIL
redirect_to_home: PASS | FAIL
status: PASS | FAIL
```
