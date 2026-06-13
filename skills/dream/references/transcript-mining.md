# Transcript mining — the v2 CYCLE-DAILY how-to

The daily engine: mine **every** transcript, every agent, every day — including
conversations entirely outside the `ac-land` pipeline (plan/review/debug/ad-hoc). This is
the coverage win over v1 (which only saw the curated structured stream). It is an
**evolution of CYCLE, not a rewrite**: the synthesize→judge→emit machinery (Phases 2/4/5)
is reused; two things change — a deterministic pre-flight runs first, and `gather` widens to
raw transcripts + git outcomes. Signal types: `signal-taxonomy.md`. Constitution (taxonomy,
homes, poisoning rule): `../context-engineering/SKILL.md`. Plan: roadmap Phase 2.v2.

## Two stages

### Stage 1 — Pre-flight (deterministic, autonomous, runs BEFORE dreaming)
Mechanical, read-only-or-reversible → safe to run unattended. Two jobs at once: keep the
system healthy AND manufacture fresh outcome-grounded signal about its own operation.
- **Refresh the derived indexes:** `qmd update && qmd embed` · `cass index` (each machine
  rebuilds its own — never sync an index; raw is the source of truth).
- **Health/hygiene checks:** disk · PM2 process health · oomd kills (`journalctl --user |
  grep oomd`) · backup/replication integrity (transcripts converged?) · `gitleaks` scan ·
  the Phase-3 lint sweep · dead-link + staleness scan.
- **A Stage-1 *failure* is a high-priority learning signal** Stage 2 then mines: a stale
  index, an oomd kill, a leaked secret, a sync that didn't converge. Emit it as a finding,
  not just an alert.

### Stage 2 — Mine (review-only — the funnel)
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

## Sources — two axes
- **Intent** (what was attempted + reasoned): `~/.claude/projects/` + `~/.codex/sessions/`
  (the full replica, post v2-a) + agent-mail coordination.
- **Outcome** (what actually resulted): **git** — the grounding layer that validates a
  transcript lesson (transcript: "I'll fix X"; git: did X ship?). **v2.1 sockets** (architect
  `gather` to accept them now, wire later): CI/deploy pass-fail · Sentry/PostHog telemetry ·
  PM2/oomd/disk infra state · beads (a *reopened* bead = a lesson that didn't stick).
- The richest lessons live at the **join** of the two axes.

## Guardrails
- **`gitleaks` gates emit** — proposals (lessons) are the only thing that ever reaches a
  shared git remote; transcripts replicate privately (tailnet-only) and never touch it.
- **Self-reference:** the dream job's own transcript becomes tomorrow's input. Mine its
  **review outcomes** (accept/reject = the acceptance-rate signal), NOT its verbatim
  deliberation — else self-referential noise compounds.
- **Review-only stands** — Stage 2 emits proposals; humans merge (REVIEW mode). Stage 1's
  autonomy covers deterministic hygiene only; anything judgment-laden (skill rewrites,
  context-engineering restructures) is a *proposal*, never an auto-action.

## Trigger + rollout
- Daily `pai-scheduler` job on the VM (watchdog + Discord alerts + heartbeat — never a raw
  PM2 cron; the dead-`qmd-watcher` lesson). Runs Stage 1 → Stage 2 over the converged replica.
- **Replaces the weekly CYCLE once daily coverage is proven.** Sequence discipline: don't
  retire `/reflect` from `ac-land`'s forced flow until the daily cycle demonstrably surfaces
  proposals from non-pipeline conversations.
