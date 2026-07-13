# Bead Conventions — types, labels, lifecycle

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
| `epic` | Grouping container | Children closed |

**No confirm-ceremony beads.** If the finding stage already diagnosed it,
file the `bug` directly. `investigation` is only for genuine unknowns.

## Labels = gating & provenance (orthogonal to type)

| Label | Meaning |
| ----- | ------- |
| `qa-finding` / `review-finding` / `hygiene-finding` | Which lens found it |
| `qa-blocker` | Gates the next merge — ac-merge refuses while open |
| `human-gate` | Agents may enrich but NEVER close — see decision beads below |
| `unrefined` | Not implementation-ready — ac-implement skips it |
| `refined` | Implementation-ready — the ONLY green light (see lifecycle contract below) |
| `tooling` | Infra/toolchain work, not app code |

## Lifecycle labels — readiness gate (the refined-stamp doctrine)

Every **open, non-epic** bead carries exactly one of three lifecycle labels:

| Label | Meaning | Who stamps it |
| ----- | ------- | ------------- |
| `unrefined` | Not implementation-ready, awaiting `/ac-bead-refine` | Default at creation (`ac-bead-capture`, `ac-beadify`) |
| `refined` | Implementation-ready | **Exclusively** `/ac-bead-refine` on convergence — no other skill, and no conductor, ever applies this label, however strong the finding's evidence |
| `human-gate` | Decision/approval bead — never implemented directly | Creator, per the decision-bead contract above |

**Readiness for implementation = presence of `refined`.** (2026-07-07 doctrine
change — this inverts the earlier convention, where *absence* of `unrefined`
meant ready. That convention let any bead created outside the normal capture
paths, or with a label accidentally stripped, silently qualify for
`/ac-implement`.) `ac-implement` gates on `refined`, not on the lack of
`unrefined`.

**Absence of any lifecycle label = unknown → treat as `unrefined` (fail-safe).**
A bead with none of the three carries a lifecycle-label gap; `ac-tidy`'s
nightly lint auto-adds `unrefined` to these — it never auto-adds `refined`,
which is only ever earned, never inferred.

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
| `epic` | `## Success Criteria` |

Plus, for every implementable bead (finding-sourced ones especially):

- **`## Test Scope`** — the file(s)/describe(s) a validator runs. Name real
  anchors: grep first, never cite a describe block you haven't seen (three
  beads in the same refine run cited nonexistent blocks). **Declare the
  validation modality, not just unit tests:** a bead that changes a user
  surface names its QA pass + journey (`browser: <journey>.md §<checkpoint>`,
  `device: …`, `ui-polish: scoped`) per `_shared/verification-gate.md`
  vocabulary — the gate's diff-inference is the safety net, the bead's
  declaration is the intent. Refine verifies the named journey exists in the
  app's `CORE/journeys/`.
- **Evidence** — file:line refs verified against the CURRENT default branch,
  plus a durable pointer (PR URL, commit sha) — never a run-temp artifact path.
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

## Lineage

Fix beads spawned by an investigation/decision carry a typed dep:
`br dep add <fix-id> <origin-id> -t discovered-from`. Then close the origin.
`br dep tree` shows the full trail.

## Where beads live

Every repo where work happens has its own `.beads/` (tracked `issues.jsonl` +
`config.yaml`; `.db` is a local cache, gitignored). Distinct issue prefixes
per db where set (`ac` = agent-compounds, `org` = root repo, `bd` = apps).
Beads live **with the work** — deps only gate within one db, so a bead
belongs in the repo whose code/files it changes. Cross-repo visibility is
ac-human-session's job (docket sweep), not a central database's.

**Public-repo rule:** some beads dbs are world-readable (agent-compounds is
a public repo — its `issues.jsonl` publishes). Beads there carry **no
strategy, money, personal, or credential content**. A decision whose memo is
sensitive keeps the memo in a private home (`_plans/`, root repo) and the
bead carries only a pointer + neutral title.

## Bulk `br` write-loops — run FOREGROUND, not backgrounded

A bulk sequential `br` write-loop (dep fan-outs, batch label stamps, batch status
flips — roughly **more than ~10–20 sequential `br` write calls**) should run as a
**plain foreground Bash call**, not `run_in_background: true`. In one session a ~129-call
`br dep add` fan-out launched in the background stalled indefinitely — zero progress, no
errors; killed and re-run identically in the foreground it completed immediately with no
special handling (suspected beads_rust SQLite write-lock contention on the background-shell
path, not yet root-caused).

**If a backgrounded bulk-`br` loop shows no output/progress, kill it and retry in the
foreground BEFORE assuming `br` or the dataset is broken.** This is a documented caution,
not a hard rule — it rests on one data point; hold off on any stronger enforcement until
the SQLite-lock hypothesis has a repro. (Single `br` calls and small loops are unaffected —
this is specifically about large sequential write sweeps.)

## Anti-inflation rules (beads are scheduled work, not a notebook)

1. **File only what survived verification** — a reviewer hunch that didn't
   survive the adversarial pass stays in the report.
2. **Dedupe first**: `br search "<keywords>"` before creating.
3. **Nits stay in reports.** A bead is something you'd genuinely schedule.
4. **`br lint`** enforces template sections — finding beads must carry
   repro/evidence/source reference.
5. **ac-tidy prunes**: stale finding-beads with no activity get closed or
   merged during pipeline housekeeping.
