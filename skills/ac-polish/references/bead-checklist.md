# bead-checklist — the question set ac-polish runs over a bead set

The loop that runs this (fresh reader per round, severity gating, fixpoint at zero changes,
per-epic not per-bead) belongs to `ac-polish/SKILL.md`. This file is only the questions.
**Routine bound-exhaustion indicts THIS FILE, not the beads.**

Grade against the schema — `ac-beadify/references/bead-schema.md` — and cite, don't restate:
bead taxonomy, status/priority, close reasons and labels are `beads-standards`
(`reference/bead-conventions.md`); the test-tier slugs are the schema's own
(`bead-schema.md` § Test-tier slugs); commit and run discipline are `ac-pipeline/references/`.

**SEVERITY GATE for a bead set — correctness · contradiction · unimplementability.** These are
the only reportable classes. Style, preference and wording are not findings.

A question you cannot answer YES with evidence is a **DECLINED** item, not a finding — unless
the gap is itself a correctness, contradiction or unimplementability defect. Declining honestly
is the reader doing its job; reaching for a finding to justify the round is not.
"Probably", "looks fine" and "the author presumably checked" are findings.

## 1. sizing

- Is this bead ONE focused worker pass — a single claim, one coherent change, one close?
- Measured anchor: 5,500 plan lines → 347 beads ≈ **16 plan lines per bead**. A bead
  carrying far more than that is asserting it is unusually simple; is it?
- Does implementing it require heavy in-bead cognition — deciding an approach, weighing
  options, discovering the surface? That is a **SPLIT SIGNAL**, not a hard bead.

## 2. probe-presence

- Settle WHICH SHAPE APPLIES before grading a single AC. `skills/_tools/element4-check.sh`
  decides it: `## Declared RED` present -> the legacy Declared-RED shape decides ALONE and
  per-AC probes are not required; absent -> the ac2 schema applies.
- Under the ac2 shape: does EVERY AC name an executable probe in the schema's form, with a tier?
- Under the ac-* shape: does every AC name an observable of ANY kind — a command, an exit, a
  named assertion? An AC with no observable at all is a finding; an informally worded one is not.
- Grading a bead against the other shape's rule manufactures findings it cannot act on. A
  finding against a bead `element4-check.sh` PASSes is a finding against this file.
- Extract them mechanically. Does each command run — `sh -c` reaches completion, no syntax
  error, no *command not found* for its leading word? A probe you did not execute is a
  probe nobody ran.
- Is any "probe" a prose fragment (`wc -l`, "diff it", "check the output")? No probe, no bead.
- An `investigation` is probe-exempt at capture, not at the stamp or the close. An agent can
  answer it? Give it an exit probe — the findings file it writes, the fix bead it spawns —
  class (c). It needs a human ruling? List it in DECLINED as `MISFILED: human fork — <why>`;
  the conductor retypes it, never the reader.

## 3. consumer-verification

- A `## Delivers` bullet naming a GIT-TRACKED, REFERENCED path with no `touchers:` line is
  class (c) — the `refined` stamp cannot survive `stamp-refined.sh`'s touchers leg, so the
  bead is unimplementable as a refined bead. Add the line; never decline it as a format gap.
- Was the touched surface's consumer set **grep-derived**, or hand-listed from memory?
  Hand-listed scopes carried a measured **16.2% repair rate** from consumers nobody found.
- Name the grep that derived it. Does every consumer it returns appear in the bead, or is
  its absence stated as deliberate? Write it as the contract's line beneath the `## Delivers`
  bullet — ``touchers: `<command>` → <N> · owned by: … | out-of-scope: …`` — because
  `stamp-refined.sh` re-runs that command and refuses a missing or stale one
  (beads-standards `bead-create-contract.md` § Touchers). Command shapes per question:
  `ac-polish/references/seams-checklist.md`.
- Evaluate every bead against the prod-write predicate in
  `skills/beads-standards/reference/bead-conventions.md` § The prod-write gate predicate; cite
  that section, do not restate it. When the predicate does not apply, write the exact line
  `prod-write: none — <reason>` with a non-empty reason. A signal-bearing bead with neither
  that line nor the `sensitive-prod` + DECISION `blocks` gate pair is class (c):
  `stamp-refined.sh` refuses it. The reader cannot write a label or an edge, so when the
  predicate does apply, list it in DECLINED as `PROD-WRITE: <id> — <clause>` for the run to
  wire (or hold) before hand-off.
- For the object this bead reshapes: which bead in the epic owns each lifecycle stage —
  create · store · read · update · delete · cleanup? A stage no bead owns and the plan does
  not name out-of-scope is a HOLE, and grep cannot find it; only this question does.

## 4. cross-AC consistency

- Can all ACs be satisfied simultaneously, or does one demand what another forbids?
- Does each AC agree with `## Intent`'s stated boundary? Intent-boundary ↔ AC is the
  surviving analog of the old Territory check — an AC outside the boundary is a defect in
  one of the two, and the bead must say which.
- Do `## Delivers` and the ACs describe the same artifacts, by the same names?

## 5. freshness write-path

- Does the bead introduce or rely on any field that goes STALE (a count, a date, a
  last-run, a status mirror)?
- If so: what WRITES it, on what cadence, and what fails loudly when the write stops?
  A freshness field with no write-path and no staleness alarm is decoration.

## 6. falsifiability

- Is there an AC an empty diff already satisfies? Is any AC ALREADY GREEN at authoring?
  Run it now and record the exit — a green probe at authoring proves the bead asserts
  nothing.
- For each AC, state the observable that CHANGES (an exit code, a count, a message) — not
  the title of the thing that checks it.

## 7. Consumes-edge parity

- Does every `## Consumes` line have a real dependency edge, and every edge a `## Consumes`
  line? Check BOTH directions — a fix applied to one bead and not swept to its sibling is
  this pipeline's most repeated repair.
- Is the direction right (`<blocked> depends-on <blocker>`) and the graph acyclic
  (`br dep cycles`)? Reversed edges are silent.
- Does every cited artifact appear verbatim in the blocker's `## Delivers`?
- Is any epic-child relation (either direction) wired as `blocks` instead of parent-child?
  Containment alone sequences the epic's terminal pick — no other edge is needed.

## 8. seam coverage

- Do the beads cover the whole plan, or is there a seam between two of them that nobody
  owns — a caller left wired to the old shape, a trigger never repointed, a write-path that
  ends between the two?
- For each pair of beads that touch the same surface: which one lands first, and is the tree
  green in that order? A bead that turns lint or CI red before its enabling bead lands is a
  sequencing defect, not a risk to accept. Run this same question over
  `skills/_tools/planned-layer.sh scan <epic>` as well as the epic's own pairs — a bead here
  can share a surface with an open bead or live plan ACROSS EPICS, not only with a sibling
  inside the epic under polish; an undeclared cross-epic pair is the same finding.
- Are there orphans — beads no phase asked for, or plan work no bead claims?

## 9. durable-content-only

- Does any bead carry content that decays before it is claimed — line numbers, a pasted
  count, a "currently X" claim, a tree state? Move it to the probe or delete it.
- Where a count SURVIVES because the bead argues it must, re-derive it with the bead's own
  stated method and report the number you got. Never grade a stated number by eye.
- State the population you counted over — open vs all, which labels, description-only vs
  description + comments. That choice moves the answer more often than the arithmetic does.
- Does the bead restate canon that already exists in `beads-standards` or
  `ac-pipeline/references/`? Replace it with the pointer.

## 10. epic done-check (only when no child is open)

- An epic with no open children has nothing left to polish — its beads are records. Run
  the epic's OWN `Probe:` lines at HEAD and report each exit.
- Every red probe is a finding with a disposition, never DECLINED: name what blocks the
  close — a renamed path the probe cites (refine the probe), a sibling that never landed
  its piece (a bead), a baseline failure outside the epic (name the owner). Never "drift".
- Does `## Delivers` name a real path, present at HEAD? A child bead id or prose is not one.
- Does the epic carry the review receipt its close path requires? A missing receipt is the
  first blocker, named first.

## 11. plan trace

Grade the quote the schema requires (`bead-schema.md`: a child AC quotes its plan
"Done when:" verbatim and adds only the probe; the epic's AC is the silver bullet
verbatim). A NO below is a correctness finding — never DECLINED.

- Does every child AC quote a plan "Done when:" verbatim, and add only the probe?
  An AC that quotes no plan "Done when:" did not carry the approved line.
- Does every AC state a behaviour, never a test's name? "a test named X passes" is not an AC.
- A deliverable split across several beads: does each child quote the parent line and
  add its own slice's values, and do the children together cover the parent line?
  A split whose children leave part of the parent line uncovered is a correctness finding.
