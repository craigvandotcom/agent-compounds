---
name: ac2-review
description: 'Independent post-batch code review for ac2 — reviewers run a different model from the workers, read-only on the shared tree, depth chosen by risk, findings reconciled by the consensus script. Triggers: "ac2 review", "review the ac2 batch". Invoked BY the ac2 batch boundary, not by a worker mid-bead. For the manual human-triggered panel use ac-review.'
---

# ac2-review — a batch in, an independent verdict out

## I/O Contract

|                  |                                                                              |
| ---------------- | ---------------------------------------------------------------------------- |
| **Input**        | A finished ac2 batch on the committed tree, plus its bead ids                 |
| **Output**       | One review report: findings with severity, verdict and catch-stage label      |
| **Artifacts**    | The report; beads for Medium-and-above findings only                          |
| **Verification** | The consensus script reconciles reviewers; a no-finding slot must be filled   |

Panel mechanics — dimensions, reviewer prompt, report shape — are `ac-review`'s, by pointer:
`skills/ac-review/scripts/consensus.py` and the reference set in `skills/ac-review/`. This
skill restates none of it. What it adds is the four constraints below, each a measured scar.

## Who reviews, and how deeply

**Reviewers run a DIFFERENT model from the workers.** That is the L2 core of this stage and it
SURVIVES tier convergence: even when a worker tier and a reviewer tier measure equally capable,
the same weights re-reading their own diff are not independent eyes — they share the blind spot
that produced the diff. Convergence retires the *cost* argument, never this rule.

Depth is chosen by RISK, not by habit: a batch touching a gate, an auth path, a migration or a
destructive operation gets the deep panel; a batch of prose and config gets one pass. Uniform
depth spends the budget where nothing was at stake and starves the batch where everything was.

## Read-only — and the one carve-out

**Reviewers are READ-ONLY on the shared tree.** No write tooling, no mutation tooling, no
"just fixing it while I'm here". This is not tidiness: reviewer write access caused an
H-impact incident, and a reviewer that can edit stops being a second pair of eyes and becomes
a second author.

**The carve-out, stated because the unqualified rule contradicts it:** destructive sabotage
probes — break the thing on purpose and prove the guard fires — DO need to write, and they run
inside a **disposable worktree**, never the shared tree. Spatial isolation earns its keep here
and nowhere else in ac2; the worktree is created for the probe, thrown away after it, and its
result travels back as a finding, never as a diff.

## Verdicts — and why DEFER exists

Every finding carries one of: **ACCEPT** (no change needed, with the reason) · **FIX** (change
required, severity attached) · **DEFER** (real, not now, with the reason and what would make it
now). DEFER is not softness. A binary accept/fix gate measured an ad hoc override — the
pressure to ship did not vanish when the third option was removed, it just stopped being
recorded. A named DEFER is auditable; an unnamed override is not.

## Fixture-shape validity is a named dimension

Judge whether each test's fixtures could EXIST in production, not merely whether the suite is
green. A 741-file suite passed while hiding three High findings behind impossible fixtures —
rows that no code path can produce, states the schema forbids. A test asserting over an
impossible input asserts nothing, and it is invisible to every green-suite signal there is.

## Causal sufficiency is a named dimension

**For every bead the batch closed, ask the one question a checksum cannot answer: does THIS
diff produce that GREEN?** Read the bead's ACs, its flight receipt's recorded RED, and the
diff. Two shapes fail it. **The token, not the thing** — most ac2 ACs are `grep -q '<string>'
<file>`, and writing the string satisfies the probe without building what the AC describes.
**The other cause** — the probe flipped, but something else in the tree flipped it: a sibling's
commit, an unrelated fix, an AC that was already green and nobody noticed.

This dimension moved here from `close-gate`'s HASH-LOCK leg, which tried to prove causality by
checksumming the test between RED and GREEN. A checksum proves a file did not change; it cannot
prove a change was SUFFICIENT. It was also structurally unsatisfiable for prose beads, whose
probe names the very file the bead edits, and its own remedy text told those beads to grow a
harness that re-runs a grep — the vacuous-AC shape this pipeline exists to kill. Judgement was
the wrong thing to mechanise. It belongs to a reader, on the committed tree, at a different
model from the one that wrote the diff.

A bead that fails this dimension is a **FIX** with catch-stage `close` — the close gate let it
through, and that is the leak worth counting.

## A reasoned no finding is a deliverable, not silence

Every dimension the panel ran gets a filled slot in the report — a finding, or an explicit
**"checked, no finding"** with the reason and what was looked at. Silence is indistinguishable
from not looking, and a report with gaps reads as coverage it never had.

## Findings — labels, and what becomes a bead

Every finding writes its **verdict** and its **catch-stage** label — the stage that SHOULD have
caught it (plan · beadify · flight · implement · close · review) — **even when the fix lands
in-batch**. The fix may be in-batch; the label never is. Catch-stage is the only signal that
says which gate is leaking, and a finding fixed silently deletes it.

**Medium and above become beads. Low findings stay in the report.** One of 102 Lows was ever
fixed: Low beads are not a backlog, they are a graveyard that makes the board unreadable.

## Out of scope

Fixing what it finds (that returns to `ac2-implement` as a bead) — and any write access to the
shared tree, the disposable worktree above being the sole, named exception.
