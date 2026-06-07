---
name: capacitor
description: Use for TypeScript development in Capacitor projects. Activate when user mentions "Capacitor", "native app", "iOS build", "Android build", "type-safe plugin", "cross-platform", or works on Capacitor config/native bridge code. Provides patterns for type-safe native bridges, plugin integration, and cross-platform workflows.
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
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
| `reference/advanced-native-patterns.md` | §2/§3 — custom plugin bridge (4-layer) + typed `safeNativeCall` wrapper |
| `reference/build-deploy.md`         | §13 — cap sync/run commands, App Store checklist, Privacy Manifest  |
| `reference/testing-debugging.md`    | Vitest mocks for Capacitor, crash diagnosis, WebView debugging      |
| `reference/deep-linking.md`         | Deep link listeners, testing commands, associated domains           |
| `reference/security-capsec.md`      | Running Capsec scanner, security rules, production checklist        |
| `reference/cold-start-auth.md`      | §16 — cold-start bootstrap gate, 6-case contract, splash handoff, 401 modal |
| `reference/supabase-lifecycle.md`   | §17 — realtime setAuth, WKWebView suspension, sign-out wipe ordering |
| `reference/optimistic-writes.md`    | §18 — SWR optimistic writes + thin repo indirection                 |
| `reference/distribution-stage.md`   | §19 — what NOT to build per stage; IDB-delete trap                  |

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

For native plugins not available as npm packages, use the 4-layer pattern (Swift plugin → ObjC registration → typed `registerPlugin<T>()` interface → React hook with `isNativePlatform()` guard + cleanup). **→ Full code: `reference/advanced-native-patterns.md`.**

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

Use a typed `CapacitorError` + `safeNativeCall<T>(plugin, fn, fallback?)` wrapper so every native call gets consistent availability gating, fallback, and error context. **→ Full code: `reference/advanced-native-patterns.md`.**

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

Key flow: `pnpm build && npx cap sync` → `npx cap open ios|android`; device live-reload via `npx cap run ios --livereload --external`. Plus the App Store checklist (signing, icons, splash, `viewport-fit=cover`) and the Apple Privacy Manifest (`PrivacyInfo.xcprivacy`) — whose collected-data-types list is **app-specific and lives in CORE**.

**→ Commands, full checklist, Privacy Manifest structure: `reference/build-deploy.md`.**

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

For `output: 'export'` apps with auth, middleware doesn't run — the login skeleton flashes before auth settles. The fix is one sticky `isBootstrapped` gate at the route-tree root, a 6-case failure contract, splash→JS handoff, a 401 session-expired interceptor, and the server-safe three-file module split.

**→ Full pattern + code + acceptance test: `reference/cold-start-auth.md`.**

---

## 17. Supabase + Capacitor Lifecycle (CRITICAL)

Three gotchas that bite every Capacitor + Supabase app: global `realtime.setAuth()` on `TOKEN_REFRESHED` (else realtime silently dies ~1h after sign-in); iOS WKWebView suspends JS ~30s after backgrounding (no background timers/network — `App.resume` refetch instead); and JWT-first sign-out wipe ordering (+ SWR static-key cross-user contamination).

**→ Full patterns + code: `reference/supabase-lifecycle.md`.**

---

## 18. Optimistic Writes + Thin Repo Pattern (HIGH)

Makes the app feel native without a sync engine, using SWR `mutate` with `optimisticData` + `rollbackOnError`, behind a `<domain>Repo` indirection introduced from day one so internals can later swap to local-first without touching callsites.

**→ Full pattern + code: `reference/optimistic-writes.md`.**

---

## 19. Distribution-Stage Discipline (MEDIUM-HIGH)

Don't pre-build Stage 3-4 infrastructure (IDB sync engine, DLQ, wipe ledger, background fetch, partner dashboards) at Stage 0-1. The right "feels native" surface at Stage 0-1 is just: cold-start bootstrap (§16) + optimistic writes (§18) + native polish.

**→ Stage table + reactivation triggers + IDB-delete trap: `reference/distribution-stage.md`.**
