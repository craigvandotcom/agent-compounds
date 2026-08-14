---
name: ac-distribute
description: Use to SHIP a built app out the door — push a signed build to TestFlight (closed beta), or submit a release to the App Store. The outbound last mile of the ac-* pipeline (implement → land → review → merge → QA → DISTRIBUTE). Triggers on "ship to testflight", "push a build", "release to app store", "cut a build", "distribute the app", "submit for review". For pulling crashes/feedback BACK IN → ac-triage. For proving the build first → ac-qa-device. For the full production release gate (version bump, proof, heavy review, tag) that CALLS this → ac-publish.
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

**Foundation:** thin wrapper over **whatever the app already uses for the build mile**
(the proven headless shape: fastlane **match** git-stored signing + Admin ASC API key —
no Apple 2FA at any point). The ASC API owns the read/submit miles. Never introduce a
second build tool to an app that already has a working lane — rewriting a working lane
is churn for zero user value. Decision record: `references/_DECISION-distribution-stack.md`.

---

## Workflow A — testflight-push

The fast, repeatable closed-beta push. Apps typically reduce this to **one command**
(→ CORE/distribution.md); this workflow is the generic shape that command wraps.

### Run tasks (this workflow only)

Long-running and failure-prone (signing probes, processing hangs, keychain footguns) —
open a `TaskCreate` run ledger, one task per section, so a stalled/hung step is visible

If TaskCreate is unavailable (subagent / fan-out path), track the ledger inline in progress.md; this is a sanctioned equivalent, not a deviation.
rather than silent:

Ledger contract: `ac-pipeline/references/run-ledger.md` — one task per section, advance as you go; ledger = run position, never work items.

```
TaskCreate("Preconditions — macOS + clean merge + fresh QA PASS + signing probe + prod-backend check")
TaskCreate("Confirm build number already bumped by ac-merge (no re-bump here)")
TaskCreate("Build the web bundle + cap sync")
TaskCreate("Archive + sign (fastlane match/gym) + codesign-verify the .app inside the archive")
TaskCreate("Upload to TestFlight (pilot)")
TaskCreate("Processing wait — poll ASC until processingState == VALID")
TaskCreate("Verify — dSYM uploaded, build VALID/visible, backend + version confirmed")
TaskCreate("Report — TESTFLIGHT_PUSH block")
```

`TaskUpdate` each to `in_progress` on start, `completed` on finish — a hung Processing
wait or a signing-probe failure shows up as a stuck task instead of a silent hang.

### Preconditions (all must hold — STOP if not)

1. **On macOS.** `uname` → not `Darwin` ⇒ stop: producing the `.ipa` (xcodebuild
   archive/export) is Mac-only. (Everything else in the ac-* pipeline is headless; only
   this step is a Mac ritual.)
2. **Clean wave merge.** The commit being shipped is merged/landed (via `ac-merge`), not a
   dirty tree. Build from the integration branch's HEAD.
3. **`ac-prove` gate — fresh proven SHA (`ci` depth, before any dispatch).** Before Step 2
   (build) below, call `ac-prove` in `ensure --fix-forward` mode at `ci` depth on the
   commit established by item 2 (the clean wave-merge HEAD) — a TestFlight push does not
   require `+qa` here (native-QA freshness for THIS lane is item 4's PASS-artifact check +
   the WARN-only `--lane testflight` journey-stamp below; `+qa` is reserved for the App
   Store lane, Workflow B Stage 0). Full contract: `ac-prove/SKILL.md`. Two things matter:
   - **Consume the RETURNED proven SHA, never the original ref** (`ac-prove`'s
     Returned-SHA Contract) — if `ac-prove` had to fix forward, the tip moved; Steps 2-3
     must build/archive/upload that new SHA, not the commit `ac-distribute` started with.
   - **Only proceed on a green receipt** — freshness + `ac-prove`'s own dispatched
     `runId` (attribution) + `conclusion=success` (its three-condition trust rule). A FAIL
     from `ac-prove` (PROFOUND failure or iteration cap hit) stops `ac-distribute` here —
     never archive/sign/upload off an unproven tree, even mid-wave.
QA evidence/report schema: `ac-pipeline/references/qa-shared.md`.
Pass selection defers to `ac-pipeline/references/verification-gate.md` — one selection brain, never re-decided locally.

4. **Fresh native-QA PASS.** A `ac-qa-device` `QA_VALIDATION` report artifact exists whose
   **`platform:` is `ios-simulator` (or `android-emulator`)**, `status: PASS`, and
   `journeys_tested` block is **fresh relative to the commit being shipped** — not the
   session's memory that "QA passed," and **not a `browser-*` PASS** (the browser twin
   proves the web shell, never the native ship). Mechanical gate, not vibes. No qualifying
   artifact ⇒ run `ac-qa-device` (smoke at minimum) first.
   **Review-critical journeys are part of this gate — mechanically, not by memory.**
   TestFlight pushes run `skills/_tools/journey-stamp-check.sh --app <this-app> --sha
   <ship-sha> --lane testflight`, which never blocks but prints `WARN` lines — a stamp
   gap is visible, not silent, ahead of the store lane's harder gate.
   **For App Store submissions this check is no longer run standalone here** — it's
   absorbed into Workflow B's mandatory `ac-prove ensure --fix-forward +qa` gate (Stage 0
   below): `+qa` drives `ac-qa-device`, including the review-critical sim-PASS rule
   (memory: `rule-review-critical-journeys-sim-pass-before-submission`), against the
   commit being submitted. `ac-distribute` does not additionally dispatch the BLOCKING
   `--lane store` journey-stamp-check itself in parallel — one gate, not two. Why:
   runtime behavior, not static presence, is the only sufficient proof — above all on
   COMMERCE surfaces (live store data + enabled CTA). StoreKit offering/product fetch
   WORKS on the simulator; only purchase COMPLETION is device-only — "sim can't test
   payments" never excuses a missing/stale stamp. A stamp is refreshed by driving the
   journey again (`ac-qa-device`/`ac-qa-browser` writing `last_pass`) — see
   `ac-publish`'s full-QA phase, which is where every critical journey's stamp gets
   refreshed before a release ceremony.
   **QA-freshness equivalence:** a PASS artifact captured *pre-merge* still satisfies this
   gate post-merge **iff no commits landed on main between the QA run and the merge commit
   being shipped** (i.e. the merge was fast-forward-equivalent — the version/build-bump
   commit only, no other diffs). Any intervening commit invalidates freshness and requires
   a re-run. This is a stated equivalence, not yet mechanized — verify by commit range, not
   by assumption.
5. **Signing reachable — PROBE, don't assume.** Before any signed build, run the 5-second
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
6. **Prod backend baked in.** If the app's `.env.local` is intentionally backendless (a
   fail-soft test pattern), the prod env MUST be injected into the web build BEFORE
   archiving, else you ship a backendless binary. Verify the prod ref appears in the build
   output (proven recipe: a `.env.release.local` + a `grep <project-ref> out/` assertion in
   the ship script).

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
   `CORE/distribution.md`; it must defer to `ac-merge`'s ownership for every normal push.
   (pbxproj carries `CURRENT_PROJECT_VERSION` ×4; a bump moves all four in lockstep.)
2. **Build the web bundle** for the native target (e.g. `BUILD_TARGET=capacitor pnpm
   build`) with prod env, then sync to native (`npx cap sync ios`).
3. **Archive → sign → upload** via the app's lane (fastlane `release`: match → gym →
   codesign-verify the signed `.app` inside the archive → [dSYM upload, see ac-triage /
   Sentry] → pilot/TestFlight, `distribute_external: false` for closed beta).
4. **What-to-Test** (optional, recommended): derive the tester note from the wave's git log
   (`feat:`/`fix:` subjects since the last tag) rather than hand-writing it.
5. **If the upload-retry exception bumped the build number, commit it** — normal pushes
   already carry `ac-merge`'s bump (don't push automatically unless the app's flow does).

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
  merge-triggered native build UPLOADS or is health-check-only — this ambiguity has burned
  an evening.
- **`setup_ci` on a PERSONAL-Mac runner hijacks the user's keychain** — it makes
  `fastlane_tmp_keychain` the user's DEFAULT keychain and drops login from the search list.
  Fine on ephemeral CI VMs; on a self-hosted personal Mac it breaks the owner's GUI session
  (system dialogs demanding the tmp keychain's password — which is the empty string). Any
  lane using `setup_ci` on such a runner MUST restore in `after_all` AND `error` hooks:
  `security list-keychains -s ~/Library/Keychains/login.keychain-db` + `default-keychain -s`
  + `delete_keychain`.

Store-submit footguns (validated live):

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

## Workflow B — store-release (validated live)

Production App Store submission. ASC **API** work — runs anywhere the API key exists; NOT
Mac-bound (the build it submits was already produced by testflight-push). **Human-gated at
submit** (it enters Apple's review queue; release is manual). The repetitive part is fully
headless via a fastlane `submit` lane (`upload_to_app_store`, `skip_metadata: true`,
`submit_for_review: true`, `automatic_release: false`) + a read-only ASC-API preflight.

Flow (per app, wired in CORE/distribution.md):
`cap:build → testflight-push → wait for build to process → submit-preflight (read-only) →
submit → click Release in ASC after approval`.

**Run tasks — kept minimal.** Mostly one-shot ASC API calls (unlike Workflow A's long,
failure-prone build/sign/upload mile), so a full per-section ledger is overkill; a short
3-task list is enough to track the human-gated hand-off:

```
TaskCreate("ac-prove gate — ensure --fix-forward +qa on the commit whose build is being submitted")
TaskCreate("Preflight — read-only ASC health check (build VALID, version editable, review info present)")
TaskCreate("Submit — clear any stuck prior submission, attach build, submit_for_review")
TaskCreate("Monitor — poll review state through to WAITING_FOR_REVIEW / hand off for Release tap")
```

Stages (Stage 0 gates everything after it):

0. **`ac-prove` gate — mandatory `+qa` (before Stage 1, before any dispatch).** Call
   `ac-prove` in `ensure --fix-forward +qa` mode on the commit whose build was uploaded via
   Workflow A (testflight-push). `+qa` drives `ac-qa-device` — including the review-critical
   sim-PASS rule (memory: `rule-review-critical-journeys-sim-pass-before-submission`) — this
   IS the App Store lane's sim-PASS gate now; item 4's `--lane store` journey-stamp-check is
   **not** run as a separate parallel call (see Workflow A item 4 — absorbed here, not
   duplicated). As with Workflow A: **consume the returned proven SHA**, and only proceed on
   a green receipt (freshness + own-`runId` + `conclusion=success`); a FAIL stops
   `ac-distribute` here, before Stage 1.
   **Identity check (App-Store-specific):** unlike Workflow A, Workflow B does not build —
   it submits a build ASC already has. If `ac-prove` had to fix forward, the returned SHA is
   a NEW tip whose build was never uploaded via testflight-push — submitting the OLD
   processed build under a differently-proven commit is a mismatch, not a valid ship. In
   that case, stop, re-run Workflow A (testflight-push, which re-runs its own `ci`-depth
   `ac-prove` gate) for the new tip, then resume Workflow B. Only advance to Stage 1 when the
   returned SHA matches the commit whose build is already `VALID` in ASC.
1. **Submission-health / preflight (read-only)** — latest build `VALID`? App Store version
   editable? review info present? Pure ASC-API reads, mutate nothing (e.g. a
   `submit:preflight` script).
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
listing); apps leaving closed beta inherit this validated shape.

---

## Per-app facts → CORE/distribution.md

**Onboarding a new app:** copy `references/distribution.template.md` (this skill dir) → the
app's `.claude/skills/CORE/distribution.md` and fill every `{{…}}` (incl. the
`template_version` stamp). ~30 min if the app already has a build lane; longer if it needs
one stood up first.

**Keeping it current:** the CORE file is a real, app-owned copy — `deploy.sh` never overwrites
it, so it does NOT auto-update. `infra-sync` flags `template_version` drift; reconcile by
grafting new template sections in while PRESERVING filled values, then bump the stamp (see the
template's *Maintaining this file* note). Never edit this symlinked SKILL.md per-app — method
changes land HERE and propagate to every app.

Each consuming app carries a `CORE/distribution.md` (same per-app pattern as
`journeys/native.md`): bundle id, ASC app id + team id, signing setup, TestFlight group,
demo account, the exact ship command, screenshot specs, and **pointers** to secrets (key id,
issuer id, where the `.p8` lives) — never the secrets themselves. Build-number ownership is
NOT per-app configurable — it's `ac-merge` (`skills/ac-merge/references/version-bump.md`)
for every app; only document a same-version upload-retry exception here if the app uses one.

## Remember

- **This skill ships OUT. `ac-triage` pulls signal IN. `ac-qa-device` proves the build.**
  Three skills, three concerns — don't merge them.
- **Wrap what the app already uses** for the build — don't impose a tool.
- **The sim-QA gate is mechanical** — a fresh PASS artifact, not a memory.
- **A direct ship dispatch never bypasses proof.** Both workflows call `ac-prove` first —
  `ensure --fix-forward` at `ci` depth for TestFlight, mandatory `+qa` for App Store — and
  build/submit off `ac-prove`'s RETURNED SHA, never the stale input ref.
- **Build number is the footgun** — increment every upload; owned by `ac-merge`
  (`skills/ac-merge/references/version-bump.md`), never re-bumped here.
- **Only the build mile is Mac-bound** — submit/monitor/triage all run headless.

---

_The outbound last mile. Prove it (ac-qa-device) → ship it (here) → listen (ac-triage)._
