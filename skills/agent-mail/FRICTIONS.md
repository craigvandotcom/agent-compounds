---
skill: agent-mail
created: 2026-08-14
last_pass: 2026-08-21
entries: 5
---

# agent-mail — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## commit-as-reservation-holder
- skills: [agent-mail]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-14
- last_seen: 2026-08-14
- stage: implement
- status: open
- proposed_fix: never mint a second exclusive reservation under a new name on paths already leased; commit as the identity that holds the exclusive lease (export that AGENT_NAME in the same shell as git commit). A second exclusive reserve makes the guard reject BOTH identities.
- narrative: RUN 20260814-213141-15553. A child took an exclusive reserve, then reserved again under a second name. The pre-commit guard then rejected commits from both identities — the first is no longer the exclusive holder of record once the second reserve lands, and the second cannot prove it holds the first lease. Cost minor. Distinct from the existing same-identity missing-env facts (`agent-mail-reservations-and-the-commit-shell`, `precommit-guard-needs-agent-name-in-shell`): those fail because AGENT_NAME is absent in the commit shell; this fails because the lease and the committer are two different minted names. Sibling: `references/session-procedure.md` § Export.

## roster-is-populated-with-names-that-never-mint
- skills: [agent-mail, ac-land]
- impact: M
- frequency: every-run
- recurrence: 3
- related: [registration-keys-on-the-absolute-path-not-the-project, roster-from-registrations]
- first_seen: 2026-08-17
- last_seen: 2026-08-20
- stage: ac-loop
- status: open
- proposed_fix: allocate a roster name only for an agent that will actually hold Agent Mail tools. Tool availability is per-agent configuration, and stance children (implementer, researcher, validator and the generic executors) do not carry the MCP surface — so a name minted for one is a name that can never register, and the teardown sweep that later hunts for it finds nothing and cannot distinguish "never existed" from "leaked". Size the roster from the set of tool-holding agents, and make the teardown sweep report unminted names as EXPECTED rather than as orphans.
- narrative: 48 roster names were handed to a run and 46 of them were never minted — a 4% hit rate
  on the run's own identity plan. The roster was sized from the DELEGATION graph (every child that
  would be spawned) rather than from the set of children that can register, and the great majority
  of those children are stance agents holding no `mcp__mcp-agent-mail__*` tools at all. Two costs
  follow, and the second is the expensive one: the plan misrepresents the run's coordination
  surface to anyone reading it, and the closing sweep spends its time looking for 46 identities
  that were never created, which makes a genuine leak indistinguishable from the noise floor. The
  roster is a coordination artifact, so it should model who can coordinate, not who will run.
  **+1 — same shape at small scale, and the teardown reported CLEAN off it.** A roster handoff
  listed 11 identities; exactly one was ever minted. The other 10 were stance children, which
  hold no `mcp__mcp-agent-mail__*` tools BY CONSTRUCTION, so they could not have registered
  under any circumstances — the 1-of-11 hit rate was determined before the run started. What
  this occurrence adds is the consequence the first one only predicted: the teardown verified
  the full roster, found 10 names absent, and reported a clean sweep. A sweep that cannot
  distinguish "never existed" from "leaked" returns the same result in both cases, so its green
  carries no information about whether anything actually leaked. That makes this an instance of
  the global rule `a-dormant-pipeline-reports-success` (a check whose "found nothing" is
  indistinguishable from "never ran"), and it is the reason the fix must be to size the roster
  from tool-holders rather than to make the sweep more thorough — a more thorough sweep over a
  fictional inventory is still proving nothing.
  **+1 (RUN 20260820-005558-8974, 3 of ~40) — and the fix is now stated as a source, not a size.**
  Three names minted against roughly forty handed out. The two prior occurrences argued for
  *sizing* the roster from tool-holders; this one shows sizing is the wrong verb, because the
  set is not knowable at plan time — a conductor cannot always tell which children will carry the
  MCP surface. **The roster must be BUILT BY QUERYING REGISTRATIONS at teardown, not authored in
  advance from the delegation graph at all.** The plan describes who ran; only the registry
  describes who can leak, and teardown is exclusively interested in the second. Land-side pointer:
  `roster-from-registrations` in `skills/ac-land/FRICTIONS.md`.

## registration-keys-on-the-absolute-path-not-the-project
- skills: [agent-mail]
- impact: M
- frequency: occasional
- recurrence: 2
- related: [roster-is-populated-with-names-that-never-mint]
- first_seen: 2026-08-17
- last_seen: 2026-08-20
- stage: ac-batch-close
- status: open
- proposed_fix: register with the canonical project KEY, never a filesystem path — a registration made from a different cwd, or with an absolute path passed as the project, lands in a second project namespace that no sibling agent's inbox or roster query can see. Caller discipline alone has now failed across four separate occurrences, so the fix must move into the tool surface: have the session macro DERIVE the canonical key rather than accept whatever the caller passes, and have registration assert the key it actually used back to the caller. App-local rule and history: BCA memory `agent-mail-project-keying-gotcha`.
- narrative: a closing-ceremony identity registered under the ABSOLUTE-PATH project key instead of
  the canonical one, reproducing the known upstream key-fragmentation bug live in a real run. The
  agent registers successfully, reports success, and is invisible: it sits in a namespace of one,
  so no sibling can message it, no roster query lists it, and the teardown sweep run against the
  canonical key cannot deregister it. Every failure mode here is SILENT and every symptom looks
  like "nothing happened" — which is also what a correctly quiet run looks like. Worth pairing
  with the roster entry above: between them, an identity plan can be simultaneously over-populated
  with names that never mint and missing the one identity that did.
  **+1, and the fragmentation is FLEET-WIDE, not per-session.** A single identity was found
  split across THREE project keys at once — and one of those keys is an absolute path rooted at
  `/home/van/...`, a filesystem layout belonging to a DIFFERENT MACHINE. That is the escalation
  worth recording: the earlier occurrence could be read as one caller passing one bad argument
  in one session, and this one cannot. Registrations keyed on absolute paths accumulate across
  machines into a permanent namespace sprawl, because the key that a Linux box mints under is
  unreachable from a Mac and vice versa, so neither side can ever see, message, or deregister
  the other's rows. Caller discipline has now failed across five occurrences on at least two
  machines, which retires "remind the callers" as a fix: the macro must DERIVE the canonical
  key and refuse a path-shaped project argument outright.

## teardown-and-sweep-recipes-are-unrunnable-as-published
- skills: [agent-mail]
- impact: M
- frequency: occasional
- recurrence: 0
- related: []
- first_seen: 2026-08-17
- last_seen: 2026-08-17
- stage: ac-land
- status: open
- proposed_fix: see the primary entries.
- narrative: POINTER ENTRY, not a copy — the guard half is counted at
  `dcg-blocks-the-skills-own-canonical-artifact-redirects` in `skills/ac-loop/FRICTIONS.md`, the
  shell half at `zsh-nullglob-aborts-the-teardown-selector` in `skills/ac-land/FRICTIONS.md`.
  LOCAL MANIFESTATION: the roster sweep recipe published in `references/agent-identity.md` cannot
  be run as written on the fleet — its selectors abort on a zsh no-match instead of returning an
  empty set, and its file-fed loop is blocked by dcg, which reads a `done` read-redirect as a
  truncation of the file being read. The identity layer is where this matters most: a sweep that
  aborts leaves live registrations and held reservations behind, and the next run inherits them as
  phantom conflicts with no trace of where they came from.

## edit-guard-marker-holds-env-fallback-not-minted-name
- skills: [agent-mail, ac-loop-swarm]
- impact: L
- frequency: every Tier-1 session
- recurrence: 1
- related: [roster-is-populated-with-names-that-never-mint]
- first_seen: 2026-08-21
- last_seen: 2026-08-21
- stage: implement
- status: open
- proposed_fix: (1) `am-identity-set.sh <name>` helper a session runs right after `macro_start_session` to rewrite its marker with the minted name (MINTED=1); (2) key the marker by session AND writer so N in-session workers do not share one marker — read `agent_id` from the hook stdin payload if Claude Code supplies it, else accept that enforce is top-level-sessions-only; (3) only then flip `AM_EDIT_GUARD_MODE=advisory` → `enforce`, after an advisory observation of `/tmp/am-edit-guard.log` per the advisory-first rule.
- narrative: Flipping the edit guard to enforce was attempted as a one-line settings change and stopped before commit. `am-identity-start.sh` writes the marker once at SessionStart from `$AGENT_NAME` (the `FoggyCreek` env fallback). `macro_start_session` mints a different name and nothing rewrites the marker. `resolve_self()` therefore returns `FoggyCreek` for every minted session; in enforce mode the guard would block a session editing the very paths it reserved under its minted name — the whole Tier-1 pipeline, not an edge case. Verified live: this session's marker read `AGENT_NAME=FoggyCreek MINTED=0` while it held reservations as JadeCave and ChartreuseBrook, and `/tmp/am-edit-guard.log` held 105 WOULD-BLOCK lines — the newest three being this session's own edits to paths it had itself reserved ("reserved by 'JadeCave'"). The advisory stream is not clean; it is one false positive per Tier-1 edit. Second blocker: the marker is per `CLAUDE_CODE_SESSION_ID`; `ac-loop-swarm` mints N identities inside one session, so even a rewritten marker names only the last writer. Cost: enforce stays off; edit-time enforcement remains advisory-only and the pre-commit guard is the sole real gate.
