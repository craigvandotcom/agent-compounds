---
name: ac-qa-simulator
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

Drive the **real native app** in the iOS Simulator with an accessibility-tree
see → act → assert loop. Tooling: **agent-device** (Callstack; XCUITest engine —
sees the full webview tree, @ref targeting, wait/is/find primitives, real HID
taps) + **`xcrun simctl`** (lifecycle, screenshots, video, push payloads, deep
links, permissions, appearance). AXe is the engine-diverse fallback (point-probe
only on webview apps — see `setup.md`).

> Tool decision settled 2026-06-11 by bake-off against a Capacitor app on
> iOS 26.5: AXe/XcodeBuildMCP tree dumps are **webview-blind** (empty Groups);
> agent-device's XCUITest snapshot sees everything. Re-evaluate the tool layer
> when Xcode 27's first-party agent automation ships (~fall 2026).

Android (emulator) support: planned — agent-device drives Android with the same
commands, so the structure (layers, checklist, journey reuse) carries over.

## Platform Gate (read first)

**Everything here requires macOS** (Xcode + simulators). Check before doing
anything: `uname` → if not `Darwin`, **stop** — report that simulator QA needs
a Mac session and hand off. Remote Linux→Mac driving (idb gRPC) exists but is
friction-prone — see `setup.md` appendix; don't attempt it ad hoc.

## Layered QA model — what to test where

| Layer | Tool | Coverage | Cost |
| ----- | ---- | -------- | ---- |
| 1. Browser (DOM) | `browser-testing` skill (agent-browser) | Exhaustive: every page, button, state, edge case | Cheap, fast |
| 2. **Simulator (this skill)** | agent-device + simctl | Every journey happy-path with REAL native taps + the native-shell checklist | Slower per action |
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
npm install -g agent-device   # see + act (XCUITest runner; first snapshot builds it)
brew install jq               # JSON parsing for simctl output
# simctl ships with Xcode — nothing to install
```

agent-device matches simulators **by name** — if two sims share a name it can
boot the wrong one. Rename duplicates first (`xcrun simctl rename <udid> "<name (os)>"`).

## Core loop

```bash
# 0. Build + install — ALWAYS via the app's own build command (from CORE).
#    Never xcodebuild alone: hybrid apps must sync web assets first or you
#    QA a stale bundle (the #1 false-result source).

# 1. Simulator up (keep it warm between runs — cold boot is 20–60s)
xcrun simctl boot "<sim-name>" 2>/dev/null || true
xcrun simctl bootstatus "<sim-name>"        # WAIT for this, not the Booted flag

# 2. Open an app session (binds device + app; --relaunch for a clean restart)
agent-device open <bundle-id> --platform ios --device "<sim-name>"

# 3. SEE — full accessibility tree with @ref targets, roles, labels, values
agent-device snapshot -i                    # add --raw for frames + hittability

# 4. ACT — target by @ref from the LATEST snapshot (refs renumber every snapshot)
agent-device click @e24
agent-device fill @e19 "text"               # REPLACES field content (no clear needed)
agent-device type $'\n'                     # types into the FOCUSED field
agent-device scroll down 200 | swipe 200 600 200 250

# 5. ASSERT / SYNC — built-in waits beat sleep-and-resnapshot
agent-device wait "Dashboard" 15000         # text/ref/selector, with timeout
agent-device is visible "<selector>"        # predicate assert

# 6. EVIDENCE
xcrun simctl io booted screenshot /tmp/qa-<step>.png
agent-device record start /tmp/qa-flow.mp4  # ... agent-device record stop
```

### Discipline rules (non-negotiable)

1. **Tree first, pixels second.** Act only on @refs from the latest
   `snapshot -i`. Never guess coordinates from a screenshot. Screenshots are
   for *visual confirmation* of a state the tree already proved.
2. **Refs renumber on every snapshot.** Re-snapshot after every navigation,
   sheet, scroll, keyboard event, or animation — then use the NEW refs. Taps
   on stale refs are the top flake source.
3. **The iOS keyboard is the #1 mis-tap source.** agent-device cannot dismiss
   it (`keyboard dismiss` is unsupported without a native dismiss control).
   While the keyboard is up, frames of elements under it are stale/unhittable —
   a tap there hits keyboard keys and **types characters into your form**.
   - NEVER tap an element whose frame center sits in the keyboard's region.
   - Submit forms / commit inputs with `type $'\n'` (fires the web form/input
     Enter handler) instead of hunting for a button under the keyboard.
   - To blur: tap a verified non-interactive node, or round-trip a top-of-form
     control that opens its own sheet (open → close = input blurred, keyboard
     gone). Verify with a fresh snapshot containing no `[key]` nodes.
4. **Checkpoint your fills.** After `fill`, verify the value landed (snapshot
   grep) before submitting — fills can race screen transitions and land
   nowhere. A wait on the *previous* screen's disappearance is cheaper than
   diagnosing a cascade.
5. **Empty/keyboard-only snapshot ⇒ retry.** Rarely (~1/50) the snapshot
   returns only keyboard nodes or a near-empty tree while reporting success.
   Treat as "not ready": retry once or twice before concluding anything.
6. **Element not in the tree?** Scroll it into view first (the tree only
   exposes renderable content). Still missing → that's an **accessibility bug
   in the app** (unlabeled control) — report it as a finding, don't hack
   around it with coordinates.
7. **System UI is tappable too.** Permission alerts, native OAuth sheets,
   share sheets, keyboard-education overlays (QuickPath tips) all appear in
   the tree — handle them like any element (`alert` inspects/handles platform
   alerts directly).
8. **Prefer @refs over semantic label clicks.** `click "Label"` resolves
   internally but failed silently in testing; `click @ref` from a fresh
   snapshot is deterministic. `hittable:false` in `--raw` output is advisory,
   not authoritative — verify by outcome (wait/assert), not by flag.
9. **Catch toasts — success waits race past them.** Toasts are transient
   (~4s) and a `wait "<next screen>"` that passes can still have skipped an
   error toast the user would have seen. The toast container IS in the tree
   (web toast libraries label a region, e.g. "Notifications alt+T"). After
   EVERY mutation (save/upload/delete/submit), poll that region's children
   for ~5s at sub-second cadence before declaring the step clean — toast
   text present = a finding, even when the operation eventually succeeded.
10. **Empty ≠ clean.** Before interpreting an empty list/zero-count grep as
   success, check the tree for error-state nodes (error boundaries, "Retry"
   buttons, error toasts). A view in an error state greps exactly like an
   empty view — the canonical false-clean.
11. **Screenshot hygiene for long sessions.** Downscale before reading —
   `sips -Z 1500 <png>` — BEFORE the first Read. The model API caps images
   at 2000px/side once a conversation carries many images; raw modern-iPhone
   screenshots (2622px tall) read fine early in a session and then ALL new
   image reads fail late in it. Tree-first keeps screenshot count low to
   begin with.

## Seeing the WebView (hybrid/Capacitor apps)

XCUITest projects the DOM's accessibility tree fully: web content appears as
`[button]`, `[text]`, `[text-field]`, `[securetextfield]`, `[link]`,
`[switch]`, with `[off-screen below]` summaries for scrolled-out content.

- Labels come from **visible text, `aria-label`, `alt`, `placeholder`** — the
  app's existing journey button-labels usually work verbatim.
- `data-testid`, CSS selectors, DOM attributes are **invisible** on this
  plane. If a control is unreachable, the fix is an `aria-label` (which is
  also an a11y win) — not Layer 3.
- Element-dense pages still snapshot fast (sub-second for 300+ node trees);
  visible-node listing + off-screen summary keeps output compact.

## State control quick reference (simctl)

| Need | Command |
| ---- | ------- |
| Deep link / OAuth callback | `xcrun simctl openurl booted "<scheme>://<path>"` (or `agent-device open <url>`) |
| Push notification payload | `xcrun simctl push booted <bundle-id> payload.apns` (or `agent-device push`) |
| Pre-grant/revoke permission | `xcrun simctl privacy booted grant photos <bundle-id>` (camera, location, …) |
| Dark / light mode | `xcrun simctl ui booted appearance dark` |
| Dynamic Type | `xcrun simctl ui booted content_size accessibility-extra-extra-extra-large` |
| GPS | `xcrun simctl location booted set 51.5,-0.12` |
| Deterministic screenshots | `xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4` (clear when done) |
| App logs | `xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS "<bundle-id>"'` (or `agent-device logs`) |
| Reset app state | `xcrun simctl uninstall booted <bundle-id>` then reinstall |
| Face ID match/no-match | see `perf-and-limits.md` (notifyutil pattern) |

## Reusing the app's journeys

The app's `CORE/journeys/*.md` files are the **what** (flows, exact button
labels, checkpoints, edge cases). This skill is the **how**. To run a journey
natively: follow its happy path step-by-step, locating each step's button
label in `snapshot -i` output instead of a DOM ref.

**Journey docs drift.** When a label/flow in the doc doesn't match the tree,
trust the tree, complete the journey via the real UI, and fix the doc as part
of the QA pass (that's a finding, not a blocker).

The app's CORE must also provide **`journeys/native.md`** with the native
facts this skill needs:

```
- bundle id, Xcode project/scheme, default simulator
- build+install command (the one that syncs web assets)
- deep-link scheme(s) and example URLs
- native-only flows (OAuth sheets, plugin calls) and how to exercise them
- sim-impossible flows (camera, Bluetooth, …) and their stand-ins
- app-specific native hot spots (keyboard config, splash behavior, …)
- validated act/assert idioms for the app's tricky screens
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

## Findings = beads (file immediately, like failing tests)

A finding is anything where the app diverges from the journey docs' expected
behavior, plus a11y gaps and native-shell bugs. Do NOT bury findings in prose
or "note for later" — **file each one as a bead the moment it's confirmed**,
in the same session:

```bash
# CONFIRMED finding (you have root cause or a solid repro) → a fix bead:
br create "fix(<area>): <finding title>" -t bug \
  -d "QA finding (<date>, sim QA): <repro + evidence + journey ref>" \
  --labels qa-finding
# User-facing break or trapped state? Add the blocker label:
#   --labels qa-finding,qa-blocker

# SUSPECTED finding (cause unknown, weak repro) → an investigation bead:
br create "investigate: <symptom>" -t investigation \
  -d "QA finding (<date>, sim QA): <what was observed, repro attempt>" \
  --labels qa-finding
```

**Type + label semantics (they compose, not compete):**

- **Type** = kind of work. `bug` when confirmed — file the fix directly; do
  NOT add a "confirm this" ceremony bead when the QA run already diagnosed
  it. `investigation` when genuinely unconfirmed — its acceptance is
  "reproduce → spawn fix beads or document-and-close".
- **Label** = gating. `qa-blocker` gates the next merge (ac-merge refuses
  while open). `qa-finding` alone = real but shippable, normal priority.
- **Lineage**: fix beads spawned by an investigation carry a typed dep —
  `br dep add <fix-id> <investigation-id> -t discovered-from` — then close
  the investigation. `br dep tree` shows the full issue→fixes trail.
- **Journey-doc drift is NOT a finding** — fix the doc inline during the run.
- A finding that turns out to be intended behavior is resolved by updating
  the journey doc and closing the bead — an expectation change, exactly like
  updating a test.

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
findings_filed: [bead ids created this run, qa-blocker flagged]
a11y_findings: [unlabeled controls discovered via the tree]
perf_observations: [qualitative only — hangs, freezes, leaks]
evidence: [screenshot/video paths]
status: PASS | FAIL
notes: [issues, sim-impossible flows skipped and why, journey-doc drift fixed]
```

## Teardown

- Stop any recordings (`agent-device record stop`, `kill -INT` simctl video).
- `xcrun simctl status_bar booted clear` if you overrode it.
- Reset appearance/content-size if you changed them.
- Delete test entries/data the run created (leave the account as found).
- **Leave the simulator booted** (warm sim = fast next run). Do NOT shutdown
  or erase unless state pollution is suspected.

## Troubleshooting

- **Stale UI / missing recent changes** → web assets weren't synced; rerun the
  app's full build command (never bare `xcodebuild`). Check bundle freshness
  before blaming the code.
- **`SESSION_NOT_FOUND`** → run `agent-device open <bundle-id>` first; a
  session binds device + app.
- **"App bundle is not installed"** → agent-device matched a different sim
  with the same name; rename duplicates and retarget.
- **Snapshot missing an element** → not rendered yet (use `wait`), offscreen
  (scroll), or unlabeled (file a11y finding).
- **Taps type characters instead of tapping** → element was under the
  keyboard; see discipline rule 3.
- **Snapshot returns only keyboard/near-empty tree** → transient; retry.
- **XCUITest runner breaks after Xcode update** → `npm update -g agent-device`,
  re-run `agent-device prepare ios-runner --platform ios`; AXe point-probes
  are the engine-diverse stopgap (`setup.md`).
- **Permission dialog blocks flow unexpectedly** → pre-grant with
  `simctl privacy` in setup, or handle via `agent-device alert`.

## Related files

- `native-shell-checklist.md` — what ONLY the simulator/native shell can catch
- `perf-and-limits.md` — CAN/MISLEADING/CANNOT taxonomy, hardware matrix,
  xctrace recipes, visual regression, automation speed tricks
- `setup.md` — Mac setup, AXe fallback, Linux→Mac remote appendix,
  Appium webview escape hatch (Layer 3)
- `browser-testing/SKILL.md` — Layer 1 (exhaustive DOM coverage)
- Consuming app's `CORE/journeys/` + `CORE/journeys/native.md` — the what
