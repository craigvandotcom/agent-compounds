---
name: react-best-practices
description: React and Next.js performance optimization guidelines. Use when reviewing components, optimizing performance, fixing waterfalls, reducing bundle size, or implementing data fetching patterns.
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across all neoMeta apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# React Best Practices

**Purpose:** Optimize React/Next.js performance using Vercel Engineering patterns
**Source:** [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills)
**Status:** Complete

---

## When to Use This Skill

**Intent Triggers:**

- Reviewing React components for performance issues
- Optimizing data fetching (avoiding waterfalls)
- Reducing bundle size or client payload
- Implementing server components or server actions
- Fixing re-render issues or optimizing state
- Adding caching or deduplication

**When NOT to Use:**

- UI styling/design (use `design-system`)
- Testing patterns (use `testing`)
- General TypeScript without React context

---

## Priority Guide

| Category                  | Impact      | When to Apply                        |
| ------------------------- | ----------- | ------------------------------------ |
| Eliminating Waterfalls    | CRITICAL    | Always - 2-10x improvement potential |
| Bundle Size Optimization  | CRITICAL    | Always - affects initial load        |
| Server-Side Performance   | HIGH        | RSC/Server Actions work              |
| Client-Side Data Fetching | MEDIUM-HIGH | SWR/hooks work                       |
| Re-render Optimization    | MEDIUM      | Complex state/lists                  |
| Rendering Performance     | MEDIUM      | Large lists, animations              |
| JavaScript Performance    | LOW-MEDIUM  | Hot paths, loops                     |
| Advanced Patterns         | LOW         | Edge cases only                      |

---

## 1. Eliminating Waterfalls (CRITICAL)

### Defer Await Until Needed

```tsx
// BAD - Sequential requests
async function Page() {
  const user = await getUser();
  const posts = await getPosts(user.id);
  return <Feed user={user} posts={posts} />;
}

// GOOD - Parallel with deferred await
async function Page() {
  const userPromise = getUser();
  const postsPromise = getPosts();
  const [user, posts] = await Promise.all([userPromise, postsPromise]);
  return <Feed user={user} posts={posts} />;
}
```

### Parallel Data Fetching with Component Composition

```tsx
// BAD - Parent fetches everything
async function Page() {
  const user = await getUser();
  const posts = await getPosts();
  const comments = await getComments();
  return <Dashboard user={user} posts={posts} comments={comments} />;
}

// GOOD - Each component fetches its own data
async function Page() {
  return (
    <Suspense fallback={<Skeleton />}>
      <UserCard />
      <PostList />
      <CommentFeed />
    </Suspense>
  );
}
```

### Strategic Suspense Boundaries

```tsx
// BAD - Single boundary blocks everything
<Suspense fallback={<FullPageLoader />}>
  <Header />
  <MainContent />
  <Sidebar />
</Suspense>

// GOOD - Granular boundaries
<>
  <Header /> {/* Static, no suspense needed */}
  <Suspense fallback={<ContentSkeleton />}>
    <MainContent />
  </Suspense>
  <Suspense fallback={<SidebarSkeleton />}>
    <Sidebar />
  </Suspense>
</>
```

### Promise.all() for Independent Operations

```tsx
// BAD - Sequential in API route
export async function GET() {
  const users = await db.users.findMany();
  const posts = await db.posts.findMany();
  const stats = await analytics.getStats();
  return Response.json({ users, posts, stats });
}

// GOOD - Parallel
export async function GET() {
  const [users, posts, stats] = await Promise.all([
    db.users.findMany(),
    db.posts.findMany(),
    analytics.getStats(),
  ]);
  return Response.json({ users, posts, stats });
}
```

---

## 2. Bundle Size Optimization (CRITICAL)

### Avoid Barrel File Imports

```tsx
// BAD - Imports entire library
import { Button } from '@/components';
import { format } from 'date-fns';

// GOOD - Direct imports
import { Button } from '@/components/ui/button';
import format from 'date-fns/format';
```

### Dynamic Imports for Heavy Components

```tsx
// BAD - Always loaded
import { HeavyChart } from '@/components/charts';

// GOOD - Code split
const HeavyChart = dynamic(() => import('@/components/charts/HeavyChart'), {
  loading: () => <ChartSkeleton />,
  ssr: false,
});
```

### Conditional Module Loading

```tsx
// BAD - Always imports both
import { MobileNav } from './MobileNav';
import { DesktopNav } from './DesktopNav';

// GOOD - Load based on condition
const Nav = dynamic(() =>
  isMobile
    ? import('./MobileNav').then(m => m.MobileNav)
    : import('./DesktopNav').then(m => m.DesktopNav)
);
```

### Defer Non-Critical Third-Party Libraries

```tsx
// BAD - Blocks initial render
import confetti from 'canvas-confetti';

// GOOD - Load on interaction
const handleSuccess = async () => {
  const confetti = (await import('canvas-confetti')).default;
  confetti();
};
```

### Preload Based on User Intent

```tsx
// Preload on hover/focus
<Link
  href="/dashboard"
  onMouseEnter={() => router.prefetch('/dashboard')}
  onFocus={() => router.prefetch('/dashboard')}
>
  Dashboard
</Link>
```

---

## 3. Server-Side Performance (HIGH)

### Per-Request Deduplication with React.cache()

```tsx
// Without cache - multiple DB calls
async function getUser(id: string) {
  return db.user.findUnique({ where: { id } });
}

// With cache - deduplicated per request
const getUser = cache(async (id: string) => {
  return db.user.findUnique({ where: { id } });
});
```

### Use after() for Non-Blocking Operations

```tsx
import { after } from 'next/server';

export async function POST(request: Request) {
  const data = await request.json();
  const result = await saveToDatabase(data);

  // Non-blocking - runs after response sent
  after(async () => {
    await analytics.track('submission', data);
    await sendNotification(data);
  });

  return Response.json(result);
}
```

### Minimize Serialization at RSC Boundaries

```tsx
// BAD - Passes entire object
async function Page() {
  const user = await getUser(); // { id, name, email, settings, history, ... }
  return <Profile user={user} />;
}

// GOOD - Pass only what's needed
async function Page() {
  const user = await getUser();
  return <Profile name={user.name} email={user.email} />;
}
```

### Authenticate Server Actions Like API Routes

```tsx
'use server';

export async function updateProfile(formData: FormData) {
  const session = await getSession();
  if (!session) {
    throw new Error('Unauthorized');
  }

  // Validate input
  const data = schema.parse(Object.fromEntries(formData));

  return db.user.update({
    where: { id: session.userId },
    data,
  });
}
```

---

## 4. Client-Side Data Fetching (MEDIUM-HIGH)

### Use SWR for Automatic Deduplication

```tsx
// BAD - Manual fetching in multiple components
function ComponentA() {
  const [data, setData] = useState(null);
  useEffect(() => {
    fetch('/api/data')
      .then(r => r.json())
      .then(setData);
  }, []);
}

// GOOD - SWR deduplicates automatically
function ComponentA() {
  const { data } = useSWR('/api/data', fetcher);
}
function ComponentB() {
  const { data } = useSWR('/api/data', fetcher); // Same cache, no refetch
}
```

### Version and Minimize localStorage Data

```tsx
// BAD - Unversioned, may break
localStorage.setItem('settings', JSON.stringify(settings));

// GOOD - Versioned with migration
const STORAGE_VERSION = 2;
const stored = JSON.parse(localStorage.getItem('settings') || '{}');
if (stored.version !== STORAGE_VERSION) {
  stored = migrateSettings(stored);
}
```

---

## 5. Re-render Optimization (MEDIUM)

### Use Functional setState Updates

```tsx
// BAD - Stale closure risk, triggers extra renders
setCount(count + 1);
setItems([...items, newItem]);

// GOOD - Always current, batched
setCount(c => c + 1);
setItems(prev => [...prev, newItem]);
```

### Use Lazy State Initialization

```tsx
// BAD - Computed every render
const [data, setData] = useState(expensiveComputation());

// GOOD - Computed once
const [data, setData] = useState(() => expensiveComputation());
```

### Extract to Memoized Components

```tsx
// BAD - Child re-renders on parent state change
function Parent() {
  const [count, setCount] = useState(0);
  return (
    <div>
      <button onClick={() => setCount(c => c + 1)}>+</button>
      <ExpensiveChild data={staticData} />
    </div>
  );
}

// GOOD - Memoized child
const MemoizedChild = memo(ExpensiveChild);
function Parent() {
  const [count, setCount] = useState(0);
  return (
    <div>
      <button onClick={() => setCount(c => c + 1)}>+</button>
      <MemoizedChild data={staticData} />
    </div>
  );
}
```

### Use Transitions for Non-Urgent Updates

```tsx
// BAD - Blocks UI on heavy update
const handleSearch = (query: string) => {
  setQuery(query);
  setSearchResults(search(query)); // Expensive
};

// GOOD - Non-blocking with transition
const [isPending, startTransition] = useTransition();
const handleSearch = (query: string) => {
  setQuery(query);
  startTransition(() => {
    setSearchResults(search(query));
  });
};
```

### Don't Wrap Simple Expressions in useMemo

```tsx
// BAD - Overhead exceeds benefit
const doubled = useMemo(() => count * 2, [count]);
const fullName = useMemo(() => `${first} ${last}`, [first, last]);

// GOOD - Direct computation
const doubled = count * 2;
const fullName = `${first} ${last}`;

// GOOD - useMemo for expensive operations
const sortedItems = useMemo(
  () => items.sort((a, b) => a.score - b.score),
  [items]
);
```

---

## 6. Rendering Performance (MEDIUM)

### CSS content-visibility for Long Lists

```css
.list-item {
  content-visibility: auto;
  contain-intrinsic-size: auto 100px;
}
```

### Hoist Static JSX Elements

```tsx
// BAD - Created every render
function Component() {
  const header = <Header title="Static" />;
  return <div>{header}</div>;
}

// GOOD - Created once
const header = <Header title="Static" />;
function Component() {
  return <div>{header}</div>;
}
```

### Prevent Hydration Mismatch Without Flickering

```tsx
// BAD - Flash of wrong content
function ThemeProvider({ children }) {
  const [theme, setTheme] = useState('light');
  useEffect(() => {
    setTheme(localStorage.getItem('theme') || 'light');
  }, []);
  return (
    <ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>
  );
}

// GOOD - Inline script sets before hydration
// In _document.tsx or layout.tsx <head>
<script
  dangerouslySetInnerHTML={{
    __html: `
      document.documentElement.dataset.theme =
        localStorage.getItem('theme') || 'light';
    `,
  }}
/>;
```

### Use Explicit Conditional Rendering

```tsx
// BAD - Component mounts/unmounts
{showModal && <Modal />}

// GOOD for animations - CSS visibility
<Modal style={{ display: showModal ? 'block' : 'none' }} />

// Or use Activity for preserved state (React 19+)
<Activity mode={showModal ? 'visible' : 'hidden'}>
  <Modal />
</Activity>
```

---

## 7. JavaScript Performance (LOW-MEDIUM)

### Use Set/Map for O(1) Lookups

```tsx
// BAD - O(n) lookup
const isSelected = selectedIds.includes(id);

// GOOD - O(1) lookup
const selectedSet = new Set(selectedIds);
const isSelected = selectedSet.has(id);
```

### Early Return from Functions

```tsx
// BAD - Nested conditions
function process(data) {
  if (data) {
    if (data.isValid) {
      return transform(data);
    }
  }
  return null;
}

// GOOD - Guard clauses
function process(data) {
  if (!data) return null;
  if (!data.isValid) return null;
  return transform(data);
}
```

### Cache Property Access in Loops

```tsx
// BAD - Property lookup each iteration
for (let i = 0; i < array.length; i++) {
  process(array[i]);
}

// GOOD - Cached length
for (let i = 0, len = array.length; i < len; i++) {
  process(array[i]);
}
```

### Combine Multiple Array Iterations

```tsx
// BAD - 3 passes
const filtered = items.filter(x => x.active);
const mapped = filtered.map(x => x.value);
const total = mapped.reduce((a, b) => a + b, 0);

// GOOD - Single pass
const total = items.reduce(
  (sum, item) => (item.active ? sum + item.value : sum),
  0
);
```

---

## Anti-Patterns to Flag

| Pattern                                     | Issue              |
| ------------------------------------------- | ------------------ |
| Sequential awaits in same function          | Creates waterfall  |
| `import { x } from 'library'` on large libs | Bundle bloat       |
| `useState(expensiveCall())`                 | Runs every render  |
| `useMemo` for simple math/concat            | Overhead > benefit |
| Missing `key` or using index as key         | Re-render bugs     |
| `useEffect` for derived state               | Should be computed |
| Fetching in useEffect without SWR/cache     | No deduplication   |
| `transition: all`                           | Performance hit    |

---

## Supporting Documentation

| Resource                                                                                                              | When to Read                     |
| --------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| [AGENTS.md (full rules)](https://github.com/vercel-labs/agent-skills/blob/main/skills/react-best-practices/AGENTS.md) | Deep dive into any specific rule |
| [Next.js Docs](https://nextjs.org/docs)                                                                               | Framework-specific patterns      |
| `design-system/SKILL.md`                                                                                              | UI/styling patterns              |
