# Agent identity & file-reservation lifecycle (shared) — the two-tier contract

**One unique identity per tree-writing session that contends; one explicit shared chore
identity for everything that doesn't** (epic `ac-ycr`). This replaces
the earlier mint-or-inherit doctrine (one identity per top-level invocation, inherited by
every spawned stage), which was never wired and is now rejected: see "Why not inherit" below.

## ToC
- The principle
- Tier 1 — unique minted identity
- Tier 2 — FoggyCreek, the explicit chore identity
- Why not inherit
- Assignee vs reservation — the two-identity split (unchanged, load-bearing)
- Deregistration — three layers (defence in depth)
- Call-scoped facts (`ac-g93`) — note 1 binds only sessions that HOLD the tools, note 2 binds everyone that commits, stance children included
- Enforcement (two layers over advisory reservations)
- Project key format (canonical — the one home for the key-format rule)
- Conformance status

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
| `ac-implement` child running as its **own full session** (holds the `mcp__mcp-agent-mail__*` tools) | the canonical contended writer — **mints its own name and reserves per bead**, commits to `main`; at `PARALLEL_WIDTH>1` several run concurrently in ONE shared checkout |
| `ac-implement` child **spawned as a stance subagent** (researcher / implementer / validator) | **still a contended writer — it COMMITS — but it CANNOT reserve anything.** The stance agents carry zero `mcp__*` tools (`agents/*.md` `tools:` lists; reproduced in bd-2p5tl), so `macro_start_session` / `file_reservation_paths` are unavailable to it. It is **handed** an `AGENT_NAME` by its conductor (re-exported in each commit's own shell — note 2 below) purely for attribution + the pre-commit guard; **the CONDUCTOR holds the reservations on its behalf.** This is the spawn mode the pipeline uses most |
| `ac-review` | its Phase-4 auto-fix engineer edits product code; Phase 6 commits + pushes (wiring: `ac-ycr.2`) |
| `ac-batch-close` | fix-forward edits code on red CI; minting also yields a real `registration_token` for the build slot (wiring: `ac-ycr.3`) |
| plan-family skills (`ac-plan-init`, `ac-plan-refine-*`, `ac-plan-clean`) | already conform — mint + reserve their plan files |

**Lifecycle (token-holding sessions only — a stance child has no `macro_start_session` to
call):** `macro_start_session` (mint) → `file_reservation_paths` at the **work grain**
(the bead's spec file list; the review's AUTO_FIX list) → release on unit close →
**self-deregister at session exit** (see Deregistration below).

**Never per-edit:** hold reservations for the whole unit of work — releasing between the
edits of one multi-file change opens a window for another invocation to grab a file mid-task
and corrupt both.

> **When the writers CANNOT reserve, parallel safety comes from DISJOINT SCOPE — so partition
> before you fan out.** A reservation protects only between distinct identities that can actually
> take one, so a fan-out of stance children has **no lock grain at all**: the conductor must
> partition the **file sets (or one repo per child) BEFORE dispatch**, and that partition *is* the
> entire safety argument. Measured: four implementer children at width
> 2 across two repos, conductor holding every reservation centrally, scope partitioned by repo —
> **zero collisions, but the safety came from the disjointness, not from the reservations.** The
> enforcement mechanism is `ac-loop` § Efficiency § Parallelism's pre-dispatch width-N check
> (bd-3sh8k): **both** *tree-disjointness* (no shared expected file set) **and**
> *resource-disjointness* (no shared build dir, serve port, Supabase stack, ledger). Overlap →
> serialize.

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

## Why not inherit

The old model ("one identity per top-level invocation, inherited by every spawned stage")
was written for a serial world where the conductor serialized all writers. The parallelism
upgrade (`PARALLEL_WIDTH>1`) obsoleted it: parallel `ac-implement` children are genuinely
**independent concurrent writers in one shared checkout** — inherit one loop identity and
the reservation system cannot tell them apart (two concurrent writers under one name, which
even the old doctrine's own corollary forbade). Below the boundary the old model
over-provisioned nothing, but per-worker names would: engineer/reviewer/tester subagents
**never commit and never reserve** (the session conductor is the sole writer, one bead at a
time), so they carry **no identity at all** — with ONE exception the old model never anticipated,
now the Tier-1 stance-subagent row: a stance child that **does** commit needs a *handed* name for
attribution, and takes its write protection from scope partitioning instead of a lock.
Granularity wins exactly down to the writer boundary and is pure cost below it.

## Assignee vs reservation — the two-identity split (unchanged, load-bearing)

These are different axes; do not conflate them:

- **Bead ASSIGNEE** = claim visibility. A delegated `ac-implement` child claims under
  `CLAIM_ASSIGNEE` — the **loop's** identity, handed in the delegation prompt — so the
  BEADS-CLOSED-GATE sees the whole batch under one name (bd-w504y; the gate also unions
  reported child identities and fails closed on an empty set).
- **File RESERVATION** = write protection. Always under the **minting** session's own name — it
  coordinates the shared checkout per-session. A stance child has no minted name and cannot
  reserve at all: its conductor's reservation stands in, and disjoint scope does the rest
  (the Tier-1 stance-subagent row).

## Deregistration — three layers (defence in depth)

| Layer | Who | When | Wiring |
|---|---|---|---|
| 1. **Self-deregister** | every Tier-1 minter, for its own name only | at its own session exit (implement Phase Final; review/batch-close ceremony end; the loop conductor last, AFTER `ac-land` returns) | `ac-ycr.4` (ac-implement Phase Final + loop conductor); review/batch-close self-deregister land with their own lifecycle wiring — `ac-ycr.2` / `ac-ycr.3` |
| 2. **Roster sweep — reservations only** | `ac-land` | at loop exit — the Exit-Land prompt hands it the roster (loop name + every child identity that actually **minted** — never a handed stance-child name, § below); land runs `force_release_file_reservation` on the roster's stale holds — **but resolve the roster per § The sweep is NOT project-key-agnostic, never a per-name loop on one assumed key**. Identities are **not** retired here — see below | `ac-ycr.5` |
| 3. **Stale sweep + TTL floor** | next run's `ac-loop` Phase 0 | catches runs that died before land — stale-**reservation** sweep only, same project-key-agnostic query as layer 2; reservation TTL (7200 s) is the absolute floor. There is **no identity TTL** | `ac-ycr.5` |

Runtime-verified (`ac-ycr.8`): `retire_agent`/`deregister_agent` mark
`registration_token` optional in the *schema* but **reject name-only calls at runtime** unless
the MCP session already authenticated as that agent — tokens live with the minting session
(call-scoped fact #1 below), so cross-session identity retirement is impossible by design.
Identity cleanup is therefore **layer 1 (self-deregister) only**; a crashed session's identity
persists (harmless roster noise — retired/active listing only, no write authority) until the
upstream admin-sweep primitive requested of mcp-agent-mail lands. Reservations — the
safety-critical half — DO sweep cross-session: `force_release_file_reservation` releases
another agent's hold by name after validating abandonment heuristics.

### The sweep is NOT project-key-agnostic — query the store, don't loop per name

**One checkout mints SEVERAL project keys.** A 12-identity run on one `body-compass-app`
checkout registered across three: `neometa/body-compass-app` (7), the **absolute path** (4),
and bare `body-compass-app` (1) — re-verified live below. So a per-name
`force_release_file_reservation` loop keyed on the "obvious" key resolves 4 of 12; the other 8
return `Agent '<name>' not found in project '<key>'`, and a loop that tolerates that error
reports a **clean roster having never looked at two thirds of it** — a false clean, the worst
shape for a teardown check. Ask the global question instead; then addressability cannot hide
anything:

> **A handed stance-child name is NOT a roster entry** (corollary of the Tier-1 stance-subagent
> row): it never registered and holds no reservations, so it resolves in **zero** projects by
> construction — put it on the roster and the loud failure below fires every run, which is how an
> operator learns to ignore a real one. The roster is the set of names that **minted**; the
> conductor's own reservations already cover its children's files.

```bash
AM_DB="file:$HOME/mcp_agent_mail/storage.sqlite3?mode=ro"   # read-only; never write this store

# 1. THE SAFETY QUESTION — every project at once, no project_key, no per-name loop.
sqlite3 "$AM_DB" "SELECT p.human_key, a.name, r.path_pattern, r.expires_ts
  FROM file_reservations r JOIN agents a ON a.id=r.agent_id JOIN projects p ON p.id=r.project_id
 WHERE r.released_ts IS NULL AND r.expires_ts > datetime('now');"   # empty output = clean

# 2. Roster resolution — a name resolving NOWHERE is a LOUD failure, never a skipped iteration.
#    `while read`, NOT `for n in $ROSTER`: unquoted expansion doesn't word-split in zsh, so that
#    loop would run ONCE with the whole roster as one name and "pass".
while IFS= read -r n; do
  [ -n "$n" ] || continue
  keys=$(sqlite3 "$AM_DB" "SELECT p.human_key FROM agents a JOIN projects p ON p.id=a.project_id
                            WHERE a.name='$n';" | paste -sd'|' -)
  [ -n "$keys" ] && echo "ok $n -> $keys" \
    || echo "SWEEP FAILURE: '$n' resolves in ZERO projects — the sweep did NOT look at it" >&2
done < "$ROSTER_FILE"   # one name per line
```

Verified under `bash` and `zsh`: reproduced the three-key fragmentation above, and
a bogus name produced the loud failure rather than a silent skip. **Root cause is upstream** —
`mcp_agent_mail` derives `project_key` from a path at several call sites, so differing child
launch contexts fork keys for one repo. That is a third-party repo (`Dicklesworthstone/
mcp_agent_mail`); it needs an upstream issue, and this sweep method is the whole of the local fix.

## Call-scoped facts (`ac-g93`) — note 1 binds only sessions that HOLD the tools, note 2 binds **everyone that commits**, stance children included

1. **Capture `macro_start_session`'s returned `registration_token` and thread it EXPLICITLY on
   EVERY privileged / mutating Agent Mail call.** The token-requiring set is NOT the old three
   tools — it is the blanket rule: `file_reservation_paths`, `release_file_reservations`,
   `renew_file_reservations`, `force_release_file_reservation`, `acquire_build_slot` /
   `release_build_slot` / `renew_build_slot`, `send_message` / `reply_message` (as `sender_token`),
   `deregister_agent`, `retire_agent`, `hard_delete_agent`. **Do NOT rely on same-session auth
   carry.** Validation (`ac-g93` — read `~/mcp_agent_mail` `app.py`): same-session
   token-free auth is a REAL, intended mechanism (`register_agent` / `macro_start_session` bind the
   MCP session via `_bind_session_agent`; `_authenticate_agent` then honors the binding), but it is
   **conditional** — the binding is keyed on a stable `ctx.session_id`, and (a) a separate phase
   child is a separate MCP session that never inherits the conductor's binding, and (b) a transport
   that doesn't surface a stable session id falls to a per-call orphan UUID that makes the binding
   invisible. So the carry is *intended-but-conditional*, NOT a guarantee to depend on (verdict: not
   a clean server bug — no upstream bead; our docs were over-claiming). Threading the token is the
   only reliable path; tokens live with the minting session and do not transfer. The narrow
   "these three tools only, unless already authenticated" model is **retired**.
2. `export` lives only in the bash call that ran it — every later bash call is a fresh shell
   (where `AGENT_NAME` falls back to FoggyCreek via `settings.json`). Re-assert
   `AGENT_NAME=<your minted-OR-handed name>` in the SAME call as each `git commit`/`git push`, or the
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

## Project key format (canonical — the one home for the key-format rule)

**Rule: always pass the app's canonical two-segment key `neometa/<app-dir>` (e.g.
`neometa/body-compass-app`, `neometa/agent-compounds`) — READ the pinned `human_key`
from the app's `.claude/hooks/session-start.md`. NEVER derive it from cwd, the repo
root, or `git rev-parse --show-toplevel`, and never an absolute path or ad-hoc slug.**
One canonical key = one shared mailbox; a divergent key forks a *separate* project
(a separate mailbox) and the coordinating sessions can no longer see each other — split-brain.
Every `ac-*` call site that names `CANONICAL_PROJECT_KEY` resolves it that way.

**Which arg takes it:** `macro_start_session` takes it as **`human_key`**; every other
Agent Mail tool (`file_reservation_paths`, `release_file_reservations`, `install_precommit_guard`,
`send_message`, …) takes it as **`project_key`**. Same value, different parameter name — the
one call-signature fact worth keeping inline at each call site.

**Live accept-matrix (probed via `macro_start_session` against the dev server).** The
server does **not** reject any of these — it slugifies `human_key` (lowercase; every non-alnum
run → `-`) and maps each *distinct* key to a *distinct* project/mailbox. The coordination rule
therefore holds because a divergent key silently forks a divergent mailbox, **not** because the
validator enforces a format:

| `human_key` passed | Server result | Resolved project slug | Effect |
|---|---|---|---|
| `neometa/agent-compounds` (canonical two-segment) | accepted | `neometa-agent-compounds` (the shared project) | joins the ONE canonical mailbox ✅ |
| `sandbox/w2-shakedown` (two-segment, non-neometa) | accepted | `sandbox-w2-shakedown` (a different project) | forks a separate mailbox ⚠️ |
| `/Users/…/agent-compounds` (absolute path) | accepted | `users-craigvanheerden-…-agent-compounds` (a different project) | forks a **per-machine** mailbox — split-brain ⚠️ |

**Reconciliation verdict.** An earlier shakedown saw
`macro_start_session` *reject* a non-neometa key with `human_key must be an absolute path-like
project key` — an error that flatly contradicted this doctrine. That error **no longer
reproduces**: the current server accepts every form above. So the doctrine is
accurate as stated — an absolute path *does* fork a distinct mailbox (row 3, confirmed live) —
and the contradicting server message is retired; no upstream server bead is warranted (the
probe found nothing to fix server-side). The `project` field the commit-guard filters on (below) is this
same resolved-project identity — which is exactly why a divergent key defeats the guard.

## Conformance status

**Doctrine ratified (epic `ac-ycr`); wiring in flight.** Live today: Tier-1
minting in ac-loop / ac-implement / plan family; CLAIM_ASSIGNEE threading + gate union;
Tier-2 chore commits in scheduled workflows. Pending (blocked on this file's rewrite, now
landed): `ac-ycr.2` (review mint+reserve) · `ac-ycr.3` (batch-close mint) · `ac-ycr.4`
(self-deregister) · `ac-ycr.5` (roster hand-off + sweeps) · `ac-ycr.6` (FoggyCreek guard) ·
`ac-ycr.7` (engineer wip-commit hatch — independent).

**Cross-refs:** artifacts-dir scoping → `run-id.md` · bead lifecycle → `bead-conventions.md` ·
gate mechanics → `scripts/beads-closed-gate.sh` header.
