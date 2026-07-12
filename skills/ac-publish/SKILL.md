---
name: ac-publish
disable-model-invocation: true
description: 'The manual, human-triggered release gate — the definitive "ship to production" step. Pins main, mints the single release version bump (Phase 0), then calls ac-prove (ensure --fix-forward) for a fresh ref-pinned full-suite + full device/browser QA proof, checks migrations are expand/contract-safe, then ships web + native. Composes ac-prove (the confidence gate) + ac-distribute (native ship). Triggers: "/ac-publish", "publish", "release to prod", "ship it to production", "cut the release".'
---

# ac-publish — Manual Release Gate

**You are the publish conductor.** Publish is **manual** — Craig triggers it; there is no autonomous
promoter (parallel-execution doctrine §6). Your job spans two things no other skill owns end-to-end:
**mint the single release version** (Phase 0 — relocated here from `ac-batch-close` Phase 2; see
`version-bump-defaults-to-patch`) and act as the *definitive confidence gate* before production —
obtain a fresh, ref-pinned proof that the full suite is green **for the exact commit you're about to
ship** (via `ac-prove`), run the genuinely-new expensive check (full device/browser QA), confirm
migrations are release-safe, fix anything that surfaces **in-session**, then ship web + native.

**You compose, you don't duplicate.** The confidence proof is owned by `ac-prove`
(`skills/ac-prove/SKILL.md`) — you **call** it with `ensure --fix-forward`, you don't re-derive
freshness/dispatch/trust logic yourself. The native build/sign/upload is owned by `ac-distribute` —
you **call** it, never inline it.

> **⚠ Web already deploys at merge.** `ac-merge` triggers a Vercel prod deploy on every wave merge,
> autonomously — so **web content is already live** by the time you run. You are the definitive gate
> for the **native** ship and the migration/QA **checkpoint**; you do NOT gate web content. Web is
> protected upstream instead: `ac-merge`'s apply-timing gate (`rule-migrations-expand-contract`)
> ensures an EXPAND migration is pushed before/at the merge of code that depends on it, so live web
> code never runs ahead of prod schema.

---

## I/O Contract

| | |
|---|---|
| **Input** | `main` at rest, whatever commits have landed since the last release |
| **Output** | Production web deploy (Vercel) + native build shipped (`ac-distribute` → TestFlight / App Store); one minted version bump per publish |
| **Not in scope** | Merging (that's `ac-merge`/`ac-batch-close`), the confidence-proof mechanics (that's `ac-prove`), autonomous triggering |

---

## Phase 0: Preflight

### Create Workflow Tasks (run ledger)

**One task per phase — the ledger tracks this gate's own progress toward a ship.** Create
the fixed tasks below now; **add a "Fix-in-session — round N" task each time Phase 1 or 2
surfaces an issue** (dynamic, per the re-entrant loop — a fix commit re-invokes `ac-prove`
against the new tip, which returns whatever `R` it actually proved per its Returned-SHA
Contract; the Confidence/QA gate task goes back to `in_progress` on that return, it does not
get re-created). `ac-distribute`, invoked from Phase 4, keeps its own ledger — don't duplicate
its build/sign/upload steps here.

```
# Fixed tasks — create upfront:
TaskCreate("Preflight — pin candidate C, mint the release bump (R), push R")
TaskCreate("Confidence/QA gate — ac-prove ensure --fix-forward --ref R (+qa)")
TaskCreate("Migration safety — expand/contract audit since last release")
TaskCreate("Ship — confirm web live, invoke ac-distribute for native")
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

**Forward-only, even on abort.** If a later phase aborts PROFOUND (Phase 3, no fix found) after
this push has already landed, an unreleased bump commit is stranded on `main`. This is harmless:
versions are monotonic and forward-only (`version-bump-defaults-to-patch`), a skipped release
number costs nothing, and mint-once is scoped to *successful* publishes — an aborted attempt
just means the next successful publish mints from a slightly higher floor. Never try to "revert"
the bump to reclaim the number.

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
of the three missing is not proof — treat it as `ac-prove` reporting FAIL and go to Phase 3.
Never trust a stale prior-SHA green; `ac-prove` proves the *exact* ref you pass it.

`ac-prove`'s `+qa` layer is where the one genuinely-new expensive check at publish happens —
full device/browser QA against the release build (`ac-qa-device` + `ac-qa-browser`, per
`qa-gating-craig-owns-visual-agent-functional`: agent runs functional QA, Craig owns visual
sign-off). This is also where every non-peripheral journey's `last_pass` stamp gets refreshed,
so `ac-distribute`'s store gate (`skills/_tools/journey-stamp-check.sh`) sees fresh
review-critical stamps at submission. Any QA blocker → Phase 3.

**Fix-forward re-pin.** If `ac-prove` fixes forward, it returns a **new tip `R′ ≠ R`** (its
Returned-SHA Contract — never assume your input `--ref` still holds). Re-pin `R ← R′` and
re-scope every downstream step (migration diff, review, tag) to `R′`. **Do not re-bump** — a
fix-forward round is a code fix, never a `package.json` touch; the Phase-0 mint already rides
along on `R′` since it descends from `R`, so mint-once holds across re-pins. This loop is
inherently bounded: evidence/bead-writing commits are `[skip ci]` and can't themselves
re-trigger a `reason=prove` dispatch, and `ac-prove`'s own fix-forward mini-loop is capped.

Red (FAIL from `ac-prove`, no valid receipt) → Phase 3 (fix-in-session).

**TaskUpdate("Confidence/QA gate", completed)**

## Phase 2: Migration safety (expand/contract)

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

## Phase 3: Fix-in-session

If `ac-prove` reports FAIL (Step 1 — its own internal fix-forward loop already exhausted, or a
`+qa` blocker it doesn't auto-fix), or migrations (Phase 2) surface an issue: **add a
"Fix-in-session — round {N}" task now** (`in_progress`) and fix it — you may ask Craig. Get to
100% before shipping. File a bead only if the fix is genuinely bigger than this session (then
stop). A fix commit moves the tip, so **re-invoke `ac-prove` against the new commit** (never
re-bump — see Phase 1's Fix-forward re-pin) and adopt whatever `R` it returns — **mark
"Fix-in-session — round {N}" `completed`** (note the new SHA in its description) and set
**"Confidence/QA gate" back to `in_progress`** (it is re-entered, not re-created).

## Phase 4: Ship

**TaskUpdate("Ship", in_progress)**

1. **Bump already minted (Phase 0).** The single mint for this publish already happened, once,
   at Phase 0 — on `R` (or `R′`, if Phase 1 re-pinned). Nothing to verify or re-derive here; just
   carry the version reported there into the Phase 4 report. Do not touch `package.json` again in
   this phase — that counter has exactly one mint per publish.
2. **Web (Vercel).** Prod deploys automatically on push to `main`. Confirm the deploy for
   `R` is live (`vercel ls <project>` / the project's deploy check) — don't redeploy.
3. **Native.** Invoke `ac-distribute` for the actual build/sign/upload (Workflow A → TestFlight, or
   Workflow B → App Store submit). Pass that its preconditions are met (fresh QA PASS from Phase 1's
   `+qa` layer, the Phase-0 mint). `ac-distribute` is check-only on the bump — no re-bump.

**TaskUpdate("Ship", completed)**
**TaskUpdate("Report", in_progress)**

4. **Confirm + notify.** Web live + native uploaded → report the release (SHA, build number, what
   shipped) on Slack.

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
- **Never re-bump on a fix-forward re-pin** — a fix commit is a code fix, never a `package.json`
  touch; adopt whatever `R` `ac-prove` returns and re-scope downstream steps to it.
- **Never inline the native ship** — call `ac-distribute`; don't duplicate build/sign/upload.
- **Expand/contract is a hard gate** — a backward-incompatible migration in range stops the ship.
- **A stranded bump commit on abort is harmless** — versions are forward-only; the next
  successful publish just mints from a slightly higher floor.

---

_ac-publish is the terminal, human-facing gate: mint the release, get a fresh green-for-this-SHA
proof (via `ac-prove`) + full QA + migration-safe, then ship web + native. This is the only place
production risk is finally weighed._
