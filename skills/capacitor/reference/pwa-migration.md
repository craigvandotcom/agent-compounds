# PWA to Native Migration Gotchas

**When to read:** Migrating PWA features to Capacitor native, debugging iOS storage issues, auth token loss, CORS errors, or environment detection problems on WKWebView.

---

## WKWebView Limitations (iOS)

- **Service workers NOT supported** in WKWebView. Capacitor runtime handles asset serving instead.
- **Storage eviction:** iOS evicts `localStorage` AND `IndexedDB` from WKWebView when device storage is low. Auth tokens in localStorage get wiped, causing random logouts.
- **`sessionStorage` is ephemeral:** Each Capacitor page load clears it (each static page = separate HTML load).

---

## What to Replace

| PWA Feature                         | Replace With                               |
| ----------------------------------- | ------------------------------------------ |
| Service worker (offline cache)      | Capacitor asset serving (automatic)        |
| `navigator.camera` / `getUserMedia` | `@capacitor/camera`                        |
| `localStorage` (auth tokens)        | `@capacitor/preferences` (UserDefaults)    |
| Web push notifications              | `@capacitor/push-notifications` (APNs/FCM) |
| `navigator.share`                   | `@capacitor/share` (native sheet)          |
| PWA install prompt                  | Remove — native app is already installed   |
| IndexedDB (critical data)           | `@capacitor-community/sqlite`              |

---

## Supabase Storage Adapter

Replace cookie/localStorage auth with native Preferences to prevent token eviction on iOS:

```typescript
// lib/supabase/capacitor-storage.ts
import { Preferences } from '@capacitor/preferences';
import type { SupportedStorage } from '@supabase/supabase-js';

export const capacitorStorage: SupportedStorage = {
  async getItem(key: string) {
    const { value } = await Preferences.get({ key });
    return value;
  },
  async setItem(key: string, value: string) {
    await Preferences.set({ key, value });
  },
  async removeItem(key: string) {
    await Preferences.remove({ key });
  },
};

// In createClient():
import { isNativePlatform } from '@/lib/utils/platform';
const client = createBrowserClient(url, key, {
  auth: {
    storage: isNativePlatform() ? capacitorStorage : undefined,
  },
});
```

---

## CORS Architecture (Next.js + Capacitor)

**Single-source pattern:** CORS headers live in `next.config.mjs` `headers()`, applied to `/api/:path*`. This covers ALL HTTP methods including OPTIONS — no per-route CORS logic needed.

**OPTIONS handlers:** Each API route exports a bare `OPTIONS()` function returning `corsPreflightResponse()` from `@/lib/cors` (returns `new Response(null, { status: 204 })`). Do NOT set CORS headers in the OPTIONS handler — browsers reject duplicate `Access-Control-Allow-Origin` headers.

**Allowed origins:**

- iOS: `capacitor://localhost`
- Android: `http://localhost` (add to next.config.mjs when Android support ships)

**Reference files:**

- `next.config.mjs` — CORS header definitions (single source of truth)
- `lib/cors.ts` — `corsPreflightResponse()` helper
- All `app/api/*/route.ts` files — export `OPTIONS` function

---

## Background Navigation

`fetch()` calls launched after `router.push()` are killed in WKWebView (new HTML page loads). Always `await` async work before navigating.

---

## Environment Detection

`capacitor://localhost` has `hostname === 'localhost'`. Check `isNativePlatform()` BEFORE hostname-based environment detection to avoid misidentifying production native as dev.
