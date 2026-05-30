---
name: web-design-guidelines
description: Web interface best practices for accessibility, forms, animations, typography, and UX. Use when reviewing UI code, checking accessibility, auditing design patterns, or fixing UX issues.
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across all neoMeta apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Web Design Guidelines

**Purpose:** Audit UI code against 100+ web interface best practices
**Source:** [vercel-labs/web-interface-guidelines](https://github.com/vercel-labs/web-interface-guidelines)
**Status:** Complete

---

## When to Use This Skill

**Intent Triggers:**

- Reviewing UI code for best practices
- Checking accessibility compliance
- Auditing form implementations
- Reviewing animations and transitions
- Fixing typography or content issues
- Improving touch interactions

**When NOT to Use:**

- React performance issues (use `react-best-practices`)
- Project-specific design tokens (use `design-system`)
- Testing patterns (use `testing`)

---

## Quick Audit Checklist

Run through these categories when reviewing UI code:

- [ ] **Accessibility** - Labels, ARIA, keyboard, semantics
- [ ] **Focus States** - Visible focus, focus-visible
- [ ] **Forms** - Autocomplete, validation, errors
- [ ] **Animation** - Reduced motion, compositor-friendly
- [ ] **Typography** - Quotes, ellipsis, tabular-nums
- [ ] **Images** - Dimensions, lazy loading
- [ ] **Performance** - Virtualization, no layout thrashing
- [ ] **Touch** - Touch-action, overscroll-behavior

---

## 1. Accessibility

### Required Patterns

```tsx
// Icon buttons need aria-label
<button aria-label="Close dialog">
  <XIcon aria-hidden="true" />
</button>

// Form controls need labels
<label htmlFor="email">Email</label>
<input id="email" type="email" />

// Or use aria-label
<input type="search" aria-label="Search products" />

// Interactive elements need keyboard handlers
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => e.key === 'Enter' && handleClick()}
>

// Images need alt text
<img src="hero.jpg" alt="Team collaborating on whiteboard" />

// Decorative images
<img src="decorative-line.svg" alt="" aria-hidden="true" />

// Async updates need aria-live
<div aria-live="polite">{statusMessage}</div>
```

### Semantic HTML Priority

```tsx
// BAD - div with click handler
<div onClick={handleAction}>Submit</div>

// GOOD - semantic elements
<button onClick={handleAction}>Submit</button>
<a href="/dashboard">Go to Dashboard</a>
<nav>...</nav>
<main>...</main>
<article>...</article>
```

### Heading Hierarchy

```tsx
// BAD - Skipping levels
<h1>Page Title</h1>
<h3>Section</h3>  {/* Skipped h2 */}

// GOOD - Sequential
<h1>Page Title</h1>
<h2>Section</h2>
<h3>Subsection</h3>

// Include skip link
<a href="#main-content" className="sr-only focus:not-sr-only">
  Skip to main content
</a>
```

---

## 2. Focus States

### Required Patterns

```tsx
// GOOD - Visible focus ring
<button className="focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2">

// BAD - Removes focus without replacement
<button className="outline-none">  {/* NEVER do this */}

// GOOD - Use focus-visible over focus (avoids ring on click)
<button className="focus-visible:ring-2">  {/* Not focus:ring-2 */}

// Group focus for compound controls
<div className="focus-within:ring-2">
  <input />
  <button>Search</button>
</div>
```

### Scroll Margin for Anchors

```css
/* Prevent fixed headers from covering anchored headings */
[id] {
  scroll-margin-top: 80px;
}
```

---

## 3. Forms

### Input Attributes

```tsx
// Required attributes
<input
  type="email"
  name="email"
  autoComplete="email"
  inputMode="email"
  spellCheck={false}
/>

<input
  type="tel"
  name="phone"
  autoComplete="tel"
  inputMode="tel"
/>

// Correct input types
<input type="email" />     // Shows @ keyboard on mobile
<input type="tel" />       // Shows numeric keyboard
<input type="url" />       // Shows .com keyboard
<input type="number" inputMode="numeric" />

// Disable spellcheck on codes/usernames
<input type="text" name="code" spellCheck={false} />
```

### Never Block Paste

```tsx
// BAD - Blocks password managers
<input type="password" onPaste={(e) => e.preventDefault()} />

// GOOD - Allow paste
<input type="password" />
```

### Labels and Hit Targets

```tsx
// GOOD - Clickable label with htmlFor
<label htmlFor="terms">Accept terms</label>
<input id="terms" type="checkbox" />

// GOOD - Wrapping label (no dead zones)
<label className="flex items-center gap-2 cursor-pointer">
  <input type="checkbox" />
  <span>Accept terms</span>
</label>
```

### Form Submission States

```tsx
// Submit button behavior
<button
  type="submit"
  disabled={isSubmitting}  // Only during request
  className="disabled:opacity-50"
>
  {isSubmitting ? (
    <>
      <Spinner /> Saving...
    </>
  ) : (
    'Save Changes'
  )}
</button>

// Errors inline next to fields
<input aria-invalid={!!error} aria-describedby="email-error" />
{error && <p id="email-error" className="text-destructive">{error}</p>}

// Focus first error on submit
const firstError = formRef.current?.querySelector('[aria-invalid="true"]');
firstError?.focus();
```

### Placeholders

```tsx
// GOOD - Example pattern with ellipsis
<input placeholder="e.g., john@example.com..." />
<input placeholder="Search products..." />

// Prevent password manager triggers on non-auth fields
<input type="text" autoComplete="off" />
```

### Unsaved Changes Warning

```tsx
useEffect(() => {
  if (isDirty) {
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = '';
    };
    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }
}, [isDirty]);
```

---

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

---

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

---

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

---

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

---

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

---

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

---

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

---

## 11. Dark Mode & Theming

### Required Meta Tags

```tsx
// Set color-scheme for native element styling
<html style={{ colorScheme: 'dark' }}>

// Theme color for browser chrome
<meta name="theme-color" content="#0a0a0a" />
```

### Native Selects in Dark Mode

```tsx
// Windows requires explicit colors
<select className="bg-background text-foreground">
```

---

## 12. Locale & i18n

### Use Intl APIs

```tsx
// BAD - Hardcoded formats
`${date.getMonth()}/${date.getDate()}/${date.getFullYear()}``$${price.toFixed(2)}`;

// GOOD - Locale-aware
new Intl.DateTimeFormat('en-US').format(date);
new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(
  price
);

// Detect language via Accept-Language or navigator.languages, not IP
```

---

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

---

## Anti-Patterns to Flag

| Pattern                                      | Issue                         |
| -------------------------------------------- | ----------------------------- |
| `user-scalable=no` or `maximum-scale=1`      | Disables zoom (accessibility) |
| `onPaste` with `preventDefault`              | Blocks password managers      |
| `transition: all`                            | Performance hit               |
| `outline-none` without focus replacement     | Removes focus visibility      |
| `<div onClick>` for navigation               | Breaks Cmd/Ctrl+click         |
| `<div onClick>` for actions                  | Should be `<button>`          |
| Images without dimensions                    | Layout shift                  |
| Large arrays `.map()` without virtualization | Performance                   |
| Form inputs without labels                   | Accessibility                 |
| Icon buttons without `aria-label`            | Accessibility                 |
| Hardcoded date/number formats                | i18n issues                   |
| `autoFocus` without justification            | Mobile UX                     |

---

## Content & Copy Guidelines

| Rule                            | Example                                           |
| ------------------------------- | ------------------------------------------------- |
| Active voice                    | "Install the CLI" not "The CLI will be installed" |
| Title Case for headings/buttons | "Save Changes" not "Save changes"                 |
| Numerals for counts             | "8 deployments" not "eight deployments"           |
| Specific button labels          | "Save API Key" not "Continue"                     |
| Error messages include fix      | "Invalid email. Please check the format."         |
| Second person                   | "Your settings" not "My settings"                 |
| `&` over "and" when constrained | "Terms & Conditions"                              |

---

## Supporting Documentation

| Resource                                                                   | When to Read                         |
| -------------------------------------------------------------------------- | ------------------------------------ |
| [Full Guidelines](https://github.com/vercel-labs/web-interface-guidelines) | Complete rule reference              |
| `design-system/SKILL.md`                                                   | Project-specific tokens and patterns |
| `design-system/touch-interactions.md`                                      | Mobile touch patterns                |
