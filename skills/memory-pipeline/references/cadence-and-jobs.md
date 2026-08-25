# Cadence and jobs

What runs when, which lane it feeds or drains, and where its proof-of-life lives.

- [The wired schedule](#the-wired-schedule)
- [Feeders vs drains](#feeders-vs-drains)
- [Run markers](#run-markers)
- [Wiring a new job](#wiring-a-new-job)

## The wired schedule

Jobs live in `infrastructure/jobs/{daily,weekly,monthly}.json` and are executed by
`infrastructure/scheduler/`. `day_of_week` uses Python `weekday()` semantics — **0 is
Monday, 6 is Sunday**. `enabled_on` pins a job to named machines, so a job absent from
this machine's list simply never fires here.

| Job | Cadence | Lane | Role |
|---|---|---|---|
| Maintenance | daily 00:30 | all | health sweep; escalates what it cannot fix |
| Knowledge Triage | daily 01:00 | L3 | routes inbound knowledge |
| Context Mining | daily 01:30 | L3 | mines transcripts into lesson candidates |
| Dream Queue — Stale Escalation | daily 02:25 | L3 | priority-bumps `dream-proposal` beads older than 7d |
| Retrieval Evals | daily 03:30 | L3 | scores the recall hook against the qrels set |
| Infra Sync | daily 06:30 | all | `harness-sync.sh --all` — re-projects skills/agents/hooks to every target |
| Dream Queue (apply + file) | Monday 02:00 | L3 | applies the auto tier; files gated proposals as beads |
| Dream Cycle | Sunday 07:30 | L3 | the full CYCLE — gather, synthesize, lint, judge, emit |
| Wiki — Hallucination Audit | monthly, 1st | wiki | verifies every claim still cites something true |
| Wiki — Garden Pass | monthly, 15th | wiki | dedup, reconcile, prune |

The skill-friction lane has **no scheduled drain**. It is worked when someone runs the
hygiene-pass, or when a dream cycle promotes a weighted friction into a proposal. That
asymmetry is the lane's main risk: it is the only lane whose backlog nothing bumps.

## Feeders vs drains

Feeders are automatic and cheap; drains need judgment and are therefore rate-limited by
human attention. Every lane's failure mode is the ratio between them.

**Feeders:** context mining · knowledge triage · `reflect` at session end · every run that
writes a friction entry.

**Drains:** the Monday queue job (auto tier only) · `dream` REVIEW (gated) ·
`skill-builder` hygiene-pass · the monthly wiki passes.

**The one-way valve.** CYCLE never applies — it only emits. The apply path is the Monday
job for the two auto tiers, and a human for everything else. Nothing else may write to a
target on the cycle's behalf; a skill that applies its own proposals has removed the gate
that makes the whole system safe to run unattended.

## Run markers

A scheduled job that leaves no artifact cannot be distinguished from one that never fired.
Each lane's proof-of-life:

| Marker | Tells you |
|---|---|
| `infrastructure/dream-cycle/last-run.json` | when CYCLE last completed, and what it read/emitted |
| `infrastructure/dream-cycle/escalated.json` | which stale beads were bumped, and when |
| `infrastructure/health/reports/retrieval-evals-<date>.json` | the nightly recall measurement |
| `infrastructure/health/reports/memory-hook-health.json` | whether injection ran at all (liveness only) |
| a proposal's `status:` frontmatter | `pending` → `applied` / `rejected`; the terminal value means it actually landed |
| a friction entry's `status:` | `open` → `promoted` when the skill edit ships |

**A missing marker is a finding, not an absence.** Compare the marker's timestamp against
the cadence: a weekly job whose marker is 3 weeks old did not run quietly, it failed
quietly.

## Wiring a new job

1. **Check the capability is reachable at the job's cwd.** A job running at `cwd=X` can
   only invoke skills and scripts projected to X or above it. A heartbeat that references
   an absent skill fails unattended, at 3am. (`context-engineering` § ALTITUDE.)
2. **Pin `enabled_on`** to the machines that should run it. Unpinned jobs either
   double-run or never run.
3. **Write a marker** — a dated artifact under `infrastructure/health/reports/` or an
   equivalent state file. If the job's only output is a Slack message, it is unverifiable.
4. **Decide the failure surface.** A non-zero exit is the scheduler's page signal; make
   sure a real failure exits non-zero and a benign one does not. A job that always exits 0
   is a job nobody will ever notice breaking.
5. **Say what it drains.** A job that only feeds a lane increases the backlog. If nothing
   downstream consumes its output, wiring it makes the system worse, not better.
