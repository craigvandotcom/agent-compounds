# Animation, Typography & Content

Objective patterns. Read when auditing motion, reduced-motion safety, typographic mechanics, or content/overflow handling.

## 4. Animation

### Honor Reduced Motion

```tsx
// CSS approach
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}

// JS approach
const prefersReducedMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)'
).matches;

// Tailwind
<div className="motion-safe:animate-bounce motion-reduce:animate-none">
```

### Compositor-Friendly Animations

```tsx
// BAD - Causes layout/paint
<div className="transition-all">  // Never use transition: all
<div style={{ left: x }}>       // Triggers layout

// GOOD - GPU accelerated
<div className="transition-transform duration-200">
<div style={{ transform: `translateX(${x}px)` }}>

// Only animate transform and opacity
<div className="transition-[transform,opacity] duration-200">
```

### Explicit Transition Properties

```tsx
// BAD
className = 'transition-all';

// GOOD
className = 'transition-colors';
className = 'transition-transform';
className = 'transition-opacity';
className = 'transition-[transform,opacity]';
```

### SVG Animation

```tsx
// BAD - Transform on SVG element
<svg style={{ transform: 'rotate(45deg)' }}>

// GOOD - Transform on wrapper with correct origin
<g style={{
  transformBox: 'fill-box',
  transformOrigin: 'center',
  transform: 'rotate(45deg)'
}}>
  <path ... />
</g>
```

### Interruptible Animations

```tsx
// Animations should respond to user input mid-animation
// Use CSS transitions (interruptible) over CSS animations when possible
// For complex animations, handle interruption in animation libraries
```

## 5. Typography

### Punctuation

```tsx
// BAD
"Hello"     // Straight quotes
...         // Three dots

// GOOD
"Hello"     // Curly quotes (" ")
...          // Ellipsis character (…)

// Loading states end with ellipsis
"Loading…"
"Saving…"
"Processing…"
```

### Non-Breaking Spaces

```tsx
// Use &nbsp; to prevent awkward breaks
'10&nbsp;MB';
'⌘&nbsp;K';
'John&nbsp;Smith'; // Brand names
```

### Tabular Numbers

```tsx
// For number columns/comparisons
<td className="font-variant-numeric: tabular-nums">1,234</td>

// Tailwind
<span className="tabular-nums">$99.99</span>
```

### Text Wrapping

```tsx
// Prevent widows in headings
<h1 className="text-wrap-balance">
  Welcome to Our Platform
</h1>

// Or text-pretty for body text
<p className="text-pretty">
```

## 6. Content Handling

### Long Content

```tsx
// Handle overflow
<p className="truncate">...</p>
<p className="line-clamp-3">...</p>
<p className="break-words">...</p>

// Flex children need min-w-0 for truncation
<div className="flex">
  <span className="min-w-0 truncate">{longText}</span>
</div>
```

### Empty States

```tsx
// Always handle empty data
{
  items.length > 0 ? (
    <ItemList items={items} />
  ) : (
    <EmptyState message="No items found" />
  );
}

// Handle empty strings
{
  title?.trim() || 'Untitled';
}
```
