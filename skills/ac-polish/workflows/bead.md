# polish · bead mode

The loop is in `ac-polish/SKILL.md` and is the same in every mode. This file supplies only
what bead mode binds, and it is a MANDATORY load for a bead run.

## Bindings

| knob | bead mode |
| --- | --- |
| **TARGET** | the epic id |
| **ARTIFACT** | the epic plus its OPEN children, exported to one file by `scripts/bead-artifact.py export --ids <epic>,<open children>` — export runs `bead.py check` on each id; a REFUSED verdict still exports, as `CHECK:` lines (polish is the repair lane) — only NOT-GATED aborts. Never a closed bead: a closed description is the record of what shipped, and export REFUSES a closed id (see § Scope). Export ends with the seams sweep (§ Seams sweep at export) over every plan-less bead the `seams-missing` rule covers |
| **CHECKLIST** | `references/bead-checklist.md` |
| **VALIDATE** | `skills/_tools/stamp-refined.sh --check <description-file> --type <t> --labels <csv>` per bead (`<t>`/`<csv>` read off that bead's own artifact-block meta-header line) — the restamp gate's OWN read-only entry point: element4-check.sh plus every content leg `bead.py check` runs, in one call; it names on one line whichever board-only leg it cannot run without a live id, never silent. Either RED blocks the round from recording. ONE entry point for both readers, so a bead VALIDATE passes never gets downgraded at restamp for a content reason `--check` could have caught |
| **READERS** | ONE `coordinator` per round — it applies its own edits and must fix a VALIDATE RED itself, so it needs judgment tier AND the Edit tool; `references/reader-prompt.md` verbatim |
| **STAMP** | `polish-fixpoint.sh --mode bead` writes the `POLISH-FIXPOINT:` receipt comment to EVERY bead in the artifact, not only the epic — no hand fan-out |

## Scope — the epic and its OPEN children, nothing that is done

Read child status BEFORE scoping. The ids are the epic plus every child still open —
`RUST_LOG=error br list --json` excludes closed beads by default; keep the ids that start with
`<epic>.`. Say the count out loud before round 1: *"ac-xxxx: 3 open of 15 children"*. A
request for "all open beads" resolves to the epics that HAVE open children. An epic whose
children are all closed is not polished — it is done-checked (`bead-checklist.md` §
epic done-check): run its own probes, and each red one is a finding that blocks the
close, never a decline.
A bead with no epic is its own TARGET and a one-bead artifact; several open standalones may
share one artifact to share the round cost, and a closed one is refused like any other.
Measured 2026-09-15: "all open beads" run as "all open epics" rewrote 52 closed descriptions
and receipted 84 closed beads for nothing.

## Seams sweep at export — a plan-less bead owns no plan to carry its Seams

A bead descended from an approved plan inherits that plan's `## Seams`. A plan-less
task/feature/bug does not, so the sweep derives them. It runs once, at export, over every
exported bead the `seams-missing` rule covers: plan-less, type task/feature/bug, at least one
`## Delivers` path, and no `## Seams` section. It is part of the ARTIFACT, written into the
artifact block before round 1 — ac-polish keeps ONE round procedure, and the board is still
untouched until writeback.

1. **Derive, per Delivers path.** `skills/_tools/touchers.sh derive <path>` prints
   `<stem>\t<command>`, or `new` for an untracked path. `new` gets the row
   `<path> · new — no touchers` and no reader. Everything else gets a reader.
2. **One reader per object with a command**, sent `skills/ac-plan/references/plan-seams-reader.md`
   verbatim, spawned by this session in parallel (the same prompt `ac-plan` step 4 sends, not
   a second copy). `<DELIVERABLES>` is the bead's `## Delivers` plus its ACs. `<FILES>` is the
   command's output tagged SOURCE, plus the test globs `**/*<stem>*.test.*` and, when
   `factory.json` sets `journeys_dir`, that directory. The test globs are never empty, so
   `no-test-globs` cannot fire.
3. **Write `## Seams`** into the bead's artifact block from the reports: the SEAMS rows, the
   TESTS `must update` rows, and the OUT-OF-PLAN rows a fresh second reader confirmed
   (`plan-seams-reader.md` § Confirming an OUT-OF-PLAN claim). A path whose command finds no
   seam to record gets one line instead:
   `<path> · none — <command> lists <K> files, all covered`, where K is the number of files
   that command prints. The next round's reader re-derives K (`bead-checklist.md` § 3).

## Run PER-EPIC, never per-bead

One loop over the epic's open bead set. Per-bead is a ~20x cost difference for no measured
gain, and cross-bead defects — Consumes↔edge parity, duplicated Delivers, a contradiction
between two siblings — are invisible to a per-bead reader.

## The board is not the artifact

Export once, at the start. The loop edits the ARTIFACT; the board is not touched until the run
ends. A mid-run writeback changes what the next round's reader sees, and the round that follows
measures churn instead of defects.

Land it with `scripts/bead-artifact.py writeback --apply` AFTER the verdict, in one pass.
Every exported block carries `base:`, the digest of that bead's live title+body at export.
Writeback checks it FIRST and REFUSES the whole set, writing nothing, if any bead moved or
closed since — another session edited it. Re-export and re-run; never overwrite. (Measured
2026-09-15: a writeback landed bodies exported 90 minutes earlier over a refine made in
between.)
Writeback also wires every `## Consumes` line to its dependency edge — additive only, never a
removal — and reports on one `EDGES` line any edge that has no Consumes line.
The script refuses when `br` cannot resolve a board from the CWD, and never writes `refined`
or `unrefined` — those belong to `stamp-refined.sh` alone.

## `refined` is a separate gate, and it is not this loop's to grant

The receipt this loop writes is a PRECONDITION of `refined`, not a grant of it.
`skills/_tools/stamp-refined.sh` is the sole sanctioned writer: it runs `element4-check.sh`,
REFUSES any description carrying no executable `Probe:` line — a stamp that certifies nothing
a gate can execute is a labeling defect — and requires a conforming fixpoint receipt at
rounds >= 2 from EVERY origin, no family exemption.

The restamp is a MECHANISM, not a remembering exercise: `bead-artifact.py writeback --apply`
ends with a RESTAMP SWEEP that re-gates every implementable bead in the artifact through
`stamp-refined.sh`, SKIPPING a human-gate bead outright (it never carries `refined`). A
conforming bead is restamped under the current contract; a stale one (a pre-floor stamp, a
missing receipt) is stripped by the gate's downgrade leg and returns to the refine lane. Any
refusal inside the sweep exits the sweep non-zero — it is never silently swallowed. A
cannot-check result mutates nothing. Never grandfathered, mechanically.

Stamp `refined` only on beads that are implementable work. A `decision`-type bead is a human
fork and element 4 exempts it — a receipt records that it was polished; it does not make it
ready to implement. Leave those, and anything held, for the human.

Epics gate like children: the restamp sweep re-gates the epic through `stamp-refined.sh`
the same way. A probe-less epic sweeps back to refine — DOWNGRADED is the gate working,
reversible, never an error exit.

## Prod-write gate wiring — the predicate, evaluated at refine

The per-round reader evaluates every bead against beads-standards' prod-write predicate and
hands a positive verdict to this run as `PROD-WRITE: <id> — <clause>` in DECLINED. This workflow
never asks the reader to infer that verdict from a signal alone. Before hand-off, wire each tag's
`blocks` edge to a human-gate decision bead (create the decision bead when none exists) and its
`sensitive-prod` label — the board state is the predicate's trace, never the trigger. A tagged
bead whose gate edge cannot be wired is HELD for the human and is never stamped `refined`.

## Hand-off

Retype every `MISFILED: human fork` a reader declined to `decision` + `human-gate`, with its
memo (`beads-standards/reference/human-gate-template.md`), before handing off.

**Called from ac-beadify:** report `rounds-to-fixpoint` and return the verdict token to the caller — no `Next:` line. ac-beadify is the one that asks the human whether to start implement;
this workflow never asks it and never prints one.

**Run standalone:** report `rounds-to-fixpoint` with the verdict token, then stop: `Next: /ac-implement <epic>` — or name what still blocks it.

**Never invoke `ac-implement` from this hand-off**, in either branch — the stamp makes the
beads eligible, not the swarm authorized. The next call is the human's, or an "X then Y" the
human typed in this session (`ac-pipeline/references/stage-table.md`).
