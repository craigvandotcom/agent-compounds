# Bead Conventions — the pipeline-internal contract layer (owner-hosted: beads-standards/reference/, ac-znk.7)

**Scope (ratified 2026-07-30, ac-gcj.1):** this file carries ONLY what the `ac-*`
pipeline stages enforce — I/O contract, routing, claim semantics, lifecycle wiring,
per-type close artifacts, anti-inflation. The **machine-wide floor** (taxonomy,
templates, status/priority + close-reason grammar, label hygiene, where beads live,
`bv`/`br` operations) is `skills/beads-standards/SKILL.md` — read both inside an
`ac-*` skill; never restate the floor here.

Shared by the pipeline skills (ac-qa-device, ac-qa-browser, ac-review, ac-hygiene,
ac-merge, ac-implement, ac-human-session, ac-tidy). One principle drives all of
it:

> **No pipeline stage may produce prose exhaust.** Anything actionable that a
> stage doesn't act on right now leaves as a typed bead — not a report
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
| `qa-finding` / `review-finding` / `hygiene-finding` | Which lens found it |
| `qa-blocker` | Gates the next merge — ac-merge refuses while open |
| `human-gate` | Agents may enrich but NEVER close — see decision beads below |
| `unrefined` | Not implementation-ready — ac-implement skips it |
| `refined` | Implementation-ready — the ONLY green light (see lifecycle contract below) |
| `tooling` | Infra/toolchain work, not app code |

<!-- diet: "Lifecycle labels — readiness gate (the refined-stamp doctrine)" -> ../SKILL.md § Agent bead template (doctrine); pipeline wiring retained below (ac-gcj.1) -->
## Lifecycle labels — pipeline wiring (doctrine lives in beads-standards)

The refined/unrefined/human-gate doctrine — presence-of-`refined` readiness, fail-safe
unknown, 2026-07-07 inversion rationale — is machine-wide floor:
`beads-standards` § Agent bead template. This section carries only the pipeline wiring:

- **Single-stamper invariant:** `refined` is applied **exclusively** by `/ac-bead-refine`
  on convergence — no other skill, and no conductor, however strong the evidence.
  `unrefined` is the default at creation (`ac-bead-capture`, `ac-beadify`).
- **Gap repair:** `ac-tidy`'s nightly lint auto-adds `unrefined` to beads missing all
  three lifecycle labels — it never auto-adds `refined`, which is earned, never inferred.
- `ac-implement` gates on presence of `refined`, not on the lack of `unrefined`.

**One-time board migration (legacy boards, run once per repo):** boards built
under the old convention have open beads that are implementation-ready but
only signal it by *lacking* `unrefined`. Backfill the explicit `refined` stamp:

```bash
br list --json --limit 1000 | jq -r '
  .issues[]
  | select(.status == "open")
  | select((.labels // []) as $l |
      ($l | index("unrefined") | not) and
      ($l | index("human-gate") | not) and
      ($l | index("refined") | not))
  | .id' \
| while read -r id; do br label add "$id" "refined"; done
```

## Batch-producing workflows (per-run epic + in-session refine)

Any skill that files **multiple beads in one run** (`ac-hygiene`, `ac-triage`, future ones)
follows the same batching contract — this is the shared authority both cite:

1. **2+ beads → one per-run epic.** `br create -t epic "<Skill> <date> — <noun>"` (e.g.
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
  `br close --help`). Live precedent, not theory: `bd-5gl3` is closed with `.10` still
  open and `bd-tk2b` is closed with `.9` deferred. Use it deliberately and say why in the
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
them (that's how a 2026-07-06 refine run spent its whole first round doing
creation's job):

| Type | Required header(s) |
| ---- | ------------------ |
| `bug` | `## Steps to Reproduce` + `## Acceptance Criteria` |
| `task` / `feature` | `## Acceptance Criteria` |
| `investigation` | the open question + `## Acceptance Criteria` (exit criteria: what answers it) |
| `decision` | the pre-staged memo (context · options · recommendation — see below) |
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
- **`## Delivers` + `## Consumes`** — the bead I/O contract (next section).

## Bead I/O contract (`## Delivers` / `## Consumes`)

Dep edges carry ordering ("B before A") but not payload ("A needs X from B") —
the handoff otherwise lives in agents' heads and gets re-derived per session.
These two headers write it down, making three things mechanical: pre-dispatch
premise checks (ac-implement), close-time output verification (ac-implement),
and split-coverage checks (ac-bead-refine). Skill-enforced, like Test Scope —
not a `br lint` template section. (Source: ATG, arXiv 2607.01942 — plan
`_plans/2026-07-12-bead-io-contract.md`.)

```markdown
## Delivers
- file: features/settings/api.ts — PUT /api/settings handler
- migration: 20260712_user_settings.sql — bca.user_settings table

## Consumes
- ac-abc12 → bca.user_settings table
```

`<kind>` ∈ `file | endpoint | migration | schema | doc | decision | config`.
Consumes lines are `<blocker-bead-id> → <artifact it delivers>`, or the single
literal `- none`.

Rules:

1. **Every implementable bead** (`task`/`feature`/`bug`) carries both headers.
   `epic` carries `## Delivers` only — the promise its children must cover.
   `decision`/`investigation`: `## Delivers` is one line — the recorded
   decision / the answer (their closure semantics, made explicit).
2. **Every Consumes line must correspond to an existing dep edge.** The dep
   graph stays the single authority for ordering; Consumes names the payload
   on an edge, never substitutes for `br dep add`. A Consumes line with no
   matching edge fails refine; an edge with no Consumes line is fine — some
   deps are pure sequencing.
3. **Artifacts are concrete and greppable** — a path, table, route, symbol.
   "The auth work" is not an artifact. Same discipline as Test Scope anchors:
   grep first, never name what you haven't seen.
4. **`- none` is explicit, never omitted.** A missing `## Consumes` means "not
   yet contracted" — refine treats the bead as unready.

Emit at creation (ac-beadify holds the cross-bead data flow; batch workflows
per their conventions); quick-capture (`ac-bead-capture`) is exempt — refine
authors the contract there, as it does for whatever capture omits.

## Binding vs advisory (the present-tree rule)

Beads are written at plan time and executed later, against a tree that has
moved — every recorded expensive spec failure (bd-fsx: AC depended on
components never wired into the runtime; l73.11: headline ACs owned by the
bead's own dependents) is the same event: a load-bearing claim pointing at
imagined state. The rule that removes the class:

**Binding sections** — `## Acceptance Criteria`, `## Delivers`, `## Consumes`,
`## Test Scope` (+ `## Steps to Reproduce` on bugs) — **may only reference two
things: what exists in the tree NOW (grep-verified), or what an upstream
blocker's `## Delivers` explicitly promises.** A binding claim resting on
anything else — the bead's own dependents, unwired components, unpromised
future state — is a refine-blocking defect.

**Everything else is advisory.** Suggested implementation, imagined wiring,
file-by-file how-to goes under `## Approach (advisory)` (or in comments).
Engineers re-derive the how against the real tree and may discard it;
**advisory staleness is not a defect** and reviewers don't flag it. Detail
that helps a cold-start belongs there — self-containment means a complete
contract plus useful pointers, not prophecy dressed as fact.

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
- **`investigation`** → cite the **findings + the fix beads it spawned** (the
  `discovered-from` trail below).
- **`task` / `feature`** → cite the **delivered artifact(s)** — the `## Delivers` refs
  (file / route / migration / doc).

Thin rules — no new template machinery, no per-type description headers, no lint schema
change. Enforcement is **convention-level**: `br lint` checks DESCRIPTION template
sections only (§ Body template — the `br lint` contract), NOT `close_reason` content, so
these rules live in the closing skills (`ac-implement`, `ac-batch-close`, `ac-review`) +
the refine/close review, not in a new `br lint` rule. Presence-checked, not truth-checked
— kept deliberately light until/unless `br` gains close-content linting.

## Lineage

Fix beads spawned by an investigation/decision carry a typed dep:
`br dep add <fix-id> <origin-id> -t discovered-from`. Then close the origin.
`br dep tree` shows the full trail.

## Where beads live

Machine-wide floor — `beads-standards` § Where beads live (per-repo `.beads/`, prefixes
`ac`/`org`/`bd`, beads-live-with-the-work, the public-repo content rule). Not restated here.

<!-- diet: "Bulk `br` write-loops — run FOREGROUND, not backgrounded" -> ../SKILL.md § br gotchas (ac-gcj.1) -->
<!-- diet: "br CLI gotchas (shared tool — learned once, applies everywhere)" -> ../SKILL.md § br gotchas (ac-gcj.1) -->
## Operating `br`/`bv` (bulk-write foreground rule, CLI gotchas)

Machine-wide tool learnings — `beads-standards` § Operating the tools (bulk `br`
write-loops run FOREGROUND; JSON shape differences; never chain `br close` to a commit;
0-open-children epics are usually done). Not restated here.

## Anti-inflation rules (beads are scheduled work, not a notebook)

1. **File only what survived verification** — a reviewer hunch that didn't
   survive the adversarial pass stays in the report (an inferred CAUSE that
   does survive files as `-t investigation` — the quarantined-guess rule above).
2. **ANCHOR DEDUPE — keyword search is not enough** (promoted from ac-review,
   ac-gzb P2; this is the ONE definition — sources cite, never re-derive).
   Before `br create`, take the finding's primary anchor — `file:line` for code
   findings; **journey + checkpoint** for QA findings (which have no file:line) —
   and check whether an OPEN bead already carries it
   (`br list --status open --limit 0 --json`, grep the descriptions). Same
   anchor + same defect → **`br comments add` on the existing bead** and say it
   recurred — never a second bead: recurrence recorded as a comment is the
   corroboration signal the auto-fix cascades run on; recurrence filed as a new
   bead inflates the board and loses the evidence.
3. **SEVERITY FLOOR — a Low-severity finding NEVER gets its own bead:** roll
   ALL of a run's Low findings into ONE rollup bead (one per run,
   `-t task`, each item a titled paragraph naming its anchor + source report);
   split an item out only if it later grows.
4. **ROLLUP CEILING — Low ONLY; Medium and above NEVER roll up.** One Medium+
   finding = one bead. A rollup is indivisible — it cannot be partially closed,
   prioritised, or drained, so a KEEP on it says nothing about the unexamined
   items. Medium+ findings that genuinely belong together group as an **epic
   with one child per finding** — cohesion without indivisibility.
5. **Nits stay in reports.** A bead is something you'd genuinely schedule.
6. **`br lint`** enforces template sections — finding beads must carry
   repro/evidence/source reference.
7. **ac-tidy prunes**: stale finding-beads with no activity get closed or
   merged during pipeline housekeeping.
