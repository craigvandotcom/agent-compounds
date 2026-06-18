# Shared QA methodology (ac-qa-device + ac-qa-browser)

Platform-agnostic conventions for the QA twins. Each twin owns its toolchain,
core loop, and shell checklist; this file owns what they share so the two stay
in lockstep. Reference it from a twin as `_shared/qa-shared.md`.

The split:

| Plane | Owner |
| ----- | ----- |
| Native shell (safe-area, splash, plugins, OAuth sheets, keyboard, deep links, lifecycle) | **`ac-qa-device`** (`native-shell-checklist.md`) |
| Web shell (CORS, SPA routing, storage, service worker, console, responsive) | **`ac-qa-browser`** (`web-shell-checklist.md`) |
| Depth levels · journey reuse · findings=beads · report schema | **this file** |

For hybrid (Capacitor) apps the device webview renders the **same bundle** as the
browser, so visual/DOM-matrix coverage stays cheap in the browser (`ac-qa-browser`);
the device twin proves only what the native shell adds. Don't QA the same DOM logic
twice — route by plane.

## Depth levels

- **smoke** — build/serve, launch, first-paint, auth, primary journey. Run after
  changes that touch the relevant plane, before a ship gate.
- **full** — every journey in the app's `CORE/journeys/` walked + the twin's shell
  checklist + appearance spot-checks.
- **exhaustive** — full + every screen/control reachable, appearance matrix
  (dark/light × 2–3 type sizes), responsive/lifecycle matrix, perf sanity. Release-grade.

## Reusing the app's journeys

The app's `CORE/journeys/*.md` files are the **what** (flows, exact button labels,
checkpoints, edge cases). A QA twin is the **how**. To run a journey: follow its
happy path step-by-step, locating each step's control in the latest snapshot
(accessibility tree for device, DOM for browser) instead of trusting a stale ref.

**Journey docs drift.** When a label/flow in the doc doesn't match the live tree,
trust the tree, complete the journey via the real UI, and fix the doc as part of
the pass (that's a finding's resolution, not a blocker).

## Findings = beads (file immediately, like failing tests)

A finding is anything where the app diverges from the journey docs' expected
behavior, plus a11y gaps and shell bugs. Do NOT bury findings in prose or
"note for later" — **file each as a bead the moment it's confirmed**, same session:

```bash
# CONFIRMED finding (root cause or solid repro) → a fix bead:
br create "fix(<area>): <finding title>" -t bug \
  -d "QA finding (<date>, <device|browser> QA): <repro + evidence + journey ref>" \
  --labels qa-finding
# User-facing break or trapped state? Add the blocker label:  --labels qa-finding,qa-blocker

# SUSPECTED finding (cause unknown, weak repro) → an investigation bead:
br create "investigate: <symptom>" -t investigation \
  -d "QA finding (<date>, <device|browser> QA): <observed + repro attempt>" \
  --labels qa-finding
```

**Type + label semantics (compose, not compete):**

- **Type** = kind of work. `bug` when confirmed — file the fix directly; no
  "confirm this" ceremony bead when the run already diagnosed it. `investigation`
  when genuinely unconfirmed — acceptance is "reproduce → spawn fix beads or
  document-and-close".
- **Label** = gating. `qa-blocker` gates the next merge (`ac-merge` refuses while
  open). `qa-finding` alone = real but shippable.
- **Lineage**: fix beads spawned by an investigation carry a typed dep —
  `br dep add <fix-id> <investigation-id> -t discovered-from` — then close the
  investigation.
- **Journey-doc drift is NOT a finding** — fix the doc inline during the run.
- A finding that turns out to be intended behavior is resolved by updating the
  journey doc and closing the bead (an expectation change, like updating a test).

## Reporting — the QA_VALIDATION block

Both twins emit the same block; the `platform:` field disambiguates which plane
was proven. Consumed by `ac-merge` (gates the PR) and `ac-distribute` (gates the
ship — it keys on `platform:` so a browser PASS can't satisfy a native ship gate).

```markdown
QA_VALIDATION:
platform: ios-simulator | android-emulator | browser-local | browser-preview | browser-production
target: [sim/emulator model + OS  |  browser + viewport]
app_build: [how built/served — command + branch/commit]
depth: smoke | full | exhaustive
journeys_tested: [list, with PASS/FAIL each]
shell_checklist: [items checked, PASS/FAIL — native-shell-checklist.md | web-shell-checklist.md]
appearance_matrix: [combos checked]
findings_filed: [bead ids created this run, qa-blocker flagged]
a11y_findings: [unlabeled controls / violations discovered]
perf_observations: [qualitative only — hangs, freezes, leaks, layout shift]
evidence: [screenshot/video paths]
status: PASS | FAIL
notes: [issues, platform-impossible flows skipped and why, journey-doc drift fixed]
```

> History: this block was `SIM_QA_VALIDATION` (device-only) until the browser twin
> landed (2026-06-18). The `platform:` field is the load-bearing addition — ship
> gates predicate on it.
