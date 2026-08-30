# Bead conventions — machine-wide canon (owner-hosted: beads-standards/reference/)

**Scope:** the detail layer `skills/beads-standards/SKILL.md` points into — machine-wide
canon for every repo with a `.beads/` directory: types, labels, lifecycle wiring, routing,
pick-order, claim semantics, body template, decision beads, per-type close artifacts,
admission tests, anti-inflation. One pipeline exists (ac2), and it has one bead contract:
the ac2 four-section schema (`skills/ac-beadify/references/bead-schema.md`).

Shared by the skills that file and work beads — ac-beadify, ac-implement, ac-polish,
ac-bead-capture, ac-review, ac-hygiene, ac-qa-device, ac-qa-browser, ac-triage, ac-tidy,
ac-human-session — and any workflow that files beads. One principle drives all of it:

> **No workflow may produce prose exhaust.** Anything actionable that a
> workflow doesn't act on right now leaves as a typed bead — not a report
> paragraph, not a dangling AskUserQuestion, not a markdown TODO.

## Types = kind of work

| Type | Use when | Closure means |
| ---- | -------- | ------------- |
| `task` | Default unit of planned work | Work done |
| `feature` | New capability | Shipped |
| `bug` | CONFIRMED defect (root cause or solid repro in hand) | Fixed + verified |
| `investigation` | Suspected issue / open question an agent can resolve (repro, research, spike) | Answered: spawned fix beads, or documented-and-closed |
| `decision` | A fork only the human can resolve (taste, product, money, risk) | Human decision RECORDED, consequences executed |
| `epic` | Grouping container | `## Delivers` covered, PROPOSED by `ac-tidy` |

**No confirm-ceremony beads.** If the finding stage already diagnosed it —
**diagnosed = source-traced, not inferred** — file the `bug` directly.
`investigation` is only for genuine unknowns, AND for any finding whose cause
is a hunch: **quarantine the guess, don't ban it** (ac-gzb design decision) —
the symptom enters as fact; an inferred cause enters a clearly-marked
*unverified* slot the implementer re-derives, never inherits. Type is the
carrier: source-traced cause → `-t bug`; inferred cause → `-t investigation`.

**Epics stay open across batches.** An epic's close criterion is that its `## Delivers`
promise is covered — and the close itself is PROPOSED by `ac-tidy`, not "children closed"
mechanically and not `ac-batch-close`'s job. Parent-child edges do NOT block `br ready`
(only `blocks` edges sequence), so an epic staying open across many batches starves no
work and costs nothing; do not force-close an epic just because its currently-open
children are done.

## Labels = gating & provenance (orthogonal to type)

| Label | Meaning |
| ----- | ------- |
| `origin:<skill>` | Which workflow created the bead (`origin:manual`, `origin:unknown` also legal) — required by the capture contract, `beads-standards/reference/bead-create-contract.md`, which every `br create` in the fleet satisfies. Complementary to `discovered-from` (a typed dep/body field naming the SOURCE BEAD an escape traces to): `origin:` names the CREATING WORKFLOW, `discovered-from` names the SOURCE BEAD — not duplicates. |
| `qa-finding` / `review-finding` / `hygiene-finding` | Which lens found it |
| `qa-blocker` | REPO-WIDE gate — Hard-stops ac-batch-close and ac-merge for every batch in this repo while open, not a per-bead "blocked" marker. For a single bead, use a `blocks` dependency — never this label. |
| `human-gate` | Agents may enrich but NEVER close — see decision beads below |
| `unrefined` | Not implementation-ready — ac-implement skips it |
| `refined` | Implementation-ready — the ONLY green light (see lifecycle contract below) |
| `human-ratified` | Fast-track provenance from `ac-human-session` (completeness check, not the gauntlet). Implement-eligible without `refined`; does NOT stamp `refined` / `refine-full` / `refine-light` |
| `tooling` | Infra/toolchain work, not app code |
| `pipeline-proposal` | Names a plan for a human to decide on — it does NOT implement one, so it **never counts as implementation proof**. Any gate that counts beads as evidence of work done (archive gates, coverage counts, "all matching beads closed") MUST exclude these, closed ones included: a workflow that emits proposal beads and then counts them is self-certifying. Pair with `human-gate` **only** when the body states `Gate-reason: fork —` or `Gate-reason: authorization —`; otherwise the pairing is invalid. |

<!-- diet: "Lifecycle labels — readiness gate (the refined-stamp doctrine)" -> ../SKILL.md § Agent bead template (doctrine); pipeline wiring retained below (ac-gcj.1) -->
## Lifecycle labels — pipeline wiring (doctrine lives in beads-standards)

The refined/unrefined/human-gate doctrine — presence-of-`refined` readiness, fail-safe
unknown — is machine-wide floor:
`beads-standards` § Agent bead template. This section carries only the pipeline wiring:

- **Single-stamper invariant:** `refined` is applied **exclusively** by `/ac-polish`
  on convergence — no other skill, and no conductor, however strong the evidence.
  `unrefined` is the default at creation (`ac-bead-capture`, `ac-beadify`).
- **Gap repair:** `ac-tidy`'s nightly lint auto-adds `unrefined` to beads missing all
  three lifecycle labels — it never auto-adds `refined`, which is earned, never inferred.
- `ac-implement` gates on presence of `refined`, not on the lack of `unrefined`.

## Batch-producing workflows (per-run epic + in-session refine)

Any skill that files **multiple beads in one run** (`ac-hygiene`, `ac-triage`, future ones)
follows the same batching contract — this is the shared authority both cite:

1. **2+ beads → one per-run epic.** `br create -t epic "<Skill> <date> — <noun>" --labels origin:<skill>` (e.g.
   "Hygiene 2026-07-07 — deferred findings", "Triage 2026-07-07 — findings"), children
   linked via `--parent` (`parent-child` dep). 0–1 beads → no epic (don't inflate).
2. **≥1 bead → in-session `ac-bead-refine` at run end.** Scoped to the epic if one exists
   (2+ beads), to the single bead otherwise. The conductor still holds every cluster, source
   permalink, and repro rationale in context right now — a deferred refine session has to
   re-derive all of it from cold. 0 beads → nothing to refine.
3. **Single-stamper invariant intact.** Children ship `unrefined` at creation, same as any
   other bead. The run-end `ac-bead-refine` invocation is what earns `refined` — on its own
   convergence, exclusively, exactly as for any other bead (see Lifecycle labels above). The
   batch workflow never stamps `refined` itself; it only runs the skill that does, while
   context is hot.

`ac-bead-capture` is the human quick-capture skill (one bead, typed live in conversation) —
batch workflows create beads directly via `br create` per these conventions; they do not
invoke `ac-bead-capture`.

## Bead routing (creation → parent) — convention, not a gate

A new bead routes to an epic parent by **convention**, adopted when the routing is
obvious — never a hard creation-time gate (§9 = Option B; the one ENFORCED exception is
the `human-gate` class, whose parentage is wired at creation per Arm 0 — see
`skills/beads-standards/reference/human-gate-template.md`). Four creation sources, four
routing behaviours:

| Creation source | Parent routing |
| --------------- | -------------- |
| `ac-beadify` (plan → beads) | The plan's epic, with cross-epic `blocks` edges wired per the plan's data flow |
| Ad-hoc capture / raw `br create` | Deferred — `ac-bead-refine` adopts an obvious parent when it processes the bead. A `human-gate`/DECISION shape instead resolves parentage AT capture (Arm 0), never deferred |
| In-loop exhaust (`ac-review` / QA / conductor findings) | The epic whose beads were in the batch that produced the finding; per-finding by file/scope when the batch spanned epics; fallback to a per-run review epic |
| Per-run batch workflows (`ac-hygiene`, `ac-triage`, …) | Per-run epic for 2+ beads; **0–1 beads → no epic** (unchanged — see § Batch-producing workflows) |

`ac-tidy` flags what stays unparented (the parentage-gap orphan class,
`ac-pipeline/references/board-scan.md`). What this deliberately is NOT: no I1 provenance mandate, no
disposition grammar, no backfill sweep — considered and cut.

### `--parent` is CONTAINMENT only — never provenance (bd-nbn3h)

`br create --parent <id>` mints a **dot-notation** child (`bd-xxxxx.N`) and an open
dot-child **blocks its parent's close** (verified against `br create --help` v0.2.16 and
the live board). So using it to record "this bead came out of that one" silently converts
the origin bead into one that cannot close until the derived work is done — which is the
opposite of what a provenance link should cost. **Reserve `--parent` for genuine epic
containment: "this bead is part of that epic's `## Delivers`."**

- **Provenance instead:** the `discovered-from` dep type
  (`br dep add <fix-id> <origin-id> -t discovered-from`, § Lineage below) or the
  `discovered-from:` body field (`beads-standards` § Agent bead template). Neither gates a
  close — § Lineage even has you close the origin once the trail is wired.
- **Recovery — you are NOT stuck.** If a parent is already blocked by a dot-child, closing
  or re-minting the child is **not** the only way out: `br close -f/--force` is the
  documented escape ("Close even if blocked by open dependencies", verbatim from
  `br close --help`). Use it deliberately and say why in the
  close reason — a forced close over work that genuinely still matters just hides the work.
- The `--parent` semantics themselves are **upstream** (`br` ships as a prebuilt binary; no
  source on this machine), so this convention is the whole of the local fix.

## Pick-order (which ready bead the loop picks next)

When several beads are ready, selection order is:

1. **Priority** — bugs drain first (bug-lane Rule 0), then `0` → `4`.
2. **Graph structure** — `bv` ranking / critical-path position among the same-priority set.
3. **FIFO** — creation time, oldest first, as the final tie-break.

**Arrival order is NEVER an edge.** "B was filed after A" is not a dependency — encoding it
as one fabricates a `blocks` edge that serializes work which could run in parallel and
risks wedging a chain. Ordering with no bead-level cause is priority + pick-order, never
the dependency graph.

## Claim semantics — `post-merge` exhaust (one definition)

Concurrency proof harness for claim races: `ac-pipeline/scripts/claim-race-harness.sh` (run it when changing any claim path).

Exhaust beads filed inside a batch's verify → review → close window would, if immediately
`br ready`, be claimable before the batch that spawned them has even merged. So they are
stamped **`post-merge` at creation** — the literal label `beads-closed-gate.sh` excludes
from its open-bead union, letting a batch close cleanly despite its own fresh exhaust.

**Every claim path strips `post-merge` at claim** — wave claim-at-selection, bug-lane batch
claim, and `ac-implement`'s incremental/replacement claims all remove the label the moment
they take the bead. One definition, stated once here, so no claim path forgets it and no
permanently gate-excluded zombie bead can form.

## Body template (the `br lint` contract)

`br lint` checks each bead's DESCRIPTION for per-type template sections (fuzzy
phrase match — a literal markdown header is the reliable form). **Emit these at
CREATION time** — a later refine pass verifies them, it must not have to author
them (otherwise a refine pass spends its whole first round doing
creation's job):

| Type | Required header(s) |
| ---- | ------------------ |
| `bug` | `## Steps to Reproduce` + `## Acceptance Criteria` |
| `task` / `feature` | `## Acceptance Criteria` |
| `investigation` | the open question + `## Acceptance Criteria` (exit criteria: what answers it) |
| `decision` | the pre-staged memo (context · options · recommendation — see § Decision beads below) |
| `epic` | `## Delivers` |

Plus, for every implementable bead (finding-sourced ones especially):

- **`## Test Scope`** — the file(s)/describe(s) a validator runs. Name real
  anchors: grep first, never cite a describe block you haven't seen (three
  beads in the same refine run cited nonexistent blocks). **Declare the
  validation modality, not just unit tests:** a bead that changes a user
  surface names its QA pass + journey (`browser: <journey>.md §<checkpoint>`,
  `device: …`, `ui-polish: scoped`) per `ac-pipeline/references/verification-gate.md`
  vocabulary — the gate's diff-inference is the safety net, the bead's
  declaration is the intent. Refine verifies the named journey exists in the
  app's `CORE/journeys/`.
- **Evidence** — file:line refs verified against the CURRENT default branch,
  plus a durable pointer (PR URL, commit sha) — never a run-temp artifact path.
  **Perishability (ac-gzb P3):** a claim about currently-failing external state
  (CI red, job failing, page 404s) is stamped `observed: <ISO date> · <run id/URL>`
  and is **advisory, never binding** — a binding AC may not rest on it.
- **Falsifiable ACs** — a criterion that both branches of a choice satisfy
  gates nothing; pick the branch or split the criterion.
- **`## Delivers` + `## Consumes`** — the artifact handoff, owned by the ac2 bead
  schema (`skills/ac-beadify/references/bead-schema.md`): `## Delivers` names the
  promised artifacts; `## Consumes` is one `<blocker-id> → <artifact>` per line or
  the literal `none`, and every Consumes line pairs with a dependency edge.

## Binding vs advisory (the present-tree rule)

Beads are written at plan time and executed later, against a tree that has
moved — every recorded expensive spec failure (bd-fsx: AC depended on
components never wired into the runtime; l73.11: headline ACs owned by the
bead's own dependents) is the same event: a load-bearing claim pointing at
imagined state. The rule that removes the class:

**A binding claim — any load-bearing statement a later stage executes or verifies
against (acceptance criteria, delivered artifacts, declared tests) — may only
reference two things: what exists in the tree NOW (grep-verified), or what an
upstream blocker's `## Delivers` explicitly promises.** A binding claim resting on
anything else — the bead's own dependents, unwired components, unpromised future
state — is a defect the moment it is written, owned by whoever writes it: capture,
beadify, a conductor follow-up, or a refine split.

Grep-verify a binding claim as you type it. Refine is the last net, not the
first: refine authors binding claims too — split children, contracts written
for quick-capture beads — and no later stage re-checks those.

**Everything else is advisory.** Suggested implementation, imagined wiring,
file-by-file how-to goes under `## Approach (advisory)` (or in comments).
Engineers re-derive the how against the real tree and may discard it;
**advisory staleness is not a defect** and reviewers don't flag it. Detail
that helps a cold-start belongs there — self-containment means a complete
contract plus useful pointers, not prophecy dressed as fact.

## Decision beads (the human-gate contract)

The contract that keeps autonomous sweeps safe:

1. **Agent creates it PRE-STAGED** — a decision memo, not a vague flag:
   context, options with trade-offs, agent recommendation. The agent does all
   the work a decision can absorb before the human arrives.
2. **Agents may enrich, never close.** Closure requires a recorded human
   decision (`br comments add <id> "DECISION (<human>): <choice> — <why>"`),
   after which the agent executes the consequences and closes. The decision
   trail lives in the bead.
3. **Downstream work blocks on it via normal deps**
   (`br dep add <downstream> <decision-id>`). `br ready` then excludes the
   subtree automatically — `bv --robot-next` cannot select past an undecided
   fork. The dependency graph IS the gate; no extra machinery.
4. **AskUserQuestion is for synchronous forks only** — the human is present
   and work cannot proceed in any direction. In autonomous runs the same
   fork becomes a decision bead + blocked downstream, and the sweep
   continues elsewhere.

Batching: `ac-human-session` presents all open `human-gate` beads as the
**decision docket** for focused sit-down sessions — and enforces this contract
at the dashboard: a decision arriving without a memo is flagged `⚠ no memo` and
framed on demand (it cannot be a one-tap choice without staged options).

## Per-type close artifacts

`close_reason` leads with an outcome verb (`shipped:`/`fixed:`/… — beads-standards
§ Status & priority canon); ONE level down, each type names the evidence its closure
rests on, so closed beads cluster cleanly for future metrics:

- **`bug`** → cite the **regression test** that now guards the fix (path + describe block).
  A prose/doc/config bug with no test file cites its **recorded grep/diff probe** instead
  (before-state → after-state — the same temporal shape). A NON-FIX close
  (`obsolete:` / `duplicate:` / `wontfix`) needs neither: there is no fix to guard.
- **`investigation`** → cite the **findings + the fix beads it spawned** (the
  `discovered-from` trail below).
- **`task` / `feature`** → cite the **delivered artifact(s)** — the `## Delivers` refs
  (file / route / migration / doc).

Thin rules — no new template machinery, no per-type description headers, no lint schema
change. Enforcement is **MECHANICAL at close time** (ac-on0y.2):
`ac-pipeline/scripts/close-evidence-check.sh` refuses a close whose `close_reason` lacks
the shape its type declares, wired at the single live `br close` call site (`ac-implement`'s
close step) and seam-proofed — its harness greps that call site and goes RED if the
invocation is silently reverted. `br lint` is unchanged: it checks DESCRIPTION template
sections only (§ Body template), never `close_reason`.

Still **presence-checked, not truth-checked** — semantic verification remains review's job.
Exit 2 = NOT-CHECKED and is never a pass. `epic` and `human-gate` beads are exempt (their
closure semantics differ). Historical closes are NEVER swept: the check runs at close time,
on the bead being closed. A bypass requires BOTH `--force` and `EVIDENCE-BYPASS: <why>` in
the reason, so the escape lands on the bead where a reader will meet it.

Calibrated before enforcement over all 204 closed beads (2026-08-27): pass 77 · exempt 52 ·
refuse 28 · not-checked 47. The dry run is what widened the `bug` rule above — 5 refusals
were non-fix closes and 13 were doc bugs carrying real grep evidence, neither of which a
test-path-only rule could have recognised.

## Lineage

Fix beads spawned by an investigation/decision carry a typed dep:
`br dep add <fix-id> <origin-id> -t discovered-from`. Then close the origin.
`br dep tree` shows the full trail.

## Anti-inflation rules (beads are scheduled work, not a notebook)

1. **File only what survived verification** — a reviewer hunch that didn't
   survive the adversarial pass stays in the report (an inferred CAUSE that
   does survive files as `-t investigation` — the quarantined-guess rule above).
2. **ANCHOR DEDUPE — keyword search is not enough** (this is the ONE
   definition — sources cite, never re-derive).
   Before `br create`, take the finding's primary anchor — per the lane table
   below. Every filing lane has one; a lane with no defined anchor cannot dedupe —
   and check whether an OPEN bead already carries it
   (`br list --status open --limit 0 --json`, grep the descriptions). Same
   anchor + same defect → **`br comments add` on the existing bead** and say it
   recurred — never a second bead: recurrence recorded as a comment is the
   corroboration signal the auto-fix cascades run on; recurrence filed as a new
   bead inflates the board and loses the evidence.

   | Lane | Anchor |
   |---|---|
   | review-finding · hygiene-finding | `file:line` |
   | qa-finding | journey + checkpoint |
   | curator | canonical ingredient slug + rule id (`R0`–`R9`) |
   | curator-escalation | ingredient slug + escalation reason |
   | prod-finding | Sentry issue fingerprint |
   | triage | source system + external id (GH issue #, TestFlight id) |
   | proposals (dream · pipeline · skill-improvement) | target skill/file + rule name |

   A new lane declares its anchor here before it files its first bead.
3. **NEVER ROLL UP — one finding, one bead, or no bead at all.** A rollup is
   indivisible: it cannot be partially closed, prioritised, or drained, so a
   KEEP on it says nothing about the unexamined items. Measured: every rollup
   ever filed on a mature board was still open — a rollup is a write-only bead.
   - **Low severity → the report, never a bead.** Not its own bead, not a
     shared one. The report is the durable record.
   - **Medium and above → one bead each.** Findings that genuinely belong
     together group as an **epic with one child per finding** — cohesion
     without indivisibility.
4. **Nits stay in reports.** A bead is something you'd genuinely schedule.
5. **`br lint`** enforces template sections — finding beads must carry
   repro/evidence/source reference.
6. **ac-tidy prunes**: stale finding-beads with no activity get closed or
   merged during pipeline housekeeping.

## Type admission

Each type admits on a test, not a title prefix. Type is a scheduling input: pick-order
drains `bug` before every other type (Rule 0), so a defect typed `task` waits behind every
bug and a chore typed `bug` jumps the queue.

| Type | Admits only if |
|---|---|
| `bug` | Observed behaviour differs from specified or previously-working behaviour at current HEAD. Reproduction stated as fact (`file:line` re-read at HEAD, or a driven step with observed output). Cause or a failing test in hand. |
| `investigation` | A defect is suspected but reproduction or cause is missing. Closes by spawning the `bug` or proving there is none. |
| `task` | Work with a known deliverable and no behaviour defect: chores, refactors, tests and guards, docs, config, proofs, records of past repairs. |
| `feature` | New user-visible capability. Normally a dot-child of an epic backed by a plan. |
| `decision` | A fork only the human resolves. Always `human-gate` + `Gate-reason:`. |

A missing guard or test is `task`, not `bug` — nothing is observed to be wrong yet. A
policy change ("X must now scrub Y") is `task` or `feature`; code found violating the
policy after it lands is `bug`. Refine re-grades type against this table; a change carries
a comment naming the row.

## Priority admission

Each level admits on a test, not a feeling. Without one, everything lands `2` and priority
ranks nothing.

| P | Admits only if |
|---|---|
| `0` | Production is broken NOW for real users — data loss, auth failure, payment failure. Blocks release. |
| `1` | A user hits it on a normal path AND has no workaround, or the workaround costs data or time. Reproduction verified. |
| `2` | A user hits it but a workaround exists; OR the defect is on an admin or internal path. |
| `3` | Cosmetic, or a path users rarely reach. |
| `4` | Idea or backlog. Not scheduled. |

An admin-surface defect is `2` by definition — an operator is not a user.

A filed bead states its reproduction as fact: a `file:line` re-read at the current HEAD, or a
driven step with its observed output. *May*, *likely*, *appears*, *probably* and *seems* do not
belong in a filed claim; a finding that cannot be stated as a fact is not finished.
