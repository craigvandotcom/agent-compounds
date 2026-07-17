---
name: ac-publish
description: 'The manual, human-triggered release gate — the definitive "ship to production" step. Pins main, mints the single release version bump (Phase 0), then calls ac-prove (ensure --fix-forward) for a fresh ref-pinned full-suite + full device/browser QA proof, runs a heavy 6-dimension review over everything since the last publish, checks migrations are expand/contract-safe, tags the proved commit, then ships web (Vercel promote, never a rebuild) + native. Composes ac-prove (the confidence gate) + ac-review (the heavy panel) + ac-distribute (native ship). Triggers: "/ac-publish", "publish", "release to prod", "ship it to production", "cut the release".'
---

# ac-publish — Manual Release Gate

**You are the publish conductor.** Publish is **manual** — Craig triggers it; there is no autonomous
promoter (parallel-execution doctrine §6). Your job spans several things no other skill owns
end-to-end: **mint the single release version** (Phase 0 — relocated here from `ac-batch-close`
Phase 2; see `version-bump-defaults-to-patch`), act as the *definitive confidence gate* before
production — obtain a fresh, ref-pinned proof that the full suite is green **for the exact commit
you're about to ship** (via `ac-prove`), run the genuinely-new expensive checks (full device/browser
QA **and** a heavy 6-dimension review over everything since the last publish — the "freight" that
moved here when `ac-batch-close` went on its diet, `bd-pwt44` epic), confirm migrations are
release-safe, fix anything that surfaces **in-session**, **tag** the proved commit, then ship web
(via **Vercel promote, never a rebuild** — Staged Deployments) + native, and **finalize** the feedback rows
`ac-batch-close` left pending.

**You compose, you don't duplicate.** The confidence proof is owned by `ac-prove`
(`skills/ac-prove/SKILL.md`) — you **call** it with `ensure --fix-forward`, you don't re-derive
freshness/dispatch/trust logic yourself. The heavy review panel is owned by `ac-review`
(`skills/ac-review/SKILL.md`) — you **call** it (full 6-dimension mode, not `ac-batch-close`'s
light pass), you don't re-derive its dimension rubric. The native build/sign/upload is owned by
`ac-distribute` — you **call** it, never inline it.

> **⚠ Web ship model — promote-not-rebuild via Vercel Staged Deployments, superseding "deploy at
> merge".** Historically `ac-merge` triggered a Vercel PROD deploy on every wave merge,
> autonomously — so web content was already live by the time `ac-publish` ran, and this file used
> to say so. **Under the current model that's superseded:** Vercel's **Production Branch stays
> `main`**, but domain auto-assignment for the production branch is turned OFF (`bd-pwt44.7`,
> Craig's Vercel Dashboard setting, live 2026-07-13). Effect: **every push to `main` still builds a
> PRODUCTION-target deployment** — production env vars baked in, exactly as a real prod build would
> be — but it sits as a **Staged** deployment with no domain attached; nothing is user-visible until
> `ac-publish` explicitly **promotes** that proven SHA's staged deployment (Phase 5, Step 3;
> dashboard "Promote to Production" or `vercel promote`). No rebuild between proof and going live,
> and no more silent auto-promotion of every intermediate merge (including unreviewed fix-forward
> commits). **Never promote a preview deployment** — a preview build bakes *preview* env vars into
> `NEXT_PUBLIC_*` at build time, so promoting one ships the wrong artifact; only the staged
> production-target build is ever a valid promote target (see Phase 5, Step 3). Migration safety is
> unaffected either way: `ac-merge`'s apply-timing gate (`rule-migrations-expand-contract`) still
> ensures an EXPAND migration is pushed before/at the merge of code that depends on it, so schema
> never lags code regardless of which web-ship model is currently live.

---

## I/O Contract

| | |
|---|---|
| **Input** | `main` at rest, whatever commits have landed since the last release |
| **Output** | Production web deploy (Vercel, via **promote** of `R`'s proven staged deployment — never a rebuild) + native build shipped (`ac-distribute` → TestFlight / App Store); one minted version bump per publish; a `vX` git tag at the exact proved commit `R`; `fixed_pending_release` feedback rows finalized to `fixed` with the minted build |
| **Not in scope** | Merging (that's `ac-merge`/`ac-batch-close`), the confidence-proof mechanics (that's `ac-prove`), the review-dimension rubric (that's `ac-review`), autonomous triggering |

---

## Phase 0: Preflight

### Create Workflow Tasks (run ledger)

**One task per phase — the ledger tracks this gate's own progress toward a ship.** Create
the fixed tasks below now; **add a "Fix-in-session — round N" task each time Phase 1, 2, or 3
surfaces an issue** (dynamic, per the re-entrant loop — a fix commit re-invokes `ac-prove`
against the new tip, which returns whatever `R` it actually proved per its Returned-SHA
Contract; the Confidence/QA gate task **and** the Heavy review task both go back to
`in_progress` on that return, they do not get re-created — Phase 2's stale-review invalidation
rule means a re-pin re-opens the review too). `ac-distribute`, invoked from Phase 5, keeps its
own ledger — don't duplicate its build/sign/upload steps here.

```
# Fixed tasks — create upfront:
TaskCreate("Preflight — pin candidate C, mint the release bump (R), push R, finalize feedback rows")
TaskCreate("Confidence/QA gate — ac-prove ensure --fix-forward --ref R (+qa)")
TaskCreate("Heavy review — 6-dimension review since last publish, scoped to R")
TaskCreate("Migration safety — expand/contract audit since last release")
TaskCreate("Ship — tag vX at R, promote web (not rebuild), invoke ac-distribute for native")
TaskCreate("Report — Slack the release summary")

# Dynamic task — add ONE each time a gate fails (not upfront):
TaskCreate("Fix-in-session — round {N}")
# On completion, TaskUpdate its description with what was fixed + the new commit SHA.
```

**TaskUpdate("Preflight", in_progress)**

```bash
git checkout main && git pull --rebase
git status                       # must be clean + up to date with origin
```

If `main` is not clean/current, stop — publish releases exactly what is on `origin/main`.

### Mint the release — the single bump per publish

**This is the ONE place a version bump happens for the agent-batch path.** It is relocated
here from `ac-batch-close` Phase 2 (`version-bump-defaults-to-patch`) — batch-close no longer
bumps; `ac-publish` mints once, per successful publish. `ac-merge`'s legacy-PR bump path
(dependabot/human branches) is unrelated and unchanged by this move.

```bash
C=$(git rev-parse main)                                # candidate — pin BEFORE bumping
pnpm version patch --no-git-tag-version                # default; minor/major only on deliberate
                                                         # human direction — never auto-derived
```

Propagate to native build surfaces in the same commit — this is the build-number bump that
used to live in `ac-batch-close` Phase 2 ("Propagate to native build surfaces"): iOS
`MARKETING_VERSION` ×4 + monotonic `CURRENT_PROJECT_VERSION`, Android `build.gradle` when
added, `NEXT_PUBLIC_APP_VERSION` auto-derived. Follow **`../ac-merge/references/version-bump.md`**
verbatim — it remains the sole-owner reference for the *mechanics* of this counter regardless
of which skill calls it. Web-only projects skip the native steps.

```bash
git add package.json pnpm-lock.yaml ios/App/App.xcodeproj/project.pbxproj 2>/dev/null
git commit -m "chore(release): v$(node -p "require('./package.json').version")"
R=$(git rev-parse HEAD)                                 # R := the bumped commit SHA
git push origin main
```

**CRITICAL ORDERING — why the bump must ride inside/ahead of the pin, not after it.**
"Tagged == proved `R`" only holds if the bump is baked into `R` itself:

- (a) The bump **is itself a new commit** (`pnpm version` + the propagation commit) — it
  cannot retroactively become the pre-bump candidate `C`. Pin-then-bump-separately would leave
  you proving/tagging the wrong commit.
- (b) CI's divergence step pushes a `[skip ci]` evidence commit on **every** full run — so the
  instant `ac-prove` dispatches against `R`, `main` advances past `R` again. Bumping "later" (as
  a follow-up commit after proving) would either bump a moving target or bump on top of a commit
  that's no longer the tip.

The only order that holds: **pin candidate `C` → bump ON `C` (`R` := the bumped commit) → push
`R` → prove `--ref R`.**

**PUSH IS LOAD-BEARING, not administrative.** `quality-gate.yml`'s `ref` input feeds
`actions/checkout ref: R`, which fetches `R` **from origin** — a local-only bump makes
`gh workflow run -f ref="$R"` (inside `ac-prove`'s dispatch) fail "couldn't find remote ref R".
The push above is not "save the work" housekeeping; it's the thing that makes Phase 1 possible
at all.

**Push-failure abort/retry.** If the push above is rejected — non-fast-forward (a robot/human
commit landed on `main` between the pin and the push) or an auth/network failure — **Phase 0
aborts cleanly**: do not dispatch `ac-prove`, do not tag, do not report "R published" anywhere.
Re-pin from the new `main` HEAD (`git pull --rebase`, recompute `C`, re-bump) and retry, bounded
(a small fixed number of attempts — repeated rejection is a genuine concurrent-write conflict to
surface, not something to force through). Never proceed with a stale or local-only `R`.

**Forward-only, even on abort.** If a later phase aborts PROFOUND (Phase 4, no fix found) after
this push has already landed, an unreleased bump commit is stranded on `main`. This is harmless:
versions are monotonic and forward-only (`version-bump-defaults-to-patch`), a skipped release
number costs nothing, and mint-once is scoped to *successful* publishes — an aborted attempt
just means the next successful publish mints from a slightly higher floor. Never try to "revert"
the bump to reclaim the number.

### Feedback finalize — the reciprocal of the pending-write (bd-pwt44.6)

**This completes `bd-pwt44.3`'s two-phase feedback write-back model** (Model B in
`ac-merge/references/feedback-writeback-hook.md` — not to be confused with this skill's own
Phase numbering below). `ac-batch-close` Act 3 writes `status='fixed_pending_release'` on
`triage,feedback` rows as it closes each batch (Model B's write-back Phase 1); this sweep, run
here once `R` (and its minted build number) exists, is Model B's write-back Phase 2 — the write
that actually finalizes those rows.

```bash
# STATE-BASED query — NOT a time-window / "since last publish" cutoff. A time-window cutoff
# could orphan rows accumulated across several batch-closes that ran before this publish.
# WHERE status = 'fixed_pending_release'
pnpm finalize:feedback "$R_VERSION"   # BCA: scripts/pipeline/finalize-feedback-sweep.mjs
```

`pnpm finalize:feedback <mintedVersion>` (BCA: `scripts/pipeline/finalize-feedback-sweep.mjs`) is the
prod runner for `runFeedbackFinalizeSweep(newBuild, deps)` — the finalize path of
`lib/pipeline/merge-feedback-writeback.ts` in the consuming app (BCA: bd-pwt44.6). Call it with the
version just minted above (the version baked into `R`) as the sole argument. It lists every
still-pending row via `deps.listPendingReleaseRows()` (the state-based query above) and writes
`status='fixed'` + `fixed_in_build=<R's version>` for each. This is the exact write that flips
the client's `isNowFixed` check (`features/feedback/lib/loopback.ts:190`,
`row.status === 'fixed'`) and fires the "fixed in build N" local notification — now correctly
timed at ship, with a real build number attached, instead of at batch-close when no build number
existed yet. Same never-abort-on-write-failure policy as the pending-write hook: a
0-rows-affected update is logged as a warning and the publish is never aborted by this sweep.
Replaces the manual SELECT workaround used during the v1.5.13 publish.

**TaskUpdate("Preflight", completed)**

## Phase 1: Confidence gate (ac-prove + full QA)

**TaskUpdate("Confidence/QA gate", in_progress)**

**Step 1 — call `ac-prove`.** This REPLACES the old inline SHA-pinned CI-history read (`gh run
list --workflow=quality-gate.yml --commit ...`) — `ac-publish` no longer re-derives
freshness/dispatch/trust logic itself; it delegates to the shared primitive
(`ac-prove/SKILL.md`) and trusts its verdict.

```bash
# ac-prove: ensure --fix-forward --ref "$R" +qa
```

Proceed **only** on a receipt that satisfies `ac-prove`'s three-condition Canonical Receipt
Contract: freshness-valid **AND** own-run-id (attribution) **AND** `conclusion=success`. Any one
of the three missing is not proof — treat it as `ac-prove` reporting FAIL and go to Phase 4.
Never trust a stale prior-SHA green; `ac-prove` proves the *exact* ref you pass it.

`ac-prove`'s `+qa` layer is where the one genuinely-new expensive check at publish happens —
full device/browser QA against the release build (`ac-qa-device` + `ac-qa-browser`, per
`qa-gating-craig-owns-visual-agent-functional`: agent runs functional QA, Craig owns visual
sign-off). This is also where every non-peripheral journey's `last_pass` stamp gets refreshed
(per `rule-review-critical-journeys-sim-pass-before-submission` — review-critical journeys must
show a sim-PASS on the exact build before submission), so `ac-distribute`'s store gate
(`skills/_tools/journey-stamp-check.sh`) sees fresh review-critical stamps at submission. Any QA
blocker → Phase 4.

Optionally, `+qa` can additionally target `R`'s Vercel **staged** deployment directly (`qa-browser`
against the literal production-target artifact about to be promoted, pre-promotion) — this flows
through `ac-prove`'s existing `--ref` contract already in play above; no new machinery is needed to
support it. Never target a preview deployment for this purpose — its baked-in preview env vars
make it a different artifact than the one that will actually ship.

**Fix-forward re-pin.** If `ac-prove` fixes forward, it returns a **new tip `R′ ≠ R`** (its
Returned-SHA Contract — never assume your input `--ref` still holds). Re-pin `R ← R′` and
re-scope every downstream step (migration diff, heavy review, tag) to `R′`. **Do not re-bump** —
a fix-forward round is a code fix, never a `package.json` touch; the Phase-0 mint already rides
along on `R′` since it descends from `R`, so mint-once holds across re-pins. This loop is
inherently bounded: evidence/bead-writing commits are `[skip ci]` and can't themselves
re-trigger a `reason=prove` dispatch, and `ac-prove`'s own fix-forward mini-loop is capped. If
Phase 2's heavy review already ran against the old `R`, this re-pin **invalidates** it — see
Phase 2's stale-review rule below.

Red (FAIL from `ac-prove`, no valid receipt) → Phase 4 (fix-in-session).

**TaskUpdate("Confidence/QA gate", completed)**

## Phase 2: Heavy 6-Dimension Review

**TaskUpdate("Heavy review", in_progress)**

**This review panel is NEW to `ac-publish`** — it was never part of `ac-batch-close`'s ceremony
(batch-close keeps only its own single light `VERDICT` pass); the full 6-dimension panel
consolidates here, at the publish boundary, as the heavy pre-tag adversarial gate the
batch-close diet shed (`bd-pwt44` epic; `conductor-remedies-need-adversarial-rounds`).

Scope it to everything merged since the last publish, against the current `R`:

```bash
LAST_TAG=$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null)
git log "$LAST_TAG"..R --oneline           # the range under review
```

Delegate to `ac-review` (do not inline its work — `ac-review/SKILL.md` is a full skill, not a
sub-step of this one), full 6-dimension mode (correctness/security/perf/architecture always, plus
test-quality/contracts unless provably irrelevant — **not** `ac-batch-close`'s light single pass):

> "Run ac-review over `$LAST_TAG..$R` (full 6-dimension panel, not the trunk-direct light mode).
> report_dest=.claude/reviews/publish/"

Findings at Critical/High severity block the ship — route them to Phase 4 (Fix-in-session), same
as a Confidence-gate or migration-safety failure.

**Stale-review invalidation.** If Phase 1 fix-forwards to a new tip (`R ← R′`) **after** this
phase has already run, the review just computed is invalidated — the fix-forward commits have
not themselves been adversarially reviewed. Re-run this phase at the new `R′` before proceeding;
never carry forward a review verdict computed against a superseded tip. This is the same rule
`conductor-remedies-need-adversarial-rounds` has argued since 2026-07-02: a round that wrote a fix
is never self-certifying — the fresh review at the new tip is what certifies it, not the
fix-forward commit itself.

**TaskUpdate("Heavy review", completed)**

## Phase 3: Migration safety (expand/contract)

**TaskUpdate("Migration safety", in_progress)**

Shared prod Supabase DB + native builds lag weeks — the one real release hazard
(`shared-prod-migration-collisions`, `app-version-pinned-1.2.0-appstore-resubmission`). Inspect every
migration added since the last release:

```bash
LAST_RELEASE=$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null || git describe --tags --abbrev=0)
git diff --name-only "$LAST_RELEASE".."$R" -- supabase/migrations/
```

Read each new migration and classify it per `rule-migrations-expand-contract`:

- **Expand (additive):** must already be **applied to prod** (it was required before/at the merge of
  its dependent code — `ac-merge`'s apply-timing gate). If one is merged-but-unpushed, apply it now
  (collision-aware: `migration fetch` → review → `db push` → verify) before shipping.
- **Contract (drop / rename / narrow / `NOT NULL` without default):** allowed **only as a deliberate,
  explicitly-approved step after old native builds have aged out** — check the oldest still-live
  native build version against what the contract removes; Craig approves the push. A contract that
  hasn't met the aged-out bar stays **held** (merged, unapplied) — do not push it as part of this
  release.
- **Backward-incompatible change bundled into one migration:** → **stop**, split into an expand-now /
  contract-later pair.

This gate blocks the ship; it is not a warning.

**TaskUpdate("Migration safety", completed)**

## Phase 4: Fix-in-session

If `ac-prove` reports FAIL (Phase 1 — its own internal fix-forward loop already exhausted, or a
`+qa` blocker it doesn't auto-fix), the heavy review (Phase 2) surfaces a Critical/High finding,
or migrations (Phase 3) surface an issue: **add a "Fix-in-session — round {N}" task now**
(`in_progress`) and fix it — you may ask Craig. Get to 100% before shipping. File a bead only if
the fix is genuinely bigger than this session (then stop). A fix commit moves the tip, so
**re-invoke `ac-prove` against the new commit** (never re-bump — see Phase 1's Fix-forward
re-pin) and adopt whatever `R` it returns — **mark "Fix-in-session — round {N}" `completed`**
(note the new SHA in its description), set **"Confidence/QA gate" back to `in_progress`** (it is
re-entered, not re-created), and — because the tip moved — set **"Heavy review" back to
`in_progress`** too (Phase 2's stale-review invalidation rule: a fix commit landed after the
last heavy-review pass means that pass no longer covers the code you're about to ship).

## Phase 5: Ship

**TaskUpdate("Ship", in_progress)**

1. **Bump already minted (Phase 0).** The single mint for this publish already happened, once,
   at Phase 0 — on `R` (or `R′`, if Phase 1 re-pinned). Nothing to verify or re-derive here; just
   carry the version reported there into the Phase 5 report. Do not touch `package.json` again in
   this phase — that counter has exactly one mint per publish.

2. **Tag the release — at the explicit `R`, never `HEAD`.**

   ```bash
   TAG="v$(node -p "require('./package.json').version")"
   git tag "$TAG" "$R"
   git push origin "$TAG"
   ```

   Tag `R` **explicitly by SHA**, not `HEAD` — `ac-prove`'s dispatch pushes a `[skip ci]` evidence
   commit on every full run, so by the time you reach this phase `main`'s `HEAD` has moved past
   `R` again; tagging `HEAD` would tag a commit that was never proven or reviewed. **Do not bump
   the version again here** — the single mint already happened in Phase 0 (or rode along on `R′`
   if Phase 1 re-pinned); this step only tags what was already minted, proved, and reviewed.

3. **Promote-not-rebuild — the web ship (Vercel Staged Deployments).** Vercel's Production Branch
   stays `main`; domain auto-assignment for the production branch is OFF (`bd-pwt44.7`, Craig's
   Vercel Dashboard setting, live 2026-07-13). Effect: the push to `main` in Phase 0/1 already
   built a PRODUCTION-target deployment (production env vars) for `R` — it is sitting as
   **Staged**, with no domain attached. Production moves ONLY by promoting that staged deployment
   — no rebuild between proof and going live. The artifact `ac-prove` (and any `+qa` browser pass)
   validated IS the artifact that ships; a fresh `vercel deploy --prod` would build a *different*
   artifact than the one just proven.

   ```bash
   # Locate R's existing STAGED deployment (production-target build, sitting with no domain),
   # keyed on R's git SHA:
   STAGED_URL=$(vercel ls <project> --meta githubCommitSha="$R" | ...)
   vercel inspect "$STAGED_URL"                   # confirm it actually built R AND is a
                                                    # production-target build (production env
                                                    # vars) — never a preview
   vercel promote "$STAGED_URL"                    # dashboard equivalent: "Promote to Production"
   ```

   Assert there is **no** `vercel deploy --prod` call anywhere in this step — promotion is an
   alias move over an already-built, already-proven staged deployment, never a new build.

   **NEVER promote a preview deployment.** A preview deployment bakes **preview** env vars into
   `NEXT_PUBLIC_*` at build time — promoting one ships the wrong artifact into production (stale
   or wrong API keys/flags baked in, not swappable post-build). Only the staged production-target
   build produced by the `main` push is ever a valid promote target; verify this via
   `vercel inspect` before promoting, never by URL naming alone. If `vercel inspect` shows the
   candidate is a preview build, or no staged deployment for `R` can be found, **abort this step**
   with an explicit message and surface it to Craig — never report a completed ship on an
   unverified or wrong-artifact promote.

4. **Post-promotion verify — deployment IDENTITY, never a version-grep.** Confirm production is
   actually serving `R`, not merely that a version string matches (a stale version string can
   coincidentally match across two different deployments that both minted the same
   `package.json` bump). Check the LIVE PRODUCTION ALIAS's own deployment metadata against `R`:

   ```bash
   vercel inspect <production-url>      # confirm the returned commit SHA / deployment id == R
   ```

   A version-number match alone is never proof of identity — always confirm against the prod
   alias's own deployment metadata.

5. **Native.** Invoke `ac-distribute` for the actual build/sign/upload (Workflow A → TestFlight,
   or Workflow B → App Store submit). Pass that its preconditions are met (fresh QA PASS from
   Phase 1's `+qa` layer — including the review-critical-journeys sim-PASS rule,
   `rule-review-critical-journeys-sim-pass-before-submission` — and the Phase-0 mint).
   `ac-distribute` is check-only on the bump — no re-bump.

**TaskUpdate("Ship", completed)**
**TaskUpdate("Report", in_progress)**

6. **Confirm + notify.** Web live (verified by identity, Step 4) + native uploaded → report the
   release (SHA, build number, tag, what shipped) on Slack. **Known-action findings from this
   run (defects, decision forks, refinements you KNOW need action) are filed as beads
   (`unrefined`) and cited by ID here, never left as prose-only** — a prose-only findings
   channel orphans once its consumer closes (`rule-known-action-capture-beads-not-prose`;
   bd-pwt44 lesson).

**TaskUpdate("Report", completed)**

---

## Remember

- **Manual only** — Craig triggers publish; no autonomous promoter (doctrine §6).
- **Mint once, at Phase 0** — the single version/build bump for the agent-batch path lives here
  now (moved from `ac-batch-close` Phase 2); `ac-merge`'s legacy-PR bump path is untouched.
- **Pin → bump → push → prove, in that order** — the bump must ride inside the pinned commit
  before `ac-prove` ever sees it; push is load-bearing, not housekeeping.
- **Delegate the confidence gate** — call `ac-prove ensure --fix-forward --ref R +qa`; don't
  re-derive freshness/dispatch/trust logic. Trust only its three-condition green receipt.
- **Delegate the heavy review** — call `ac-review` full 6-dimension mode over the range since
  the last publish; don't re-derive its dimension rubric. This is the panel `ac-batch-close`
  shed — it lives here now, as the pre-tag gate.
- **A fix-forward re-pin invalidates a heavy review already run at the old `R`** — re-run Phase 2
  at the new `R′` before tagging; never carry forward a review verdict computed against a
  superseded tip (`conductor-remedies-need-adversarial-rounds`).
- **Never re-bump on a fix-forward re-pin** — a fix commit is a code fix, never a `package.json`
  touch; adopt whatever `R` `ac-prove` returns and re-scope downstream steps to it.
- **Tag at the explicit `R`, never `HEAD`** — `ac-prove`'s evidence-commit push moves `HEAD` past
  `R` on every dispatch; tagging `HEAD` would tag an unproven, unreviewed commit.
- **Promote, don't rebuild** — production moves only via `vercel promote` on `R`'s already-proven
  STAGED deployment (production-target build, no domain attached); a fresh `vercel deploy --prod`
  builds a different artifact than the one proved and reviewed. Verify by deployment identity,
  never a version-grep.
- **Never promote a preview** — preview deployments bake preview env vars into `NEXT_PUBLIC_*` at
  build time; only the staged production-target build is a valid promote target. Verify via
  `vercel inspect`, never by URL naming.
- **Production Branch stays `main`; domain auto-assignment for production is OFF** (`bd-pwt44.7`,
  Craig's Vercel Dashboard setting, live 2026-07-13) — this is what makes every `main` push a
  production-target staged deployment instead of a live prod deploy.
- **Never inline the native ship** — call `ac-distribute`; don't duplicate build/sign/upload.
- **Expand/contract is a hard gate** — a backward-incompatible migration in range stops the ship.
- **Finalize the feedback rows at mint (Phase 0)** — sweep `fixed_pending_release` rows to
  `fixed` + `fixed_in_build=R`'s version via a STATE-BASED query, never a time-window one; this
  is the write that actually fires the client's "fixed in build N" notification.
- **A stranded bump commit on abort is harmless** — versions are forward-only; the next
  successful publish just mints from a slightly higher floor.

---

_ac-publish is the terminal, human-facing gate: mint the release, finalize pending feedback rows,
get a fresh green-for-this-SHA proof (via `ac-prove`) + full QA + a heavy 6-dimension review +
migration-safe, tag the proved commit, then ship web (promote, never rebuild) + native. This is
the only place production risk is finally weighed._
