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

## Option: XcodeBuildMCP — use its CLI MODE, not the MCP server

[getsentry/XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP) bundles
a pinned AXe binary (no version skew) and adds two genuinely better
primitives on top of the same engine:

- `snapshot_ui` → semantic snapshot with **elementRef** targets (`tap {"elementRef":"e8"}`
  — no coordinate math) + screen-hash dedup (`sinceScreenHash`)
- `wait_for_ui` → polls until a predicate holds (label/textContains/gone/settled)
  — a real assertion/synchronization primitive nothing else has

**Prefer it as a CLI** (`xcodebuildmcp <workflow> <tool>` + the skill that
`xcodebuildmcp init` installs), NOT as an MCP server:

- Sentry's own 1,350-trial study (Feb 2026): MCP mode ≈ same success rate as
  a primed shell at **+106% tokens / +135% cost**.
- Claude Code **subagents can't reliably reach MCP servers** (background
  subagents not at all; some hallucinate tool results) — a CLI works in every
  spawned engineer/reviewer/tester; an MCP server only at top level.
- House convention is CLI-over-MCP for exactly these reasons.

```bash
brew install getsentry/xcodebuildmcp/xcodebuildmcp
xcodebuildmcp init        # installs its CLI agent skill
xcodebuildmcp doctor      # verify environment
# Verify once: snapshot_ui / wait_for_ui reachable via the ui-automation CLI
# workflow (CLI and MCP "share the same tool implementations" per docs).
```

MCP-server mode (`claude mcp add XcodeBuildMCP xcodebuildmcp mcp`) is an
opt-in for long top-level interactive pairing sessions only — enable just the
`simulator` workflow to cap schema cost.

**Caveats (as of 2026-06):** the elementRef/`wait_for_ui` runtime model
shipped 2026-06-01 — very new. Known rough edges: refs can go stale with an
unhelpful error (issue #445), and `snapshot_ui` can return an **empty tree
while reporting success** when the sim's AX daemon isn't ready (#408) — treat
empty/zero-frame snapshots as "not ready → retry / relaunch app", and fall
back to AXe coordinate taps if refs misbehave. There is **no published
evidence yet of anyone running it against a Capacitor/WKWebView app** — spike
it against your app before relying on it for a full pass.

Avoid WebDriverAgent-based servers (e.g. mobile-mcp) for sim-only iOS work:
WDA breaks on new Xcode/iOS versions for weeks at a time.

> **Horizon note:** WWDC 2026 announced Xcode 27 with a Device Hub and
> first-party agent-driven app automation (~fall 2026). This skill's method
> (see → act → assert over the a11y tree, journeys, checklist) is
> tool-agnostic — re-evaluate the tool layer when Xcode 27 ships.

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
