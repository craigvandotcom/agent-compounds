---
skill: agent-mail
created: 2026-08-14
last_pass: 2026-08-17
entries: 4
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
- skills: [agent-mail]
- impact: M
- frequency: every-run
- recurrence: 1
- related: [registration-keys-on-the-absolute-path-not-the-project]
- first_seen: 2026-08-17
- last_seen: 2026-08-17
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

## registration-keys-on-the-absolute-path-not-the-project
- skills: [agent-mail]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [roster-is-populated-with-names-that-never-mint]
- first_seen: 2026-08-17
- last_seen: 2026-08-17
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
