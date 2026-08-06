---
name: ac-tidy
description: 'Pipeline housekeeping — archive completed items, reconcile backlog/plans/beads, flag orphans, suggest consolidation. Triggers: ''tidy the pipeline'', ''clean up backlog'', ''reconcile plans and beads'', ''pipeline housekeeping''. For codebase code review/cleanup use ac-hygiene.'
---

**You are the pipeline janitor.** Scan all three data stores, reconcile lifecycle state, archive completed work, flag orphans, suggest consolidation.

## Modes

| Mode | Invocation | Confirmation | Writes |
|---|---|---|---|
| **INTERACTIVE** (default) | direct human / `ac-human-session` | `AskUserQuestion` throughout | applies on approval |
| **NIGHTLY** (headless) | scheduled `workflows/nightly.md` heartbeat | none (no human present) | auto-applies the sanctioned subset; emits proposals for the rest |

In **NIGHTLY** mode:

- **Tier 1 — auto-apply** (non-destructive reconciliation): Phase 2d (`captured → planned`) + Phase 2e (fix/infer plan frontmatter) + adding missing `plans:` fields + stripping a stale `unrefined` label from any CLOSED bead — **including one labelled `human-gate`/`qa-blocker`**, which the guardrail below explicitly scopes to OPEN beads (a closed bead is past refinement by definition — pure label reconciliation; `br label remove <id> unrefined`, verify via the issues.jsonl, not `br show`) + Phase 2f (stamping fail-safe `unrefined` onto any OPEN bead with a lifecycle-label gap — never `refined`, that stamp is only earned). Always runs.
- **Tier 2 — auto-apply provably-done archive** (Phases 2b/2c): ONLY when the Tier-2 toggle is ON *and* the positive-proof gate passes (see NIGHTLY Guardrails). Otherwise the item falls through to a Tier-3 proposal.
- **Tier 3 — propose only** (Phases 3–4: orphans, consolidation, dedup, finding-bead prune): emit a proposal file + a `human-gate,pipeline-proposal` bead. **Never** `AskUserQuestion` — there is no human. `ac-human-session` applies approved proposals later by re-invoking this skill's INTERACTIVE flow.

INTERACTIVE mode is unchanged from the sections below — every move requires user confirmation.

## NIGHTLY Guardrails

*(This exact header is the deterministic marker the `nightly.md` heartbeat greps to read the toggle.)*

- **Tier-2 auto-archive: ON** — the toggle. Default OFF for the pilot. It lives here in the SKILL **body** (never YAML frontmatter — the scheduler strips frontmatter before the agent sees the prompt). Flip to ON only via the post-observation sign-off; because it is an agent-compounds edit, it takes effect only after re-sync + `pm2 restart pai-scheduler`.
- **Positive proof, never empty-parse.** Before any Tier-2 archive: require `N_matching > 0` **and** `N_closed == N_matching` **and** the `br list --json` result parsed to a non-empty, expected shape. **`N_matching` and `N_closed` count IMPLEMENTATION beads ONLY — beads carrying the `pipeline-proposal` label are EXCLUDED from both** (label semantics: `beads-standards/reference/bead-conventions.md` § Labels — a proposal bead never counts as implementation proof). This skill emits those beads itself, so the exclusion binds at every site that defines "matching" here — the Tier-2 archive gate above and Phases 2b and 2c below. *Worked negative example:* a loop-ready plan's only match is `bd-pzlhv`, a CLOSED `pipeline-proposal` bead that merely NAMES the plan, its close reason recording a human decision to KEEP it. Naive arithmetic `N_matching = 1` / `N_closed = 1` → gate passes → an un-beadified loop-ready plan is archived. Under the exclusion `bd-pzlhv` is dropped, so `N_matching = 0`, the `N_matching > 0` clause fails, and the plan falls through to a **Tier-3 proposal** — never a silent no-op, never an archive. `br` output shape varies (`{issues:[]}` vs a bare array — `bca-br-tooling-flaky`); an empty or misparsed result MUST abort the archive and fall through to a Tier-3 proposal — never read emptiness as "done".
- **Never touch OPEN `human-gate` or `qa-blocker` beads** — gated, not housekeeping. A CLOSED one gates nothing (a gate withholds FUTURE work, and there is none), so the Tier-1 stale-label carve-out below applies to it.
- **Provable, never heuristic** — keyword/similarity-inferred "looks done" is a Tier-3 proposal, never an auto-move.

---

## I/O Contract

|                  |                                                                      |
| ---------------- | -------------------------------------------------------------------- |
| **Input**        | None (reads project state directly)                                  |
| **Output**       | Tidied pipeline — items archived, statuses reconciled, orphans flagged |
| **Artifacts**    | None (stateless)                                                     |
| **Verification** | Report of all changes made                                           |

## Prerequisites

- beads_rust (`br`) installed — verify with `which br`
- Project has `_backlog/` and/or `_plans/` directories

---

## Phase 0: Initialize

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Read `AGENTS.md` for project context.

### Create Workflow Tasks (run ledger)

**One task per major section — every reconciliation sub-phase gets its own line.** Create
these upfront; `TaskUpdate` each to `in_progress` when its section starts and `completed`
when it ends (both modes — NIGHTLY tracks the ledger internally even with no human to show
it to). This run does not invoke sub-skills mid-flight; if a future revision does, that
sub-skill keeps its own ledger — don't duplicate its steps here.

Ledger contract: `ac-pipeline/references/run-ledger.md` — one task per section, advance as you go; ledger = run position, never work items.

```
TaskCreate("Scope + scan — read AGENTS.md, scan beads/plans/backlog via board-scan")
TaskCreate("2a — archive completed backlog items")
TaskCreate("2b — archive beadified plans")
TaskCreate("2c — archive completed plans (all beads closed)")
TaskCreate("2d — update backlog status for planned items")
TaskCreate("2e — fix missing plan frontmatter")
TaskCreate("2f — lifecycle label gap lint")
TaskCreate("Flag orphans + suggest consolidation")
TaskCreate("Report — tidy summary, commit changes")
```

**TaskUpdate("Scope + scan", in_progress)**

---

## Phase 1: Scan Everything

**Read the board per `ac-pipeline/references/board-scan.md`** (scans A beads · B plans · C backlog) — the single shared definition of how pipeline state is read. Collect it once; the rest of this skill reconciles it.

Your lens (the reconciliation inputs to pull from the board):

- **Beads** — closed vs open; `unrefined`-labelled; lifecycle-label gaps (open beads with none of `unrefined`/`refined`/`human-gate` — Phase 2f); epics with child completion ratios (total / closed / open); finding labels (`qa-finding` / `review-finding` / `hygiene-finding`) for the prune pass (Phase 4).
- **Plans** — `status` (and infer it if frontmatter is missing → Phase 2e); whether each plan is **referenced by a bead** (= beadified → Phase 2b) and whether those beads are all closed (→ Phase 2c); `source_backlog` (→ Phase 2d).
- **Backlog** — `status` + `plans` fields; checked vs unchecked task counts; which folder (`active/` = committed · `pool/` = candidate; flag any legacy `v*/` for the `{active/, pool/}` migration `/ac-align` offers).

**TaskUpdate("Scope + scan", completed)**

---

## Phase 2: Reconcile Lifecycle State

**TaskUpdate("2a", in_progress)**

### 2a: Archive Completed Backlog Items

**Condition:** All tasks checked off (`- [x]`) OR frontmatter `status: complete`

**Action:** Propose moving to `_backlog/_done/` via `AskUserQuestion` — question: "{count} backlog files appear complete. Archive them?" · header: "Archive Backlog" · multiSelect: true · one option per file: label "{filename}", description "{checked}/{total} tasks done".

For approved items:
1. Update frontmatter: `status: complete`
2. Move to `_backlog/_done/`

**TaskUpdate("2a", completed)**
**TaskUpdate("2b", in_progress)**

### 2b: Archive Beadified Plans

> **NIGHTLY:** auto-archive ONLY if the Tier-2 toggle is ON and the positive-proof gate passes (see NIGHTLY Guardrails); otherwise emit a Tier-3 proposal instead of asking. INTERACTIVE: confirm via `AskUserQuestion` as below.

**Condition:** Plan frontmatter `status: beadified` OR plan is referenced by beads in `br` AND all those beads exist — where "referenced by beads" counts IMPLEMENTATION beads only, per the exclusion in NIGHTLY Guardrails § Positive proof

**Action:** Propose moving to `_plans/_done/` via `AskUserQuestion` — question: "{count} plans have been beadified. Archive to _done/?" · header: "Archive Plans" · multiSelect: true · one option per plan: label "{filename}", description "Beadified — beads are the source of truth".

For approved items:
1. Update frontmatter: `status: done`
2. Move to `_plans/_done/`

**TaskUpdate("2b", completed)**
**TaskUpdate("2c", in_progress)**

### 2c: Archive Completed Plans (All Beads Closed)

> **NIGHTLY:** same as 2b — auto-archive only under the Tier-2 toggle + positive-proof gate; else Tier-3 proposal.

**Condition:** Plan has matching beads AND all matching beads are closed — "matching" is defined by the exclusion in NIGHTLY Guardrails § Positive proof. A plan whose only matches are proposal beads therefore has `N_matching = 0`, fails the positive-proof gate, and falls through to a Tier-3 proposal — it is never archived and never silently skipped

**Action:** Same archive flow as 2b, but with different description:

```
{ label: "{filename}", description: "All {count} beads closed — work complete" }
```

**TaskUpdate("2c", completed)**
**TaskUpdate("2d", in_progress)**

### 2d: Update Backlog Status for Planned Items

> **NIGHTLY (Tier 1):** auto-applies in both modes — non-destructive reconciliation, no confirmation needed.

**Condition:** Backlog file has `status: captured` but a matching plan exists (either via `plans:` frontmatter field or keyword matching)

**Action:** Update frontmatter to `status: planned` and add `plans:` field if missing.

Report: "Updated {filename}: status → planned (plan: {plan_name})"

**TaskUpdate("2d", completed)**
**TaskUpdate("2e", in_progress)**

### 2e: Fix Missing Plan Frontmatter

> **NIGHTLY (Tier 1):** auto-applies in both modes — inferring + adding frontmatter is non-destructive; report the inference.

**Condition:** Plan files that lack YAML frontmatter entirely

**Action:** Infer status from content:
- Has `## Refinement Log` with rounds → `status: refined`
- Has `Status: Approved` text → `status: approved`
- Referenced by beads → `status: beadified`
- None of the above → `status: draft`

Add frontmatter:

```yaml
---
status: {inferred}
refinement_rounds: {count from Refinement Log, or 0}
---
```

Report each inference.

**TaskUpdate("2e", completed)**
**TaskUpdate("2f", in_progress)**

### 2f: Lifecycle Label Gap Lint

> **NIGHTLY (Tier 1):** auto-applies in both modes — adding the fail-safe `unrefined` label is non-destructive; report every bead flagged. **Never auto-adds `refined`** — that stamp is exclusively earned via `/ac-bead-refine` convergence, no other skill (`skills/beads-standards/reference/bead-conventions.md`).

**Condition:** an open, non-epic bead carries none of `unrefined` / `refined` / `human-gate` — a lifecycle-label gap, i.e. unknown readiness state.

```bash
br list --json --limit 1000 | jq -r '
  .issues[]
  | select(.status == "open")
  | select((.labels // []) as $l |
      ($l | index("unrefined") | not) and
      ($l | index("refined") | not) and
      ($l | index("human-gate") | not))
  | .id'
```

**Action:** `br label add <id> "unrefined"` (fail-safe — unknown readiness is treated as not-ready). List every flagged bead in the report.

Report: "Lifecycle gap: {id} had no readiness label — added `unrefined`."

**TaskUpdate("2f", completed)**
**TaskUpdate("Flag orphans + suggest consolidation", in_progress)**

---

## Phase 3: Flag Orphans

### Orphan Plans
- Plans with no matching backlog item AND no beads referencing them
- Report: "Orphan plan: {filename} — no backlog source, no beads. Where did this come from?"

### Orphan Beads
- Beads whose description references a plan file that doesn't exist (not in active or `_done/`)
- Report: "Orphan bead {id}: references plan {name} which doesn't exist"

### Parentage-Gap Orphans (the I1 orphan class — `ac-pipeline/references/board-scan.md`)
- **An open, non-epic bead with no epic parent** (no `parent-child` edge to any epic). This is the I1 sense of "orphan" (no home epic) — **distinct** from the plan-reference orphan above. Read it from the board-scan spec's parentage-gap detector; do not re-derive.
- **`human-gate` beads are EXCLUDED** — their parentage is wired at creation (Arm 0 owns them); never flag a `human-gate` bead as a parentage-gap orphan.
- **FLAG-ONLY (Tier 3), never backfill.** Report the gap. When the §3 routing map (`beads-standards/reference/bead-conventions.md` § Bead routing) makes a parent obvious, the report MAY carry a **Tier-3 adoption proposal** (`br dep add -t parent-child <id> <epic-id>` — the `-t` is mandatory; the default `-t blocks` would author the very I2 violation below) — but there is **NO backfill mandate and nothing is auto-applied**. Missing/ambiguous routing → leave it flagged, unparented.
- Report: "Parentage-gap orphan {id}: open non-epic bead with no epic parent{ — obvious parent {epic-id} (proposal)| — no obvious parent}"
- **REPORT-ONLY — never emit a `human-gate` proposal bead for this class** (bd-zugqh). Parentage has exactly ONE consumer in the whole skill tree — Epic-Close Proposals below. It does **not** affect `br ready`, `bv --robot-triage`, scheduling, or priority, so the class's stated harm ("they drift unscheduled") is FALSE; its real cost is only that some epics cannot be auto-proposed for closure — lint-grade. Report the count in the run summary; if an epic-close proposal is actually blocked by a missing parent, raise THAT, naming the epic.

### Authored Epic-Edge Violations (I2 — `ac-pipeline/references/board-scan.md`)
- **Any `blocks` edge with an epic endpoint** (either end an epic) is an I2 violation: containment is `parent-child`, sequencing is bead-level `blocks` (`skills/beads-standards/SKILL.md` § Sequencing & parentage). Read it from the board-scan spec's authored epic-edge detector.
- **Report ALWAYS.** Conversion to bead↔bead edges (or dropping an arrival-order-only edge) needs judgment → **Tier 3 proposal**, never auto-applied.
- Report: "Epic-edge violation: `blocks` edge {a}→{b} has an epic endpoint — propose bead-level rewire (Tier 3)"

### Epic-Close Proposals (the epic-close home — NOT `beads-closed-gate.sh`)
- Tidy already collects epic child-completion ratios (total / closed / open — § Scope + scan, from `board-scan.md`). Add the close action: **when every child of an epic is closed AND the epic's `## Delivers` is covered by the delivered artifacts of those children → propose closing the epic.** This is the single home for epic-close proposals; `beads-closed-gate.sh` stays focused on the claimed set and never closes epics.
- **NIGHTLY (Tier 3):** emit a proposal (do not auto-close). **INTERACTIVE (Tier 2):** confirm via `AskUserQuestion` before closing.
- Report: "Epic {id}: all {n} children closed + Delivers covered — propose close"

> **All Phase-3 proposals exclude `in_progress`/claimed beads and re-validate at apply time (proposal→apply TOCTOU guard).** A bead claimed since the scan may have moved; before any proposal is applied (via `ac-human-session`'s re-invocation of the INTERACTIVE flow), re-check `br show <id>` and skip anything now `in_progress`, claimed, or already reconciled. Never propose an adoption/rewire/close over a bead another session holds.

### Stale Backlog
- Backlog items with `status: planned` but linked plan has been archived/deleted
- Report: "Stale backlog: {filename} says 'planned' but plan is gone"

### Stale "In Progress" Items
- Backlog with `status: in_progress` but no recent git activity in related files (>30 days)
- Report as informational, don't auto-change

---

## Phase 4: Suggest Consolidation

Scan active backlog files for merge opportunities:

### Small File Merge Candidates
- Files with only 1-2 unchecked tasks in the same domain
- Propose: "Merge {file1} (1 task) + {file2} (2 tasks)? Both are {domain}."

### Duplicate Detection
- Backlog items that describe the same work in different words
- Propose: "Possible duplicate: {file1} task '{task}' ≈ {file2} task '{task}'?"

### Stale Finding-Bead Pruning

Finding beads (`qa-finding`, `review-finding`, `hygiene-finding` labels — see
`skills/beads-standards/reference/bead-conventions.md`) inflate fastest — the pipeline stages
file them automatically; ac-tidy is their pruner.

```bash
br list --json --limit 1000 | jq -r '.issues[] | select(.labels // [] | (index("qa-finding") or index("review-finding") or index("hygiene-finding"))) | select(.status != "closed") | "\(.id) \(.status) \(.title)"'
br stale --json 2>/dev/null   # age-based staleness
```

Flag for the user (never auto-close): finding beads that are (a) duplicates of
each other or of an existing bug, (b) stale with no activity and no longer
reproducible, or (c) superseded by a fix that already merged. Propose
close/merge per item. **Never touch OPEN `human-gate` or `qa-blocker` beads** —
those are gated, not housekeeping.

> **The RAW OPEN COUNT is not debt and is never escalated alone** (bd-8ms5t).
> Report the lane's **age distribution** (oldest, median, how many carry merged-fix evidence),
> never a bare total, and escalate ONLY the actionable subset per (a)/(b)/(c); empty subset → one
> line, file nothing. A count that only rises trains the reader to ignore the lane. Inflow is
> bounded at source: Low findings never become beads (`beads-standards/reference/bead-conventions.md`
> § Anti-inflation rules).

**INTERACTIVE:** present merge/prune suggestions (if any) via `AskUserQuestion`. Only suggest, never force.

**NIGHTLY (Tier 3):** do NOT `AskUserQuestion` (no human present). Instead emit a proposal file (`_plans/_proposals/<YYYY-MM-DD>/NN-<slug>.md`) + one `human-gate,pipeline-proposal` bead per cluster, per `workflows/nightly.md`. Before emitting, **dedup**: skip any cluster already covered by an open `pipeline-proposal` bead (the populated-`bead:` slot is the idempotency marker). `ac-human-session` applies approved proposals by re-invoking this skill's INTERACTIVE flow.

**TaskUpdate("Flag orphans + suggest consolidation", completed)**
**TaskUpdate("Report", in_progress)**

---

## Phase 5: Report

```
## Backlog Tidy Report

### Archived
- {count} backlog files → _done/
- {count} plans → _done/

### Status Updates
- {count} backlog items: captured → planned
- {count} plans: frontmatter added/corrected

### Lifecycle Label Gaps
- {count} open beads had none of `unrefined`/`refined`/`human-gate` — `unrefined` added (fail-safe)

### Orphans Flagged
- {count} orphan plans (no source, no beads)
- {count} orphan beads (missing plan reference)
- {count} stale backlog items

### Merge Suggestions
- {count} potential consolidations offered

### Pipeline Health
- Active backlog items: {count} across {file_count} files
- Active plans: {count} ({draft}/{refined}/{approved}/{beadified})
- Active beads: {count} ({ready}/{blocked}/{in_progress})
```

### Commit Changes

If any files were moved or updated:

Git discipline: `ac-pipeline/references/commit-discipline.md` — pathspec-only commits, no wildcard adds / stash, commit=push, deletion check.

```bash
# You performed every move/update yourself — commit EXACTLY those paths.
# Never `git add -A <dir>`: _plans/ and _backlog/ carry other sessions' in-flight
# WIP (ac-plan-init writes _plans/ concurrently) — a dir-wildcard sweeps it (H7d).
git add -- <exact files this run moved/updated>
git commit -m "$(cat <<'EOF'
chore: backlog-tidy — archive completed items, reconcile pipeline state

{summary of changes}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

**TaskUpdate("Report", completed)**

---

## Remember

- **All moves require confirmation in INTERACTIVE** — never archive without asking. In NIGHTLY, only the sanctioned auto-tiers apply (Tier 1 always; Tier 2 under the toggle + positive-proof gate); everything else is a proposal, never a silent move.
- **Infer conservatively** — when in doubt about status, flag rather than change
- **Beads are source of truth** — once beadified, the plan is archival
- **Frontmatter is the API** — pipeline tracking depends on structured metadata
- **Suggest, don't force merges** — consolidation is a recommendation
- **Run before `/ac-align` or `/ac-human-session`** — a clean pipeline makes better recommendations

---

_Pipeline janitor — archive, reconcile, flag, suggest. For capturing: `/ac-backlog`. For the human command center: `/ac-human-session`._
