# ac-triage — the method (per-run procedure)

The spine (`SKILL.md`) owns the shape-routing doctrine; this file is the run procedure.
The headless heartbeat runs it through `workflows/scheduled-daily.md`.

## Create Workflow Tasks (run ledger)

**One task per phase below — headless runs still keep the ledger (proof-of-life for the
run itself, not just its report).** Create these upfront; `TaskUpdate` each to
`in_progress` when its phase starts and `completed` when it ends.

Ledger contract: `ac-pipeline/references/run-ledger.md` — one task per section, advance as you go; ledger = run position, never work items.

```
TaskCreate("Scope + watermark — read CORE/triage.md, load per-source watermarks")

If TaskCreate is unavailable (subagent / fan-out path), track the ledger inline in progress.md; this is a sanctioned equivalent, not a deviation.
TaskCreate("Fetch — pull new signal from enabled sources in parallel")
TaskCreate("Cluster + dedupe — fingerprint raw events into findings")
TaskCreate("Route defects → beads")
TaskCreate("Route themes → backlog pool")
TaskCreate("Group + file — defects filed unrefined for ac-polish")
TaskCreate("Report — write + Slack the run summary")
```

## Phase 0 — scope + watermark

**TaskUpdate("Scope + watermark", in_progress)**

Read `CORE/triage.md` for enabled sources + per-app severity bar. Load the **last-run
watermark per source** (timestamp / last issue id / cursor) from the app's
**`.claude/state/triage-watermarks.json`** (committed, one key per source:
`{"sentry": {"watermark": "<ISO ts / cursor>", "updated": "<ISO ts>"}, …}`) so each run
only pulls NEW signal. Missing file or missing key = first run for that source: bounded
lookback (e.g. last 7 days) to avoid a flood, then write the entry.

**TaskUpdate("Scope + watermark", completed)**

## Phase 1 — fetch (per enabled source, in parallel)

**TaskUpdate("Fetch", in_progress)**

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
(`br create -t task --labels origin:ac-triage,unrefined,triage,ops,impact:<class>`) so it surfaces in `ac-human`.
Add `human-gate` ONLY if the body states `Gate-reason: authorization —`.
Dedupe first, update the existing open ops bead if one already tracks this failure.
Silent-skip is reserved for sources that were never wired.

**TaskUpdate("Fetch", completed)**

## Phase 2 — cluster + dedupe (your core work — do NOT delegate)

**TaskUpdate("Cluster + dedupe", in_progress)**

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

**TaskUpdate("Cluster + dedupe", completed)**
**TaskUpdate("Route defects → beads", in_progress)**

## Phase 3a — route DEFECTS to beads

For each confirmed, deduped **defect**, create a typed bead directly via `br create`, per
`beads-standards/reference/bead-conventions.md` (the authority for bead shape; raw `br create`
is the deliberate pattern here — `ac-bead-capture` is the human quick-capture skill).

```
br create -t bug --labels origin:ac-triage,triage,<source>,prod-finding,unrefined,impact:<class>  \
  --title "<crash culprit / error signature> (<freq>× / <users> users)" \
  --description "<source link · first-seen release · suspected wave · top stack frames
                 ## Steps to Reproduce (repro hints / crash path)
                 ## Acceptance Criteria (crash signature gone in next release's source)
                 - Probe: `<command>` — tier: <slug>   (REQUIRED at creation — no probe → -t investigation)
                 ## Test Scope (real test file/describe anchors — grep them first)>"
# body headers per beads-standards/reference/bead-conventions.md §Body template — emit at creation
```

- **Catch-stage at filing, per source.** Every triage source is external real-user signal,
  so the template's `prod-finding` token covers all of them — Sentry and beta/store
  feedback alike (a token from beads-standards' CLOSED set; never a new one).
- `-t bug` for confirmed defects; `-t investigation` for plausible-but-unconfirmed (e.g. a
  Supabase error spike with no clear cause).
- **Readiness gate (the loop seam):** every finding ships `unrefined`, however strong the
  evidence; `refined` is applied EXCLUSIVELY by `/ac-polish` on convergence.
  `-t investigation` beads are ALWAYS
  `unrefined` — they are questions, not specs. The Phase-3a bar (permalink, first-seen
  release, suspected wave/commit, stack frames/repro, verification path) is not a stamping
  decision: it is how completely to evidence the bead now, so refinement converges in one
  pass instead of needing investigative rounds.
- **`## Test Scope` at creation, with grep-verified anchors** (same bar as `ac-hygiene`):
  name the real file(s)/describe block(s) a validator would run — grep each before citing it,
  never invent a describe you have not seen — plus the QA modality for user-facing surfaces
  (`browser:`/`device:` + journey). A finding with no test plan is a test the implementer authors cold.
- **ac-lane findings carry a `catch-stage` label and a `discovered-from` edge.** File the
  escape as `catch-stage:<stage>` — the stage that SHOULD have caught it (plan · beadify ·
  flight · implement · close · review) — plus `discovered-from: <bead>` naming the work that
  shipped it. Without both it is a bug report; with them it is evidence about which gate leaks.
- **Product findings to the board; process observations to the ac2 family ledger.** The same
  signal yields both, and conflating them is how a board fills with beads about ourselves
  (measured 39%). A defect in the shipped thing → a bead, here. An observation about how the
  pipeline itself behaved → `FRICTIONS.md`, never a bead, never both.
- **Escapes feed the batch telemetry rollup.** Report every ac-lane finding at the next batch
  boundary with its catch-stage: EXTERNAL escapes, not the findings our own review caught, are
  the metric the lean-pipeline thesis is judged on. A rollup carrying only internally-caught
  findings is a self-graded exam.
- Always include the **source permalink** (Sentry issue URL / ASC feedback id) and the
  **suspected wave/commit** so the implementer starts with a lead, not a cold trail.
- Apply the anti-inflation rules: dedupe first, nits stay out, one bead per fingerprint.

**TaskUpdate("Route defects → beads", completed)**
**TaskUpdate("Route themes → backlog pool", in_progress)**

## Phase 3b — route THEMES to the backlog pool (feature requests + recurring patterns)

For each confirmed, deduped **desire/pattern**, write a backlog **candidate** directly into
`_backlog/pool/` (headless — no interactive grouping; the human approves it into the pool from
`ac-human`'s 🟢 hopper, where grouping/refinement intent is confirmed). This is the
triage→backlog promotion path: real-user *desire* becomes a planning candidate without a human
having to notice and file it.

Filename `_backlog/pool/NNN-<slug>.md` (NNN = max+1 across `pool/` + `active/`):

```markdown
---
status: candidate          # awaiting human approval into the pool (surfaced in ac-human 🟢)
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

**TaskUpdate("Route themes → backlog pool", completed)**
**TaskUpdate("Group + refine", in_progress)**

## Phase 3c — group + file (before the report)

**Per-run epic:** if this run created 2+ finding-beads (Phase 3a), group them under one
epic (`br create -t epic "Triage <date> — findings" -l origin:ac-triage,impact:<class>`, children linked via parent-child
deps) so the batch ships to refinement and the loop as one cohesive
unit. 0–1 beads → no epic (don't inflate). Backlog candidates (Phase 3b) aren't beads —
they don't count toward this threshold and aren't epic children.

Beads ship `unrefined` — there is no in-session refine step. Refinement happens through
`ac-polish` (bead mode), the only sanctioned path to the `refined` label via
`skills/_tools/stamp-refined.sh`; triage never stamps `refined` itself.

**TaskUpdate("Group + file", completed)**
**TaskUpdate("Report", in_progress)**

## Phase 4 — report

```
TRIAGE RUN  (<date>)
sources:    sentry ✓ (12 new issues)  ·  asc ✓ (2 feedback)  ·  supabase — (not wired)
clustered:  14 raw → 5 findings (3 defects · 2 themes)
beads:      3 created (bd-xxxx bug, bd-yyyy bug, bd-zzzz investigation), 1 deduped to existing
candidates: 1 created (pool/061-offline-logging.md, from 4 feedback items) — awaiting approval in ac-human 🟢
dropped:    9 (sub-threshold / known-3rd-party — listed)
watermarks updated.
```

The report must OUTLIVE the session — headless runs otherwise report to nobody. Write it
to the app's **`.claude/state/triage-last-run.md`** and, when the app has a Slack channel
configured, post it via `slack-send`. A run that found nothing new still writes the report
(proof-of-life beats silence — an empty report and a dead scheduler look identical otherwise).

**TaskUpdate("Report", completed)**