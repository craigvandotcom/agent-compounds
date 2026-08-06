---
name: ac-batch-close
description: 'Trunk-direct batch closing ceremony — a THIN committed-state checkpoint: batch-anchored CI dispatch + commit the batch report (batch mark advance + feedback pending-write). Version mint, tag and deploy-verification live in ac-publish; code quality is ac-hygiene's lane. Triggers: ''batch close'', ''close the batch'', ''ac-batch-close'', ''ship the batch''.'
---


**You are the conductor closing out a batch of trunk-direct commits on `main`.** Agents commit
directly to `main` — no wave branch, no PR. This is the periodic (or on-demand) closing
ceremony: dispatch Tier 1 CI for the batch, and commit a thin batch-report checkpoint that
advances the batch mark. Fired once per batch, not per commit.

---

## I/O Contract

|                  |                                                                                            |
| ---------------- | ------------------------------------------------------------------------------------------ |
| **Input**        | `main`, with implementation commits already pushed directly since the last batch anchor (no branch, no PR) |
| **Output**       | Tier 1 CI confirmed for the batch, batch report committed, batch mark advanced, in-scope `triage,feedback` beads marked `fixed_pending_release` |
| **Not in scope** | Version bump/tag, deploy verification, the 6-dim review panel (all `ac-publish`) |
| **Artifacts**    | Batch-close summary in `.claude/reviews/batch/`, scratch in `$ARTIFACTS_DIR`                |
| **Verification** | Tier 1 CI dispatch green for the batch                                                       |

## Prerequisites

- On `main` (trunk-direct — no branch-name check; if invoked on a branch, that's `ac-merge`'s job, not this skill's)
- `gh` CLI authenticated
- Agent Mail MCP tools available (`acquire_build_slot`/`renew_build_slot`/`release_build_slot`) —
  see Build Slot below
- Implementation commits already landed directly on `main` (from `ac-implement`, trunk-direct — no wave branch to check out)
- A `quality-gate.yml` workflow with `workflow_dispatch` inputs `reason` + `batch_anchor`.
  If the workflow doesn't exist yet, the Act 1 DISPATCH is skipped — the gate is not waived:
  Act 1 must then assert a local-equivalent gate or report `Tier 1 CI: NOT GATED`, never green.

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
  → release_build_slot() at the very end, after Act 2's report commit lands — release even on
    abort, so a stalled conductor doesn't leave a stale advisory lease for the next run
```

> **Concurrency assertion.** Assert `git rev-parse origin/main` equals your local `HEAD`
> immediately before and after each CI-affecting step (dispatch, any fix-forward push, the
> Act 2 report commit). A mismatch is the real signal a concurrent conductor
> moved `main` under you — the slot is advisory (memory `agent-mail-build-slot-advisory`), so this
> assertion, not the lease, is what actually protects the range.

No mutual exclusion is enforced by the primitive itself — this is a presence signal for a
conflicting concurrent run to notice, not a queue or a lock.

---

## Run Ledger

Declare the run ledger per `ac-pipeline/references/run-ledger.md` (pattern + resume doctrine there).
This ceremony's table:

```
TaskCreate (one per section, in run order):
  1.  Acquire build slot; determine batch anchor + scope + quality gate   in_progress
  2.  QA smoke gate (conditional)                                         pending
  3.  Gitleaks scan + Tier 1 CI dispatch + fix-forward (Act 1)            pending
  4.  Feedback pending-write + commit batch report (Act 2)               pending
  5.  Report + Slack + release build slot + finalize                     pending
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

The **batch anchor** — the last commit that touched `.claude/reviews/batch/`, i.e. where the
previous ceremony left off. Every batch consumer shares this range, including the verification
gate (`ac-pipeline/references/verification-gate.md`):

> **The probe is only correct because `.claude/reviews/batch/` has exactly ONE writer per
> ceremony — Act 2 below (bd-kudrb).** Any second writer puts a commit inside the very range
> the anchor is meant to bound.

```bash
ANCHOR=$(git log -1 --format=%H -- .claude/reviews/batch/)
if [ -z "$ANCHOR" ]; then
  # Bootstrap fallback: no batch batch mark exists yet. The `batch_anchor`
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
      echo "  Something other than ac-batch-close Act 2 wrote to .claude/reviews/batch/." >&2
      echo "  Using it would silently UNDER-SCOPE this batch (bd-kudrb)." >&2
      echo "  Fix the offending writer — this ceremony is the only one that may write" >&2
      echo "  .claude/reviews/batch/ — then" >&2
      echo "  step the anchor back to the previous batch-close mark:" >&2
      echo "    git log --format='%H %s' -- .claude/reviews/batch/ | grep -m1 ' batch-close:'" >&2
      exit 2
      ;;
  esac
fi

BATCH_RANGE="$ANCHOR..HEAD"
echo "ANCHOR=$ANCHOR" >> "$STATE"
```

Deterministic `$ARTIFACTS_DIR` per `ac-pipeline/references/run-id.md` (prefix `batch-close`) — trunk-direct
has no wave branch to key on, so the key is the anchor SHA instead of a branch slug:

```bash
# Mint RUN_ID if the orchestrator didn't hand one down (contract: ac-pipeline/references/run-id.md
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
br list --json | tee "$ARTIFACTS_DIR/beads.json" >/dev/null           # the claim set this batch is closing. `| tee` is the dcg-sanctioned write shape — destination is an ARGUMENT, so there is no redirect operator to match (ac-pipeline/references/shell-guardrails.md)
git log $BATCH_RANGE --oneline | tee "$ARTIFACTS_DIR/commits.txt" >/dev/null
git diff $BATCH_RANGE --stat | tee "$ARTIFACTS_DIR/diff-stats.txt" >/dev/null
```

No PR body is constructed. This context feeds the Act 2 batch-close report only.

Mark ledger task 1 `completed`; `TaskUpdate` task 2 `in_progress`.

---

## Act 1 — Batch-Anchored CI Dispatch

Covers the pre-flight quality gate, the QA smoke safety net, a gitleaks backstop, and the
batch's single Tier 1 CI dispatch.

### Quality Gate (post-sync)

Same order `ac-merge` mirrors from `ac-pipeline/references/verification-gate.md` §Format-first — format FIRST
(auto-fix), then type-check, lint, tests:

```bash
# format (auto-fix) -> type-check -> lint -> tests
# Tests = the AGGREGATED affected run, pinned to the BATCH ANCHOR (the trunk-direct
# equivalent of ac-merge's origin/main merge-base pin — here we're already on main, so
# the anchor is the older boundary that matters):
VITEST_AFFECTED_REF=$ANCHOR pnpm test
```

> **Sequence the local pre-flight and the CI dispatch — never overlap them.** Finish (or skip)
> this local pre-flight BEFORE firing the dispatch below.

**If any fail:** fix before proceeding — same rule as `ac-merge`: never dispatch Tier 1 CI with
failing local checks.

### QA Smoke Gate (conditional — safety net)

This is the **post-push re-proof** (J5 — the trunk-direct successor of ac-merge's
post-rebase re-proof; only the trigger-event name changed). **Run the ceremony smoke net
per `ac-pipeline/references/verification-gate.md` § Ceremony smoke net** with `<RANGE>` =
`$ANCHOR...HEAD` — device-twin conditions, browser twin, FAIL escalation (STOP before
proceeding), `mac-needed` note, and the qa-blocker STOP all live there.

Mark ledger task 2 `completed`; `TaskUpdate` task 3 `in_progress`.

### Gitleaks scan (CI backstop)

The pre-commit `gitleaks protect --staged` hook is `--no-verify`-bypassable, so a gitleaks
step is wired into `quality-gate.yml`'s batch-close leg, scanning `$BATCH_RANGE` (honoring
the repo-root `.gitleaksignore`). Nothing extra to invoke here — that step rides inside the
SAME `reason=batch-close` dispatch fired below, not a separate call. If that step hasn't
landed yet, the dispatched workflow simply doesn't have it — and that gap is *reported*, not
swallowed, under the same assert-don't-assume rule the dispatch below carries.

### Resolve THIS repo's gate workflow (never hardcode a name)

```bash
# Probe, then branch on the trigger shape.
GATE_WORKFLOW="${GATE_WORKFLOW:-}"   # a conductor may pin one explicitly; else probe
if [ -z "$GATE_WORKFLOW" ]; then
  for w in quality-gate.yml registry-lint.yml ci.yml lint.yml; do
    [ -f ".github/workflows/$w" ] && { GATE_WORKFLOW="$w"; break; }
  done
fi
GATE_DISPATCHABLE=no
[ -n "$GATE_WORKFLOW" ] && grep -q 'workflow_dispatch' ".github/workflows/$GATE_WORKFLOW" && GATE_DISPATCHABLE=yes
echo "GATE_WORKFLOW=${GATE_WORKFLOW:-<none>} dispatchable=$GATE_DISPATCHABLE"
```

No gate workflow at all → report `Tier 1 CI: NOT GATED (no gate workflow in .github/workflows/)`
and go straight to the local-equivalent arm (ii) below. Never let the absence read as a pass.

### Fire the Tier 1 CI dispatch (dispatchable gates ONLY — `GATE_DISPATCHABLE=yes`)

```bash
gh workflow run "$GATE_WORKFLOW" -f reason=batch-close -f batch_anchor="$ANCHOR"
```

**Assert this gate; never assume it** (canon: `ac-pipeline/references/verification-gate.md`
§ Assert the gate). If no gate workflow resolved, or it has no `workflow_dispatch` trigger, the
dispatch is skipped — but the GATE is not waived, and you may NOT report Tier 1 CI green. The
same hole opens even where a workflow DOES exist: a path-filtered one (`on.push.paths`)
creates **zero runs** for a batch touching none of its paths (a docs-only, `templates/`-only or
ledger-only batch, including the Act 2 mark commit itself), so "skip silently and continue"
reads clean while nothing executed. Report `Tier 1 CI: green` ONLY on:

- **(i) an executed run.** Which SHA(s) to assert depends on the trigger shape resolved above —
  asserting the single anchor SHA against a push-triggered gate is vacuous (the anchor commit
  often has no run of its own once `paths:` filters bite):

  ```bash
  # DISPATCHABLE gate: one run, head SHA == the batch anchor.
  if [ "$GATE_DISPATCHABLE" = yes ]; then
    GH_DEBUG= gh run list --workflow "$GATE_WORKFLOW" --json headSha,conclusion --limit 100 \
      2>/dev/null | jq -r --arg s "$ANCHOR" '[.[] | select((.headSha|startswith($s)) and .conclusion=="success")] | length'
  else
    # PUSH-TRIGGERED gate: one run PER COMMIT — assert every commit in the range, and report
    # the no-run case as its own verdict. It is NOT a pass.
    # Re-derive the range HERE (same rule as Act 2): BATCH_RANGE is assigned in the anchor
    # block, a SEPARATE fenced block, so it may be empty — and `git rev-list ""` errors into an
    # EMPTY loop, i.e. zero per-commit verdicts that read as "nothing to report".
    BATCH_RANGE="${BATCH_RANGE:-$ANCHOR..HEAD}"
    RUNS=$(GH_DEBUG= gh run list --workflow "$GATE_WORKFLOW" --json headSha,conclusion --limit 200 2>/dev/null)
    for c in $(git rev-list "$BATCH_RANGE"); do
      green=$(printf '%s' "$RUNS" | jq -r --arg s "$c" '[.[] | select((.headSha|startswith($s)) and .conclusion=="success")] | length')
      any=$(printf '%s' "$RUNS" | jq -r --arg s "$c" '[.[] | select(.headSha|startswith($s))] | length')
      if [ "$green" -gt 0 ]; then      echo "${c:0:8} green"
      elif [ "$any" -gt 0 ]; then      echo "${c:0:8} FAILED"
      else                             echo "${c:0:8} no-run (paths-filtered)"
      fi
    done
  fi
  ```

  The `.conclusion=="success"` filter IS the assertion — counting SHA matches alone passes on a
  FAILED run, the same vacuous shape this section exists to close. `GH_DEBUG=`/`2>/dev/null` are
  load-bearing too: a tracing `gh` prefixes non-JSON, making `jq` exit 5 — a false "check errored", not a false green. `0` = no run PASSED for this anchor; never report green.
  On the push-triggered arm, `Tier 1 CI: green` requires EVERY commit `green`. Any `FAILED` →
  triage below. Any `no-run (paths-filtered)` → report
  `Tier 1 CI: PARTIAL (<n>/<N> commits gated; <m> no-run, paths-filtered)` and name those SHAs —
  a commit no gate ever executed against must never read as `Tier 1 CI: green`.
- **(ii) a recorded local-equivalent gate**, naming all three of: the exact command(s) run,
  their exit codes, and the SHA they ran against (e.g. "`./lint.sh` exit 0 + the three touched
  proof scripts exit 0, at `<sha>`"). Fewer than three is not recorded and does not count.

Neither → report `Tier 1 CI: NOT GATED (<reason>)` in Act 2. Still do not block the batch on
infrastructure another bead is landing — but never let an un-executed gate read as a passed one.

### Poll for the dispatched run against HEAD — DISPATCHABLE GATES ONLY, FOREGROUND ONLY

**Skip this whole section unless `GATE_DISPATCHABLE=yes`.** No dispatch was fired on a
push-triggered gate, so there is nothing to poll for: the per-commit `RUNS` assertion above IS
this repo's verdict and the ~25-min loop below would burn its full cap waiting on a run that
was never dispatched.

Same bounded-wait discipline as `ac-merge`'s PR-checks poll (`ac-pipeline/references/delegation-contract.md`:
hard-capped, timeout-terminal — a stalled CI run is a reportable outcome, not a pause). **This
poll runs in the foreground, inside this turn, to completion or the cap below — never fork it
to a background process that outlives the session.** The `$STATE` persistence above covers a
session that drops and resumes; it does not license spawning a detached poller that keeps
running after this turn ends.

> **Cap must be WIDE — the wall-clock is batch-CONTENT-dependent.** A batch whose diff touches
> `scripts/` or CI config correctly defeats `vitest-affected` selection (fail-closed, by design)
> and runs the **FULL suite**, not the ~4-min affected leg. The poll below is therefore capped
> at ~25min (`seq 1 50` at 30s).
>
> **Invoke this poll with Bash `timeout: 600000`** (the tool's 120000ms default silently kills a
> multi-minute poll mid-loop). 600000ms is the Bash-tool MAX (10min), which is shorter than
> the 25-min logical cap, so a full-suite-fallback
> run will span **2–3 foreground Bash invocations**: each returns with `$STATUS` still not
> `completed`, and you re-invoke (the loop re-resolves `RUN_DB_ID` from `HEAD_SHA` each call, so
> it resumes cleanly) until `completed` or the ~25-min logical cap is exhausted. Re-invoking in
> the same turn is NOT backgrounding — it stays foreground.

```bash
[ "$GATE_DISPATCHABLE" = yes ] || { echo "poll skipped: $GATE_WORKFLOW is not dispatchable"; }
HEAD_SHA=$(git rev-parse HEAD)
# Resolve the dispatched run's id ONCE (list + match by headSha to get its databaseId), then
# poll THAT id deterministically with `gh run view <id>` — re-listing + jq-selecting by headSha
# every iteration is fragile. The run may take a cycle to register, so keep resolving until the
# id is known, then switch to the deterministic view.
RUN_DB_ID=""
# ~25-min logical cap (50 × 30s) — wide enough for a full-suite-fallback batch (~19min).
# Invoke with Bash timeout: 600000; a full-suite run spans 2-3 foreground re-invocations
# (this loop re-resolves RUN_DB_ID from HEAD_SHA each call, so re-invoking resumes cleanly).
for i in $(seq 1 50); do
    sleep 30
    if [ -z "$RUN_DB_ID" ]; then
        RUN_DB_ID=$(gh run list --workflow="$GATE_WORKFLOW" --branch main \
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
# Terminal verdict on cap exhaustion — a stalled/never-registered run is a REPORTABLE outcome,
# never a silent fall-through into the triage step below.
[ "$STATUS" = completed ] || echo "Tier 1 CI: STALLED (no completed run for $HEAD_SHA within the cap)"
echo "$MATCH" >> "$ARTIFACTS_DIR/dispatch-run.json"
```

### Triage on failure (same core-work rule as ac-merge)

**THIS IS YOUR CORE WORK. Do not delegate triage.** Source of findings here is the dispatch
run's failed jobs (`gh run view <id> --log-failed`) — not PR comments/agent reviews (the light
review is Act 2, which runs after this act). Same classification `ac-merge` uses:

- **Auto-fix:** obvious CI failures (lint/type/format), clear single-fix issues.
- **Conductor decides:** high-severity items with clear fixes, easy improvements.
- **Present to user:** architectural/debatable items (Exhaust Rule applies if headless —
  `br create -t investigation --labels ci-finding,unrefined` rather than blocking silently
  (debatable = cause not source-traced = investigation, never bug — ac-gzb); stamp the
  perishable state `observed: <ISO date> · <run id>` per bead-conventions § Body template —
  CI is the catch stage; the eventual close cites the regression test per bead-conventions
  § Per-type close artifacts).

> **Correlated failures → escalate to the LCA, don't fix-forward N times.** If **2+** batch
> beads fail for one shared root cause (same wrong contract/assumption/parent-decomposition
> error, not just the same file), do not queue per-bead fix-forwards: trace them to their
> lowest common ancestor and route that parent node back to `/ac-bead-refine`, keeping
> closed+verified beads frozen — re-open and re-decompose the parent; never edit a bead already
> closed and verified in this batch. Per-bead fix-forward remains correct for uncorrelated,
> single-bead CI failures.

**Reserve the files you are about to fix BEFORE editing** (`agent-mail/references/session-procedure.md`
§ Reserve — fix-forward is Tier-1 product-code editing in the shared
checkout; release with the rest at teardown § Release). Apply fixes, then commit under
the minted Tier-1 identity — **re-assert `AGENT_NAME` inline in
the fix-forward commit shell** (exports don't survive across bash calls; the pre-commit guard
reads it, and a fix-forward as `FoggyCreek` would be a Tier-2-boundary violation):

Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check.

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

## Act 2 — Commit the Batch Report (feedback pending-write + batch-mark advance)

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
and this single file IS the mark. One commit, one writer, so the next ceremony's anchor probe
cannot return a commit inside its own range (bd-kudrb).

Sections: **Summary**, **Beads Completed**, **Changes**, **Test Coverage**, **Known post-merge
tails**. Keep each to what a later reader needs to reconstruct the batch — this report IS the
mark, so it is the only durable record of what the range contained.
Fill them per the template's field descriptions; `$BATCH_RANGE` is the range those sections'
`git diff`/`git log` commands key on. Batch-close's own addition beyond the template is a short **Feedback write-back** line
(the pending-write count logged above) — there is no Deploy section anymore (deploy
verification moved to `ac-publish`). **Known-action findings surfaced during the batch
(defects, decision forks, refinements you KNOW need action beyond this ceremony) are filed
as beads (`unrefined`) and cited by ID in this report, never left as prose-only** — a
prose-only findings channel orphans once its consumer closes
(`rule-known-action-capture-beads-not-prose`; bd-pwt44).

**Worker cost line (per-child / per-batch).** Add a one-line **Worker cost** entry to the
report: per-child implementer usage (model + token cost, which the conductor received in each
engineer's task-completion notification) and the batch total. This is where per-bead TOKEN cost
lives — deliberately at batch/child granularity, never per bead (a child can't see its own token
usage, so a per-bead split would be fabricated precision; see `ac-implement`'s worker-identity
stamp, which carries model/session/skill@version/duration per bead but explicitly NOT tokens).
Format: `Worker cost: <child-session> (<model>) <tokens>; … — batch total <tokens>`.

```bash
export AGENT_NAME=<minted-name>   # re-assert inline (Phase-0 mint) — this commit is the operative batch mark; attribute it to the minted identity, not FoggyCreek

# FATAL on an empty ANCHOR rather than silently computing "..HEAD" — an unknown batch
# scope must stop the ceremony, never widen it.
[ -n "$ANCHOR" ] || { echo "FATAL: ANCHOR is empty — batch scope is unknown; refusing to write the mark." 1>&2; exit 1; }

git add ".claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md"
# Pathspec-on-commit: the trailing `-- <report path>` scopes the commit to ONLY this file,
# so pre-staged foreign WIP in the shared checkout cannot be swept into it. The `git add`
# above is still needed because the report is a brand-new untracked file.
git commit -m "batch-close: ${ANCHOR:0:8}..$(git rev-parse --short HEAD) — {N} beads, {commit count} commits" \
  -- ".claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md"
git push origin main || { git pull --rebase origin main && git push origin main; }
```

**This must be the LAST commit of the ceremony.** If a fix-forward round is still needed after
this point, that means Act 1 (or Act 2) isn't actually done — re-run from there and redo this
commit last, again. Nothing pushes after the batch report.

### Ceremony pool ack + post-ack drain (bd-chd5p.2)

When the loop handed a **pool-backed** batch (pool-only, mixed, or pure risk-solo that
snapshot'd into `/tmp/loop-pool-<RUN_ID>.json`), Act 2 **acks** after the report commit:

1. Under `flock` on `/tmp/loop-pool-<RUN_ID>.json`, remove **only this batch's
   `in_flight` IDs** (never whole-file wipe).
2. Non-pool ceremonies (planned-wave / pure risk-solo with no snapshot) **no-op** the
   pool — leave `pending`/`in_flight`/`risk_queue` intact.
3. On ceremony **failure** before this ack: re-merge `in_flight` → `pending` (do not
   drop IDs); recompute `first_close_ts = min(closed_at)`.
4. After successful ack, if `in_flight` is empty → run the **drain sequence**
   (`ac-pipeline/references/ceremony-batching-pool.md` § Drain sequence): risk_queue head first (mixed or
   pure risk-solo), else fire opportunity on `pending` (soft-8 / ~3h window / line-floor
   N≈800, hard-10 ceiling), else stop.

Ceremony batch range for CI/report scope uses `ac-pipeline/references/risk-classification.md`
**binding #1** (pool-only union of `in_flight` `pre_sha..close_sha`; mixed ∪ risk bead
range; planned-wave/pure risk-solo = that batch's range).

Mark ledger task 5 `completed`; `TaskUpdate` task 6 `in_progress`.

---

## Report + Slack + Finalize

### Report

```markdown
## Batch Closed: {ANCHOR short-sha}..{HEAD short-sha}

**Batch report:** `.claude/reviews/batch/YYYY-MM-DD-HHMM-batch-close.md`
**Beads completed:** {count}
**Commits:** {count}

### Tier 1 CI
{run URL} — {green | fixed after N rounds}, or `NOT GATED (<reason>)` when neither Act 1
branch (i) nor (ii) held. "green" asserts a gate that EXECUTED — never a skipped one.

### Feedback write-back
{N} rows marked fixed_pending_release ({M} warnings)

### What Shipped
{1-3 bullet summary}
```

### Slack Notify

```bash
slack-send --channel sofi --card \
  --title "Batch closed" \
  --body "Batch closed — ${ANCHOR:0:8}..$(git rev-parse --short HEAD), ${N} beads, ${COMMIT_COUNT} commits. CI: ${RUN_URL}. Review: APPROVED."
```

> **If the batch produced visual evidence, UPLOAD the images — don't just cite `/tmp`
> paths in the card body** (`ac-pipeline/references/qa-shared.md` § Conductor /
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

---

_Trunk-direct batch closing: gate through a light review, dispatch CI once, commit the thin
batch report, advance the batch mark. Version/tag/deploy/heavy-review: `/ac-publish`. For
legacy branches: `/ac-merge`. For next feature: `/ac-plan-init`._
