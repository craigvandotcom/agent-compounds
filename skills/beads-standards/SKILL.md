---
name: beads-standards
description: 'Use when creating, refining, or reviewing a bead in ANY `.beads/` project under ~/Repos — choosing a label, deciding refined vs unrefined, writing a human-gate/DECISION bead, wiring `blocks` dependencies, setting `close_reason` or `defer_until`, or picking priority/status. Triggers: "beads standard", "bead template", "human-gate", "DECISION bead", "HUMAN bead", "create a bead", "close reason", "refined unrefined", "wire dependencies", "which label". Machine-wide canon for every repo with a `.beads/` directory (root, every app, agent-compounds, future personal task tracking) — not scoped to the agent-compounds `ac-*` pipeline (that pipeline''s own batch-epic + routing supplement lives in `skills/beads-standards/reference/bead-conventions.md`; read both inside an `ac2` skill). This is the STANDARD, not an executor: to actually refine a bead use ac-bead-refine, to capture one use ac-bead-capture, to generate a wave use ac-beadify.'
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

Pipeline-side extensions for the agent-compounds `ac2` production line (batch-epic +
in-session refine, bead routing, claim semantics, binding-vs-advisory)
live in `skills/beads-standards/reference/bead-conventions.md` — this skill is the wider floor every
project stands on; that file is the detail layer `ac2` skills also need.

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
label is legal only when the body names what ONLY the human can supply:

```
Gate-reason: fork — <the irreducible choice; no option is objectively better>
Gate-reason: authorization — <what is spent or exposed>
Gate-reason: intent — <what was meant; unrecoverable from the repo at any depth>
Gate-reason: action — <the outward-facing act only the human may perform>
```

A `human-gate` with no marker is invalid — do not file it. Mechanical work is never gated.

**The check runs BOTH ways.** A bead whose acceptance criteria cannot be satisfied without
the human MUST carry the label and a marker. An unmarked one is worse than a false gate: no
docket shows it, so every wave claims it and bounces it. "I could not decide" is not a
gate reason — finish the analysis or name which of the four applies.

**`DECISION:` — a decision card** (a fork that passes the escalation test). The card shape,
the three mandatory fork fields (`evidence:` · `consequence:` · `recommendation:`), and the
five-condition test (Real · Unsettled · Not evidence-settleable · Human-owned consequence ·
Costlier wrong than asked) have ONE home: `reference/human-gate-template.md` § The escalation
test, with `## Before filing` as the run order. Every site points there and defines nothing
itself. (`HUMAN:` remains an accepted alias prefix for a decision-shaped gate that isn't a
fork — an approval, credential handoff, or go/no-go — same fields, same wiring rule.)

**`ACTION:` — an action card** (a do-in-the-world task only Craig can perform — a console
toggle, a store submission, a credential handoff). Not a fork, so **no options block**; the
copy-paste field block + worked example (BCA `bd-l6khg.13`) live in
`reference/human-gate-template.md` § ACTION cards.

**MANDATORY dependency wiring — not optional, not "if convenient":** every bead this
decision gates gets a `blocks` edge back to the decision, at creation time
(`br dep add <downstream> <decision-id>`; the Exhaust-Rule rationale + cockpit ground
truth #3 — 30/31 open gates with zero downstream reach before this rule — live in
`reference/human-gate-template.md` § Mandatory dependency wiring).

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
| `refined` | Implementation-ready **and probe-bearing**: every AC names an executable probe — a `Probe:` line a gate can run. Stamped **exclusively** by `skills/_tools/stamp-refined.sh` at refine convergence, which refuses probe-less descriptions — no conductor or capture step ever applies it directly. (Measured 2026-08-29: 18 of 22 `refined` beads in one ready pool were probe-less — every ac2 claim died NOT-GATED at flight-check.) |
| `unrefined` | Needs a refinement pass before agent pickup. Default at creation. |
| *(neither)* | **Ungraded — never assume ready.** Missing-both is not "not ready" either; it's unknown. Fail-safe: treat as unrefined until graded. |

**Kind — the filing axis:**

| Label | Meaning |
|---|---|
| `kind:product` | A defect in the thing users touch. The only kind the board admits, and only at priority `0`/`1` with a verified reproduction. |
| `kind:machinery` | A DEFECT in the factory — pipeline, skill text, lint, bead schema, CI wrappers, harness, tool flags, local stack. Belongs in a `friction:` block, NEVER the board. On the board it is a filing defect, not a category. A factory **action** carrying a real trigger or dependency edge is not this: a friction log holds no trigger, so it stays a bead. |

Kind is set at creation by whoever files. A bead with no kind is unrouted, so an autonomous run may not file one. **Every `br create` in the fleet satisfies one capture contract — `reference/bead-create-contract.md`.** It names the required axes (`origin:<skill>` for the creating workflow; a readiness label on every non-epic bead) and the two enforcers that hold them: `hooks/bead-capture-guard.py` at creation, `lint.sh` Check 19 on the templates the registry ships. Skills carry their own template, never their own copy of the rules — point at the contract with a `§` anchor. Origin values and the `skill:`/`discovered-from:` boundaries: `reference/origin-provenance.md`.

Readiness for pickup = **presence** of `refined`, never inferred from the absence of
`unrefined`. This is what gates loop/agent pickup everywhere this labelling is adopted.

**Holds are labels or edges, never body prose.** A "do not implement" that lives only in the
body is invisible to every eligibility filter — the bead still reads claimable and burns a
claim before its first read. Carry a hold as `human-gate` (human fork), an open `blocks`
edge (waiting on work), or `deferred` (waiting on time); the body may explain the hold, never
carry it alone. (Measured: bd-1538r, 2026-08-29 — self-held in prose, claimed anyway.)

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
0 = critical, 4 = backlog. Never a word ("high"/"low") in the field itself. Each level admits
on a TEST — `reference/bead-conventions.md` § Priority admission; type admits the same way, § Type
admission (pick-order drains `bug` first, so type schedules). Without a test everything lands `2`.

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
- `origin:<skill>` — the creator/provenance axis, enforced forward-only by `hooks/bead-capture-guard.py`

Adding a NEW load-bearing label is allowed (it breaks no existing series); **renaming or retiring** a frozen one requires the migration note. Worked example — **`degraded-solo`** (added 2026-07-29, bd-nreuv): a capability-starved run (no `Task` tool, or spawns exhausted) stamps it **alongside** the path label, never instead of it, so the pair series above stays intact and `refine-full ∧ degraded-solo` is one grep; grammar + the `refine-light-solo` criteria live in `ac-pipeline/references/degraded-mode.md`. Migration log:

- 2026-08-29 — `origin:ac2-*` label series renamed to `origin:ac-*` equivalents
  (origin:ac2-implement→origin:ac-implement, origin:ac2-review→origin:ac-review,
  origin:ac2-beadify→origin:ac-beadify, origin:ac2-polish→origin:ac-polish,
  origin:ac2-plan→origin:ac-plan, origin:ac2-publish→origin:ac-publish) as part of the
  ac2→ac skill rename. The ledger sweep runs in the app repo at the same cutover.
  Historical bead comments keep the old tokens — comments are history, not labels.
- 2026-08-29 — `refined` definition tightened (not renamed, no sweep needed): it now means
  probe-bearing, and `skills/_tools/stamp-refined.sh` refuses probe-less descriptions.
  Zero-probe stamps from before the floor are labeling defects — restamp on sight, never
  grandfather. (Measured: 18/22 ready-pool beads probe-less, ac-implement run 2026-08-29.)

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
- **`qa-blocker` is REPO-WIDE, not per-bead.** It is a gate label: Hard-stops
  ac-batch-close and ac-merge for every batch in this repo until removed. Use it only
  when the whole ship path must halt pending QA. To mark a single bead blocked, use a
  `blocks` dependency — never this label. (There is no `blocked` status.)

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

> Migrated here from root `AGENTS.md` (2026-07-25, context-tokenomics): look-up
> material for beads work, never load-on-spawn prose. Status/priority canon is above.

`br` ([beads_rust](https://github.com/Dicklesworthstone/beads_rust)) is the issue
tracker; `bv` ([beads_viewer](https://github.com/Dicklesworthstone/beads_viewer)) is a
graph-aware triage engine over `.beads/beads.jsonl`. Use `bv`'s robot flags for
deterministic, dependency-aware output (PageRank, betweenness, critical path, cycles)
rather than parsing JSONL or guessing at graph traversal.

**Scope boundary:** `bv` decides *what to work on*, `br` creates, modifies and closes.
**Use ONLY `--robot-*` flags — a bare `bv` launches an interactive TUI that blocks the session.**

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
br create --title="..." --type=task --priority=2 --labels=origin:<skill>,unrefined   # origin: is MANDATORY — see canon above
br update <id> --status=in_progress
br close <id> --reason="shipped: ..."   # close_reason is MANDATORY — see canon above
br close <id1> <id2>      # close several
br dep add <issue> <depends-on>          # wire a blocking dependency
br update <id> --status closed           # REFUSED rc 4 — terminal states close via `br close -r` only (0.5.12)
# .beads/policy.yaml would gate closes/transitions; a malformed one makes every command exit 7 (absent here)
br sync --flush-only      # export DB -> JSONL
```

**Types:** `task` · `bug` · `feature` · `epic` · `chore` · `docs` · `question`.
**Priority:** integers `0`-`4` — see § *Status & priority canon* above, not repeated here.
**Dependencies** gate `br ready`: an issue with an open blocker never appears in it.

### `br` gotchas (learned once, applies everywhere)


- **JSON shapes differ by command.** `br list --json` returns a **paginated object**
  (`.issues[]`) with **no default limit** (`br schema commands` on `br` 0.5.12: `limit: 0`,
  truncation disclosed via `has_more` — sweep with `--limit 0`). But
  `br ready --json` and `br show <id> --json` return **bare arrays** — index `.[0]` (e.g.
  `br show <id> --json | jq '.[0].labels'`), NOT `.id` directly: `jq '.id'` on a `br show`
  array fails with `Cannot index array with string`. Don't reach for `.issues` on these.
  Parsers must handle both shapes.
- **`br list` hides CLOSED beads by default — pass `--all`.** Without it an existence
  probe false-negatives: a conductor once concluded a plan had zero beads and dispatched
  a beadify child, when the epic was 18/20 closed and shipped. Sound probe form:
  `br list --all --limit 0 --json`, matched against title AND labels AND description —
  matching descriptions only misses beads titled from the plan's own heading.
- **A `-d`/`--description` body is shell text, not a literal.** A double-quoted body
  containing backticks runs command substitution; an angle-bracket `<placeholder>` parses
  as a redirect. Both fail with a shell-syntax error that names nothing about the bead.
  Pass any multi-line body via a FILE: `br comments add <ID> -f <file>` (ID comes first),
  and capture a `br create` body with `-d "$(cat <file>)"` — the file is not re-scanned,
  so backticks and angle brackets stay literal.
- **`br label add` applies every positional label, rc 0** (measured on `br` 0.5.12; the
  same call errored rc 3 on 0.2.x). Mixing bare labels with `-l` flags is a validation
  error, rc 4 — verify with `br show` afterwards.
- **`br lint` scans the DESCRIPTION field only — never `--notes`.** A lint-required
  section added via `--notes` leaves the finding open and reads as a flaky linter. Fold
  every lint-required section into the `-d`/`-f` body.
- **`bv` has no `--robot-list`.** To list or search beads use `br list --all --limit 0
  --json`, not `bv` — `bv` is the triage surface, `br` is the ledger surface.
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
- **`br dep add` refuses a write that CLOSES a cycle, rc 5** (measured on `br` 0.5.12);
  only a lone reversed edge that closes no cycle lands silently — re-run `br dep cycles`
  after any post-hoc `dep add` batch and require it clean.
- **An epic with 0 OPEN children is usually DONE, not empty.** The open-board view hides
  closed children and epics don't auto-close on last child close — check closed children
  before triaging an epic as abandoned/empty.
- **`br` in a NON-TTY context (scripts/agents) mis-executes compound one-liners** — a call chained
  with `&&`, or inside a `for` loop, pipe or substitution, can fail with a "not a terminal" error.
  Give every `br` call its own standalone Bash invocation (worker.md's `--json`/`-f` pattern).

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
