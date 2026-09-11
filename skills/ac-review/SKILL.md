---
name: ac-review
description: 'The batch boundary''s independent review: a post-batch verdict over the committed batch range, invoked by the batch boundary (trigger: ''review the batch''), plus the same contract run targeted at any range Craig names (`ac-review <range>`). Reviewers run the validator stance — a different stance from the implement workers, read-only on the shared tree, and every finding carries ACCEPT/FIX/DEFER plus a catch-stage label; only a named impact: makes a bead. ac-batch-close and ac-publish route its report via report_dest. Triggers: ''/ac-review'', ''review the batch'', ''review this range''.'
---

# ac-review — the post-batch review

**One contract, two entry points.** Batch-boundary over the just-closed batch ("review the
batch"); same contract at any range Craig names (`ac-review <range>`). No phase ladder
(Phases 0–8 gone): verdict + findings; fixing is the implement lane (§ Findings).

## Who reviews

- **A different stance from the workers — the validator, tier-resolved per harness.**
  (L2 — survives tier convergence) The same weights re-reading their own diff are not
  independent eyes: they share the diff's blind spot; convergence never retires this rule.
- **READ-ONLY on the shared tree.** No write/mutation tooling, no "just fixing it while I'm
  here" — a reviewer that can edit is a second author (H-impact incident). Sole carve-out:
  sabotage probes in a **disposable worktree**; the result is a finding, never a diff.
- **Depth by risk, not habit.** A batch touching a gate, an auth path, a migration or a
  destructive operation gets the deep panel; prose and config get one pass.

## The contract

1. **Scope.** Batch boundary: the committed batch range plus its bead ids. Manual: the named
   range. Diff pathspec everywhere: `:(exclude).beads/`.
2. **Panel.** Spawn reviewers in parallel — one per dimension from
   `references/review-dimensions.md` (core four always; test-quality/contracts per their SKIP
   rules), each prompt built from `references/reviewer-prompt-template.md`. Write the panel
   manifest (`panel-round-1.json`: spawned/skipped) BEFORE spawning — `consensus.py` refuses
   to run without it (exit 3), and a spawned dimension with no output file is a partial
   failure, never a silent pass. A reviewer that dies is re-spawned ONCE.
3. **Consensus.** `python3 scripts/consensus.py --artifacts-dir <dir> --round 1`. Exit 3
   (PANEL UNKNOWN) is a hard stop — reconstruct the manifest, never default the panel. A
   `reviewers_missing` that survives the re-spawn → file the un-reviewed dimension as an
   honest harness-failure bead: `br create -t task --labels origin:ac-review,qa-blocker,review-finding,unrefined,impact:<class>`; then `VERDICT: NEEDS_DECISION` — never `-t bug` with no catch-stage (a harness failure is not a shipped defect).
4. **Report.** `references/report-template.md` — the `**Range:**` line (full SHAs,
   machine-parsed coverage) and the `**Panel:**` line (copied from
   `consensus-round-1.json`: the panel that ACTUALLY ran) are mandatory. Destination:
   `.claude/reviews/pending/` when the boundary passes `report_dest`, `.claude/reviews/`
   root otherwise — never `.claude/reviews/batch/` (that dir is the review-mark).
5. **Verdict.** `VERDICT: APPROVED` only if every manifest dimension reported, findings are
   dispositioned, and no qa-blocker remains; else `VERDICT: NEEDS_DECISION` — the boundary
   stops instead of closing. The panel/conductor writes the verdict; the implementer whose
   diff is under review never does (the party optimising against the measure cannot record
   the verdict).

## What the review judges

- The dimensions in `references/review-dimensions.md`, plus two a green suite cannot see:
  **fixture-shape validity** — could each test's fixtures EXIST in production? a test over an
  impossible input asserts nothing — and **causal sufficiency** — for every bead the batch
  closed, does THIS diff produce that GREEN? (The token is not the thing; and the probe may
  have flipped for another cause — a sibling's commit, an already-green AC.)
- **Review surface:** code a user reaches in production, or code that writes what a user
  reads (`review-dimensions.md` § Review surface). Factory findings (scripts, tests, CI,
  `.claude/`, docs) are report-only; sole exception: a mutation-probe-convicted test finding.

## Findings

- Every finding carries **ACCEPT / FIX / DEFER** (DEFER names what would make it now) and a
  **catch-stage label** — the stage that SHOULD have caught it (plan · beadify · flight ·
  implement · close · review) — **even when the fix lands in-batch**: auto-applied
  Critical/High findings write their catch-stage record — no work bead, the fix landed; **no VERDICT record** for an auto-fixed Critical/High fails the run's own checklist.
- **Severity orders the report; only a named `impact:` makes a bead**
  (`bead-create-contract.md` § Required axes). Else DEFER with a reason. Shipped defect →
  `-t bug`; mutation-probe-convicted test → `-t task`; unverified → `-t investigation`;
  labels `origin:ac-review,impact:<class>,review-finding,unrefined`, `discovered-from: <bead>`,
  epic parent, `post-merge` (`bead-conventions.md`). FIX → bead or `ac-polish code` — never
  in-place, never auto-fixed here. **Conductor confirm:** dedupe · confirm · file · record
  `proposed-by:`/`confirmed-by:`; consumes workers' **PROPOSED-BEAD** blocks and reviewers'
  findings. Forks: one decision bead per distinct fork, re-verified against HEAD before
  filing (`human-gate-template.md` § Before filing) — never per finding. A reasoned
  **"checked, no finding"** per dimension is a deliverable; silence is not coverage.

## Not this skill

Standing code quality between batches is `ac-hygiene`; doctrine-delta over `skills/` prose is
lint's; the stage map is `ac-pipeline/references/stage-table.md` (Review row).
