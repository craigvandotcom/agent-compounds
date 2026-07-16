# Agent identity & file-reservation lifecycle (shared) — the two-tier contract

**One unique identity per tree-writing session that contends; one explicit shared chore
identity for everything that doesn't.** Ratified 2026-07-14 (epic `ac-ycr`) — this replaces
the earlier mint-or-inherit doctrine (one identity per top-level invocation, inherited by
every spawned stage), which was never wired and is now rejected: see "Why not inherit" below.

## The principle

**Identity is the lock grain, and the grain must match the writer-concurrency boundary.**
A file reservation can only protect between *distinct* identities. So:

- Every session that can **collide with a concurrent writer** needs its **own** name.
- Below the writer boundary (workers that never commit or reserve), identity is pure
  ceremony — mint nothing.
- Coarser than the boundary (one name inherited across concurrent writers), the lock can't
  tell the writers apart and the protection vanishes exactly when it's needed.

## Tier 1 — unique minted identity

**Who:** any session that **claims beads** or **edits product code**:

| Session | Why it's Tier 1 |
|---|---|
| `ac-loop` conductor | claims batches at selection (`--assignee $AGENT_NAME`) — the claim-visibility anchor; holds no file reservations |
| each `ac-implement` child | the canonical contended writer — reserves per bead, commits to `main`; at `PARALLEL_WIDTH>1` several run concurrently in ONE shared checkout |
| `ac-review` | its Phase-4 auto-fix engineer edits product code; Phase 6 commits + pushes (wiring: `ac-ycr.2`) |
| `ac-batch-close` | fix-forward edits code on red CI; minting also yields a real `registration_token` for the build slot (wiring: `ac-ycr.3`) |
| plan-family skills (`ac-plan-init`, `ac-plan-refine-*`, `ac-plan-clean`) | already conform — mint + reserve their plan files |

**Lifecycle:** `macro_start_session` (mint) → `file_reservation_paths` at the **work grain**
(the bead's spec file list; the review's AUTO_FIX list) → release on unit close →
**self-deregister at session exit** (see Deregistration below).

**Never per-edit:** hold reservations for the whole unit of work — releasing between the
edits of one multi-file change opens a window for another invocation to grab a file mid-task
and corrupt both.

## Tier 2 — `FoggyCreek`, the explicit chore identity

The `settings.json` env fallback (`AGENT_NAME=FoggyCreek`, `rule-agent-mail-identity-setup`)
is **deliberate doctrine, not an accident**: the shared identity for **serial,
low-contention chore writers** — scheduled jobs (`ac-tidy`, `ac-align`, `dream` dailies),
`ac-land`'s format-sweep / report / learnings commits.

**The hard rule (= the tier boundary AND the safety guard, wiring: `ac-ycr.6`):**

> **FoggyCreek may commit chore files. FoggyCreek may NEVER claim beads or reserve files.**

A bead claim or reservation appearing under FoggyCreek is always a bug — a conductor that
forgot to re-assert its minted name in a fresh shell. Guards assert `assignee != FoggyCreek`
at claim-at-selection and reject it as an identity in `beads-closed-gate.sh`, converting
silent misattribution into a loud immediate error. Chore commits stay safe without
reservations because the pre-commit guard blocks any commit touching a path reserved by a
*different* identity — protection Tier 2 gets for free, in the direction that matters.

## Why not inherit (recorded so this isn't relitigated)

The old model ("one identity per top-level invocation, inherited by every spawned stage")
was written for a serial world where the conductor serialized all writers. The parallelism
upgrade (`PARALLEL_WIDTH>1`) obsoleted it: parallel `ac-implement` children are genuinely
**independent concurrent writers in one shared checkout** — inherit one loop identity and
the reservation system cannot tell them apart (two concurrent writers under one name, which
even the old doctrine's own corollary forbade). Below the boundary the old model
over-provisioned nothing, but per-worker names would: engineer/reviewer/tester subagents
**never commit and never reserve** (the session conductor is the sole writer, one bead at a
time), so they carry **no identity at all**. Granularity wins exactly down to the writer
boundary and is pure cost below it.

## Assignee vs reservation — the two-identity split (unchanged, load-bearing)

These are different axes; do not conflate them:

- **Bead ASSIGNEE** = claim visibility. A delegated `ac-implement` child claims under
  `CLAIM_ASSIGNEE` — the **loop's** identity, handed in the delegation prompt — so the
  BEADS-CLOSED-GATE sees the whole batch under one name (bd-w504y; the gate also unions
  reported child identities and fails closed on an empty set).
- **File RESERVATION** = write protection. Always under the session's **own** minted name —
  it coordinates the shared checkout per-session.

## Deregistration — three layers (defence in depth)

| Layer | Who | When | Wiring |
|---|---|---|---|
| 1. **Self-deregister** | every Tier-1 minter, for its own name only | at its own session exit (implement Phase Final; review/batch-close ceremony end; the loop conductor last, AFTER `ac-land` returns) | `ac-ycr.4` (ac-implement Phase Final + loop conductor); review/batch-close self-deregister land with their own lifecycle wiring — `ac-ycr.2` / `ac-ycr.3` |
| 2. **Roster sweep** | `ac-land` | at loop exit — the Exit-Land prompt hands it the roster (loop name + every child identity from summaries); land `retire_agent`s stragglers + `force_release_file_reservation` on stale holds | `ac-ycr.5` |
| 3. **Stale sweep + TTL floor** | next run's `ac-loop` Phase 0 | catches runs that died before land; reservation TTL (7200 s) is the absolute floor | `ac-ycr.5` |

Verified against live tool schemas (2026-07-14): `deregister_agent` and `retire_agent` take
`registration_token` as **optional** — layer 2's by-name sweep works without token custody;
`force_release_file_reservation` validates abandonment heuristics before releasing.

## Call-scoped facts (shakedown-verified 2026-07-08)

1. Capture `macro_start_session`'s returned `registration_token` — `file_reservation_paths`,
   `release_file_reservations`, and `send_message` REQUIRE it unless the MCP session already
   authenticated as the agent. Tokens live with the minting session and do not transfer.
2. `export` lives only in the bash call that ran it — every later bash call is a fresh shell
   (where `AGENT_NAME` falls back to FoggyCreek via `settings.json`). Re-assert
   `AGENT_NAME=<minted-name>` in the SAME call as each `git commit`/`git push`, or the
   pre-commit guard treats you as FoggyCreek and blocks against your own reservation.

## Enforcement (two layers over advisory reservations)

- **Edit-time (built, not yet wired):** a global `PreToolUse(Edit|Write)` hook resolves the
  editor's identity via the `CLAUDE_CODE_SESSION_ID → name` marker, reads the local
  reservation store (~0-2 ms, no MCP round-trip), and blocks (exit 2) if the path is held by
  a *different* identity. Fail-open on any error. `~/.local/bin/am-edit-guard.py`
  (`AM_EDIT_GUARD_MODE=advisory|enforce`). The guard filters reservations by the absolute
  `project` field, never the project dir name.
- **Commit-time (live backstop):** the Agent Mail pre-commit guard blocks a commit touching
  another identity's reserved path. Keyed on `AGENT_NAME` in the commit shell.

## Conformance status

**Doctrine ratified 2026-07-14 (epic `ac-ycr`); wiring in flight.** Live today: Tier-1
minting in ac-loop / ac-implement / plan family; CLAIM_ASSIGNEE threading + gate union;
Tier-2 chore commits in scheduled workflows. Pending (blocked on this file's rewrite, now
landed): `ac-ycr.2` (review mint+reserve) · `ac-ycr.3` (batch-close mint) · `ac-ycr.4`
(self-deregister) · `ac-ycr.5` (roster hand-off + sweeps) · `ac-ycr.6` (FoggyCreek guard) ·
`ac-ycr.7` (engineer wip-commit hatch — independent).

**Cross-refs:** artifacts-dir scoping → `run-id.md` · bead lifecycle → `bead-conventions.md` ·
gate mechanics → `scripts/beads-closed-gate.sh` header.
