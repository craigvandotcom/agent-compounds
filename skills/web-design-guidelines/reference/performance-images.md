# Performance & Images

Objective patterns. Read when auditing image attributes, loading strategy, virtualization, or layout thrashing.

> Deep React/Next perf engineering (waterfalls, bundle, re-renders) → `react-best-practices`.
> Perceived-speed *feel* (skeletons, optimistic UI) → `ui-elevate`.

## 7. Images

### Required Attributes

```tsx
// Always specify dimensions (prevents CLS)
<img
  src="/hero.jpg"
  alt="Product showcase"
  width={800}
  height={600}
/>

// Next.js Image handles this automatically
<Image src="/hero.jpg" alt="..." width={800} height={600} />
```

### Loading Strategy

```tsx
// Below-fold images: lazy load
<img loading="lazy" src="/below-fold.jpg" />

// Above-fold critical images: priority
<Image src="/hero.jpg" priority />
// Or
<img fetchPriority="high" src="/hero.jpg" />
```

## 8. Performance

### Virtualization

```tsx
// Large lists (>50 items) must be virtualized
import { VList } from 'virtua';

<VList style={{ height: 400 }}>
  {items.map((item) => (
    <ListItem key={item.id} item={item} />
  ))}
</VList>

// Or use CSS content-visibility
.list-item {
  content-visibility: auto;
  contain-intrinsic-size: auto 80px;
}
```

### Avoid Layout Thrashing

```tsx
// BAD - Interleaved reads/writes
items.forEach(item => {
  const height = item.offsetHeight; // Read
  item.style.height = height + 10; // Write
});

// GOOD - Batch reads, then writes
const heights = items.map(item => item.offsetHeight);
items.forEach((item, i) => {
  item.style.height = heights[i] + 10;
});

// NEVER read layout in render
function Component() {
  // BAD - triggers layout
  const height = ref.current?.offsetHeight;
}
```

### Preconnect Critical Origins

```tsx
// In <head>
<link rel="preconnect" href="https://cdn.example.com" />
<link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossOrigin="" />
```
