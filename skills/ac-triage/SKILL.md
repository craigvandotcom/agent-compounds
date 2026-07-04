---
name: ac-triage
description: Use to pull operational + user signal BACK IN from external systems — crashes, errors, logs, beta feedback, externally-filed issues — cluster it, and route real findings by shape — defects to beads, recurring feature/experience themes to the backlog pool (as candidates the human approves). Fetches from Sentry, App Store Connect (TestFlight feedback), Supabase logs, GitHub Issues, PostHog, store reviews. The inbound counterpart to ac-distribute. Triggers on "triage crashes", "check sentry", "any new errors", "pull feedback", "triage github issues", "what's breaking in prod", "triage production signal", "review crash reports". Headless — runs anywhere, scheduled.
---

> **Generic skill — method only, zero app facts.** Symlinked from agent-compounds and
> shared across consuming apps (incl. web-only ones). App specifics — Sentry org/project
> slug, Supabase project ref, ASC app id, PostHog project, which sources are live, the
> per-app severity bar — live in the consuming app's **`.claude/skills/CORE/triage.md`**.
> Read that FIRST. Secrets (Sentry token, service-role keys) are POINTED TO, never stored.

# ac-triage — the signal-IN lane

**You poll external systems for signal and turn the real findings into beads.** This is the
**external-systems sibling** to **`ac-bead-capture`**. The dividing line is NOT machine-vs-
human — it's **polled-from-a-system vs handed-to-you-in-conversation**:

- `ac-bead-capture` — signal you hold right now and type ("bead this idea / log this bug").
- `ac-triage` — signal sitting in an **external system** you must FETCH or you'll miss it:
  Sentry (machine), Supabase logs (machine), **ASC beta feedback (human)**, **GitHub Issues
  (human)**, store reviews (human). Author type is irrelevant; the *fetch* is what unites them.

It closes the Discovery→beads flywheel: real-user breakage becomes tracked work without a
human having to notice and report it.

**Scope boundary:** ac-triage FETCHES + clusters external signal and routes each confirmed
finding **by shape** — defects to **`ac-bead-capture`** (which owns classification, repo-
routing, and dedupe), feature/experience themes to the **backlog pool** as candidates. It
does NOT ship builds (that's `ac-distribute`) and does NOT itself reimplement the bead-side
conventions — it hands off. Headless, source-agnostic, cross-app; only the *sources* are
app-specific.

**Route by shape, not by source** (the same rule `ac-backlog` uses): a *defect* — something
broken, a specific reproducible crash/error — becomes a **bead** (execution-ready). A *desire
or pattern* — a feature request, a recurring UX friction across reports, anything needing
design — becomes a **backlog candidate** (it needs planning, not a thin bead). Crashes/errors
are almost always defects; beta feedback / filed issues / store reviews are often desires.

**Loop guard:** beads created by triage carry a `triage,<source>` label + the source record
id (e.g. the Sentry issue id / GitHub issue number) in the bead. NEVER re-import a finding
whose source id already maps to a bead — and if beads also sync OUT to GitHub issues, exclude
triage-authored issues by that marker so the loop can't feed itself.

## Sources (pluggable adapters — enable per app in CORE/triage.md)

| #   | Source                  | Signal                                          | Auth (pointer)             |
| --- | ----------------------- | ----------------------------------------------- | -------------------------- |
| 1   | **Sentry**              | symbolicated crashes + JS/native errors, freq.  | `SENTRY_AUTH_TOKEN` + org/proj |
| 2   | **App Store Connect**   | TestFlight beta feedback (notes + screenshots), crash submissions | ASC API key (`.p8`) |
| 3   | **Supabase**            | edge-function logs, Postgres errors, auth failures | service-role / mgmt API |
| 4   | **GitHub Issues**       | externally-filed bug reports / feature requests (matters for public/OSS repos) | `gh` CLI / token |
| 5   | PostHog (later)         | funnel drop-off, error events, session signal    | project API key            |
| 6   | **Feedback reports**    | solicited in-app user feedback (structured, owned table) | service-role (see adapter spec) |
| 7   | store reviews (later)   | App Store / Play user reviews                     | ASC / Play API             |

Source numbers 1–5 are fixed across all apps. Source #6 (feedback reports) applies to apps
with a structured in-app feedback UI writing to an owned table. Source #7 (store reviews) is
deferred. Per-app CORE/triage.md assigns and enables sources; the number is per-app, not
global — if your app needs a different slot, use the CORE/triage.md table as the authority.

**Feedback reports (source #6):** solicited in-app feedback stored in a service-controlled
Supabase table (e.g. `public.feedback_reports`). Distinct from source #3 (error-log clustering)
— this reads VOLUNTARY structured reports, not machine-generated errors. Full adapter spec
(query, dedup, evidence-guard, write-back, unit test cases):
`references/feedback-adapter.md`.

**Sentry is source #1** — symbolicated native + JS stacks are the highest-signal, lowest-
noise input, and it captures crashes whether or not a tester taps "report." **ASC #2 is
validated** (2026-06-13): `GET /v1/apps/{appId}/betaFeedbackCrashSubmissions` (JWT from the
`.p8`, no `sort` param on the nested path) returns tester crash submissions with
comment/email/deviceModel/os — it adds the human texture Sentry can't see. **GitHub Issues
#4** is per-repo: high value on public/OSS repos (vitest-affected, neometa-brand) where
outsiders file; near-N/A on private app repos with no external filers — enable per app. Light
up sources as they're wired; a source that isn't configured is skipped, not an error — but a
source that IS wired and fails to fetch escalates (see Phase 1).

## Method (per run)

### Phase 0 — scope + watermark

Read `CORE/triage.md` for enabled sources + per-app severity bar. Load the **last-run
watermark per source** (timestamp / last issue id / cursor) from the app's
**`.claude/state/triage-watermarks.json`** (committed, one key per source:
`{"sentry": {"watermark": "<ISO ts / cursor>", "updated": "<ISO ts>"}, …}`) so each run
only pulls NEW signal. Missing file or missing key = first run for that source: bounded
lookback (e.g. last 7 days) to avoid a flood, then write the entry.

### Phase 1 — fetch (per enabled source, in parallel)

Pull signal since the watermark via each source's API (pointer-auth from CORE):

- **Sentry:** issues sorted by `lastSeen`, with `count`, `userCount`, culprit, latest
  event stack, release. Prefer unresolved + regression issues. Canonical fetch (region
  API host from CORE/triage.md — EU-region orgs live on `de.sentry.io`, and calls to
  `sentry.io` fail there even with a valid token):
  `curl -sf -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" "https://<region-host>/api/0/projects/<org>/<project>/issues/?query=is:unresolved&sort=date&statsPeriod=14d"`
- **ASC:** `GET /v1/apps/{appId}/betaFeedbackCrashSubmissions` (+ `…ScreenshotSubmissions`),
  JWT from the `.p8`; filter to records newer than the watermark `createdDate`.
- **Supabase:** error-level logs / failed-request rows since watermark.
- **GitHub Issues:** `gh issue list --state open --search "updated:>=<watermark>"`; EXCLUDE
  triage-authored issues (loop guard) and issues already linked to a bead — linkage marker
  = a `bead:<id>` line in the issue body (write it when the bead is created) or a `triaged`
  issue label.

Record the new watermark per source AFTER a successful fetch — NEVER advance a watermark
on a failed or partial fetch.

**Configured-but-failing ≠ not-configured.** A source that CORE/triage.md marks live but
that errors at fetch (auth 401, network, schema change) is an **escalation**, not a skip:
mark it `✗ FAILING (<error>)` in the Phase-4 report and file ONE ops bead
(`br create -t task --labels triage,ops,human-gate`) so it surfaces in `ac-human-session`
— dedupe first, update the existing open ops bead if one already tracks this failure.
Silent-skip is reserved for sources that were never wired.

### Phase 2 — cluster + dedupe (your core work — do NOT delegate)

- **Cluster** raw events into issues by fingerprint (Sentry already does this; do it for
  ASC/Supabase by error signature + location). N crash events of one bug = ONE finding.
- **Cross-reference** each cluster against recent waves/commits (`git log` since the
  finding's first-seen release) — a crash that appeared right after wave X is a strong lead.
- **Severity** per the app's bar: frequency × user-count × crash-vs-error × is-it-on-a-
  primary-journey. Drop noise (single-occurrence transient, known-3rd-party, sub-threshold).
- **Shape** each surviving finding → **defect** (broken → bead, Phase 3a) or **desire/pattern**
  (feature request, recurring friction, needs-design → backlog candidate, Phase 3b). When
  several feedback items express the *same* desire, cluster them into ONE theme.
- **Dedupe before creating** — search BOTH stores: open beads with the same
  fingerprint/signature (for defects) AND open `status: candidate` pool items covering the
  same theme (for desires). Recurrence updates the existing bead/candidate (bump count /
  append evidence), it does NOT create a duplicate.

### Phase 3a — route DEFECTS to beads (hand off to ac-bead-capture)

For each confirmed, deduped **defect**, create a typed bead via the `ac-bead-capture`
conventions (authority: `_shared/bead-conventions.md`):

```
br create -t bug --labels triage,<source>  \
  --title "<crash culprit / error signature> (<freq>× / <users> users)" \
  --description "<source link · first-seen release · suspected wave · top stack frames · repro hints>"
```

- `-t bug` for confirmed defects; `-t investigation` for plausible-but-unconfirmed (e.g. a
  Supabase error spike with no clear cause).
- **Readiness gate (the ac-loop seam):** the loop treats any ready bead WITHOUT the
  `unrefined` label as shippable and hands it straight to `ac-implement` — no
  `ac-bead-refine` pass. So omit `unrefined` ONLY when the bead is refined-by-construction:
  source permalink, first-seen release, suspected wave/commit, stack frames/repro, AND a
  verification path (how the implementer proves the fix). Anything vaguer — no repro,
  unclear cause, cross-cutting blast radius — gets `--labels triage,<source>,unrefined` so
  the loop routes it through `ac-bead-refine` instead of burning an implement slot on a
  cold trail. `-t investigation` beads are ALWAYS `unrefined` — they are questions, not specs.
- Always include the **source permalink** (Sentry issue URL / ASC feedback id) and the
  **suspected wave/commit** so the implementer starts with a lead, not a cold trail.
- Apply the anti-inflation rules: dedupe first, nits stay out, one bead per fingerprint.

### Phase 3b — route THEMES to the backlog pool (feature requests + recurring patterns)

For each confirmed, deduped **desire/pattern**, write a backlog **candidate** directly into
`_backlog/pool/` (headless — no interactive grouping; the human approves it into the pool from
`ac-human-session`'s 🟢 hopper, where grouping/refinement intent is confirmed). This is the
triage→backlog promotion path: real-user *desire* becomes a planning candidate without a human
having to notice and file it.

Filename `_backlog/pool/NNN-<slug>.md` (NNN = max+1 across `pool/` + `active/`):

```markdown
---
status: candidate          # awaiting human approval into the pool (surfaced in ac-human-session 🟢)
type: feature
size: M                    # S | M | L
channel: discovery         # product | discovery | content
horizon: later
source: triage:<source>
source_ids: [<feedback/issue id>, ...]   # loop-guard — never re-promote these records
dependencies: []
---

# <Theme> — <short description>

One-line intent, synthesized from {N} reports.

## Scope
- <the requested capability / the recurring friction — one cohesive theme>

## Evidence
- {N}× since {date} · {source permalink(s)} · representative quote(s)

## Notes
```

- **Loop-guard (same as beads):** record every contributing `source_id`; never re-promote a
  record already mapped to a candidate OR a bead. Recurrence appends evidence to the existing
  candidate — it does not create a second.
- **Cohesion (same as ac-backlog):** one candidate = one coherent theme = one future wave.
  Don't bundle unrelated desires; do cluster many reports of the *same* desire into one.
- A candidate is NOT yet committed work — `ac-align` promotes it `pool → active` only after the
  human approves it (`status: candidate → captured`).

### Phase 4 — report

```
TRIAGE RUN  (<date>)
sources:    sentry ✓ (12 new issues)  ·  asc ✓ (2 feedback)  ·  supabase — (not wired)
clustered:  14 raw → 5 findings (3 defects · 2 themes)
beads:      3 created (bd-xxxx bug, bd-yyyy bug, bd-zzzz investigation), 1 deduped to existing
candidates: 1 created (pool/061-offline-logging.md, from 4 feedback items) — awaiting approval in ac-human-session 🟢
dropped:    9 (sub-threshold / known-3rd-party — listed)
watermarks updated.
```

The report must OUTLIVE the session — headless runs otherwise report to nobody. Write it
to the app's **`.claude/state/triage-last-run.md`** and, when the app has a Slack channel
configured, post it via `slack-send`. A run that found nothing new still writes the report
(proof-of-life beats silence — an empty report and a dead scheduler look identical otherwise).

## Cadence

Designed to run **scheduled + headless** (the VM is the natural host — it's pure API work,
no Mac). A heartbeat/cron invokes it; defect findings land as beads the loop picks up, theme findings land as backlog candidates the human approves in `/ac-human-session`'s 🟢 hopper (human-gate escalations surface there too).
Also runnable on demand ("triage crashes"). The high-leverage automation in the whole
pipeline: it's the only step that manufactures work from *real users* instead of from the
team's own ideas.

## Per-app facts → CORE/triage.md

**Onboarding a new app:** copy `triage.template.md` (this skill dir) → the app's
`.claude/skills/CORE/triage.md` and fill every `{{…}}` (incl. the `template_version` stamp).
Enable whichever sources the app has.

**Keeping it current:** the CORE file is app-owned and never auto-overwritten. `infra-sync`
flags `template_version` drift; reconcile by grafting new template sections in while PRESERVING
filled values, then bump the stamp (see the template's *Maintaining this file* note). Never
edit this symlinked SKILL.md per-app — method changes land HERE and propagate everywhere.

Enabled sources + their org/project/ref ids, secret POINTERS (never the secrets), the
per-app severity bar, the dedupe-fingerprint convention, and any source-specific quirks.

## Remember

- **Fetch + cluster here; classify/route/dedupe via `ac-bead-capture`.** Don't reimplement
  the bead side.
- **Route by shape, not source** — defects → beads (3a); feature/experience themes →
  backlog candidates (3b). The same rule `ac-backlog` uses for human-captured ideas.
- **Dedupe against existing beads AND candidates BEFORE creating** — recurrence updates
  (bump count / append evidence), never duplicates.
- **One bead per fingerprint**, with a source link + suspected wave. No cold trails.
- **Sentry first** — symbolicated stacks beat sparse beta-crash APIs.
- **A source not configured is skipped; a source configured-but-FAILING is an escalation**
  — file/update the ops bead, never silently skip a wired source, never advance its watermark.
- **Respect the ac-loop seam** — no `unrefined` label means the bead ships without any
  refinement pass; only refined-by-construction defects may omit it.
- **Inbound counterpart to `ac-distribute`** — it ships out, this listens back.

---

_The inbound last mile. Real-user signal → clustered findings → beads. The flywheel's
discovery engine._
