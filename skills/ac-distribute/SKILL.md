---
name: ac-distribute
description: Use to SHIP a built app out the door — push a signed build to TestFlight (closed beta), or submit a release to the App Store. The outbound last mile of the ac-* pipeline (implement → land → review → merge → QA → DISTRIBUTE). Triggers on "ship to testflight", "push a build", "release to app store", "cut a build", "distribute the app", "submit for review". For pulling crashes/feedback BACK IN → ac-triage. For proving the build first → ac-qa-device.
---

> **Generic skill — method only, zero app facts.** Symlinked from agent-compounds and
> shared across consuming apps. App specifics — bundle id, ASC app id, build command,
> signing setup, version/build-number owner, TestFlight group, demo account, the exact
> ship command — live in the consuming app's **`.claude/skills/CORE/distribution.md`**.
> Read that FIRST. Do not add app facts here.

# ac-distribute — the ship-OUT lane

**You are shipping a build to users.** Two workflows, different cadence/risk/platform:

| Workflow            | Cadence      | Platform           | Risk / gate                              |
| ------------------- | ------------ | ------------------ | ---------------------------------------- |
| **testflight-push** | per wave-ish | **macOS** (builds) | sim-QA PASS artifact + clean merge       |
| **store-release**   | rare         | ASC API (anywhere) | human-gated at submit                    |

**Scope boundary:** this skill gets the artifact OUT. It does NOT pull crashes/feedback
back in — that's **`ac-triage`** (inbound, headless, source-agnostic). It does NOT prove
the build — that's **`ac-qa-device`** (run it first; this gates on its report).

**Foundation (Decision 2026-06-15):** thin wrapper over **whatever the app already uses
for the build mile**. art-still uses **fastlane** (match git-stored signing + Admin ASC
API key → fully headless, no Apple 2FA). Keep it. The ASC API owns the read/submit miles.
Do not introduce a second build tool to an app that already has a working lane.

---

## Workflow A — testflight-push

The fast, repeatable closed-beta push. art-still has reduced this to **one command**
(`pnpm ship:testflight`); this workflow is the generic shape that wraps it.

### Preconditions (all must hold — STOP if not)

1. **On macOS.** `uname` → not `Darwin` ⇒ stop: producing the `.ipa` (xcodebuild
   archive/export) is Mac-only. (Everything else in the ac-* pipeline is headless; only
   this step is a Mac ritual.)
2. **Clean wave merge.** The commit being shipped is merged/landed (via `ac-merge`), not a
   dirty tree. Build from the integration branch's HEAD.
3. **Fresh native-QA PASS.** A `ac-qa-device` `QA_VALIDATION` report artifact exists whose
   **`platform:` is `ios-simulator` (or `android-emulator`)**, `status: PASS`, and
   `journeys_tested` block is **fresh relative to the commit being shipped** — not the
   session's memory that "QA passed," and **not a `browser-*` PASS** (the browser twin
   proves the web shell, never the native ship). Mechanical gate, not vibes. No qualifying
   artifact ⇒ run `ac-qa-device` (smoke at minimum) first.
   **Review-critical journeys are part of this gate (store submissions especially):** the
   QA pass must DRIVE the flows a reviewer will drive — above all any COMMERCE surface:
   the paywall must render LIVE store data with an ENABLED purchase CTA, not placeholders
   or a disabled button. Static presence checks (dep installed, chunk bundled, key baked,
   plugin registered) are never sufficient — runtime behavior is the only proof (BCA
   2.1(b): five static layers passed while the purchase flow hung, through four
   rejections). StoreKit offering/product fetch WORKS on the simulator; only purchase
   COMPLETION is device-only — "sim can't test payments" never excuses skipping this.
   **QA-freshness equivalence:** a PASS artifact captured *pre-merge* still satisfies this
   gate post-merge **iff no commits landed on main between the QA run and the merge commit
   being shipped** (i.e. the merge was fast-forward-equivalent — the version/build-bump
   commit only, no other diffs). Any intervening commit invalidates freshness and requires
   a re-run. This is a stated equivalence, not yet mechanized — verify by commit range, not
   by assumption.
4. **Signing reachable — PROBE, don't assume.** Before any signed build, run the 5-second
   codesign probe: `cp /bin/ls /tmp/csp && codesign --force --sign "<distribution identity>"
   /tmp/csp`. On `errSecInternalComponent`, classify by CONTEXT before touching key ACLs —
   the same error means different things in different places: (a) **agent/automation shells
   and CI runner services are often OUTSIDE the user's GUI security session** — keychain
   private keys are unusable there regardless of ACLs (`security show-keychain-info` saying
   "User interaction is not allowed" is the tell); route the build through the app's CI ship
   lane (`setup_ci` temp keychain) or the user's real terminal instead. (b) If the probe
   fails in the USER's own terminal too, it's a real key-ACL break (Xcode/macOS updates
   reset these): `security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k <pw>`
   then re-probe. Never start a 20-minute archive to discover what the probe tells you in 5s.
   match details per app → CORE/distribution.md.
5. **Prod backend baked in.** If the app's `.env.local` is intentionally backendless (a
   fail-soft test pattern), the prod env MUST be injected into the web build BEFORE
   archiving, else you ship a backendless binary. Verify the prod ref appears in the build
   output. (art-still: `.env.release.local` + a `grep <project-ref> out/` assertion in the
   ship script.)

### Steps

1. **Verify the build number was already bumped at merge — do not re-bump here.**
   `CURRENT_PROJECT_VERSION` (iOS) / `versionCode` (Android) MUST increment every upload —
   ASC/Play reject duplicates. **`ac-merge` (`skills/ac-merge/references/version-bump.md`)
   is the SOLE owner of this counter**, bumping it once per wave in lockstep with
   `MARKETING_VERSION` before the merge commit. This step is a check, not a mutation:
   confirm the commit being shipped already carries the bumped `CURRENT_PROJECT_VERSION`
   (`git show <SHA>:ios/App/App.xcodeproj/project.pbxproj | grep CURRENT_PROJECT_VERSION`
   vs. the last-shipped build) — if it wasn't bumped, that's an `ac-merge` gap to fix
   upstream, not something to patch here. The **only** exception `ac-distribute` may own
   is a same-version **upload-retry** bump (a rejected/stuck build that must move without a
   new marketing version) — record that narrow convention, if used, in
   `CORE/distribution.md`; it must defer to `ac-merge`'s owner ship for every normal push.
   (art-still: monotonic `CURRENT_PROJECT_VERSION` ×4 in pbxproj, bumped by `ac-merge`.)
2. **Build the web bundle** for the native target (e.g. `BUILD_TARGET=capacitor pnpm
   build`) with prod env, then sync to native (`npx cap sync ios`).
3. **Archive → sign → upload** via the app's lane (fastlane `release`: match → gym →
   codesign-verify the signed `.app` inside the archive → [dSYM upload, see ac-triage /
   Sentry] → pilot/TestFlight, `distribute_external: false` for closed beta).
4. **What-to-Test** (optional, recommended): derive the tester note from the wave's git log
   (`feat:`/`fix:` subjects since the last tag) rather than hand-writing it.
5. **Commit the build-number bump** (don't push automatically unless the app's flow does).

### Report block

```
TESTFLIGHT_PUSH
build:        <marketing> (<build#>)   e.g. 1.0 (6)
commit:       <short SHA>
qa_artifact:  <path> — status PASS, fresh ✓
backend:      prod ✓ (<project-ref> baked in)
upload:       SUCCESS — processing on ASC (visible to testers in ~5-15 min)
dsym:         uploaded ✓ | SKIPPED (Sentry not wired — see ac-triage)
```

### Known footguns (cross-app — pin these in CORE/distribution.md per app)

- **Build number must increment** every upload (above).
- **codesign-verify the `.app` inside the `.xcarchive`**, not the archive container ("code
  object is not signed at all").
- **Export compliance:** add `ITSAppUsesNonExemptEncryption = false` (HTTPS-only apps) to
  Info.plist so builds auto-clear "Missing Compliance" instead of being hidden from testers.
- **Headless auth:** an **Admin** ASC API key (not Apple-ID/2FA). Admin is needed so match
  can create certs/profiles via the API. The `.p8` NEVER touches any repo — pointer only.
- **Ruby toolchain:** modern fastlane/bundler (`Gemfile.lock` `BUNDLED WITH 4.x`) needs
  **Ruby 3.x+** (e.g. Homebrew `/opt/homebrew/opt/ruby/bin`), NOT macOS system Ruby 2.6
  (`/usr/bin`). Non-login/background shells (incl. agent-run commands) default to system
  Ruby and die with `Could not find 'bundler' (4.x)`. Prefix the lane with the right Ruby on
  PATH; pin the exact path + any vendored-gem `BUNDLE_PATH` in CORE/distribution.md.
- **Sync the web bundle FIRST** (`pnpm cap:build` / the app's equivalent) before the lane —
  fastlane's archive step does NOT run it, so skipping ships a stale bundle silently.
- **A merge-triggered archive workflow is NOT a store upload.** Some apps run an
  archive-only build-health check on main (Xcode Cloud or CI) that never uploads to
  TestFlight — its green run proves the commit still archives, nothing more. Never claim
  "build shipped" from an archive success; the proof is the build appearing in ASC with
  `processingState == VALID`. CORE/distribution.md must state explicitly whether the
  merge-triggered native build UPLOADS or is health-check-only (BCA burned an evening on
  this ambiguity, 2026-07-02).
- **`setup_ci` on a PERSONAL-Mac runner hijacks the user's keychain** — it makes
  `fastlane_tmp_keychain` the user's DEFAULT keychain and drops login from the search list.
  Fine on ephemeral CI VMs; on a self-hosted personal Mac it breaks the owner's GUI session
  (system dialogs demanding the tmp keychain's password — which is the empty string). Any
  lane using `setup_ci` on such a runner MUST restore in `after_all` AND `error` hooks:
  `security list-keychains -s ~/Library/Keychains/login.keychain-db` + `default-keychain -s`
  + `delete_keychain`. (BCA Fastfile is the reference implementation, 2026-07-03.)

Store-submit footguns (validated on BCA's first headless submit, 2026-06-17):

- **A stuck rejected `reviewSubmission` blocks a new one** — "Cannot submit for review – a
  review submission is already in progress." A prior rejection sits in `UNRESOLVED_ISSUES`
  occupying the app's single review slot. Cancel it via the ASC API:
  `PATCH /v1/reviewSubmissions/{id}` body `{data:{type:"reviewSubmissions",id,attributes:{canceled:true}}}`
  → `CANCELING`→`COMPLETE`, slot frees.
- **An empty / incomplete localization blocks review** — "missing required attribute
  description/keywords/supportUrl." Know the app's **primary locale** (it is NOT always
  `en-US` — pin it in CORE/distribution.md). `deliver` defaults to `en-US` and will *create*
  a stray empty `en-US` localization from a local metadata mirror — which then blocks review.
  Prefer **`skip_metadata: true`** (manage the listing in ASC web); delete a stray empty
  locale: `DELETE /v1/appStoreVersionLocalizations/{id}`.
- **`whatsNew` is not settable for the first *released* version** (`PATCH` → 409
  `STATE_ERROR`) and isn't required. (If v1.0 was rejected/never approved, the next version
  is effectively first-release.)
- **Apple build PROCESSING can hang indefinitely** (90+ min, esp. with a WidgetKit
  extension). A fresh **re-upload** (new build number, identical source) unsticks it — often
  processes in minutes. Don't wait forever; re-ship. Poll `builds.processingState == VALID`.
- **Submit-lane version resolution must be path-independent** — read `MARKETING_VERSION`
  from the pbxproj via a `__dir__`-relative path, NOT `Dir.pwd`→package.json (which silently
  falls back to a default like `1.0.0` and submits the wrong version + build 1).

---

## Workflow B — store-release (VALIDATED — BCA first headless submit 2026-06-17)

Production App Store submission. ASC **API** work — runs anywhere the API key exists; NOT
Mac-bound (the build it submits was already produced by testflight-push). **Human-gated at
submit** (it enters Apple's review queue; release is manual). The repetitive part is fully
headless via a fastlane `submit` lane (`upload_to_app_store`, `skip_metadata: true`,
`submit_for_review: true`, `automatic_release: false`) + a read-only ASC-API preflight.

Flow (per app, wired in CORE/distribution.md):
`cap:build → testflight-push → wait for build to process → submit-preflight (read-only) →
submit → click Release in ASC after approval`.

Stages:

1. **Submission-health / preflight (read-only)** — latest build `VALID`? App Store version
   editable? review info present? Pure ASC-API reads, mutate nothing (BCA: `pnpm submit:preflight`).
2. **Listing + screenshots** — managed in **ASC web** (standing config: description,
   keywords, supportUrl, screenshots, demo account). The submit lane leaves these alone
   (`skip_metadata`). Asset side: `app-store-screenshots` / `screenshot-refresh` skills.
3. **Demo account** — comp it to a trial/active subscription so the reviewer can exercise
   paid features (Guideline 2.1(b)); never commit its password. The business-model reply is
   a committed text file pasted into App Review Information.
4. **Submit → monitor** — the lane attaches the latest processed build to the current
   version and `submit_for_review`; then poll review state (`WAITING_FOR_REVIEW` →
   `IN_REVIEW` → ...). Clear any stuck prior submission first (footgun above).

**ASC API client:** a dependency-free ES256-JWT script (sign with the Admin `.p8`) handles
builds, reviewSubmissions, appStoreVersionLocalizations, ciBuildRuns. One small script
covers read (status/preflight) + the surgical writes (cancel stuck submission, delete empty
locale) that `deliver` can't do cleanly. Pin the app id + script path in CORE/distribution.md.

First real submission does one-time human setup (app record, privacy labels, primary-locale
listing). art-still/unsit/move-free inherit this validated shape when they leave closed beta.

---

## Per-app facts → CORE/distribution.md

**Onboarding a new app:** copy `distribution.template.md` (this skill dir) → the app's
`.claude/skills/CORE/distribution.md` and fill every `{{…}}` (incl. the `template_version`
stamp). ~30 min if the app already has a build lane; longer if it needs one stood up first.

**Keeping it current:** the CORE file is a real, app-owned copy — `deploy.sh` never overwrites
it, so it does NOT auto-update. `infra-sync` flags `template_version` drift; reconcile by
grafting new template sections in while PRESERVING filled values, then bump the stamp (see the
template's *Maintaining this file* note). Never edit this symlinked SKILL.md per-app — method
changes land HERE and propagate to every app.

Each consuming app carries a `CORE/distribution.md` (mirror of `journeys/native.md`):
bundle id, ASC app id + team id, signing setup, TestFlight group, demo account, the exact
ship command, screenshot specs, and **pointers** to secrets (key id, issuer id, where the
`.p8` lives) — never the secrets themselves. Build-number ownership is NOT per-app
configurable — it's `ac-merge` (`skills/ac-merge/references/version-bump.md`) for every
app; only document a same-version upload-retry exception here if the app uses one.

## Remember

- **This skill ships OUT. `ac-triage` pulls signal IN. `ac-qa-device` proves the build.**
  Three skills, three concerns — don't merge them.
- **Wrap what the app already uses** for the build — don't impose a tool.
- **The sim-QA gate is mechanical** — a fresh PASS artifact, not a memory.
- **Build number is the footgun** — increment every upload; owned by `ac-merge`
  (`skills/ac-merge/references/version-bump.md`), never re-bumped here.
- **Only the build mile is Mac-bound** — submit/monitor/triage all run headless.

---

_The outbound last mile. Prove it (ac-qa-device) → ship it (here) → listen (ac-triage)._
