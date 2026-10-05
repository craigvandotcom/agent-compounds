# Cadence and jobs

What runs when, which lane it feeds or drains, and where its proof-of-life lives.

- [The wired schedule](#the-wired-schedule)
- [Feeders vs drains](#feeders-vs-drains)
- [Run markers](#run-markers)
- [Wiring a new job](#wiring-a-new-job)

## The wired schedule

Jobs are a method, not a shipped tool — wire your own scheduler (illustrated below as
`<your-deployment>/jobs/{daily,weekly,monthly}.json` run by
`<your-deployment>/scheduler/`). If `day_of_week` is in the job schema, use Python
`weekday()` semantics — **0 is Monday, 6 is Sunday**. `enabled_on` pins a job to named
machines, so a job absent from this machine's list simply never fires here.

| Job | Cadence | Lane | Role |
|---|---|---|---|
| Maintenance | daily 00:30 | all | health sweep; escalates what it cannot fix |
| Knowledge Triage | daily 01:00 | L3 | routes inbound knowledge |
| Context Mining | daily 01:30 | L3 | mines transcripts into lesson candidates |
| Retrieval Evals | daily 03:30 | L3 | scores the recall hook against the qrels set |
| Infra Sync | daily 06:30 | all | `harness-sync.sh --all` — re-projects skills/agents/hooks to every target |
| Wiki — Hallucination Audit | monthly, 1st | wiki | verifies every claim still cites something true |
| Wiki — Garden Pass | monthly, 15th | wiki | dedup, reconcile, prune |

`dream` carries no row here — it is a human-started, unscheduled session, never a cron
job: `../../dream/SKILL.md`.

The skill-friction lane has **no scheduled drain**. It is worked when someone runs the
hygiene-pass, or when a dream session promotes a weighted friction into a proposal. That
asymmetry is the lane's main risk: it is the only lane whose backlog nothing bumps.

## Feeders vs drains

Feeders are automatic and cheap; drains need judgment and are therefore rate-limited by
human attention. Every lane's failure mode is the ratio between them.

**Feeders:** context mining · knowledge triage · `reflect` at session end · every run that
writes a friction entry.

**Drains:** a `dream` session (rules each item with the human, fixes approved items
in-session) · `skill-builder` hygiene-pass · the monthly wiki passes.

**The one-way valve.** Nothing applies to a target except inside a human-run `dream`
session or a hygiene-pass under its own deterministic guards. A skill that applies its
own proposals outside that has removed the gate that makes the whole system safe.

## Run markers

A scheduled job that leaves no artifact cannot be distinguished from one that never fired.
Each lane's proof-of-life:

| Marker | Tells you |
|---|---|
| `<your-deployment>/health/reports/retrieval-evals-<date>.json` | the nightly recall measurement |
| `<your-deployment>/health/reports/memory-hook-health.json` | whether injection ran at all (liveness only) |
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
3. **Write a marker** — a dated artifact under `<your-deployment>/health/reports/` or an
   equivalent state file. If the job's only output is a Slack message, it is unverifiable.
4. **Decide the failure surface.** A non-zero exit is the scheduler's page signal; make
   sure a real failure exits non-zero and a benign one does not. A job that always exits 0
   is a job nobody will ever notice breaking.
5. **Say what it drains.** A job that only feeds a lane increases the backlog. If nothing
   downstream consumes its output, wiring it makes the system worse, not better.
