# UI/UX Audit Checklist

**Purpose:** Comprehensive UI/UX quality verification for Body Compass
**Domain:** Accessibility, mobile design, touch interactions, design system compliance, PWA
**Tech Stack:** Next.js 15, React 19, Tailwind CSS, Radix UI, Mobile-first

---

## Quick Reference Commands

```bash
# Visual regression testing
pnpm test:e2e

# Check for hover states (anti-pattern for mobile)
grep -r "hover:" app/ --include="*.tsx" --include="*.css"

# Find hardcoded colors (should use semantic tokens)
grep -r "text-gray\|bg-red\|border-blue" app/ --include="*.tsx"

# Check touch target sizes
grep -r "h-\[" app/ --include="*.tsx" | grep -v "min-h-\[44"

# Find accessibility attributes
grep -r "aria-\|role=" app/ --include="*.tsx"

# Manual testing tools:
# - Chrome DevTools > Lighthouse (Accessibility score)
# - axe DevTools browser extension
# - Responsive Design Mode (375px, 390px, 428px)
```

---

## UI/UX Audit Items

### [UI-001] Verify Mobile-First Viewport Constraints

**Description:** Ensure app is designed for mobile-only (320-428px), no desktop/tablet breakpoints
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** UI-Responsive

**Verification:**

1. Search for breakpoints: `grep -r "md:\|lg:\|xl:\|2xl:" app/ --include="*.tsx"`
2. Verify only `sm:` used if needed (rare)
3. Test app at 375px, 390px, 428px (common mobile widths)
4. Check no horizontal scroll at any mobile width
5. Verify layout doesn't break at 320px (smallest common)

**Expected Output:** No desktop breakpoints, layout works 320-428px

**Deliverable:** Remove any desktop-oriented responsive styles

---

### [UI-002] Audit Touch Target Sizes

**Description:** Verify all interactive elements meet 44x44px minimum (iOS HIG)
**Severity:** CRITICAL
**Auto-fixable:** YES
**Parallel Group:** UI-Touch

**Verification:**

1. Find buttons: `grep -r "<button\|Button" app/ --include="*.tsx"`
2. Check for `h-11` or `min-h-[44px]` on buttons
3. Verify icon buttons have adequate padding: `p-3` minimum
4. Run visual inspection: `agent-browser --url "http://localhost:3000" --task "Verify all interactive elements (buttons, links, inputs) are at least 44x44px. Check icon buttons, nav items, and form controls. Report any elements below 44x44px with their actual dimensions."`
5. Check touch targets aren't too close (<8px spacing)

**Expected Output:** All interactive elements ≥44x44px

**Deliverable:** Fix undersized touch targets

---

### [UI-003] Verify No Hover States (Mobile-First)

**Description:** Ensure no `:hover` CSS since it doesn't work on mobile touch
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Touch

**Verification:**

1. Search for hover: `grep -r "hover:" app/ --include="*.tsx" --include="*.css"`
2. Check Tailwind classes: `hover:bg-`, `hover:text-`, etc.
3. Verify state-driven styling instead: `isActive ? 'bg-zone-green' : ...`
4. Test on mobile: tap element, verify visual feedback
5. Check for CSS `:hover` in style files

**Expected Output:** Zero hover states, all feedback via active/state

**Deliverable:** Replace hover states with state-driven styling

---

### [UI-004] Audit Touch Feedback Animations

**Description:** Verify all interactive elements provide tactile feedback via spring animations
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Touch

**Verification:**

1. Find buttons: `grep -r "<button\|Button" app/ --include="*.tsx"`
2. Check for spring utilities: `spring-press-shrink`, `spring-press-expand`, `spring-press-subtle`
3. Verify small elements expand, large elements shrink
4. Test: tap button, verify smooth spring animation
5. Check animation duration reasonable (150-200ms)

**Expected Output:** All interactive elements have spring feedback

**Deliverable:** Add spring animations where missing

---

### [UI-005] Verify Active State Styling

**Description:** Ensure `:active` pseudo-class provides instant tap feedback
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Touch

**Verification:**

1. Find interactive elements without spring utilities
2. Check for `active:` Tailwind classes
3. Verify instant visual feedback on tap (no delay)
4. Test: tap and hold, verify feedback appears immediately
5. Check active state is visible (not too subtle)

**Expected Output:** Active states provide instant tap feedback

**Deliverable:** Add active states where missing

---

### [UI-006] Audit Semantic Color Token Usage

**Description:** Verify using semantic tokens, not hardcoded Tailwind colors
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Design-System

**Verification:**

1. Search for hardcoded colors: `grep -r "text-gray-\|bg-red-\|border-blue-" app/ --include="*.tsx"`
2. Verify using semantic tokens: `text-muted-foreground`, `bg-destructive`, etc.
3. Check zone colors used correctly: `bg-zone-green`, `text-zone-yellow`
4. Review design tokens: `.claude/skills/design-system/reference/design-tokens.md`
5. Test: verify colors update if theme changes

**Expected Output:** No hardcoded colors, all semantic tokens

**Deliverable:** Replace hardcoded colors with semantic tokens

---

### [UI-007] Verify Zone Color Consistency

**Description:** Ensure zone colors (green/yellow/red) used consistently for food classification
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** UI-Design-System

**Verification:**

1. Find zone color usage: `grep -r "zone-green\|zone-yellow\|zone-red" app/ --include="*.tsx"`
2. Verify only used for food-related UI (not general-purpose)
3. Check consistency: green = nutritious, yellow = context-dependent, red = inflammatory
4. Test: add food in each zone, verify color matches classification
5. Verify color contrast meets WCAG AA (4.5:1)

**Expected Output:** Zone colors used consistently and appropriately

**Deliverable:** Audit report of zone color usage

---

### [UI-008] Audit Spacing Scale Compliance

**Description:** Verify using Tailwind spacing scale, not arbitrary values
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** UI-Design-System

**Verification:**

1. Search for arbitrary values: `grep -r "\[.*px\]\|\[.*rem\]" app/ --include="*.tsx"`
2. Check if values can use spacing scale: `p-3`, `mb-4`, etc.
3. Allow exceptions: `min-h-[44px]` for touch targets
4. Verify consistent spacing (not `mb-[13px]`)
5. Check design system defines standard spacing

**Expected Output:** Minimal arbitrary values, prefer spacing scale

**Deliverable:** Replace arbitrary spacing with scale values

---

### [UI-009] Verify Accessibility Attributes on Interactive Elements

**Description:** Ensure buttons, links, inputs have proper ARIA attributes
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Find interactive elements: `grep -r "<button\|<input\|<a" app/ --include="*.tsx"`
2. Check icon buttons have `aria-label`
3. Verify form inputs have labels (visible or `aria-label`)
4. Check buttons have descriptive text or aria-label
5. Test with screen reader (VoiceOver on iOS)

**Expected Output:** All interactive elements properly labeled

**Deliverable:** Add missing ARIA labels

---

### [UI-010] Audit Focus Indicators

**Description:** Verify visible focus indicators for keyboard navigation
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Find focusable elements: buttons, links, inputs
2. Check for `focus:` styles (ring, outline, etc.)
3. Verify focus indicator visible (not `focus:outline-none` without replacement)
4. Run visual focus audit: `agent-browser --url "http://localhost:3000" --task "Tab through all interactive elements on each page. Verify every button, link, and input shows a visible focus indicator. Check that focus indicators have at least 3:1 contrast ratio. Report any elements without visible focus or with insufficient contrast."`
5. Test manually: tab through UI, verify focus always visible

**Expected Output:** All focusable elements have visible focus indicators

**Deliverable:** Add focus styles where missing

---

### [UI-011] Verify Image Alt Text

**Description:** Ensure all images have descriptive alt attributes
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Find images: `grep -r "<Image\|<img" app/ --include="*.tsx"`
2. Check for `alt` prop on every image
3. Verify alt text is descriptive (not "image" or filename)
4. Check decorative images use `alt=""` (not omitted)
5. Test with screen reader: verify alt text reads well

**Expected Output:** All images have descriptive alt text

**Deliverable:** Add/improve alt text on images

---

### [UI-012] Audit Color Contrast Ratios

**Description:** Verify text meets WCAG AA contrast ratios (4.5:1 for normal, 3:1 for large)
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Use Chrome DevTools > Lighthouse > Accessibility
2. Run visual contrast audit: `agent-browser --url "http://localhost:3000" --task "Check all text for WCAG AA contrast compliance. Verify: text-muted-foreground on bg-background (4.5:1 minimum), zone colors on white background (4.5:1), small text <18pt (4.5:1), large text ≥18pt (3:1). Report all contrast violations with actual ratios."`
3. Check disabled states still readable (if needed)
4. Verify zone colors meet requirements across all uses

**Expected Output:** All text meets WCAG AA contrast requirements

**Deliverable:** Adjust colors to meet contrast ratios

---

### [UI-013] Verify Semantic HTML Usage

**Description:** Ensure proper HTML5 semantic elements (not all divs)
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Check for semantic tags: `<nav>`, `<main>`, `<article>`, `<section>`, `<header>`, `<footer>`
2. Verify buttons use `<button>` (not `<div onClick>`)
3. Check links use `<a>` or Next.js `<Link>`
4. Verify headings follow hierarchy (h1 → h2 → h3)
5. Test with screen reader: verify semantic structure

**Expected Output:** Proper semantic HTML throughout

**Deliverable:** Replace divs with semantic elements where appropriate

---

### [UI-014] Audit Form Input Labels

**Description:** Ensure all form inputs have associated labels
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Find inputs: `grep -r "<input\|<Input" app/ --include="*.tsx"`
2. Verify each has `<label>` with `htmlFor` matching input `id`
3. Check placeholder text not used as only label
4. Verify labels visible (not display:none)
5. Test with screen reader: verify label announces correctly

**Expected Output:** All inputs have visible, associated labels

**Deliverable:** Add labels to unlabeled inputs

---

### [UI-015] Verify Loading States

**Description:** Ensure async operations show loading indicators
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Feedback

**Verification:**

1. Find async operations: `grep -r "isLoading\|isPending" app/ --include="*.tsx"`
2. Verify loading state shown during data fetching
3. Check buttons disabled during submission
4. Test: throttle network, verify loading indicators appear
5. Verify loading states accessible (aria-busy)

**Expected Output:** All async operations have loading states

**Deliverable:** Add loading indicators where missing

---

### [UI-016] Audit Error State Handling

**Description:** Verify error messages are clear, visible, and accessible
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Feedback

**Verification:**

1. Find error handling: `grep -r "error\|Error" app/ --include="*.tsx"`
2. Check error messages displayed to user
3. Verify errors styled prominently (red, icon, etc.)
4. Test: trigger errors, verify clear messaging
5. Check errors have `role="alert"` for screen readers

**Expected Output:** Clear, accessible error messages

**Deliverable:** Improve error state presentation

---

### [UI-017] Verify Success Feedback

**Description:** Ensure successful actions provide clear confirmation
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Feedback

**Verification:**

1. Find success actions: form submissions, deletions, etc.
2. Check for toast notifications or success messages
3. Verify success feedback visible (not just console.log)
4. Test: complete action, verify confirmation appears
5. Check success messages auto-dismiss after reasonable time

**Expected Output:** All successful actions provide feedback

**Deliverable:** Add success feedback where missing

---

### [UI-018] Audit Progressive Web App (PWA) Manifest

**Description:** Verify PWA manifest configured correctly for mobile install
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-PWA

**Verification:**

1. Check manifest.json in public/
2. Verify required fields: name, short_name, icons, start_url, display
3. Check icons include 192x192 and 512x512
4. Verify theme_color matches app branding
5. Test: "Add to Home Screen" on iOS/Android

**Expected Output:** PWA manifest complete and valid

**Deliverable:** Fix manifest issues

---

### [UI-019] Verify Offline Page UI

**Description:** Ensure offline fallback page is user-friendly
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-PWA

**Verification:**

1. Read `app/offline/page.tsx`
2. Check for clear messaging: "You're offline"
3. Verify suggestions: check connection, retry
4. Test: go offline, navigate to new page
5. Check offline page matches app branding

**Expected Output:** Offline page clear and helpful

**Deliverable:** Improve offline page UX

---

### [UI-020] Audit Navigation Bar Usability

**Description:** Verify bottom navigation is accessible and functional
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Navigation

**Verification:**

1. Check navigation component location and structure
2. Verify active state clearly indicates current page
3. Check icons have text labels or aria-labels
4. Test: tap each nav item, verify navigation works
5. Verify nav bar fixed to bottom (doesn't scroll away)

**Expected Output:** Navigation clear, accessible, and functional

**Deliverable:** Fix navigation issues

---

### [UI-021] Verify Drawer/Modal Focus Trapping

**Description:** Ensure drawers and modals trap focus for accessibility
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Find modals/drawers: `grep -r "Dialog\|Drawer\|Modal" app/ --include="*.tsx"`
2. Check using Radix UI primitives (built-in focus trap)
3. Test: open modal, tab through, verify focus cycles
4. Check Escape key closes modal
5. Verify focus returns to trigger element on close

**Expected Output:** Modals trap focus, proper keyboard navigation

**Deliverable:** Fix focus management in modals

---

### [UI-022] Audit Form Validation Feedback

**Description:** Verify form validation errors are clear and accessible
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Forms

**Verification:**

1. Find forms: `grep -r "useForm\|handleSubmit" app/ --include="*.tsx"`
2. Check for inline validation errors
3. Verify errors appear near invalid field
4. Test: submit invalid form, verify error messages
5. Check errors have `role="alert"` for screen readers

**Expected Output:** Validation errors clear and accessible

**Deliverable:** Improve form validation feedback

---

### [UI-023] Verify Input Autocomplete Attributes

**Description:** Ensure form inputs have appropriate autocomplete attributes
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Forms

**Verification:**

1. Find inputs: `grep -r '<input\|<Input' app/ --include="*.tsx"`
2. Check for `autocomplete` prop on relevant fields
3. Verify values: "email", "name", "tel", etc.
4. Test: start typing in field, verify browser autocomplete works
5. Check sensitive fields have `autocomplete="off"` if needed

**Expected Output:** Autocomplete attributes improve UX

**Deliverable:** Add autocomplete attributes to forms

---

### [UI-024] Audit Transition Smoothness

**Description:** Verify all transitions use appropriate duration and easing
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** UI-Animations

**Verification:**

1. Find transitions: `grep -r "transition-" app/ --include="*.tsx"`
2. Check durations reasonable (150-300ms)
3. Verify easing appropriate (ease-in-out for most)
4. Test: interact with UI, verify no janky transitions
5. Check spring animations use cubic-bezier

**Expected Output:** Smooth, natural-feeling transitions

**Deliverable:** Fix janky or missing transitions

---

### [UI-025] Verify No Layout Shift (CLS)

**Description:** Ensure page loads without unexpected layout shifts
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Performance

**Verification:**

1. Run Lighthouse in Chrome DevTools
2. Check Cumulative Layout Shift (CLS) score (should be < 0.1)
3. Identify elements causing shift (images, fonts, dynamic content)
4. Verify images have explicit width/height
5. Check fonts use font-display: swap or optional

**Expected Output:** CLS < 0.1 on all pages

**Deliverable:** Fix layout shift issues

---

### [UI-026] Audit Text Legibility

**Description:** Verify text is readable (size, line-height, contrast)
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Typography

**Verification:**

1. Check base font size: should be ≥16px (1rem)
2. Verify line-height: 1.5 for body text minimum
3. Check text isn't too long (max 75ch width)
4. Test on actual mobile device (not just DevTools)
5. Verify headings have clear hierarchy

**Expected Output:** Text comfortable to read on mobile

**Deliverable:** Adjust typography for better legibility

---

### [UI-027] Verify Icon Button Clarity

**Description:** Ensure icon-only buttons have clear purpose
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Iconography

**Verification:**

1. Find icon buttons: `grep -r "<button.*><.*Icon" app/ --include="*.tsx"`
2. Check for aria-label on each
3. Verify icons intuitive (edit, delete, add, etc.)
4. Test: show to user, verify they understand purpose
5. Consider adding text labels for critical actions

**Expected Output:** Icon buttons have clear purpose and labels

**Deliverable:** Add aria-labels or text to unclear icon buttons

---

### [UI-028] Audit Empty States

**Description:** Verify empty states provide guidance and action
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Content

**Verification:**

1. Find empty state handling: `grep -r "length === 0\|isEmpty" app/ --include="*.tsx"`
2. Check for helpful messaging (not just "No data")
3. Verify call-to-action (e.g., "Add your first food")
4. Test: view page with no data, verify good UX
5. Check empty state is visually distinct

**Expected Output:** Empty states helpful and actionable

**Deliverable:** Improve empty state UX

---

### [UI-029] Verify Swipe Gesture Support

**Description:** Ensure mobile-appropriate swipe gestures where applicable
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** UI-Touch

**Verification:**

1. Identify swipeable elements: list items, cards, drawers
2. Check for swipe gesture implementation
3. Verify swipe direction intuitive (left to delete, etc.)
4. Test: swipe elements, verify smooth interaction
5. Check visual feedback during swipe

**Expected Output:** Swipe gestures implemented where appropriate

**Deliverable:** Add swipe gestures to enhance mobile UX

---

### [UI-030] WCAG 2.2 Focus Not Obscured

**Description:** Verify focus states visible and not covered by sticky headers/footers (WCAG 2.2, EAA enforceable June 2025)
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Run focus visibility audit: `agent-browser --url "http://localhost:3000" --task "Tab through all interactive elements on each page. Verify that no focus states are obscured by sticky headers, footers, or bottom navigation. Check that modal/drawer overlays don't hide focus rings. Report any elements where focus is partially or fully obscured."`
2. Check for sticky headers/footers obscuring focus
3. Verify bottom navigation doesn't cover focused elements
4. Test with keyboard only: ensure all focus states visible
5. Check modals/drawers don't obscure focus rings

**Expected Output:** Focus states never obscured by UI elements

**Deliverable:** Fix obscured focus states

---

### [UI-031] WCAG 2.2 Target Size Minimum

**Description:** Verify touch targets meet WCAG 2.2 minimum (24x24px) and recommended sizes
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Touch
**Blocked By:** [UI-002]

**Verification:**

1. Verify all touch targets >= 24x24px (WCAG 2.2 minimum)
2. Check >= 44x44px (iOS HIG recommended)
3. Verify >= 48x48dp (Material Design recommended)
4. Check >= 8px spacing between adjacent targets
5. Run visual compliance check: `agent-browser --url "http://localhost:3000" --task "Audit all touch targets for WCAG 2.2 compliance. Verify minimum 24x24px (required), recommended 44x44px (iOS HIG), and 48x48dp (Material Design). Check spacing between adjacent targets is at least 8px. Generate compliance report."`

**Expected Output:** All targets meet WCAG 2.2 minimum, most meet recommended 44x44px

**Deliverable:** Touch target size compliance report

---

### [UI-032] WCAG 2.2 Accessible Authentication

**Description:** Verify authentication doesn't require cognitive tests (WCAG 2.2)
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Check no CAPTCHAs in authentication flow
2. Verify password managers allowed (autocomplete enabled)
3. Check copy-paste not disabled on auth fields
4. Verify biometric alternatives available (if platform supports)
5. Test: use password manager, verify works

**Expected Output:** Authentication accessible, no cognitive tests

**Deliverable:** Accessible authentication verification

---

### [UI-033] Screen Reader Testing Protocol

**Description:** Comprehensive screen reader testing on mobile platforms
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** UI-Accessibility

**Verification:**

1. Test with VoiceOver (iOS/macOS): swipe through all screens
2. Test with TalkBack (Android): verify all elements announced
3. Check semantic HTML verification (headings, landmarks)
4. Verify ARIA labels where native semantics insufficient
5. Test form error announcements (role="alert")

**Expected Output:** All content accessible via screen reader

**Deliverable:** Screen reader testing report with issues

---

### [UI-034] Automated Accessibility Testing

**Description:** Run automated a11y tools and meet score thresholds
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Run axe DevTools scan on all major pages
2. Check Lighthouse accessibility score: >= 90 target
3. Run pa11y CI integration: `pa11y-ci`
4. Verify color contrast (4.5:1 text, 3:1 UI)
5. Fix all critical/serious axe violations

**Expected Output:** Lighthouse >= 90, zero critical axe violations

**Deliverable:** Automated a11y test results with fixes

---

### [UI-035] PWA iOS Storage Awareness

**Description:** Verify PWA handles iOS Safari storage limits (50MB cache, 7-day eviction)
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-PWA
**Blocked By:** [UI-018]

**Verification:**

1. Check cache size stays under 50MB (iOS Safari limit)
2. Verify 7-day storage eviction cap handled gracefully
3. Test service worker lifecycle on iOS Safari
4. Verify offline fallback page always available
5. Test: use app offline on iOS, verify functionality

**Expected Output:** PWA works within iOS limitations, graceful degradation

**Deliverable:** iOS PWA storage compliance report

---

### [UI-036] Keyboard Navigation Audit

**Description:** Comprehensive keyboard-only navigation testing
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Verify tab order logical on all pages
2. Check focus indicators visible (3:1 contrast)
3. Verify skip links to main content exist
4. Test modal focus trapping (tab cycles within)
5. Check Escape key dismisses overlays/modals

**Expected Output:** Full keyboard navigation support

**Deliverable:** Keyboard navigation compliance report

---

### [UI-037] Audit Health Data Visualization Accessibility

**Description:** Verify charts and data visualizations are accessible to all users
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Check all charts have data table alternative: `grep -r "recharts\|chart" app/ --include="*.tsx"`
2. Add text summaries explaining key trends (not just visual data)
3. Verify chart elements meet 3:1 contrast with neighbors
4. Ensure keyboard navigation for interactive charts
5. Include pattern differentiation (stripes, dots) not just color for zones
6. Verify screen reader can access all data points via ARIA
7. Test with zone colors: users should understand meaning without seeing color

**Expected Output:** All visualizations have text alternatives, patterns, and keyboard access

**Deliverable:** Chart accessibility audit with fixes applied

**Reference:** Health data visualization improves literacy by 35% among visually impaired users when accessible

---

### [UI-038] Implement prefers-reduced-motion Support

**Description:** Respect user preference for reduced motion (critical for vestibular disorders)
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility

**Verification:**

1. Search CSS: `grep -r "prefers-reduced-motion" app/ --include="*.css" --include="*.tsx"`
2. Add media query: `@media (prefers-reduced-motion: reduce)`
3. Verify spring animations fallback to fades/opacity changes
4. Test: enable "Reduce motion" in system settings, verify no animations
5. Ensure no essential information conveyed only via animation
6. Check Tailwind config includes motion-safe/motion-reduce utilities

**Expected Output:** All animations respect reduced motion preference

**Deliverable:** Motion-safe CSS with fallbacks for reduced motion users

**Example CSS:**

```css
@media (prefers-reduced-motion: reduce) {
  .spring-press-shrink,
  .spring-press-expand {
    transform: none !important;
    transition: opacity 150ms ease;
  }
}
```

**Reference:** Vestibular disorders affect 35% of adults over 40; motion can trigger nausea, migraines

---

### [UI-039] Offline Sync State Feedback

**Description:** Provide clear feedback during offline/sync operations
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-PWA
**Blocked By:** [UI-019]

**Verification:**

1. Check for sync state indicators: `grep -r "sync\|offline\|online" app/ --include="*.tsx"`
2. Verify user knows when data is queued vs synced
3. Add visual indicator for pending sync items (badge, icon)
4. Show confirmation when sync completes after reconnection
5. Handle sync conflicts gracefully with user feedback
6. Test: add food offline, go online, verify sync feedback shown

**Expected Output:** Users always know sync state of their data

**Deliverable:** Sync state UI components and feedback patterns

---

### [UI-040] WCAG 2.2 Reflow Verification (320px)

**Description:** Explicitly verify content reflows at 320px viewport (WCAG 2.2 requirement)
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** UI-Responsive
**Blocked By:** [UI-001]

**Verification:**

1. Test at exactly 320px viewport width (Chrome DevTools)
2. Verify no horizontal scrolling required
3. Check all content readable without zooming
4. Verify touch targets still meet 44px minimum at 320px
5. Test critical flows: login, food entry, dashboard
6. Check no content cut off or overlapping

**Expected Output:** Full app functionality at 320px width

**Deliverable:** 320px reflow compliance report

**Reference:** 320px CSS pixels = 400% zoom at 1280px width (WCAG criterion)

---

### [UI-041] Skip Links Implementation Audit

**Description:** Verify skip links exist and function for keyboard navigation
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** UI-Accessibility
**Blocked By:** [UI-036]

**Verification:**

1. Check for skip link: `grep -r "skip.*main\|skip.*content" app/ --include="*.tsx"`
2. Verify skip link is first focusable element on page
3. Check skip link visible when focused (CSS :focus-visible)
4. Test: Tab once, verify skip link appears, Enter skips to main
5. Verify skip link target has `id="main-content"` or similar
6. Check skip link text is descriptive: "Skip to main content"

**Expected Output:** Skip links present and functional on all pages

**Deliverable:** Skip link implementation or verification

**Example Implementation:**

```tsx
<a
  href="#main-content"
  className="sr-only focus:not-sr-only focus:absolute focus:top-2 focus:left-2 focus:z-50 focus:p-2 focus:bg-background"
>
  Skip to main content
</a>
```

---

## Summary Template

After completing audit items, generate this summary:

```markdown
## UI/UX Audit Summary

**Date:** YYYY-MM-DD
**Auditor:** [Name/Tool]
**Scope:** Body Compass App - Full Application

### Accessibility Metrics

| Category                 | Score  | Status   |
| ------------------------ | ------ | -------- |
| Lighthouse Accessibility | XX/100 | ✅/⚠️/❌ |
| axe DevTools Issues      | X      | ✅/⚠️/❌ |
| WCAG 2.1 Level           | AA/AAA | ✅/⚠️/❌ |

### Mobile Design Compliance

| Metric                    | Status   | Notes                |
| ------------------------- | -------- | -------------------- |
| No hover states           | ✅/⚠️/❌ | Found X violations   |
| Touch targets ≥44px       | ✅/⚠️/❌ | X undersized targets |
| Semantic color tokens     | ✅/⚠️/❌ | X hardcoded colors   |
| Mobile-first (no desktop) | ✅/⚠️/❌ | Found X breakpoints  |

### Findings by Severity

| Severity | Count | Auto-fixable |
| -------- | ----- | ------------ |
| CRITICAL | X     | Y            |
| HIGH     | X     | Y            |
| MEDIUM   | X     | Y            |
| LOW      | X     | Y            |
| INFO     | X     | Y            |

### Recommendations

**Immediate (Critical/High):**

1. [Finding 1] - [Impact on users]
2. [Finding 2] - [Impact on users]

**Short-term (Medium):**

1. [Finding 1]
2. [Finding 2]

**Long-term (Low/Info):**

1. [Finding 1]
```
