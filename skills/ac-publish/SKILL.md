---
name: ac-publish
description: 'The manual, human-triggered release gate — the definitive "ship to production" step, run AFTER the loop has merged waves to main. Reads the full-suite CI result SHA-pinned to main, runs full device/browser QA, checks migrations are expand/contract-safe, then ships web + native. Composes ac-merge (bump ownership) + ac-distribute (native ship); it never bumps and never re-runs affected tests. Triggers: "/ac-publish", "publish", "release to prod", "ship it to production", "cut the release".'
---

# ac-publish — Manual Release Gate

**You are the publish conductor.** Publish is **manual** — Craig triggers it; there is no autonomous
promoter (parallel-execution doctrine §6). By the time you run, the loop has already merged its waves
to `main` and fired the loop-close full `test:all` on CI (`ac-land`, §5 Tier 2). Your job is the
*definitive confidence gate* before production: confirm the full suite is green **for this exact
`main`**, run the genuinely-new expensive check (full device/browser QA), confirm migrations are
release-safe, fix anything that surfaces **in-session**, then ship web + native.

**You compose, you don't duplicate.** The version/build bump is owned solely by `ac-merge`
(`skills/ac-merge/references/version-bump.md`) — you **verify** it, never re-bump. The native
build/sign/upload is owned by `ac-distribute` — you **call** it, never inline it.

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
| **Input** | `main` at rest after a loop's waves merged; a loop-close full `test:all` run on CI |
| **Output** | Production web deploy (Vercel) + native build shipped (`ac-distribute` → TestFlight / App Store) |
| **Not in scope** | Merging (that's `ac-merge`), bumping the build number (that's `ac-merge`), autonomous triggering |

---

## Phase 0: Preflight

### Create Workflow Tasks (run ledger)

**One task per phase — the ledger tracks this gate's own progress toward a ship.** Create
the fixed tasks below now; **add a "Fix-in-session — round N" task each time Phase 1 or 2
surfaces an issue** (dynamic, per the re-entrant loop — a fix commit moves `main`, so the
run returns to Phase 1a and re-pins `RELEASE_SHA`; the Confidence/QA gate task goes back to
`in_progress` on that return, it does not get re-created). `ac-distribute`, invoked from
Phase 4, keeps its own ledger — don't duplicate its build/sign/upload steps here.

```
# Fixed tasks — create upfront:
TaskCreate("Preflight — confirm main clean + current, pin RELEASE_SHA")
TaskCreate("Confidence/QA gate — SHA-pinned CI read + full device/browser QA")
TaskCreate("Migration safety — expand/contract audit since last release")
TaskCreate("Ship — verify bump, confirm web live, invoke ac-distribute for native")
TaskCreate("Report — Slack the release summary")

# Dynamic task — add ONE each time a gate fails (not upfront):
TaskCreate("Fix-in-session — round {N}")
# On completion, TaskUpdate its description with what was fixed + the new commit SHA.
```

**TaskUpdate("Preflight", in_progress)**

```bash
git checkout main && git pull --rebase
git status                       # must be clean + up to date with origin
RELEASE_SHA=$(git rev-parse main)
```

If `main` is not clean/current, stop — publish releases exactly what is on `origin/main`.

**TaskUpdate("Preflight", completed)**

## Phase 1: Confidence gate (SHA-pinned CI + full QA)

**TaskUpdate("Confidence/QA gate", in_progress)**

**1a — Read the full-suite CI result, SHA-pinned to `RELEASE_SHA`.** Only a **full** run counts —
that is a `workflow_dispatch` run (loop-close or a prior publish); `push`/`pull_request` runs are
affected-only (§5) and must NOT satisfy this gate. **Guard first** — only body-compass-app has
this workflow today; if `quality-gate.yml` doesn't exist in this repo, fall back to a local full
run as the confidence gate.

```bash
if gh workflow list --json name --jq '.[].name' 2>/dev/null | grep -qi quality-gate; then
  gh run list --workflow=quality-gate.yml --commit "$RELEASE_SHA" \
    --json databaseId,event,status,conclusion,headSha \
    --jq '[.[] | select(.event=="workflow_dispatch")]'
else
  echo "No quality-gate.yml workflow — running local full suite as the confidence gate."
  pnpm test:all 2>&1 | tail -30
fi
```

- **A `success` `workflow_dispatch` run exists for `RELEASE_SHA`** → gate passes; do not re-run.
- **None exists, or `main` moved since loop-close, or it's `failure`** → fire a fresh full run for
  the current HEAD and wait (this is the only re-run, and only when the SHA-pinned read misses);
  no CI workflow → re-run the local full suite instead:

  ```bash
  if gh workflow list --json name --jq '.[].name' 2>/dev/null | grep -qi quality-gate; then
    gh workflow run quality-gate.yml -f reason=publish --ref main
    # poll until a workflow_dispatch run for RELEASE_SHA reports conclusion=success
  else
    pnpm test:all 2>&1 | tail -30
  fi
  ```

Red → Phase 3 (fix-in-session). Never trust a stale prior-SHA green.

**1b — Full QA (device + browser).** This is the one genuinely-new expensive thing at publish
(`qa-gating-craig-owns-visual-agent-functional`): run `ac-qa-device` + `ac-qa-browser` at full depth against the
release build. Agent runs functional QA; Craig owns visual sign-off. Any blocker → Phase 3.
This run is also where every non-peripheral journey's `last_pass` stamp gets refreshed — the
twins write stamps per their Journey stamps doctrine, so `ac-distribute`'s store gate
(`skills/_tools/journey-stamp-check.sh`) sees fresh review-critical stamps at submission.

**TaskUpdate("Confidence/QA gate", completed)**

## Phase 2: Migration safety (expand/contract)

**TaskUpdate("Migration safety", in_progress)**

Shared prod Supabase DB + native builds lag weeks — the one real release hazard
(`shared-prod-migration-collisions`, `app-version-pinned-1.2.0-appstore-resubmission`). Inspect every
migration added since the last release:

```bash
LAST_RELEASE=$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null || git describe --tags --abbrev=0)
git diff --name-only "$LAST_RELEASE"..main -- supabase/migrations/
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

If CI (1a), QA (1b), or migrations (2) surface an issue: **add a "Fix-in-session — round {N}"
task now** (`in_progress`) and fix it — you may ask Craig. Get to 100% before shipping. File a
bead only if the fix is genuinely bigger than this session (then stop — it re-enters the loop).
A fix commit moves `main`, so **return to Phase 1a** and re-pin `RELEASE_SHA` — **mark
"Fix-in-session — round {N}" `completed`** (note the new SHA in its description) and set
**"Confidence/QA gate" back to `in_progress`** (it is re-entered, not re-created).

## Phase 4: Ship

**TaskUpdate("Ship", in_progress)**

1. **Verify the bump (never perform it).** `ac-merge` already bumped `CURRENT_PROJECT_VERSION` at
   merge — confirm the build number advanced since `$LAST_RELEASE`. If it somehow did not, route back
   to `ac-merge` (`references/version-bump.md`); **do not bump here** — that counter has one owner.
2. **Web (Vercel).** Prod deploys automatically on push to `main`. Confirm the deploy for
   `RELEASE_SHA` is live (`vercel ls <project>` / the project's deploy check) — don't redeploy.
3. **Native.** Invoke `ac-distribute` for the actual build/sign/upload (Workflow A → TestFlight, or
   Workflow B → App Store submit). Pass that its preconditions are met (fresh QA PASS from Phase 1b,
   bump already verified). `ac-distribute` is check-only on the bump — no re-bump.

**TaskUpdate("Ship", completed)**
**TaskUpdate("Report", in_progress)**

4. **Confirm + notify.** Web live + native uploaded → report the release (SHA, build number, what
   shipped) on Slack.

**TaskUpdate("Report", completed)**

---

## Remember

- **Manual only** — Craig triggers publish; no autonomous promoter (doctrine §6).
- **Read, don't re-run** — the confidence gate READS the loop-close full run SHA-pinned; it only
  fires a fresh full run when no green run exists for the current `main` HEAD.
- **Never bump** — `ac-merge` owns `CURRENT_PROJECT_VERSION`; publish verifies, never mutates.
- **Never inline the native ship** — call `ac-distribute`; don't duplicate build/sign/upload.
- **Expand/contract is a hard gate** — a backward-incompatible migration in range stops the ship.
- **Fix-in-session, then re-pin** — any fix commit moves `main`; re-read the SHA-pinned gate.

---

_ac-publish is the terminal, human-facing gate: green-for-this-SHA + full QA + migration-safe →
ship web + native. Everything upstream (affected-only waves, one loop-close full run) exists so this
gate is the only place production risk is finally weighed._
