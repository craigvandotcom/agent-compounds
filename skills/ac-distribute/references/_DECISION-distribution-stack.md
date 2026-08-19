# Distribution + Triage — Architecture & Setup Record

**Status (2026-06-15):** Phase 2 LANDED. After 5 live headless ship cycles on
art-still (builds 2→6), two decisions are ratified (below). `ac-distribute/SKILL.md`
is now written (ship-OUT lane); the feedback leg is SPLIT OUT into a new sibling
skill **`ac-triage`** (signal-IN lane). Sentry wiring is teed up to a single human
gate (create the Sentry project). The historical Phase-1 plan + results are retained
below as the record.

**Created:** 2026-06-10 · amended 2026-06-11 · re-factored 2026-06-15. Pipeline
position: the last mile of the ac-* pipeline — implement → land/review → merge →
**distribute**. ac-distribute is the SHIP lane; it composes with `ac-qa-device`
(QA proves the build) upstream and `ac-triage` (pulls real-user signal back to beads)
as its inbound counterpart.

---

## Decision update (2026-06-15) — RATIFIED after 5 live cycles

### 1. KEEP fastlane (hybrid) — do NOT rip it out

The original "NOT fastlane, use the `asc` CLI" stance predated discovering that
art-still already standardized on fastlane. After 5 headless cycles (fastlane
**match** git-stored signing + Admin ASC API key, **no Apple 2FA at any point**),
the lane is proven. Ratified: **fastlane owns the BUILD mile (archive → sign →
upload); the ASC API owns the read + submit miles.** They are NOT competitors —
they cover different miles. `ac-distribute` is therefore a thin wrapper over
**whatever each app already uses** for the build (fastlane here; could differ for a
future app). Rewriting a working lane to the asc-CLI is churn for zero user value.
The `asc` CLI / upstream rorkai skills are NOT adopted; revisit only if a future app
arrives with no lane of its own.

### 2. SPLIT feedback-triage OUT into a new `ac-triage` skill

The old doc's "feedback-triage" conflated a *capability* (triage operational signal
→ beads) with *one source* (ASC TestFlight feedback). That work is **inbound** (pull
signal), continuous/scheduled, **headless-anywhere**, **source-agnostic** (Sentry,
Supabase, ASC, PostHog), and **cross-app** (works for web-only apps too) — orthogonal
to ac-distribute's **outbound**, event-driven, Mac-bound shipping. So it gets its own
skill, **`ac-triage`**: it FETCHES + clusters machine signal, then routes each finding
to **`ac-bead-capture`** (which already classifies / routes-to-repo / dedupes). It is
the *machine-signal sibling* to ac-bead-capture's *human-signal intake*. ASC beta
feedback is merely ac-triage's ASC source adapter; **Sentry is source #1**.

### 3. `ac-distribute` scope = ship OUT only

Two workflows: **testflight-push** (≈ built — art-still's `pnpm ship:testflight`) and
**store-release** (future; ASC API; human-gated at submit). feedback-triage REMOVED
from this skill (now `ac-triage`).

## Decided

- **Name: `ac-distribute`** (was `app-distribution`). Pipeline stage → ac- prefix
  (precedent: ac-qa-device). NOT platform-suffixed (`-ios`): Capacitor
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
  ac-qa-device report artifact (its `journeys_tested` PASS block), fresh
  relative to the commit being shipped — not the session's memory that "QA
  passed".
- **Build-number source of truth:** pick ONE owner + bump convention per app
  BEFORE the first push (package.json version vs Info.plist CFBundleVersion vs
  agvtool is the classic Capacitor footgun — duplicate-build upload errors).
  Record it in the app's `CORE/distribution.md`.

## Phase 1 — Mac session (~30 min)

```bash
# 1. Install the asc CLI:
brew install asc          # homebrew-core formula, MIT, zero deps, bottled
# Prefer this over the project's `curl -fsSL https://asccli.sh/install | bash`:
# homebrew-core is reviewed and the bottle is prebuilt.
# Formula source: github.com/rorkai/App-Store-Connect-CLI
# 2. Auth — NOT a human step. The Team Admin key already exists and the .p8 is
#    already on this machine; art-still has used it headlessly since 2026-06-13.
#    A team key authorizes every app in DYNQVB8R49, so it covers BCA:
asc auth login --name bca \
  --key-id 4BDSRVV64D \
  --issuer-id 7c951934-341a-4a7a-88b4-7714eafb1693 \
  --private-key ~/.appstoreconnect/private_keys/AuthKey_4BDSRVV64D.p8 \
  --network
#    Stores in the system keychain by default. NEVER pass --local: that writes
#    ./.asc/config.json into this repo, which is public. The .p8 stays outside
#    the repo. Only creating a NEW key would be a human step.
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

Gate: a sim QA smoke PASS (ac-qa-device report artifact) before the upload
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

## Phase 1 results (cycle 1 — art-still-app, 2026-06-13)

```
date / tooling:  2026-06-13. fastlane 2.236.1 on Homebrew Ruby 4.0 (system Ruby 2.6 too old).
auth setup:      ASC Admin API key (key 4BDSRVV64D, issuer 7c951934-…). HEADLESS — no Apple
                 2FA at any point. match created the distribution cert + app-store profile
                 via the API key and stored them in a private git repo (neometa-ios-signing).
testflight push: PASS — build 2 (v1.0, App 6778303129) uploaded to closed TestFlight.
```

**MAJOR DEVIATION from the "Foundation" decision — reconcile in Phase 2:** this cycle did
NOT use the `asc` CLI or the upstream rorkai skills. art-still-app already carried a fastlane
lane from its own rrk.1 work (`ios/App/fastlane/`), so the fastest validated path was to
**fix + use that fastlane lane**, not introduce a second tool. The doc's "NOT fastlane"
stance predates discovering an app already standardized on fastlane. **Phase-2 decision
needed:** standardize the org on `asc`-CLI and rip fastlane out of art-still, OR keep
fastlane where it already exists and scope `ac-distribute` as a thin wrapper over *whatever
each app already uses*. Recommendation: the latter — fastlane match's git-stored signing is
genuinely good, and rewriting a working lane to asc-CLI is churn for no user value.

**Gaps fixed in the rrk.1 fastlane scaffolding (all real, would have failed CI):**
1. The lane never built `app_store_connect_api_key` — would have fallen back to Apple-ID/2FA.
2. `APP_STORE_CONNECT_API_KEY_PATH` env name auto-maps onto `match.api_key_path` →
   "Unresolved conflict between api_key_path and api_key". Renamed to custom `ASC_API_KEY_*`.
3. `codesign --verify` ran on the `.xcarchive` container ("not signed at all") instead of the
   signed `.app` inside it.
4. The Sentry dSYM gate hard-failed with no Sentry creds → made conditional.

**missing operations (Phase-2 wrapper candidates):** web-build+cap-sync is a manual
precondition (lane assumes assets pre-synced; and prod-env injection is needed because
`.env.local` is backend-less); build-number bump is manual; What-to-Test from git log not
wired; feedback-triage (crashes/beta feedback → beads) not built.

**remaining for CI tag-push (art-still):** GitHub secrets `MATCH_GIT_BASIC_AUTHORIZATION`
(PAT), `APPLE_ID`, and Sentry trio. 7 of 10 secrets already set.

Per-app facts recorded in art-still: `.claude/skills/CORE/distribution.md`.

## Cleanup

- [ ] After Phase 2 skill exists: delete this file, symlink skill into
      consuming apps, delete vendored upstream skills from apps, add
      `CORE/distribution.md` per app
- [ ] Revisit Blitz GUI app when unsit-app / move-free-app approach first
      App Store submission
