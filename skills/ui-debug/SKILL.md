---
name: ui-debug
description: Debug UI bugs, CSS styling issues, and unexpected visual behavior. Use when elements render wrong, styles don't apply, or mobile/desktop differences occur.
---

# UI Debug Skill

**Purpose:** Debug UI bugs and CSS styling issues in React/Next.js applications
**Domain:** Frontend debugging, CSS troubleshooting
**Status:** Complete

---

## First Steps (Always Do These)

1. **Inspect element** - Check computed styles in dev tools, not just defined styles
2. **Search for known issues** - `[component] [symptom] issue github`
3. **Check global CSS** - Look for rules affecting the element type (`button`, `input`, etc.)
4. **Check parent containers** - Flex/grid constraints, overflow, min/max dimensions

## CSS Debugging Checklist

- [ ] Inspect **computed styles** (what's actually applied)
- [ ] Check for `!important` overrides
- [ ] Check media queries affecting mobile/desktop differently
- [ ] Look for global element selectors in `globals.css`
- [ ] Check CSS specificity conflicts
- [ ] Verify CSS variables are defined and correct values

## Common Culprits

| Symptom                             | Check First                                      |
| ----------------------------------- | ------------------------------------------------ |
| Element wrong size                  | Global min/max constraints, flex shrink/grow     |
| Styles not applying                 | Specificity, cascade order, typos in class names |
| Works on desktop, broken on mobile  | Media queries, touch target rules                |
| Component looks different than docs | External CSS overriding component styles         |
| Color not showing                   | CSS variable undefined, wrong color format       |
| Animation not working               | `transform: none !important` overrides           |

## Debugging Commands

```bash
# Search for global CSS rules affecting an element type
grep -n "^button\|^  button" app/globals.css

# Find all files using a component
grep -r "Switch\|role='switch'" --include="*.tsx"

# Check for media queries
grep -n "@media" app/globals.css
```

## Browser Dev Tools Tips

1. **Computed tab** shows final applied values (not just what's defined)
2. **Styles panel** shows which rules are crossed out (overridden)
3. **Filter styles** by property name to find conflicts
4. **Force element state** (:hover, :active, :focus) to debug state-specific issues

---

## Lessons Learned

### 2026-01-21: Switch toggle appearing circular instead of pill-shaped

**Symptom:** shadcn Switch component rendered as a circle on mobile instead of horizontal pill shape.

**Investigation steps taken (inefficient):**

1. Adjusted Switch component dimensions repeatedly
2. Tried different width/height ratios
3. Compared with shadcn website screenshots
4. Eventually searched for known issues

**Root cause:** Global CSS in `globals.css`:

```css
@media (max-width: 768px) {
  button {
    min-height: 44px;
    min-width: 44px;
  }
}
```

This forced the Switch (a `<button role="switch">`) to be at least 44×44px.

**Fix:** Exclude switches from the rule:

```css
button:not([role='switch']) { ... }
```

**Lesson:** Always inspect computed styles first. Would have immediately shown `min-height: 44px` being applied from an external rule.

---

## When to Use This Skill

- UI element not rendering as expected
- Styles working in one context but not another
- Component looks different from documentation/examples
- Mobile vs desktop rendering differences
