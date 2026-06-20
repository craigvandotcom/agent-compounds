# React Performance for Capacitor Static Export

Performance patterns for React + Next.js `output: 'export'` running inside WKWebView. There is no server runtime — every byte executes client-side. Generic Next.js performance guides include server-specific patterns that **do not apply here** and must be skipped.

---

## What Does NOT Apply on Static Export

Skip entirely when you see these in generic React guides:

| Pattern | Why Not Applicable |
|---|---|
| `React.cache()` | Per-request deduplication — no request server exists |
| `after()` from `next/server` | Post-response hooks — no server |
| RSC serialization minimization | No React Server Components |
| Server Action auth patterns | No server |
| `<Suspense>` for server data streaming | All data is client-side; `<Suspense>` is still valid for lazy-loaded components |

**For data fetching:** `reference/swr-native-discipline.md` is the authority. Pre-warming + `preload` API replace the server-side data patterns entirely.

---

## 1. Parallel Data Fetching (CRITICAL)

Sequential awaits for independent operations are a waterfall — each blocks the next. Always launch independent fetches in parallel.

### Utility Functions and API Handlers

```typescript
// WRONG — sequential, 3× slower than parallel
async function getDashboardData(userId: string) {
  const signals = await fetchSignals(userId);
  const insights = await fetchInsights(userId);
  const zones = await fetchPersonalZones(userId);
  return { signals, insights, zones };
}

// CORRECT — parallel
async function getDashboardData(userId: string) {
  const [signals, insights, zones] = await Promise.all([
    fetchSignals(userId),
    fetchInsights(userId),
    fetchPersonalZones(userId),
  ]);
  return { signals, insights, zones };
}
```

### Defer Await Until Needed

Start the fetch as early as possible; `await` only when the value is required:

```typescript
// WRONG — waits for user before starting postsPromise
async function loadProfile(userId: string) {
  const user = await getUser(userId);
  const posts = await getUserHistory(user.id);
  return { user, posts };
}

// CORRECT — userId known, launch both immediately
async function loadProfile(userId: string) {
  const userPromise = getUser(userId);
  const postsPromise = getUserHistory(userId);
  const [user, posts] = await Promise.all([userPromise, postsPromise]);
  return { user, posts };
}
```

### Parallel SWR Pre-Warming

Don't chain SWR hooks where the second doesn't need data from the first. Call both at the parent level — SWR fires them concurrently and both cache slots fill in parallel:

```typescript
// In Dashboard (parent — always mounted):
useInsightsData({ dateRange });  // pre-warm — fires immediately
usePersonalZones();              // pre-warm — fires concurrently, not after

// In InsightsView (child):
const { data: insights } = useInsightsData({ dateRange }); // instant cache hit
const { data: zones } = usePersonalZones();                // instant cache hit
```

Full SWR pre-warming, key alignment, and App.resume integration → `reference/swr-native-discipline.md`.

---

## 2. Bundle Size (CRITICAL)

The initial JS bundle loads and evaluates on every cold start inside WKWebView. Smaller bundle = faster cold start; every unnecessary KB adds latency before the splash screen can hide.

### No Barrel File Imports

```typescript
// WRONG — imports entire component library barrel
import { Button, Card, Input, Select } from '@/components';
import { format } from 'date-fns';

// CORRECT — direct imports (only the imported module loads)
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import format from 'date-fns/format';
```

**Why barrels are dangerous:** A barrel `index.ts` re-exports everything in the directory. Tree-shaking only works when bundlers can statically trace the import graph — barrel re-exports break this analysis in most real projects.

### Dynamic Imports for Heavy Components

```typescript
// WRONG — HeavyChart always in initial bundle
import { HeavyChart } from '@/features/insights/charts';

// CORRECT — split; only loads when InsightsView mounts
const HeavyChart = dynamic(() => import('@/features/insights/charts/HeavyChart'), {
  loading: () => <ChartSkeleton />,
  ssr: false,  // REQUIRED on static export
});
```

**`ssr: false` is mandatory** for any dynamic import using browser APIs (`window`, `document`, `localStorage`), Capacitor APIs, or any code that would crash during `next build` prerendering.

### Defer Non-Critical Third-Party Libraries

```typescript
// WRONG — in initial bundle even though rarely used
import confetti from 'canvas-confetti';

// CORRECT — load only when needed (on celebration success)
const handleSuccess = async () => {
  const confetti = (await import('canvas-confetti')).default;
  confetti();
};
```

### Preload on User Intent

```typescript
// Prefetch the route on hover/focus — arrives before the user clicks
<Link
  href="/app/insights"
  onMouseEnter={() => router.prefetch('/app/insights')}
  onFocus={() => router.prefetch('/app/insights')}
>
  Insights
</Link>
```

---

## 3. Re-render Optimization (MEDIUM-HIGH)

Dropped frames are visible inside WKWebView. Eliminate unnecessary re-renders, especially in list items and frequently-updated components.

### Functional setState — Always

```typescript
// WRONG — captures stale closure; extra renders when batched
setCount(count + 1);
setEntries([...entries, newEntry]);

// CORRECT — always receives current value; batches correctly
setCount(c => c + 1);
setEntries(prev => [...prev, newEntry]);
```

### Lazy State Initialization

```typescript
// WRONG — computeInitialState() runs on every render
const [filters, setFilters] = useState(computeInitialFilters());

// CORRECT — callback runs only on mount
const [filters, setFilters] = useState(() => computeInitialFilters());
```

### memo() on Expensive List Children

```typescript
// WRONG — every SignalCard re-renders whenever the parent state changes
function SignalLog({ entries }: Props) {
  const [filter, setFilter] = useState<string | null>(null);
  return (
    <div>
      <FilterBar value={filter} onChange={setFilter} />
      {entries.map(e => <SignalCard key={e.id} entry={e} />)}
    </div>
  );
}

// CORRECT — SignalCard only re-renders if its own props change
const MemoizedSignalCard = memo(SignalCard);
function SignalLog({ entries }: Props) {
  const [filter, setFilter] = useState<string | null>(null);
  return (
    <div>
      <FilterBar value={filter} onChange={setFilter} />
      {entries.map(e => <MemoizedSignalCard key={e.id} entry={e} />)}
    </div>
  );
}
```

### useTransition for Heavy Synchronous Updates

```typescript
// WRONG — synchronous filter blocks input responsiveness during typing
function handleSearch(query: string) {
  setQuery(query);
  setResults(filterEntries(entries, query)); // Synchronous; may block for 50-100ms
}

// CORRECT — input renders immediately; filter result deferred
const [isPending, startTransition] = useTransition();
function handleSearch(query: string) {
  setQuery(query);
  startTransition(() => {
    setResults(filterEntries(entries, query));
  });
}
```

### useMemo Threshold

The cost of `useMemo` (dependency comparison + closure allocation) exceeds the benefit for simple expressions:

```typescript
// WRONG — overhead exceeds benefit
const doubled = useMemo(() => count * 2, [count]);
const displayName = useMemo(() => `${first} ${last}`, [first, last]);
const isOverdue = useMemo(() => status === 'overdue', [status]);

// CORRECT — compute inline; React is fast at simple math/concat
const doubled = count * 2;
const displayName = `${first} ${last}`;
const isOverdue = status === 'overdue';

// CORRECT — useMemo for genuinely expensive operations
const sortedEntries = useMemo(
  () => [...entries].sort((a, b) => b.createdAt - a.createdAt),
  [entries]
);
const filteredZones = useMemo(
  () => zones.filter(z => z.score > threshold),
  [zones, threshold]
);
```

**Rule of thumb:** If the computation doesn't involve sorting, filtering a large array, or a heavy derivation, skip `useMemo`. Profile first; memoize second.

---

## 4. Rendering Performance (MEDIUM)

### Hoist Static JSX Elements

JSX inside a function creates a new object reference on every render, even if the element never changes:

```typescript
// WRONG — new React element on every render (referential inequality)
function EmptyState() {
  const icon = <EmptyIcon className="text-muted" size={48} />;
  return <div className="empty-state">{icon}</div>;
}

// CORRECT — created once at module scope
const EMPTY_ICON = <EmptyIcon className="text-muted" size={48} />;
function EmptyState() {
  return <div className="empty-state">{EMPTY_ICON}</div>;
}
```

### CSS `content-visibility` for Long Lists

Long food logs, history lists, or any scrollable list that regularly exceeds 20+ items:

```css
.entry-row {
  content-visibility: auto;
  contain-intrinsic-size: auto 96px; /* Estimated item height — prevents cumulative layout shift */
}
```

Tells the browser to skip painting off-screen items entirely. Effective inside WKWebView where GPU resources are shared with the native layer.

### Hydration Mismatch Prevention

Static export runs `next build` prerendering on values that don't exist server-side. Runtime-only values (localStorage, Capacitor APIs, `window.innerWidth`) must be deferred to `useEffect`:

```typescript
// WRONG — `localStorage` doesn't exist at prerender time → hydration error
const [theme, setTheme] = useState(localStorage.getItem('theme') || 'light');

// CORRECT — null initial state, deferred read
const [theme, setTheme] = useState<string | null>(null);
useEffect(() => {
  setTheme(localStorage.getItem('theme') || 'light');
}, []);

// CORRECT (no flash) — inline script sets before hydration
// In layout.tsx <head>:
<script
  dangerouslySetInnerHTML={{
    __html: `
      document.documentElement.dataset.theme =
        localStorage.getItem('bc-theme') || 'dark';
    `,
  }}
/>
```

Note: for `@capacitor/preferences` (not localStorage), always use `useEffect` — it's async and unavailable at render time.

---

## 5. JavaScript Performance (LOW-MEDIUM)

### Set/Map for Repeated Lookups

```typescript
// WRONG — O(n) lookup inside render or loop
const isSelected = selectedIds.includes(id);

// CORRECT — build Set once, O(1) lookups thereafter
const selectedSet = useMemo(() => new Set(selectedIds), [selectedIds]);
const isSelected = selectedSet.has(id);
```

`visitedTabs` in the keep-mounted nav pattern (§2 of `capacitor-native`) uses exactly this — a `Set` for O(1) tab mount checks.

### Guard Clauses Over Nested Conditions

```typescript
// WRONG — nesting obscures intent and increases cognitive load
function processEntry(entry: Entry | null) {
  if (entry) {
    if (entry.isValid) {
      if (entry.foods.length > 0) {
        return computeScore(entry);
      }
    }
  }
  return null;
}

// CORRECT — fail fast, readable top-down
function processEntry(entry: Entry | null) {
  if (!entry) return null;
  if (!entry.isValid) return null;
  if (entry.foods.length === 0) return null;
  return computeScore(entry);
}
```

### Single-Pass Array Operations

```typescript
// WRONG — 3 passes over the same array
const active = entries.filter(e => e.isActive);
const scores = active.map(e => e.score);
const total = scores.reduce((a, b) => a + b, 0);

// CORRECT — 1 pass
const total = entries.reduce(
  (sum, e) => e.isActive ? sum + e.score : sum,
  0
);
```

---

## Anti-Patterns — Flag on Every PR

| Pattern | Problem | Fix |
|---|---|---|
| Sequential `await` for independent ops | Waterfall — 2-10× slower | `Promise.all()` |
| `import { x } from '@/components'` | Bundle bloat, breaks tree-shaking | Direct path import |
| `useState(expensiveCall())` | Runs on every render | `useState(() => expensiveCall())` |
| `useMemo` for simple math/string | Overhead exceeds benefit | Compute inline |
| Missing `key` or index as `key` in lists | Broken reconciliation, re-render bugs | Stable unique ID |
| `useEffect` for derived state | Unnecessary async; triggers cascading renders | Compute inline or `useMemo` |
| `useEffect` + `fetch` without SWR | No dedup, re-fetches on every mount | `useSWR` hook |
| `transition: all` on interactive elements | Delays color changes by full duration | `transition-transform` only (see also §5 in SKILL.md) |
| Barrel imports on large feature dirs | Bundle bloat, defeats tree-shaking | Direct module path |
| `useMemo`/`useCallback` everywhere | Premature optimisation — adds overhead | Profile first; memoize second |
