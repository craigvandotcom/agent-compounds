# Common Validation Patterns

Reusable assertions and patterns for browser testing.

## Session Setup (Always Do First)

```bash
agent-browser --session [name] open "[URL]"
agent-browser --session [name] set viewport 390 844
agent-browser --session [name] wait --load networkidle
```

Mobile viewport (390x844) is **recommended for mobile-first apps** targeting 320–428px. Check the consuming app's CORE for its viewport policy. Only use desktop viewport when explicitly requested.

## Standard Assertions

### Page Loads Successfully

```bash
agent-browser --session [name] snapshot -i
```

**Pass criteria:**

- HTTP 200 (page renders)
- Not stuck on "Loading..."
- Expected elements visible

### No Critical Console Errors

```bash
agent-browser --session [name] errors
```

**Ignore these (non-critical):**

- `Failed to load resource: 404` (favicon, manifest)
- `Manifest` errors
- `deprecated` warnings
- `AuthApiError` (expected on invalid login attempts)
- `"<PluginName>" plugin is not implemented on web` (Capacitor stubs — always
  present on web builds, never causal for auth, navigation, or save failures)

**Flag these (critical):**

- Uncaught exceptions
- React errors
- Network failures for API calls
- Type errors

### Element Exists

```bash
agent-browser --session [name] snapshot -i
# Check output for expected element
```

### Element is Clickable

```bash
agent-browser --session [name] click @[ref]
# Should not error
```

### Form Submission Works

```bash
agent-browser --session [name] fill @[input-ref] "[value]"
agent-browser --session [name] click @[submit-ref]
agent-browser --session [name] wait --load networkidle
```

---

## Wait Patterns

### Wait for Navigation

```bash
agent-browser --session [name] wait --url "/expected-path"
```

### Wait for Network Idle

```bash
agent-browser --session [name] wait --load networkidle
```

### Wait with Timeout

```bash
agent-browser --session [name] wait --timeout 15000
```

### Wait for Element (via polling)

```bash
# Retry snapshot until element appears
for i in 1 2 3; do
  agent-browser --session [name] snapshot -i | grep -q "expected text" && break
  agent-browser --session [name] wait --timeout 2000
done
```

---

## Screenshot Patterns

### Capture Current State

```bash
agent-browser --session [name] screenshot "screenshots/[name]-[timestamp].png"
```

### Capture for Comparison

```bash
# Before change
agent-browser --session [name] screenshot "screenshots/before.png"

# After change
agent-browser --session [name] screenshot "screenshots/after.png"
```

---

## Session Management

### Create Named Session

```bash
agent-browser --session my-test open "[URL]"
```

### Reuse Existing Session

Session persists until closed. Subsequent commands use same browser context:

```bash
agent-browser --session my-test open "[another-URL]"
```

### Close Session

```bash
agent-browser --session my-test close
```

### Multiple Parallel Sessions

```bash
agent-browser --session test-1 open "[URL-1]"
agent-browser --session test-2 open "[URL-2]"
# ... work with both
agent-browser --session test-1 close
agent-browser --session test-2 close
```

---

## Validation Report Template

```markdown
BROWSER_VALIDATION:
environment: [local | preview | production]
session: [session-name]
url: [tested URL]

smoke_test:
status: PASS | FAIL
page_loads: yes | no
console_errors: none | [list]

auth_test:
status: PASS | FAIL | SKIPPED
login_successful: yes | no
reason: [if skipped/failed]

feature_tests: - name: [test name]
status: PASS | FAIL
notes: [details]

overall_status: PASS | FAIL | PARTIAL
blocking_issues: [list if any]
screenshots: [list of paths]
```

---

## Error Recovery

### Browser Unresponsive

```bash
agent-browser --session [name] close
# Start fresh session
agent-browser --session [name]-2 open "[URL]"
```

### Daemon Resource Exhaustion (os error 11)

If click / navigation / snapshot commands fail with `Resource temporarily unavailable (os error 11) after 5 retries`, the daemon has hit an OS file-descriptor or process limit — not an app bug.

```bash
# Close all open sessions
agent-browser --session [name] close

# Kill stale daemon processes
pkill -f agent-browser || true

# Open a fresh session (daemon auto-restarts)
agent-browser --session [name]-2 open "[URL]"
```

If failure persists after restart, bypass click-driven flow and navigate directly via URL (`agent-browser open "http://localhost:3000/app?view=..."`) then snapshot — this reduces the command count against the daemon.

### Element Ref Changed

```bash
# Re-fetch snapshot to get current refs
agent-browser --session [name] snapshot -i
# Use new refs
```

### Page Stuck Loading

```bash
agent-browser --session [name] reload
agent-browser --session [name] wait --load networkidle --timeout 30000
```
