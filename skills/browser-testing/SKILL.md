---
name: browser-testing
description: Use when testing UI, validating browser behavior, checking login flows, or verifying deployments. Triggers on "test UI", "validate browser", "check login", "test flow", "preview validation", environment testing (local/preview/production). Handles browser automation via agent-browser CLI for manual testing requests, smoke tests, and auth flow verification.
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across all neoMeta apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Browser Testing Skill

Validate UI functionality using the `agent-browser` CLI. Supports local dev, Vercel preview, and production environments with environment-aware authentication.

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

Load `environments.md` for the environment template; fill in the consuming app's actual URLs and credentials (from its `.env.local` or CORE):

| Environment  | When                                          |
| ------------ | --------------------------------------------- |
| `local`      | Dev server (typically `localhost:3000`)       |
| `preview`    | Vercel preview deployments                    |
| `production` | Live site (the app's production URL)          |

## Mobile Viewport

For mobile-first PWA apps targeting 320px–428px viewports (portrait-primary), **always set mobile viewport before testing** unless explicitly testing desktop.

```bash
# Set immediately after opening URL
agent-browser --session test set viewport 390 844
```

| Viewport    | Dimensions   | Device            |
| ----------- | ------------ | ----------------- |
| **Default** | `390 x 844`  | iPhone 15 Pro     |
| Small       | `320 x 568`  | iPhone SE (1st)   |
| Large       | `428 x 926`  | iPhone 14 Pro Max |
| Desktop     | `1280 x 800` | Only if requested |

Whether mobile viewport is mandatory depends on the app — check the consuming app's CORE for its viewport policy.

## Standard Workflow

```bash
# 1. Start session (add viewport line for mobile-first apps)
agent-browser --session test open "[BASE_URL]/login"
agent-browser --session test set viewport 390 844        # mobile-first apps
agent-browser --session test wait --load networkidle

# 2. Authenticate
#    Credentials and login flow → see the app's CORE or environments.md
agent-browser --session test fill @[email-ref] "[EMAIL]"
agent-browser --session test fill @[password-ref] "[PASSWORD]"
agent-browser --session test click @[submit-ref]
agent-browser --session test wait --url "/[post-login-path]"

# 3. Validate
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

## App-Specific Journeys

App-specific journeys (what routes to test, what features to exercise, entry flows, etc.) live in the consuming app's own CORE:

```
<app-root>/.claude/skills/CORE/journeys/
├── *.md                 # journey definitions (the "what")
├── flows/*.md           # app-specific flow recipes (login, dashboard, ...)
├── environments.md      # the app's real URLs, credentials, routes
└── README.md            # journey index + viewport policy
```

This skill provides the **how** (CLI mechanics, assertions, patterns, the `environments.md` template, `flows/common.md`). The app's CORE provides the **what** (which journeys exist, which routes are protected, what the login button is labelled, the real URLs/credentials, and whether mobile viewport is mandatory).

## Related Files

### Configuration

- `environments.md` — environment template (URLs and credential patterns per environment)

### Flows (Reusable Patterns)

- `flows/common.md` — reusable assertions, wait patterns, session management, error recovery

### Related Skills

- `.claude/skills/testing/SKILL.md` — automated testing (Vitest, Playwright)
- `.claude/skills/CORE/testing.md` — testing quick reference

## Accessibility Validation

### Keyboard Navigation Testing

```bash
# Tab through all interactive elements
agent-browser --session a11y snapshot -i
# Note element order — verify logical tab sequence

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

**"Resource temporarily unavailable"** — Transient error, retry the command

**Page stuck on "Loading..."** — Wait longer, use `--timeout` flag

**Element not found** — Run `snapshot -i` to see current element refs

**Auth fails** — Verify credentials match environment (local vs preview/prod may use different auth backends — check the app's `environments.md`)
