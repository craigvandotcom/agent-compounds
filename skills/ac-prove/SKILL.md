---
name: ac-prove
description: Use to obtain-or-produce a tip-valid full-suite proof for a commit — the shared freshness-probe/dispatch/fix-forward primitive every ship path calls instead of re-implementing its own CI-trust logic. Wraps scripts/ci/publish-checkpoint-gate.mjs (freshness) + quality-gate.yml's reason=prove dispatch (the full leg). Three modes — probe (read-only), ensure (probe + dispatch-if-stale), ensure --fix-forward (blocking, ship-path only). Triggers on "prove this commit", "ac-prove", "is main green", "get a fresh checkpoint", "prove the tip", "gate on a full proof". NOT for running tests locally (use testing) or for reading CI state as a board pane (use ac-dashboard).
---

# ac-prove — Obtain-or-Produce a Tip-Valid Full Proof

**You are the shared proof primitive.** Every path that needs to *know* the full suite is
green for a commit — not "green as of some older SHA" — calls `ac-prove` instead of
re-deriving freshness/dispatch/trust logic per-caller. You wrap two existing pieces:
`scripts/ci/publish-checkpoint-gate.mjs` (the freshness gate, read-only ancestor/path check)
and `quality-gate.yml`'s `reason=prove` `workflow_dispatch` leg (the actual full run). You are
the **sole dispatcher** of `reason=prove` — no other skill fires it directly.

---

## I/O Contract

| | |
|---|---|
| **Input** | Optional `--ref <sha>` (defaults to current HEAD); a mode (`probe` / `ensure` / `ensure --fix-forward [+qa]`) |
| **Output** | `probe`: exit 0/1, no side effects. `ensure`/`ensure --fix-forward`: a **proven SHA** returned to the caller, or FAIL with no valid receipt |
| **Not in scope** | Version bumping, tagging, deploying, native ship — those are the callers' job. `ac-prove` only proves; it never ships. |

---

## Three Modes

Every mode accepts an optional `--ref <sha>` — proves that exact commit; omitted, it proves
current HEAD.

1. **`probe`** — read-only freshness check only. No dispatch, ever. Exits 0/1 exactly like
   `publish-checkpoint-gate.mjs` itself (in fact it just shells out to it). Use this when a
   caller wants a cheap signal and is willing to act on staleness itself (or not act at all).
2. **`ensure`** — probe first; if stale, dispatch a fresh full run and wait for it. **Never**
   fixes forward — a red run is reported as FAIL, as-is. Use this for non-ship paths that want
   an up-to-date answer but aren't authorized to touch the tree.
3. **`ensure --fix-forward [+qa]`** — the **blocking, ship-path-only** mode: probe →
   dispatch-if-stale → fix-forward mini-loop until a green receipt exists at some tip → optional
   `+qa` layer. This is the only mode that may commit code (fixes) and the only one that
   guarantees a green receipt or an explicit FAIL — never a silent stale pass.

---

## Step 1 — Freshness Probe (always first, every mode)

Before touching dispatch, always run the existing gate against the ref-or-HEAD:

```bash
REF="${ref:-$(git rev-parse HEAD)}"
node scripts/ci/publish-checkpoint-gate.mjs --release-sha "$REF"
```

- **Exit 0** means the last checkpoint in `_ci-evidence/vitest-affected-divergence-log.jsonl`
  is an ancestor of `$REF` with only evidence commits in between (see Canonical Receipt Contract
  below) — but that alone is **not** enough to short-circuit dispatch. Exit 0 short-circuits
  dispatch **only when** the referenced runId in that trusted line is confirmed
  `conclusion=success` (Step 3, Green Gate). **A tip-valid receipt sitting on top of a RED run
  does NOT short-circuit** — the gate script only checks ancestry/path-scoping, not the run's
  actual conclusion; that confirmation is `ac-prove`'s job, not the script's.
- **Exit 1** (stale, or no valid checkpoint at all) → proceed to Step 2 in `ensure`/
  `ensure --fix-forward`; in `probe` mode, this **is** the final answer — return FAIL, no dispatch.

`probe` mode stops here, always. It never dispatches, never fixes, never ships.

---

## Step 2 — Dispatch-if-Stale (`ensure` and `ensure --fix-forward` only)

```bash
gh workflow run quality-gate.yml -f reason=prove ${ref:+-f ref="$ref"}
```

**`ac-prove` is the SOLE dispatcher of `reason=prove`.** No other skill fires this reason
directly — if another path needs a fresh proof, it calls `ac-prove`, it does not dispatch
`reason=prove` itself.

**Foreground-poll to completion, in-turn.** Never background a poller that outlives this
session — a paused/backgrounded watcher can silently never resume
(memory: `background-agent-resume-chains-break-silently`). Poll with a bounded loop inside the
current turn; if the session would need to end before the run completes, that is a reportable
FAIL/timeout, not a fire-and-forget.

**The full leg** this dispatch runs (Tier 2, `quality-gate.yml` `workflow_dispatch` path) is the
genuinely expensive, comprehensive proof:

- vitest — unit + integration
- real-Postgres, from-scratch migrations (`supabase db reset`)
- Supabase integration tests against that fresh local stack
- the shadow divergence check (full-suite vs. affected-only blind-spot detector)
- `next build`
- whole-repo static checks (format, lint, type-check, design/token lints, prompt-drift)
- the size-limit bundle-size budget (its own bead, bd-pwt44.11 — lands alongside this rung)

This is the only place all of that runs together; nothing short of `reason=prove` (or
`loop-close`/`publish`) exercises the from-scratch-migration + Supabase-integration legs.

---

## Step 3 — Green Gate (critical — read this before trusting any receipt)

The divergence step that writes the receipt runs `if: !cancelled()` — it appends a line **on a
RED run too**, and the line carries **no pass/fail field of its own**. A receipt existing is
proof the run *reached* that step, not proof it was green.

**`ac-prove` MUST separately confirm the dispatched run's conclusion:**

```bash
gh run view "$RUN_ID" --json conclusion --jq '.conclusion'
```

Only `conclusion=success` counts. Freshness-exit-0 alone, or receipt-existence alone, is
**never** sufficient — see Canonical Receipt Contract's three-condition trust rule below, which
this step is one leg of.

Red conclusion → this is not a green proof. In `ensure` mode: report FAIL, stop. In
`ensure --fix-forward` mode: proceed to Step 4.

---

## Step 4 — Fix-Forward Mini-Loop (`ensure --fix-forward` only)

Classify the failure:

- **MECHANICAL** (lint, format, type error, flaky-but-fixable test, obvious single-cause
  failure): fix it, commit, **re-dispatch the full run** (Step 2 again) against the new tip,
  re-check the Green Gate (Step 3). Repeat until green **or** the iteration cap is hit.
- **PROFOUND** (architectural, ambiguous, needs a design decision, or the cap is hit): **abort**
  — file a plan or beads describing what's blocking, report **FAIL**, and return **no valid
  (green) receipt** to the caller. Never fabricate a pass.
- **ENVIRONMENT** (runner-side blocker: leaked Supabase local stack, port conflict, disk
  pressure, stale process — no code to fix and no design fork). Seen live on the first
  `ac-publish` run (v1.5.13): round 1 failed the local-stack guard on a leaked stack. Rules:
  - **CI-started leak → auto-clear, then re-dispatch.** Only if the blocker is **provably**
    CI-started (e.g. no interactive dev session owns the stack/port) may you clear it (stop the
    stack, free the port) and re-dispatch. When in doubt, treat as dev-owned.
  - **Active dev session → NEVER auto-kill.** If a stack/process might belong to a live dev
    session, **halt `NEEDS_DECISION`** with the specific blocker and the exact remedy command —
    let the operator clear it. Killing a dev's stack is destructive.
  - **ENVIRONMENT retries do NOT count against the MECHANICAL round cap** — clearing a leaked
    stack is not a code-fix round, so an auto-clear + re-dispatch is free against the cap below.

**Bounded iteration cap.** This loop re-dispatches a full CI run per round — cap the number of
rounds (a small fixed number, e.g. 3) and treat hitting the cap as PROFOUND. No unbounded
re-dispatch loop under any circumstance. **The cap counts MECHANICAL code-fix rounds only;
ENVIRONMENT auto-clears are excluded** (they change no code and prove no new tip).

Each successful round proves a **new tip** — the SHA changes every time a fix lands. This is
why the Returned-SHA Contract below exists: the caller's original `--ref` is stale the moment a
fix-forward round commits.

### Optional `+qa` layer

After a green receipt (whether reached with zero or several fix-forward rounds), `+qa` runs the
device/browser QA layer on top of the proven tip:

Pass selection defers to `ac-pipeline/references/verification-gate.md` — one selection brain, never re-decided locally. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

- `ac-qa-device` — including the review-critical sim-PASS rule
  (memory: `rule-review-critical-journeys-sim-pass-before-submission`) when the caller's context
  requires it (e.g. an App Store submission path).
- `ac-qa-browser`
- `ac-ui-polish` (spec-conformance/premium-polish lens, when the caller wants it)

`+qa` findings that block ship are reported the same way `ac-qa-device`/`ac-qa-browser` always
report them (findings=beads) — they do not themselves trigger another fix-forward CI round
unless the caller re-invokes `ac-prove` after fixing.

---

## Returned-SHA Contract

`ac-prove` **returns the proven SHA to its caller** — this is the only thing a caller should
trust as "the commit that's proven":

- **`--fix-forward` that needed fixing:** proves a **new tip R′ ≠ input `--ref R`**. `ac-prove`
  returns **R′**, not R.
- **A plain proof that goes green with no fix needed:** returns the **input `--ref R`
  unchanged**.

**Consumers MUST consume the returned SHA — never assume their input `--ref` still holds.** A
caller that tags, ships, or records "the proven commit" using its own original `--ref` after a
fix-forward round is shipping an unproven (and possibly broken) SHA by mistake.

---

## Canonical Receipt Contract

The receipt is a JSONL line appended to `_ci-evidence/vitest-affected-divergence-log.jsonl`,
shape `{ runId, sha, ... }`, **append-only** — the freshness gate (`publish-checkpoint-gate.mjs`)
reads only the **LAST** line.

**Attribution check:** because concurrent full runs can append after the one you dispatched, a
dispatching consumer must confirm the **trusted line's `runId`** equals its **own dispatched
run's id** — not just that *some* recent line looks fresh. A newer line from someone else's
concurrent run is not proof of *your* dispatch's outcome.

**Trust a receipt as proof-of-green ONLY when ALL THREE hold:**

1. Freshness gate exits 0 (`publish-checkpoint-gate.mjs --release-sha <ref>`).
2. The trusted line's `runId` matches the run `ac-prove` itself dispatched (attribution).
3. `gh run view <runId> --json conclusion` reports `conclusion=success` (Step 3, Green Gate).

**`probe` mode checks condition (1) only** — freshness alone. It is a baseline-pointer read,
**never** proof-of-green on its own; a caller that only needs "is there roughly-recent evidence"
uses `probe`, a caller that needs "is this commit actually proven" uses `ensure` or
`ensure --fix-forward` and gets all three conditions checked.

---

## Consumer Roster

| Consumer | Mode | Notes |
|---|---|---|
| **(a) `ac-publish`** | `ensure --fix-forward` | `+qa` when the ship touches native |
| **(c) manual invocation** | `ensure` | fix-forward **OFF** by default — a human decides whether to authorize fixing |
| **(d) `ac-distribute`** | `ensure --fix-forward` | `ci` depth for TestFlight; `+qa` **mandatory** for App Store submission |
| **(e) `ac-hygiene`** | `probe` **only** | never dispatches, never fixes — a cheap baseline read alongside its other lenses |
| **(b) idle-cron** | — | **DEFERRED**, not active this plan — see `workflows/scheduled.md`, which ships ready-but-unwired |

All of a/c/d/e are **active this plan**; b is deferred (spec is shipped, not wired to any
scheduler entry).

QA evidence/report schema: `ac-pipeline/references/qa-shared.md`. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

`+qa` depth (consumers a and d) = `ac-qa-device` (including the review-critical sim-PASS rule,
memory `rule-review-critical-journeys-sim-pass-before-submission`) / `ac-qa-browser` /
`ac-ui-polish`, per Step 4's `+qa` layer above.

**Explicitly NOT a consumer: loop-start.** Starting a new loop iteration does not call
`ac-prove` — proof is a ship-time/checkpoint concern, not a work-intake concern.

---

## Remember

- **Freshness first, always** — every mode runs the probe before anything else.
- **Exit-0 freshness is not the same as green** — the Green Gate's `conclusion=success` check is
  mandatory on any dispatched run; a receipt can exist on a RED run.
- **`ac-prove` owns `reason=prove` exclusively** — nothing else dispatches it.
- **No backgrounded pollers** — foreground, in-turn, bounded; a dropped background poller can
  never resume.
- **`--fix-forward` is ship-path-only and returns the SHA it actually proved** — never the
  caller's stale input ref after a fix round.
- **`probe` never dispatches, never fixes** — it is a read-only baseline signal only.

---

_ac-prove is the one place "is this commit actually proven" gets answered honestly — freshness
+ attribution + conclusion, or an explicit, receipt-free FAIL. Everything downstream (publish,
distribute, hygiene, manual checks) trusts this primitive instead of re-deriving it._
