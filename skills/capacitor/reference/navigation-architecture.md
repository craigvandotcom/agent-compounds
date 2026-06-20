# Navigation Architecture — Keep-Mounted Tabs

Tab navigation architecture for Capacitor native apps. The central problem: React's conditional rendering unmounts and remounts components on every tab switch, which is correct behaviour for web apps but catastrophically wrong for native apps where tab switches must be instant.

---

## The Problem: What Conditional Rendering Costs

```tsx
// This pattern — correct on web, wrong in Capacitor:
{currentView === 'settings' && <SettingsView />}
{currentView === 'entries' && <EntriesView />}
{currentView === 'insights' && <InsightsView />}
```

Every switch triggers:

| Symptom | Root Cause |
|---|---|
| Stagger animation flash | `initial="hidden"` on `<motion.div>` replays on mount |
| Skeleton flash on tab return | SWR `dedupingInterval` elapsed → full re-fetch |
| Scroll position lost | DOM node destroyed and recreated |
| State reset | All React state destroyed on unmount |
| SWR cache miss | If different keys, cache slot abandoned |

Users feel the app is sluggish. On a mid-tier iPhone, visible loading on every tab switch is the difference between "feels native" and "feels like a website".

---

## Solution A: CSS Hidden + Mount-on-First-Visit (Recommended)

**Principle:** Render a tab once (on first visit), then toggle its visibility with CSS. The DOM node, React state, SWR cache, and scroll position all survive.

### The `visitedTabs` Pattern

```tsx
type ViewType = 'insights' | 'entries' | 'settings';

// State — tracks which tabs have been mounted at least once
const [visitedTabs, setVisitedTabs] = useState<Set<ViewType>>(
  () => new Set([currentView] as ViewType[])  // mount initial view immediately
);

// Extend the visited set on navigation
const handleViewChange = useCallback((newView: ViewType) => {
  setVisitedTabs(prev => {
    if (prev.has(newView)) return prev;        // already visited → no state update
    return new Set([...prev, newView]);
  });
  setCurrentView(newView);
}, [setCurrentView]);

// Helpers
const tabVisible = (view: ViewType) => currentView === view;
const tabMounted = (view: ViewType) => visitedTabs.has(view);
```

### JSX — Replace Conditional Renders

```tsx
// Before:
{currentView === 'insights' && <InsightsView ... />}

// After:
{tabMounted('insights') && (
  <div hidden={!tabVisible('insights')} aria-hidden={!tabVisible('insights')}>
    <ErrorBoundary fallback={<SupabaseErrorFallback />}>
      <InsightsView ... />
    </ErrorBoundary>
  </div>
)}
```

### Why `hidden` Attribute (not `style={{ display: 'none' }}`)

- `hidden` is an HTML boolean attribute that sets `display: none !important` natively
- No inline style specificity battles with Tailwind
- `aria-hidden={!tabVisible(...)}` hides the subtree from assistive technology
- Cleaner than a `className` toggle for this use case

### Why Not Pre-Mount All Tabs

Don't render all three tabs on initial load:

```tsx
// WRONG — triggers 3× SWR fetches simultaneously on cold start:
<div hidden={currentView !== 'insights'}><InsightsView /></div>
<div hidden={currentView !== 'entries'}><EntriesView /></div>
<div hidden={currentView !== 'settings'}><SettingsView /></div>
```

The `visitedTabs` Set gates mounting until the user actually navigates to the tab. Cold start only mounts the initial view. Subsequent navigations mount each tab exactly once.

---

## `display: none` vs `visibility: hidden` — The Tradeoff

Both hide the element. The critical difference is scroll position:

| Property | Layout | GPU layer | Scroll position | When to use |
|---|---|---|---|---|
| `display: none` (`hidden` attr) | Removed | Released | **RESET on re-show** | Most tabs — simpler, cleaner accessibility |
| `visibility: hidden` (Tailwind `invisible`) | Preserved | Maintained | **Preserved on re-show** | Tabs with scrollable content where position must persist |

**Ionic's finding** (issue #7177): `display: none` triggers a full layout recalculation when the element re-appears, causing a measurable repaint on re-show. `visibility: hidden` keeps the element in the layout flow and preserves GPU composite layers — no repaint cost. For most tab switches this difference is imperceptible, but for tabs with heavy DOM or long scroll lists, `visibility: hidden` is preferable.

```tsx
// If scroll preservation matters:
{tabMounted('entries') && (
  <div
    className={tabVisible('entries') ? '' : 'invisible absolute inset-0 pointer-events-none'}
    aria-hidden={!tabVisible('entries')}
  >
    <EntriesView ... />
  </div>
)}
```

`absolute inset-0` prevents the invisible tab from pushing other elements during layout. `pointer-events-none` ensures hidden tabs don't intercept touches.

---

## Animation Cleanup

Framer Motion stagger animations that animate `opacity` from 0 on mount will replay whenever the component mounts. With keep-mounted tabs, the animation plays once and is then preserved — this is correct behaviour. However, if the stagger was the source of the flash (which it often is), remove it entirely:

```tsx
// Before — flash source:
<motion.div
  initial="hidden"
  animate="show"
  variants={containerVariants}  // staggerChildren: 0.1
>
  {items.map(item => (
    <motion.div key={item.id} variants={itemVariants}>
      {/* ... */}
    </motion.div>
  ))}
</motion.div>

// After — plain div, instant render:
<div className="space-y-3">
  {items.map(item => (
    <div key={item.id}>{/* ... */}</div>
  ))}
</div>
```

Keep subtle mount animations only for content that should announce itself (e.g., modal overlays). Navigation tabs are structural — they should feel instant, not performative.

---

## Scroll Position on Tab Return

With `hidden` attribute (display:none), scroll position resets when the tab re-appears. If this is undesirable:

**Option 1:** Use `visibility: hidden` instead (scroll position preserved natively).

**Option 2:** Save and restore scroll position manually:

```tsx
const scrollPositions = useRef<Partial<Record<ViewType, number>>>({});

const handleViewChange = useCallback((newView: ViewType) => {
  // Save current scroll position before switching
  const container = scrollContainerRef.current;
  if (container) {
    scrollPositions.current[currentView] = container.scrollTop;
  }
  setVisitedTabs(prev => prev.has(newView) ? prev : new Set([...prev, newView]));
  setCurrentView(newView);
  // Restore next tab's scroll position after render
  requestAnimationFrame(() => {
    if (container) {
      container.scrollTop = scrollPositions.current[newView] ?? 0;
    }
  });
}, [currentView, setCurrentView]);
```

**Option 3:** Use a `useEffect` on `currentView` to scroll-to-top on first visit only:

```tsx
useEffect(() => {
  if (!scrollPositions.current[currentView]) {
    scrollContainerRef.current?.scrollTo(0, 0);
  }
}, [currentView]);
```

---

## React 19 `<Activity>` — Upgrade Path

React 19.2 introduced the `<Activity>` component as the first-party answer to this problem. It suspends effects in hidden mode while preserving state.

### Current Status (React 19.2.x)

- API: `unstable_Activity` — still marked unstable
- Semantics: `mode="hidden"` → effects cleanup (conceptual unmount), state preserved, updates deferred to idle priority, `display: none` applied
- Semantics: `mode="visible"` → effects remount, normal rendering

### Key Difference From CSS Hidden

```tsx
// CSS hidden — effects CONTINUE running in background:
<div hidden={!tabVisible('entries')}>
  <EntriesView />  // useEffect intervals still fire; SWR still revalidates
</div>

// <Activity mode="hidden"> — effects SUSPEND:
<Activity mode={tabVisible('entries') ? 'visible' : 'hidden'}>
  <EntriesView />  // useEffect cleanup runs; intervals stop; SWR pauses
</Activity>
```

For tabs that run background work (periodic re-fetch, intervals), `<Activity>` is more correct. For most data-display tabs, CSS hidden is simpler and equally effective.

### Migration Pattern (When `<Activity>` Stabilises)

```tsx
import { unstable_Activity as Activity } from 'react';

// One-line swap per tab — no other changes required:
{tabMounted('insights') && (
  <Activity mode={tabVisible('insights') ? 'visible' : 'hidden'}>
    <InsightsView ... />
  </Activity>
)}
```

Remove `hidden`/`aria-hidden` div wrappers — Activity handles accessibility itself.

### Caveat: Data Fetching Compatibility

`<Activity>` only warms data fetched via Suspense-compatible sources (Relay, `use()` hook, RSC). SWR's `useSWR` is NOT Suspense-integrated by default — its cache persists independently of Activity lifecycle. For SWR-based apps, CSS hidden achieves the same user-facing result with no compatibility risk.

---

## Testing Keep-Mounted Components

### Component Tests (Vitest + RTL)

Keep-mounted tabs mean all views mount simultaneously in full-page renders. Isolate per test:

```typescript
// Don't render the whole page — render the view directly:
import { render, screen } from '@testing-library/react';
import { InsightsView } from './insights-view';

it('renders insights data', () => {
  render(<InsightsView allFoods={mockFoods} allSymptoms={mockSymptoms} />);
  expect(screen.getByText('Insights')).toBeInTheDocument();
});
```

### Testing Tab Lifecycle

```typescript
import { render, screen, fireEvent } from '@testing-library/react';
import { Dashboard } from './page';

it('mounts tabs on first visit and keeps them mounted', () => {
  const { container } = render(<Dashboard />);

  // Initial state: only current tab mounted
  expect(screen.queryByTestId('entries-view')).not.toBeInTheDocument();

  // Navigate to entries
  fireEvent.click(screen.getByRole('tab', { name: /entries/i }));
  expect(screen.getByTestId('entries-view')).toBeInTheDocument();

  // Switch away from entries
  fireEvent.click(screen.getByRole('tab', { name: /insights/i }));

  // Entries should still be mounted (keep-alive), just hidden
  expect(screen.getByTestId('entries-view')).toBeInTheDocument();
  expect(screen.getByTestId('entries-view').closest('[hidden]')).toBeTruthy();
});
```

### Testing `visibility: hidden` vs `display: none`

RTL's `toBeVisible()` checks `display: none` and `visibility: hidden` differently:

```typescript
// hidden attribute (display:none) — toBeVisible() returns false:
expect(element).not.toBeVisible();  // ✓

// visibility:hidden — toBeVisible() may return TRUE (RTL doesn't check this by default):
// Check computed style directly:
expect(window.getComputedStyle(element).visibility).toBe('hidden');
```

### Tests That May Break After Keep-Mounted Migration

| Test pattern | Issue | Fix |
|---|---|---|
| Asserts component unmounts on tab switch | Now it stays mounted | Assert `hidden` attribute instead |
| Mocks `useEffect` cleanup timing | Cleanup no longer fires on tab switch | Test explicit unmount path separately |
| Renders full Dashboard and asserts only one view | All visited tabs render | Filter by non-hidden elements, or render views in isolation |
| Uses `screen.getByTestId` assuming unique IDs | Keep-mounted = all views in DOM | Use `within()` to scope queries to the visible tab |

---

## Platform Detection for Tab Behaviour

If web and native require different tab strategies:

```typescript
import { Capacitor } from '@capacitor/core';

const useKeepMountedTabs = Capacitor.isNativePlatform();

// On web: conditional rendering is fine (tab switches are free)
// On native: keep-mounted required (tab switches must be <16ms)
{useKeepMountedTabs
  ? tabMounted('settings') && (
      <div hidden={!tabVisible('settings')} aria-hidden={!tabVisible('settings')}>
        <SettingsView ... />
      </div>
    )
  : currentView === 'settings' && <SettingsView ... />
}
```

In practice, keep-mounted on both platforms is simpler and causes no harm on web.
