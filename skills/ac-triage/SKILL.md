---
name: ac-triage
description: Use to pull operational + user signal BACK IN from external systems — crashes, errors, logs, beta feedback, externally-filed issues — cluster it, and route real findings by shape — defects to beads, recurring feature/experience themes to the backlog pool (as candidates the human approves). Fetches from Sentry, App Store Connect (TestFlight feedback), Supabase logs, GitHub Issues, PostHog, store reviews. The inbound counterpart to ac-distribute. Triggers on "triage crashes", "check sentry", "any new errors", "pull feedback", "triage github issues", "what's breaking in prod", "triage production signal", "review crash reports". Headless — runs anywhere, scheduled. NOT for triaging the bead board itself — that is bv (read-only) or ac-polish (bead mode).
---

> **Generic skill — method only, zero app facts.** Symlinked from agent-compounds and
> shared across consuming apps (incl. web-only ones). App specifics — Sentry org/project
> slug, Supabase project ref, ASC app id, PostHog project, which sources are live, the
> per-app severity bar — live in the consuming app's **`.claude/skills/CORE/triage.md`**.
> Read that FIRST. Secrets (Sentry token, service-role keys) are POINTED TO, never stored.

# ac-triage — the signal-IN lane

**You poll external systems for signal and turn the real findings into beads.** The
**external-systems sibling** to **`ac-bead-capture`**: the dividing line is not machine-vs-
human but **polled-from-a-system vs handed-to-you-in-conversation** — triage FETCHES signal
sitting in an external system, or it would be missed.

**Scope boundary:** ac-triage FETCHES + clusters external signal and routes each confirmed
finding **by shape** — defects to **`ac-bead-capture`** (classification, repo-routing,
dedupe), feature/experience themes to the **backlog pool** as candidates. It does NOT ship
builds (that's `ac-distribute`) and does NOT reimplement the bead-side conventions — it hands
off. Headless, source-agnostic, cross-app; only the *sources* are app-specific.

Findings disposition per `ac-pipeline/references/disposition.md` (this skill is its
external-signal instantiation). Loop guard: beads created by triage carry a
`triage,<source>` label + the source record id; NEVER re-import a finding whose source id
already maps to a bead, and exclude triage-authored issues from outbound syncs so the loop
can't feed itself.

**The method** (per-run ledger, Phases 0–4: scope+watermark · fetch · cluster+dedupe ·
route by shape · report) lives in `references/method.md`. The workflow
`workflows/scheduled-daily.md` is the headless heartbeat skeleton that runs it.

## Sources (pluggable adapters — enable per app in CORE/triage.md)

| # | Source | Signal | Auth (pointer) |
| --- | --- | --- | --- |
| 1 | **Sentry** | symbolicated crashes + JS/native errors, freq. | `SENTRY_AUTH_TOKEN` + org/proj |
| 2 | **App Store Connect** | TestFlight beta feedback + crash submissions | ASC API key (`.p8`) |
| 3 | **Supabase** | edge-function logs, Postgres errors, auth failures | service-role / mgmt API |
| 4 | **GitHub Issues** | externally-filed bug reports / feature requests | `gh` CLI / token |
| 5 | PostHog (later) | funnel drop-off, error events, session signal | project API key |
| 6 | **Feedback reports** | solicited in-app user feedback (structured) | service-role — see `references/feedback-adapter.md` |
| 7 | store reviews (later) | App Store / Play user reviews | ASC / Play API |

Source numbers 1–5 are fixed across all apps; #6 applies to apps with a structured in-app
feedback table; #7 is deferred. Per-app `CORE/triage.md` assigns and enables sources — the
number is per-app, not global. Source bindings (Sentry project slug, Supabase schema) read
from `templates/factory.json` `triage.*` keys where the app carries them. Sentry is source
#1 — symbolicated stacks are the highest-signal input. A source that isn't configured is
skipped, not an error; a source that IS wired and fails to fetch escalates (see method).

## Route by shape, not by source

The same rule `ac-backlog` uses: a *defect* — something broken, a specific reproducible
crash/error — becomes a **bead** (execution-ready). A *desire or pattern* — a feature
request, a recurring UX friction, anything needing design — becomes a **backlog candidate**
(it needs planning, not a thin bead). Crashes/errors are almost always defects; beta
feedback / filed issues / store reviews are often desires. Cluster raw events by fingerprint,
cross-reference recent waves/commits, dedupe against open beads AND open pool candidates —
recurrence updates the existing bead/candidate, it never creates a duplicate.

## Cadence

Designed to run **scheduled + headless** (pure API work, no Mac); also on demand
("triage crashes"). Defect findings land as beads the loop picks up; theme findings land as
backlog candidates the human approves in `/ac-human`'s 🟢 hopper. The high-leverage
automation in the pipeline: the only step that manufactures work from *real users* instead
of the team's own ideas.

## Per-app facts → CORE/triage.md

**Onboarding a new app:** copy `triage.template.md` (this skill dir) → the app's
`.claude/skills/CORE/triage.md` and fill every `{{…}}` (incl. the `template_version` stamp).
The CORE file is app-owned and never auto-overwritten; `infra-sync` flags
`template_version` drift. Never edit this symlinked SKILL.md per-app — method changes land
HERE and propagate everywhere.

## Remember

- **Route by shape, not source** — defects → beads; feature/experience themes → backlog candidates.
- **One bead per fingerprint**, with a source link + suspected wave. No cold trails.
- **Sentry first** — symbolicated stacks beat sparse beta-crash APIs.
- **A source not configured is skipped; a source configured-but-FAILING is an escalation**
  — file/update the ops bead, never silently skip a wired source, never advance its watermark.
- **Per-run epic** (2+ finding-beads) — refined through `/ac-polish`, never in-session.
- **Inbound counterpart to `ac-distribute`** — it ships out, this listens back.