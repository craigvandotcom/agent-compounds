# SWR Discipline for Native Feel

SWR cache strategy for Capacitor native apps. The default SWR configuration is tuned for web browsers. On native, several defaults cause visible performance regressions — skeleton flashes, double-fetches on foreground, and cache misses despite pre-warming. This reference covers the correct configuration and patterns for this stack.

---

## The Core Problem: Default SWR Behaves Incorrectly on Native

| Default Behaviour | Problem in Capacitor |
|---|---|
| `dedupingInterval: 2000` | 2s elapses during a tab switch → re-fetches ALL data on return |
| `revalidateOnFocus: true` | Fires on BOTH browser tab focus AND Capacitor foreground event → double-fetches on every app switch |
| No `keepPreviousData` | Shows skeleton while revalidating (data was already in cache — unnecessary flash) |
| No pre-warming | InsightsView cold-starts even though Dashboard fetched related data earlier |

These combine to produce: skeleton flash on tab return, thundering herd of requests on app foreground, and wasted pre-fetch work due to key misalignment.

---

## Standard Global Config

Apply at the SWR provider root, then override per-hook where needed:

```typescript
import { SWRConfig } from 'swr';

// In app layout or _app.tsx:
<SWRConfig
  value={{
    dedupingInterval: 30_000,     // 30s: post-save invalidation uses mutate(), not the dedup window
    keepPreviousData: true,       // No skeleton flash during revalidation
    revalidateOnFocus: false,     // Handle via App.resume instead (see below)
    revalidateOnReconnect: true,  // Good for mobile network switching
    focusThrottleInterval: 60_000, // If you keep revalidateOnFocus true on web, throttle heavily
  }}
>
  {children}
</SWRConfig>
```

**Why 30s and not higher:** 30s matches the typical interaction window. Users don't notice stale data within a 30s session. Post-save mutations use explicit `mutate()` to invalidate immediately — the dedup window only governs background-initiated revalidations.

---

## `dedupingInterval` vs `focusThrottleInterval` — The Distinction

These are often confused:

| Option | What it controls | When to use |
|---|---|---|
| `dedupingInterval` | Deduplicates ALL requests with the same key within the window — including focus-triggered revalidations, mount-triggered revalidations, and explicit revalidations | Always set to 30 000 |
| `focusThrottleInterval` | Specifically throttles how often a focus event can trigger revalidation — does NOT deduplicate other request types | Set if keeping `revalidateOnFocus: true` on web |
| `revalidateOnFocus: false` | Disables focus-triggered revalidation entirely | Preferred for Capacitor — use App.resume instead |

**The Capacitor trap:** `revalidateOnFocus: true` uses the browser Visibility API (`document.visibilitychange`). In Capacitor, the Visibility API fires when:
1. The user switches app tabs (inside the Capacitor app) — correct
2. The Capacitor app is foregrounded from the OS — also fires

This means every app foreground event triggers SWR revalidation across ALL mounted hooks simultaneously — a thundering herd. Setting `revalidateOnFocus: false` globally and handling revalidation explicitly in `App.resume` gives predictable, controlled behaviour.

---

## App.resume Revalidation — The Correct Pattern

```typescript
import { App } from '@capacitor/app';
import { mutate } from 'swr';

// Wire ONCE at app root — never inside a component:
App.addListener('resume', async () => {
  // 1. Refresh auth first (token may have expired while backgrounded)
  await supabase.auth.getSession();

  // 2. Revalidate all SWR caches
  mutate(() => true);  // Matches ALL keys — revalidates everything in cache
});
```

**Selective revalidation** (if full revalidation is too expensive):

```typescript
App.addListener('resume', async () => {
  await supabase.auth.getSession();

  // Revalidate only keys matching a pattern:
  mutate(key => typeof key === 'string' && key.startsWith('dashboard'));

  // Or specific keys:
  mutate(DASHBOARD_CACHE_KEY);
  mutate(INSIGHTS_CACHE_KEY);
});
```

**Why `App.resume` instead of `revalidateOnFocus`:**
- Fires exactly once per app foreground event (not per web-tab-focus)
- Lets you sequence: token refresh → revalidation (correct order)
- Explicit, predictable, easy to test

---

## `keepPreviousData: true` — Eliminating Skeleton Flashes

```typescript
// Without keepPreviousData — skeleton shows during every revalidation:
const { data, isLoading } = useSWR(key, fetcher);
// isLoading = true while revalidating → skeleton renders even when we have stale data

// With keepPreviousData — stale data shows immediately, updated silently:
const { data, isLoading } = useSWR(key, fetcher, { keepPreviousData: true });
// isLoading = true only on first load (no cached data)
// On revalidation: data = previous value, isValidating = true (no skeleton)
```

**Practical pattern:** Use `isValidating` (not `isLoading`) to show subtle refresh indicators:

```tsx
const { data, isLoading, isValidating } = useSWR(key, fetcher, {
  keepPreviousData: true,
});

if (isLoading) return <Skeleton />;      // Only on first load

return (
  <div>
    {isValidating && <RefreshIndicator />}  // Subtle refresh on revalidation
    <DataContent data={data} />
  </div>
);
```

---

## Pre-Warming — Loading Cache Before the User Navigates

Pre-warming fills the SWR cache at the parent level so child views get instant data on first visit (not just tab returns).

### Pattern: Call Child Hooks at Parent Level

```typescript
// In Dashboard (parent — always mounted):
const insightsDateRange = useMemo(() => computeDateRange(insightsTf.dayCount), [insightsTf.dayCount]);
const { data: insightsData } = useInsightsData({ dateRange: insightsDateRange }); // pre-warm
usePersonalZones(); // discard return value — SWR side-effect fills cache

// In InsightsView (child — mounted on first visit):
const { data: insightsData } = useInsightsData({ dateRange });  // instant cache hit
const { data: zones } = usePersonalZones();                      // instant cache hit
```

The key insight: SWR's cache is shared across the entire application. Calling a hook anywhere populates the cache for the same key everywhere.

---

## Key Alignment — The Silent Cache Miss

**Pre-warming only works if the keys are identical.** This is the most common failure mode.

### The Broken Pattern

```typescript
// In Dashboard:
useInsightsData()
// Key produced: ['insights-v2', 'default-28d']

// In InsightsView:
useInsightsData({ dateRange: { start: new Date(...), end: new Date(...) } })
// Key produced: ['insights-v2', '2026-06-20T00:00:00.000Z']

// Different keys → separate cache slots → Dashboard's pre-warm never helps InsightsView
```

### The Fix: Lift Key-Defining Computation to Parent

```typescript
// Shared date range computation (same formula in both places):
function buildInsightsDateRange(dayCount: number) {
  const today = getLocalTodayDate();
  const end = new Date(`${today}T23:59:59.999`);
  const start = new Date(end.getTime() - dayCount * 24 * 60 * 60 * 1000);
  return { start, end };
}

// In Dashboard:
const insightsDateRange = useMemo(
  () => buildInsightsDateRange(insightsTf.dayCount),
  [insightsTf.dayCount]
);
useInsightsData({ dateRange: insightsDateRange }); // pre-warm with exact same key

// Pass dateRange down as prop to InsightsView:
<InsightsView tf={insightsTf} dateRange={insightsDateRange} />

// In InsightsView:
useInsightsData({ dateRange: props.dateRange }); // same key → cache hit
```

### Alternative: Extract Key Function

```typescript
// In use-insights-data.ts — export the key builder:
export function buildInsightsKey(dateRange: DateRange) {
  return ['insights-v2', dateRange.start.toISOString(), dateRange.end.toISOString()];
}

// In Dashboard:
const key = buildInsightsKey(insightsDateRange);
useSWR(key, fetcher, swrConfig);  // pre-warm

// In InsightsView:
const key = buildInsightsKey(dateRange);
const { data } = useSWR(key, fetcher, swrConfig); // guaranteed same key
```

**Rule:** Never compute dates or dynamic values inside the hook with `new Date()` if the hook is called from two places. `new Date()` at different milliseconds produces different ISO strings → different keys.

---

## The `preload` API — Eager Cache Warming

For warming caches before any component mounts:

```typescript
import { preload } from 'swr';

// In the root layout or early app init — warm critical routes on app start:
async function warmCaches(userId: string) {
  await Promise.all([
    preload(['dashboard', userId], () => fetchDashboard(userId)),
    preload(['preferences', userId], () => fetchPreferences(userId)),
  ]);
  // Now hide the splash screen — first render is instant
  SplashScreen.hide();
}
```

`preload` runs the fetcher and populates the cache without a React component being mounted. Use it to fill the cache during the cold-start window (while the splash screen is showing) so the first render has data immediately.

---

## Never Raw `useEffect` + Fetch for Shared State

Every `useEffect` that fetches data to shared state is a pre-warming miss:

```typescript
// WRONG — re-fetches on every mount, no dedup, no pre-warm, no cache:
const [prefs, setPrefs] = useState<Preferences | null>(null);
useEffect(() => {
  preferencesRepo.get().then(setPrefs);
}, []);

// CORRECT — deduped, pre-warmable, participates in the cache:
export function useUserPreferences() {
  return useSWR('user-preferences', () => preferencesRepo.get(), {
    revalidateOnFocus: false,
    dedupingInterval: 30_000,
    keepPreviousData: true,
  });
}
```

If two components call `useUserPreferences()`, they share one fetch and one cache slot. If Dashboard calls it for pre-warming, SettingsView's first render is instant. This is impossible with raw `useEffect`.

---

## Post-Save Invalidation — `mutate()` is the Mechanism

The dedup window controls how often SWR auto-revalidates. It is NOT how you invalidate after a save.

```typescript
const DASHBOARD_CACHE_KEY = ['dashboard', userId];

// Save handler — always use explicit mutate:
async function handleSaveEntry(entry: Entry) {
  await entriesRepo.create(entry);

  // Invalidate: tells SWR to re-fetch on next access
  await mutate(DASHBOARD_CACHE_KEY);

  // Or invalidate and re-fetch immediately:
  await mutate(DASHBOARD_CACHE_KEY, fetchDashboard(), { revalidate: true });
}
```

**Optimistic mutate:** Update the cache immediately, revert on error:

```typescript
await mutate(
  DASHBOARD_CACHE_KEY,
  async (current) => {
    await entriesRepo.create(entry);
    return { ...current, entries: [...(current?.entries ?? []), entry] };
  },
  {
    optimisticData: (current) => ({
      ...current,
      entries: [...(current?.entries ?? []), entry],
    }),
    rollbackOnError: true,
    revalidate: false,  // Don't re-fetch after optimistic update
  }
);
```

Full optimistic writes + thin repo pattern → `reference/optimistic-writes.md`.

---

## SWR Key Conventions

Consistent key shapes make cache management predictable:

```typescript
// User-scoped data — ALWAYS scope by userId to prevent cross-user contamination:
const key = ['dashboard', userId];
const key = ['preferences', userId];
const key = ['entries', userId, dateRange];

// Global data (not user-specific):
const key = 'food-database';
const key = ['insights-v2', start.toISOString(), end.toISOString()];

// Never use object keys — different reference every render:
// BAD:
const key = { path: 'dashboard', userId };

// Object key that's stable (serialize it):
const key = JSON.stringify({ path: 'dashboard', userId }); // consistent string
```

**Sign-out contamination:** On sign-out, flush ALL user-scoped keys. If you don't, the next user who logs in on the same device may see the previous user's data briefly:

```typescript
async function handleSignOut() {
  await supabase.auth.signOut();
  // Flush all SWR caches — use a key predicate:
  await mutate(() => true, undefined, { revalidate: false }); // clear all
}
```

---

## Per-Hook Config Overrides

Some hooks warrant different settings from the global default:

```typescript
// Frequently mutated data — shorter dedup to catch rapid changes:
const { data } = useSWR(key, fetcher, {
  dedupingInterval: 5_000,   // 5s for data user edits frequently
});

// Slow-changing reference data — longer dedup:
const { data } = useSWR(key, fetcher, {
  dedupingInterval: 300_000, // 5 minutes for food database
  revalidateOnMount: false,  // Never revalidate after first load in session
});

// Real-time critical data — always fresh:
const { data } = useSWR(key, fetcher, {
  refreshInterval: 30_000,   // Poll every 30s
  dedupingInterval: 5_000,
});
```

---

## Testing SWR in Capacitor Context

### Mock SWR in Component Tests

```typescript
import { vi } from 'vitest';

vi.mock('swr', () => ({
  default: vi.fn(),
  useSWR: vi.fn(),
  mutate: vi.fn(),
}));

import useSWR from 'swr';

beforeEach(() => {
  (useSWR as ReturnType<typeof vi.fn>).mockReturnValue({
    data: mockData,
    isLoading: false,
    isValidating: false,
    error: null,
  });
});
```

### Testing Pre-Warm Behaviour

```typescript
it('pre-warms insights cache at dashboard level', () => {
  const useInsightsData = vi.fn().mockReturnValue({ data: null });

  render(<Dashboard insightsTf={{ dayCount: 28 }} />);

  // Dashboard should call useInsightsData with a dateRange (pre-warm)
  expect(useInsightsData).toHaveBeenCalledWith(
    expect.objectContaining({ dateRange: expect.any(Object) })
  );
});
```

### Testing Key Alignment

```typescript
import { buildInsightsKey } from '@/lib/hooks/use-insights-data';

it('produces identical key for same dayCount on same day', () => {
  const dateRange = buildInsightsDateRange(28);
  const key1 = buildInsightsKey(dateRange);
  const key2 = buildInsightsKey(dateRange);

  expect(key1).toEqual(key2);
});

it('dashboard and insights-view produce the same SWR key', () => {
  const dashboardDateRange = buildInsightsDateRange(28);
  const insightsViewDateRange = buildInsightsDateRange(28); // same computation

  expect(buildInsightsKey(dashboardDateRange)).toEqual(
    buildInsightsKey(insightsViewDateRange)
  );
});
```

**Do not test dedup timing** — never assert that a hook only called the fetcher once within a 30s window. Test the business logic (data renders correctly), not SWR's internal dedup mechanism.
