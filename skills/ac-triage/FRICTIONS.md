---
skill: ac-triage
created: 2026-08-24
last_pass: 2026-09-06
entries: 1
---

# ac-triage — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     near-duplicate; bump recurrence and last_seen on the existing entry instead. -->

## safety-lives-on-the-ceremonious-path-and-the-casual-one-writes-unguarded
- skills: [ac-triage]
- impact: M
- frequency: occasional
- perceptibility: silent
- recurrence: 1
- related: []
- first_seen: 2026-08-24
- last_seen: 2026-08-24
- stage: triage
- status: open
- proposed_fix: put the state-write guard at the WRITE, not on a path. Any invocation that writes `.claude/state/` re-reads and compares before overwriting, regardless of how the skill was entered.
- narrative: the skill has two entry paths that write the same state files, and only the
  scheduled one is protected — its workflow spells worktree isolation nineteen times, the
  on-demand one not once. So a session started by hand can overwrite `.claude/state/` files
  that are newer than its own view and already committed, and nothing reports it: the write
  succeeds, the file looks written, and the loss is only visible later as state that
  mysteriously regressed to an older run.
  The general shape is worth more than the instance. Safety accreted onto the path that gets
  the most ceremony, because that is the path being written about when someone is thinking
  about safety. The casual path is both the less-guarded one AND the one a human reaches for
  when they want a quick answer — so the protection is weakest exactly where impulse is
  strongest. A guard attached to an invocation path protects the path; a guard attached to the
  write protects the data.
