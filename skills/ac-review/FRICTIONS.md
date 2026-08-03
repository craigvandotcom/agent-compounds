---
skill: ac-review
created: 2026-07-29
last_pass: 2026-08-03
entries: 7
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
- recurrence: 2
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-30
- stage: ac-loop
- status: open
- proposed_fix: verify reservation release by re-listing the project's held reservations after the call, not by reading the release call's returned count.
- narrative: `release_file_reservations` returned `released:0` despite 12 leases having been granted earlier — most likely because the pre-commit guard had already cleared them. The operation is idempotent so no harm was done, but the zero count makes the release unverifiable from the response alone, and reads exactly like a failure to a caller who doesn't already know that. RECURRENCE 2 (2026-07-30, ac-human-session): identical shape on a single-path release — `released:0` on a lease granted ~2 minutes earlier and well inside its TTL. Independently re-derived this entry's own proposed_fix under pressure (re-listed active reservations, which showed nothing held, confirming release) before discovering this entry already prescribed it — evidence the fix is right AND that the log is not being read before the same friction is re-hit.

## low-severity-findings-each-get-their-own-bead
- skills: [ac-review, ac-tidy]
- impact: L
- frequency: every-run
- recurrence: 1
- related: []
- first_seen: 2026-07-30
- last_seen: 2026-07-30
- stage: ac-human-session
- status: promoted
- proposed_fix: severity floor in the Phase-4 exhaust rule — a Low finding never gets its own bead; roll all of a run's Low findings into ONE bead, split out only if an item grows.
- narrative: the exhaust rule said "nothing actionable leaves this phase as prose", and reviewers already skip Low + leave nits in the report — but a Low finding that DID surface still got its own P3 bead. The finding lane therefore inflated monotonically with nothing pruning it: 55 open findings on 2026-07-22 to 102 by 2026-07-30 (+84% in ~8 days), while ac-tidy escalated the raw count across four nightlies and produced zero action. The lane was NOT stale bookkeeping — measured, only 1 of 102 open findings carried any evidence of a merged fix — so it could not be drained by an auto-closer either; the only lever was the inflow. Landed as the severity floor (agent-compounds 4d8ec80) after Craig ruled A+D on bd-8ms5t. Recorded here because the fix was applied straight to SKILL.md core with no prior friction entry, which is the evidence-trail gap this log exists to close.

## contradictory-panel-consensus-needs-source-re-derivation
- skills: [ac-review]
- impact: M
- frequency: rare
- recurrence: 1
- related: []
- first_seen: 2026-07-31
- last_seen: 2026-07-31
- stage: ac-loop
- status: open
- proposed_fix: contradictory consensus across review lenses is a signal to RUN THE COMMAND and re-derive from source — never average or split the difference on severities.
- narrative: two review lenses reached opposite conclusions from the same facts. Resolving it required the conductor to read a migration's call-site audit directly rather than trust either lens's stated severity. Cost ~6 minutes of conductor verification.

## panel-reviewer-wrote-to-shared-checkout
- skills: [ac-review]
- impact: H
- frequency: rare
- recurrence: 1
- related: [ac-7rf]
- first_seen: 2026-07-31
- last_seen: 2026-07-31
- stage: ac-loop
- status: resolved
- proposed_fix: shipped — Phase 3 mandatory post-panel tree check + banned-ops list for panel workers (ac-7rf P0 acceptance).
- narrative: a panel reviewer planted a vulnerability into the shared main checkout via an unscoped `git stash` from a worktree. Read-only reviewers can still mutate the shared tree through guard gaps; the post-panel `git status` diff against the Phase-1 inventory is the detection layer.
  **2026-08-03 — adjacent surface, not covered by this fix:** a refine-panel reviewer removed a live pre-commit guard through an MCP call, which leaves no trace in the `git status` diff this entry's fix inspects. Logged as `reviewer-prompts-must-explicitly-forbid-mutating-mcp-calls` in ac-bead-refine's file; the pairing is the point — scoping away git mutation does not scope away tool-surface mutation.

## reviewers-cannot-see-harness-builtin-skills
- skills: [ac-review]
- impact: H
- frequency: occasional
- recurrence: 1
- related: [contradictory-panel-consensus-needs-source-re-derivation]
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: any finding of the form "skill/tool X does not exist" must be checked by the CONDUCTOR against the live available-skills list before it is accepted or auto-fixed — a repo-scoped reviewer's filesystem is not the harness's namespace, so absence-of-evidence from a reviewer is not evidence of absence.
- narrative: a panel reviewer raised a Critical on the grounds that a referenced skill did not exist. It does — as a harness BUILT-IN, invisible to a reviewer whose view is the repository checkout. The finding was well-argued, correctly cited (the name genuinely appears nowhere in the repo), and wrong, and it reached the auto-fix stage before the conductor caught it. Had it landed, the fix would have DELETED a valid reference. This is the reviewer-blind-spot class at its most dangerous shape: the reviewer is not mistaken about anything it can see, so nothing in its own reasoning can flag the gap, and the finding's confidence is fully justified from inside its context. Only the conductor holds the namespace that falsifies it.

## panel-undercounts-occurrences-of-a-multi-site-defect
- skills: [ac-review]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [contradictory-panel-consensus-needs-source-re-derivation]
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: when a finding asserts a COUNT ("2 broken anchors", "3 call sites"), re-derive it mechanically before scoping the fix — a per-file occurrence grep, not a re-read. A reviewer's table is a sample of what it happened to inspect, not an enumeration, and the fix is scoped from the number.
- narrative: a panel's site-by-site audit reported 2 broken anchors; a mechanical per-file occurrence count found 6. The 3x undercount came from a reviewer that presented its results as a TABLE — the format that most strongly signals exhaustiveness — while having audited only the sites it happened to open. Cost ~10 tool calls of conductor verification, and would have cost a fix that repaired a third of the defect while closing the finding. Converges with `contradictory-panel-consensus-needs-source-re-derivation` on the same remedy (re-derive from source rather than trust the panel's summary), but the trigger is different and easier to miss: there is no contradiction here to alert anyone — one reviewer, confident, internally consistent, and numerically wrong.
