---
skill: ac-pipeline
created: 2026-08-27
last_pass: 2026-08-30
entries: 12
---

# ac-pipeline — friction log

<!-- The pipeline FAMILY ledger: process observations exhaust here, never to the board
     (Invariant 6). Sensor log, not a work-surface; never loaded with SKILL.md.
     Schema: skill-builder/references/friction-capture.md. Two family-only fields extend it,
     and lint Check 22 (scripts/ac-ledger-integrity.sh) enforces both directions:
       control:         the pipeline control that treats this friction — `I<n>` for an
                        Invariant, `C-<slug>` for a Calibration, or the explicit
                        `untreated` when the pipeline has no control for it yet.
       control_landed:  the date that control landed. A `last_seen` AFTER it is a FAILED
                        CONTROL — the friction kept biting after its fix shipped, which is
                        the recurrence-26 class the old ledgers never surfaced.
      SEED: these ids were MINTED IN THE ac-* LEDGERS and are inherited, id and all — the
      pipeline controls were written against them, so a foreign id here is legal input, not
      drift. Their metrics are copied from the source ledger, cited as the receipt.
      PROVENANCE: this is the former ac2-pipeline family ledger, moved at the ac2→ac
      pipeline rename. Entry bodies are verbatim history — `skills:` and `stage:` lines
      keep the ac2- tokens they were written with. The OLD ac-pipeline friction log (the
      legacy architecture lane's) retired with that lane at the same merge; git history
      preserves it, and its cross-cutting pointer entries' primaries live in
      _archive/skills/ac-loop/FRICTIONS.md. -->

## filed-beads-carry-drifted-anchors-and-false-premises
- skills: [ac2-pipeline]
- impact: M
- frequency: every-run
- perceptibility: silent
- recurrence: 5
- related: [heavy-review-does-not-mean-converged]
- first_seen: 2026-07-22
- last_seen: 2026-08-20
- stage: ac-bead-refine
- status: open
- receipt: _archive/skills/ac-bead-refine/FRICTIONS.md (source ledger, recurrence 5; archived at the Phase-4 cutover 2026-08-28)
- control: I1
- control_landed: 2026-08-27
- proposed_fix: stop storing tree-state in the bead; verify at claim instead.
- narrative: beads carried file:line anchors and premises that had decayed by the time the
  work started — the measured 100% base rate that ac2 answers by moving verification to the
  fresh moment.

## heavy-review-does-not-mean-converged
- skills: [ac2-pipeline]
- impact: M
- frequency: occasional
- perceptibility: misleading
- recurrence: 3
- related: [filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-07-29
- last_seen: 2026-08-04
- stage: ac-bead-refine
- status: open
- receipt: _archive/skills/ac-bead-refine/FRICTIONS.md (source ledger, recurrence 3; archived at the Phase-4 cutover 2026-08-28)
- control: I4
- control_landed: 2026-08-27
- proposed_fix: run a checklist to fixpoint instead of counting reviewer rounds.
- narrative: rounds of review were read as convergence; the round count rose while the
  findings kept changing, so depth was being bought without a stopping rule.

## br-d-body-is-shell-expanded
- skills: [ac2-pipeline]
- impact: L
- frequency: frequent
- perceptibility: silent
- recurrence: 4
- related: []
- first_seen: 2026-08-04
- last_seen: 2026-08-25
- stage: beads-standards
- status: open
- receipt: skills/beads-standards/FRICTIONS.md (source ledger, recurrence 4)
- control: C-receipt-formats
- control_landed: 2026-08-27
- proposed_fix: bodies through a file; keep bead prose dcg-safe.
- narrative: `br create -d "$(cat file)"` routes the body through the shell, so prose with
  substitutions or unbalanced quoting was silently truncated or refused.

## agent-identity-env-lost-between-tool-calls
- skills: [ac2-pipeline]
- impact: L
- frequency: frequent
- perceptibility: silent
- recurrence: 5
- related: []
- first_seen: 2026-07-30
- last_seen: 2026-08-26
- stage: ac-loop-swarm
- status: open
- receipt: _archive/skills/ac-loop-swarm/FRICTIONS.md (source ledger, recurrence 5; archived at the Phase-4 cutover 2026-08-28)
- control: C-coordinator
- control_landed: 2026-08-27
- proposed_fix: one live-session identity signs both the reservation and the commit; never
  the static env fallback.
- narrative: a static `AGENT_NAME` fallback shadowed the session identity, so the guard
  compared a reservation against the wrong name and rejected the worker's OWN reservation.

## low-severity-findings-each-get-their-own-bead
- skills: [ac2-pipeline]
- impact: L
- frequency: every-run
- perceptibility: misleading
- recurrence: 1
- related: []
- first_seen: 2026-07-30
- last_seen: 2026-07-30
- stage: ac-review
- status: open
- receipt: skills/ac-review/FRICTIONS.md (source ledger; 1 of 102 Lows was ever fixed)
- control: I6
- control_landed: 2026-08-27
- proposed_fix: Lows stay in the report; only externally-verdicted work reaches the board.
- narrative: every Low finding became a bead, inflating the board with work nobody
  intended to do — a count that only rises trains the reader to ignore the lane.

## upstream-defect-reports-have-no-owner-or-cadence
- skills: [ac2-pipeline]
- impact: L
- frequency: occasional
- perceptibility: silent
- recurrence: 2
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-08-21
- stage: ac-pipeline
- status: open
- receipt: skills/ac-pipeline/FRICTIONS.md (source ledger, recurrence 2)
- control: untreated
- proposed_fix: name an owner and a cadence for defects filed against upstream tools.
- narrative: defects found in tools we do not own were written down and then belonged to
  nobody. ac2 has no control for this yet — declared untreated rather than papered over
  with a control that does not exist.

## refine-corrections-land-in-the-beads-and-never-reach-the-plan
- skills: [ac2-pipeline, ac2-polish, ac2-beadify]
- impact: M
- frequency: occasional
- perceptibility: misleading
- recurrence: 2
- related: [heavy-review-does-not-mean-converged]
- first_seen: 2026-08-27
- last_seen: 2026-08-27
- stage: ac2-polish
- status: open
- receipt: _archive/skills/ac2-pipeline/dogfood-receipts.md (dogfood #1, round 2, findings 1 and 2)
- control: untreated
- proposed_fix: name the artifact a refine correction must be swept back into, and check it.
- narrative: caught TWICE in one run. (1) refine rounds 3-4 found that Phase 1's stated order
  turns lint red — the constitution cannot be written before the Check-14 enabler — and fixed
  it by splitting ac-g2v4 out into the BEAD graph, while the plan text still reads "the
  constitution, written first". (2) the plan's frontmatter records the ac-on0y precursors as
  closed and assumption 1 as PROBED-and-HOLDS, while its body still carries them as live
  assumptions whose detection rules ("if .2 slips, Phase 2 waits") can no longer fire. Both
  are the same hole: a correction applied to one artifact and never swept to its sibling —
  the class round 4 already found WITHIN the bead set, recurring across the plan/bead seam.
  Untreated: tenet 7 retires the plan, which makes divergence harmless AT retirement but not
  while the plan is still the authority ac2-beadify compiles from.

## cutover-slate-archives-a-gate-the-new-pipeline-still-depends-on
- skills: [ac2-pipeline]
- impact: L
- frequency: rare
- perceptibility: silent
- recurrence: 1
- related: []
- first_seen: 2026-08-27
- last_seen: 2026-08-27
- stage: ac2-polish
- status: open
- receipt: _archive/skills/ac2-pipeline/dogfood-receipts.md (dogfood #1, round 2, finding 3)
- control: untreated
- proposed_fix: before the slate commit, enumerate every executable a surviving skill still
  calls and assert it is not inside the archive set.
- narrative: Phase 4 moves "every absorbed ac-* skill" to _archive/skills/, and ac-bead-refine
  is named in ac2-polish's Absorbs column — but stamp-refined.sh, which the plan itself
  designates the SOLE SANCTIONED WRITER of `refined`, moved to skills/_tools/ in cutover prep
  (its origin skills/ac2-polish/ archived 2026-08-28),
  and ac2's own batch-boundary eligibility filter still requires `refined`. The slate
  enumerates other cutover relocations and omits this one; the plan's script-home rule would
  put it in skills/_tools/. Archiving a skill silently archives the executables inside it,
  and nothing in the cutover checks what still calls them.

## an-empty-artifact-diff-is-not-an-empty-finding-set
- skills: [ac2-polish]
- impact: M
- frequency: occasional
- perceptibility: misleading
- recurrence: 1
- related: [refine-corrections-land-in-the-beads-and-never-reach-the-plan]
- first_seen: 2026-08-27
- last_seen: 2026-08-27
- stage: ac2-polish
- status: open
- receipt: _archive/skills/ac2-pipeline/dogfood-receipts.md (dogfood #1, the NO STAMP WAS TAKEN section)
- control: untreated
- proposed_fix: make polish-fixpoint.sh take the round's finding COUNT as a required input and
  refuse to stamp a diff-empty round that reported findings.
- narrative: found by the engine's own first dogfood run. polish-fixpoint.sh proves a fixpoint
  from the ARTIFACT digest alone, which is sound only while every finding is dispositioned INTO
  the artifact. Dogfood #1 broke that assumption honestly: three real findings were routed to
  this ledger rather than to a plan about to be retired, leaving the digest byte-identical
  across both rounds — so the engine would have reported STAMPED over three unfixed defects.
  The run refused the stamp by hand, which is precisely the manual discipline a gate is
  supposed to replace. Caught at the first opportunity a gate had to be wrong, which is the
  cheapest place to catch it.

## freshly-authored-acs-are-green-at-authoring-and-the-author-cannot-see-it
- skills: [ac2-beadify, ac2-polish]
- impact: L
- frequency: every-run
- perceptibility: silent
- recurrence: 1
- related: [heavy-review-does-not-mean-converged]
- first_seen: 2026-08-27
- last_seen: 2026-08-27
- stage: ac2-beadify
- status: open
- receipt: bead ac-7f8s, dogfood #2 compile receipt (rounds 1-5: 10, 5, 3, 1, 0 findings)
- control: untreated
- proposed_fix: have ac2-beadify EXECUTE each authored probe at compile time and refuse any
  that exits 0 before the work exists — the same shape as the no-probe-no-bead refusal.
- narrative: dogfood #2 compiled 8 beads whose ACs all named runnable probes, so the
  no-probe-no-bead refusal passed them. Five rounds of fresh readers then found 19 real
  defects, and the dominant class was ACs ALREADY GREEN AT AUTHORING — probes that exit 0
  today and therefore assert nothing (one bead carried four in a row). The author could not
  see it: a probe you just wrote looks right, and running it is a different act from writing
  it. Two of the 19 were defects introduced by the author's OWN fix in the previous round and
  caught only by the next fresh reader, which is the bound earning its keep rather than
  ceremony. ac2-beadify checks that a probe EXISTS and is RUNNABLE; nothing checks that it is
  RED at authoring, which is the cheap mechanical half of what five reader rounds paid for.

## FRICTION: derive ROOT from the git toplevel, never from BASH_SOURCE level-counting
- domain: ac2-implement
- severity: high
- control: untreated
- proposed_fix: set ROOT via `git rev-parse --show-toplevel` from the invoking cwd; fall back to
  `pwd -P` only when git fails. Apply to close-gate.sh and flight-check.sh alike.
- narrative: do not count `../..` levels off BASH_SOURCE. A skill reached through a symlink
  (`<repo>/.claude/skills/<name> -> <registry>/skills/<name>`) resolves `dirname/../../..` to a
  directory INSIDE the repo's `.claude`, not the repo root. Every file-reading probe then fails
  on the wrong cwd, and the gate reports the worker's diff as the cause. Invoke with an explicit
  `--root` until the script is fixed. coordinator.sh shares the class AND hardcodes
  `$ROOT/skills/ac-implement/scripts/swarm-commit.sh` (line ~116) — a registry-relative path
  that does not exist in app repos where the registry is symlinked under `.claude/skills/` —
  so the ledger flush succeeds and the commit leg then refuses LEDGER-WRITE. Fix both together:
  derive ROOT from `git rev-parse --show-toplevel` and resolve sibling scripts off the script's
  own BASH_SOURCE directory, never off ROOT.

## FRICTION: flight-check CONSUMES leg reads a CLOSED blocker as "not on the board"
- domain: ac2-implement
- severity: medium
- control: untreated
- proposed_fix: the CONSUMES resolution should treat `status=closed` as the SATISFIED state
  (a consumed premise is fulfilled by its blocker closing, not voided by it); re-derive the
  check off `br show <id>` exit status, not board membership.
- narrative: bd-ufg84 `## Consumes` names bd-pt46x; bd-pt46x closed the same session
  (verified `br show bd-pt46x` → status closed, present in issues.jsonl), yet flight-check
  emitted `PREMISE-FAILED: CONSUMES — blocker 'bd-pt46x' is not on the board` and the worker
  lost the bead to the routing. A satisfied consume is indistinguishable from a dangling one,
  so the gate converts the pipeline's own success (a blocker landing) into a refusal.

## refined-beads-reach-the-worker-pool-with-zero-probe-lines-and-burn-claim-cycles
- skills: [ac-implement, ac-polish, ac-beadify]
- impact: M
- frequency: occasional
- perceptibility: loud
- recurrence: 1
- related: [freshly-authored-acs-are-green-at-authoring-and-the-author-cannot-see-it]
- first_seen: 2026-08-30
- last_seen: 2026-08-30
- stage: ac-implement
- status: open
- receipt: RUN 2026-08-30 worker log — bd-f4ljn, bd-n6f38, bd-12ef4 each claimed, flight-checked (exit 2 NOT-GATED), commented, unclaimed and burned before an actionable bead was reached
- control: I9
- control_landed: 2026-08-31
- proposed_fix: refuse to stamp `refined` on a bead whose description carries no `Probe:` line (the floor flight-check enforces at claim), and strip a stale stamp on content refusal rather than leaving it to look ready — shipped as stamp-refined.sh's downgrade leg (9c9d5c5).
- narrative: three of the first four ready `refined` beads named no `Probe:` lines at all. The
  refusal downstream was correct — a bead with no probe cannot earn a RED — but it surfaced one
  stage too late and three stages too expensively: claim, flight-check, comment, unclaim, burn,
  per bead. Root cause was deeper than the proposed fix: the beads were stamped under the legacy
  dialect (f9fc04e9, 08-28) the day BEFORE the probe floor existed (ac53c1c, 08-29), and
  re-polish passed them via element4's prose-Declared-RED shape while never re-stamping. A
  stamp was being trusted long after the content it certified had stopped meeting the bar.
  TREATED 2026-08-31 (9c9d5c5): stamp-refined.sh now STRIPS a stale `refined` on content
  refusal, and every polish writeback re-gates the epic's implementable beads through the sole
  writer. One-time sweep the same day: bd-f4ljn, bd-n6f38, bd-12ef4 (BCA) and ac-gcj.11 (this
  board) downgraded to `unrefined`. This entry was first written in a foreign dialect
  (`## FRICTION:` heading, `domain:`/`severity:` fields, a paragraph in `control:`) that the
  ledger parser could not read, and its unparseable control was attributed to the entry
  above it — rewritten to the canonical schema 2026-09-02. Whatever appended the original
  will do so again; it has not been found.
