---
name: ac-batch-close
description: 'Trunk-direct batch closing ceremony — a THIN committed-state checkpoint: batch-anchored CI dispatch + one light review pass + commit the batch report (review-mark advance + feedback pending-write). Version mint, tag, deploy-verification, and the heavy 6-dim review all moved to ac-publish (bd-pwt44 epic). Triggers: ''batch close'', ''close the batch'', ''ac-batch-close'', ''ship the batch''.'
---


**You are the conductor closing out a batch of trunk-direct commits on `main`.** Agents commit
directly to `main` — no wave branch, no PR. This is the periodic (or on-demand) closing
ceremony: gate the batch through a light review, dispatch Tier 1 CI for the batch, and commit a
thin batch-report checkpoint that advances the review-mark. **It is deliberately thin** — under
3-5 concurrent conductors the heavy freight (version bump, tag, deploy-verification, the full
6-dimension review) no longer belongs at every batch; that freight consolidates at the publish
boundary (`ac-publish`, bd-pwt44 epic "Publish-Anchored Quality — The Batch-Close Diet"). Fired
once per batch, not per commit.

This skill is a retarget of `ac-merge` (`skills/ac-merge/SKILL.md`) for the trunk-direct flow.
`ac-merge` is **unchanged** and remains the PR-merge path for legacy branches (dependabot,
human feature branches — `.claude/legacy-branches.txt`). Nothing from `ac-merge` is silently
dropped: the PR ceremony below is removed with cause; everything else is either retargeted to
the batch anchor or relocated to `ac-publish` (also with cause, see below).

## Removed from ac-merge (PR ceremony — `ac-merge` still owns this path)

There is no branch and no PR on trunk-direct, so these have nothing to attach to:

- `gh pr create`, PR body assembly (`ac-merge/references/pr-body-template.md`), `gh pr merge`,
  `--delete-branch`, local branch deletion, branch-rebase-onto-main.
- The interactive "Does this project have GitHub CI checks…" `AskUserQuestion` — Tier 1 CI
  dispatch (Act 1) is now a fixed mechanism, not a per-project optional wait; the only
  remaining conditional is a file-existence check (does `quality-gate.yml` exist at all).

## Removed from this skill's own earlier (7-phase) design — relocated to `ac-publish`

This skill previously carried a version bump, a git tag, and a deploy-verification act of its
own (pre-`bd-pwt44.3`). **All three are gone from batch-close entirely** — they are not
"skipped conditionally," they do not exist in this skill anymore:

- **Version bump + native-surface propagation** → relocated to `ac-publish` Phase 0
  ("mint-at-publish" — `ac-publish/SKILL.md`, `version-bump-defaults-to-patch`). Batch-close
  never touches `package.json`.
- **Git tag** → relocated to `ac-publish` (tags at the explicit release candidate `R`, once
  the publish-side heavy-review/promote work lands — bd-pwt44.6). Batch-close never tags.
- **Deploy verification (Vercel served-version + intermediate-commit scan, native
  archive-watch-head)** → not batch-close's job anymore; `ac-publish` is the definitive
  ship/verify gate for the boundary that actually matters (mint + prove + ship).
- **The full 6-dimension review panel** → stays `ac-review`'s own standalone mechanism
  (feature-branch / on-demand) and becomes `ac-publish`'s heavy pre-tag gate (bd-pwt44.6);
  batch-close keeps only the single light `VERDICT` pass described in Act 2 below.

If you're looking for any of the above, it now lives in `ac-publish/SKILL.md`.

Everything else below is the same mechanism, retargeted anchor and audience.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | `main`, with implementation commits already pushed directly since the last batch anchor (no branch, no PR) |
| **Output**       | Batch reviewed (light `VERDICT: APPROVED`), Tier 1 CI confirmed for the batch, batch report committed, review-mark advanced, in-scope `triage,feedback` beads marked `fixed_pending_release` |
| **Not in scope** | Version bump/tag, deploy verification, the 6-dim review panel (all `ac-publish`) |
| **Artifacts**    | Batch-close summary in `.claude/reviews/batch/`, scratch in `$ARTIFACTS_DIR`                |
| **Verification** | Light-review `VERDICT: APPROVED`; Tier 1 CI dispatch green for the batch                    |

## Prerequisites

- On `main` (trunk-direct — no branch-name check; if invoked on a branch, that's `ac-merge`'s job, not this skill's)
- `gh` CLI authenticated
- Agent Mail MCP tools available (`acquire_build_slot`/`renew_build_slot`/`release_build_slot`) —
  see Build Slot below
- Implementation commits already landed directly on `main` (from `ac-implement`, trunk-direct — no wave branch to check out)
- A `quality-gate.yml` workflow with `workflow_dispatch` inputs `reason` + `batch_anchor`
  (added by the sibling bead bd-u2lo1.10). If the workflow doesn't exist yet, Tier 1 CI
  dispatch (Act 1) is skipped silently — same escape hatch `ac-merge`'s CI-config question
  offered, now inferred from file presence instead of asked.

---

## Session Identity (Tier 1 — mint FIRST, before the build slot)

ac-batch-close is a **Tier-1 session**: on a red Tier-1 CI dispatch it **fix-forwards** —
edits code, commits, pushes to `main` (Act 1 triage). Mint a unique identity at ceremony
start (doctrine: `agent-mail/references/agent-identity.md` — Tier 1 lifecycle). Minting is also the
**prerequisite for the build slot**: `acquire_build_slot` needs a real `registration_token`
for a pre-existing identity, and the mint is what yields one — a loop-spawned session that
skips this step holds no token (this closes bd-kskxg's token-less graceful-degrade path):

**Run the mint + token/export discipline per `agent-mail/references/session-procedure.md` (§ Mint,
§ Export)** — capture `name` + `registration_token`; the build slot below and every
fix-forward commit consume them.

---

## Build Slot (advisory coordination across concurrent conductors)

This ceremony can be invoked more than once concurrently under 3-5 concurrent conductors
(`trunk-direct-execution-doctrine`). Wrap the run in an **advisory** Agent Mail build_slot —
`acquire_build_slot` **always grants** and returns a `conflicts` list; it never blocks or
refuses (memory `agent-mail-build-slot-advisory`). Correctness is entirely on the caller:

```
acquire_build_slot(project_key=CANONICAL_PROJECT_KEY, agent_name=AGENT_NAME, slot="batch-close:main", registration_token=<the token from macro_start_session above>, ttl_seconds=<covers the expected CI-poll wall-clock>)
  → read the returned `conflicts` list
  → if another agent's active lease is present, this is advisory, not a lock: proceed only if
    your batch anchor genuinely does not overlap theirs (different ANCHOR..HEAD ranges are
    fine); if ranges overlap, back off and retry after a short bounded wait — report the
    conflict, never proceed blind
  → renew_build_slot before TTL expiry if the ceremony runs long (the CI poll below can eat
    most of a lease); renew CANNOT resurrect a lapsed lease — check its return and hard-stop if
    the lease is already gone
  → release_build_slot() at the very end, after Act 3's report commit lands — release even on
    abort, so a stalled conductor doesn't leave a stale advisory lease for the next run
```

> **Token custody + concurrency assertion (bd-kskxg field-test, resolved).** The Session
> Identity mint above gives this ceremony a real `registration_token`, so `acquire_build_slot`
> succeeds — there is no longer a token-less path to degrade around. What remains, unconditionally,
> is the concurrency assertion the slot only ever *hinted* at: assert `git rev-parse origin/main`
> equals your local `HEAD` immediately before and after each CI-affecting step (dispatch, any
> fix-forward push, the Act 3 report commit). A mismatch is the real signal a concurrent conductor
> moved `main` under you — the slot is advisory (memory `agent-mail-build-slot-advisory`), so this
> assertion, not the lease, is what actually protects the range.

No mutual exclusion is enforced by the primitive itself — this is a presence signal for a
conflicting concurrent run to notice, not a queue or a lock.

---

## Run Ledger

Declare the run ledger per `ac-pipeline-builder/references/run-ledger.md` (pattern + resume doctrine there).
This ceremony's table:

```
TaskCreate (one per section, in run order):
  1.  Acquire build slot; determine batch anchor + scope + quality gate   in_progress
  2.  QA smoke gate (conditional)                                         pending
  3.  Gitleaks scan + Tier 1 CI dispatch + fix-forward (Act 1)            pending
  4.  Light review gate — VERDICT required (Act 2)                       pending
  5.  Feedback pending-write + commit batch report (Act 3)               pending
  6.  Report + Slack + release build slot + finalize                     pending
```

State vars this run persists to `$STATE`: `ANCHOR`, `DISPATCH_RUN_ID`.

### Determine the Batch Anchor

No rebase step — trunk-direct commits already landed on `main` directly, there's nothing to
rebase onto. The only sync risk is a **concurrent pusher race** (another agent pushed to
`main` since your last fetch): pull-rebase, never force.

```bash
git fetch origin main
git pull --rebase origin main   # never --force; re-verify HEAD after
```

The **batch anchor** — same mechanism `ac-review` uses to find its scope (`ac-review/SKILL.md`
Phase 1 "Scope Detection"), computed identically here so both skills agree on the range:

> <!-- net-growth-ok: bd-kudrb — the single-writer invariant and its self-check tripwire must
> live AT the probe. This bug's whole shape is silent under-scoping (no error, just a wrong
> range); a reader who reaches this snippet without the invariant in view re-introduces it. -->
> **The probe is only correct because `.claude/reviews/batch/` has exactly ONE writer per
> ceremony — Act 3 below (bd-kudrb).** `ac-review` stages its report in the sibling
> `.claude/reviews/pending/`; Act 3 `git mv`s it into `batch/` in the same commit as the summary.
> Before that split `ac-review` committed straight into `batch/` mid-batch, so this probe
> returned *that* report — a commit INSIDE the range it bounds. It failed SILENTLY: one live
> case would have shrunk a 7-commit batch to 2 and still reported success.

```bash
ANCHOR=$(git log -1 --format=%H -- .claude/reviews/batch/)
if [ -z "$ANCHOR" ]; then
  # Bootstrap fallback: no batch review-mark exists yet. The `batch_anchor`
  # workflow input is a COMMIT SHA (quality-gate.yml peels it via `^{commit}`
  # and diffs `<anchor>...HEAD`), so resolve the newest v* tag to the SHA it
  # POINTS TO — never pass the bare tag NAME. Passing a tag name works only
  # while checkout fetches tags (fetch-depth:0); if that ever narrows, an
  # unresolvable tag name silently degrades to the full-scope root-commit
  # fallback. A resolved SHA keeps the contract honest.
  ANCHOR=$(git rev-list -n1 "$(git describe --tags --match 'v*' --abbrev=0)")
  ANCHOR_FROM_BOOTSTRAP=1
fi

# Self-check tripwire (bd-kudrb) — belt-and-braces on top of the single-writer rule above.
# A well-formed mark is a `batch-close:` commit. Anything else touching `.claude/reviews/batch/`
# means some other skill wrote there mid-batch and this anchor is INSIDE its own range; that
# under-scopes the batch silently, so fail LOUD here instead.
if [ -z "$ANCHOR_FROM_BOOTSTRAP" ]; then
  ANCHOR_SUBJECT=$(git log -1 --format=%s "$ANCHOR")
  case "$ANCHOR_SUBJECT" in
    batch-close:*) ;;
    *)
      echo "FATAL: batch anchor $ANCHOR is not a batch-close mark." >&2
      echo "  subject: $ANCHOR_SUBJECT" >&2
      echo "  Something other than ac-batch-close Act 3 wrote to .claude/reviews/batch/." >&2
      echo "  Using it would silently UNDER-SCOPE this batch (bd-kudrb)." >&2
      echo "  Fix the offending writer (reports belong in .claude/reviews/pending/), then" >&2
      echo "  step the anchor back to the previous batch-close mark:" >&2
      echo "    git log --format='%H %s' -- .claude/reviews/batch/ | grep -m1 ' batch-close:'" >&2
      exit 2
      ;;
  esac
fi

BATCH_RANGE="$ANCHOR..HEAD"
echo "ANCHOR=$ANCHOR" >> "$STATE"
```

Deterministic `$ARTIFACTS_DIR` per `ac-pipeline-builder/references/run-id.md` (prefix `batch-close`) — trunk-direct
has no wave branch to key on, so the key is the anchor SHA instead of a branch slug:

```bash
# Mint RUN_ID if the orchestrator didn't hand one down (contract: ac-pipeline-builder/references/run-id.md
# mint-if-absent rule). Not folded into ARTIFACTS_DIR below: this dir is keyed on the
# anchor SHA (stable across a resumed/dropped session), and RUN_ID is re-minted per
# invocation — appending it would break resume detection (`[ -f "$STATE" ]` below relies
# on recomputing the SAME path on retry).
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
ARTIFACTS_DIR="/tmp/batch-close-${ANCHOR:0:8}"
mkdir -p "$ARTIFACTS_DIR"
STATE="$ARTIFACTS_DIR/state.env"
[ -f "$STATE" ] && . "$STATE"   # on resume, reload instead of re-deriving
```

### Gather Batch Context (retarget of "Gather PR Context" — no PR body, just scope)

```bash
br list --json > "$ARTIFACTS_DIR/beads.json"           # the claim set this batch is closing. If dcg blocks a write here (variable-built redirect target), do NOT bypass — see ac-pipeline-builder/references/shell-guardrails.md
git log $BATCH_RANGE --oneline > "$ARTIFACTS_DIR/commits.txt"
git diff $BATCH_RANGE --stat > "$ARTIFACTS_DIR/diff-stats.txt"
```

No PR body is constructed. This context feeds the Act 3 batch-close report only.

Mark ledger task 1 `completed`; `TaskUpdate` task 2 `in_progress`.

---

## Act 1 — Batch-Anchored CI Dispatch

Covers the pre-flight quality gate, the QA smoke safety net, a gitleaks backstop, and the
batch's single Tier 1 CI dispatch.

### Quality Gate (post-sync)

Same order `ac-merge` mirrors from `ac-pipeline-builder/references/verification-gate.md` §Format-first — format FIRST
(auto-fix), then type-check, lint, tests:

```bash
# format (auto-fix) -> type-check -> lint -> tests
# Tests = the AGGREGATED affected run, pinned to the BATCH ANCHOR (the trunk-direct
# equivalent of ac-merge's origin/main merge-base pin — here we're already on main, so
# the anchor is the older boundary that matters):
VITEST_AFFECTED_REF=$ANCHOR pnpm test
```

> **Runner self-contention (bd-kskxg field-test).** On a single self-hosted Mac runner, this
> local affected pre-flight and the Tier 1 CI dispatch fired below run on the SAME machine —
> executing the local suite while CI is already dispatched makes both contend for one runner and
> stretches wall-clock. Sequence them: finish (or skip) this local pre-flight BEFORE firing the
> dispatch; never overlap them.

**If any fail:** fix before proceeding — same rule as `ac-merge`: never dispatch Tier 1 CI with
failing local checks.

### QA Smoke Gate (conditional — safety net)

This is the **post-push re-proof** (J5 — the trunk-direct successor of ac-merge's
post-rebase re-proof; only the trigger-event name changed). **Run the ceremony smoke net
per `ac-pipeline-builder/references/verification-gate.md` § Ceremony smoke net** with `<RANGE>` =
`$ANCHOR...HEAD` — device-twin conditions, browser twin, FAIL escalation (STOP before
proceeding), `mac-needed` note, and the qa-blocker STOP all live there.

Mark ledger task 2 `completed`; `TaskUpdate` task 3 `in_progress`.

### Gitleaks scan (CI backstop — bd-pwt44.4)

The pre-commit `gitleaks protect --staged` hook is `--no-verify`-bypassable — zero CI
enforcement existed before. `bd-pwt44.4` wires a gitleaks step into `quality-gate.yml`'s
batch-close leg, scanning `$BATCH_RANGE` (honoring the repo-root `.gitleaksignore`). Nothing
extra to invoke here — that step rides inside the SAME `reason=batch-close` dispatch fired
below, not a separate call. If bd-pwt44.4 hasn't landed yet, the dispatched workflow simply
doesn't have that step (same silent-gap handling as any other pre-existing-infra dependency).

### Fire the Tier 1 CI dispatch

```bash
gh workflow run quality-gate.yml -f reason=batch-close -f batch_anchor="$ANCHOR"
```

If `quality-gate.yml` has no `workflow_dispatch` trigger yet (pre-bd-u2lo1.10), skip this
phase silently and note the gap in the Act 3 report — do not block the batch on
infrastructure another bead is landing.

### Poll for the dispatched run against HEAD — FOREGROUND ONLY

Same bounded-wait discipline as `ac-merge`'s PR-checks poll (`ac-pipeline-builder/references/delegation-contract.md`:
hard-capped, timeout-terminal — a stalled CI run is a reportable outcome, not a pause). **This
poll runs in the foreground, inside this turn, to completion or the cap below — never fork it
to a background process that outlives the session.** The `$STATE` persistence above covers a
session that drops and resumes; it does not license spawning a detached poller that keeps
running after this turn ends.

> **Cap must be WIDE — the wall-clock is batch-CONTENT-dependent.** A batch whose diff touches
> `scripts/` or CI config correctly defeats `vitest-affected` selection (fail-closed, by design)
> and runs the **FULL suite (~19min observed, run 29243312437)**, not the ~4-min affected leg.
> The poll below is therefore capped at ~25min (`seq 1 50` at 30s), NOT the old 10min — a 10-min
> cap times out mid-run on any full-suite-fallback batch.
>
> **Invoke this poll with Bash `timeout: 600000`** (the tool's 120000ms default silently kills a
> multi-minute poll mid-loop — cost 2 extra Bash turns, RUN_ID 20260713-222115). 600000ms is the
> Bash-tool MAX (10min), which is shorter than the 25-min logical cap, so a full-suite-fallback
> run will span **2–3 foreground Bash invocations**: each returns with `$STATUS` still not
> `completed`, and you re-invoke (the loop re-resolves `RUN_DB_ID` from `HEAD_SHA` each call, so
> it resumes cleanly) until `completed` or the ~25-min logical cap is exhausted. Re-invoking in
> the same turn is NOT backgrounding — it stays foreground.

```bash
HEAD_SHA=$(git rev-parse HEAD)
# Resolve the dispatched run's id ONCE (list + match by headSha to get its databaseId), then
# poll THAT id deterministically with `gh run view <id>` — re-listing + jq-selecting by headSha
# every iteration is fragile (bd-kskxg field-test). The run may take a cycle to register, so
# keep resolving until the id is known, then switch to the deterministic view.
RUN_DB_ID=""
# ~25-min logical cap (50 × 30s) — wide enough for a full-suite-fallback batch (~19min).
# Invoke with Bash timeout: 600000; a full-suite run spans 2-3 foreground re-invocations
# (this loop re-resolves RUN_DB_ID from HEAD_SHA each call, so re-invoking resumes cleanly).
for i in $(seq 1 50); do
    sleep 30
    if [ -z "$RUN_DB_ID" ]; then
        RUN_DB_ID=$(gh run list --workflow=quality-gate.yml --branch main \
          --json databaseId,headSha --limit 10 2>/dev/null \
          | jq -r --arg sha "$HEAD_SHA" '[.[] | select(.headSha == $sha)][0].databaseId // empty')
        [ -z "$RUN_DB_ID" ] && { echo "Run not registered yet... ($i/50)"; continue; }
    fi
    MATCH=$(gh run view "$RUN_DB_ID" --json databaseId,status,conclusion,url 2>/dev/null)
    STATUS=$(echo "$MATCH" | jq -r '.status // empty')
    if [ "$STATUS" = "completed" ]; then
        echo "Dispatch run completed."
        break
    fi
    echo "Waiting... ($i/50)"
done
echo "$MATCH" >> "$ARTIFACTS_DIR/dispatch-run.json"
```

### Triage on failure (same core-work rule as ac-merge)

**THIS IS YOUR CORE WORK. Do not delegate triage.** Source of findings here is the dispatch
run's failed jobs (`gh run view <id> --log-failed`) — not PR comments/agent reviews (the light
review is Act 2, which runs after this act). Same classification `ac-merge` uses:

- **Auto-fix:** obvious CI failures (lint/type/format), clear single-fix issues.
- **Conductor decides:** high-severity items with clear fixes, easy improvements.
- **Present to user:** architectural/debatable items (Exhaust Rule applies if headless —
  `br create -t bug --labels ci-finding,unrefined` rather than blocking silently — CI is the catch stage;
  its eventual close cites the regression test per bead-conventions § Per-type close artifacts).

> **Correlated failures → escalate to the LCA, don't fix-forward N times.** If **2+** batch
> beads fail for one shared root cause (same wrong contract/assumption/parent-decomposition
> error, not just the same file), do not queue per-bead fix-forwards: trace them to their
> lowest common ancestor and route that parent node back to `/ac-bead-refine`, keeping
> closed+verified beads frozen. Full detection + frozen-region rule: `ac-review` § Correlated-
> Failure Escalation (LCA Repair). Per-bead fix-forward remains correct for uncorrelated,
> single-bead CI failures.

<!-- net-growth-ok: ac-3rb — fix-forward edited product code with NO file reservation (Tier-1 obligation); this seals the protocol gap via the shared canon -->
**Reserve the files you are about to fix BEFORE editing** (`agent-mail/references/session-procedure.md`
§ Reserve, bead ac-3rb — fix-forward is Tier-1 product-code editing in the shared
checkout; release with the rest at teardown § Release). Apply fixes, then commit under
the minted Tier-1 identity — **re-assert `AGENT_NAME` inline in
the fix-forward commit shell** (exports don't survive across bash calls; the pre-commit guard
reads it, and a fix-forward as `FoggyCreek` would be a Tier-2-boundary violation):

```bash
export AGENT_NAME=<minted-name>   # re-assert inline — the Phase-0 mint's name
git commit -m "batch-close: fix-forward CI failure — <summary>" -- <fixed files>
git push origin main || { git pull --rebase origin main && git push origin main; }
```

Re-dispatch, re-poll (5-minute cap, same as `ac-merge`'s re-poll) — **still foreground**, never
backgrounded. **If checks still fail after fixes:** present failures and ask abort vs
proceed-anyway (interactive), or file a `qa-blocker` bead + STOP (autonomous/headless).

Mark ledger task 3 `completed`; `TaskUpdate` task 4 `in_progress`.

### Verdict comment (VERDICT grammar)

The Tier 1 CI dispatch result is a verification verdict — record it on the batch's anchor /
scope beads as a structured comment per **`beads-standards` § Verification verdicts**
(exact CLI: `br comments add <id> "VERDICT: passed: <detail>"` — plural `comments`
subcommand only; do not invent a singular verb):
`VERDICT: passed:` on a green dispatch, `VERDICT: failed:` when the run red-Xed (put the
fix-forward SHA in the detail), `VERDICT: blocked:` for a stalled/timeout-terminal run. CI
is a *verifier* ceremony — the verdict is written here, never by the implementer whose
commit is under test (Goodhart guard). A finding filed from a CI failure carries the
`ci-finding` catch-stage label (the CI token in beads-standards' closed set) plus
`discovered-from: <bead-id|unknown>`.

---

## Act 2 — One Light Review Pass

This ceremony **NEVER closes an unreviewed batch** — the gate is unconditional. This is
deliberately **NOT** `ac-review`'s full 6-dimension panel (correctness/security/perf/
architecture/test-quality/contracts) — that panel remains `ac-review`'s own mechanism when run
standalone on a feature branch, and becomes `ac-publish`'s heavy pre-tag gate (bd-pwt44.6).
Batch-close's gate is a single lightweight `VERDICT` pass, same as before this bead's diet.

What widens on trunk-direct is only the *source* of the review verdict: Act 2 accepts **either**
a standard `ac-review` run **or** an equivalent-review artifact the invoking conductor
pre-supplies. In both cases the accepted artifact must carry an explicit `VERDICT:` line and
must reach `.claude/reviews/batch/` **only via Act 3's single commit** — never by a writer of
its own (bd-kudrb). Until then it lives in `.claude/reviews/pending/`.

**(a) Pre-supplied equivalent-review artifact.** If the delegation prompt hands you a completed
review of this same diff — e.g. `ac-hygiene`'s 7-lens panel run report (same severity bar,
already adversarial) — do **not** re-run `ac-review` on the same diff (double-review). Take that
report as the review artifact: confirm it contains an explicit `VERDICT:` line, place it in
`.claude/reviews/pending/` (uncommitted, or committed there — either way it is invisible to the
anchor probe), then carry it into `.claude/reviews/batch/` via **Act 3's commit** (the same
commit that lands the batch-close summary), so the trunk-direct review-mark is backed by a
committed artifact exactly as the `ac-review` path is. Read its `VERDICT:` and gate on it below.
No supplied artifact, or one lacking an explicit `VERDICT:` line → fall through to (b); never
proceed unreviewed.

**(b) No artifact supplied → run `ac-review` yourself.** There is no PR to attach a review to, so
`ac-review` runs directly on `main` and its `VERDICT` gates this ceremony — the same severity bar
`ac-merge` enforced at PR-merge, moved here since there's no PR-merge choke point left on
trunk-direct. Delegate (do not inline its work — `ac-review/SKILL.md` is a full skill, not a
sub-step of this one):

> "Run ac-review on main (trunk-direct mode, single light pass — not the full 6-dim panel unless
> ac-review's own default routing says otherwise). report_dest=.claude/reviews/pending/"

`ac-review`'s own Phase 6 commits its findings report to that destination and pushes. Because
`pending/` is a sibling of `batch/`, that commit does **not** touch the review-mark path and the
Act 1 anchor probe never sees it — Act 3 below is the only commit that advances the mark
(bd-kudrb). **Do not pass `report_dest=.claude/reviews/batch/`**: that is the exact wiring that
made the anchor probe return a commit inside its own range.

**Read the supplied-or-produced artifact for `VERDICT:`.**

- **`VERDICT: APPROVED`** → proceed to Act 3.
- **`VERDICT: NEEDS_DECISION`** → STOP. Do not dispatch further, do not commit the batch report.
  Report the gap the same way `ac-review` reports it (missing reviewer dimension, open
  `qa-blocker`, or unresolved decision bead) — never proceed past a `NEEDS_DECISION` verdict.

Mark ledger task 4 `completed`; `TaskUpdate` task 5 `in_progress`.

---

## Act 3 — Commit the Batch Report (feedback pending-write + review-mark advance)

### Feedback write-back — PHASE 1 (pending, not final)

**Two-phase model** — full spec, error-handling policy, unit test cases:
**`../ac-merge/references/feedback-writeback-hook.md`**. Batch-close marks rows **PENDING**
here; the final `status='fixed'` + `fixed_in_build` stamp — the transition that actually fires
the client's "fixed in build N" notification (`features/feedback/lib/loopback.ts:190`,
`isNowFixed = row.status === 'fixed'`) — is deferred to `ac-publish` at mint (bd-pwt44.6).
**Do not write `status='fixed'` here.** Batch-close has no build number to attach to it, and
writing the literal string `'fixed'` would notify the user weeks early with a null build.

**Selector: run the canonical Step 1 from that spec — do NOT hand-roll it here.** It needs both
`--status closed` (bare `br list` excludes closed beads, so an inline `.status == "closed"` filter
selects nothing) AND scoping to the bead IDs named in `$BATCH_RANGE`'s commits (bd-2tlwf).

For each matching bead, resolve `linked_bead` (parsed from the bead description's
`Source: public.feedback_reports / id=<uuid>` line) and call `runFeedbackPendingWriteHook`
(`body-compass-app/lib/pipeline/merge-feedback-writeback.ts`) to write
`status='fixed_pending_release'` (no `fixed_in_build`) back to the row via the service-role
client. If a bead's `linked_bead` is unset or the row isn't found: log a warning and continue —
**never abort the batch-close for a write-back failure.** There is no web/native or
build-number branch here (that distinction only matters at publish, once a real build number
exists).

Log in the batch report:

```
Feedback pending-write: <N> rows marked fixed_pending_release
  <N> warnings (missing linked_bead or row not found — see log)
```

### Commit the batch report

Write `.claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md` — the batch-close summary,
distinct from `ac-review`'s own findings report staged in `.claude/reviews/pending/` in Act 2.
**Both files land in this one commit** (bd-kudrb): the summary is created here, and the Act 2
findings report is `git mv`'d out of `pending/` into `batch/` so the ceremony leaves exactly one
mark and `pending/` is empty again for the next batch.

**Single source of truth for the shared sections:** `ac-review/references/report-template.md`.
The **Summary**, **Beads Completed**, **Changes**, **Test Coverage**, **Known post-merge tails**,
and **Also carried** sections are that template's — do NOT re-specify their contents here (a
second hand-rolled copy is exactly the drift bug ac-vgt filed). Fill them per the template's
field descriptions; `$BATCH_RANGE` is the range those sections' `git diff`/`git log` commands
key on. Batch-close's own addition beyond the template is a short **Feedback write-back** line
(the pending-write count logged above) — there is no Deploy section anymore (deploy
verification moved to `ac-publish`). **Known-action findings surfaced during the batch
(defects, decision forks, refinements you KNOW need action beyond this ceremony) are filed
as beads (`unrefined`) and cited by ID in this report, never left as prose-only** — a
prose-only findings channel orphans once its consumer closes
(`rule-known-action-capture-beads-not-prose`; bd-pwt44 lesson).

**Worker cost line (per-child / per-batch).** Add a one-line **Worker cost** entry to the
report: per-child implementer usage (model + token cost, which the conductor received in each
engineer's task-completion notification) and the batch total. This is where per-bead TOKEN cost
lives — deliberately at batch/child granularity, never per bead (a child can't see its own token
usage, so a per-bead split would be fabricated precision; see `ac-implement`'s worker-identity
stamp, which carries model/session/skill@version/duration per bead but explicitly NOT tokens).
Format: `Worker cost: <child-session> (<model>) <tokens>; … — batch total <tokens>`.

```bash
export AGENT_NAME=<minted-name>   # re-assert inline (Phase-0 mint) — this commit is the operative review-mark; attribute it to the minted identity, not FoggyCreek

# Carry Act 2's findings report from the staging sibling into the mark directory (bd-kudrb).
# `git mv` when it was committed to pending/; a plain `mv` + `git add` when it is still
# untracked. Both files must be in the SAME commit — that is what keeps `batch/` single-writer.
# net-growth-ok: bd-f72as — the carry snippet IS the review-mark writer; a wrong pick makes the
# mark attest to an unreviewed diff. The fail-loud branch and its operator guidance must be at
# the selection site, inline in the runnable block, or a hurried child re-derives the positional
# pick that near-missed three ceremonies in one day.
# Select the report by CONTENT, not position. It must claim THIS batch's anchor in its own
# `**Range:**` line (ac-review on main bases its range on the same review-mark this ceremony
# anchors on, so the base sha matches by construction). A positional pick (`ls | head -1`) is
# lexically-OLDEST-first and near-missed three ceremonies in one day; `pending/` legitimately
# accumulates, because a withheld close (stop condition C2) deliberately leaves its report
# there. Carrying the wrong file makes the review-mark attest to a diff nobody reviewed while
# the real artifact stays in `pending/` forever — a clean-looking review blackout (bd-f72as).
CARRIED=""
PENDING_REPORT=$(grep -lE "Range:.*${ANCHOR:0:8}[0-9a-f]*\.\." .claude/reviews/pending/*.md 2>/dev/null)
N_PENDING=$(printf '%s\n' "$PENDING_REPORT" | grep -c . || true)
if [ "$N_PENDING" -ne 1 ]; then
  echo "FATAL: cannot identify this batch's review artifact — carrying NOTHING." >&2
  echo "  anchor: $ANCHOR" >&2
  echo "  reports in pending/ claiming that anchor: $N_PENDING (need exactly 1)" >&2
  echo "  present: $(ls -1 .claude/reviews/pending/*.md 2>/dev/null | tr '\n' ' ')" >&2
  echo "  0 matches -> Act 2's review did not run, or wrote no machine-parseable" >&2
  echo "     '**Range:** <base>..<head>' line (ac-review Phase 6 requires it). Re-run Act 2." >&2
  echo "  >1 matches -> two artifacts claim the same anchor; a human picks. Do NOT guess." >&2
  echo "  There is NO positional fallback: an unidentifiable artifact is 'unknown', and" >&2
  echo "     unknown must never collapse to ok. Only after verifying a report's Range" >&2
  echo "     actually covers \$BATCH_RANGE may a conductor set PENDING_REPORT by hand." >&2
  exit 1
fi
CARRIED=".claude/reviews/batch/$(basename "$PENDING_REPORT")"
git mv "$PENDING_REPORT" "$CARRIED" 2>/dev/null \
  || { mv "$PENDING_REPORT" "$CARRIED" && git add "$CARRIED"; }

git add ".claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md"
# Pathspec-on-commit (bd-kskxg field-test): the trailing `-- <report path>` scopes the commit to
# ONLY these files, so pre-staged foreign WIP in the shared checkout cannot be swept into the
# batch-report commit (happened live; a soft-reset recovered it). The `git add` above is still
# needed because the report is a brand-new untracked file. $CARRIED is included in the pathspec
# so the moved findings report rides in this same commit (both its delete-from-pending and
# add-to-batch halves are staged by the `git mv` above).
git commit -m "batch-close: ${ANCHOR:0:8}..$(git rev-parse --short HEAD) — {N} beads, {commit count} commits" \
  -- ".claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md" ${CARRIED:+"$CARRIED" ".claude/reviews/pending/"}
git push origin main || { git pull --rebase origin main && git push origin main; }
```

**Why this commit is the operative review-mark — and the ONLY writer of that path (bd-kudrb):**
the probe takes the **latest** commit touching `batch/`. Correctness used to rest on ordering
("this commit lands later, so it supersedes `ac-review`'s"), which holds for the *next* batch but
not this one — Act 1's probe runs **after** Act 2's review, so it returned `ac-review`'s report,
inside the range being closed. Ordering cannot fix a probe that runs mid-ceremony; routing the
report through `pending/` removes the ambiguity at the source.

**This must be the LAST commit of the ceremony.** If a fix-forward round is still needed after
this point, that means Act 1 (or Act 2) isn't actually done — re-run from there and redo this
commit last, again. Nothing pushes after the batch report.

### Ceremony pool ack + post-ack drain (bd-chd5p.2 / Item 1)

When the loop handed a **pool-backed** batch (pool-only, mixed, or pure risk-solo that
snapshot'd into `/tmp/loop-pool-<RUN_ID>.json`), Act 3 **acks** after the report commit:

1. Under `flock` on `/tmp/loop-pool-<RUN_ID>.json`, remove **only this batch's
   `in_flight` IDs** (never whole-file wipe).
2. Non-pool ceremonies (planned-wave / pure risk-solo with no snapshot) **no-op** the
   pool — leave `pending`/`in_flight`/`risk_queue` intact.
3. On ceremony **failure** before this ack: re-merge `in_flight` → `pending` (do not
   drop IDs); recompute `first_close_ts = min(closed_at)`.
4. After successful ack, if `in_flight` is empty → run the **drain sequence**
   (`ac-pipeline-builder/references/ceremony-batching-pool.md` § Drain sequence): risk_queue head first (mixed or
   pure risk-solo), else fire opportunity on `pending` (soft-8 / ~3h window / line-floor
   N≈800, hard-10 ceiling), else stop.

Ceremony batch range for CI/report scope uses `ac-pipeline-builder/references/risk-classification.md`
**binding #1** (pool-only union of `in_flight` `pre_sha..close_sha`; mixed ∪ risk bead
range; planned-wave/pure risk-solo = that batch's range).

Mark ledger task 5 `completed`; `TaskUpdate` task 6 `in_progress`.

---

## Beads-closed gate

`ac-merge` never invoked `beads-closed-gate.sh` directly — only `ac-loop` does, as its own
pre-merge gate, upstream of whichever closing skill it calls. Nothing to retarget here: the
gate stays `ac-loop`'s responsibility (its assignee-scoping rewrite is a sibling bead and needs
no change in this skill).

## Documented technique — the union allocator pattern (for the record)

`ac-pipeline-builder/scripts/allocate-wave-branch.sh` is deleted alongside this skill's creation —
trunk-direct has no numbered wave branches to allocate. Its collision-guard pattern is worth
remembering for **any future numbered-artifact allocation**: compute NEXT from the union of
live refs ∪ main-log merge/commit messages ∪ tags — never refs alone (`git fetch --prune` drops
merged refs, so a refs-only scan can reuse a shipped number). Re-derive this pattern fresh if a
future skill needs to allocate a numbered artifact; don't resurrect the deleted script.

---

## Report + Slack + Finalize

### Report

```markdown
## Batch Closed: {ANCHOR short-sha}..{HEAD short-sha}

**Batch report:** `.claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md`
**Beads completed:** {count}
**Commits:** {count}

### Light Review
**VERDICT:** APPROVED — {N} auto-fixed, {M} decisions resolved

### Tier 1 CI
{run URL} — {green | fixed after N rounds}

### Feedback write-back
{N} rows marked fixed_pending_release ({M} warnings)

### What Shipped
{1-3 bullet summary}
```

No Deploy section — deploy verification is `ac-publish`'s job now, not this ceremony's.

### Slack Notify

```bash
slack-send --channel sofi --card \
  --title "Batch closed" \
  --body "Batch closed — ${ANCHOR:0:8}..$(git rev-parse --short HEAD), ${N} beads, ${COMMIT_COUNT} commits. CI: ${RUN_URL}. Review: APPROVED."
```

> **If the batch produced visual evidence, UPLOAD the images — don't just cite `/tmp`
> paths in the card body** (Craig's directive — `ac-pipeline-builder/references/qa-shared.md` § Conductor /
> worker evidence protocol). A `/tmp` path is unreachable from his phone and transient.
> Send only the LIVE decision surface, with context (bead id + SHA + what needs his eyes):
> ```bash
> slack-send -c C0AQ7964ZU6 "<context — bead, SHA, what needs judgment>" --file a.png b.png
> ```
> Message BEFORE `--file` (argparse is greedy — it becomes the `initial_comment`).

### Release the build slot

```
release_build_slot(project_key=CANONICAL_PROJECT_KEY, agent_name=AGENT_NAME, slot="batch-close:main")   # release even on an aborted run
```

### Self-deregister the Tier-1 identity (Layer 1)

After the build slot is released, deregister the name minted in the Session Identity step
per `agent-mail/references/session-procedure.md` § Release + self-deregister (even on an aborted run).

### Next Step

```
AskUserQuestion(
  questions: [{
    question: "Batch closed. What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Start new feature (Recommended)", description: "Run /ac-plan-init — begin planning the next batch" },
      { label: "Hygiene pass", description: "Run /ac-hygiene — codebase health check after the batch" },
      { label: "Publish", description: "Run /ac-publish — mint a release, prove it, ship web + native" },
      { label: "Done", description: "Nothing more to do right now" }
    ]
  }]
)
```

(Skipped entirely when the delegation prompt says so — e.g. an autonomous loop invocation says
"no 'what's next?' after batch-close.")

### Finalize

Mark the run ledger's final task `completed`. Clean up only on the clean "Done" path — if a
follow-up was chosen or a CI/review step flagged an error, leave `$ARTIFACTS_DIR` for
investigation.

```bash
rm -rf "$ARTIFACTS_DIR"   # ONLY on the clean "Done" path
```

---

## Remember

<!-- diet: all bullets deleted (ac-gcj.5 Remember diet, Craig ruling 2) — every bullet restated a live body section (grep-verified: one-writer, freeze, always-grants, last-commit, pending-write all have body twins); nothing was Remember-only -->

_(Body sections are the canon — nothing summarized here.)_

---

_Trunk-direct batch closing: gate through a light review, dispatch CI once, commit the thin
batch report, advance the review-mark. Version/tag/deploy/heavy-review: `/ac-publish`. For
legacy branches: `/ac-merge`. For next feature: `/ac-plan-init`._
