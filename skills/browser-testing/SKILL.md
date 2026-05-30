---
name: browser-testing
description: Use when testing UI, validating browser behavior, checking login flows, testing dashboard interactions, or verifying deployments. Triggers on "test UI", "validate browser", "check login", "test dashboard", "preview validation", environment testing (local/preview/production). Handles browser automation via agent-browser CLI for manual testing requests, smoke tests, and auth flow verification.
---

# Browser Testing Skill

Validate UI functionality using agent-browser CLI. Supports local dev, Vercel preview, and production environments with environment-aware authentication.

## When to Use

- `/work-review` preview validation phase
- Manual UI testing requests
- Smoke tests after deployments
- Auth flow verification

## When NOT to Use

- Unit or integration testing → use `.claude/skills/testing/SKILL.md`
- Automated CI E2E tests → use `.claude/skills/testing/workflows/e2e-test.md` (Playwright)
- API-only testing without browser interaction
- Performance or load testing
- Security vulnerability scanning

## Quick Reference

### Start a Session

```bash
agent-browser --session [name] open "[URL]"
agent-browser --session [name] wait --load networkidle
```

### Core Commands

| Command                   | Usage                        |
| ------------------------- | ---------------------------- |
| `open [url]`              | Navigate to URL              |
| `snapshot -i`             | Get interactive element tree |
| `click @ref`              | Click element by ref         |
| `fill @ref "value"`       | Fill input field             |
| `wait --load networkidle` | Wait for network idle        |
| `wait --url "/path"`      | Wait for URL change          |
| `wait --timeout N`        | Wait N milliseconds          |
| `console`                 | Get console logs             |
| `errors`                  | Get console errors           |
| `screenshot [path]`       | Capture screenshot           |
| `close`                   | End session                  |

### Environment Selection

Load `environments.md` for credentials and URLs:

| Environment  | When                          |
| ------------ | ----------------------------- |
| `local`      | Dev server (`localhost:3000`) |
| `preview`    | Vercel preview deployments    |
| `production` | Live site (`bodycompass.app`) |

## Mobile Viewport (CRITICAL)

This is a **mobile-first PWA** targeting 320px-428px viewports (portrait-primary). **Always set mobile viewport before testing** unless explicitly testing desktop.

```bash
# MUST be first command after opening URL
agent-browser --session test set viewport 390 844
```

| Viewport    | Dimensions   | Device            |
| ----------- | ------------ | ----------------- |
| **Default** | `390 x 844`  | iPhone 15 Pro     |
| Small       | `320 x 568`  | iPhone SE (1st)   |
| Large       | `428 x 926`  | iPhone 14 Pro Max |
| Desktop     | `1280 x 800` | Only if requested |

## Standard Workflow

```bash
# 1. Start session with mobile viewport
agent-browser --session test open "[BASE_URL]/login"
agent-browser --session test set viewport 390 844
agent-browser --session test wait --load networkidle

# 2. Authenticate (see flows/login.md)
agent-browser --session test fill @email "[EMAIL]"
agent-browser --session test fill @password "[PASSWORD]"
agent-browser --session test click @submit
agent-browser --session test wait --url "/app"

# 3. Validate (see flows/dashboard.md or flows/common.md)
agent-browser --session test snapshot -i
agent-browser --session test errors

# 4. Cleanup
agent-browser --session test close
```

## Validation Outputs

Always report:

```markdown
BROWSER_VALIDATION:
environment: local | preview | production
viewport: [width x height]
session: [session-name]
auth_status: PASS | FAIL | SKIPPED
routes_tested: [list]
console_errors: none | [list critical errors]
status: PASS | FAIL
notes: [any issues]
```

## QA Story Workflow

For structured, repeatable QA validation use YAML story files with the `browser-qa-agent`:

- **Story files:** `browser-stories/*.yaml` (project root)
- **Format reference:** `browser-stories/_format.md`
- **Run all stories:** `/browser:ui-review`
- **Run filtered stories:** `/browser:ui-review smoke`
- **Ad-hoc automation:** `/browser:automate <description>`

Stories output a PASS/FAIL table per step with screenshots. Use this for deployment validation and regression checks.

## Related Files

### Configuration

- `environments.md` - URLs and credentials per environment

### Flows (How to Test)

- `flows/login.md` - Authentication patterns
- `flows/dashboard.md` - Dashboard validation
- `flows/common.md` - Reusable assertions and report template

### User Journeys (What to Test)

- `journeys/README.md` - Journey index and mapping
- `journeys/auth.md` - Login/logout flows
- `journeys/food-entry.md` - Add/edit/delete food
- `journeys/signal-entry.md` - Add/edit/delete signals
- `journeys/dashboard.md` - View insights and entries
- `journeys/settings.md` - User preferences

### Related Skills

- `.claude/skills/testing/SKILL.md` - Automated testing (Vitest, Playwright)
- `.claude/skills/CORE/testing.md` - Testing quick reference

## Accessibility Validation

### Keyboard Navigation Testing

```bash
# Tab through all interactive elements
agent-browser --session a11y snapshot -i
# Note element order - verify logical tab sequence

# Test keyboard activation
agent-browser --session a11y keyboard Tab
agent-browser --session a11y keyboard Enter
```

### Focus State Verification

```bash
# Check that focused elements are visible
agent-browser --session a11y snapshot -i
# Look for focused element indicators in snapshot

# Test focus trap in modals
agent-browser --session a11y click @[open-modal]
agent-browser --session a11y keyboard Tab
agent-browser --session a11y keyboard Tab
# Focus should cycle within modal
```

### Screen Reader Text

```bash
# Snapshot includes aria-labels and roles
agent-browser --session a11y snapshot -i

# Verify:
# - Buttons have descriptive names
# - Images have alt text
# - Form inputs have labels
# - Headings are properly nested
```

### Accessibility Checklist

```markdown
A11Y_VALIDATION:
keyboard_navigation: PASS | FAIL
focus_visible: PASS | FAIL
focus_trap_modals: PASS | FAIL
aria_labels: PASS | FAIL
color_contrast: PASS | FAIL (manual check)
touch_targets: PASS | FAIL (min 44x44px)
```

---

## Troubleshooting

**"Resource temporarily unavailable"** - Transient error, retry the command

**Page stuck on "Loading..."** - Wait longer, use `--timeout` flag

**Element not found** - Run `snapshot -i` to see current element refs

**Auth fails** - Verify credentials match environment (local=dev Supabase, preview/prod=prod Supabase)
