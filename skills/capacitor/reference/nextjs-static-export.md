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
