# Agent identity & file-reservation lifecycle (shared)

**One Agent Mail identity per top-level invocation, inherited by everything it spawns.**
Reservations enforce *between* invocations; the conductor serializes *within* one. This
supersedes the old per-stage pattern where each stage (ac-implement, ac-land, …) minted its
own `macro_start_session` name.

## The principle

- The reservation lock is grained at the **identity**, and identity = the **top-level
  invocation**: one `ac-loop` run · one human `/ac-<skill>` invocation · one casual editor session.
- Everything that invocation spawns — sub-stages (implement/land/review/merge) and their
  engineer/reviewer subagents — **shares the one identity**.
- **Protection boundary = the invocation.** Two invocations (loop vs loop, loop vs human) have
  distinct identities, so their reservations exclude each other. *Inside* one invocation there
  is **no lock granularity** — two subagents share the name, so the lock can't tell them apart.
  Intra-invocation safety is the **conductor's job** (serialize writers; ac-implement is
  one-bead-at-a-time).
- **Corollary:** never run two concurrent writers under one identity. To parallelize, spawn a
  **separate invocation** (its own identity) — not a second writer under the same name.

## Lifecycle — who does what, when

| Step | Who | When |
|---|---|---|
| **Mint** | the top-level invocation | at start, **only if** no identity was inherited |
| **Inherit** | every spawned stage / subagent | adopt the passed name — **never mint again** |
| **Reserve** | the working stage (ac-implement) | per **bead**, before editing, under the identity |
| **Enforce** | the edit hook (PreToolUse) + pre-commit guard | on every edit / at commit |
| **Release** | the working stage | per **bead**, on close — release the reserved paths |
| **Deregister** | the **minter only** | **once**, at the invocation's end (ac-land at loop exit) |

## Mint-or-inherit — the one rule that makes it work

On session start: **if an identity was handed down** (env `AGENT_NAME`, the delegation prompt,
or a `session_id → name` marker), **adopt it**. **Otherwise you are top-level** → call
`macro_start_session` to mint, and write the `session_id → name` marker so descendants *and the
edit hook* can resolve you.

Symmetric teardown: **only the minter deregisters** — it owns the identity. An inheritor that
deregistered would kill the live identity mid-run (which is why per-stage `deregister` is wrong
under this model; ac-land deregisters the inherited top identity once, at loop exit).

## Enforcement (two layers over advisory reservations)

- **Edit-time (target):** a global `PreToolUse(Edit|Write)` hook resolves the editor's identity,
  reads the local reservation store (`~/.mcp_agent_mail_*/…/file_reservations/*.json` — ~0-2 ms,
  no MCP round-trip), and **blocks (exit 2)** if the path is held by a *different* identity.
  **Fail-open** on any error/timeout (degrade to commit-time, never brick the machine).
- **Commit-time (current backstop):** the Agent Mail pre-commit guard blocks a commit touching
  another identity's reserved path. Keyed on `AGENT_NAME` in the commit shell.

## Reserve/release granularity — do NOT get this wrong

- **Reserve + release at the bead (task) grain** — hold for the whole unit of work, release on
  bead close. **Never per-edit:** releasing between the edits of one multi-file change opens a
  window for another invocation to grab a file mid-task and corrupt both.
- **Deregister at the invocation grain** — once, at exit.

## Standalone / casual / parallel

- **Standalone `/ac-<skill>` invocation (human)** → its own top-level invocation → mints its own
  name → distinct from any loop → protected.
- **Casual editor session (no skill)** → a `SessionStart` hook still mints an identity (if
  installed), so the edit hook protects it both ways. *Without* registration it's invisible to
  the lock — that blind spot is exactly what a SessionStart auto-mint closes.
- **Parallel = parallel invocations** (distinct identities), never parallel writers under one name.

## Implementation notes (confirmed)

- **Marker key = `CLAUDE_CODE_SESSION_ID`** (env-exposed to spawned commands incl. hooks).
  **In-process subagents share the parent's `session_id`** (probe-verified) — so one marker
  resolves every engineer/reviewer subagent to its session's identity, no per-subagent
  propagation. `SessionStart` fires per *real* session, not per subagent — minting happens once.
  Separate `claude -p` sub-sessions get their own id → env-propagated `AGENT_NAME` → their own
  marker (`MINTED=0`).
- **The edit guard reads ALL reservations and filters by the absolute `project` field**, never
  by the project *dir* name — robust against the project-keying gotcha (one app has several
  inconsistently-keyed dirs). Built + unit-tested: `~/.local/bin/am-edit-guard.py` (fail-open;
  `AM_EDIT_GUARD_MODE=advisory|enforce`; degrades to advisory when identity is unresolved, so it
  is **safe to install standalone** — it can't block until markers exist).

## Conformance status

**Partially built — not yet wired.** The **edit guard is built + tested** (above); the
SessionStart/PostToolUse/SessionEnd hooks + the global `settings.json` install + the skill
rewire (stages inherit instead of `macro_start_session`; **ac-land drops `deregister_agent`**;
ac-loop propagates `AGENT_NAME` into sub-stage spawns + a Phase-0 stale-identity sweep) remain.
Until wired, per-stage `macro_start_session` still functions (just coarser-grained than needed).

**Cross-refs:** artifacts-dir scoping → `run-id.md` · bead lifecycle → `bead-conventions.md` ·
edit hook → `edit-reservation-hook` (to build).
