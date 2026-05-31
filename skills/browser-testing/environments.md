# Browser Testing Environments

> **Generic template.** Fill in the values below for each app. App-specific URLs,
> credentials, and route tables belong in the consuming app's CORE — not here.

## Environment Configuration

### Local Development

```yaml
name: local
base_url: http://localhost:<port>         # typically 3000
auth_backend: <dev or prod — check app>
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
base_url: https://[deployment-id]-<team>.vercel.app
auth_backend: prod (same as production)
credentials_source: Vercel env vars / app CORE
```

**Get preview URL:**

```bash
vercel ls --yes 2>&1 | grep "Preview" | head -1 | awk '{print $2}'
```

**Credentials:** See the consuming app's CORE (`environments.md` or `SKILL.md`) for
the test account email/password used in preview/production.

**Pre-requisites:**

- Branch pushed to remote
- Vercel deployment ready

---

### Production

```yaml
name: production
base_url: https://<app-production-url>
auth_backend: prod
credentials_source: Vercel env vars / app CORE
```

**Caution:** Production testing should be read-only or use a dedicated test account.

---

## Credential Lookup

### Reading from .env.local (Local Dev)

Claude can read `.env.local` directly:

```bash
# In .env.local:
TEST_USER_EMAIL="<your-test-email>"
TEST_USER_PASSWORD="<your-test-password>"
```

When executing browser tests, read these values and use them in `agent-browser` commands.

### Preview / Production Credentials

Stored in the consuming app's CORE (`.claude/skills/CORE/SKILL.md` or a dedicated
`environments.md` inside CORE). Never store live credentials in this generic skill.

---

## Route Classification

Route tables (which routes are public vs protected, what query params control tab
state, etc.) are app-specific. Read the consuming app's CORE for its route map.

**Pattern to follow in each app's CORE:**

| Route        | Auth required | Description        |
| ------------ | ------------- | ------------------ |
| `/`          | No            | Landing / home     |
| `/login`     | No            | Login form         |
| `/signup`    | No            | Registration form  |
| `/app`       | Yes           | Main app entry     |
| `...`        | ...           | (app-specific)     |

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
