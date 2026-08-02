# Agent Mail — session procedure (mint · export · reserve · release)

**Scope (ac-gcj.2):** the CALL PROCEDURE every Tier-1 session runs. The governing
doctrine — tiers, deregistration layers, call-scoped facts, project key format,
enforcement — lives in `agent-mail/references/agent-identity.md`; this file never restates the why.
Skills point here and keep only their genuine deltas (build slots, backstop sweeps,
teardown ordering, skill-specific reservation params).

## Mint (every session that reserves files or commits under its own name)

```
mcp__mcp-agent-mail__macro_start_session(
  human_key: CANONICAL_PROJECT_KEY,   // this tool takes human_key (other tools take project_key) — canonical "neometa/<app-dir>" key; key-format + never-absolute rule: agent-mail/references/agent-identity.md § Project key format
  program: "claude-code",
  model: "<the model THIS session is running, e.g. claude-opus-5>"  // never a fixed string — a stale pin misattributes every commit and review
)
```

Capture the returned `name` AND `registration_token`.

> **Two call-scoped facts (`ac-g93`):**
> (1) thread `registration_token` EXPLICITLY on EVERY privileged / mutating Agent Mail
> call — file reservations (`file_reservation_paths`, `release_file_reservations`,
> `renew_file_reservations`, `force_release_file_reservation`), build slots,
> `send_message` / `reply_message` (as `sender_token`), and `deregister_agent` /
> `retire_agent`. Do NOT rely on same-session auth carry — it is transport-conditional
> and never inherited by a separate phase child (blanket rule + verdict:
> `agent-mail/references/agent-identity.md` § Call-scoped facts).
> (2) `export` lives only in the bash call that ran it — every later bash call is a
> fresh shell: re-assert `AGENT_NAME` (and any env the pre-commit guard reads) in the
> SAME call as each `git commit`/`git push`, or the guard treats you as anonymous and
> blocks against your own reservation. Same rule for ANY variable a skill carries
> across phases — recompute or restate the assignment at point of use.

## Export (attribution)

```bash
export GIT_IDENTITY_ENABLED=1   # Agent Mail git identity/attribution — NOT worktree isolation (WORKTREES_ENABLED made subagents worktree; see rule-agent-mail-identity-setup)
export AGENT_NAME=<returned-name>   # unique per session — re-assert inline at each git commit
```

Parallel sessions each run their own mint and get a distinct adjective+noun name — no
manual discriminators. A **stance-spawned** child holds no Agent Mail tools and cannot
reserve — hand it an `AGENT_NAME` and reserve on its behalf (the two-tier contract:
`agent-mail/references/agent-identity.md`; parallel writers need distinct identities **or** provably
disjoint scope).

## Reserve (at the work grain, BEFORE touching files)

```
mcp__mcp-agent-mail__file_reservation_paths(
  project_key: CANONICAL_PROJECT_KEY,   // project_key here, not human_key
  agent_name: AGENT_NAME,
  paths: [<files this session will edit>],
  ttl_seconds: <covers the expected work>,
  exclusive: true,
  reason: "<skill> — <what>",
  registration_token: <from the mint>
)
```

On `FILE_RESERVATION_CONFLICT`: do NOT claim the work — skip or re-plan around the
holder (enforcement layers + conflict doctrine: `agent-mail/references/agent-identity.md`
§ Enforcement).

## Release + self-deregister (session exit — the ceremony's true last act)

Order: `release_file_reservations` (all your paths) → any skill-specific slot/waiter
cleanup → `deregister_agent` LAST, so the registry doesn't accumulate one zombie
identity per ceremony. Run it even on an aborted run. Don't leave reservations to
TTL-expire; if the commit failed, do NOT release — the files still need the work.

```
mcp__mcp-agent-mail__deregister_agent(
  project_key: CANONICAL_PROJECT_KEY,
  agent_name: AGENT_NAME    // own name ONLY — Layer 1 self-deregister; token optional
)                           // on the self path (the minting session is authenticated)
```

Never `retire_agent`, never deregister another session's name (name-only cross-session
calls are rejected at runtime, ac-ycr.8), never deregister `FoggyCreek` — a Tier-2
session holds no reservations and skips this section entirely
(`agent-mail/references/agent-identity.md` § Tier 2, § Deregistration). Layers 2/3 (roster + stale
sweeps) are backstops for sessions that die before reaching here — they do not replace
this self-deregister.
