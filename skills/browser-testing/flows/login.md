# Login Flow

Standard authentication flow for all environments.

## Login Steps

### 1. Navigate to Login Page

```bash
agent-browser --session [name] open "[BASE_URL]/login"
agent-browser --session [name] wait --load networkidle
```

### 2. Verify Form Loaded

```bash
agent-browser --session [name] snapshot -i
```

**Expected elements:**

- `textbox "Email"`
- `textbox "Password"`
- `button "Continue Your Journey"`

If you see only "Loading..." - wait longer or check server status.

### 3. Fill Credentials

```bash
# Get element refs from snapshot
agent-browser --session [name] fill @[email-ref] "[EMAIL]"
agent-browser --session [name] fill @[password-ref] "[PASSWORD]"
```

**Environment-specific credentials:**

| Environment | Email                  | Password Source        |
| ----------- | ---------------------- | ---------------------- |
| local       | Read from `.env.local` | Read from `.env.local` |
| preview     | `test@bodycompass.app` | `12345abcde`           |
| production  | `test@bodycompass.app` | `12345abcde`           |

### 4. Submit Login

```bash
agent-browser --session [name] click @[submit-ref]
```

The submit button is labeled "Continue Your Journey" (not "Sign In").

### 5. Wait for Redirect

```bash
agent-browser --session [name] wait --timeout 15000 --url "/app"
```

### 6. Verify Dashboard

```bash
agent-browser --session [name] snapshot -i
```

**Expected elements on success:**

- `button "Insights"`
- `button "Entries"`
- `button "Settings"`

---

## Complete Login Flow (Copy-Paste)

### Local Development

```bash
# Read credentials from .env.local first, then:
agent-browser --session local open "http://localhost:3000/login"
agent-browser --session local wait --load networkidle
agent-browser --session local snapshot -i
# Use refs from snapshot:
agent-browser --session local fill @e3 "[TEST_USER_EMAIL]"
agent-browser --session local fill @e4 "[TEST_USER_PASSWORD]"
agent-browser --session local click @e6
agent-browser --session local wait --timeout 15000 --url "/app"
agent-browser --session local snapshot -i
agent-browser --session local errors
```

### Vercel Preview

```bash
# Get preview URL first:
PREVIEW_URL=$(vercel ls --yes 2>&1 | grep "Preview" | head -1 | awk '{print $2}')

agent-browser --session preview open "$PREVIEW_URL/login"
agent-browser --session preview wait --load networkidle
agent-browser --session preview snapshot -i
# Use refs from snapshot:
agent-browser --session preview fill @e3 "test@bodycompass.app"
agent-browser --session preview fill @e4 "12345abcde"
agent-browser --session preview click @e6
agent-browser --session preview wait --timeout 15000 --url "/app"
agent-browser --session preview snapshot -i
agent-browser --session preview errors
```

---

## Login Failure Handling

**Invalid credentials:**

- Page stays on `/login`
- Error message appears
- Retry with correct credentials or report auth failure

**Supabase mismatch:**

- Local uses dev Supabase - preview/prod credentials won't work
- Preview/prod use prod Supabase - local credentials won't work

**Session timeout:**

- Login again if session expired
- Check for redirect to `/login`

---

## Session Persistence Warning

`agent-browser` sessions do NOT reliably persist cookies or auth state across
every invocation. If a test flow navigates away from the app (e.g. redirect
to the marketing landing page after "Save entry") and you lose the
authenticated session:

1. **Do not report it as an application regression** unless you can reproduce
   it in a real browser with a persistent cookie store.
2. Re-login using the standard flow above and retry the step.
3. If the save action itself looks like the cause, verify by checking
   `agent-browser --session [name] errors` for actual JS exceptions — not
   just console warnings like `"Keyboard" plugin is not implemented on web`
   (Capacitor stubs that are harmless on web — see `common.md`).
4. If still suspicious, file a P1 follow-up bead so the issue gets verified
   manually in the next session rather than blocking session close.

---

## Logout Flow

Settings is a tab within the dashboard, not a separate route.

```bash
# Navigate to settings tab
agent-browser --session [name] open "[BASE_URL]/app?view=settings"
agent-browser --session [name] wait --load networkidle
agent-browser --session [name] snapshot -i
# Find "Logout" button in snapshot (button label is "Logout", not "Sign Out")
agent-browser --session [name] click @[logout-ref]
# Logout redirects to home page (/), not /login
agent-browser --session [name] wait --url "/"
```
