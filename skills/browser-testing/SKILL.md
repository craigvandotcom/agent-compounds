---
name: browser-testing
description: Use for ad-hoc (not pipeline-gated) browser checks — post-deploy smoke tests, login/auth flows, validating browser behavior via the agent-browser CLI. Triggers on "test UI", "validate browser", "check login", "test flow", "preview validation", environment testing (local/preview/production). NOT for structured full-app QA with depth levels, QA_VALIDATION reporting, or ac-merge gating (use ac-qa-browser).
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Browser Testing Skill

Validate UI functionality using the `agent-browser` CLI. Supports local dev, Vercel preview, and production environments with environment-aware authentication.

## When to Use

- `/ac-review` preview validation phase
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
| `close`                   | End session (MANDATORY — see Teardown) |

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

# 4. Cleanup (MANDATORY — see Teardown below)
agent-browser --session test close
```

## Teardown

**Scoped teardown is mandatory: always close the named session(s) you opened, by
name, as the final step of any browser work. Never leave a session open.**
`agent-browser` runs a long-lived daemon per session that spawns a headless
Chrome with `--remote-debugging-port`. Pair every `open` with a matching `close`
for the same session name:

```bash
agent-browser --session [name] close   # tears down THIS session's daemon + Chrome
```

- One `close` per `open`, every time — even when a test fails (use a trap or a
  `finally`-style cleanup step so `close` runs on the error path too).
- Close only the session(s) **you** opened, by name. Do not use `close --all` —
  it is unsafe under concurrent sessions and will tear down browsers other agents
  are actively using. Closing your own named sessions is the correct, scoped
  behavior.
- Use a distinct, predictable `--session` name so your cleanup is unambiguous.
- Never assume the session "timed out" — daemon idle-shutdown is **disabled by
  default**. If you do not `close`, the session stays alive.

### Why scoped teardown matters (the runaway-CPU failure mode)

If a session's daemon dies without closing Chrome — a crashed test, an agent that
forgot to `close`, or a session server killed mid-run — the headless Chrome is
**reparented to launchd (PPID 1) and keeps spinning at ~100% CPU indefinitely**.
Quitting the Chrome.app does NOT kill these detached automation instances, and
they are invisible to `agent-browser session list` (the dead daemon no longer
answers), so they will not self-heal. In one incident three orphaned instances
ran for **four days**, pinning a 10-core machine to a load average of 54.
Disciplined `close` on the normal exit path prevents the common case.

### Manual escape hatch (abnormal-exit only)

Discipline cannot cover the abnormal-exit path (crash, killed test, daemon
death). On the rare occasion you spot a runaway (sluggish machine, fans spinning,
high load), force-kill the orphaned automation Chromes by hand:

```bash
# Inspect: orphaned remote-debugging Chrome (PPID 1 = daemon already dead)
ps -axo pid,ppid,command | grep -- --remote-debugging-port | grep -v -- --type=

# Force-kill every agent-browser Chrome:
pkill -9 -f "remote-debugging-port"
```

> **Caution:** `pkill -9 -f "remote-debugging-port"` kills **ALL** agent-browser
> Chromes, including other live sessions. Use it only when you know no other
> session is active — i.e. when you have spotted a genuine runaway. There is no
> automation for this; it is a deliberate manual step.

### The dev server is the same failure mode (kill it too)

If your test targets a **local dev server you started** (`pnpm dev` / `next dev`),
that process is a second orphan class: a subagent's shell does not persist `$!`
across tool calls, so a background `next dev` (≈200% CPU) outlives the agent and
keeps running. On a machine that also hosts a single self-hosted CI runner this is
not cosmetic — one orphaned `next-server` drove a Mac to **load ~30** and stalled a
CI vitest step at **34 min** (2026-06-24). Kill the dev server you started, by
process, as the final teardown step on both the success and error paths:

```bash
pkill -f "next dev"        # or the app's dev command from AGENTS.md
```

> **Caution (same as the Chrome hatch):** this matches ALL dev servers. Safe when
> the agent is the only one running it; skip if a human has their own `pnpm dev` up.
> Targeting a deployed preview/production URL? You started no server — nothing to kill.

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

QA story workflow requires the consuming app to provide `commands/browser/` and story files (BCA has these). Check they exist before invoking; otherwise use the browser-tester subagent directly.

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
