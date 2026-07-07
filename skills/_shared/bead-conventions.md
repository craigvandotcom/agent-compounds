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

## Decision beads (`-t decision` + `human-gate` + assignee)

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

## Anti-inflation rules (beads are scheduled work, not a notebook)

1. **File only what survived verification** — a reviewer hunch that didn't
   survive the adversarial pass stays in the report.
2. **Dedupe first**: `br search "<keywords>"` before creating.
3. **Nits stay in reports.** A bead is something you'd genuinely schedule.
4. **`br lint`** enforces template sections — finding beads must carry
   repro/evidence/source reference.
5. **ac-tidy prunes**: stale finding-beads with no activity get closed or
   merged during pipeline housekeeping.
