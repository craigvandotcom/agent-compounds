---
skill: skill-builder
created: 2026-08-05
last_pass: 2026-09-06
entries: 3
---

# skill-builder — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## removal-list-elides-spans-and-hides-live-rules
- skills: [skill-builder]
- impact: H
- frequency: frequent
- recurrence: 1
- related: [change-proposal-asserts-a-gap-the-text-already-closes]
- first_seen: 2026-08-05
- last_seen: 2026-08-05
- stage: hygiene-pass
- status: open
- proposed_fix: make the removal-list FORMAT a contract in `workflows/hygiene-pass.md` § A2, next to the existing CORE/EXTRACT/CUT ledger — (a) every CUT quotes the FULL span verbatim, never an ellipsis and never a line number, because a concurrent writer invalidates line anchors mid-run; (b) the executor's prompt carries the standing instruction "read the full span first and stop if it contains anything operational"; (c) three verdicts, DELETE / MOVE / KEEP, since "extract and polish" is two operations under one name; (d) report GROSS deletions, not net. Full discipline is the global memory rule `a-removal-list-must-be-mechanically-executable` — cite it rather than restating it.
- narrative: across a 9-file sweep of always-loaded conductor spines, three CUT items were written with ellipsized middles. All three elisions hid load-bearing text: one would have deleted a live rule from ac-implement, and one was caught only because the executor opened the full span and refused — that item was a bolded normative guarantee in ac-land about it being the guaranteed exit step. The refusal was not luck: it happened after the executor's instruction gained an explicit "read the full span first and stop if it contains anything operational" clause, and the next agent stopped correctly. Separately a concurrent writer shifted every line in one target file mid-run, which is what makes quoted excerpts load-bearing rather than stylistic. The cost is asymmetric and that is the whole argument for the format being a contract: an over-quoted list costs reading time, an elided one deletes doctrine silently and the loss is only discoverable when a future run behaves differently for no visible reason. Also observed and worth pricing into estimates: deleting inside a wrapped paragraph is a PARAGRAPH-level edit, not a line cut, and every executor independently reported re-wrapping as the real cost of the pass.

## sweep-script-skips-unparsed-shape-silently
- skills: [skill-builder]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [removal-list-elides-spans-and-hides-live-rules]
- first_seen: 2026-08-05
- last_seen: 2026-08-05
- stage: hygiene-pass
- status: open
- proposed_fix: state in `workflows/hygiene-pass.md` § B (batch sweep) that any script used to sweep the registry must report every input it could not parse, and must print the count it examined alongside its result — a sweep that says "70 removed" without saying "of how many, and 3 unparsed" is not a measurement. The cheap enforcement is a residual re-count after the sweep: run the detector again and require zero, rather than trusting the sweep's own tally.
- narrative: a marker-sweep script written for the registry silently skipped a comment shape its pattern could not match, and reported success. It was caught only because the operator independently re-counted the residual markers afterwards — nothing in the script's own output distinguished "70 markers removed, all of them" from "70 removed, 3 shapes never seen". Zero durable damage this run, and that is precisely why it is logged: the script's output was indistinguishable from a complete sweep, so the same script re-run on a larger tree would under-report by an unknown amount with no signal. Same root as the org-wide rule `every-gate-needs-a-runner-not-a-spec` § The chain has three links (a scan that meets a shape it cannot handle must say so); logged here because skill-builder OWNS the batch-sweep workflow that keeps producing these scripts, and each hygiene pass writes a new one from scratch.
  Related targeting lesson from the same programme, worth carrying into § B1's ranking step: a keyword regex is the wrong instrument for this sweep in the first place. A marker regex predicted ~50 hits across the loop-family skills; the manual passes found roughly three times that, because the largest classes carry NO keyword — migration-provenance blocks, justification prose arguing that a rule is correct, and "considered and rejected" design records. A regex-only pass strips the visible markers and leaves the doctrine that generates them, which is the worst outcome available: it looks done.

## change-proposal-asserts-a-gap-the-text-already-closes
- skills: [skill-builder, ac-review, ac-human-session]
- impact: M
- frequency: frequent
- recurrence: 2
- related: [removal-list-elides-spans-and-hides-live-rules]
- first_seen: 2026-08-05
- last_seen: 2026-08-18
- stage: hygiene-pass
- status: open
- proposed_fix: require every proposed change — doctrine edit, review finding, or filed defect proposing a safeguard — to QUOTE the current text or grep the target for the mechanism it claims is missing, in the proposal itself. A proposal that cannot quote the sentence it is fixing has not read it, and the quote is a one-grep cost that makes the whole class impossible. Add it to `workflows/hygiene-pass.md` § A2 alongside the removal-list format, since both are the same contract — a proposal is executable only if it names the exact text it acts on.
- narrative: three separate proposals in one hygiene programme named a gap that the target text already closed: a proposal to gate a workflow that was already gated (two of its three tiers create beads and only the third is autonomous), a proposal to rescope a rule that was already correctly scoped inside its own text, and a proposal to rescope a citation rule that already carried the qualifier being asked for. Each cost a review cycle to refute. The root is structural rather than careless: a sweep operator holds a mental model of the doctrine assembled over many files and proposes against the model, not the file, and the model is exactly what a long pass degrades. Quoting the current text is the only step that forces the file to be reopened at the moment of proposing. Cross-listed to ac-review because a review finding that asserts a missing rule has the identical shape and the identical fix. Recurred in ac-human-session: a P1 bead was filed proposing a detect-and-refuse guard for a CI workflow that already carried that exact guard in the same file, and in the same session an improvement was proposed to generalise a tidy rule that had already shipped. Same root outside doctrine text — the proposer reasons from a model of the system rather than reopening the file — so the fix generalises from "quote the text" to "quote the text or grep the target for the mechanism".
