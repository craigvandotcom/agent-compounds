# ⚠ TEMP — Tool Bake-off (pending, run on Mac)

**Status:** PENDING. Run this protocol in a Claude Code session ON the Mac
with Body Compass as the test app. Record results below, apply the decision
rule, finalize the skill (checklist at bottom), then **delete this file**.

**Created:** 2026-06-10 (VM session, post-research). Expected effort: ~45–60 min.

## What is already decided (do NOT re-litigate)

- **Approach:** accessibility-tree see → act → assert. Settled — ecosystem
  consensus, and the only workable iOS path for webview apps.
- **Transport:** CLI over MCP. Settled — house convention + Sentry's own
  1,350-trial data (+106% tokens for MCP at equal success) + Claude Code
  subagents can't reliably reach MCP servers.
- **simctl stays regardless** (status-bar override, locale, addmedia,
  Dynamic Type, erase are unique to it).

## What this bake-off decides

Which CLI is the skill's **primary driver**. The deciding unknown: **snapshot
fidelity + reliability on a Capacitor WKWebView app** — no published evidence
exists for any candidate; we are first.

| | Candidate | Engine | Pre-bet |
| - | --------- | ------ | ------- |
| A | **AXe + simctl** (current default) | Private AX APIs, nothing in sim | Safe, proven idiom; weakest ergonomics (coordinate math, no waits) |
| B | **agent-device** (Callstack) | XCUITest runner app in sim | Best fit if it works: agent-browser idioms (@refs, wait/is/find), built-in push/permissions/appearance/video/diff, replayable `.ad` scripts, same tool for Android later. Risk: XCTest snapshot serialization on heavy webview trees (`IOS_AX_SNAPSHOT_FAILED`, upstream #701) |
| C | **XcodeBuildMCP CLI mode** (Sentry) | AXe (bundled) | Adds `wait_for_ui`/elementRefs over A — IF those tools are CLI-reachable (unverified); elementRef model is June-2026-new (staleness bugs #445, #408) |

## Setup (Mac, one-time)

```bash
brew install cameroncooke/axe/axe jq                      # A
npm install -g agent-device                               # B (or pnpm add -g)
brew install getsentry/xcodebuildmcp/xcodebuildmcp        # C
xcodebuildmcp doctor                                      # C env check

cd <body-compass-app> && ./scripts/cap-build-run.sh sim   # build + install + launch
UDID=$(xcrun simctl list devices booted -j | jq -r '[.devices[][]|select(.state=="Booted")][0].udid')
```

Pre-flight gate for C: `xcodebuildmcp --help` → confirm whether `snapshot_ui`
and `wait_for_ui` are exposed in the ui-automation CLI workflow. If NOT
CLI-reachable, C is eliminated immediately (MCP-server-only violates the
settled transport decision).

## Benchmark protocol (run per candidate)

Test screens (chosen for webview density + async load — see BCA
`CORE/journeys/`): **login**, **dashboard** (async Supabase data),
**food-entry with expanded ingredient modifiers** (densest tree).

1. **Snapshot fidelity** — dump the tree on each test screen
   (`axe describe-ui` / `agent-device snapshot -i` / `xcodebuildmcp … snapshot_ui`).
   - Are the journey's named controls present with usable labels?
   - Any empty-tree-reported-as-success, serialization failures, or >5s snapshots?
2. **Act reliability** — walk the **auth journey + food-entry happy path**
   (per `CORE/journeys/auth.md`, `food-entry.md`). Count: mis-taps,
   retries, stale-ref/coordinate failures.
3. **Wait/assert ergonomics** — after login, wait for dashboard data to
   render. Count tool calls + wall time to a reliable assert.
4. **Economy** — total tool calls and rough output tokens for step 2.
5. **Stability** — repeat step 2 three times. Count flakes.

## Scoring + decision rule

Score each: snapshot fidelity (PASS/DEGRADED/FAIL), journey completion
(x/3 clean runs), calls-per-journey, subjective friction notes.

- **B passes fidelity + ≥2/3 clean runs → agent-device PRIMARY.**
  A stays documented as engine-diverse fallback + smoke tool (different
  failure class: when an Xcode update breaks the XCUITest runner, AXe
  likely still works, and vice versa). File any webview findings upstream
  (callstack/agent-device — they have no Capacitor coverage; be the first
  data point). Maestro section in setup.md gets demoted (\.ad replay
  covers regression artifacts).
- **B fails fidelity → A stays PRIMARY** (+ C's primitives if C passed its
  gate and beats A on calls-per-journey). File the failure upstream anyway.
- **Tie/unclear → A stays PRIMARY** (simplest, settled), re-run bake-off
  after agent-device's #701 fallback lands.

## Results (fill in on the Mac)

```
date / xcode / ios-runtime / sim model:
A axe:           fidelity=      runs=  /3   calls≈      notes:
B agent-device:  fidelity=      runs=  /3   calls≈      notes:
C xbm-cli:       gate(CLI-reachable)=Y/N  fidelity=  runs= /3  calls≈  notes:
DECISION:
```

## Related — while on the Mac (NOT part of the bake-off)

Optional follow-up, separate decision: the **App Store Connect skill pack**
(`npx skills add rorkai/app-store-connect-cli-skills` + the `asc` CLI) covers
the distribution half this skill doesn't — TestFlight orchestration, crash
triage, release flow, build/upload, store screenshots. Standalone (the Blitz
GUI app is NOT required; only its 4 internal-API skills need it — relevant
for first-time submissions of unsit/move-free, not BCA). Cherry-pick
`asc-testflight-orchestration`, `asc-crash-triage`, `asc-release-flow` first
rather than all 23. Note: its `asc-shots-pipeline` drives the sim with AXe
(production evidence for candidate A) and may supersede the browser-based
`app-store-screenshots` skill — evaluate at next screenshot refresh.

## Finalization checklist (after deciding)

- [ ] SKILL.md: rewrite Toolchain + Core loop for the winner; remove the temp banner
- [ ] setup.md: winner first, losers to fallback/appendix; prune dead caveats
- [ ] BCA `CORE/journeys/native.md`: add any app facts learned (snapshot quirks, unlabeled controls found)
- [ ] File upstream issues (agent-device webview findings; XcodeBuildMCP if #408-class hit)
- [ ] **Delete this file**; commit agent-compounds + BCA with the decision in the message
