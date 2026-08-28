# Next.js Static Export for Capacitor

**When to read:** Configuring Next.js for Capacitor builds, debugging static export errors, handling dynamic routes, or working with Server Components in the native context.

Capacitor requires static HTML/CSS/JS output. SSR does not work in native apps.

---

## next.config.mjs

```typescript
const isCapacitorBuild = process.env.BUILD_TARGET === 'capacitor';

const nextConfig = {
  ...(isCapacitorBuild && {
    output: 'export',
    images: { unoptimized: true },
    // trailingSlash NOT needed — capacitor://localhost handles routing
    // assetPrefix NOT needed for same reason
  }),
};
```

---

## Dynamic Routes

`useParams()` is broken in static export (Next.js #64660, unresolved). Use query params instead:

```typescript
// Instead of /foods/[id]/page.tsx with useParams()
// Use /foods/view?id=123 with useSearchParams()
'use client';
import { useSearchParams } from 'next/navigation';

export default function FoodViewPage() {
  const id = useSearchParams().get('id');
  // ...
}
```

For `generateStaticParams()`, return `[]` to opt out of build-time generation. Do NOT add `dynamicParams = false` alongside it — causes known conflicts.

---

## Server Components Constraint

Static export executes Server Components at BUILD time only. Any runtime server dependency breaks the build:

```typescript
// BREAKS static export:
import { cookies } from 'next/headers';
export default async function Page() {
  const c = await cookies(); // ERROR
}

// OK — executes at build time, produces static HTML:
export default function Layout({ children }) {
  return <div>{children}</div>;
}
```

Server Actions are incompatible with static export. Use API routes on the web build, direct Supabase calls on native.

---

## Build Command

```bash
BUILD_TARGET=capacitor pnpm build && npx cap sync
```

---

## Environment variables — NEXT_PUBLIC discipline

- **`NEXT_PUBLIC_*` is for publishable-safe values ONLY — never a sensitivity toggle.**
  Anything secret, or any permission-gate allowlist, must be **server-only and enforced
  server-side**. Do NOT invent a `NEXT_PUBLIC_*` allowlist for gating; **reuse the existing
  `ADMIN_EMAILS → /api/me → isAdmin` server pattern** — native DOES reach `/api/me` even under
  static export. `output: 'export'` pre-renders PAGES; it does NOT remove runtime fetches to
  deployed API routes (those run on Vercel, not in the shipped native binary).
- **`NEXT_PUBLIC_*` inlines at BUILD time.** Enabling a dark feature/flag needs a **Vercel
  redeploy AND a new native build** (set in both Vercel and `.env.local`); a runtime env change
  does nothing to an already-built bundle — an already-archived TestFlight/App-Store binary
  won't pick up a later flag. (PostHog: 3 vars, ships with autocapture off — browsing/login
  produces zero events; only explicit `track()` calls register.)
- **Non-prefixed env vars are two-valued.** Only `NEXT_PUBLIC_*` reaches the browser
  bundle: a bare `process.env` read in a module a client component imports resolves to the
  **default** in the browser and the **env value** on the server, with no warning. Never
  read a non-`NEXT_PUBLIC_` env var in code reachable from `'use client'`; a shared config
  module is such code.
- **`NEXT_PUBLIC_*` keys trip gitleaks' generic-api-key rule** (false positive on publishable
  client keys, e.g. a PostHog `phc_…` project key). Allowlist via a `.gitleaksignore`
  `file:rule:line` fingerprint, not by loosening the rule — re-confirm the fingerprint after
  big edits (line-number-based, shifts as the file grows).

Mnemonic: **"if it gates access or unlocks privilege, it never gets `NEXT_PUBLIC_`."** Every
Next.js-static-export + Capacitor app in the portfolio shares this constraint.
