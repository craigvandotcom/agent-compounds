---
name: device-testing
description: Use for ad-hoc (not pipeline-gated) native iOS-simulator work — driving the real app with agent-device to capture screenshots or record screen video. Triggers on "record the screen", "screenshot the app" (native simulator capture), "capture the simulator", "drive the simulator", "record a flow", "grab a screenshot on device". NOT for structured native QA / ac-merge gating (ac-qa-device), web capture (browser-testing), landing-page screenshots (screenshot-refresh), or store listing assets (app-store-screenshots).
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (bundle id, build command,
> simulator target, login flow, where a screen lives) → read this app's
> `.claude/skills/CORE/SKILL.md`** (native facts in `CORE/journeys/native.md`).
> Do not add app-specific facts to this file — they belong in CORE.

# Device Testing & Capture Skill

Drive the **real native app** in the iOS Simulator with `agent-device`, and turn
a flow into a **clean screenshot or screen recording** you can hand off (App
Store review evidence, a bug repro clip, a demo, a marketing video).

The engine and the see→act→assert loop are the same as the pipeline QA skill —
this skill is the **ad-hoc entry point** and owns the **capture recipe** (the
part that bites you if you wing it). For the full driving reference (snapshot
discipline, keyboard traps, parallel-sim isolation, setup/install) see
**`ac-qa-device/SKILL.md`** + **`ac-qa-device/references/setup.md`**. Don't duplicate those
here.

## When to use

- "Record a screen recording of <flow>" — App Review evidence, demo, bug repro
- "Screenshot the <screen>" on the real native shell
- A quick ad-hoc drive of the native app (no QA report needed)

## When NOT to use

- Structured native QA (depth levels, `QA_VALIDATION`, native-shell checklist,
  ac-merge gating) → **`ac-qa-device`**
- Web / browser capture or testing → **`browser-testing`** (agent-browser drives
  Chromium; it can emulate a phone viewport but it is NOT the native shell)
- Unit / integration / E2E code tests → **`testing`**

## Toolchain

```bash
npm install -g agent-device   # drive: see + act (XCUITest; sees the webview tree)
# xcrun simctl ships with Xcode — screenshots + video + lifecycle
# ffmpeg (brew install ffmpeg) — required to make video playable (see Video)
```

Resolve the sim **UDID** once and target capture by UDID, never the bare
`booted` / a shared sim name (parallel QA on one Mac collides — see
`ac-qa-device` § Parallel QA):

```bash
UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
```

## Drive (quick loop — full reference in ac-qa-device)

```bash
# Build+install via the APP's own build command (from CORE) — never xcodebuild
# alone (hybrid apps must sync web assets first or you capture a stale bundle).
agent-device open <bundle-id> --platform ios --device "<sim-name>" --session <app>
agent-device snapshot -i --session <app>          # SEE — @refs renumber every snapshot
agent-device click @e<N> --session <app>          # ACT — target the LATEST ref
agent-device fill @e<N> "text" --session <app>
```

- **Refs renumber on every snapshot** — re-snapshot after any navigation; act on
  the newest ref only.
- **System sheets are outside the app tree.** A `SFSafariViewController` (in-app
  browser via `Browser.open`), the share sheet, OAuth sheets, etc. make
  `snapshot -i` go **sparse (≈2 nodes)** — agent-device can't see into them. Use
  a **screenshot as visual truth** there, and escape by tapping known coordinates
  or `agent-device open … --relaunch` (relaunch usually keeps the login session).

## Screenshots

```bash
xcrun simctl io "$UDID" screenshot out.png    # instant; the visual truth
```

- Use a screenshot to *visually confirm* a state the tree already proved (or to
  see inside a system sheet the tree can't). Don't drive off pixels — drive off
  the tree.
- **Clean status bar** for hero/marketing/evidence shots:
  ```bash
  xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4
  # ... capture ...
  xcrun simctl status_bar "$UDID" clear
  ```
- Sim screenshots are tall (~2622px). Reading many in one session can exhaust the
  image-read budget late in the session — capture sparingly, crop if you only
  need a region.

## Video — the VFR-safe recipe (read before recording)

### Record

```bash
xcrun simctl io "$UDID" recordVideo --codec h264 --force raw.mov >/dev/null 2>&1 &
RPID=$!
#   ... drive the flow with deliberate pacing (see Pacing) ...
kill -INT "$RPID"                              # SIGINT, NOT kill -9
until ! kill -0 "$RPID" 2>/dev/null; do sleep 1; done   # wait for the .mov to finalize
```

- **Stop with `kill -INT`.** A `kill -9` leaves the `.mov` unfinalized/corrupt.
  Always wait for the process to exit before touching the file.

### THE GOTCHA — simulator recordings are variable-frame-rate (VFR)

A static screen emits **no new frames**, so the raw `.mov` is sparse. Two traps:

1. `ffprobe` `duration` is wall-clock, but the encoded frames are few and
   unevenly spaced.
2. **Seeking/trimming the raw VFR with `ffmpeg -ss` mangles playback** — you get
   a black lead-in, a single-frame *flash* of the real content, then the last
   static frame filling the rest. It looks fine if you only extract frames
   (because `-ss` seeking lands on real frames), but it **plays broken**. This is
   the #1 "the clip makes no sense" failure.

### THE FIX — re-encode to constant frame rate; never seek-trim the raw

```bash
ffmpeg -y -i raw.mov -vf "fps=30" -c:v libx264 -pix_fmt yuv420p \
  -movflags +faststart -an evidence.mp4
```

- `-vf "fps=30"` resamples to constant 30 fps (duplicates frames over the static
  holds) → smooth playback, no flash/black.
- `-pix_fmt yuv420p` + `-movflags +faststart` → plays in QuickTime and uploads
  cleanly to App Store Connect Resolution Center / stores.
- `-an` — sim recordings have no audio.
- **If you must trim, trim the CFR `.mp4` (after re-encode), never the raw VFR
  `.mov`.**

### Pacing — you control the holds with sleeps, not editing

agent-device taps and snapshots are **invisible to the recording** — only what's
on the device screen is captured. So pace the clip live:

1. **Pre-navigate to the START state BEFORE you start recording.** Record only
   the meaningful segment, not the login + menu hunting.
2. Start recording, then `sleep` between taps to hold each screen long enough to
   read (~3–5 s per key screen). A mid-flow `snapshot` to fetch the next ref is
   free — it doesn't show on screen and naturally extends the hold.

```bash
# Example: hold screen A ~4s, transition, hold screen B ~5s
xcrun simctl io "$UDID" recordVideo --codec h264 --force raw.mov >/dev/null 2>&1 & RPID=$!
sleep 1.5                                              # show start screen
agent-device click @<trigger> --session <app>         # → screen A
sleep 4                                                # hold A
agent-device click @<next> --session <app>            # → screen B
sleep 5                                                # hold B
kill -INT "$RPID"; until ! kill -0 "$RPID" 2>/dev/null; do sleep 1; done
```

### VERIFY PLAYBACK, not just frames

A frame-extraction spot-check **passes on a clip that plays broken** (the VFR
trap). After the CFR re-encode, confirm both:

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate,nb_frames \
  -show_entries format=duration -of default=noprint_wrappers=1 evidence.mp4
# sanity: nb_frames ≈ duration × fps  (e.g. ~10.5s × 30 ≈ ~314 frames, not ~12)
ffmpeg -y -ss 0 -i evidence.mp4 -frames:v 1 f0.png    # first frame must NOT be black
```

Then eyeball f0 + a couple of mid/late frames to confirm the timeline reads:
start screen → held content → end screen.

## Teardown

- **Stop any running recording** (`kill -INT` the simctl PID; wait for exit).
- Leave the sim **warm** if more capture is likely (cold boot is 20–60 s); else
  tear down THIS app's QA sim via its build script (e.g. `cap-build-run.sh
  sim-clean`) — only ever touch a sim your app owns (see `ac-qa-device`
  ownership rule).
- Clean up scratch `.mov`/frame `.png`s; keep only the final deliverable.

## App-specific bits live in CORE

Which screen to capture, how to reach it (entry flow, gating), the build command,
the sim name, and login credentials are **app facts** — read the consuming app's
`CORE/SKILL.md` and `CORE/journeys/`. This skill is the **how** (drive + capture
mechanics); CORE is the **what**.

## Worked example — App Review 3.1.2(c) EULA-in-purchase-flow evidence

Goal: a clip proving the subscription paywall shows the Terms of Use (EULA) link
and that the link works. Pattern that produced a clean 10.5 s clip:

1. Build+install (app's build command) → boot sim → `agent-device open … --session`.
2. Drive to the gated screen (log in → trigger the paywall) — **before** recording.
3. Start recording; hold the paywall ~4 s; tap the EULA link → the Terms page
   loads (SafariViewController — tree goes sparse, that's expected); hold ~5 s.
4. `kill -INT` the recorder; re-encode with `-vf fps=30` (CFR); verify playback.
5. Deliver the `.mp4` (+ a still). Output: paywall (disclosure + EULA + Privacy)
   → functional Terms page, smooth, no flash.
