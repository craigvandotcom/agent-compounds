---
name: capacitor
description: Use for ALL engineering decisions when building Capacitor native apps on the neoMeta stack (Next.js static export + React + SWR + Supabase) — load before planning or implementing any UI, navigation, data fetching, auth, storage, lifecycle, or build work. Triggers on "capacitor", "native app", "iOS", "Android", "native feel", "tab switch", "keep-mounted", "WKWebView", "skeleton flash", "SWR cache", "static export", "cold start", "app lifecycle", "Preferences storage", "plugin", "native performance", "background", "app resume", "safe area", "tab navigation", "plugin bridge", "MainActor", "visibility hidden", "display none". NOT for writing or fixing tests (use testing), SQL/schema/RLS/migrations (use supabase), visual or CSS defects (use ui-debug), or accessibility audits (use web-design-guidelines).
---

# Capacitor Native — Engineering Reference

> **Generic skill — method only, zero app facts.** App specifics (bundle IDs, schema names, domain rules, feature flows, env values) → read this app's `.claude/skills/CORE/SKILL.md`. Do not add app-specific facts here.

**The founding constraint:** This is a web app running inside a native shell. Users judge by *native app* standards — instant tab switches, no skeleton flashes, no animation replays, no random logouts, no battery drain. Every decision in this skill exists because of that constraint.

---

## When to Use

Load at the START of any session touching:

- Navigation, tab switching, routing, or view transitions
- Data fetching hooks, SWR configuration, or cache strategy
- Auth flows, session handling, or cold start
- Storage decisions (localStorage vs Preferences vs IndexedDB vs SQLite)
- iOS/Android app lifecycle, backgrounding, or App.resume
- Native plugin integration, feature gating, or custom Swift/Kotlin bridges
- Build, deployment, or App Store work
- **Planning any feature** — load before `ac-plan-init` or `ac-plan-refine-internal`

**Scope — `(protected)/app/*` routes only.** This skill does not apply to web landing/marketing pages. In the BCA codebase, `app/(public)/*` routes (`about`, `blog`, `privacy`, `terms`, `foods`) are served by the full Next.js Vercel deployment — not WKWebView. For those routes: hover states are valid, `next/image` optimization is active, Server Components and middleware work, Core Web Vitals are the performance target, and `revalidateOnFocus: false` / `App.resume` patterns are irrelevant. `app/(auth)/*` is a mixed context — auth flows must work on both web and native (OAuth deep links).

**Not for:** Backend/API code with no native context; `(public)/*` landing/marketing pages; styling without native implications.

---

## Priority Guide

| Category | Impact | See |
|---|---|---|
| Plugin Availability Gating | CRITICAL | §1 |
| Keep-Mounted Tab Architecture | CRITICAL | §2 + `reference/navigation-architecture.md` |
| iOS WKWebView Lifecycle | CRITICAL | §3 |
| iOS Plugin Threading (MainActor) | CRITICAL | §4 |
| Cold-Start Auth Bootstrap | CRITICAL | `reference/cold-start-auth.md` |
| Supabase + Capacitor Lifecycle | CRITICAL | §8 + `reference/supabase-lifecycle.md` |
| Next.js Static Export Constraints | CRITICAL | §6 |
| Mobile Touch Rules | CRITICAL | §5 |
| isMountedRef in React Strict Mode | CRITICAL | §13 |
| SWR Discipline for Native Feel | HIGH | §7 + `reference/swr-native-discipline.md` |
| Storage Hierarchy | HIGH | §9 |
| Optimistic Writes + Thin Repo | HIGH | `reference/optimistic-writes.md` |
| Safe Area Handling | HIGH | §10 |
| Type-Safe Native Bridges | HIGH | `reference/advanced-native-patterns.md` |
| Parallel Data Fetching | CRITICAL | §15 + `reference/react-performance.md` |
| Bundle Size | CRITICAL | §15 + `reference/react-performance.md` |
| Re-render Optimization | MEDIUM-HIGH | `reference/react-performance.md` |
| Security | MEDIUM | `reference/security-capsec.md` |
| Distribution Stage Discipline | MEDIUM | §11 + `reference/distribution-stage.md` |
| Performance Targets | MEDIUM | §12 |
| Build & Deployment | MEDIUM | `reference/build-deploy.md` |
| Deep Linking | LOW-MEDIUM | `reference/deep-linking.md` |
| Plugin Ecosystem | LOW | `reference/plugin-catalog.md` |
| OTA Live Updates | LOW | §16 |

---

## Reference Files — Load On-Demand

| File | When to Read |
|---|---|
| `reference/navigation-architecture.md` | Full keep-mounted pattern, visitedTabs Set, visibility:hidden vs display:none, React 19 Activity upgrade path |
| `reference/swr-native-discipline.md` | Complete SWR cache strategy — dedup, pre-warming, key alignment, App.resume integration |
| `reference/cold-start-auth.md` | 6-case bootstrap contract, splash → JS handoff, 401 interceptor, 3-file module split |
| `reference/supabase-lifecycle.md` | Realtime setAuth, WKWebView suspension, JWT sign-out wipe ordering, cross-tab SIGNED_OUT |
| `reference/optimistic-writes.md` | SWR optimistic writes + rollback, thin repo indirection pattern |
| `reference/nextjs-static-export.md` | Static export config, what breaks, useParams workaround, dynamic imports |
| `reference/build-deploy.md` | Build commands, App Store checklist, Privacy Manifest, fastlane |
| `reference/advanced-native-patterns.md` | 4-layer custom plugin bridge, typed safeNativeCall wrapper |
| `reference/testing-debugging.md` | Capacitor plugin mocks, keep-mounted test patterns, crash diagnosis, WebView debugging |
| `reference/security-capsec.md` | Capsec scanner, WKWebView origin validation, production checklist |
| `reference/distribution-stage.md` | Stage table, IDB-delete trap, what NOT to build at Stage 0–1 |
| `reference/pwa-migration.md` | localStorage → Preferences adapter, CORS config, storage eviction, PKCE fix |
| `reference/plugin-catalog.md` | Full plugin list, install commands |
| `reference/react-performance.md` | Parallel fetching, bundle size, re-render optimisation, JS perf — all adapted for static export + Capacitor (no RSC/server patterns) |
| `reference/deep-linking.md` | Deep link listeners, test commands, associated domains |

---

## §1. Plugin Availability Gating (CRITICAL)

Every native plugin call must be gated. Never assume a plugin is available:

```typescript
import { Capacitor } from '@capacitor/core';

async function takePhoto() {
  if (!Capacitor.isPluginAvailable('Camera')) {
    return null; // web fallback — use <input type="file"> instead
  }
  return Camera.getPhoto({ quality: 80, resultType: CameraResultType.Uri });
}
```

**Camera:** Always `CameraResultType.Uri` on native — never Base64. WKWebView heap ceiling ~200MB; Base64 of full-resolution images causes OOM crashes. Fetch the blob at upload time only.

**Image picker on native:** `<input type="file">` returns an empty file list inside WKWebView PHPicker. Branch on `isNativePlatform()` and use `Camera.pickImages()` for multi-select flows.

**`safeNativeCall<T>(plugin, fn, fallback?)`** — typed wrapper with consistent availability gating, fallback, and structured error context. Use for all native calls in production code. Full pattern → `reference/advanced-native-patterns.md`.

---

## §2. Keep-Mounted Tab Architecture (CRITICAL)

**Never `{currentView === 'X' && <View />}` for tab navigation.** Conditional unmount causes: stagger animation replay on every switch, SWR re-fetches when dedupe window elapsed, scroll position loss, state reset.

**Pattern — mount-on-first-visit, CSS-hidden thereafter:**

```tsx
const [visitedTabs, setVisitedTabs] = useState<Set<ViewType>>(
  () => new Set([currentView] as ViewType[])
);

const handleViewChange = useCallback((newView: ViewType) => {
  setVisitedTabs(prev =>
    prev.has(newView) ? prev : new Set([...prev, newView])
  );
  setCurrentView(newView);
}, [setCurrentView]);

const tabVisible = (view: ViewType) => currentView === view;
const tabMounted = (view: ViewType) => visitedTabs.has(view);

// In JSX:
{tabMounted('insights') && (
  <div hidden={!tabVisible('insights')} aria-hidden={!tabVisible('insights')}>
    <ErrorBoundary fallback={<SupabaseErrorFallback />}>
      <InsightsView ... />
    </ErrorBoundary>
  </div>
)}
```

**`hidden` attribute** sets `display: none !important` natively and hides from the accessibility tree via `aria-hidden`. Use `visibility: hidden` (Tailwind `invisible`) when the tab has a scrollable container whose scroll position must survive hide/show — `display: none` resets scroll on re-show; `visibility: hidden` preserves it.

**Animation:** Remove Framer Motion stagger from any keep-mounted view. Replace `<motion.div initial="hidden" animate="show">` wrappers with plain `<div>`. The animation plays on first visit and is preserved by keep-alive — replaying on every tab switch is the source of the flash.

**React 19 `<Activity>`:** Correct long-term solution (suspends effects in hidden mode, preserves state). As of React 19.2.x the API is `unstable_Activity` — check stability before adopting. Activity also uses `display: none` internally; use manual `visibility: hidden` if scroll preservation is required. Full upgrade path and test patterns → `reference/navigation-architecture.md`.

---

## §3. App Lifecycle — WKWebView (CRITICAL)

iOS suspends the JS runtime ~30s after backgrounding. No timers, no network, no background fetch. **Any "sync within N minutes regardless of app state" SLO is impossible without native code.**

**Wire ONCE at app root — never in a component:**

```typescript
import { App } from '@capacitor/app';
import { mutate } from 'swr';

App.addListener('resume', async () => {
  await supabase.auth.getSession(); // refreshes expired token
  mutate(() => true);               // revalidate ALL SWR keys
});
```

**`revalidateOnFocus: false` globally.** SWR's focus handler fires on BOTH the browser Visibility API AND Capacitor foreground — double-fetches on every tab switch inside the app. Revalidate explicitly via `App.resume` only.

**WKWebView process kill (white screen):** iOS kills the WebView under memory pressure; the user sees white. Guard in `AppDelegate.swift`: record `backgroundDate` on `applicationDidEnterBackground`, call `bridge.webView.reload()` on `applicationWillEnterForeground` if `elapsed > 600s`. The `resume` event fires before the WebView is ready after a kill — debounce or guard handlers with a `webView.isLoaded` check.

**Supabase Realtime** drops WebSocket connections on extended background. Re-subscribe channels on `App.resume`. Full lifecycle → `reference/supabase-lifecycle.md`.

---

## §4. iOS Plugin Threading — MainActor Trap (CRITICAL)

Capacitor invokes every `@objc` plugin method on a **background bridge queue**, not main. Any plugin touching UIKit, ARKit, CoreData, or `MainActor`-isolated Swift must dispatch to main first:

```swift
// WRONG — crashes on device (simulator may pass):
@objc func myMethod(_ call: CAPPluginCall) {
    MainActor.assumeIsolated { uiKitStuff() }  // 💥
}

// CORRECT:
@objc func myMethod(_ call: CAPPluginCall) {
    DispatchQueue.main.async {
        MainActor.assumeIsolated { uiKitStuff() }  // ✓
    }
}
```

**Diagnostic signature:** Simulator tests pass; device crashes → threading violation. Checklist before shipping any custom plugin: every `MainActor.assumeIsolated`, `UIView`, `UIViewController`, `ARKit`, or `@MainActor`-annotated call inside a plugin method needs `DispatchQueue.main.async`.

---

## §5. Mobile Touch Rules (CRITICAL)

**Never `:hover` CSS** — touch devices have no hover state. Use `:active` for press feedback; use React state for conditional styling:

```typescript
// Never:
'hover:bg-brand-primary'

// Always:
cn(isActive ? 'text-brand-primary' : 'text-muted-foreground', 'active:scale-95')
```

- **Minimum touch target:** 44×44px (iOS HIG) — enforce on every interactive element
- **Never `transition-all`** on toggles — delays color feedback by the full duration. Use `transition-transform` or `transition-[transform,opacity]` only
- **Never override `color` in hover media queries** — blocks React's className-based dynamic color updates
- **60 FPS animations:** Only `transform` + `opacity`. Never animate `height`, `width`, `top`, `left`, `box-shadow` — these trigger layout recalculation every frame
- **Hardware acceleration:** `will-change: transform` on animated elements; remove after animation completes to free GPU memory

---

## §6. Next.js Static Export — What Breaks (CRITICAL)

`output: 'export'` makes Next.js a pure SPA with no runtime server. Unavailable at runtime:

| Feature | Status | Fix |
|---|---|---|
| Server Actions | ✗ | Direct Supabase calls |
| `cookies()`, `headers()` at runtime | ✗ | Client-side Supabase auth |
| Middleware | ✗ | Cold-start bootstrap gate in layout |
| `useParams()` in App Router | ✗ (issue #64660) | `useSearchParams()` + query params |
| ISR / `revalidate` | ✗ | SWR client-side revalidation |
| Image optimization | ✗ | `images: { unoptimized: true }` |
| `dynamicParams: true` | ✗ | `generateStaticParams()` returning `[]` |

**Required `next.config.ts`:**
```typescript
output: 'export',
trailingSlash: true,           // Prevents 404s in WebView file-based routing
images: { unoptimized: true }, // No optimization server
```

**Dynamic route workaround:** Replace `/app/foods/[id]` with `/app/foods?id=123` read via `useSearchParams()`. Wrap in `<Suspense>` to prevent static build bailout.

**Node-only modules:** `dynamic(() => import('...'), { ssr: false })` prevents evaluation during `next build` prerendering.

**Build command:** `BUILD_TARGET=capacitor pnpm build && npx cap sync`

Full config, edge cases, dynamic import patterns → `reference/nextjs-static-export.md`.

---

## §7. SWR Discipline for Native Feel (HIGH)

**Standard dedup interval: 30 000 ms.** Default 2s causes re-fetches on rapid tab switches. Post-save invalidation uses explicit `mutate()` — the dedup window is NOT the cache-bust mechanism.

```typescript
// Standard config for every hook in a Capacitor app:
{
  dedupingInterval: 30_000,
  keepPreviousData: true,    // No skeleton flash on key change or revalidation
  revalidateOnFocus: false,  // Handled by App.resume (§3)
}
```

**Pre-warming:** Call child hooks at the parent level (discard return value) so SWR populates the cache before the user navigates. First visit becomes instant, not just tab returns.

**Key alignment — the silent cache miss:** If Dashboard calls `useInsightsData()` and InsightsView calls `useInsightsData({ dateRange })`, they produce different SWR keys → separate cache slots → pre-warm is wasted. Lift the key-defining computation to the parent OR compute identically in both. Different `new Date()` calls produce different ISO strings.

**Never raw `useEffect` + fetch for shared state.** Raw effects don't dedupe, can't be pre-warmed, and fall outside the cache strategy. Every `preferencesRepo.get()` in a raw effect is a re-fetch on every mount.

Full SWR config, `focusThrottleInterval` vs `dedupingInterval`, `preload` API, App.resume integration → `reference/swr-native-discipline.md`.

---

## §8. Supabase Integration (CRITICAL)

**Realtime `setAuth` — wire ONCE at app root, never in components:**

```typescript
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'TOKEN_REFRESHED' || event === 'SIGNED_IN') {
    supabase.realtime.setAuth(session?.access_token ?? null);
  }
  if (event === 'SIGNED_OUT') {
    supabase.realtime.setAuth(null);
  }
});
```

Without this, realtime channels carry a stale JWT ~1h after sign-in. Silent data staleness with no client-side error.

**Channel name uniqueness:** Duplicate channel names on remount cause `"cannot add postgres_changes callbacks after subscribe()"` render throws. Suffix channel names with `useId()` per component instance.

**Sign-out wipe order:** JWT clear → SWR cache flush → Preferences clear → IDB (if present). Never flush SWR before JWT — stale renders may re-subscribe with wrong keys.

**All DB operations through `lib/db.ts`** — never ad-hoc Supabase calls in components.

Full lifecycle, WKWebView suspension patterns, cross-tab SIGNED_OUT → `reference/supabase-lifecycle.md`.

---

## §9. Storage Hierarchy (HIGH)

| Tier | Mechanism | Reliability | When to Use |
|---|---|---|---|
| 1 | `@capacitor/preferences` | High (UserDefaults / SharedPrefs) | Auth token references, settings, critical small config |
| 2 | SWR in-memory cache | Session only — lost on WKWebView kill | Active API responses, current session data |
| 3 | `localStorage` | Low — iOS evicts on low disk | Non-critical UI state, draft content only |
| 4 | IndexedDB | Low on iOS (co-evicted) | Do not use until Stage 3+ |
| 5 | `@capacitor-community/sqlite` | High (native FS) | Stage 3+: large datasets, offline queue |

**Auth tokens:** Never `localStorage` on iOS — evicted on low storage, causing random logouts. Use Preferences storage adapter for Supabase:

```typescript
auth: {
  storage: isNativePlatform() ? capacitorStorage : undefined,
  storageKey: 'sb-native-auth',
  detectSessionInUrl: false, // Prevents deep link conflicts
  flowType: 'pkce',
}
```

**`@capacitor/preferences` is async** — preload critical values on app start into React context. Never call in synchronous render paths.

**PKCE + SFSafariViewController:** iOS clears cookies when SFSafariViewController opens for OAuth. The `@supabase/ssr` cookie-based adapter loses the PKCE code verifier at that moment. Use explicit `localStorage`-backed storage adapter (not cookies) for the verifier to survive. Full adapter code → `reference/pwa-migration.md`.

---

## §10. Safe Area Handling (HIGH)

Required on any layout touching screen edges (notch, Dynamic Island, home indicator):

```css
:root {
  --safe-area-top: env(safe-area-inset-top, 0px);
  --safe-area-bottom: env(safe-area-inset-bottom, 0px);
}
.app-header { padding-top: calc(var(--safe-area-top) + 12px); }
.bottom-nav { padding-bottom: calc(var(--safe-area-bottom) + 8px); }
```

**Required viewport meta in root layout:**
```html
<meta name="viewport" content="viewport-fit=cover, width=device-width, initial-scale=1.0" />
```

**iOS keyboard accessory bar (Previous / Next / Done):** Adds ~44px above the system keyboard. Bottom nav buttons below the keyboard become unreachable. Wire `Keyboard.addListener('keyboardWillShow')` from `@capacitor/keyboard` to shift layout, or use CSS `env(keyboard-inset-height)`.

**Tailwind utilities:**
```css
@layer utilities {
  .pt-safe { padding-top: env(safe-area-inset-top); }
  .pb-safe { padding-bottom: env(safe-area-inset-bottom); }
}
```

---

## §11. Distribution Stage Discipline (MEDIUM-HIGH)

"Native feel" at Stage 0–1 = exactly three things:
1. Cold-start auth bootstrap — no login skeleton flash
2. Optimistic writes + thin repo — writes feel instant
3. Keep-mounted nav + touch polish — 44pt targets, `:active` states, `App.resume` refetch, safe areas

**Never build at Stage 0–1:** sync engine, DLQ, IDB wipe ledger, background fetch, partner dashboards, custom analytics, SQLite local-first. These solve problems not yet evidenced by real usage.

Full stage table, activation triggers, IDB-delete trap → `reference/distribution-stage.md`.

---

## §12. Performance Targets

| Metric | Target | Notes |
|---|---|---|
| Tab switch | <16ms (one paint) | Keep-mounted makes this a CSS class toggle |
| Cold start → first interactive | ≤1500ms P50 | Mid-tier device: Pixel 6a / iPhone 13-class |
| Splash → JS handoff | Invisible | Match splash colour to branded loader; `launchAutoHide: false` |
| FPS during animations | 60 FPS steady | Only `transform` + `opacity`; no layout props |
| First Load JS (gzip) | Baseline + ≤10% per phase | Capture from `next build` output — NOT `du -h` on chunks |
| Supabase query round trip | <500ms | Global P50 ~434ms; optimistic writes bridge the gap |
| Vitest suite | <5s | Never `npx vitest` directly — use `pnpm test` to respect memory cap |

**Profiling:** Real devices only for accuracy. iOS: Xcode Instruments (Core Animation, Time Profiler). Android: Android Studio Profiler. Simulator ≠ device performance.

**`performance.mark` scope:** JS-bootstrap onwards only. Splash → WKWebView handoff is NOT measurable from JS — use real-device stopwatch for that window.

---

## §13. isMountedRef in React Strict Mode (CRITICAL)

React Strict Mode runs mount → unmount → remount in development. Without resetting the ref on each mount, it stays `false` after the first unmount and silently breaks all guards:

```typescript
// WRONG — ref stays false after Strict Mode's first unmount:
const isMountedRef = useRef(true);
useEffect(() => {
  return () => { isMountedRef.current = false; };
}, []);

// CORRECT — reset to true on every mount:
const isMountedRef = useRef(true);
useEffect(() => {
  isMountedRef.current = true;   // Required
  return () => { isMountedRef.current = false; };
}, []);
```

---

## §14. Type Design for Capacitor (HIGH)

- No `any` — use `unknown` with type guards for native responses
- `Partial<Options>` for configurable plugin params
- `readonly` for device state objects (GPS coords, camera results)
- Discriminated unions: `{ platform: 'ios' | 'android' | 'web' }`
- `registerPlugin<YourPlugin>('YourPlugin')` — always supply the type parameter

Custom 4-layer plugin bridge (Swift → ObjC registration → TS interface → React hook) → `reference/advanced-native-patterns.md`.

---

## §15. React Performance (CRITICAL + HIGH)

Full patterns with code → `reference/react-performance.md`. **§3 (Server-Side) in generic React guides does not exist on `output: 'export'` — `React.cache()`, `after()`, RSC serialization, Server Actions auth are all N/A. Skip them.**

**Waterfalls (CRITICAL):** Independent fetches must run in parallel. `Promise.all()` in utility functions; parallel SWR hooks at the parent level for pre-warming. Full SWR pre-warming → `reference/swr-native-discipline.md`.

**Bundle (CRITICAL):**
- No barrel imports: `from '@/components'` → `from '@/components/ui/button'`
- Heavy components: `dynamic(() => import('...'), { ssr: false })` — `ssr: false` required for any import using browser or Capacitor APIs
- Defer non-critical third-party libs to interaction-time: `const x = await import('lib')`

**Re-renders (MEDIUM-HIGH):**
- Always functional setState: `setCount(c => c + 1)` not `setCount(count + 1)`
- `memo()` on expensive list children; `useTransition` for heavy synchronous state updates
- `useMemo` only for genuine heavy ops (sort, filter large arrays) — never for simple math or string concat

**Anti-patterns to flag on every PR:**

| Pattern | Problem |
|---|---|
| Sequential `await` for independent ops | Waterfall |
| `import { x } from 'feature-barrel'` | Bundle bloat |
| `useState(expensiveCall())` | Runs every render |
| `useMemo` for simple math/concat | Overhead > benefit |
| `useEffect` + `fetch` without SWR | No dedup, re-fetches on mount |
| `transition: all` on interactive elements | Delays color (also §5) |

---

## §16. OTA Live Updates (LOW)

```typescript
// Must call within 10s of app start or Capgo auto-rolls back:
CapacitorUpdater.notifyAppReady();
```

Channels: `production`, `beta`, `dev`. Upload: `bunx @capgo/cli upload --channel production`. Only JS/HTML/CSS changes qualify — any native code change requires a full app store build.

---

## Supporting Skills

- `supabase` — SDK patterns, migrations, RLS, type generation
- `testing` — Vitest, RTL, Playwright; native plugin mock patterns in `reference/testing-debugging.md`
- `ac-qa-device` — device/simulator QA automation
- `ui-debug` — CSS/visual defect diagnosis
- `ui-brainstorm` — design alternatives and native UI ideation
