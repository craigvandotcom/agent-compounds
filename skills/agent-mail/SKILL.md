---
name: agent-mail
description: 'Multi-agent coordination via Agent Mail — registering a session identity, reserving files before editing a shared checkout, releasing + self-deregistering at exit, build slots, messaging. Use when starting any session that will commit code alongside concurrent agents, when hitting FILE_RESERVATION_CONFLICT or a pre-commit guard block, or when choosing between a minted Tier-1 identity and the FoggyCreek chore fallback. Triggers: "register agent identity", "reserve files", "file reservation", "agent mail", "macro_start_session", "release reservations", "deregister agent", "build slot", "FoggyCreek".'
---

# agent-mail — the multi-agent coordination domain

**Purpose:** one owner for how sessions coexist on a shared checkout — identity, file
reservations, teardown, build slots. The MCP server provides the tools
(`mcp__mcp-agent-mail__*`); this skill owns the doctrine and procedure for using them.

## The two-minute version

1. **Mint** a Tier-1 identity at session start if you will reserve files or commit under
   your own name; capture `name` + `registration_token`
   ([references/session-procedure.md](references/session-procedure.md) § Mint, § Export).
2. **Reserve** the files you are about to edit, at the work grain, BEFORE editing
   (§ Reserve). On `FILE_RESERVATION_CONFLICT`: skip or re-plan — never claim over it.
3. **Release + self-deregister** as your true last act (§ Release) — own name only,
   never `retire_agent`, never cross-session, never `FoggyCreek`.
4. `FoggyCreek` is the shared **Tier-2 chore identity** — it may commit chore files but
   may NEVER claim beads or reserve files
   ([references/agent-identity.md](references/agent-identity.md) § Tier 2).

## References (the domain canon)

- **[references/session-procedure.md](references/session-procedure.md)** — the CALL
  PROCEDURE: mint template, the two call-scoped facts (explicit token threading;
  per-shell `AGENT_NAME` re-assert), export block, reservation cycle, release/deregister
  exit ordering.
- **[references/agent-identity.md](references/agent-identity.md)** — the DOCTRINE: the
  two-tier contract (minted Tier-1 vs FoggyCreek Tier-2), the three deregistration
  layers + ac-ycr.8 runtime facts, assignee-vs-reservation split, enforcement layers
  (pre-commit guard), canonical project-key format.

## Related mechanisms (owned elsewhere, used with these tools)

- Pre-commit reservation guard install: `install_precommit_guard` — invoked in
  `ac-implement` Phase 0; blocks commits touching another agent's reserved paths.
- Build slots (advisory, always-grant): usage pattern in `ac-batch-close` § Build Slot;
  memory `agent-mail-build-slot-advisory`.
- Child-spawn contract (children usually hold NO Agent Mail tools — conductor reserves
  on their behalf): `ac-pipeline-builder/references/delegation-contract.md`.
