# Accessibility & Focus

Objective compliance patterns. Read when auditing a11y, ARIA, keyboard, semantics, or focus states.

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
