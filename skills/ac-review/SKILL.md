---
name: ac-review
description: 'The hand-run independent review: `ac-review <range>` over a range the operator names — nothing triggers it and no batch runs it. Three lenses (correctness against the plan and the bead ACs, test-quality, and one risk lens the diff chooses) report against one bar: a demonstrated failure in ordinary operation, or a violated acceptance criterion, with a reproducing command. Every finding routes to Defect (a bead), Hardening (one report line, never a bead) or Nothing; a fresh verifier re-runs each Critical/High before any fix. Reviewers run the validator stance, read-only on the shared tree; reports land in `.claude/reviews/`. Triggers: ''/ac-review'', ''review the batch'', ''review this range''.'
---

# ac-review — the hand-run review

**One entry point: `ac-review <range>`.** A range the operator names, and nothing else.
Nothing triggers a review — no batch boundary, no epic close, no scheduled job. Review is
a deliberate tool, run when the operator asks for one.

## Who reviews

- **A different stance from the workers — the validator, tier-resolved per harness.**
  (L2 — survives tier convergence) The same weights re-reading their own diff are not
  independent eyes: they share the diff's blind spot; convergence never retires this rule.
- **READ-ONLY on the shared tree.** No write/mutation tooling, no "just fixing it while I'm
  here" — a reviewer that can edit is a second author (H-impact incident). Sole carve-out:
  sabotage probes in a **disposable worktree**; the result is a finding, never a diff.
- **Depth by risk, not habit.** A range touching a gate, an auth path, a migration or a
  destructive operation gets all three lenses; prose and config may take correctness alone.

## The contract

1. **Scope.** The named range, diff pathspec `:(exclude).beads/`.
2. **The lenses.** One reviewer per lens in `references/review-dimensions.md` —
   correctness, test-quality, and the one risk lens the diff chooses (security or
   contracts) — each prompt built from `references/reviewer-prompt-template.md`, all in a
   single message (parallel). A reviewer that dies is re-spawned ONCE.
3. **The verify round.** Before any fix, one fresh verifier per Critical/High finding runs
   each probe and tries to refute it (`reviewer-prompt-template.md` § The verify round).
   No Critical/High → no verify round.
4. **Report and verdict.** `references/report-template.md`, written to `.claude/reviews/`.
   `VERDICT: APPROVED` when every lens reported and every finding is dispositioned; else
   `VERDICT: NEEDS_DECISION`. The conductor writes the verdict, never the reviewer.

## What the review judges

- **The one bar** (`references/review-dimensions.md`): a demonstrated failure in ordinary
  operation, or a violated acceptance criterion, with a reproducing command. "Could be
  bypassed" counts only against a real adversary — user input, auth, external data, PII,
  money — never our own worker, and the probe may not set up state a cooperative worker or
  a real user would not produce.
- Two things a green suite cannot see: **fixture-shape validity** — could each test's
  fixtures EXIST in production? A test over an impossible input asserts nothing — and
  **causal sufficiency** — for every bead the range closed, does THIS diff produce that
  GREEN? (The token is not the thing; a probe may have flipped for another cause.)
- **Plan fidelity** — the correctness lens reads the plan's `## Vision` and `## Out of
  scope` and flags any diff in range that breaks them, with one mechanical probe: the net
  line change on the epic's named files after the plan's last deliverable commit.

## Findings

- **Three bins replace ACCEPT/FIX/DEFER.** **Defect** → a bead, and the `impact:` label
  carries its demonstration. **Hardening** → one line in the report, never a bead.
  **Nothing** → ACCEPT with one line saying what was checked.
- A confirmed defect becomes a bead whose acceptance-criterion probe IS the finding's
  reproducing command; its fix is checked by re-running that command, never by a second
  review. Fix order: delete > simplify > tighten an instruction > add code. A fix that adds
  a guard, mode or option asks the operator through the existing human-gate DECISION bead;
  a deleting fix does not ask.
- **Closed epics accept no child.** A late finding against a closed epic opens a follow-up
  epic — never a new child of the closed one, never a silent reopen. The follow-up carries
  its own `discovered-from:` trail back to the finding; the closed epic stays closed.
- **Severity orders the report; only a named `impact:` makes a bead**
  (`bead-create-contract.md` § Required axes). A shipped defect → `-t bug`;
  mutation-probe-convicted test → `-t task`; labels
  `origin:ac-review,impact:<class>,review-finding,unrefined`, plus a `Probe:` line carrying
  the reviewer's reproducing command. A confirmed defect is never re-reviewed.
- **Friction route.** Machinery that actually misbehaved or cost time in the run goes to
  the skill's `FRICTIONS.md`, deduplicated and recurrence-counted, and is ruled in the
  dream session. Imagined problems die in the report — never a bead.

## Not this skill

Standing code quality between reviews is `ac-hygiene`; doctrine-delta over `skills/` prose
is lint's; the stage map is `ac-pipeline/references/stage-table.md` (Housekeeping row).
