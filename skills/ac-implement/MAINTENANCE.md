---
skill: ac-implement
archetype: orchestrator
last_pass: 2026-07-30
spine_lines: 736 / target ≤500 orch
---

# ac-implement — maintenance ledger

## Health
over orch target; contradiction-wave fixes applied 2026-07-30 (ac-9hi, ac-bkg, ac-32p, ac-gwg); horizontal dedup queued under epic ac-gcj

## Inbox — shape signal awaiting triage
<!-- Behavior-changing signal does NOT go here — it goes to a skill:ac-implement skill-improvement bead. -->
- [2026-07-30 · src:audit] §Register Session Identity block (~32 lines) is a verbatim twin of ac-loop's — candidate for `_shared/agent-mail.md` (epic ac-gcj wave 2)
- [2026-07-30 · src:audit] Pathspec-commit mechanics restated at ~L549-576 after declaring `references/shared-checkout-git.md` the single source — candidate for pointer-only (epic ac-gcj wave 3)

## Holding pen — content pulled from SKILL.md, disposition undecided
- [pulled 2026-07-30 · from §Phase 1c Review Quality · review-by 2026-08-29 · default: delete]
  **Worktree mode only:** Before copying files from a worktree, verify no uncommitted changes: `git -C <worktree> status --porcelain`. If uncommitted changes exist, commit them in the worktree first. `cp` reads the filesystem (committed state), not the working tree — uncommitted edits will be silently lost.
  — uncertainty: worktree mode is retired under trunk-direct (banned at §Phase 0 and §Red-test classification; "no mode switch needed" §Multi-Session Parallelism), but ac-review still runs its test-quality probe in a disposable worktree — parked in case a sanctioned worktree path returns. (bead ac-gwg)

## Cut-log — append-only audit trail (feeds the churn detector)
- [2026-07-30] CUT "Worktree mode only: before copying files from a worktree…" — reason: stale (contradicts trunk-direct ban, same file) — relocated→holding pen above (bead ac-gwg)
