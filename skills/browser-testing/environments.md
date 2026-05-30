# Browser Testing Environments

## Environment Configuration

### Local Development

```yaml
name: local
base_url: http://localhost:3000
supabase: prod (spilwpcqjncrxptqdggn)
credentials_source: .env.local
start_command: pnpm dev
```

**Credentials:**

- `TEST_USER_EMAIL` from `.env.local`
- `TEST_USER_PASSWORD` from `.env.local`

**Pre-requisites:**

- Dev server running (`pnpm dev`)
- `.env.local` configured with test credentials

---

### Vercel Preview

```yaml
name: preview
base_url: https://[deployment-id]-craigvandotcoms-projects.vercel.app
supabase: prod (spilwpcqjncrxptqdggn)
credentials_source: Vercel env vars
```

**Get preview URL:**

```bash
vercel ls --yes 2>&1 | grep "Preview" | head -1 | awk '{print $2}'
```

**Credentials:**

- Email: `test@bodycompass.app`
- Password: `12345abcde`

**Pre-requisites:**

- Branch pushed to remote
- Vercel deployment ready

---

### Production

```yaml
name: production
base_url: https://www.bodycompass.app
supabase: prod (spilwpcqjncrxptqdggn)
credentials_source: Vercel env vars
```

**Credentials:**

- Same as preview (prod Supabase)

**Caution:** Production testing should be read-only or use dedicated test account.

---

## Credential Lookup

### Reading from .env.local (Local Dev)

Claude can read `.env.local` directly:

```bash
# In .env.local:
TEST_USER_EMAIL="craigvh89@gmail.com"
TEST_USER_PASSWORD="..."
```

When executing browser tests, read these values and use them in agent-browser commands.

### Preview/Production Credentials

Hardcoded in this file for Claude's reference:

- **Email:** `test@bodycompass.app`
- **Password:** `12345abcde`

These are set in Vercel environment variables for the TEST*USER*\* vars.

---

## Route Classification

### Public Routes (No Auth Required)

| Route      | Description      |
| ---------- | ---------------- |
| `/`        | Landing page     |
| `/login`   | Login form       |
| `/signup`  | Signup form      |
| `/about`   | About page       |
| `/privacy` | Privacy policy   |
| `/terms`   | Terms of service |
| `/offline` | Offline fallback |

### Protected Routes (Auth Required)

| Route                     | Description                      |
| ------------------------- | -------------------------------- |
| `/app`                    | Dashboard (Insights tab default) |
| `/app?view=entries`       | Dashboard - Entries tab          |
| `/app?view=settings`      | Dashboard - Settings tab         |
| `/app/foods/new`          | New food entry                   |
| `/app/foods/[id]`         | Edit food entry                  |
| `/app/foods/[id]/camera`  | Camera capture for food entry    |
| `/app/symptoms/add`       | Add signal                       |
| `/app/symptoms/edit/[id]` | Edit signal                      |

**Note:** Settings is a tab within `/app`, not a separate `/settings` route. Use `?view=settings` to navigate directly.

---

## Environment Detection

```bash
# Detect current environment from URL
if [[ "$URL" == *"localhost"* ]]; then
  ENV="local"
elif [[ "$URL" == *"vercel.app"* ]]; then
  ENV="preview"
else
  ENV="production"
fi
```
