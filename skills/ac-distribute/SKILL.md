---
name: ac-distribute
description: Use to SHIP a built app out the door — push a signed build to TestFlight (closed beta), or submit a release to the App Store. The ship-OUT stage of the ac-* pipeline — position per `ac-pipeline/references/stage-table.md`; the release gate that CALLS this is ac-publish. Triggers on "ship to testflight", "push a build", "release to app store", "cut a build", "distribute the app", "submit for review". For pulling crashes/feedback BACK IN → ac-triage. For proving the build first → ac-qa. For the full production release gate (version bump, proof, heavy review, tag) that CALLS this → ac-publish.
---

> **Generic skill — method only, zero app facts.** Symlinked from agent-compounds and
> shared across consuming apps. App specifics — bundle id, ASC app id, build command,
> signing setup, version/build-number owner, TestFlight group, demo account, the exact
> ship command — live in the consuming app's **`.claude/skills/CORE/distribution.md`**,
> with per-app store ids read from the app's **`factory.json` `store.*` keys** — never
> app literals in this text. Read those FIRST. Do not add app facts here.

# ac-distribute — the ship-OUT lane

**You are shipping a build to users.** Two workflows, different cadence/risk/platform:

| Workflow            | Cadence      | Platform           | Risk / gate                              |
| ------------------- | ------------ | ------------------ | ---------------------------------------- |
| **testflight-push** | per wave-ish | **macOS** (builds) | sim-QA PASS artifact + clean merge       |
| **store-release**   | rare         | ASC API (anywhere) | human-gated at submit                    |

**Scope boundary:** this skill gets the artifact OUT. It does NOT pull crashes/feedback
back in — that's **`ac-triage`** (inbound, headless, source-agnostic). It does NOT prove
the build — that's **`ac-qa`** (run it first; this gates on its report).

**Foundation:** thin wrapper over **whatever the app already uses for the build mile**
(the proven headless shape: fastlane **match** git-stored signing + Admin ASC API key —
no Apple 2FA at any point). The ASC API owns the read/submit miles. Never introduce a
second build tool to an app that already has a working lane — rewriting a working lane
is churn for zero user value. Decision record: `references/_DECISION-distribution-stack.md`.

Full mechanics for both workflows (run ledger, preconditions, steps, report block,
footguns): `references/workflows.md`.

---

## Workflow A — testflight-push

The fast, repeatable closed-beta push. Apps typically reduce this to **one command**
(→ CORE/distribution.md); this workflow is the generic shape that command wraps.
Mechanics: `references/workflows.md` § Workflow A.

**Preconditions (all must hold — STOP if not):**

1. **On macOS** — producing the `.ipa` is Mac-only.
2. **Clean wave merge** — the commit being shipped is merged/landed, not a dirty tree.
3. **`ac-prove` gate — fresh proven SHA (`ci` depth)** — call `ac-prove` in
   `ensure --fix-forward` mode before building; consume the RETURNED proven SHA, never
   the stale input ref; proceed only on a green receipt (freshness + own-`runId` +
   `conclusion=success`). Full contract: `ac-prove/SKILL.md`.
4. **Fresh native-QA PASS** — a `ac-qa` `QA_VALIDATION` artifact with
   `platform: ios-simulator|android-emulator`, `status: PASS`, `journeys_tested` fresh
   relative to the shipped commit. Mechanical, not memory; `NOT-GATED` is not a pass
   (ac-61zh.1). Review-critical journeys are gated mechanically via
   `skills/_tools/journey-stamp-check.sh --lane testflight` (WARN-only here; absorbed
   into Workflow B's `+qa` gate for store).
5. **Signing reachable — PROBE, don't assume** (the 5-second codesign probe; classify
   `errSecInternalComponent` by context before touching key ACLs).
6. **Prod backend baked in** — inject prod env before archiving; verify the prod ref in
   the build output.

**Steps:** verify the build number was already bumped (owned by `ac-publish`, never
re-bumped here — `ac-distribute` defers to the version-bump owner; sole exception: a
same-version upload-retry bump, recorded in CORE/distribution.md) → build the web bundle
+ cap sync → archive/sign/upload via the app's lane → What-to-Test from the wave git log
→ commit an upload-retry bump if used. A pre-merge QA PASS stays fresh iff the merge was
fast-forward-equivalent (bump commit only).

**Report block** (`TESTFLIGHT_PUSH`): build · commit · qa_artifact · backend · upload ·
dsym — template in `references/workflows.md`.

---

## Workflow B — store-release (validated live)

Production App Store submission. ASC **API** work — runs anywhere the API key exists; NOT
Mac-bound. **Human-gated at submit.** Mechanics + the submit-lane shape:
`references/workflows.md` § Workflow B.

**Stage 0 gates everything after it:** `ac-prove ensure --fix-forward +qa` on the commit
whose build was uploaded via Workflow A — `+qa` drives `ac-qa` including the
review-critical sim-PASS rule; consume the RETURNED proven SHA, and only advance when it
matches the commit whose build is already `VALID` in ASC (Identity check — a fix-forward
tip's build was never uploaded; re-run Workflow A if the SHA moved).

**Stages:** preflight (read-only ASC health) → listing/screenshots in ASC web →
demo account comped to an active subscription (Guideline 2.1(b)) → submit + monitor to
`WAITING_FOR_REVIEW`. Clear any stuck prior submission first.

**ASC API client:** a dependency-free ES256-JWT script (sign with the Admin `.p8`) for
builds, reviewSubmissions, appStoreVersionLocalizations, ciBuildRuns — read + surgical
writes only. Store-submit footguns (stuck review slot, empty locale, first-release
`whatsNew`, hang-inducing processing, path-independent version resolution):
`references/workflows.md`.

---

## Per-app facts → CORE/distribution.md

**Onboarding a new app:** copy `references/distribution.template.md` (this skill dir) → the
app's `.claude/skills/CORE/distribution.md` and fill every `{{…}}` (incl. the
`template_version` stamp); set the app's `factory.json` `store.app_store_id` /
`store.team_id`. ~30 min if the app already has a build lane.

**Keeping it current:** the CORE file is a real, app-owned copy — `deploy.sh` never
overwrites it, so it does NOT auto-update. `infra-sync` flags `template_version` drift;
reconcile by grafting new template sections while PRESERVING filled values, then bump the
stamp. Never edit this symlinked SKILL.md per-app — method changes land HERE and propagate
to every app.

Each consuming app's `CORE/distribution.md`: bundle id, ASC app id + team id, signing
setup, TestFlight group, demo account, the exact ship command, screenshot specs, and
**pointers** to secrets — never the secrets themselves. Build-number ownership is NOT
per-app configurable — it's `ac-publish` (`skills/ac-publish/references/version-bump.md`)
for every app.

---

## Remember

- **This skill ships OUT. `ac-triage` pulls signal IN. `ac-qa` proves the build.**
- **Wrap what the app already uses** for the build — don't impose a tool.
- **The sim-QA gate is mechanical** — a fresh PASS artifact, not a memory.
- **A direct ship dispatch never bypasses proof** — both workflows call `ac-prove` first
  and build/submit off its RETURNED SHA, never the stale input ref.
- **Build number is the footgun** — increment every upload; owned by `ac-publish`,
  never re-bumped here.
- **Only the build mile is Mac-bound** — submit/monitor/triage all run headless.
- **Store ids come from `factory.json` `store.*`, never app literals.**

---

_The outbound last mile. Prove it (ac-qa) → ship it (here) → listen (ac-triage)._