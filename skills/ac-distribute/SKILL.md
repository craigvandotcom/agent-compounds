---
name: ac-distribute
description: Use to SHIP a built app out the door — push a signed build to TestFlight (closed beta), or submit a release to the App Store. The outbound last mile of the ac-* pipeline (implement → land → review → merge → QA → DISTRIBUTE). Triggers on "ship to testflight", "push a build", "release to app store", "cut a build", "distribute the app", "submit for review". For pulling crashes/feedback BACK IN → ac-triage. For proving the build first → ac-qa-simulator.
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
the build — that's **`ac-qa-simulator`** (run it first; this gates on its report).

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
3. **Fresh sim-QA PASS.** A `ac-qa-simulator` report artifact exists whose `status: PASS`
   and `journeys_tested` block is **fresh relative to the commit being shipped** — not the
   session's memory that "QA passed." Mechanical gate, not vibes. No artifact ⇒ run
   `ac-qa-simulator` (smoke at minimum) first.
4. **Signing reachable.** match (or the app's signing) resolves headlessly — see
   CORE/distribution.md.
5. **Prod backend baked in.** If the app's `.env.local` is intentionally backendless (a
   fail-soft test pattern), the prod env MUST be injected into the web build BEFORE
   archiving, else you ship a backendless binary. Verify the prod ref appears in the build
   output. (art-still: `.env.release.local` + a `grep <project-ref> out/` assertion in the
   ship script.)

### Steps

1. **Bump the build number.** `CURRENT_PROJECT_VERSION` (iOS) / `versionCode` (Android)
   MUST increment every upload — ASC/Play reject duplicates. This is INDEPENDENT of the
   marketing version and of `package.json`. **Pick ONE owner + bump convention per app and
   record it in CORE/distribution.md** before the first push — the classic Capacitor
   duplicate-build footgun. (art-still: monotonic `CURRENT_PROJECT_VERSION` ×4 in pbxproj,
   bumped by the ship script.)
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

---

## Workflow B — store-release (FUTURE — outline, not yet validated)

Production App Store submission. ASC **API** work — runs anywhere `asc`/the API key exist;
NOT Mac-bound (the build it submits was already produced by testflight-push). **Human-gated
at submit.** Stages:

1. **Submission-health checks** — metadata completeness, screenshots present for required
   device classes, age rating, privacy nutrition labels, demo account for review.
2. **Metadata + screenshots sync** — localized; see the `app-store-screenshots` /
   `screenshot-refresh` skills for the asset side.
3. **Release notes** — from the release's changelog.
4. **Pre-screen** — optional review-readiness pass.
5. **Submit → monitor** — `upload_to_app_store` / ASC submission, then poll review state.

First real submission for an app does one-time human setup (app record, privacy labels).
BCA is already live; art-still/unsit/move-free hit this when they leave closed beta. Build
this workflow out on the first real submission — don't speculatively wrap it now.

---

## Per-app facts → CORE/distribution.md

**Onboarding a new app:** copy `distribution.template.md` (this skill dir) → the app's
`.claude/skills/CORE/distribution.md` and fill every `{{…}}`. ~30 min if the app already has a
build lane; longer if it needs one stood up first.

Each consuming app carries a `CORE/distribution.md` (mirror of `journeys/native.md`):
bundle id, ASC app id + team id, signing setup, TestFlight group, demo account,
**version + build-number owner/convention**, the exact ship command, screenshot specs,
and **pointers** to secrets (key id, issuer id, where the `.p8` lives) — never the secrets
themselves.

## Remember

- **This skill ships OUT. `ac-triage` pulls signal IN. `ac-qa-simulator` proves the build.**
  Three skills, three concerns — don't merge them.
- **Wrap what the app already uses** for the build — don't impose a tool.
- **The sim-QA gate is mechanical** — a fresh PASS artifact, not a memory.
- **Build number is the footgun** — increment every upload; own it per app.
- **Only the build mile is Mac-bound** — submit/monitor/triage all run headless.

---

_The outbound last mile. Prove it (ac-qa-simulator) → ship it (here) → listen (ac-triage)._
