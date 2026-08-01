---
skill: ac-human-session
created: 2026-07-30
last_pass: 2026-07-30
entries: 3
---

# ac-human-session — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## comment-trusted-over-the-events-audit-trail
- skills: [ac-human-session, ac-tidy]
- impact: L
- frequency: occasional
- recurrence: 1
- related: [memo-harm-never-verified-only-its-facts]
- first_seen: 2026-07-30
- last_seen: 2026-07-30
- stage: ac-human-session
- status: promoted
- proposed_fix: read the bead's own `events` table FIRST, before any other anti-rot verification — a comment is a CLAIM, `events` is the RECORD.
- narrative: the conductor re-gated bd-06opv.12 — a bead DECIDED 2026-07-10 and deliberately
  released by Craig three separate times with written reasoning — for the FOURTH time, believing
  its `human-gate` label had been silently lost. It had not. Every removal was a documented
  deliberate release, and the full 10-entry history sat in `.beads/beads.db` `events` the whole
  time. The conductor instead trusted bd-r0be9's comment, which logged an 18:35 re-add but NOT
  the 18:40 revert four minutes later by that same session. Worse, the error landed MINUTES after
  the conductor filed a new bead (bd-rc9kk) about exactly this detector defect, and two existing
  memory rules — completion-marker-absence-is-not-a-need-signal and
  human-gate-beads-rot-verify-before-presenting — both named bd-06opv.12 BY ID and neither was
  injected on that turn. Two written rules lost to one unread audit trail. That is why the check
  was escalated out of memory into a step in this skill (agent-compounds a7ac7f2) rather than
  restated a third time. Reverted same session.

## memo-harm-never-verified-only-its-facts
- skills: [ac-human-session, ac-tidy]
- impact: L
- frequency: frequent
- recurrence: 1
- related: [comment-trusted-over-the-events-audit-trail]
- first_seen: 2026-07-30
- last_seen: 2026-07-30
- stage: ac-human-session
- status: promoted
- proposed_fix: verify the memo's HARM, not only its facts — ask "what consumes this, and what breaks if I do nothing?" before working the list.
- narrative: proposal beads carry TOCTOU guards that re-check whether their NUMBERS went stale,
  and nothing checks whether the stated DAMAGE was ever real. 2 of 8 proposals applied this
  session were wrong about their own harm: bd-zugqh claimed 91 orphans "drift unscheduled" (a grep
  found parentage has ONE consumer, and a named orphan sat in the loop's ready set throughout),
  and bd-8ms5t assumed 102 findings were stale bookkeeping (only 1 had merged-fix evidence, so the
  auto-pruner it implied would have had nothing to close and would have had to loosen into
  laundering). In BOTH cases measuring the harm INVERTED the fix. A memo is an argument, not a
  finding. Landed as a clause in this skill's proposal-applying bullet (agent-compounds a7ac7f2).

## reservation-first-rule-broken-four-times-unnoticed
- skills: [ac-human-session]
- impact: M
- frequency: frequent
- recurrence: 1
- related: []
- first_seen: 2026-07-30
- last_seen: 2026-07-30
- stage: ac-human-session
- status: open
- proposed_fix: either make the Agent Mail edit guard enforcing for shared registry paths, or soften the written "no exceptions" rule to match what is actually enforced — a rule broken routinely and silently is worse than a narrower rule that holds.
- narrative: the Development Context Protocol states "Before editing any file, call
  file_reservation_paths ... No exceptions." This session edited FOUR shared registry files
  (three SKILL.md spines plus ac-pipeline-builder/references/board-scan.md) without reserving any of them, and did not
  notice until Craig asked about the skill-edit hook. `am-edit-guard.py` is registered at user
  scope but in `AM_EDIT_GUARD_MODE=advisory`, so nothing blocked or warned. The instructive part
  is the contrast within one session: every convention with a GATE (line budget, net-growth token,
  pointer integrity, registry listing budget) was honoured automatically and without conscious
  effort, while the prose-only convention was broken four times. Craig declined to flip the guard
  to enforcing pending a decision on scope. Directly supports the fleet rule
  recurring-rule-escalates-to-a-gate-not-a-restatement (Repos d2e3290d).
