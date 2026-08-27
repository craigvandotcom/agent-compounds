---
skill: ac2-pipeline
created: 2026-08-27
last_pass: 2026-08-27
entries: 6
---

# ac2-pipeline — friction log

<!-- The ac2 FAMILY ledger: process observations exhaust here, never to the board
     (Invariant 6). Sensor log, not a work-surface; never loaded with SKILL.md.
     Schema: skill-builder/references/friction-capture.md. Two ac2-only fields extend it,
     and lint Check 22 (scripts/ac2-ledger-integrity.sh) enforces both directions:
       control:         the ac2 control that treats this friction — `I<n>` for an
                        Invariant, `C-<slug>` for a Calibration, or the explicit
                        `untreated` when ac2 has no control for it yet.
       control_landed:  the date that control landed. A `last_seen` AFTER it is a FAILED
                        CONTROL — the friction kept biting after its fix shipped, which is
                        the recurrence-26 class the old ledgers never surfaced.
     SEED: these ids were MINTED IN THE ac-* LEDGERS and are inherited, id and all — the
     ac2 controls were written against them, so a foreign id here is legal input, not
     drift. Their metrics are copied from the source ledger, cited as the receipt. -->

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
- receipt: skills/ac-bead-refine/FRICTIONS.md (source ledger, recurrence 5)
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
- receipt: skills/ac-bead-refine/FRICTIONS.md (source ledger, recurrence 3)
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
- receipt: skills/ac-loop-swarm/FRICTIONS.md (source ledger, recurrence 5)
- control: C-deferred-coordinator
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
