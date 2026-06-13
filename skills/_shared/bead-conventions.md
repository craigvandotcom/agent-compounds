# Bead Conventions — types, labels, lifecycle

Shared by the pipeline skills (ac-qa-simulator, ac-review, ac-hygiene,
ac-merge, ac-implement, ac-human-next, ac-tidy). One principle drives all of
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
| `tooling` | Infra/toolchain work, not app code |

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

Batching: `ac-human-next` presents all open `human-gate` beads as the
**decision docket** for focused sit-down sessions.

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
ac-human-next's job (docket sweep), not a central database's.

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
