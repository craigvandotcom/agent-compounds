---
skill: ac-review
created: 2026-07-29
last_pass: 2026-07-29
entries: 3
---

# ac-review — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## stash-count-self-report-was-wrong
- skills: [ac-review]
- impact: M
- frequency: rare
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: carry the no-stash rule explicitly in engineer prompts rather than relying on AGENTS.md pickup; never accept an agent's stash-count claim without checking `git stash list` directly.
- narrative: a fix engineer ran `git stash` — forbidden by AGENTS.md — self-disclosed it, and then claimed the stash was back down to 2 entries. That claim was wrong: 15 historical entries actually existed. Caught as a near-miss before it caused harm, but it shows an agent's self-report of a guard-adjacent action cannot be trusted without independent verification.

## shared-checkout-git-add-a-risks-foreign-work
- skills: [ac-review]
- impact: L
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: pathspec scoping is load-bearing on a shared checkout, not hygiene — never `git add -A` in a width>1 run; always add explicit file paths.
- narrative: a concurrent qa-browser session left 3 CORE/journeys docs dirty in the shared working tree. A bare `git add -A` at this point would have swallowed another session's in-flight work into this commit. Caught as a near-miss pre-commit by reviewing `git status` before staging.

## file-reservation-release-zero-count-unverifiable
- skills: [ac-review]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: verify reservation release by re-listing the project's held reservations after the call, not by reading the release call's returned count.
- narrative: `release_file_reservations` returned `released:0` despite 12 leases having been granted earlier — most likely because the pre-commit guard had already cleared them. The operation is idempotent so no harm was done, but the zero count makes the release unverifiable from the response alone, and reads exactly like a failure to a caller who doesn't already know that.
