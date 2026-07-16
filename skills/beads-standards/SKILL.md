---
name: beads-standards
description: 'Use when creating, refining, or reviewing a bead in ANY `.beads/` project under ~/Repos — choosing a label, deciding refined vs unrefined, writing a human-gate/DECISION bead, wiring `blocks` dependencies, setting `close_reason` or `defer_until`, or picking priority/status. Triggers: "beads standard", "bead template", "human-gate", "DECISION bead", "HUMAN bead", "create a bead", "close reason", "refined unrefined", "wire dependencies", "which label". Machine-wide canon for every repo with a `.beads/` directory (root, every app, agent-compounds, future personal task tracking) — not scoped to the agent-compounds `ac-*` pipeline (that pipeline''s own I/O-contract + batch-epic supplement lives in `skills/_shared/bead-conventions.md`; read both inside an `ac-*` skill).'
---

# Beads Standards

**Purpose:** one canon so a bead written in body-compass-app reads the same as one in
the root repo or agent-compounds.
**Status:** Complete (ratified 2026-07-15, cockpit-mission-panel audit — bead `ac-lv5`)

## Scope & adoption

One standard, every `.beads/` project — apps, root repo, agent-compounds itself, and
any future personal-task db. Adoption is **per-project and currently uneven**
(refined/unrefined coverage: body-compass 87%, root/art-still 0%) — that's expected,
not a violation to chase down retroactively. This skill defines what a **new** bead
must do; § Backfill below is the one-time catch-up list for what's already behind.

Pipeline-internal extensions for the agent-compounds `ac-*` production line (bead I/O
contract `## Delivers`/`## Consumes`, batch-epic + in-session refine, binding-vs-advisory)
live in `skills/_shared/bead-conventions.md` — this skill is the wider floor every
project stands on; that file is the deeper layer `ac-*` skills also need.

## Bead taxonomy — agent bead vs human bead

Every bead is one of two kinds; the kind decides who may close it.

| Kind | Default | Marker | Closes |
|---|---|---|---|
| **Agent bead** | Yes — every bead starts here | none | Any agent, on verified completion |
| **Human bead** | No — must be explicit | `human-gate` label | Craig only; agents enrich, never close |

**`human-gate` is the SOLE human marker.** Assignee is clean but ~9% populated;
`DECISION:`-prefixed titles leak past label-based scans. Five deprecated synonyms
**merge into `human-gate`** — replace on sight, never create a new one:

`human-only` · `human-blocked` · `human-required` · `craig-required` · `craig-context` → **`human-gate`**

Why it matters beyond hygiene: the cockpit's leverage/on-you lanes and its 15-second
decision rule are computed directly off this one label (`is_pending` + `human-gate`
predicates, `/fleet.json` — `infrastructure/services/cockpit/SKILL.md`). A missed
synonym is a bead the cockpit cannot see.

## Human-gate template (the structured decision card)

A human bead is a **decision card**, not a flag. Title prefix `DECISION:` or `HUMAN:`.
Description carries exactly these fields:

```
decision: <one-sentence question — what is Craig actually choosing?>
options:
  a) <option> — <one-line tradeoff>
  b) <option> — <one-line tradeoff>
  (2-4 lettered options; each does the analysis work Craig shouldn't have to)
context: <why this fork exists now — the minimum needed to decide in 15 seconds>
```

**MANDATORY dependency wiring — not optional, not "if convenient":** every bead this
decision gates gets a `blocks` edge back to the decision, at creation time:

```bash
br dep add <downstream-bead-id> <decision-bead-id>
```

This is the Exhaust Rule applied to human-gate beads. Without the edge, `br ready`
can't exclude the gated subtree and the cockpit's leverage metric reads zero for a
gate that's actually stalling real work (see cockpit ground truth #3 — 30/31 open
human-gate beads had zero downstream reach before this rule existed). Full copy-paste
template + worked example: [reference/human-gate-template.md](reference/human-gate-template.md).

## Agent bead template

Title is **verb-first** ("Fix the settings race", not "Settings race condition").
Description carries `## Acceptance Criteria` (falsifiable — a criterion both branches
of a choice satisfy gates nothing). Type-specific required sections and the full body
template (`## Steps to Reproduce` for bugs, `## Test Scope`, evidence, etc.) are the
`_shared/bead-conventions.md` § Body template contract — that's the `br lint` gate,
inherited machine-wide, not repeated here.

**Refined / unrefined — the readiness gate:**

| Label | Meaning |
|---|---|
| `refined` | Implementation-ready. Stamped **exclusively** by a refine pass (`ac-bead-refine` where that skill is deployed) on convergence — no conductor or capture step ever applies it directly. |
| `unrefined` | Needs a refinement pass before agent pickup. Default at creation. |
| *(neither)* | **Ungraded — never assume ready.** Missing-both is not "not ready" either; it's unknown. Fail-safe: treat as unrefined until graded. |

Readiness for pickup = **presence** of `refined`, never inferred from the absence of
`unrefined`. This is what gates loop/agent pickup everywhere this labelling is adopted.

## Status & priority canon

| Status | Semantics |
|---|---|
| `open` | Not yet started |
| `in_progress` | Actively claimed. Stale >7 days gets challenged — re-verify the claim before trusting it (`br stale --status in_progress --days 7`; tighter than `br stale`'s generic 30-day default) |
| `closed` | Done. **Requires `close_reason`** (`br close -r "..."`) |
| `deferred` | Scheduled for later. **Requires `defer_until`** (`br defer --until <date>`) — a deferred bead with no date is a lost bead |
| `tombstone` | Deleted (`br delete`) — excluded from every "live" scan |

**`close_reason` is structured, not free text:** lead with an outcome verb, then
detail — `shipped: ...`, `fixed: ...`, `wontfix: ...`, `duplicate: ...`,
`obsolete: ...`. This is what lets a future pass cluster closed beads into
codify-as-rule candidates (cockpit phase 4) — an unstructured reason can't be
clustered.

**Priority is `0`-`4`, integers only** (`P0`-`P4` accepted as input, stored as int).
0 = critical, 4 = backlog. Never a word ("high"/"low") in the field itself.

## Verification verdicts (structured comments)

Close-status alone is a weak eval label — a bead can close green while its symptom
survives; only the verdict chain shows it (a BCA bead once closed green while the
symptom it targeted lived on). So each verification ceremony (QA, review, CI,
prod-triage) records its outcome as a **structured comment** on the bead — not prose:
greppable, survives `br` version changes, and clusterable by the same tooling that reads
`close_reason`. It is a structured-COMMENT convention — **not** a sidecar file, **not**
new `br` schema fields (labels are too coarse for a per-ceremony verdict).

**Grammar** (mirrors `close_reason`'s outcome-verb shape, so one clustering pass reads both):

```
VERDICT: <outcome-verb>: <detail>
discovered-from: <bead-id|unknown>
```

- `<outcome-verb>` leads, colon, then detail — exactly like `shipped:`/`fixed:`. Closed
  verb set: `passed` · `failed` · `blocked` (couldn't verify — env/infra) · `waived`
  (verification deliberately skipped, reason in the detail).
- `discovered-from: <bead-id>` — origin linkage, on **finding beads only** (a bead a
  ceremony filed because it caught an escape). It names the bead whose work the escape
  traces back to. **`unknown` is a legal value** — the escape-depth metric counts only
  linked findings, so an honest `unknown` is the correct entry when the origin can't be
  pinned; a fabricated link is worse than none.
- Stable greppable prefix: `grep 'VERDICT:' .beads/issues.jsonl`.

**VERIFIERS write verdicts + linkage; IMPLEMENTERS never do (Goodhart guard).** The agent
that produced the work does not grade it — the verdict is written by the QA / review / CI /
prod ceremony that checks it. An implementer stamping its own `VERDICT: passed` is grading
its own homework; that is a convention violation, not a verdict. This separation is what
makes the verdict trustworthy as an eval label.

**Catch-stage vocabulary — a CLOSED set.** A finding bead carries exactly one catch-stage
label naming the lens that caught the escape:

`qa-finding` · `review-finding` · `hygiene-finding` · `ci-finding` · `prod-finding`

Escape-depth metrics count on this set, so it is closed — no new `*-finding` token is minted
without a migration note (see LABEL-FREEZE). Sentry-sourced findings **normalize into
`prod-finding`** (an alias, not a sixth token). As of ratification: `ci-finding` and
`prod-finding` are new; `qa-finding`/`hygiene-finding` are defined but were unused;
`review-finding` is in active use.

## LABEL-FREEZE (eval-load-bearing labels are versioned)

A subset of labels is **load-bearing for skills-eval metrics** — silently renaming or
repurposing one breaks every downstream measurement that keys on it. These labels are
**frozen**: stable and versioned, renamed ONLY with a migration note (a dated line in the
migration log below **and** a one-time `br label rename` sweep recorded in the backfill
checklist). The frozen set:

- `refined` — the readiness gate
- `human-gate` — the sole human marker
- the VERDICT grammar tokens — `passed`/`failed`/`blocked`/`waived` + `discovered-from`
- the catch-stage closed set — `qa-finding`/`review-finding`/`hygiene-finding`/`ci-finding`/`prod-finding`

Adding a NEW load-bearing label is allowed (it breaks no existing series); **renaming or
retiring** a frozen one requires the migration note. Migration log:

- *(none yet — first freeze ratified 2026-07-16, bead ac-aa7)*

## Label hygiene rules

- **kebab-case, lowercase only.** `human-gate`, not `Human-Gate` or `human_gate`.
- **No slashes** — `br` rejects them outright. `wave-NNN`, never `wave/NNN` (the git
  branch `wave/NNN` is a different namespace and is fine).
- **Prefer an existing label over inventing one.** Check first: `br label list-all`
  (falls back to `grep -o '"labels":\[[^]]*\]' .beads/issues.jsonl` if that command
  isn't available in an older `br`).
- **Casing/spelling variants are the same label — normalize, don't multiply**
  (`core`/`CORE`, `followup`/`follow-up`, `bugfix`/`bug-fix`, `phase2`/`phase-2`,
  `appstore`/`app-store`, `preflight`/`pre-flight`, `browser-qa`/`browser-QA`,
  `repo:agent-compounds`/`repo-agent-compounds`). Pick the kebab-case form, rename
  with `br label rename <old> <new>`.

## Backfill (2026-07-15 audit) — one-time alignment checklist

A one-time catch-up pass across existing repos, run **after** this skill exists so it
aligns to the standard above, not the other way round. Full checklist (synonym
merges, the 9 DECISION-titled beads missing `human-gate`, the `bd-d6w79` double-label
contradiction, `defer_until` gaps): [reference/2026-07-15-backfill-checklist.md](reference/2026-07-15-backfill-checklist.md).

## Where beads live

Every repo with work has its own `.beads/` (`issues.jsonl` tracked, `.db` gitignored
local cache). Deps only gate within one db — a bead belongs in the repo whose code it
changes; there is no cross-repo dependency graph (0 cross-project `blocks` edges exist
today, confirmed by the cockpit audit — Craig himself is the only shared node across
projects). Cross-project visibility is a dashboard/docket concern (cockpit, or
`ac-human-session` where deployed), never a reason to invent a shared db.

**Public-repo rule:** agent-compounds's `issues.jsonl` is world-readable. Beads there
carry no strategy, money, personal, or credential content — a sensitive decision's
memo goes in a private home (`_plans/`, root repo) and the bead itself carries only a
neutral title + pointer.
