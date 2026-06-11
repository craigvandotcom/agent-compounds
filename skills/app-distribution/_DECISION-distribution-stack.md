# ⚠ TEMP — Distribution Stack Setup (pending, run on Mac)

**Status:** PENDING — Phase 1 runs in a Mac session (after, or independent of,
the ac-qa-simulator bake-off). This directory becomes the real `app-distribution`
skill in Phase 2; until then this file is the only content.

**Created:** 2026-06-10. Pipeline position: downstream of ac-qa-simulator —
this is the SHIP lane (TestFlight, crash triage, App Store submission),
not the QA lane.

## Decided

- **Foundation: the `asc` CLI** (github.com/rorkai/App-Store-Connect-CLI) +
  cherry-picked skills from rorkai/app-store-connect-cli-skills. CLI-first
  (house convention), ASC API-key auth, framework-agnostic (works for
  Capacitor). NOT fastlane (legacy, config-heavy). NOT the Blitz GUI app —
  defer until unsit-app / move-free-app first submissions (its 4 internal-API
  skills automate app-record creation + privacy nutrition labels, which only
  matter for first-time submission; BCA is already live).
- **Two-phase adoption:** use upstream skills for 2–3 real cycles BEFORE
  writing our own wrapper skill. No speculative wrapping.

## Phase 1 — Mac session (~30 min)

```bash
# 1. Install the asc CLI (see repo README for current install method)
# 2. Auth: create an ASC Team API key (App Store Connect → Users & Access →
#    Integrations), download the .p8 once, configure asc with key id /
#    issuer id / .p8 path
# 3. Cherry-pick exactly three upstream skills (not all 23 — context weight):
npx skills add rorkai/app-store-connect-cli-skills   # then keep only:
#   asc-testflight-orchestration  (groups, testers, builds, What-to-Test)
#   asc-crash-triage              (TestFlight crashes + beta feedback)
#   asc-release-flow              (submission validation + drive + monitor)
# 4. Validate with one real BCA TestFlight push end-to-end:
#    bump build number → pnpm cap:build → xcodebuild archive/export → upload
#    → wait for processing → What-to-Test from wave git log → distribute
# 5. Record below what worked / what was missing
```

Gate: a sim QA smoke PASS before the upload step (the lanes compose:
ac-qa-simulator proves the build, this lane ships it).

## Phase 2 — wrap into a real skill (after 2–3 cycles)

Build `app-distribution/SKILL.md` here (generic, method-only) exposing three
workflows — keep them separate, they have different cadences and risk levels:

1. **testflight-push** (weekly-ish): preconditions (sim QA PASS, clean wave
   merge) → version/build bump → app's build command → archive/export/upload
   → processing wait → What-to-Test from git log → distribute to cohort group
   → report block.
2. **feedback-triage** (per Mac session or scheduled): new crashes + beta
   feedback since last run → cluster → cross-ref recent waves → emit backlog
   candidates. This closes the flywheel loop (Discovery signal → beads).
3. **store-release** (rare, human-gated at submit): submission-health checks
   → metadata/screenshots sync → localized release notes → pre-screen with
   blitzdotdev/app-store-review-agent → submit → monitor.

Consuming apps add `CORE/distribution.md` (mirror of `journeys/native.md`):
ASC app id, bundle id, TestFlight group names, demo account for review,
version conventions, screenshot specs.

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
      consuming apps, add `CORE/distribution.md` per app
- [ ] Revisit Blitz GUI app when unsit-app / move-free-app approach first
      App Store submission
