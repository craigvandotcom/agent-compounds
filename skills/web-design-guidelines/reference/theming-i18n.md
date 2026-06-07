# Dark Mode, Theming & i18n

Objective patterns. Read when auditing dark mode, color-scheme, native control styling, or locale-aware formatting.

> Token *system* design (semantic naming, brand pillar) → `brand-system` + the app's local `design-system`.

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
