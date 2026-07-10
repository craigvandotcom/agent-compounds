# Transcript mining — the v2 CYCLE-DAILY how-to

The daily engine: mine **every** transcript, every agent, every day — including
conversations entirely outside the `ac-land` pipeline (plan/review/debug/ad-hoc). This is
the coverage win over v1 (which only saw the curated structured stream). It is an
**evolution of CYCLE, not a rewrite**: the synthesize→judge→emit machinery (Phases 2/4/5)
is reused; two things change — a cheap **precondition check** runs first (maintenance lives in
the separate `infra-maintain` job, not here), and `gather` widens to raw transcripts + git
outcomes. Signal types: `signal-taxonomy.md`. Constitution (taxonomy, homes, poisoning rule):
`../context-engineering/SKILL.md`. Plan: roadmap Phase 2.v2.

## Separation of concerns: hygiene cleans, dream remembers

dream does **not** do infra maintenance. Cleaning (caches, tmp, stale headless browsers/dev
servers, log rotation), index refresh (`qmd`/`cass`), and health checks belong to the
separate **`infra-maintain`** job. The sleep analogy is the *architecture*, not a reason to
merge: biological sleep runs two distinct processes — glymphatic *clearance* and memory
*consolidation* — in one orchestrated window, in sequence, where cleaning enables and feeds
remembering. So: **separate jobs, one nightly window, sequenced** (scheduler runs
`infra-maintain` → `dream`); the cleaning's output *feeds* the dreaming, it doesn't become it.

`infra-maintain` emits a structured **health report** (the seam between the two processes).
dream **consumes** it as an outcome-signal source; dream never performs the maintenance.

### Precondition (verify, don't clean)
Before mining, confirm inputs are usable — indexes fresh within the window (`qmd status`,
`cass status`), the night's health report present, replication converged. **On failure, do
NOT fix** — record it as a finding (a stale index / oomd kill / leaked secret / non-converged
sync is itself high-priority mineable signal) and proceed with what's available.

### Mine (review-only — the funnel)
Never feed whole transcripts to the LLM. Funnel, cheapest stage first:
1. **Segment** — only the window since the last run (`last-run.json` timestamp).
2. **Cheap pre-filter** — grep candidate segments by marker: tool-error strings,
   user-negations ("no/actually/don't"), outcome anchors (test-pass, commit, deploy). Only
   these reach the LLM — this is what makes daily-over-everything affordable AND sharp.
3. **Redaction filter** — scrub secrets from the candidate segments *into the LLM's input*
   (derived view). The canonical raw is never mutated (it's live harness state; lossy;
   copies uncatchable — encrypt at rest instead, and rotate any real secret that lands in a
   transcript rather than chasing copies).
4. **LLM-extract** — apply the signal taxonomy to the candidate segments.
5. **Dedup** — CASS retrieval against the existing substrate; drop anything already known.
6. **Judge (Phase 4) → Emit (Phase 5)** — unchanged from v1; `gitleaks` gates emit.

## Validated tuning (dry-run 2026-06-14, ASA session f81dde6c — 26 MB/10,291 lines)
The funnel narrowed to 50 human turns + 57 errors → 1 strong new lesson; dedup correctly
suppressed 3 known ones. Findings that must be built in:
1. **Dedup MUST use hardened retrieval, not naive `qmd search`.** Raw search false-negatived
   on existing facts (FTS hyphen/common-term quirks + no memory-path filter) → would re-propose
   known lessons. **Reuse the canonical memory-recall hook's per-term, alnum-tokenized,
   memory-filtered dedup/matching logic** (one unified hook now implements this — currently
   `memory-retrieval.py`, the `repos-6u6` CLI). This is how `repos-6u6` feeds v2 — via shared
   search logic, not hooks.
2. **Tighten the negation pre-filter** — bare `no` matches "now/note/no problem" (huge noise).
   Require user-role + strong phrases ("no,", "actually", "don't", "that's wrong", "instead of").
3. **Filter harness artifacts** from the human-directive lane: `[Request interrupted…]`,
   `**You are…`(command templates), `Base directory for this skill`, `[Image:`, continuation
   summaries, `A session-scoped Stop hook…`, `Goal set:`, `# Autonomous loop check`. (Extends
   the hook's existing skip of `/`- and `<`-prefixed prompts.)
4. **Hook-injected content is dual-natured** — `Stop hook feedback` lines are noise as
   "directives" but ARE a friction signal (the thrashing lesson came from them). Categorize, don't drop.
5. **Subagent transcripts** (`subagents/agent-*.jsonl`) belong to a parent session — mine as a
   unit to avoid double-counting.

## Sources — two axes
- **Intent** (what was attempted + reasoned): `~/.claude/projects/` + `~/.codex/sessions/`
  (the full replica, post v2-a) + agent-mail coordination.
- **Outcome** (what actually resulted): **git** — the grounding layer that validates a
  transcript lesson (transcript: "I'll fix X"; git: did X ship?) · **the `infra-maintain`
  health report** (oomd kills, disk-pressure events, leaked-secret hits, non-converged sync —
  the night's operational truth). **v2.1 sockets** (architect `gather` to accept them now,
  wire later): CI/deploy pass-fail · Sentry/PostHog telemetry · beads (a *reopened* bead = a
  lesson that didn't stick).
- The richest lessons live at the **join** of the two axes.

## Guardrails
- **`gitleaks` gates emit** — proposals (lessons) are the only thing that ever reaches a
  shared git remote; transcripts replicate privately (tailnet-only) and never touch it.
- **Self-reference:** the dream job's own transcript becomes tomorrow's input. Mine its
  **review outcomes** (accept/reject = the acceptance-rate signal), NOT its verbatim
  deliberation — else self-referential noise compounds.
- **Review-only stands** — dream emits proposals; humans merge (REVIEW mode). Autonomy is
  split by concern: `infra-maintain` autonomously does deterministic hygiene; dream's mining
  is propose-only — anything judgment-laden (skill rewrites, context-engineering restructures)
  is a *proposal*, never an auto-action.

## Trigger + rollout
- Daily `pai-scheduler` job on the VM (watchdog + Discord alerts + heartbeat — never a raw
  PM2 cron; the dead-`qmd-watcher` lesson), scheduled *after* the `infra-maintain` job so the
  health report + fresh indexes are ready. Runs the precondition check → mining funnel over
  the converged replica.
- **Replaces the weekly CYCLE once daily coverage is proven.** Sequence discipline: don't
  retire `/reflect` from `ac-land`'s forced flow until the daily cycle demonstrably surfaces
  proposals from non-pipeline conversations.
