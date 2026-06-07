# Cold-Start & Auth Bootstrap (CRITICAL)

For Next.js `output: 'export'` Capacitor apps with auth, **middleware does NOT run** — there is no server to run it on. Without a bootstrap gate, the first paint resolves to whichever route the router thinks matches the URL _before_ auth state settles, which for `~90% authed users` is the **login skeleton flashing for 200–600ms** before the dashboard. This is structural, not a styling bug.

## The fix: one `isBootstrapped` gate at the route-tree root

```typescript
// features/auth/components/auth-provider.tsx
export function AuthProvider({ children }) {
  const [user, setUser] = useState<User | null>(null);
  const [isBootstrapped, setIsBootstrapped] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        setUser(user);
      } catch {
        // Network unreachable — render optimistically; RLS protects data
      } finally {
        setIsBootstrapped(true); // STICKY: never set back to false
      }
    })();
  }, []);

  return <Ctx.Provider value={{ user, isBootstrapped }}>{children}</Ctx.Provider>;
}
```

```tsx
// app/layout.tsx
<AuthProvider>{isBootstrapped ? children : <BrandedLoader />}</AuthProvider>
```

## The 6-case failure-mode contract (encode in tests)

1. **Happy path (authed):** cached-authed flag = true → loader → `getUser()` returns user → `isBootstrapped=true` → route tree mounts → `/app`. **No login chrome paints.**
2. **Token expired:** cached-authed flag = true → `getUser()` returns null → clear cached flag → `/login`. User briefly sees loader, then login — acceptable; rare.
3. **Network unreachable on cold start:** `getUser()` throws → **render `/app` shell optimistically** (last-known-authed). Subsequent API calls trigger normal error UI; RLS prevents data corruption. Do NOT bounce to `/login` (that's the bug we're fixing). Retry on `@capacitor/network` `networkStatusChange` or `App.resume`.
4. **No cached flag:** never logged in → `isBootstrapped=true` immediately → `/login`.
5. **Token-refresh racing the bootstrap:** Supabase JS handles refresh internally; bootstrap waits on `getUser()` outcome. Belt-and-braces: skip retry if `supabase.auth.onAuthStateChange` is mid-`TOKEN_REFRESHED`.
6. **Stickiness invariant — `isBootstrapped` NEVER transitions back to false.** A late `getUser()` resolving null does not yank the user mid-interaction. Instead, a 401 interceptor catches failing API calls and surfaces a "session expired" modal (below).

## Splash → JS handoff

In `capacitor.config.ts`:

```typescript
plugins: {
  SplashScreen: {
    launchAutoHide: false,        // KEY: hold splash until JS dismisses
    backgroundColor: '#<brand>',  // match your branded loader so the handoff is invisible
    androidScaleType: 'CENTER_CROP',
  },
},
```

Then in your app's bootstrap, dismiss the splash _after_ React has mounted the branded loader, so the user never sees a blank WKWebView:

```typescript
import { SplashScreen } from '@capacitor/splash-screen';
import { Capacitor } from '@capacitor/core';

useEffect(() => {
  if (Capacitor.isPluginAvailable('SplashScreen')) {
    SplashScreen.hide(); // After loader is on screen
  }
}, []);
```

## 401 interceptor + session-expired modal (supports case 6)

Wrap your SWR fetcher / Supabase client to detect 401 responses. On first 401 after `isBootstrapped=true`:

- Set a global `sessionExpired` state.
- Suppress further toasts (avoid 401 toast storm on every refetch).
- Mount a single `<SessionExpiredModal />` at the route-tree root with a "Sign in again" button.
- **Do NOT navigate immediately** — preserve any in-progress form state.
- Also triggered by `onAuthStateChange('SIGNED_OUT')` from another tab/window.

## Server-safe module split (the three-file pattern)

Any module implementing bootstrap / auth / instrumentation state is transitively imported from `lib/utils/api-client.ts` — which itself is imported by server-side API route handlers. Importing React or any client-only dep at the top of such a module crashes the production build with "React hook in server context" or "Export X doesn't exist in target module."

The canonical split:

| File                           | Directive            | What lives here                                                                                                                                               |
| ------------------------------ | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/<feature>/<thing>.ts`     | (none — server-safe) | Module-level state, `_subscribe`/`_getSnapshot` bridge, imperative API (`markX`, `resetX`). No React imports. No top-level `swr`, `@capacitor/*`, `window.*`. |
| `lib/<feature>/use-<thing>.ts` | `'use client'`       | `useSyncExternalStore` hook over (1). React consumers import this.                                                                                            |
| Client-only deps in (1)        | —                    | Dynamic-import inside function bodies: `const { mutate } = await import('swr')`. Never at module top.                                                         |

**Why:** the same module is reachable from both a React tree (needs hooks) AND an API-route execution graph (no React, no DOM). Splitting by directive boundary preserves both call paths.

**Canonical examples in this codebase (all from the app-first-feel wave):**

- `lib/instrumentation/cold-start.ts` (server-safe) + `lib/instrumentation/use-cold-start-measures.ts` (`'use client'` hook).
- `lib/auth/session-expired-interceptor.ts` (server-safe) + `lib/auth/use-session-expired.ts` (`'use client'` hook).
- `session-expired-interceptor.ts:wipeAllLocalData` dynamic-imports `swr` and `@capacitor/preferences` inside the function body rather than at module top.

**Trip-wire diagnostic:** if `pnpm build` fails after adding a hook/state module under `lib/auth/`, `lib/instrumentation/`, or any auth-bootstrap path, but `pnpm test` and `pnpm type-check` pass, this is almost certainly the bug. `pnpm test` passes because vitest doesn't exercise the server-side import graph. Look for top-level imports of React, `swr`, `@capacitor/preferences`, or anything that reads `window` / `document` / `localStorage` synchronously at module scope.

## Acceptance test (silver bullet)

A Playwright test that boots with a cached-authed flag set + a mocked `getUser()` and asserts **zero paints** of login chrome before the dashboard renders. This is the regression gate for the whole pattern; ship it with the first implementation.
