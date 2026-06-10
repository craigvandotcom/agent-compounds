# Simulator QA — Setup & Alternatives

## Standard setup (Claude Code session ON the Mac)

```bash
# One-time
xcode-select -p                          # verify Xcode CLT present
brew install cameroncooke/axe/axe        # see/act CLI (accessibility + HID)
brew install jq                          # JSON parsing for simctl/axe output

# Verify
xcrun simctl list devices | head
axe --help
```

That's the whole stack. AXe rides Apple's private accessibility + HID APIs
(the same frameworks Meta's idb uses) — no WebDriverAgent to build/re-sign, no
server process, no agent app inside the simulator.

**For hybrid apps:** ensure web controls carry `aria-label`s (or visible
text) — those become the accessibility labels AXe targets. This is the only
app-side requirement.

## Option: XcodeBuildMCP (MCP server, same engine)

[getsentry/XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP) bundles
AXe and adds two genuinely better primitives:

- `snapshot_ui` → semantic snapshot with **elementRef** targets (`tap {"elementRef":"e8"}`
  — no coordinate math)
- `wait_for_ui` → polls until a predicate holds (label/textContains/gone/settled)
  — a real assertion/synchronization primitive

Plus build/run/test tools, LLDB attach, and a bridge to Xcode 26.3's built-in
MCP. Cost: an MCP server's tool-schema token overhead (~84 tools; use its
tool-filtering or skills mode).

```bash
brew tap getsentry/xcodebuildmcp && brew install xcodebuildmcp
claude mcp add XcodeBuildMCP xcodebuildmcp mcp
```

**When to prefer it:** long interactive QA sessions (elementRef + wait_for_ui
reduce flake and round-trips). **When to skip:** occasional smoke runs — the
CLI is lighter. Avoid WebDriverAgent-based servers (e.g. mobile-mcp) for
sim-only iOS work: WDA breaks on new Xcode/iOS versions for weeks at a time.

## Option: Maestro (durable regression artifacts)

If a QA pass should leave behind a *repeatable* test, Maestro YAML flows
(`tapOn: "Label"`, `assertVisible`, built-in retry/wait) run on sims and in
CI, and Maestro ships an official MCP (`claude mcp add maestro -- maestro mcp`,
needs Java). Webview content is reachable via the same accessibility tree.
Pattern: explore with AXe interactively → commit the validated flow as
Maestro YAML → `maestro test flows/` in CI.

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
screenshots/video still need `simctl` on the Mac side. **Default remains: run
simulator QA from a Mac session; use this only when a Mac session is
impossible.** Builds can't run from Linux either way — the Mac is required
regardless.

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
