# Phase-4 cutover slate — the enumerated moment

**Status: NOT SCHEDULED. This document is not an execution.** It is the item-by-item list a
human reads before deciding to run the Phase-4 hard cutover. Nothing here has been performed;
no skill has been moved, archived, deleted or rewritten by the bead that wrote this file.

The cutover is ONE atomic slate commit, human-gated, no operational coexistence. Refining the
contents below (dropping items, adding items, resolving the open questions) is the scheduler's
job, not this document's — this is the checked draft, not the approved plan.

Derivation: the archive set and the executable audit below are read off the working tree and
`_plans/2026-08-27-0211-ac2-pipeline.md` § Phases / the skill-inventory table, not from memory.
Where the tree and the plan disagree, the disagreement is recorded as an open question rather
than resolved by guess.

---

## 1. Baseline — the fixed reference

The before/after comparison is measured against `skills/ac2-pipeline/precutover-baseline.md`,
anchored to commit `5410d85` (defects by first-catch stage; external-verdict count 1/27;
unknown share 52/79). Every figure there re-derives from a command in that file.

**After the cutover, re-run those same commands against the post-cutover SHA.** Read the two
shares in the order that file names — external-verdict share first, `unknown` share second.
A drop in raw finding count is not evidence.

Do not re-derive the baseline at cutover time. A baseline measured after the change measures
nothing; that is why the cutover waits on the baseline and never the reverse.

---

## 2. The archive set — what moves to `_archive/skills/`

`git tag pre-ac2-cutover`, then `git mv` each of the following into `_archive/skills/`
(lint already excludes `_archive/`; `_archive/skills/` already holds `ac-loop`, `ac-loop-2`).

Derived from the plan's "Absorbs / replaces (at Phase-4 cutover)" column:

| # | Skill | Absorbed by |
|---|---|---|
| 1 | `ac-plan-init` | `ac2-plan` |
| 2 | `ac-plan-clean` | `ac2-polish` |
| 3 | `ac-plan-refine-internal` | `ac2-polish` |
| 4 | `ac-plan-refine-external` | `ac2-polish` |
| 5 | `ac-bead-refine` | `ac2-polish` |
| 6 | `ac-beadify` | `ac2-beadify` |
| 7 | `ac-loop-swarm` | `ac2-implement` |
| 8 | `ac-implement` | `ac2-implement` |
| 9 | `ac-batch-close` | `ac2-publish` |
| 10 | `ac-merge` | `ac2-publish` |
| 11 | `ac-publish` | `ac2-publish` |

**That is ELEVEN. `lint.sh` (the ac2 net-growth exception comment) states the seven ac2 skills
were written "before the twelve they absorb can be archived."** The twelfth is not determinable
from the tree — see Open Question A. It is left unnamed here deliberately.

Not in the archive set, from the same column: everything else under `skills/ac-*` — `ac-align`,
`ac-backlog`, `ac-bead-capture`, `ac-dashboard`, `ac-distribute`, `ac-human-session`,
`ac-hygiene`, `ac-idea-lab`, `ac-land`, `ac-plan-lab`, `ac-prove`, `ac-qa-browser`,
`ac-qa-device`, `ac-registry-audit`, `ac-site-polish`, `ac-tidy`, `ac-triage`, `ac-ui-polish`.

---

## 3. Executable audit — archiving a skill must not silently archive a live gate

Every executable that a SURVIVING skill, hook or lint check still calls, and whether it falls
inside the archive set. **This is the section the cutover exists to get right.**

| Executable | Home | In archive set? | Surviving callers |
|---|---|---|---|
| `stamp-refined.sh` | `ac-bead-refine/scripts/` | **YES** | `ac2-polish/SKILL.md:31` · `skills/_tools/polish-fixpoint.sh:138` · `beads-standards/reference/bead-conventions.md:104,109,300` · `hooks/hooks.json:55` |
| `element4-check.sh` | `ac-bead-refine/scripts/` | **YES** | invoked by `stamp-refined.sh`; cited `bead-conventions.md:109` |
| `close-evidence-check.sh` | `ac-pipeline/scripts/` | **UNKNOWN (Q-A)** | `ac2-implement/scripts/close-gate.sh:86` — its evidence core · `bead-conventions.md` |
| `consensus.py` | `ac-review/scripts/` | **UNKNOWN (Q-A)** | `ac2-review/SKILL.md:17-18` — panel mechanics by pointer |
| `beads-closed-gate.sh` | `ac-pipeline/scripts/` | **UNKNOWN (Q-A)** | `ac-tidy` · `ac-review` · `agent-mail/references/agent-identity.md` · `bead-conventions.md` |
| `validate-qa-run.sh` | `ac-pipeline/scripts/` | **UNKNOWN (Q-A)** | `ac-qa-browser` · `ac-qa-device` (both survive) |
| `claim-race-harness.sh` | `ac-pipeline/scripts/` | **UNKNOWN (Q-A)** | `bead-conventions.md` |
| `board-truth.sh` | `ac-pipeline/scripts/` | **UNKNOWN (Q-A)** | only `ac-pipeline/references/board-scan.md` (self) |
| `polish-fixpoint.sh` | `skills/_tools/` | no | `ac2-polish` · `ac2-pipeline` · `scripts/ac2-budget-check.sh` |
| `journey-stamp-check.sh` | `skills/_tools/` | no | `ac-dashboard` · `ac-human-session` · `ac-distribute` · `ac-pipeline` · (`ac-publish`, archived) |
| `friction-rollup.py` | `skill-builder/scripts/` | no | `ac-dashboard` · `ac-tidy` · `dream` · `scripts/ac2-ledger-integrity.sh` |
| `validate-skill.sh`, `init-skill.sh` | `skill-builder/scripts/` | no | `lint.sh` · `reflect` · `dream` |
| `close-gate.sh`, `flight-check.sh`, `swarm-commit.sh` | `ac2-implement/scripts/` | no | `ac2-implement` (self) |
| `ac2-budget-check.sh`, `ac2-ledger-integrity.sh`, `assurance-declarations-check.sh`, `harness-scheduling-check.sh`, `bead-template-lint.py`, `skill-diet-conservation.mjs`, `run-all-harnesses.sh` | repo `scripts/` | no | `lint.sh` · `hooks/` |

### 3a. THE BLOCKING RELOCATION — `stamp-refined.sh`

`skills/ac-bead-refine/scripts/stamp-refined.sh` is the **declared sole sanctioned writer of the
`refined` label** (`bead-conventions.md:109`), and the `refined` write is gated from INSIDE it
precisely so a caller cannot route around the gate (`ac2-polish/SKILL.md:31`,
`polish-fixpoint.sh:138`). **ac2 still requires it: `polish-fixpoint.sh` produces the fixpoint
receipt but does NOT stamp — `stamp-refined.sh` reads that receipt and performs the write.**

`ac-bead-refine` is in the archive set. Archiving it as-is archives the live gate. It also
breaks `hooks/hooks.json:55`, where `stamp-refined.sh` is the declared BACKSTOP for the
fail-open `bead-capture-guard.py`.

**The slate must therefore MOVE, not archive, these two executables**, in the same atomic
commit, before or with the `ac-bead-refine` move:

- `skills/ac-bead-refine/scripts/stamp-refined.sh` → `skills/_tools/stamp-refined.sh`
- `skills/ac-bead-refine/scripts/element4-check.sh` → `skills/_tools/element4-check.sh`
  (called by `stamp-refined.sh`; moving one without the other breaks the caller)
- their `*.test.sh` harnesses move with them (`element4-check.test.sh`,
  `stamp-refined-fixpoint.test.sh`) and stay wired into `scripts/run-all-harnesses.sh`
- re-point the four caller sites in the same commit: `ac2-polish/SKILL.md`,
  `skills/_tools/polish-fixpoint.sh`, `beads-standards/reference/bead-conventions.md`,
  `hooks/hooks.json`

`skills/_tools/` is the plan's declared home for shared executables (`_shared/` retired), which
is why it is the destination rather than an ac2 skill's `scripts/` — and `ac2-pipeline` may
never own a `scripts/` dir at all (constitution bound).

**Post-move gate (run inside the cutover, before the commit):** `stamp-refined.sh` resolves on
its new path from all four callers, and its test harness is GREEN. A `refined` stamp attempted
after the cutover that silently no-ops is the failure this item exists to prevent.

### 3b. Same class, second instance — pointers into archived skill BODIES

Not executables, but the identical failure shape: a surviving skill's operating text points at
a file that the cutover archives.

- `ac2-publish/SKILL.md:84` → `skills/ac-publish/SKILL.md § Phase 4` (web promote mechanics).
  `ac-publish` IS in the archive set → this pointer dangles. Either lift § Phase 4 into
  `ac2-publish` or re-point to the archived path explicitly.
- `ac2-implement/scripts/swarm-commit.sh:17` → `skills/ac-pipeline/references/assurance-declarations.md`
- `ac2-implement/SKILL.md:19`, `ac2-plan/SKILL.md:19`, `ac2-polish/references/plan-checklist.md:9`,
  `ac2-polish/references/bead-checklist.md:9,85`, `ac2-beadify/references/bead-schema.md:9`,
  `ac2-publish/SKILL.md:68,74` → `ac-pipeline/references/`.
  All resolve only while `ac-pipeline` survives → **gated on Open Question A.**
- `ac2-review/SKILL.md:17-18` → `skills/ac-review/scripts/consensus.py` and the `ac-review/`
  reference set → **gated on Open Question A.** Note `ac2-review`'s own frontmatter says
  "For the manual human-triggered panel use `ac-review`", which reads as ac-review SURVIVING.

**Cutover gate:** a dangling-ref grep over the surviving tree must return zero hits into
`_archive/skills/`. The plan measured ~250 cross-refs to absorbed skills in surviving skills;
a same-shape grep on the current tree counts **510** occurrences of the eleven archive-set skill
names outside their own directories. That number is the workload, not a blocker — but the grep
is a GATE, and the cutover does not land while it is non-zero.

---

## 4. Enforcers removed in the same slate

A cut removes its enforcers. These `lint.sh` checks read files that will no longer exist:

- `D3` — `skills/ac-plan-init/SKILL.md` `_backlog/{version}` assertion
- `D4` — `skills/ac-beadify/SKILL.md` plan-status gate assertion
- `D6` — "pre-merge gate" claims in `ac-implement/SKILL.md` + `ac-merge/SKILL.md`
- `D7` — "Version bump scans commits" in `ac-merge/SKILL.md`
- `D8` — `ac-merge/references/version-bump.md` sole-owner statement (the `ac-distribute` leg of
  D8 survives and must be kept)
- `G7b` — `ac-implement/SKILL.md` must name both UI-validation owners
- `D2`, `G1`, `G7c`, `G7d` — assertions over `ac-pipeline/SKILL.md` → **gated on Q-A**

Also in the same commit:
- **README registry rows** for all eleven (lint Check 4a pairs a `SKILL.md` with a row) —
  e.g. `README.md:42` `ac-bead-refine`, `README.md:45` `ac-implement`.
- **`hooks/hooks.json:55`** — the `stamp-refined.sh` BACKSTOP path (see 3a).
- **Deploy targets re-sync to one pipeline**: `~/Repos/infrastructure/ac-deploy-targets.list`
  (35 targets) — every target carries the full registry by symlink, so an archived skill must
  disappear from all 35 in the same pass, run via the existing `infra-sync.sh`.

**Expected side effect, and a wanted one:** lint Check 13 (registry description budget,
~32,228/30,000) is currently a KNOWN-FAILING accepted transient under a human ruling that it
"clears at archival". The check's own failure text says *"Diet descriptions or archive absorbed
skills."* The cutover is that archival. **Post-cutover, Check 13 must go GREEN — if it does not,
the archive set was smaller than the ruling assumed, and that is a finding.**

---

## 5. FRICTIONS dispositions

Five FRICTIONS ledgers live inside the archive set: `ac-batch-close`, `ac-bead-refine`,
`ac-implement`, `ac-loop-swarm`, `ac-publish`. Each needs a disposition in the same slate.

`scripts/ac2-ledger-integrity.sh` (lint Check 22) reads ONLY
`skills/ac2-pipeline/FRICTIONS.md`, so archiving the five does not break the check mechanically.
But its documented **seed rule** — "a friction id minted in an OLD ac-* ledger is legal input"
— means live ac2 controls cite ids whose source text would move out of the working tree.
Disposition per ledger: fold cited entries into `ac2-pipeline/FRICTIONS.md`, or record the
archived path beside the id. Silent archival leaves ac2 controls citing evidence nobody can read.

---

## 6. beads-standards fold-in

`bead-schema.md` (currently `ac2-beadify/references/`) folds into `beads-standards` as THE
machine-wide contract. The six-element sections retire **only after** their non-ac consumers get
pointer updates in this same slate: `dream`, `reflect`, `context-engineering`, `skill-builder`,
`jef-flywheel`.

Existing `refined` ac-*-schema beads stay implementable (the ac2 schema is a superset); nothing
writes the old schema again.

`dream` and `reflect` process-improvement output flips from self-beads to the family ledgers
in the same commit — that channel is the census's largest self-bead source.

---

## 7. Scheduling preconditions — check ALL before scheduling

1. **The outer loop is wired.** `ac-triage`'s inbound leg must be live before the old pipeline
   is retired: external signal (crashes, TestFlight feedback, prod findings) files with a
   `catch-stage:<stage>` label and a `discovered-from` edge into the ac2 lanes —
   `skills/ac-triage/SKILL.md` §§ around lines 198-210. **Landed under `ac-k25c.7` (closed).**
   Re-verify on the tree at scheduling time, not from this sentence. A factory whose only
   critic is itself cannot discover that it is wrong; retiring the old pipeline while nothing
   outside it can return a verdict makes the baseline's external-verdict share unmeasurable.
2. **≥1 genuine (non-synthetic) refused close on record** from the dogfood build — evidence
   before demolition.
3. **The baseline exists and is anchored** — `precutover-baseline.md` at `5410d85`. Done.
4. **§3a resolved** — `stamp-refined.sh` + `element4-check.sh` relocation written into the
   slate commit, callers re-pointed, harness green.
5. **Open Questions A and B answered by a human.** They are not answerable from the tree.
6. **Dangling-ref grep returns zero** into `_archive/skills/` from the surviving tree.

---

## 8. Rollback — concrete, minutes, human-decided

Not "revert". The named moves, in reverse:

1. `git tag pre-ac2-cutover` is taken BEFORE the slate commit — it is the rollback anchor and
   must exist before any `git mv` runs.
2. `git mv _archive/skills/<skill> skills/<skill>` for each of the eleven (plus the twelfth if
   Q-A adds one). Same-commit inverse of §2.
3. `git mv skills/_tools/stamp-refined.sh skills/ac-bead-refine/scripts/` and the same for
   `element4-check.sh` and both test harnesses; restore the four caller paths in
   `ac2-polish/SKILL.md`, `skills/_tools/polish-fixpoint.sh`,
   `beads-standards/reference/bead-conventions.md`, `hooks/hooks.json`.
4. Restore the removed `lint.sh` checks (D2/D3/D4/D6/D7/D8/G1/G7b/G7c/G7d) and the README
   registry rows.
5. Restore `beads-standards`' six-element sections and the pre-fold `bead-schema.md` home.
6. **Re-run `infra-sync.sh` against `~/Repos/infrastructure/ac-deploy-targets.list`** — the
   rollback is NOT complete at the repo boundary. 35 checkouts hold symlinks into the registry;
   an un-re-synced target is a checkout pointing at a skill that moved.
7. Verify: `bash lint.sh` shows the pre-cutover known-failure set (including Check 13 back in
   BREACH — its return is expected on rollback, not a new defect), and
   `bash scripts/run-all-harnesses.sh` is green.

Rollback is only minutes because the slate is ONE commit. If the cutover is split across
commits, this section is void and must be rewritten before scheduling.

---

## 9. Open questions — unresolved, marked, NOT guessed

**Q-A — what is the twelfth archived skill?** The plan's absorb column names eleven; `lint.sh`
says twelve. By elimination the twelfth is `ac-review` or `ac-pipeline`, and both have live
surviving consumers: `ac-review` owns `consensus.py` + the dimension references that
`ac2-review` cites by pointer (while `ac2-review`'s frontmatter tells humans to *use* ac-review
for the manual panel); `ac-pipeline` owns `close-evidence-check.sh` — the evidence core of
`ac2-implement`'s close-gate — plus `beads-closed-gate.sh`, `validate-qa-run.sh`,
`claim-race-harness.sh`, `board-truth.sh`, and the `references/` set cited from eight ac2 files.
**Archiving either one without first relocating those executables and references repeats the
§3a failure.** A human must name the twelfth, or rule that the plan's eleven is correct and
`lint.sh`'s count is stale.

**Q-B — do `ac-batch-close`, `ac-merge`, `ac-publish` archive whole, or partially?** The plan
says `ac2-publish` absorbs "ac-batch-close/ac-merge **overlap** + ac-publish **essentials**" —
overlap and essentials are not the whole skill. `ac2-publish:84` already points into
`ac-publish/SKILL.md § Phase 4` for live mechanics. If the answer is "partially", they are
§3b relocations, not §2 archives, and the archive set shrinks.

**Q-C — the registry-lint reform items the plan deferred here.** `skill-diet-conservation.mjs`
and the per-file ratchet questions were explicitly routed to this slate as their own item
(plan § Out of scope). They are recorded as present and unanswered; they do not block the
cutover but must not be lost with the plan file.
