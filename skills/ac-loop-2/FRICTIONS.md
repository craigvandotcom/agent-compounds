---
skill: ac-loop-2
created: 2026-08-09
last_pass: 2026-08-11
entries: 6
---

# ac-loop-2 — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

<!-- ac-loop's friction log is NOT this skill's history: the phase model changes which
     frictions are even possible. Start empty; do not import entries from v1. Cross-cutting
     frictions that recur here AND in ac-loop stay counted in each log, cross-referenced
     via `related:`. -->

## commit-mutex-lock-path-assumes-git-is-a-directory
- skills: [ac-loop-2]
- impact: L
- frequency: every-run
- recurrence: 1
- related: []
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: build
- status: open
- proposed_fix: derive the lock path with `git rev-parse --git-common-dir` (NOT `--git-dir`, which is per-worktree and re-opens the collision under linked worktrees), add a liveness assertion logging seconds-to-acquire, fail LOUD on "cannot create" (ENOTDIR/EACCES) instead of folding it into the "held by someone else" retry path, and cut the retry bound to safely under the Bash tool's 600s cap.
- narrative: THE RUN'S HEADLINE DEFECT. Phase 2's only mandated safety mechanism was INERT for the
  entire run and nobody could tell. The briefed lock path is `$PROJECT_ROOT/.git/ac-loop2-commit.lock`,
  but `.git` in body-compass-app is a 64-byte git-submodule POINTER FILE, so `mkdir` returns
  ENOTDIR on every one of 450 retries — indistinguishable from "lock held" to the retry loop. Found
  independently by two lanes (the curator lane observed ZERO lock directory while siblings were
  landing commits), then reproduced by the conductor. SYSTEMIC: every neoMeta app under `software/`
  is a submodule, so this is not BCA-specific. Five clean Phase-2 commits landed anyway — through
  lane spacing and territory disjointness, NOT through the mechanism briefed to provide that
  guarantee, which makes the clean outcome zero evidence the mutex works. Compounding: the 450x2s
  bound is 900s, which exceeds the Bash 600s cap, so a stuck worker is SIGTERMed before its own
  FATAL line can print — silent by construction; the guards lane burned a full 10-minute tool
  timeout and landed nothing. The corrected form was proven live in this same run: the serial risk
  queue acquired first try at the `--git-common-dir` path. Beads bd-ye0rp (P0, its body still
  specifies the narrower `--git-dir` and needs amending), ac-ac-loop2-commit-mutex-submodule-fsmh
  (agent-compounds board), bd-giy7u (P1, the 900s-vs-600s collision). Fleet fact:
  `neometa/memory/auto/loop-retro-neometa-app-dotgit-is-a-pointer-file.md`.

## phase-3-global-pass-does-not-state-which-test-tiers-it-covers
- skills: [ac-loop-2]
- impact: L
- frequency: occasional
- recurrence: 1
- related: [commit-mutex-lock-path-assumes-git-is-a-directory]
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: converge
- status: fixed
- proposed_fix: LANDED — element 3 requires `### Test-tier exposure` in bead-conventions § Implementation contract; Phase 3 must enumerate covered/excluded tiers and run any declared tier the standing pass skipped (`converge-phase.md` § 1).
- narrative: Phase 3 reported `pnpm test:all` 12366 passed / 0 failures on 0c1ca0a7. The identical
  commit then failed CI's DB Deploy validate leg TWICE with 23514 constraint violations, because
  `__tests__/supabase-integration/**` (74 files / 705 tests) is excluded from the standing vitest
  gate by config and runs only under `pnpm test:integration:local`. So a migration-shaped bead can
  satisfy every Phase-3 signal the loop checks and still be wrong. The converge agent NOTED the
  exclusion in its report and the conductor did not treat it as a hole — the conductor's error, not
  the agent's, which is why the fix is a required report field rather than an exhortation. Direct
  cause of the run's repair% breach: 1 repair item / 6 beads = 16.7%, above the 10% guidance line,
  and specifically a TEST-TIER scope miss rather than a spec miss (the bead's spec was complete; it
  was never asked the question). Cost: a full repair round of a 2-round cap, a fixture rewrite,
  a second CI dispatch. Beads bd-qouko (project-local hole), bd-04bfp (the contract fix, human-gate).

## frozen-head-is-not-enforceable-on-a-shared-checkout
- skills: [ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 1
- related: [filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: orient
- status: open
- proposed_fix: stop treating FREEZE_SHA as a guarantee and state its real status in the skill: it is a LABEL for a moment, not a lock. Every barrier crossing and every anchor re-check must MEASURE drift (`git diff --name-only FREEZE..HEAD`) and intersect the changed paths against each lane's territory, rather than trusting that the freeze held. Say explicitly which artifact classes survive drift (file-derived anchors) and which do not (board-derived counts).
- narrative: reported independently THREE times in one run by three different agents. A concurrent
  non-loop curator session moved HEAD twice during Phase 1 alone (853fcd8c to cdc22bc3 to 96c01acb).
  Nothing in ac-loop-2 can stop this — the checkout is shared with sessions that never read the
  skill — so a contract written as though the freeze holds is unenforceable by construction. The
  observed split is the useful part and belongs in the skill text: file-derived anchors held across
  the drift, board-derived counts drifted WITHIN the run (the cross-repo bead fraction was measured
  at 10/22, then 12/30 later the same run, partly self-inflicted by the refining agent's own
  stamps). The run's own Phase 1-to-2 barrier did the right thing — it diffed the freeze against
  live HEAD and confirmed the changed paths were disjoint from every refined bead's territory — so
  the correct behaviour already exists in practice and just needs to be the written contract.

## skill-edit-guard-fires-on-reads-under-skills
- skills: [ac-loop-2]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: build
- status: open
- proposed_fix: document the actual trigger surface where children are told to consult registry doctrine — the agent-compounds skill-edit guard fires on READ operations under `skills/`, not only on writes — and give the accepted read form so a child does not read the block as "this file is off-limits" and silently skip the doctrine it was told to check.
- narrative: a child instructed to consult registry doctrine was blocked while merely READING a file
  under `skills/`. The guard's name and every mental model of it say "edit", so the block reads as a
  permissions error rather than an expected shape, and the cheap wrong response is to skip the read
  and proceed on memory. Small cost this run, but the failure mode is invisible: a child that skips a
  doctrine read reports nothing unusual. Note the contrast with ac-human-session's
  `am-edit-guard.py` entry, where the Agent Mail guard was in advisory mode and did NOT fire on four
  real shared-registry edits — two different guards, opposite calibration errors, same net effect of
  agents not knowing what is actually enforced.

## dcg-false-positives-on-angle-bracket-inside-quoted-prose
- skills: [ac-loop-2]
- impact: M
- frequency: frequent
- recurrence: 0
- related: []
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: build
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in `skills/ac-loop/FRICTIONS.md`,
  where all occurrences are counted (recurrence 6 as of RUN 20260811-113939-36193). Recorded here
  because the v2 phase model inherits the hazard unchanged and its own delegation prompts emit it.
  LOCAL MANIFESTATION: five independent blocks in one ac-loop-2 run — conductor, doctrine refine
  child, ledger build child, and the closing/reflect ceremonies — each rediscovering the same
  heredoc-to-file workaround at its own cost. Trigger set is wider than shell redirects: ASCII
  arrows in ordinary prose tokenise identically, so writing ABOUT the hazard triggers it. Local fix:
  `ac-loop-2/references/delegation-prompts.md` must tell every prompt that writes bead body text to
  write the prose to a literal temp file and pass the file, and to keep bracket-style placeholders
  out of prose entirely.

## filed-beads-carry-drifted-anchors-and-false-premises
- skills: [ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 0
- related: []
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: spec
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in
  `skills/ac-bead-refine/FRICTIONS.md`, where occurrences are counted. Recorded here because it is
  the strongest validation ac-loop-2's own implementation contract received this run. LOCAL
  MANIFESTATION: cited `file:line` anchors had drifted in 100% of the beads audited, 13 separate
  drifts in a single bead — which makes contract element 1 (re-open every anchor at the frozen HEAD)
  load-bearing rather than ceremony, and makes an inherited "verified" claim from a prior refine
  round worthless as evidence. Element 6 (the adversarial break-attempt round) separately caught a
  territory omission that would have shipped a self-contradictory, byte-parity-CI-enforced prompt
  pair asserting the OPPOSITE of Craig's ruling; a refine without that round would have stamped it
  refined. Both elements earned their cost in measured terms this run — record that before anyone
  proposes trimming them.

## refine-all-degrades-to-priority-cut-when-set-exceeds-width
- skills: [ac-loop-2]
- impact: H
- frequency: every-run
- recurrence: 0
- related: []
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: spec
- status: fixed
- proposed_fix: LANDED — Phase 1 item 2 restated as a DRAIN (width bounds concurrency, never
  coverage; conductor decides ORDER, never MEMBERSHIP), grouping/order/assertion moved to
  `references/refine-drain.md`, and a `refine-drain:` assertion added to the sitting barrier.
- narrative: Phase 1 said refine "every unrefined non-`human-gate` bead" but fixed width at 5-6 and
  defined NO overflow behaviour. RUN 20260811-113939-36193 opened with 83 unrefined beads against a
  width of 5, so "every" silently degraded to "as many as fit" and the conductor improvised a cut.
  The nearest signal to hand was `priority` — which on this board encodes WHO FILED THE BEAD, not
  its value. Measured: 9 of 9 Craig-reported beads sat at P2; 14 of 26 agent-filed beads sat at
  P0/P1. A `priority <= 1` cut therefore admitted 14 agent-filed beads and STRUCTURALLY ZERO
  human-reported ones — it was arithmetically impossible for a Craig bug report to enter the wave.
  Eleven of his product bugs (input hidden behind the keyboard, credit-failed rows never
  self-healing, widget staleness) were ready, unblocked, non-human-gate, and invisible; one was
  re-discovered hours later by an expensive device-QA pass in the same run. The loop shipped
  beads-ledger guards and husky hooks instead. NOTE the regression direction: `ac-loop` v1 already
  states the correct doctrine ("ONE eligible-work queue, dispatched CONTINUOUSLY up to
  PARALLEL_WIDTH... the list is PRIORITY, NOT a barrier") and carries a Rule-0 Bug Lane that would
  have caught these. v2's phase-gated redesign dropped both and replaced them with nothing, so this
  is a restoration, not an invention. v1 needs no edit.
