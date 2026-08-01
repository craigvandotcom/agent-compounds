---
name: ac-qa-device
description: Use when QA-ing the NATIVE app build on a device/simulator — full journey validation against the real native shell (keyboard, safe-area, splash, deep links, OAuth sheets, plugin calls, push payloads), appearance matrix, screenshots/video evidence, and perf sanity. The native twin of ac-qa-browser. Triggers on "test native app", "device QA", "simulator QA", "QA on device", "test on iOS", "validate native build", "native smoke test". macOS/iOS Simulator today (Android emulator planned) — see Platform Gate.
---

> **The native twin.** `ac-qa-device` proves the native shell; `ac-qa-browser`
> proves the web shell. Shared conventions — **depth levels, journey reuse,
> findings=beads, the `QA_VALIDATION` report, and the conductor/worker evidence
> protocol** — live in **`_shared/qa-shared.md`**; both twins reference it so they
> stay in lockstep. This file owns the native/simulator specifics only.

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (bundle id, build command,
> simulator target, deep-link scheme, journeys, sim-impossible flows) → read the
> consuming app's `.claude/skills/CORE/SKILL.md`** — journeys live in
> `CORE/journeys/`, native facts in `CORE/journeys/native.md`.
> Do not add app-specific facts to this file — they belong in CORE.

# Device / Simulator QA Skill

Drive the **real native app** in the iOS Simulator with an accessibility-tree
see → act → assert loop. Tooling: **agent-device** (Callstack; XCUITest engine —
sees the full webview tree, @ref targeting, wait/is/find primitives, real HID
taps) + **`xcrun simctl`** (lifecycle, screenshots, video, push payloads, deep
links, permissions, appearance). AXe is the engine-diverse fallback (point-probe
only on webview apps — see `references/setup.md`).

> Tool choice is settled: AXe/XcodeBuildMCP tree dumps are **webview-blind**;
> agent-device's XCUITest snapshot sees everything. Re-evaluate the tool layer
> when Xcode 27's first-party agent automation ships (~fall 2026). Bake-off
> record: `references/incidents.md`.

Android (emulator) support: planned — agent-device drives Android with the same
commands, so the structure (layers, checklist, journey reuse) carries over.

## Platform Gate (read first)

**Everything here requires macOS** (Xcode + simulators). Check before doing
anything: `uname` → if not `Darwin`, **stop** — report that simulator QA needs
a Mac session and hand off. Remote Linux→Mac driving (idb gRPC) exists but is
friction-prone — see `references/setup.md` appendix; don't attempt it ad hoc.

## Layered QA model — what to test where

| Layer | Tool | Coverage | Cost |
| ----- | ---- | -------- | ---- |
| 1. Browser (DOM) | `browser-testing` skill (agent-browser) | Exhaustive: every page, button, state, edge case | Cheap, fast |
| 2. **Simulator (this skill)** | agent-device + simctl | Every journey happy-path with REAL native taps + the native-shell checklist | Slower per action |
| 3. DOM-in-shell | Appium webview context | DOM truth inside the real shell (origin/cookies/storage) | Flaky; escape hatch only (`references/setup.md`) |

For hybrid (Capacitor) apps the webview renders the **same bundle** as the
browser — so exhaustive DOM-matrix coverage stays in Layer 1. Layer 2 proves
what only the native shell can: real touch pipeline, keyboard, safe-area,
splash/cold-start, plugin bridge, system sheets, deep links, lifecycle. The
full list → `references/native-shell-checklist.md`.

**Decision rule:** logic/layout/state bug → Layer 1. "Does the real app work
when really touched" → Layer 2. DOM assertion inside the shell → Layer 3,
sparingly.

## Depth levels

Defined in **`_shared/qa-shared.md`** (smoke / full / exhaustive). Native specifics
per level: **smoke** = build→install→launch→splash→first-paint→auth→primary journey
(run before TestFlight pushes); **full** adds the `references/native-shell-checklist.md` +
appearance spot-checks; **exhaustive** adds the appearance matrix (dark/light ×
2–3 Dynamic Type sizes), deep-link matrix, lifecycle (background/resume), and a
perf sanity pass (`references/perf-and-limits.md`). **Flag-gated journeys need a flag-ON build at every level** — `qa-shared.md` § Flag-gated paths need a flag-ON build; note `NEXT_PUBLIC_*` vars are inlined at build time, so a flag ABSENT from `.env.capacitor` reads as ENABLED and native can ship a path web has disabled.

## Conductor flow (you never drive the simulator yourself)

**You are the conductor.** Journeys are executed by **`device-tester`** subagents —
**strictly one worker at a time, sequential lane only** (simulator concurrency is
flaky and collision-prone — `references/incidents.md`; the win here is context
isolation, not wall-clock). You hold the manifest, verdicts, and report; the worker
holds the accessibility trees, simctl output, and screenshots. Full protocol
(manifest/verdict schemas, completeness rule): `_shared/qa-shared.md` § Conductor /
worker evidence protocol.

1. **Orient + build (yours, once):** Platform Gate check; mint RUN_ID if the
   orchestrator didn't hand one down (contract: `ac-pipeline-builder/references/run-id.md` mint-if-absent
   rule): `RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"`; derive `ARTIFACTS_DIR`
   per `ac-pipeline-builder/references/run-id.md` (prefix `qa-device`); build + install via the app's own
   build command (from CORE — never xcodebuild alone) and boot the app's dedicated
   uniquely-named sim (§Parallel QA below). Workers never build, boot, or shut down
   simulators.
2. **Manifest:** journey list per depth (`surfaces` includes `native`, or
   `proof.required: sim-drive|device-only`), ALL in the `sequential` lane; write
   `$ARTIFACTS_DIR/journeys-manifest.json` BEFORE any spawn (visible `skipped`
   reasons — e.g. sim-impossible flows from CORE).
3. **Dispatch sequentially:** one worker per journey via
   **`references/device-tester-prompt.md`** (dispatched to the `device-tester`
   agent; no model re-pin). Bounded wait per `ac-pipeline-builder/references/delegation-contract.md`;
   a silent worker past the cap = `stall`, re-spawn once, then record.
4. **Collect + aggregate:** manifest ⊖ verdicts check; file beads from verdict
   findings (you, not workers — deduped); write `last_pass` stamps for PASSes;
   emit `QA_VALIDATION` (`platform: ios-simulator`); run
   `_shared/scripts/validate-qa-run.sh "$ARTIFACTS_DIR" --skip-teardown-check`
   (the teardown check is browser-specific; sweep agent-device sessions yourself).
5. **Teardown sweep:** verify no `qa-<app>-*` agent-device sessions remain; shut
   down only sims your app owns, per the ownership rule below.

Everything from **Core loop** down is **worker-side doctrine** — the
device-tester agent reads it; you don't execute it.

## Toolchain

```bash
npm install -g agent-device   # see + act (XCUITest runner; first snapshot builds it)
brew install jq               # JSON parsing for simctl output
# simctl ships with Xcode — nothing to install
```

agent-device matches simulators **by name** — if two sims share a name it can
boot the wrong one. Rename duplicates first (`xcrun simctl rename <udid> "<name (os)>"`).

### Parallel QA on a shared Mac (multiple apps at once)

Several apps may QA on one Mac concurrently. They collide ONLY if they share a
sim, a sim NAME, or an agent-device session. Isolate with three layers:

1. **A dedicated, uniquely-named sim per app** — e.g. `<APP>-QA-iPhone17Pro`.
   NEVER drive the bare "iPhone 17 Pro"; two apps asking for that name grab the
   same device. The app's build script should auto-provision its own sim
   (`simctl create`) and target it **by UDID** (not name) so the build is immune
   to the CoreSimulator name-match race that fires when another app boots/renames
   sims concurrently. (Symptom of the race: `xcodebuild: error: Unable to find a
   device matching…` while that exact name IS in the available list.) The pinned
   sim MUST be **iPhone-class** — never iPad: iPad Stage Manager introduces
   coordinate offsets that misread as app bugs (taps landing wrong, spurious
   `hittable:false`).
2. **A named agent-device session per app** — pass `--session <app>` to EVERY
   `agent-device` call. One daemon per machine multiplexes named sessions;
   `--tenant`/`--state-dir` give full daemon isolation if needed.
3. **Ownership rule (non-negotiable):** only ever rename/boot/shutdown a sim your
   app owns (`<APP>-QA-*`). Hijacking a shared sim mid-session breaks BOTH apps —
   the build (name race) and agent-device (wrong-device match). Incident
   record: `references/incidents.md`.

## Core loop (worker-side — device-tester agents execute this)

```bash
# 0. Build + install — done by the CONDUCTOR before you were spawned; verify the
#    app is installed and the sim booted, then skip to 1. (Standalone human runs
#    without a conductor: build via the app's own build command from CORE.
#    Never xcodebuild alone: hybrid apps must sync web assets first or you
#    QA a stale bundle — the #1 false-result source.)

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

> **Build-stall self-watchdog (step 0).** When the build+install is slow or
> backgrounded, the QA agent polls it on **its own hard-capped loop** — never hand off
> to an unbounded external monitor and wait. An open-ended build monitor + a broken
> resume chain silently eats the whole run (2026-07-03: ~45 min lost, checks time-boxed
> out, recovered only by conductor-side watchdog timers + a SendMessage poke — recipe:
> `background-agent-resume-chains-break-silently`). Bound it: poll on a fixed cadence up
> to N minutes (build-specific, e.g. 15), and if the build hasn't produced an installed
> app by the cap, **report `build-stall` and stop** — do not silently keep waiting. A
> stalled build is a reportable outcome, not a pause.

> **Screenshots / screen recordings as deliverables** (App Review evidence, bug
> repros, demos) → the **`device-testing`** skill owns the capture recipe,
> including the simulator-VFR video gotcha (raw `simctl recordVideo` is
> variable-frame-rate; seek-trimming it plays back as black + a one-frame flash —
> re-encode to CFR with `ffmpeg -vf fps=30` and verify playback, not just
> frames). Don't hand-roll capture here.

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
   not authoritative — verify by outcome (wait/assert), not by flag. But some
   interactions are *reproducibly* un-automatable (backdrop fall-through, etc.) —
   before planning, check the **known automation-limited interactions registry**
   (`references/incidents.md`) and plan those to the boundary + route the real
   step to device, rather than re-discovering the limit at ~60 min/attempt.
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
| Face ID match/no-match | see `references/perf-and-limits.md` (notifyutil pattern) |

## Reusing the app's journeys

The what/how split and journey-drift rule are in **`_shared/qa-shared.md`**.
Native specifics: locate each step's control by its button label in
`snapshot -i` output (not a DOM ref).

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

Full taxonomy + hardware matrix + xctrace recipes → **`references/perf-and-limits.md`**.
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

## Findings = beads

File each finding as a bead the moment it's confirmed — conventions, types, and
labels (`qa-finding` / `qa-blocker`) are in **`_shared/qa-shared.md`**. A native
finding is any divergence from the journey docs' expected behavior, plus a11y
gaps and native-shell bugs. Tag bead descriptions with `device QA`.

### Verdict comment (VERDICT grammar)

When the `QA_VALIDATION` pass completes, the conductor records the ceremony's outcome as
a structured **VERDICT comment** on each bead it validated — `VERDICT: passed:` (journey
PASS), `VERDICT: failed:` (a QA finding), or `VERDICT: blocked:` (infra-flaky / NO-STAMP)
— per the grammar in **`beads-standards` § Verification verdicts**. QA is a *verifier*
ceremony: the conductor writes the verdict from the verdict files (workers/implementers
never do — Goodhart guard). Each filed `qa-finding` bead also carries
`discovered-from: <bead-id|unknown>` linking the escape to the work that introduced it
(`unknown` when it can't be pinned).

## Reporting

Emit the **`QA_VALIDATION`** block from `_shared/qa-shared.md` with:

- `platform: ios-simulator` (or `android-emulator`)
- `target:` sim model + OS version
- `shell_checklist:` items from `references/native-shell-checklist.md`
- `appearance_matrix:` dark/light × Dynamic Type combos
- `perf_observations:` qualitative only — hangs, freezes, leaks

Consumed by `ac-merge` (gates the PR) and `ac-distribute` (the native ship gate
keys on `platform:`).

## Journey stamps (last_pass)

After a journey **PASS**, update its `last_pass` frontmatter block in
`CORE/journeys/<name>.md` — `build`, `sha`, `date`, `platform: ios-simulator`
(or `android-emulator`) — committed together with the QA artifacts in the same
run that emits `QA_VALIDATION`. A **FAIL** never writes a stamp — the bead
trail covers failures; a stamp is proof of success only. Schema + staleness
rule: `_shared/verification-gate.md` §Journey registry.

**Conflict rule:** `last_pass` is last-writer-wins. On a merge conflict, keep
the NEWER stamp (compare `date`, then `build`) — never hand-merge a hybrid
stamp (e.g. one journey's build with another's SHA).

## Infra-flaky drives — NO-STAMP, not FAIL

`hittable:false` false-negatives, coordinate misses, and sim-daemon weirdness
that survive a retry (discipline rule 5) are **executor** failures, not app
failures. Classify the drive as infra-flaky: write **no `last_pass` stamp**
(neither PASS nor FAIL) and file a `qa-infra` bead instead. A flaky gate that
occasionally red-Xs a working app trains gate-skipping — worse than no gate.
Prerequisite the pin depends on: the dedicated sim MUST be **iPhone-class**,
never iPad (Stage Manager coordinate offsets — see "Parallel QA on a shared
Mac" above).

## Teardown

- Stop any recordings (`agent-device record stop`, `kill -INT` simctl video).
- **Close your agent-device session** (`agent-device close --session <app>`) —
  a lingering session stays bound to its device and can collide later
  (incident record: `references/incidents.md`).
- `xcrun simctl status_bar <udid> clear` if you overrode it (target YOUR sim's
  UDID, not `booted` — multiple sims may be booted on a shared Mac).
- Reset appearance/content-size if you changed them.
- Delete test entries/data the run created (leave the account as found).
- **Solo Mac:** leave the sim booted (warm = fast next run). **Shared Mac
  (multiple apps QA'ing):** shut down YOUR OWN sim
  (`xcrun simctl shutdown <udid>`) so booted sims don't pile up — but NEVER touch
  another app's sim. A per-app `sim-clean` teardown command (close session →
  reset overrides → shutdown own sim) is the clean pattern; see the app's build
  script.

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
  are the engine-diverse stopgap (`references/setup.md`).
- **Permission dialog blocks flow unexpectedly** → pre-grant with
  `simctl privacy` in setup, or handle via `agent-device alert`.

## Related files

- `_shared/qa-shared.md` — depth levels, journey reuse, findings=beads, `QA_VALIDATION` schema (shared with the twin)
- `_shared/verification-gate.md` — journey registry schema (`last_pass` stamp fields), staleness rule
- `references/native-shell-checklist.md` — what ONLY the simulator/native shell can catch
- `references/perf-and-limits.md` — CAN/MISLEADING/CANNOT taxonomy, hardware matrix,
  xctrace recipes, visual regression, automation speed tricks
- `references/setup.md` — Mac setup, AXe fallback, Linux→Mac remote appendix,
  Appium webview escape hatch (Layer 3)
- `references/incidents.md` — full incident narratives behind the compressed rules
- `ac-qa-browser/SKILL.md` — the web-shell twin (Layer 1, exhaustive DOM coverage)
- `browser-testing/SKILL.md` — the low-level `agent-browser` mechanics the twin wraps
- Consuming app's `CORE/journeys/` + `CORE/journeys/native.md` — the what
