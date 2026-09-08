---
name: dream
description: Run the dream session — the org's deliberate self-improvement review, human-run and unscheduled. Use when asked to "run the dream cycle", "dream", "synthesize the week's lessons", "lint the memory substrate", "review dream proposals", "review the dream docket", or "what did the dream cycle find"; also when a docket-review bead is open. The session reads the ranked docket (infrastructure/dream-cycle/proposals/DOCKET.md), rules each item with the human, and emits approved work as task beads; the mechanical sweep keeps the docket fresh. NOT for capturing one session's lessons (that is reflect) or saving a single item (that is context-engineering routing).
---

# dream — human judgment over the ranked docket

**Purpose:** the compounding engine (Primitive #4), now run as a deliberate human
session. Not scheduled.
**Constitution:** `../context-engineering/SKILL.md` (load it first — taxonomy, homes,
hygiene rules all come from there).
**Docket (input):** `infrastructure/dream-cycle/proposals/DOCKET.md` — maintained by
the mechanical sweep (`infrastructure/dream-cycle/docket-sweep.py`), never by the
session.
**Status:** MANUAL (Craig ruling 2026-09-08). No scheduled dream. The only automated
artifacts are the docket (mechanical sweep) and one idempotent docket-review bead.

---

## What dream is now

A deliberate, human-run session with the agent present. Not scheduled, not headless.
The docket is the input; the session is judgment, mining, and ruling. Craig reads the
ranked docket, rules each item, and the agent captures the decisions — and mines what
the sweep only flagged.

Nothing in dream runs unattended. No cron invokes it. The scheduled weekly CYCLE and
the daily review-queue job are gone — the jobs in `infrastructure/jobs/weekly.json`
sit disabled (see The polish gate). A session starts because a human starts it.

## The automated leg — the sweep (findings only)

The mechanical sweep (`infrastructure/dream-cycle/docket-sweep.py`) does four things,
and nothing else:

1. **Verifies premises live** — every pending proposal memo and open dream bead gets
   a verdict against HEAD: `LIVE` / `ANSWERED` / `UNJUDGED` / `STALE-EVIDENCE`.
2. **Ranks the survivors** — frictions, memory-hygiene, wiki, and pending-proposal
   opportunities — into `infrastructure/dream-cycle/proposals/DOCKET.md`, weighted by
   judge score × recurrence × staleness.
3. **Mints the single docket-review bead** if none is open (idempotent — the session's
   handle on the board).
4. **Never decides anything.** Findings only.

The sweep also closes answered-at-birth items, citing the deciding artifact. It never
rules on what remains. Judgment is the session's, not the sweep's.

## Session workflow — three phases

### Phase 1 — GATHER

Read `infrastructure/dream-cycle/proposals/DOCKET.md` — the ranked survivors and the
flagged items that re-entered. Scan fresh ledgers since the last session — friction
logs, memory homes, wiki, pending proposals — so nothing the sweep's last pass predates
is missed. The docket is the input; the fresh scan is the completeness check.

### Phase 2 — JUDGE (with Craig)

Rule each ranked item with Craig. Mine the consolidations and wiki refinements the
sweep flagged. Capture every ruling in **EXACT phrasing — never paraphrase**: the words
are the decision, and a paraphrase is a new decision nobody ruled on.

### Phase 3 — EMIT

- **Approved** items become task beads born refined at apply time — implementation-ready
  because the human ruled in-session. Every bead carries the born-verified contract
  below.
- **Rejected** items are memo-marked so they do not re-enter the docket as live.
- The session ends with a **gap analysis** — what the substrate still doesn't know.
  The next session's GATHER starts there.

## The gates stay (the born-verified contract)

Every task bead born in EMIT carries:

- `evidence:` / `consequence:` / `recommendation:`
- a `Probe:` line a gate can run
- `origin:dream`

Unverified premises do not file. A premise that no longer holds at HEAD is not
emitted — it stays on the docket for the sweep's next pass. (Bead conventions:
`../beads-standards/reference/bead-conventions.md`.)

## The polish gate

Automation does not scale back up — crons, filing, auto-tier — until the manual loop
has run enough sessions to trust its output. The disabled jobs in
`infrastructure/jobs/weekly.json` are the marker: while they sit disabled, dream stays
a human session.

## Common mistakes

| Mistake | Fix |
|---|---|
| Running dream unattended | Never — a session is a human sitting with the agent |
| Paraphrasing a ruling | Capture in the exact phrasing — a paraphrase is a new ruling |
| Emitting a task bead without its probe | The probe is the born-verified contract; a probe-less bead is not implement-ready |
| Filing an item whose premise already died | Verify at HEAD before emit — unverified premises do not file |
| Letting the sweep decide | The sweep ranks and mints the bead; it never rules. Judgment is the session's |