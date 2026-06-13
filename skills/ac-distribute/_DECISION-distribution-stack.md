# ⚠ TEMP — Distribution Stack Setup (pending, run on Mac)

**Status:** PENDING — Phase 1 runs in a Mac session (ac-qa-simulator bake-off is
DONE, 2026-06-11 — the QA lane this composes with now exists). This directory
becomes the real `ac-distribute` skill in Phase 2; until then this file is the
only content.

**Created:** 2026-06-10 · amended 2026-06-11. Pipeline position: the last mile
of the ac-* pipeline — implement → land/review → merge → **distribute**. This is
the SHIP lane (TestFlight, crash triage, App Store submission), not the QA lane
(that's ac-qa-simulator; the lanes compose — QA proves the build, this ships it).

## Decided

- **Name: `ac-distribute`** (was `app-distribution`). Pipeline stage → ac- prefix
  (precedent: ac-qa-simulator). NOT platform-suffixed (`-ios`): Capacitor
  dual-build means Play Store later, and all three workflows have direct Android
  analogs (internal testing track, Play Console ANRs/reviews, store release).
  Platform handled by an internal **per-workflow gate**, not the name or a
  skill-wide gate — see below.
- **Foundation: the `asc` CLI** (github.com/rorkai/App-Store-Connect-CLI) +
  cherry-picked skills from rorkai/app-store-connect-cli-skills. CLI-first
  (house convention), ASC API-key auth, framework-agnostic (works for
  Capacitor). NOT fastlane (legacy, config-heavy). NOT the Blitz GUI app —
  defer until unsit-app / move-free-app first submissions (its 4 internal-API
  skills automate app-record creation + privacy nutrition labels, which only
  matter for first-time submission; BCA is already live).
- **Two-phase adoption:** use upstream skills for 2–3 real cycles BEFORE
  writing our own wrapper skill. No speculative wrapping.
- **Platform gate is per-workflow, not skill-wide.** Only producing the .ipa
  (app build → xcodebuild archive/export/upload) needs macOS. Everything else —
  TestFlight groups/testers, crash triage, beta feedback, metadata, submission —
  is ASC **API** work and runs anywhere `asc` + the API key exist. Consequence:
  **feedback-triage can run scheduled on the VM**; only testflight-push is a
  Mac-session ritual. (If Mac-boundness ever hurts: Xcode Cloud removes it —
  later-stage move, don't build now.)
- **Secrets routing:** the ASC .p8 key NEVER touches this repo (public) or any
  app repo. Per-machine: asc's own config / keychain on the Mac; secrets.env on
  the VM (OpenRouter-key pattern). `CORE/distribution.md` holds **pointers only**
  (key id, issuer id, where the .p8 lives).
- **Upstream skills are temporary vendor scaffolding:** install into the
  consuming app's `.claude/skills/` (real dirs, BCA first) — NOT into
  agent-compounds (public repo, upstream license, wouldn't pass registry
  conventions). The Phase 2 wrapper replaces them; delete at cleanup.
- **The sim-QA gate is mechanical, not vibes:** testflight-push REQUIRES the
  ac-qa-simulator report artifact (its `journeys_tested` PASS block), fresh
  relative to the commit being shipped — not the session's memory that "QA
  passed".
- **Build-number source of truth:** pick ONE owner + bump convention per app
  BEFORE the first push (package.json version vs Info.plist CFBundleVersion vs
  agvtool is the classic Capacitor footgun — duplicate-build upload errors).
  Record it in the app's `CORE/distribution.md`.

## Phase 1 — Mac session (~30 min)

```bash
# 1. Install the asc CLI (see repo README for current install method)
# 2. Auth [HUMAN STEP]: create an ASC Team API key (App Store Connect →
#    Users & Access → Integrations), download the .p8 once, configure asc with
#    key id / issuer id / .p8 path (per-machine — see Secrets routing above)
# 3. Cherry-pick exactly three upstream skills into BCA's .claude/skills/
#    (not all 23 — context weight; not agent-compounds — vendor scaffolding):
npx skills add rorkai/app-store-connect-cli-skills   # then keep only:
#   asc-testflight-orchestration  (groups, testers, builds, What-to-Test)
#   asc-crash-triage              (TestFlight crashes + beta feedback)
#   asc-release-flow              (submission validation + drive + monitor)
# 4. Validate with one real BCA TestFlight push end-to-end:
#    bump build number → pnpm cap:build → xcodebuild archive/export → upload
#    → wait for processing → What-to-Test from wave git log → distribute
# 5. Record below what worked / what was missing
```

Gate: a sim QA smoke PASS (ac-qa-simulator report artifact) before the upload
step.

## Phase 2 — wrap into a real skill (after 2–3 cycles)

Build `ac-distribute/SKILL.md` here (generic, method-only; per-workflow platform
gates) exposing three workflows — keep them separate, they have different
cadences, risk levels, AND platform requirements:

1. **testflight-push** (weekly-ish, Mac-only): preconditions (sim QA PASS
   artifact, clean wave merge) → version/build bump → app's build command →
   archive/export/upload → processing wait → What-to-Test from git log →
   distribute to cohort group → report block.
2. **feedback-triage** (scheduled, runs anywhere — VM candidate): new crashes +
   beta feedback since last run → cluster → cross-ref recent waves → emit
   backlog candidates. This closes the flywheel loop (Discovery signal → beads)
   — strategically the most important of the three.
3. **store-release** (rare, human-gated at submit, API-driven): submission-health
   checks → metadata/screenshots sync → localized release notes → pre-screen
   with blitzdotdev/app-store-review-agent → submit → monitor.

Consuming apps add `CORE/distribution.md` (mirror of `journeys/native.md`):
ASC app id, bundle id, TestFlight group names, demo account for review,
version conventions + build-number owner, screenshot specs, .p8 pointer.

## Phase 1 results (fill in on the Mac)

```
date / asc version:
auth setup friction:
testflight push: PASS/FAIL  — notes:
skills kept / dropped:
missing operations (candidates for Phase 2 wrapper):
DECISION on Phase 2 scope:
```

## Cleanup

- [ ] After Phase 2 skill exists: delete this file, symlink skill into
      consuming apps, delete vendored upstream skills from apps, add
      `CORE/distribution.md` per app
- [ ] Revisit Blitz GUI app when unsit-app / move-free-app approach first
      App Store submission
