# Simulator QA — Setup & Alternatives

## Standard setup (Claude Code session ON the Mac)

```bash
# One-time
xcode-select -p                          # verify Xcode CLT present
npm install -g agent-device              # see/act CLI (XCUITest engine)
brew install jq                          # JSON parsing for simctl output

# Verify
xcrun simctl list devices | head
agent-device devices --platform ios
```

First `snapshot` after `open` builds the XCUITest runner app into the target
simulator (one-time per sim, ~seconds on a warm machine). No WebDriverAgent
to re-sign, no server process to babysit — the runner is rebuilt automatically
when needed (`agent-device prepare ios-runner --platform ios` forces it).

**Gotchas (hit in the 2026-06 bake-off):**

- **Duplicate sim names**: agent-device selects devices by *name* and will
  happily boot a same-named sim on an older iOS runtime. Rename duplicates:
  `xcrun simctl rename <udid> "iPhone 17 Pro (26.4)"`.
- **iOS keyboard**: cannot be dismissed by the tool (`keyboard dismiss` →
  `UNSUPPORTED_OPERATION`). Plan flows around it — `type $'\n'` to submit,
  blur via a sheet round-trip. See SKILL.md discipline rule 3.
- **For hybrid apps:** ensure web controls carry `aria-label`s (or visible
  text) — those become the accessibility labels agent-device targets. This is
  the only app-side requirement.

Useful extras that come free with agent-device: `.ad` session replays
(`open --save-script`, `replay`, `test` for suites — covers the durable
regression-artifact need), `alert` handling, `push` payload delivery,
`record start/stop` video, `network log`, `perf`.

## Fallback: AXe + simctl (engine diversity)

```bash
brew install cameroncooke/axe/axe
```

AXe rides Apple's private accessibility + HID APIs — a *different* failure
class than the XCUITest runner. When an Xcode update breaks one, the other
usually still works. Keep it installed; reach for it when agent-device's
runner is broken.

**Hard limit on webview apps (verified on iOS 26.5, AXe 1.7.1):**
`axe describe-ui` returns **empty Groups for all WKWebView content** — full
tree enumeration is impossible. Only two things still work:

- `axe describe-ui --point x,y` — correct role/label/frame for the element at
  a point (probe-then-tap, guided by a screenshot)
- HID primitives: `axe tap/type/swipe/key` (key 40 = Return) — fine once a
  field is focused

That makes AXe a **smoke/stopgap tool, not a journey driver**, for hybrid
apps: screenshot → point-probe → tap loops are slow, blind to toasts/layout
shifts, and violate tree-first discipline. Native-UI apps are unaffected.

## Eliminated: XcodeBuildMCP (for webview apps)

Bake-off result (2026-06, v2.6.2): its CLI mode passes the transport gate
(`ui-automation snapshot-ui` / `wait-for-ui` are CLI-reachable), but it
bundles the AXe engine and inherits the same webview blindness — `snapshot_ui`
sees 0 targets on every webview screen, so its elementRef/`wait_for_ui`
primitives never engage. It does report honestly ("no likely interaction
targets found") rather than empty-tree-as-success. **Re-evaluate only for
native-UI (SwiftUI/UIKit) apps**, where its `wait_for_ui` predicates and
screen-hash dedup are genuinely better primitives than raw AXe — and prefer
its CLI over its MCP server (Sentry's own data: MCP ≈ same success at +106%
tokens; Claude Code subagents can't reliably reach MCP servers).

Avoid WebDriverAgent-based servers (e.g. mobile-mcp) for sim-only iOS work:
WDA breaks on new Xcode/iOS versions for weeks at a time.

> **Horizon note:** WWDC 2026 announced Xcode 27 with a Device Hub and
> first-party agent-driven app automation (~fall 2026). This skill's method
> (see → act → assert over the a11y tree, journeys, checklist) is
> tool-agnostic — re-evaluate the tool layer when Xcode 27 ships.

## Appendix: Linux → Mac remote driving (idb)

The only mature path for driving a Mac-hosted simulator from a Linux session:

```bash
# Mac:   brew tap facebook/fb && brew install idb-companion
#        idb_companion --udid <SIM-UDID>        # gRPC on :10882
# Linux: pip install fb-idb
#        idb connect <mac-ip> 10882
idb ui describe-all        # accessibility JSON
idb ui tap <x> <y>
idb ui text "hello"
idb ui swipe <x1> <y1> <x2> <y2>
```

Works, but: Meta maintains idb at a slow burn (expect lag after Xcode
releases), the companion must be (re)started on the Mac out-of-band, and
screenshots/video still need `simctl` on the Mac side. idb shares AXe's
private-AX-API plane, so expect the same webview blindness on tree dumps.
**Default remains: run simulator QA from a Mac session.** Builds can't run
from Linux either way — the Mac is required regardless.

## Appendix: Layer 3 — DOM-in-shell (Appium webview context)

True DOM commands (CSS selectors, `execute_script`) inside the real app's
WKWebView. The ONLY tool that does this is Appium's XCUITest driver via
webview context switching. Reserve it for assertions that are both
DOM-level AND shell-specific — e.g. `capacitor://localhost` origin
cookie/storage behavior. Known-flaky; keep the suite thin.

Requirements:

1. App config must set the webview inspectable — Capacitor:
   `ios.webContentsDebuggingEnabled: true` in `capacitor.config.ts`
   (NOT automatic in debug builds on iOS, unlike Android).
2. Appium + XCUITest driver on the Mac. The official `appium/appium-mcp`'s
   `prepare_ios_simulator` auto-installs a prebuilt WebDriverAgent.
3. Session: `getContexts()` → switch to `WEBVIEW_<pid>` — **retry in a loop**,
   the context list is intermittently empty (canonical failure mode). Use
   `nativeWebTap: true` if JS-synthesized clicks don't trigger behavior.

Note: Playwright cannot do this (desktop WebKit only, no WKWebView attach —
long-open upstream issues). Don't burn time trying.
