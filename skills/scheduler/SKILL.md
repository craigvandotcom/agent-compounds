---
name: scheduler
description: Use when adding, editing, reviewing, or debugging a scheduled job or agent heartbeat on pai-scheduler — recurring jobs, cron-like timing, nightly/weekly/monthly jobs, or wiring an agent's heartbeat to a level. Triggers on "add a scheduled job", "schedule a heartbeat", "recurring job", "pai-scheduler", "why didn't my job run", "cron". Covers the job schema, the agent↔level↔cwd ownership model, enabled_on/timezone conventions, and the pre-flight that a job's required skills are deployed at its cwd. NOT for authoring the skills a job invokes (that is skill-builder) or deciding where context lives (that is context-engineering).
---

# scheduler — configure & manage scheduled jobs (pai-scheduler)

**Purpose:** the canonical procedure for adding/managing recurring jobs + agent heartbeats.
**Constitution:** placement/altitude + the **capability-access invariant** come from
`../context-engineering/SKILL.md` (cited, not restated). Canonical rule: the
`pai-scheduler-canonical-scheduling` memory fact.
**Engine:** `infrastructure/scheduler/scheduler.py` · **Jobs:**
`infrastructure/jobs/{daily,weekly,monthly,annual}.json`

---

## The model: jobs are owned by agents at distinct levels (cwd = altitude)

| Agent | cwd (level) | jobs |
|---|---|---|
| **Pi** | root (global) | Maintenance 00:30 (the maintenance window) · Morning 07:30 · Night 23:30 |
| **Neo** | `neometa/` | Weekly (Fri 21:00) · Monthly · Annual reviews |
| **Sofi** | `neometa/software/` | *(scaffolded — heartbeat + workflows exist, not yet scheduled)* |
| **Curator** | an app (e.g. `body-compass-app/`) | Daily 23:00 |
| **Dream** | root (standalone, not agent-owned) | Weekly Sun 05:00 (CYCLE) |
| *(shell ticks)* | root | Queue Checker (60s) · Infra Sync (06:30) — deterministic, no agent |

A job's `cwd` sets its **altitude** — which determines the skills/scripts it can reach
(the access invariant below). Time-based ordering is the only sequencing the engine has;
encode "B after A" by clock time + a precondition check in B, not a dependency graph.

## Job schema (each `*.json` is an array of job objects)

| field | required | meaning |
|---|---|---|
| `name` | ✓ | unique — the concurrency-lock + log key |
| `time` `"HH:MM"` (or list) **or** `interval_seconds` | one of | when it fires |
| `day_of_week` `[0–6]` / `day_of_month` `[1–31]` / `month` `[1–12]` | — | weekly / monthly / annual |
| `model` | — | `"claude"` (default) · `"gemini"` · `"shell"` |
| `model_name` | — | e.g. `"opus"` |
| `prompt_file` (rel to cwd→root) / `prompt` / `command` | one of | the workflow (`command` for shell jobs) |
| `cwd` | — | run dir (must stay within ROOT_REPO) |
| `enabled_on` `[hostnames]` | — | machine filter (substring match; the VM is `"openclaw"`, the laptop `"Craigs-MacBook-Air"`) |
| `timeout` | — | seconds (default 2400 AI / 900 shell) |
| `misfire_grace_time` | — | seconds a missed fire may still run late (default 3600). **Raise it for jobs on intermittent machines** (a laptop that sleeps): a fire missed while asleep then runs on wake instead of being skipped. |

Notes: times are **Europe/Amsterdam** (engine forces tz regardless of host). YAML frontmatter
in a `prompt_file` is stripped (a leading `---` breaks the CLI). Same-name concurrent runs are
locked; a lock older than `timeout+60s` is treated as a dead prior run and taken over.

**Platform split (one system, two host profiles):**
- **VM (`openclaw`, always-on):** pai-scheduler under PM2 (`pm2/pai-scheduler.config.js`); jobs
  fire on time. The default home for scheduled work.
- **Mac (laptop, intermittent):** *also* pai-scheduler under PM2 — same engine, same
  `jobs/*.json` (hostname-filtered, so each host runs only its `enabled_on` jobs). Because a
  laptop sleeps, give Mac jobs a **generous `misfire_grace_time`** (e.g. 12h) so a fire missed
  during sleep runs on wake (apscheduler coalesces to one run). Residual: after a full
  *shutdown* (vs sleep) there's no while-off catch-up (in-memory jobstore) — it resumes at the
  next interval after PM2 relaunches at login. We use this instead of launchd to keep ALL
  scheduling in one git-tracked system. The PM2 config picks a per-machine `.venv` python if
  present (the Mac needs apscheduler installed there), else system `python3` (the VM).

## Pre-flight: capability availability  *(the access invariant — context-engineering)*

Before wiring a job/heartbeat, **verify every skill/script its workflow invokes is reachable
at its `cwd`** (skills project via `deploy.sh` into `.claude/skills/` at each level; one not
present at the cwd or an ancestor is unreachable). **A heartbeat referencing an absent skill
fails unattended, at 3am.** Procedure: read the `prompt_file`, list the skills/scripts/CLIs it
loads, confirm each resolves at the cwd. *(The invariant — required capabilities must be
reachable at the consumer's altitude — is owned by context-engineering ALTITUDE; this is its
scheduler application.)*

Also confirm the workflow's **instructions are executable in the unattended context** — e.g.
`git pull --rebase` fails where rebase is deny-listed (use `--ff-only`); no step may require a
human or an interactive prompt.

## Add a job (procedure)
1. Pick the cadence file (`daily`/`weekly`/`monthly`/`annual`).
2. Choose the **owner agent + cwd** (the level it runs at).
3. Write the workflow as a `prompt_file` (heartbeat) or a `command` (shell tick).
4. **Run the pre-flight** (capabilities reachable at cwd · instructions unattended-safe).
5. Add the JSON object; set `enabled_on` for the right machine(s).
6. Validate it loads: the engine logs `Loaded Job: <name>` on start (or `run_job_now`).

## Conventions (from `pai-scheduler-canonical-scheduling`)
- ALL recurring jobs (incl. shell) live in `infrastructure/jobs/*.json` — **never crontab**
  (intentionally empty) and never a raw PM2 cron (pai-scheduler gives watchdog + Discord
  failure alerts + a heartbeat — the dead-`qmd-watcher`-rotted-silently lesson).
- `enabled_on` per machine; pm2 `"stopped"`/`"waiting restart"` is often by-design.

## Common mistakes
| Mistake | Fix |
|---|---|
| Heartbeat invokes a skill not deployed at its cwd | Run the access pre-flight; `deploy.sh` the skill to that level |
| A step that can't run unattended (`pull --rebase` on a deny-listed host; interactive prompt) | Use the env-safe form (`--ff-only`); remove human-gated steps |
| Raw PM2 cron / crontab entry | Move it into `infrastructure/jobs/*.json` |
| Job runs on the wrong/all machines | Set `enabled_on` |
| Encoding "run B after A" as a dependency | Order by clock time + a precondition check inside B |
