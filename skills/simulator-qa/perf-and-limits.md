# Simulator Performance & Limits — CAN / MISLEADING / CANNOT

The simulator runs your code on the host Mac's CPU with a translated Metal
layer, Mac-sized RAM, no thermal envelope, and no jetsam. That makes it
**authoritative for correctness** and **a liar about performance**. This file
is the taxonomy of which signals to trust.

## Taxonomy

| Signal | Verdict | Why / how |
| ------ | ------- | --------- |
| Layout, rendering correctness, dark mode, Dynamic Type, locale, RTL | **CAN** | Sim is authoritative for layout logic |
| Functional flows, navigation, state, crashes | **CAN** | |
| Screenshots (`simctl io screenshot`) | **CAN** | Pixel-exact for the simulated device's logical resolution |
| Memory **leaks** (Leaks/Allocations) | **CAN** | Retain cycles are code logic; growth patterns valid. Footprint/jetsam NOT |
| Main-thread hangs (existence) | **CAN (qualitative)** | Host Mac is faster than any iPhone ⇒ a hang visible on sim is near-certainly worse on device. Absence proves little |
| Time Profiler hotspot *ranking* | **MISLEADING-but-useful** | "Where is CPU going" transfers; absolute ms are host-Mac numbers |
| Launch time | **MISLEADING** | Gross (≥2x) same-machine regressions are a signal; fine deltas and absolutes are noise |
| FPS, animation smoothness, hitch counts/ratios | **MISLEADING → never report** | Different render path, host GPU. Device-only metrics |
| Video frame-timing analysis | **MISLEADING** | `recordVideo` is variable-frame-rate; conflates app jank with recorder + host load |
| GPU/Metal throughput | **CANNOT** | Translation layer onto Mac GPU, different feature set |
| Thermal, battery, real memory pressure / jetsam | **CANNOT** | |

**Reporting rule:** perf findings from sim are *qualitative*: "main thread
blocks ~Ns on X", "memory grows unbounded doing Y", "visible multi-second
freeze during Z". Never numbers like fps or hitch-time-ratio.

## Hardware/feature matrix (Xcode 16–26 era)

| Feature | Sim status | Workaround |
| ------- | ---------- | ---------- |
| **Camera** | **NOT available** (no webcam passthrough; `AVCaptureDevice` returns nothing) | Photo-library picker works (stock photos; drag images onto sim to add). Real capture ⇒ physical device. RocketSim/iCimulator can inject a fake feed if essential |
| Push notifications | Payload simulation works: `simctl push booted <bundle> payload.apns`. Real APNs *sandbox* pushes also work on Apple-silicon Macs (sim gets a real token) | Rich push, actions, tap-routing all testable |
| Face ID / Touch ID | Simulated | Enroll: `xcrun simctl spawn booted notifyutil -s com.apple.BiometricKit.enrollmentChanged 1 -p com.apple.BiometricKit.enrollmentChanged`; match/no-match via `com.apple.BiometricKit_Sim.pearl.match` / `.nomatch` posts. Secure-Enclave-backed keychain flows may still differ |
| In-app purchase | **StoreKit Testing works fully** (.storekit config file in scheme: purchases, renewals, refunds, failure injection) | App Store *sandbox* (real Apple ID) is device-only |
| HealthKit | Available; empty by default | Seed via Health app / XCTHealthKit |
| GPS | Simulated: `simctl location set/run`, GPX routes | Accuracy behavior differs |
| Background fetch / BGTask | Xcode Debug menu simulation only | Real scheduling/budgets ⇒ device |
| Network throttling | Network Link Conditioner on the HOST throttles sim traffic | Valid for slow-network UX QA |
| Haptics | Silent no-op | Assert call-sites only |
| Bluetooth, ARKit, App Attest/DeviceCheck, Apple Pay, phone/SMS | **CANNOT** | Mock seams; device only |

## xctrace recipes (Instruments CLI against the sim)

```bash
xcrun xctrace list devices                       # sims listed with UDIDs

xcrun xctrace record \
  --device <SIM-UDID> \
  --template 'Time Profiler' \                   # also: Allocations, Leaks, CPU Profiler
  --attach <pid-or-process-name> \               # or --launch -- <bundle-id>
  --time-limit 30s \
  --output /tmp/run.trace

# Parse programmatically: export tables to XML
xcrun xctrace export --input /tmp/run.trace --toc
xcrun xctrace export --input /tmp/run.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' \
  --output /tmp/profile.xml
```

Works on sim: Time Profiler (incl. hang lanes), CPU Profiler, Allocations,
Leaks, Network, os_signpost. Device-only/meaningless on sim: GPU/Metal,
power/thermal, Animation Hitches (attaches but numbers reflect macOS render
path). XML exports are huge for long traces — keep `--time-limit` short.

### XCTest perf metrics validity on sim

`XCTClockMetric`/`XCTCPUMetric`: relative same-machine regressions only.
`XCTApplicationLaunchMetric`: coarse relative signal. `XCTMemoryMetric`:
**broken for XCUIApplication targets (reads zero)**. `XCTOSSignpostMetric`
hitch sub-metrics (hitch count/ratio, frame rate): **device-only** — sim
reports Duration only.

## Visual regression (screenshot diffing)

- Same machine + same sim model + same OS runtime + same Xcode → effectively
  deterministic run-to-run. **Cross-machine/runtime baselines drift** (Apple
  silicon vs Intel, runtime versions, host font fallback) — pin one
  environment per baseline set.
- Standard determinism prep: `simctl status_bar override --time 9:41 ...`,
  disable app animations (launch arg / `UIView.setAnimationsEnabled(false)`),
  freeze dynamic data (dates, randomness), fixed appearance + content size.
- Tolerant compare (ImageMagick): `magick compare -metric AE -fuzz 2% a.png b.png diff.png`
  — small fuzz absorbs anti-aliasing drift.

## Automation speed & warm-sim tricks

- Cold sim boot: 20–60s (first boot of a runtime slowest). **Keep one warm sim
  booted across runs — single biggest win.** Wait on `simctl bootstatus`, not
  the Booted flag.
- Per-action latency: AXe/idb-class taps are fast (tens of ms); the cost is in
  tree snapshots on element-dense screens (can hit seconds). Snapshot
  *targeted*, act in batches per screen.
- Planning number: a ~50-interaction journey pass on a warm sim ≈ 2–5 min.
- `simctl clone`: boot source sim to home screen once, shut down, clone —
  clones skip most of cold boot. Parallel sims (3–6 comfortable on a modern
  Mac) for matrix runs.
- Disable animations in the app under test where possible — cuts both wait
  time and tap-mis-land flakes.
