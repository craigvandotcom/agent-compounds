---
name: capacitor
description: Use for TypeScript development in Capacitor projects. Activate when user mentions "Capacitor", "native app", "iOS build", "Android build", "type-safe plugin", "cross-platform", or works on Capacitor config/native bridge code. Provides patterns for type-safe native bridges, plugin integration, and cross-platform workflows.
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across all neoMeta apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Capacitor TypeScript Skill

Guides writing, reviewing, and refactoring TypeScript code for Capacitor apps. Focus on type safety, cross-platform compatibility (iOS/Android/Web), and integration with React/Next.js. Always prioritize strict TS configs (noImplicitAny, strictNullChecks).

**Source:** Adapted from [capgo-skills](https://github.com/Cap-go/capgo-skills) (24 skills), official [Capacitor plugin patterns](https://capacitorjs.com/docs/plugins), and TypeScript best practices

---

## When to Use

**Intent Triggers:**

- Writing TS code for Capacitor plugins or native bridges
- Reviewing for type errors, native API mismatches
- Migrating web TS code to Capacitor native
- iOS/Android build and deployment workflows
- Plugin integration and configuration
- Cross-platform performance/accessibility optimization
- Safe area / notch handling
- OTA live update setup

**When NOT to Use:**

- Pure web UI styling (use `design-system`)
- React component optimization without native context (use `react-best-practices`)
- Testing without Capacitor specifics (use `testing`)

---

## Priority Guide

| Category                       | Impact      | When to Apply                                     |
| ------------------------------ | ----------- | ------------------------------------------------- |
| Plugin Availability Gating     | CRITICAL    | Every native call — prevents crashes              |
| Type-Safe Native Bridges       | CRITICAL    | Always — prevents runtime crashes on device       |
| Platform-Specific Guards       | CRITICAL    | Always — web vs iOS vs Android divergence         |
| Safe Area Handling             | CRITICAL    | Any UI touching screen edges                      |
| Cold-Start Auth Bootstrap      | CRITICAL    | Any app using `output: 'export'` + auth           |
| Supabase + Capacitor Lifecycle | CRITICAL    | Any app using Supabase auth/realtime on Capacitor |
| Plugin Integration             | HIGH        | Adding native features (camera, geo, push)        |
| Optimistic Writes + Repos      | HIGH        | Any "feels-native" write surface                  |
| Cross-Platform Testing         | HIGH        | Before any release                                |
| OTA Live Updates               | HIGH        | Deployment without app store review               |
| Build & Deployment             | MEDIUM-HIGH | CI/CD, app store submission                       |
| Distribution-Stage Discipline  | MEDIUM-HIGH | Before scoping any heavyweight pattern            |
| Performance Optimization       | MEDIUM      | Large lists, animations, offline-first            |
| Security                       | MEDIUM      | Secrets, secure storage, network                  |

---

## Reference Documentation

Load on-demand based on task:

| File                                | When to Read                                                        |
| ----------------------------------- | ------------------------------------------------------------------- |
| `reference/nextjs-static-export.md` | Configuring static export, dynamic routes, Server Component errors  |
| `reference/pwa-migration.md`        | Migrating PWA features, iOS storage issues, CORS, WKWebView gotchas |
| `reference/plugin-catalog.md`       | Choosing a plugin, looking up package names                         |
| `reference/testing-debugging.md`    | Vitest mocks for Capacitor, crash diagnosis, WebView debugging      |
| `reference/deep-linking.md`         | Deep link listeners, testing commands, associated domains           |
| `reference/security-capsec.md`      | Running Capsec scanner, security rules, production checklist        |

---

## 1. Plugin Availability Gating (CRITICAL)

**Always check plugin availability before calling native APIs.** This is the single most important Capacitor pattern — prevents crashes when a plugin is not available on the current platform.

```typescript
import { Capacitor } from '@capacitor/core';
import { Camera, CameraResultType } from '@capacitor/camera';

async function takePhoto() {
  if (!Capacitor.isPluginAvailable('Camera')) {
    // Fallback: use <input type="file" accept="image/*"> on web
    return null;
  }
  return Camera.getPhoto({
    quality: 80,
    width: 1024,
    resultType: CameraResultType.Uri,
  });
}
```

**Rule:** Every native plugin call must be wrapped in `isPluginAvailable()` or `isNativePlatform()`.

---

## 2. Type Design for Capacitor (CRITICAL)

Use interfaces for plugin APIs. Generics for reusable hooks. Never use `any` — use `unknown` with type guards for native responses.

### Plugin API Typing

```typescript
import { Capacitor } from '@capacitor/core';
import { Geolocation } from '@capacitor/geolocation';

interface Location {
  coords: { latitude: number; longitude: number };
}

async function getLocation(): Promise<Location> {
  if (!Capacitor.isPluginAvailable('Geolocation')) {
    throw new CapacitorError(
      'Geolocation not available',
      'Geolocation',
      Capacitor.getPlatform()
    );
  }
  const position = await Geolocation.getCurrentPosition();
  return { coords: position.coords };
}
```

### Custom Plugin Bridge Pattern

For native plugins not available as npm packages, follow this 4-layer pattern:

1. **Swift plugin** (`ios/App/App/YourPlugin.swift`):

   ```swift
   import Capacitor
   @objc(YourPlugin)
   public class YourPlugin: CAPPlugin, CAPBridgedPlugin {
       public let identifier = "YourPlugin"
       public let jsName = "YourPlugin"
       public let pluginMethods: [CAPPluginMethod] = []
       func handleEvent(_ data: SomeType) {
           notifyListeners("eventName", data: ["key": data.value])
       }
   }
   ```

2. **ObjC registration** (`ios/App/App/YourPlugin.m`):

   ```objc
   #import <Capacitor/Capacitor.h>
   CAP_PLUGIN(YourPlugin, "YourPlugin",)
   ```

3. **TypeScript interface** — `registerPlugin()` returns `unknown` without a type parameter:

   ```typescript
   import { registerPlugin, type Plugin } from '@capacitor/core';
   interface YourPlugin extends Plugin {
     addListener(
       eventName: 'eventName',
       fn: (data: { key: string }) => void
     ): Promise<{ remove: () => Promise<void> }>;
   }
   const YourPlugin = registerPlugin<YourPlugin>('YourPlugin');
   ```

4. **React hook** — register listener inside `useEffect` with `isNativePlatform()` guard and cleanup via `handle.remove()`

### Type Guidelines

- Use `Partial<Options>` for configurable plugin params
- Use `readonly` for device state objects
- Use discriminated unions: `{ platform: 'ios' | 'android' | 'web' }`
- Use utility types (Pick, Omit) for plugin config subsets
- JSDoc with `@since` on every method when authoring plugins

---

## 3. Cross-Platform Patterns (CRITICAL)

### Platform Detection

```typescript
import { Capacitor } from '@capacitor/core';

const platform = Capacitor.getPlatform(); // 'ios' | 'android' | 'web'
const isNative = Capacitor.isNativePlatform();

// Three-way branching when platforms diverge
switch (Capacitor.getPlatform()) {
  case 'ios':
    // iOS-specific behavior
    break;
  case 'android':
    // Android-specific behavior
    break;
  case 'web':
    // Web fallback
    break;
}
```

### Error Handling

```typescript
class CapacitorError extends Error {
  constructor(
    message: string,
    public readonly plugin: string,
    public readonly platform: string
  ) {
    super(`[${plugin}@${platform}] ${message}`);
    this.name = 'CapacitorError';
  }
}

async function safeNativeCall<T>(
  plugin: string,
  fn: () => Promise<T>,
  fallback?: T
): Promise<T> {
  try {
    if (!Capacitor.isPluginAvailable(plugin)) {
      if (fallback !== undefined) return fallback;
      throw new CapacitorError(
        'Plugin not available',
        plugin,
        Capacitor.getPlatform()
      );
    }
    return await fn();
  } catch (error) {
    if (error instanceof CapacitorError) throw error;
    const platform = Capacitor.getPlatform();
    if (fallback !== undefined) return fallback;
    throw new CapacitorError(
      error instanceof Error ? error.message : String(error),
      plugin,
      platform
    );
  }
}
```

### Modular Platform Separation

- Separate web/native logic: `device.native.ts` and `device.web.ts`
- Use barrel exports with platform detection
- Keep platform-specific code behind clear boundaries
- Never mix native and web logic in the same function

---

## 4. Safe Area Handling (CRITICAL)

Critical for devices with notches, Dynamic Island, rounded corners, and home indicators.

### HTML Meta Tag (Required)

```html
<meta
  name="viewport"
  content="viewport-fit=cover, width=device-width, initial-scale=1.0"
/>
```

### CSS Environment Variables

```css
:root {
  --safe-area-top: env(safe-area-inset-top, 0px);
  --safe-area-bottom: env(safe-area-inset-bottom, 0px);
  --safe-area-left: env(safe-area-inset-left, 0px);
  --safe-area-right: env(safe-area-inset-right, 0px);
}

.app-header {
  padding-top: calc(var(--safe-area-top) + 12px);
}

.bottom-nav {
  padding-bottom: calc(var(--safe-area-bottom) + 8px);
}
```

### Tailwind Utilities

```css
@layer utilities {
  .pt-safe {
    padding-top: env(safe-area-inset-top);
  }
  .pb-safe {
    padding-bottom: env(safe-area-inset-bottom);
  }
  .pl-safe {
    padding-left: env(safe-area-inset-left);
  }
  .pr-safe {
    padding-right: env(safe-area-inset-right);
  }
}
```

---

## 5. Next.js Static Export

See `reference/nextjs-static-export.md`.

Key: `output: 'export'` required; `useParams()` broken in static export (use `useSearchParams()`); Server Actions incompatible; build with `BUILD_TARGET=capacitor pnpm build && npx cap sync`.

---

## 6. PWA to Native Migration

See `reference/pwa-migration.md`.

Key: Service workers not supported in WKWebView; `localStorage` evictable on iOS (use `@capacitor/preferences` for tokens); CORS must allow `capacitor://localhost` and `http://localhost`; always `await` async work before `router.push()`.

---

## 7. React/Next.js Integration

### Reusable Native Hook Pattern

```typescript
import { useState, useEffect } from 'react';
import { App } from '@capacitor/app';

function useAppState(): 'active' | 'background' {
  const [state, setState] = useState<'active' | 'background'>('active');
  useEffect(() => {
    const listener = App.addListener('appStateChange', ({ isActive }) => {
      setState(isActive ? 'active' : 'background');
    });
    return () => {
      listener.then(l => l.remove());
    };
  }, []);
  return state;
}
```

### Listener Cleanup (Memory Leak Prevention)

Always clean up listeners in useEffect returns. Capacitor `addListener` returns a Promise:

```typescript
useEffect(() => {
  const listener = SomePlugin.addListener('event', handler);
  return () => {
    listener.then(l => l.remove());
  };
}, []);
```

### Typed Camera Hook

```typescript
import { useState, useCallback } from 'react';
import { Camera, CameraResultType, type Photo } from '@capacitor/camera';
import { Capacitor } from '@capacitor/core';

function useCamera() {
  const [photo, setPhoto] = useState<Photo | null>(null);
  const [error, setError] = useState<string | null>(null);

  const takePhoto = useCallback(async () => {
    if (!Capacitor.isPluginAvailable('Camera')) {
      setError('Camera not available on this platform');
      return;
    }
    try {
      const result = await Camera.getPhoto({
        quality: 80,
        width: 1024,
        resultType: CameraResultType.Uri,
      });
      setPhoto(result);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Camera failed');
    }
  }, []);

  return { photo, error, takePhoto };
}
```

---

## 8. Capacitor Configuration

### capacitor.config.ts (Preferred over JSON)

```typescript
import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.app',
  appName: 'My App',
  webDir: 'out', // Next.js static export directory
  server: {
    // Dev server URL — only in development
    ...(process.env.NODE_ENV === 'development' && {
      url: 'http://localhost:3000',
      cleartext: true,
    }),
  },
  plugins: {
    SplashScreen: {
      launchAutoHide: false, // see §16 — required for the splash → JS handoff pattern
      backgroundColor: '#<brand>', // match the JS-side branded loader to make the handoff invisible
      androidScaleType: 'CENTER_CROP',
    },
    StatusBar: {
      style: 'dark',
    },
  },
};

export default config;
```

Use `capacitor.config.ts` (not `.json`) for type safety and environment conditionals.

---

## 9. Plugin Ecosystem

See `reference/plugin-catalog.md`. Install: `pnpm add @capacitor/plugin-name && npx cap sync`

---

## 10. Testing & Debugging

See `reference/testing-debugging.md` for Vitest mocking, WebView debugging, crash diagnosis, and E2E options.

---

## 11. Deep Linking

See `reference/deep-linking.md` for listener patterns, test commands, and associated domain verification.

---

## 12. OTA Live Updates (Capgo)

Skip app store review for JS/HTML/CSS updates.

```typescript
import { CapacitorUpdater } from '@capgo/capacitor-updater';

// MUST be called within 10 seconds of app start
// If not called, Capgo auto-rolls back to previous version
CapacitorUpdater.notifyAppReady();
```

**Channel strategy:**

- `production` — stable releases
- `beta` — pre-release testing
- `dev` — internal testing

**CI/CD upload:** `bunx @capgo/cli upload --channel production`

---

## 13. Build & Deployment

```bash
# Sync web assets to native projects
npx cap sync

# Open native IDE
npx cap open ios
npx cap open android

# Build web first, then sync
pnpm build && npx cap sync

# Run on device (with live reload)
npx cap run ios --livereload --external
npx cap run android --livereload --external
```

**App Store Checklist:**

- Splash screen configured (`capacitor.config.ts`)
- Icons generated for all sizes (1024x1024 source)
- Bundle ID / package name set
- Signing certificates configured (iOS: provisioning profile, Android: keystore)
- Privacy manifest (iOS) / permissions declared
- `viewport-fit=cover` in meta tag for edge-to-edge

**Apple Privacy Manifest** (`ios/App/App/PrivacyInfo.xcprivacy`):
Required for App Store submission (Spring 2024+). Structure:

- `NSPrivacyTracking` — `false` if no tracking
- `NSPrivacyCollectedDataTypes` — array of collected data type dicts (linked, not tracked, purpose)
- `NSPrivacyAccessedAPITypes` — array with reason codes (e.g., UserDefaults → CA92.1)

This project's collected types: Photos (meal images), Health (symptom/food data), OtherUserContent (meal descriptions). Accessed APIs: UserDefaults (CA92.1 — `@capacitor/preferences`). Update when adding plugins that access required-reason APIs or collecting new data types.

---

## 14. Security

See `reference/security-capsec.md`. Run: `bunx capsec scan` (62+ rules, zero config).

**WKWebView Media Permission Origin Validation:**
iOS 15+ requires explicit delegate handling for `getUserMedia` — without it, camera/mic silently fails. `CustomViewController.swift` subclasses `CAPBridgeViewController` and implements `webView(_:requestMediaCapturePermissionFor:...)`.

Origin check: production grants `origin.protocol == "capacitor" && origin.host == "localhost"` only. Debug builds also allow `http://localhost` (dev server). All other origins denied. Key gotcha: `WKSecurityOrigin.protocol` returns the bare scheme name (`"capacitor"`), NOT `"capacitor://"`.

---

## 15. Performance

- **Lazy-load plugins:** Dynamic import at call site, not module top
  ```typescript
  async function vibrate() {
    const { Haptics, ImpactStyle } = await import('@capacitor/haptics');
    await Haptics.impact({ style: ImpactStyle.Light });
  }
  ```
- **Batch bridge calls:** Consolidate multiple native calls to reduce overhead
- **Targets:** First Paint < 1s, TTI < 3s, 60fps. Cold-start tap-icon → first-interactive-paint ≤ 1500ms P50 on a mid-tier device (Pixel 6a / iPhone 13-class).
- **Bundle gate — relative, not absolute:** capture a baseline from `next build` (the "First Load JS" output line — this is gzipped first-load JS, the metric that matters) and enforce **baseline + ≤10% growth** per phase. The classic "<500KB gz" absolute target is the wrong shape: it ignores starting size and punishes apps for being measured. Commit the baseline number to a research file; each PR description carries the post-build "First Load JS" line.
- **Wrong shape:** `du -h .next/static/chunks/*.js` — that's uncompressed disk of all chunks, not first-load.
- **Image quality:** 80 (not max), width: 1024 — reduces memory and transfer
- **Cold-start instrumentation — honest scope:** `performance.mark('js-bootstrap-begin' | 'auth-resolved' | 'first-route-paint')` measures **JS-bootstrap onwards only**, NOT the native splash → WKWebView handoff window. Real-device stopwatch is the primary truth for the splash → interactive measurement; CI marks are a proxy budget.
- **Offline-first:** Service Workers + IndexedDB for data persistence (see §19 distribution-stage discipline before reaching for this)
- **Profile on real devices:** Xcode Instruments (iOS), Android Profiler

---

## 16. Cold-Start & Auth Bootstrap (CRITICAL)

For Next.js `output: 'export'` Capacitor apps with auth, **middleware does NOT run** — there is no server to run it on. Without a bootstrap gate, the first paint resolves to whichever route the router thinks matches the URL _before_ auth state settles, which for `~90% authed users` is the **login skeleton flashing for 200–600ms** before the dashboard. This is structural, not a styling bug.

### The fix: one `isBootstrapped` gate at the route-tree root

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

### The 6-case failure-mode contract (encode in tests)

1. **Happy path (authed):** cached-authed flag = true → loader → `getUser()` returns user → `isBootstrapped=true` → route tree mounts → `/app`. **No login chrome paints.**
2. **Token expired:** cached-authed flag = true → `getUser()` returns null → clear cached flag → `/login`. User briefly sees loader, then login — acceptable; rare.
3. **Network unreachable on cold start:** `getUser()` throws → **render `/app` shell optimistically** (last-known-authed). Subsequent API calls trigger normal error UI; RLS prevents data corruption. Do NOT bounce to `/login` (that's the bug we're fixing). Retry on `@capacitor/network` `networkStatusChange` or `App.resume`.
4. **No cached flag:** never logged in → `isBootstrapped=true` immediately → `/login`.
5. **Token-refresh racing the bootstrap:** Supabase JS handles refresh internally; bootstrap waits on `getUser()` outcome. Belt-and-braces: skip retry if `supabase.auth.onAuthStateChange` is mid-`TOKEN_REFRESHED`.
6. **Stickiness invariant — `isBootstrapped` NEVER transitions back to false.** A late `getUser()` resolving null does not yank the user mid-interaction. Instead, a 401 interceptor catches failing API calls and surfaces a "session expired" modal (below).

### Splash → JS handoff

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

### 401 interceptor + session-expired modal (supports case 6)

Wrap your SWR fetcher / Supabase client to detect 401 responses. On first 401 after `isBootstrapped=true`:

- Set a global `sessionExpired` state.
- Suppress further toasts (avoid 401 toast storm on every refetch).
- Mount a single `<SessionExpiredModal />` at the route-tree root with a "Sign in again" button.
- **Do NOT navigate immediately** — preserve any in-progress form state.
- Also triggered by `onAuthStateChange('SIGNED_OUT')` from another tab/window.

### Server-safe module split (the three-file pattern)

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

### Acceptance test (silver bullet)

A Playwright test that boots with a cached-authed flag set + a mocked `getUser()` and asserts **zero paints** of login chrome before the dashboard renders. This is the regression gate for the whole pattern; ship it with the first implementation.

---

## 17. Supabase + Capacitor Lifecycle (CRITICAL)

Two non-obvious gotchas that bite every Capacitor + Supabase app:

### Realtime `setAuth` on `TOKEN_REFRESHED`

Supabase JS v2 has **ONE global `realtime.setAuth()`**, not a per-channel version. Without wiring it up, every realtime channel keeps the JWT it had when it was created, and ~1h after sign-in the server stops pushing messages with no client-side error — users see stale data forever.

```typescript
// lib/supabase/client.ts (module-scope side effect, ONCE per app)
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'TOKEN_REFRESHED' && session) {
    supabase.realtime.setAuth(session.access_token);
  }
});
```

Add a regression test: `features/auth/__tests__/realtime-token-refresh.test.ts` asserts `setAuth` is called exactly once on `TOKEN_REFRESHED`.

### iOS WKWebView background suspension reality

**iOS suspends WKWebView's JavaScript runtime ~30 seconds after backgrounding.** Consequences:

- `@capacitor/network` `networkStatusChange` CANNOT fire while suspended.
- `setInterval` / `setTimeout` do NOT run.
- Any "writes reach server within N minutes regardless of app state" SLO is unachievable.

This forces an honest sync model:

| User state            | Queue drain timing                                |
| --------------------- | ------------------------------------------------- |
| Foregrounded + online | Within seconds                                    |
| Backgrounded          | On next foreground (`App.resume` event), N/A here |
| Offline → online (bg) | Drains on next foreground, NOT on reconnect       |

**Explicitly NOT supported without native code:** background fetch, periodic fetch, or any "data reaches server within N minutes regardless of app state." Adding background fetch invites Apple-review battery scrutiny and platform-specific code without proportional benefit at Stage 0–2.

Wire `App.resume` to refetch on return:

```typescript
useEffect(() => {
  const listener = App.addListener('resume', () => {
    mutate(/* dashboard keys */); // SWR refetch
  });
  return () => {
    listener.then(l => l.remove());
  };
}, []);
```

### JWT-first sign-out wipe (order matters)

If the app is killed mid-wipe, the order determines what's left behind. Clear the JWT FIRST so even a half-wiped state cannot operate as the prior user:

```typescript
async function signOut() {
  // 1. JWT first — after this, the app cannot operate as the prior user
  await supabase.auth.signOut({ scope: 'local' });
  await Preferences.remove({ key: 'last-known-authed' });

  // 2. SWR cache flush — clear ALL keys (prevents cross-user contamination)
  await mutate(() => true, undefined, { revalidate: false });

  // 3. session/localStorage UI state
  sessionStorage.clear();
  // localStorage: only clear app-owned keys, not user-agent-owned ones

  // 4. If you have IDB: closeAll() → deleteDatabase() → onblocked 2s timeout
  //    (see §19 — only relevant once you actually ship local-first storage)
}
```

**Trigger from all paths:** explicit logout button, `onAuthStateChange('USER_DELETED')`, `onAuthStateChange('SIGNED_OUT')` (covers cross-tab).

**Common landmine — SWR static keys cross-user contamination:** If SWR fetcher keys are static strings like `'dashboard-data'`, signing out + signing in as a different user on the same device briefly renders the PREVIOUS user's cached data. Either flush ALL SWR keys on sign-out (above), or scope every fetcher key by `user.id`. Allow-list keys that legitimately stay global (`canonical-ingredient-list`, etc.) and fail the build on un-scoped data keys.

---

## 18. Optimistic Writes + Thin Repo Pattern (HIGH)

The pattern that makes an app feel native without a sync engine. SWR provides everything needed.

### The pattern

```typescript
import useSWR, { useSWRConfig } from 'swr';

await mutate(swrKey, async () => foodsRepo.create(payload), {
  optimisticData: current => [...(current ?? []), optimisticEntry],
  rollbackOnError: true,
  revalidate: false,
});
```

- Entry appears instantly in the UI (`optimisticData`).
- On server reject, SWR rolls back automatically (`rollbackOnError`).
- Honest rollback toast: **"Couldn't save — your input was not preserved. Try again."** Do NOT offer a "try again" button unless you actually saved the draft — the optimistic rollback removed it.

### Thin repo abstraction — introduce it FROM THE START

Even if the implementation is just Supabase passthrough today, introduce a `<domain>Repo` indirection from day one:

```typescript
// lib/data/repos/foods-repo.ts
export const foodsRepo = {
  list: () => supabase.from('foods').select('*'),
  create: payload => supabase.from('foods').insert(payload),
  update: (id, patch) => supabase.from('foods').update(patch).eq('id', id),
  delete: id => supabase.from('foods').delete().eq('id', id),
};
```

**Why it matters:** when you later swap the internals for IDB-backed local-first (§19), every action hook keeps working — internals-only swap. Without the indirection, every callsite has to change.

**API matches the SERVICE, not generic CRUD.** If a domain has upsert semantics (single row per user per day, etc.), the repo mirrors that — don't pretend it's a CRUD log table.

---

## 19. Distribution-Stage Discipline (MEDIUM-HIGH)

Per `software/CLAUDE.md` and `alignment/distribution-philosophy.md`, work sequences by distribution stage. **Don't pre-build for later stages** — that's how solo-built apps die under their own complexity before getting a single user.

The patterns below are tempting from day one but are **canonical Stage 3-4 infrastructure**. Only reach for them when cohort signal validates the pain:

| Pattern                                | Earliest stage to build     | Trigger to reactivate                                               |
| -------------------------------------- | --------------------------- | ------------------------------------------------------------------- |
| IndexedDB local-first + sync engine    | Stage 3                     | ≥10 WAU report concrete offline-write pain OR cold-cache >300ms P50 |
| Dead-letter queue for sync failures    | Stage 3                     | Real-world data shows constraint drift fires often enough           |
| `_wipe_intent` ledger + resume-on-boot | Stage 3                     | Sub-second kill mid-wipe becomes a real reported issue              |
| IDB epoch + backfill-on-eviction       | Stage 3                     | Eviction proves real in cohort telemetry                            |
| Background fetch / periodic sync       | Stage 3+ (and never on iOS) | Apple-review battery scrutiny worth the cost                        |
| Affiliate / partner dashboards         | Stage 3                     | Active creator deals in flight                                      |
| Custom analytics / observability       | Stage 2+                    | Manual measurement no longer scales                                 |

**At Stage 0–1**, the right Capacitor "feels native" surface area is:

1. The cold-start auth bootstrap (§16) — kills the worst visible bug.
2. Optimistic writes on top of server-first (§18) — delivers ~70% of the perceived "app feel" gain at ~40% of the work.
3. Native polish: haptics, page transitions, swipe-to-delete, pull-to-refresh, keyboard avoidance, 44pt touch targets, `:hover` suppression in native build, `App.resume` SWR refetch.

That's it. If you find yourself designing a sync queue + DLQ + wipe ledger at Stage 0, **stop** — you're solving a problem you don't have yet.

### IndexedDB delete blocks indefinitely (when you eventually ship it)

When/if Stage 3 work activates IDB, this is the one trap that bites everybody:

```typescript
// indexedDB.deleteDatabase BLOCKS indefinitely if any other connection holds the DB.
// Module-scope handles, service workers — anything.
async function wipeIDB() {
  await idbAdapter.closeAll(); // close all known module-scope connections first
  return new Promise(resolve => {
    const req = indexedDB.deleteDatabase('app-db');
    req.onsuccess = resolve;
    req.onblocked = () => {
      // Don't hang forever — log + continue. Orphan DB cleans up on next boot.
      setTimeout(() => {
        Sentry.captureMessage('IDB delete blocked');
        resolve();
      }, 2000);
    };
  });
}
```

Without `closeAll()`, the delete sits there forever; without the `onblocked` timeout, your sign-out flow deadlocks.
