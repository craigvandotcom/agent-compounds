---
name: simulator-qa
description: Use when QA-ing the NATIVE app build in the iOS Simulator — full journey validation against the real native shell (keyboard, safe-area, splash, deep links, OAuth sheets, plugin calls, push payloads), appearance matrix, screenshots/video evidence, and perf sanity. Triggers on "test native app", "simulator QA", "QA in simulator", "test on iOS", "validate native build", "native smoke test". macOS only — see Platform Gate.
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (bundle id, build command,
> simulator target, deep-link scheme, journeys, sim-impossible flows) → read the
> consuming app's `.claude/skills/CORE/SKILL.md`** — journeys live in
> `CORE/journeys/`, native facts in `CORE/journeys/native.md`.
> Do not add app-specific facts to this file — they belong in CORE.

# Simulator QA Skill

> **⚠ TEMP — primary tool choice is PENDING a Mac bake-off.** Before the
> first real QA run on the Mac, execute **`_DECISION-tool-bakeoff.md`**
> (AXe vs agent-device vs XcodeBuildMCP-CLI against Body Compass), finalize
> this skill per its checklist, and delete that file. Until then, the AXe
> default below is provisional.

Drive the **real native app** in the iOS Simulator with an accessibility-tree
see → act → assert loop. Tooling: **AXe** (see/tap/type/swipe — taps go through
the real native touch pipeline) + **`xcrun simctl`** (lifecycle, screenshots,
video, push payloads, deep links, permissions, appearance). No WebDriverAgent,
no agent app inside the simulator, nothing to re-sign per Xcode release.

Android (emulator) support: planned. This skill is iOS-first; the structure
(layers, checklist, journey reuse) is platform-agnostic and will be copied.

## Platform Gate (read first)

**Everything here requires macOS** (Xcode + simulators). Check before doing
anything: `uname` → if not `Darwin`, **stop** — report that simulator QA needs
a Mac session and hand off. Remote Linux→Mac driving (idb gRPC) exists but is
friction-prone — see `setup.md` appendix; don't attempt it ad hoc.

## Layered QA model — what to test where

| Layer | Tool | Coverage | Cost |
| ----- | ---- | -------- | ---- |
| 1. Browser (DOM) | `browser-testing` skill (agent-browser) | Exhaustive: every page, button, state, edge case | Cheap, fast |
| 2. **Simulator (this skill)** | AXe + simctl | Every journey happy-path with REAL native taps + the native-shell checklist | Slower per action |
| 3. DOM-in-shell | Appium webview context | DOM truth inside the real shell (origin/cookies/storage) | Flaky; escape hatch only (`setup.md`) |

For hybrid (Capacitor) apps the webview renders the **same bundle** as the
browser — so exhaustive DOM-matrix coverage stays in Layer 1. Layer 2 proves
what only the native shell can: real touch pipeline, keyboard, safe-area,
splash/cold-start, plugin bridge, system sheets, deep links, lifecycle. The
full list → `native-shell-checklist.md`.

**Decision rule:** logic/layout/state bug → Layer 1. "Does the real app work
when really touched" → Layer 2. DOM assertion inside the shell → Layer 3,
sparingly.

## Depth levels

- **smoke** — build, install, launch, splash→first-paint, auth, primary
  journey. Run after native-touching changes, before TestFlight pushes.
- **full** — every journey in the app's `CORE/journeys/` walked natively + the
  native-shell checklist + appearance spot-checks.
- **exhaustive** — full + walk every screen/control reachable, appearance
  matrix (dark/light × 2–3 Dynamic Type sizes), deep-link matrix, lifecycle
  (background/resume), perf sanity pass (`perf-and-limits.md`). Release-grade.

## Toolchain

```bash
brew install cameroncooke/axe/axe   # see + act (accessibility tree, HID taps)
# simctl ships with Xcode — nothing to install
```

Optional upgrade: **XcodeBuildMCP in CLI mode** (Sentry) — same engine (AXe,
bundled+pinned), adds `snapshot_ui` elementRefs + `wait_for_ui` predicates
through plain Bash. Prefer its CLI over its MCP server (token cost; Claude
Code subagents can't reliably reach MCP servers). New + unproven on webview
apps as of 2026-06 — spike before relying on it. See `setup.md`.

## Core loop

```bash
# 0. Build + install — ALWAYS via the app's own build command (from CORE).
#    Never xcodebuild alone: hybrid apps must sync web assets first or you
#    QA a stale bundle (the #1 false-result source).

# 1. Simulator up (keep it warm between runs — cold boot is 20–60s)
xcrun simctl boot "<sim-name>" 2>/dev/null || true
xcrun simctl bootstatus "<sim-name>"        # WAIT for this, not the Booted flag
UDID=$(xcrun simctl list devices booted -j | jq -r '[.devices[][]|select(.state=="Booted")][0].udid')

# 2. Launch with console logs
xcrun simctl launch --console-pty booted <bundle-id> &   # or plain `launch` + log stream

# 3. SEE — accessibility tree: labels, roles, frames (JSON)
axe describe-ui --udid $UDID

# 4. ACT — tap the CENTER of an element's frame from step 3
axe tap -x <cx> -y <cy> --udid $UDID
axe type "text to enter" --udid $UDID
axe swipe --start-x 200 --start-y 600 --end-x 200 --end-y 200 --udid $UDID

# 5. ASSERT — re-run describe-ui, check expected label/value appeared;
#    poll with short sleeps for async transitions (2–10s budget)

# 6. EVIDENCE
xcrun simctl io booted screenshot /tmp/qa-<step>.png
xcrun simctl io booted recordVideo --codec h264 /tmp/qa-flow.mp4 &  # kill -INT to stop
```

### Discipline rules (non-negotiable)

1. **Tree first, pixels second.** Act only on frames from `describe-ui`. Never
   guess coordinates from a screenshot. Screenshots are for *visual
   confirmation* of a state the tree already proved.
2. **Re-snapshot after every navigation, sheet, scroll, or animation.** Frames
   go stale; taps on stale frames are the top flake source.
3. **Element not in the tree?** Scroll it into view first (the tree only
   exposes renderable content). Still missing → that's an **accessibility bug
   in the app** (unlabeled control) — report it as a finding, don't hack
   around it with coordinates.
4. **System UI is tappable too.** Permission alerts, native OAuth sheets,
   share sheets all appear in the tree — handle them like any element.
5. **Animations:** if taps mis-land during transitions, wait for the tree to
   stabilize (two identical consecutive snapshots = settled).

## Seeing the WebView (hybrid/Capacitor apps)

WebKit projects the DOM's accessibility tree into UIAccessibility, so web
content appears natively typed: `Button`, `StaticText`, `TextField`, `Link`.

- Labels come from **visible text, `aria-label`, `alt`, `placeholder`** — the
  app's existing journey button-labels usually work verbatim.
- `data-testid`, CSS selectors, DOM attributes are **invisible** on this
  plane. If a control is unreachable, the fix is an `aria-label` (which is
  also an a11y win) — not Layer 3.
- Element-dense pages snapshot slowly; prefer targeted scroll + re-snapshot
  over dumping huge trees repeatedly.

## State control quick reference (simctl)

| Need | Command |
| ---- | ------- |
| Deep link / OAuth callback | `xcrun simctl openurl booted "<scheme>://<path>"` |
| Push notification payload | `xcrun simctl push booted <bundle-id> payload.apns` |
| Pre-grant/revoke permission | `xcrun simctl privacy booted grant photos <bundle-id>` (camera, location, …) |
| Dark / light mode | `xcrun simctl ui booted appearance dark` |
| Dynamic Type | `xcrun simctl ui booted content_size accessibility-extra-extra-extra-large` |
| GPS | `xcrun simctl location booted set 51.5,-0.12` |
| Deterministic screenshots | `xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4` (clear when done) |
| App logs | `xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS "<bundle-id>"'` |
| Reset app state | `xcrun simctl uninstall booted <bundle-id>` then reinstall |
| Face ID match/no-match | see `perf-and-limits.md` (notifyutil pattern) |

## Reusing the app's journeys

The app's `CORE/journeys/*.md` files are the **what** (flows, exact button
labels, checkpoints, edge cases). This skill is the **how**. To run a journey
natively: follow its happy path step-by-step, locating each step's button
label in `describe-ui` output instead of a DOM ref.

The app's CORE must also provide **`journeys/native.md`** with the native
facts this skill needs:

```
- bundle id, Xcode project/scheme, default simulator
- build+install command (the one that syncs web assets)
- deep-link scheme(s) and example URLs
- native-only flows (OAuth sheets, plugin calls) and how to exercise them
- sim-impossible flows (camera, Bluetooth, …) and their stand-ins
- app-specific native hot spots (keyboard config, splash behavior, …)
```

If `native.md` doesn't exist in the consuming app yet, create it from the
template above before the first full QA pass.

## Performance & rendering — what you may claim

Full taxonomy + hardware matrix + xctrace recipes → **`perf-and-limits.md`**.
The headlines:

- **CAN verify:** layout/rendering correctness, dark mode, Dynamic Type,
  functional flows, crashes, memory **leaks**, main-thread hangs
  (sim hang ⇒ almost certainly worse on device — high-confidence finding),
  relative CPU hotspots, launch *success* and gross (≥2x) launch regressions.
- **MISLEADING — never report as findings:** fps, animation smoothness, hitch
  counts, absolute launch ms, memory footprint. Host-Mac numbers, not iPhone.
- **CANNOT:** GPU/Metal perf, thermal, battery, jetsam behavior, camera,
  Bluetooth, ARKit, App Attest, Apple Pay, haptics. (Push payloads, Face ID,
  StoreKit purchases, HealthKit, GPS all have working simulators/workarounds —
  see the matrix.)
- **Video:** qualitative only (recordings are variable-frame-rate). Freezes
  ≥0.5s, wrong state order, layout pops = real findings. Frame-timing claims
  from sim video = noise, never report.

## Reporting

```markdown
SIM_QA_VALIDATION:
platform: ios-simulator
device: [sim model + iOS version]
app_build: [how built — command + branch/commit]
depth: smoke | full | exhaustive
journeys_tested: [list, with PASS/FAIL each]
native_checklist: [items checked, PASS/FAIL each — see native-shell-checklist.md]
appearance_matrix: [combos checked]
a11y_findings: [unlabeled controls discovered via the tree]
perf_observations: [qualitative only — hangs, freezes, leaks]
evidence: [screenshot/video paths]
status: PASS | FAIL
notes: [issues, sim-impossible flows skipped and why]
```

## Teardown

- Stop any `recordVideo` processes (`kill -INT`).
- `xcrun simctl status_bar booted clear` if you overrode it.
- Reset appearance/content-size if you changed them.
- **Leave the simulator booted** (warm sim = fast next run). Do NOT shutdown
  or erase unless state pollution is suspected.

## Troubleshooting

- **Stale UI / missing recent changes** → web assets weren't synced; rerun the
  app's full build command (never bare `xcodebuild`). Check bundle freshness
  before blaming the code.
- **`describe-ui` missing an element** → not rendered yet (wait), offscreen
  (scroll), or unlabeled (file a11y finding).
- **Taps mis-land** → stale frames; re-snapshot, wait for settle.
- **Sim "Booted" but unresponsive** → you didn't wait for `bootstatus`.
- **AXe breaks after Xcode update** → `brew upgrade axe`; known lag of days,
  fall back to XcodeBuildMCP or `idb` if urgent.
- **Permission dialog blocks flow unexpectedly** → pre-grant with
  `simctl privacy` in setup, or handle the alert via the tree.

## Related files

- `native-shell-checklist.md` — what ONLY the simulator/native shell can catch
- `perf-and-limits.md` — CAN/MISLEADING/CANNOT taxonomy, hardware matrix,
  xctrace recipes, visual regression, automation speed tricks
- `setup.md` — Mac setup, XcodeBuildMCP option, Linux→Mac remote appendix,
  Appium webview escape hatch (Layer 3)
- `browser-testing/SKILL.md` — Layer 1 (exhaustive DOM coverage)
- Consuming app's `CORE/journeys/` + `CORE/journeys/native.md` — the what
