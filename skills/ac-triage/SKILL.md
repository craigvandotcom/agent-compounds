---
name: ac-triage
description: Use to pull operational signal BACK IN from production — crashes, errors, logs, beta feedback — cluster it, and route real findings to beads. Fetches from Sentry, App Store Connect (TestFlight feedback), Supabase logs, PostHog. The inbound counterpart to ac-distribute. Triggers on "triage crashes", "check sentry", "any new errors", "pull feedback", "what's breaking in prod", "triage production signal", "review crash reports". Headless — runs anywhere, scheduled.
---

> **Generic skill — method only, zero app facts.** Symlinked from agent-compounds and
> shared across consuming apps (incl. web-only ones). App specifics — Sentry org/project
> slug, Supabase project ref, ASC app id, PostHog project, which sources are live, the
> per-app severity bar — live in the consuming app's **`.claude/skills/CORE/triage.md`**.
> Read that FIRST. Secrets (Sentry token, service-role keys) are POINTED TO, never stored.

# ac-triage — the signal-IN lane

**You pull production signal back in and turn the real ones into beads.** This is the
machine-signal sibling to **`ac-bead-capture`** (which intakes *human* signal). It closes
the Discovery→beads flywheel: real-user breakage becomes tracked work without a human
having to notice and report it.

**Scope boundary:** ac-triage FETCHES + clusters external machine signal and routes each
confirmed finding to **`ac-bead-capture`** (which owns classification, repo-routing, and
dedupe). It does NOT ship builds (that's `ac-distribute`) and does NOT itself reimplement
the bead-side conventions — it hands off. Headless, source-agnostic, cross-app; only the
*sources* are app-specific.

## Sources (pluggable adapters — enable per app in CORE/triage.md)

| #   | Source                  | Signal                                          | Auth (pointer)             |
| --- | ----------------------- | ----------------------------------------------- | -------------------------- |
| 1   | **Sentry**              | symbolicated crashes + JS/native errors, freq.  | `SENTRY_AUTH_TOKEN` + org/proj |
| 2   | **App Store Connect**   | TestFlight beta feedback (notes + screenshots), crash submissions | ASC API key (`.p8`) |
| 3   | **Supabase**            | edge-function logs, Postgres errors, auth failures | service-role / mgmt API |
| 4   | PostHog (later)         | funnel drop-off, error events, session signal    | project API key            |

**Sentry is source #1** — symbolicated native + JS stacks are the highest-signal, lowest-
noise input, and (unlike ASC's sparse beta-crash API) it captures crashes whether or not a
tester taps "report." ASC #2 adds the human texture (tester notes/screenshots Sentry can't
see). Light up sources as they're wired; a source that isn't configured is skipped, not an
error.

## Method (per run)

### Phase 0 — scope + watermark

Read `CORE/triage.md` for enabled sources + per-app severity bar. Load the **last-run
watermark per source** (timestamp / last issue id / cursor) so each run only pulls NEW
signal. First run: bounded lookback (e.g. last 7 days) to avoid a flood.

### Phase 1 — fetch (per enabled source, in parallel)

Pull signal since the watermark via each source's API (pointer-auth from CORE):

- **Sentry:** issues sorted by `lastSeen`, with `count`, `userCount`, culprit, latest
  event stack, release. Prefer unresolved + regression issues.
- **ASC:** `betaFeedbackCrashSubmissions` + `betaFeedbackScreenshotSubmissions` for the app,
  newest builds first.
- **Supabase:** error-level logs / failed-request rows since watermark.

Record the new watermark per source AFTER a successful fetch.

### Phase 2 — cluster + dedupe (your core work — do NOT delegate)

- **Cluster** raw events into issues by fingerprint (Sentry already does this; do it for
  ASC/Supabase by error signature + location). N crash events of one bug = ONE finding.
- **Cross-reference** each cluster against recent waves/commits (`git log` since the
  finding's first-seen release) — a crash that appeared right after wave X is a strong lead.
- **Severity** per the app's bar: frequency × user-count × crash-vs-error × is-it-on-a-
  primary-journey. Drop noise (single-occurrence transient, known-3rd-party, sub-threshold).
- **Dedupe against existing beads** BEFORE creating: search the repo's db for an open bead
  with the same fingerprint/signature. Recurrence updates the existing bead (bump a
  count/comment), it does NOT create a duplicate.

### Phase 3 — route to beads (hand off to ac-bead-capture)

For each confirmed, deduped finding, create a typed bead via the `ac-bead-capture`
conventions (authority: `_shared/bead-conventions.md`):

```
br create -t bug --labels triage,<source>  \
  --title "<crash culprit / error signature> (<freq>× / <users> users)" \
  --description "<source link · first-seen release · suspected wave · top stack frames · repro hints>"
```

- `-t bug` for confirmed defects; `-t investigation` for plausible-but-unconfirmed (e.g. a
  Supabase error spike with no clear cause).
- Always include the **source permalink** (Sentry issue URL / ASC feedback id) and the
  **suspected wave/commit** so the implementer starts with a lead, not a cold trail.
- Apply the anti-inflation rules: dedupe first, nits stay out, one bead per fingerprint.

### Phase 4 — report

```
TRIAGE RUN  (<date>)
sources:   sentry ✓ (12 new issues)  ·  asc ✓ (2 feedback)  ·  supabase — (not wired)
clustered: 14 raw → 5 findings
beads:     3 created (bd-xxxx bug, bd-yyyy bug, bd-zzzz investigation), 2 deduped to existing
dropped:   9 (sub-threshold / known-3rd-party — listed)
watermarks updated.
```

## Cadence

Designed to run **scheduled + headless** (the VM is the natural host — it's pure API work,
no Mac). A heartbeat/cron invokes it; findings land as beads the next `ac-next` surfaces.
Also runnable on demand ("triage crashes"). The high-leverage automation in the whole
pipeline: it's the only step that manufactures work from *real users* instead of from the
team's own ideas.

## Per-app facts → CORE/triage.md

Enabled sources + their org/project/ref ids, secret POINTERS (never the secrets), the
per-app severity bar, the dedupe-fingerprint convention, and any source-specific quirks.

## Remember

- **Fetch + cluster here; classify/route/dedupe via `ac-bead-capture`.** Don't reimplement
  the bead side.
- **Dedupe against existing beads BEFORE creating** — recurrence updates, never duplicates.
- **One bead per fingerprint**, with a source link + suspected wave. No cold trails.
- **Sentry first** — symbolicated stacks beat sparse beta-crash APIs.
- **A source not configured is skipped, not an error** — light them up as they're wired.
- **Inbound counterpart to `ac-distribute`** — it ships out, this listens back.

---

_The inbound last mile. Real-user signal → clustered findings → beads. The flywheel's
discovery engine._
