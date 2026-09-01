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

## 3. consumer-verification

- Was the touched surface's consumer set **grep-derived**, or hand-listed from memory?
  Hand-listed scopes carried a measured **16.2% repair rate** from consumers nobody found.
- Name the grep that derived it. Does every consumer it returns appear in the bead, or is
  its absence stated as deliberate?

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
- Is any epic→child relation wired as `blocks` instead of parent-child?

## 8. seam coverage

- Do the beads cover the whole plan, or is there a seam between two of them that nobody
  owns — a caller left wired to the old shape, a trigger never repointed, a write-path that
  ends between the two?
- For each pair of beads that touch the same surface: which one lands first, and is the tree
  green in that order? A bead that turns lint or CI red before its enabling bead lands is a
  sequencing defect, not a risk to accept.
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
