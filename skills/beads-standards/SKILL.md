---
name: beads-standards
description: 'Use when creating, refining, or reviewing a bead in ANY `.beads/` project under ~/Repos — choosing a label, deciding refined vs unrefined, writing a human-gate/DECISION bead, wiring `blocks` dependencies, setting `close_reason` or `defer_until`, or picking priority/status. Triggers: "beads standard", "bead template", "human-gate", "DECISION bead", "HUMAN bead", "create a bead", "close reason", "refined unrefined", "wire dependencies", "which label". Machine-wide canon for every repo with a `.beads/` directory (root, every app, agent-compounds, future personal task tracking) — not scoped to the agent-compounds `ac-*` pipeline (that pipeline''s own I/O-contract + batch-epic supplement lives in `skills/beads-standards/reference/bead-conventions.md`; read both inside an `ac-*` skill). This is the STANDARD, not an executor: to actually refine a bead use ac-bead-refine, to capture one use ac-bead-capture, to generate a wave use ac-beadify.'
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
live in `skills/beads-standards/reference/bead-conventions.md` — this skill is the wider floor every
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

## Human-gate template (two card kinds — one gate label)

A human bead is a **card**, not a flag — everything Craig needs to act is on it.
`human-gate` stays the **SOLE** gate label: no `-gate` variant is ever introduced. The
two kinds below differ only by **title prefix** and body template, so the cockpit's
`is_pending` + `human-gate` predicates are untouched — the split is at the template
level, not the label level.

**`human-gate` is INVALID without an explicit `Gate-reason:` marker in the body.** The
label is legal only when the body states one of the two reasons:

```
Gate-reason: fork — <why this is a genuine fork only Craig can resolve>
```

or

```
Gate-reason: authorization — <why this needs Craig's authorization>
```

A `human-gate` label with neither marker is invalid — do not file it. Mechanical work is
never gated by default.

**`DECISION:` — a decision card** (a fork only Craig can resolve). Description fields:

```
decision: <one-sentence question — what is Craig actually choosing?>
Gate-reason: fork — <why this is a genuine fork only Craig can resolve>
options:
  a) <option> — <one-line tradeoff>
  b) <option> — <one-line tradeoff>
  (2-4 lettered options; each does the analysis work Craig shouldn't have to)
context: <why this fork exists now — the minimum needed to decide in 15 seconds>
```

(`HUMAN:` remains an accepted alias prefix for a decision-shaped gate that isn't a
fork — an approval, credential handoff, or go/no-go — same fields, same wiring rule.)

**`ACTION:` — an action card** (a do-in-the-world task only Craig can perform — a console
toggle, a store submission, a credential handoff). Not a fork, so **no options block**;
instead:

```
Gate-reason: authorization — <why this needs Craig's authorization>
what:            <the action, one line>
where:           <the exact surface — console / app / URL / menu path>
checklist:       <ordered steps to complete it>
estimated-time:  <rough wall-clock — "2 min", "15 min">
best-done-when:  <the ridealong hint — e.g. "on the next ASC version submission">
```

Motivating case: BCA `bd-l6khg.13` (ASC intro-offer config) — no options, pure action,
must ride a version submission. Copy-paste blocks + worked examples for both kinds:
`reference/human-gate-template.md`.

**MANDATORY dependency wiring — not optional, not "if convenient":** every bead this
decision gates gets a `blocks` edge back to the decision, at creation time:

```bash
br dep add <downstream-bead-id> <decision-bead-id>
```

This is the Exhaust Rule applied to human-gate beads. Without the edge, `br ready`
can't exclude the gated subtree and the cockpit's leverage metric reads zero for a
gate that's actually stalling real work (see cockpit ground truth #3 — 30/31 open
human-gate beads had zero downstream reach before this rule existed). Full copy-paste
template + worked example: `reference/human-gate-template.md`.

## Agent bead template

Title is **verb-first** ("Fix the settings race", not "Settings race condition").
Description carries `## Acceptance Criteria` (falsifiable — a criterion both branches
of a choice satisfy gates nothing). Type-specific required sections and the full body
template (`## Steps to Reproduce` for bugs, `## Test Scope`, evidence, etc.) are the
`beads-standards/reference/bead-conventions.md` § Body template contract — that's the `br lint` gate,
inherited machine-wide, not repeated here.

**Refined / unrefined — the readiness gate:**

| Label | Meaning |
|---|---|
| `refined` | Implementation-ready. Stamped **exclusively** by a refine pass (`ac-bead-refine` where that skill is deployed) on convergence — no conductor or capture step ever applies it directly. |
| `unrefined` | Needs a refinement pass before agent pickup. Default at creation. |
| *(neither)* | **Ungraded — never assume ready.** Missing-both is not "not ready" either; it's unknown. Fail-safe: treat as unrefined until graded. |

Readiness for pickup = **presence** of `refined`, never inferred from the absence of
`unrefined`. This is what gates loop/agent pickup everywhere this labelling is adopted.

**`cross-repo` — work whose bytes live in a different git repo than the board that
holds the ticket.** Mandatory body line: `Repo: <name>` (the owning checkout —
`agent-compounds`, root `~/Repos`, etc.). Enforcement: `ac-implement/SKILL.md`
selection filter still *selects* these beads (the board that holds the id is the
only one that can see them); the env-prerequisite table + `ac-pipeline/references/commit-discipline.md`
§ Cross-repo skill/infra beads require the session to **commit in that repo**,
never into the board repo. Do not overload `human-gate` as a routing stopgap.

## Sequencing & parentage (derived, not authored)

**Bead-level `blocks` edges are the only authored sequencing truth.** Epic order is
DERIVED from the cross-epic bead edges beneath it — epics are sequenced so as to honour
the bead edges that cross between them, never the reverse — epic order follows the bead
edges, it never leads them. **No workflow EVER authors an epic->epic dependency edge** (a `blocks` edge with an epic endpoint is an I2 violation —
the epic-edge detector in `ac-pipeline/references/board-scan.md` reports it).

The only legitimate cross-epic edge is a genuinely bead-shaped **consume** — bead B needs
an artifact bead A delivers. The falsifiability test before adding any cross-epic edge:
*does B actually need A's `## Delivers` artifact?* If not — if the ordering is strategic
("do the auth epic before the billing epic") with no bead-level cause — it is **not** an
edge. Strategic ordering lives in priority (`0`-`4`) plus `ac-align`, never in the
dependency graph. A fabricated edge serializes work that could run in parallel and risks
wedging a whole chain.

**Routing is a convention, not a hard gate; `--parent` is CONTAINMENT only, never
provenance.** The routing table (per creation source), the Arm-0 human-gate exception
(the ONE enforced parentage), and the full `--parent`/dot-child semantics + recovery
(`br close --force`, bd-nbn3h) are pipeline canon — `beads-standards/reference/bead-conventions.md`
§ Bead routing + § `--parent` is CONTAINMENT only. Floor rule worth knowing everywhere:
provenance uses `-t discovered-from`, never `--parent`.

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

**Typed close evidence:** after the verb, the detail names evidence appropriate to the
bead's TYPE (bug → regression test; investigation → findings + spawned fix beads;
task/feature → delivered artifacts). Per-type detail + enforcement model: pipeline canon,
`beads-standards/reference/bead-conventions.md` § Per-type close artifacts — not restated here.

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
- the refine-path pair — `refine-full`/`refine-light` (stamped by `ac-bead-refine` at finalize; `refine-light` records a disclosed reduced-process deviation, making the light-path frequency/safety measurable)
- `human-ratified` — fast-track provenance stamped only by `ac-human-session` after a lightweight completeness check; not a synonym for the gauntlet and never a stamp of `refined`

Adding a NEW load-bearing label is allowed (it breaks no existing series); **renaming or retiring** a frozen one requires the migration note. Worked example — **`degraded-solo`** (added 2026-07-29, bd-nreuv): a capability-starved run (no `Task` tool, or spawns exhausted) stamps it **alongside** the path label, never instead of it, so the pair series above stays intact and `refine-full ∧ degraded-solo` is one grep; grammar + the `refine-light-solo` criteria live in `ac-pipeline/references/degraded-mode.md`. Migration log:

- *(none yet — first freeze ratified 2026-07-16, bead ac-aa7)*

## Worker-identity stamp (structured comment)

A bead's `assignee` is the conductor (loop) identity — the agent that actually implemented it
is a per-child session + model, otherwise unrecoverable. At close, the implementing skill
(`ac-implement`) stamps a structured comment recording it, written in the same
stable-greppable-prefix style as the VERDICT grammar (`grep 'WORKER:' .beads/issues.jsonl`):

```
WORKER: model=<model-id> session=<session-name> skill@version=<agent-compounds SHA> duration=<wall-clock>
```

Fields are **joinable for future model-level comparison**: `model` groups runs by model,
`skill@version` (the agent-compounds git SHA at skill-load) is the **skills-eval before/after
axis** — it lets a doctrine change be measured against outcomes. Per-bead **token cost is
excluded** (a child can't observe its own usage — a per-bead split would be fabricated
precision); token cost is reported at batch/child granularity by `ac-batch-close`.

## Label hygiene rules

- **kebab-case, lowercase only.** `human-gate`, not `Human-Gate` or `human_gate`.
- **No slashes** — `br` rejects them outright. `wave-NNN`, never `wave/NNN` (the git
  branch `wave/NNN` is a different namespace and is fine).
- **50-character cap.** `br` rejects a label longer than 50 characters with an
  explicit validation error (`Validation failed: label: exceeds 50 characters`).
  It never silently truncates. Keep labels short enough to survive the cap.
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
contradiction, `defer_until` gaps): `reference/2026-07-15-backfill-checklist.md`.

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

---

## Operating the tools — `bv` triages, `br` mutates

> Migrated here from root `AGENTS.md` (2026-07-25, context-tokenomics): this is
> look-up material, needed only once you are already doing beads work — it does not
> belong in a file every agent loads on every spawn. Status/priority canon is above;
> this section is purely operational.

`br` ([beads_rust](https://github.com/Dicklesworthstone/beads_rust)) is the issue
tracker; `bv` ([beads_viewer](https://github.com/Dicklesworthstone/beads_viewer)) is a
graph-aware triage engine over `.beads/beads.jsonl`. Use `bv`'s robot flags for
deterministic, dependency-aware output (PageRank, betweenness, critical path, cycles)
rather than parsing JSONL or guessing at graph traversal.

**Scope boundary:** `bv` decides *what to work on* (triage, priority, planning).
`br` creates, modifies and closes. **Use ONLY `--robot-*` flags — a bare `bv` launches
an interactive TUI that blocks the session.**

### Start with triage

`bv --robot-triage` is the single entry point; it returns `quick_ref` (counts + top 3
picks), `recommendations` (ranked, with scores/reasons/unblock info), `quick_wins`,
`blockers_to_clear`, `project_health`, and copy-pasteable `commands`.

```bash
bv --robot-triage                  # the mega-command: start here
bv --robot-next                    # just the top pick + claim command
bv --robot-triage --format toon    # TOON: token-optimized output, lower context cost
```

Before claiming, verify current state with `br show <id> --json` or `br ready --json`.
`recommendations` can include graph-important work that is blocked or already assigned —
**only `quick_ref.top_picks` and a non-empty `claim_command` mean claimable.**

### Other `bv` commands

| Command | Returns |
|---|---|
| `--robot-plan` | Parallel execution tracks with unblocks lists |
| `--robot-priority` | Priority misalignment detection with confidence |
| `--robot-insights` | PageRank, betweenness, HITS, eigenvector, critical path, cycles, k-core |
| `--robot-alerts` | Stale issues, blocking cascades, priority mismatches |
| `--robot-suggest` | Hygiene: duplicates, missing deps, label suggestions, cycle breaks |
| `--robot-diff --diff-since <ref>` | Changes since ref: new/closed/modified |
| `--robot-graph [--graph-format=json\|dot\|mermaid]` | Dependency graph export |

Scoping: `--label <x>` (subgraph), `--as-of HEAD~30` (point-in-time),
`--recipe actionable` (ready, unblocked), `--recipe high-impact` (top PageRank).

### `br` cheatsheet

```bash
br ready                  # ready to work (no blockers)
br list --status=open     # all open
br show <id>              # full detail with dependencies
br create --title="..." --type=task --priority=2
br update <id> --status=in_progress
br close <id> --reason="shipped: ..."   # close_reason is MANDATORY — see canon above
br close <id1> <id2>      # close several
br dep add <issue> <depends-on>          # wire a blocking dependency
br sync --flush-only      # export DB -> JSONL
```

**Types:** `task` · `bug` · `feature` · `epic` · `chore` · `docs` · `question`.
**Priority:** integers `0`-`4` — see § *Status & priority canon* above, not repeated here.
**Dependencies** gate `br ready`: an issue with an open blocker never appears in it.

### `br` gotchas (learned once, applies everywhere)


- **JSON shapes differ by command.** `br list --json` returns a **paginated object**
  (`.issues[]`) with a **50-row default limit** — pass `--limit 1000` for full sweeps. But
  `br ready --json` and `br show <id> --json` return **bare arrays** — index `.[0]` (e.g.
  `br show <id> --json | jq '.[0].labels'`), NOT `.id` directly: `jq '.id'` on a `br show`
  array fails with `Cannot index array with string`. Don't reach for `.issues` on these.
  Parsers must handle both shapes.
- **Bulk `br` write-loops run FOREGROUND, never backgrounded.** A bulk sequential write
  sweep (dep fan-outs, batch label stamps — more than ~10–20 sequential `br` write calls)
  runs as a plain foreground Bash call, not `run_in_background: true`: a ~129-call
  `br dep add` fan-out once stalled indefinitely in the background (zero progress, no
  errors) and completed immediately re-run foreground — suspected beads_rust SQLite
  write-lock contention, not yet root-caused. If a backgrounded bulk loop shows no
  progress, kill it and retry foreground BEFORE assuming `br` or the data is broken.
  One data point — documented caution, not a hard rule; single calls and small loops
  are unaffected.
- **Never chain `br close` to a commit in one call.** `git commit && br close <id>` records
  the **wrong SHA** when the commit fails (untracked file, bad pathspec) — the close fires
  against whatever HEAD is. Commit, verify the SHA, *then* close as a separate step.
- **`br dep add` does NO cycle prevention.** Edges added after an initial structure go
  unchecked — re-run `br dep cycles` after ANY post-hoc `dep add` batch and require it
  clean.
- **An epic with 0 OPEN children is usually DONE, not empty.** The open-board view hides
  closed children and epics don't auto-close on last child close — check closed children
  before triaging an epic as abandoned/empty.

### Working cadence

1. **Triage** — `bv --robot-triage` for the highest-impact actionable work
2. **Claim** — `br update <id> --status=in_progress`
3. **Work** — implement
4. **Complete** — `br close <id> -r "..."`
5. **Sync** — `br sync --flush-only` at session end, always

### Session protocol

```bash
git status                # what changed
git add <files>           # stage EXPLICIT paths, never -A (H7d — ac-pipeline/references/commit-discipline.md)
br sync --flush-only      # export beads changes to JSONL
git commit -m "..."
git push
```

⚠️ `br sync --flush-only` refuses after a fast-forward pull ("Export would lose N
issue(s)" = DB behind JSONL). Run a bare `br sync` (import→export) — **never `--force`**,
which deletes the pulled beads.

**ONE COMMITTER PER SCOPE.** `issues.jsonl` is a DERIVED artifact — the `.db` is the source of
truth and the JSONL is regenerable from it. So it must have exactly **one committer per scope**,
and scopes must nest: **within a run**, the conductor owns the final ledger commit (children hold
their mutations); **across scheduled jobs**, exactly one designated job commits it — or none, and
it is regenerated on demand. Never sweep it into a feature commit (the explicit-paths rule above
already covers that).

Two independent writers do not merely risk a lost update — they routinely produce the SAME derived
content, and a duplicate is what makes a commit **empty** on rebase. An automated `pull --rebase`
then stops to ask `--skip` or `--continue` with no operator present, stranding the checkout
detached mid-rebase; every session committing afterwards lands orphaned (BCA 2026-07-27: 8 hours,
~26 sessions, no data lost but main wedged). Because the DB is authoritative, the recovery is
always cheap — discard the JSONL and re-export — but the wedge is not.
