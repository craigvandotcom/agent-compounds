# Forms

Objective form-implementation patterns. Read when auditing form code, inputs, validation, or submission UX.

## Input Attributes

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

## Never Block Paste

```tsx
// BAD - Blocks password managers
<input type="password" onPaste={(e) => e.preventDefault()} />

// GOOD - Allow paste
<input type="password" />
```

## Labels and Hit Targets

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

## Form Submission States

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

## Placeholders

```tsx
// GOOD - Example pattern with ellipsis
<input placeholder="e.g., john@example.com..." />
<input placeholder="Search products..." />

// Prevent password manager triggers on non-auth fields
<input type="text" autoComplete="off" />
```

## Unsaved Changes Warning

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
