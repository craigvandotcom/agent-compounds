# ac-distribute workflow mechanics — testflight-push + store-release

<!-- mirror: ac-pipeline/references/run-ledger.md · stage-table.md -- edit there first -->

## Run ledger (Workflow A)

Long-running and failure-prone (signing probes, processing hangs, keychain footguns) —
open a `TaskCreate` run ledger, one task per section, so a stalled/hung step is visible
rather than silent. If TaskCreate is unavailable (subagent / fan-out path), track the
ledger inline in progress.md; this is a sanctioned equivalent. Ledger contract:
`ac-pipeline/references/run-ledger.md` — one task per section, advance as you go.

```
TaskCreate("Preconditions — macOS + clean merge + fresh QA PASS + signing probe + prod-backend check")
TaskCreate("Confirm build number already bumped (no re-bump here)")
TaskCreate("Build the web bundle + cap sync")
TaskCreate("Archive + sign + codesign-verify the .app inside the archive")
TaskCreate("Upload to TestFlight")
TaskCreate("Processing wait — poll ASC until processingState == VALID")
TaskCreate("Verify — dSYM uploaded, build VALID/visible, backend + version confirmed")
TaskCreate("Report — TESTFLIGHT_PUSH block")
```

`TaskUpdate` each to `in_progress` on start, `completed` on finish.

## Workflow A — testflight-push

### Preconditions (all must hold — STOP if not)

1. **On macOS.** `uname` → not `Darwin` ⇒ stop: producing the `.ipa` (xcodebuild
   archive/export) is Mac-only.
2. **Clean wave merge.** The commit being shipped is merged/landed, not a dirty tree.
   Build from the integration branch's HEAD.
3. **`ac-prove` gate — fresh proven SHA (`ci` depth, before any dispatch).** Call
   `ac-prove` in `ensure --fix-forward` mode at `ci` depth on the clean merge-HEAD
   before building — a TestFlight push does not require `+qa` (native-QA freshness is
   item 4's PASS-artifact check + the WARN-only `--lane testflight` journey-stamp).
   Full contract: `ac-prove/SKILL.md`. Two things matter:
   - **Consume the RETURNED proven SHA, never the original ref** — if `ac-prove` fixed
     forward, the tip moved; build/archive/upload the new SHA.
   - **Only proceed on a green receipt** — freshness + own-`runId` + `conclusion=success`.
     A FAIL from `ac-prove` stops `ac-distribute` here — never archive/sign/upload off
     an unproven tree.
   QA evidence/report schema: `ac-qa/references/qa-shared.md`. Pass selection:
   `ac-pipeline/references/verification-gate.md`.
4. **Fresh native-QA PASS.** A `ac-qa` `QA_VALIDATION` report artifact exists
   whose `platform:` is `ios-simulator` (or `android-emulator`), `status: PASS`, and
   `journeys_tested` block is **fresh relative to the commit being shipped** — not
   memory, and **not a `browser-*` PASS**. Mechanical gate. `status: NOT-GATED` is not
   a pass (ac-61zh.1); this gate keys on `status: PASS` literally.
   **Review-critical journeys are part of this gate — mechanically.** TestFlight pushes
   run `skills/_tools/journey-stamp-check.sh --app <this-app> --sha <ship-sha> --lane
   testflight`, which never blocks but prints `WARN` lines.
   **For App Store submissions this check is absorbed into Workflow B's mandatory
   `ac-prove ensure --fix-forward +qa` gate (Stage 0)** — `+qa` drives `ac-qa`
   including the review-critical sim-PASS rule
   (`rule-review-critical-journeys-sim-pass-before-submission`) against the commit being
   submitted. One gate, not two — runtime behavior is the only sufficient proof, above
   all on COMMERCE surfaces (live store data + enabled CTA). StoreKit offering/product
   fetch WORKS on the simulator; only purchase COMPLETION is device-only.
   **QA-freshness equivalence:** a PASS artifact captured *pre-merge* still satisfies
   this gate post-merge **iff no commits landed on main between the QA run and the merge
   commit** (fast-forward-equivalent). Any intervening commit invalidates freshness —
   verify by commit range, not assumption.
5. **Signing reachable — PROBE, don't assume.** Run the 5-second codesign probe
   (`cp /bin/ls /tmp/csp && codesign --force --sign "<distribution identity>" /tmp/csp`).
   On `errSecInternalComponent`, classify by CONTEXT: (a) agent/automation shells and CI
   runner services are often OUTSIDE the user's GUI security session — keychain private
   keys are unusable there regardless of ACLs; route through the app's CI ship lane
   (`setup_ci` temp keychain) or the user's real terminal. (b) Fails in the USER's
   terminal too → real key-ACL break: `security set-key-partition-list -S
   apple-tool:,apple:,codesign: -s -k <pw>` then re-probe. Never start a 20-minute
   archive to discover what the probe tells you in 5s.
6. **Prod backend baked in.** If `.env.local` is intentionally backendless, the prod env
   MUST be injected into the web build BEFORE archiving. Verify the prod ref appears in
   the build output (proven recipe: `.env.release.local` + a `grep <project-ref> out/`
   assertion in the ship script).

### Steps

1. **Verify the build number was already bumped — do not re-bump here.**
   `CURRENT_PROJECT_VERSION` (iOS) / `versionCode` (Android) MUST increment every upload.
   **`ac-publish` (`skills/ac-publish/references/version-bump.md`) is the SOLE owner** of
   this counter, bumping it once per wave in lockstep with `MARKETING_VERSION` before the
   merge commit. This step is a check, not a mutation. The **only** exception
   `ac-distribute` may own is a same-version **upload-retry** bump — record that narrow
   convention, if used, in `CORE/distribution.md`.
2. **Build the web bundle** for the native target with prod env, then sync to native.
3. **Archive → sign → upload** via the app's lane: match → gym → codesign-verify the
   signed `.app` inside the archive → [dSYM upload → ac-triage / Sentry] → TestFlight,
   `distribute_external: false` for closed beta.
4. **What-to-Test** (optional): derive from the wave's git log since the last tag.
5. **If the upload-retry exception bumped the build number, commit it** — normal pushes
   already carry the bump.

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

### Known footguns (cross-app — pin per app in CORE/distribution.md)

- **Build number must increment** every upload.
- **codesign-verify the `.app` inside the `.xcarchive`**, not the archive container.
- **Export compliance:** `ITSAppUsesNonExemptEncryption = false` (HTTPS-only) so builds
  auto-clear "Missing Compliance".
- **Headless auth:** an **Admin** ASC API key (not Apple-ID/2FA); the `.p8` NEVER touches
  any repo — pointer only.
- **Ruby toolchain:** modern fastlane/bundler needs **Ruby 3.x+** (Homebrew), NOT macOS
  system Ruby 2.6 — non-login/background shells default to system Ruby and die with
  `Could not find 'bundler'`. Prefix the lane with the right Ruby on PATH.
- **Sync the web bundle FIRST** — fastlane's archive step does NOT run it.
- **A merge-triggered archive workflow is NOT a store upload.** Its green run proves the
  commit still archives, nothing more; the proof is the build appearing in ASC with
  `processingState == VALID`. CORE/distribution.md must state explicitly whether the
  merge-triggered native build UPLOADS or is health-check-only.
- **`setup_ci` on a PERSONAL-Mac runner hijacks the user's keychain** — restores in
  `after_all` AND `error` hooks: `security list-keychains -s
  ~/Library/Keychains/login.keychain-db` + `default-keychain -s` + `delete_keychain`.

## Workflow B — store-release (validated live)

Production App Store submission. ASC **API** work — runs anywhere the API key exists; NOT
Mac-bound. **Human-gated at submit.** Headless via a fastlane `submit` lane
(`upload_to_app_store`, `skip_metadata: true`, `submit_for_review: true`,
`automatic_release: false`) + a read-only ASC-API preflight.

Flow (per app, wired in CORE/distribution.md):
`cap:build → testflight-push → wait for build to process → submit-preflight (read-only) →
submit → click Release in ASC after approval`.

Run tasks — minimal (short 3-task list tracks the human-gated hand-off):

```
TaskCreate("ac-prove gate — ensure --fix-forward +qa on the commit whose build is being submitted")
TaskCreate("Preflight — read-only ASC health check (build VALID, version editable, review info present)")
TaskCreate("Submit — clear any stuck prior submission, attach build, submit_for_review")
TaskCreate("Monitor — poll review state through to WAITING_FOR_REVIEW / hand off for Release tap")
```

Stages (Stage 0 gates everything after it):

0. **`ac-prove` gate — mandatory `+qa`.** Call `ac-prove` in `ensure --fix-forward +qa`
   mode on the commit whose build was uploaded via Workflow A. `+qa` drives
   `ac-qa` — this IS the App Store lane's sim-PASS gate. Consume the returned
   proven SHA; only proceed on a green receipt.
   **Identity check:** Workflow B does not build — it submits a build ASC already has. If
   `ac-prove` fixed forward, the returned SHA is a NEW tip whose build was never uploaded
   — submitting the OLD processed build under a differently-proven commit is a mismatch.
   Stop, re-run Workflow A for the new tip, then resume. Only advance when the returned
   SHA matches the commit whose build is already `VALID` in ASC.
1. **Submission-health / preflight (read-only)** — latest build `VALID`? version editable?
   review info present? Pure ASC-API reads.
2. **Listing + screenshots** — managed in **ASC web** (description, keywords, supportUrl,
   screenshots, demo account); the submit lane leaves these alone (`skip_metadata`).
3. **Demo account** — comp it to a trial/active subscription so the reviewer can exercise
   paid features (Guideline 2.1(b)); never commit its password.
4. **Submit → monitor** — attach the latest processed build, `submit_for_review`; poll
   review state. Clear any stuck prior submission first.

**ASC API client:** a dependency-free ES256-JWT script (sign with the Admin `.p8`)
handles builds, reviewSubmissions, appStoreVersionLocalizations, ciBuildRuns — read
(status/preflight) + surgical writes (cancel stuck submission, delete empty locale) that
`deliver` can't do cleanly.

Store-submit footguns (validated live):

- **A stuck rejected `reviewSubmission` blocks a new one** — cancel via the ASC API:
  `PATCH /v1/reviewSubmissions/{id}` `{canceled:true}` → slot frees.
- **An empty / incomplete localization blocks review** — know the app's **primary locale**
  (NOT always `en-US`; pin in CORE/distribution.md). Prefer **`skip_metadata: true`**;
  delete a stray empty locale: `DELETE /v1/appStoreVersionLocalizations/{id}`.
- **`whatsNew` is not settable for the first *released* version** (`PATCH` → 409
  `STATE_ERROR`) and isn't required.
- **Apple build PROCESSING can hang indefinitely** — a fresh **re-upload** (new build
  number, identical source) unsticks it. Poll `builds.processingState == VALID`.
- **Submit-lane version resolution must be path-independent** — read `MARKETING_VERSION`
  from the pbxproj via a `__dir__`-relative path, NOT `Dir.pwd`→package.json.