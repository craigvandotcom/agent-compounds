# Interaction, Navigation & Hydration

Objective patterns. Read when auditing navigation/links, URL state, destructive actions, touch optimization, drag, autofocus, or hydration safety.

## 9. Navigation & State

### URL Reflects State

```tsx
// BAD - State lost on refresh
const [tab, setTab] = useState('overview');

// GOOD - URL synced (use nuqs or similar)
const [tab, setTab] = useQueryState('tab', { defaultValue: 'overview' });

// Filters, pagination, expanded panels should be in URL
?tab=settings&page=2&expanded=section-1
```

### Links Must Be Links

```tsx
// BAD - No Cmd/Ctrl+click support
<div onClick={() => router.push('/about')}>About</div>

// GOOD - Proper link
<Link href="/about">About</Link>
```

### Destructive Actions

```tsx
// NEVER immediate - always confirm or undo
<button onClick={() => setShowDeleteConfirm(true)}>Delete</button>;

// Or provide undo
const handleDelete = () => {
  const undoId = toast('Item deleted', {
    action: { label: 'Undo', onClick: () => restore(item) },
  });
  deleteItem(item);
};
```

## 10. Touch & Interaction

### Touch Optimization

```tsx
// Remove double-tap zoom delay
<button className="touch-action-manipulation">

// Prevent tap highlight (or set intentionally)
<button className="-webkit-tap-highlight-color-transparent">

// Prevent scroll chaining in modals
<div className="overscroll-behavior-contain">
```

### Drag Operations

```tsx
// During drag: disable text selection
<div style={{ userSelect: 'none' }} onDragStart={...}>

// Add inert to dragged elements
<div inert={isDragging}>
```

### AutoFocus

```tsx
// Use sparingly - desktop only, single primary input
// Avoid on mobile (opens keyboard unexpectedly)
{
  !isMobile && <input autoFocus />;
}
```

## 13. Hydration Safety

### Controlled vs Uncontrolled

```tsx
// Inputs with value need onChange
<input value={value} onChange={onChange} />

// Or use defaultValue for uncontrolled
<input defaultValue={initialValue} />
```

### Date/Time Rendering

```tsx
// Guard against server/client mismatch
const [mounted, setMounted] = useState(false);
useEffect(() => setMounted(true), []);

{
  mounted ? <time>{formattedDate}</time> : <span>-</span>;
}

// Or use suppressHydrationWarning sparingly
<time suppressHydrationWarning>{date}</time>;
```
