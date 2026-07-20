# Hygiene Pass — the skill-diet workflow

Callable cleanup for **existing** skills: shrink an oversized SKILL.md to its irreducible
enforcement spine, extract optional payload to `references/`, centralize cross-skill blocks
to `_shared/`, and delete sediment — **without ever weakening enforcement that loads every run.**

Two modes:
- **Single-skill diet** — one named skill (Part A).
- **Batch sweep** — scan a whole `skills/` dir, rank offenders, diet each (Part B wraps Part A).

This is the operational counterpart to `references/structure-standard.md` (the rulebook) and
`references/token-economics.md` (the token-bucket + enforcement-hierarchy framework). Read both
before running. It is heavier than `refine-skill.md` (which improves one skill interactively at
*rule* granularity); use hygiene-pass when the goal is a structural **diet** at *section* granularity.

**Golden rule (from token-economics §3):** the question is never "can this be shorter?" It is
"what failure does this token prevent, and does a stronger-or-equal mechanism exist for fewer
tokens?" Enforcement stays; only optional payload moves; only duplicate/dead/stale is cut.

---

## The risk tier — what this workflow may auto-apply

Skill signal splits into two tiers (full boundary: `references/maintenance-ledger.md`):
- **Shape / structure** (dedup, sediment, extraction, buried triggers, near-dups) — this workflow
  **agent-applies WITHOUT a human gate**, but ONLY after the deterministic guards pass (A4 survival
  gate + `validate-skill.sh --diff` proving no enforcement line vanished). This is the efficiency unlock.
- **Behavior / enforcement** (a new gate, a changed branch, a contract fix) — this workflow does **NOT**
  apply. Route it to a `skill:<name>` `skill-improvement` bead (reflect's human-gated channel). If a
  cartography item turns out to change what the skill *does*, kick it to a bead and move on.

The line is always **behavior vs shape.** When unsure which tier, treat it as behavior (escalate).

## Part A — Single-skill diet

### A0. Classify archetype + read the ledger (before anything)

1. **Classify the archetype** (`references/structure-standard.md` § Skill archetypes): orchestrator /
   knowledge / hybrid. This sets the diet **bias** — orchestrators protect a long enforcement spine
   (risk = over-extraction); knowledge skills push aggressively to `references/` and keep SKILL.md a
   thin index (risk = under-disclosure). Apply the right bias throughout; a fat knowledge SKILL.md is
   a bug, a long orchestrator spine may be legitimate.
2. **Read `skills/<name>/MAINTENANCE.md`** if it exists — the **Inbox** is this pass's agenda, the
   **Holding pen** lists decisions owed (check `review-by` dates), the **Cut-log** is churn history
   (don't re-cut what's been reinstated before). Also pull open behavior beads: `br list -l skill:<name>`.
   If no ledger exists, you'll create one lazily in A6 if this pass produces any cut/hold/defer.

### A1. Baseline

```bash
SKILL=<name>; DIR=<skills-dir>/$SKILL
wc -l "$DIR/SKILL.md"
ls "$DIR/references/" "$DIR/workflows/" 2>/dev/null
bash <skill-builder>/scripts/validate-skill.sh "$DIR"      # size/description/section/pointer checks
grep -nE '^#{1,4} ' "$DIR/SKILL.md"                        # section skeleton with line numbers
```

Record: current line count, existing reference/workflow files, and the section skeleton. If the
skill is already ≤400 lines with no duplication, stop — a diet buys nothing; note it and exit.

### A2. Cartography — the CORE / EXTRACT / CUT ledger (MANDATORY, before any edit)

Walk the SKILL.md **section by section** (use the skeleton from A1). For each block, one ledger row:

| line-range | verdict | target | one-clause why |
|---|---|---|---|

Verdict rubric (apply the discriminator from structure-standard.md to *every* block):

- **CORE** — the orchestrator itself needs it on **every** run: routing rules, fully-written
  branches, run-ledger / gate / stop-condition lines, exact option sets, standing constraints,
  the Remember block. **Stays inline even if long** — length here IS the enforcement.
- **EXTRACT → `references/<file>.md`** — only a sub-agent, a single stage, or a conditional
  sub-path consumes it: sub-agent prompt bodies, single-stage output/report templates, JSON
  schemas, off-main-flow state machines, mutually-exclusive variants.
- **EXTRACT → `_shared/<file>.md`** — same as above **and** already (or about to be) consumed
  verbatim by a second skill. Consumer count decides the target, not size.
- **CUT** — sediment: same content twice in this file, dead paths, stale/superseded layers,
  deprecation history in prose or description (token-economics § Sediment). Apply the **move-out
  decision** (structure-standard § The move-out decision): hard-delete pure sediment vs
  relocate-then-delete anything with residual value (incident → `references/incidents.md`/memory).
  **Before any delete run the churn guard:** `git log -S "<snippet>" -- <SKILL.md>` — a block cut
  before is sticky sediment; home it properly or fix the re-adder, and note it in the Cut-log, don't
  silently re-cut.

**Two traps that a naive line-count pass gets wrong — check both explicitly:**

1. **Enforcement-by-repetition is CORE, not duplication.** A rule re-stated at each decision
   point where it fires (a bug-lane check re-consulted every selection; a gate invoked in two
   phases) is level-4 enforcement, not sediment. Only *verbatim* restatement with no per-site
   decision is CUT. When unsure, keep it.
2. **Persuasion inside a CORE block compresses in place — it does not move.** Incident
   narrative (dates, RUN_IDs, SHAs, minutes-lost) riding alongside an operational rule: keep
   the rule + one-clause causal why, cut or relocate the story to `references/incidents.md` or
   a memory key. The block stays CORE; only its narrative weight drops.

Sum the ledger: approximate CORE vs EXTRACT vs CUT line counts. State what the spine becomes
post-diet, and confirm it reads as a coherent "what the conductor does every run" narrative with
no dangling logic. If extraction would strand cross-references, that's a coordinated edit (A5), not a blocker.

### A3. The orchestrator-trap gate (before extracting ANY child-spawn prompt)

For every block headed to EXTRACT that is a **sub-agent / child-delegation prompt**, ask: does the
skill spawn a fresh child that receives this prompt *pasted into its context*, never opening the
skill's files? If yes → it is orchestrator-trapped (structure-standard § The orchestrator trap):

- It may still move to `references/`/`_shared/` **only if** the spine keeps, at the spawn site, an
  explicit *"read `<file>` and paste it verbatim into the child prompt before spawning — never
  point the child at the file"* instruction.
- If you cannot guarantee that inline-paste step, **the prompt stays in the spine.** Mark its
  ledger row CORE and move on. Silently extracting it reintroduces the "child acts before it reads" bug.

### A4. Enforcement-preservation check (the survival gate)

Before cutting/moving, produce a numbered **constraint inventory** (as in `refine-skill.md` Phase 3.0):
every behavioral rule, gate, branch, completion criterion, exact option set, standing constraint.
Then map each inventory item to its post-diet home: inline-spine / script / condition-labelled pointer.

**A rule that drops a level on the enforcement hierarchy (script > inline-at-use > completion-criterion
> repetition > prose > pointer) is a FAIL** — restore it inline or move it *up*, never down. Spawn a
validator-stance subagent to walk the inventory against the planned rewrite and confirm zero rules
weakened; treat its verdict as a gate, not advice.

### A5. Execute — move text, don't rewrite logic

1. Create each target file (`references/<x>.md`, or `_shared/<x>.md` for ≥2-consumer blocks); add a
   ToC if >100 lines.
2. Cut each EXTRACT block to its target **verbatim**; in the spine leave a one-line imperative pointer
   + the variable substitutions the consumer needs (or the trap-guarded inline-paste instruction from A3).
3. Delete CUT blocks; compress in-place persuasion per A2 trap 2.
4. **Coordinated multi-site pointer fix:** update every cross-reference the move touched — inside this
   skill AND in *sibling skills* that referenced the moved block by section name (grep the registry for
   the old section title / file path). For any prose restatement of a `_shared/` block, add
   `<!-- mirror of _shared/<x>.md — edit there first -->`.

### A6. Re-validate + write the ledger

```bash
bash <skill-builder>/scripts/validate-skill.sh "$DIR"          # size ↓, pointer-integrity clean
bash <skill-builder>/scripts/validate-skill.sh --diff "$DIR" HEAD   # NO enforcement line removed w/o relocation
git diff --stat                                                # moved lines ≈ removed lines
grep -rn "<moved-section-title>" <skills-dir> --include=*.md   # no stale sibling pointers remain
```

Confirm: content preserved (diff the moved text), spine is enforcement-dense, every pointer resolves,
no sibling dangling, validator survival-gate passed, `--diff` clean. **The `--diff` clean result is
what authorizes the no-human-gate auto-apply** — if it flags a removed enforcement line, that change
was behavior-tier: revert and route to a `skill:<name>` bead instead.

**Write `skills/<name>/MAINTENANCE.md`** (create lazily if absent, per `references/maintenance-ledger.md`):
- Append each cut/extract/reinstate to the **Cut-log** (with reason + destination + any churn count).
- **Resolve the Inbox** — every shape item applied, deferred (with reason), or re-tiered to a bead;
  emptying it is this pass's definition-of-done.
- Move any undecided content to the **Holding pen** with a `review-by` date + default resolution;
  resolve/escalate any pen item already past its review-by.
- Refresh the **Health** header (archetype, last_pass, spine_lines).

Report the before/after line count, what moved where, ledger deltas, and any block deliberately kept
inline (with the reason — usually A2-trap-1 or A3).

---

## Part B — Batch sweep (registry-wide)

Use when the ask is "clean up our skills" against a whole `skills/` dir, not one named skill.

### B1. Scan and rank

```bash
bash <skill-builder>/scripts/validate-skill.sh --registry <skills-dir>   # budget + exact-dup + near-dup candidates
for md in <skills-dir>/*/SKILL.md; do printf "%6s  %s\n" "$(wc -l <"$md")" "$(dirname "$md" | xargs basename)"; done | sort -rn | head -25
```

Rank offenders by: (a) SKILL.md line count over target (judged against the skill's **archetype** —
a long orchestrator may be fine, a long knowledge skill is not), (b) cross-skill duplicate blocks the
`--registry` scan surfaced — both exact-line and **near-dup** (fuzzy shingle-overlap; these catch
reworded/synonym-swapped blocks the exact matcher misses, e.g. a rationale block copied with
batch→wave substituted). The script surfaces *candidate pairs*; **you make the semantic call** on
whether they say the same thing, then route real dups to `_shared/`. (c) known-stale skills
(recent supersession events — deprecations, thinnings, renames leave sediment).

### B2. Queue and diet

Produce a work-list: one row per skill needing a diet, with the headline reason. Then run **Part A
on each**, sequentially or as parallel isolated sub-agents. Two batch-only rules:

- **`_shared/` promotions are done ONCE, first.** When the same block appears in N skills, create the
  single `_shared/` copy and repoint all N consumers in one coordinated edit *before* dieting those
  skills individually — otherwise each per-skill diet re-derives a divergent copy.
- **No silent truncation.** If the sweep bounds coverage (top-N skills, skip-if-under-target), `log`
  what was deferred so "swept the registry" doesn't over-claim.

### B3. Registry re-validate

Re-run `validate-skill.sh --registry` — confirm the description budget held (a diet shouldn't touch
descriptions unless they were the finding), no new pointer breaks across the repointed `_shared/`
graph, and the invocation-graph check still passes. Report per-skill before/after + the `_shared/`
files created.

---

## Output

- The CORE/EXTRACT/CUT ledger per skill (the audit trail for what moved and why).
- Before/after line counts; `_shared/` files created and their consumer lists.
- The validator survival-gate verdict (zero enforcement rules weakened).
- Anything deliberately kept inline against a naive line-count expectation, with the reason.
