# Review Report: maintenance batch 2 — lint ratchet + frontmatter check + preamble backfill + trigger corpus

**Date:** 2026-08-03
**Mode:** batch-close
**Range:** 0c34a1c5aeea5f785a207a3e463f125cea19b751..337589de3d58b23ee6402ea0ce5d590142e8ac07
**Plan:** none (maintenance batch)
**Panel (manifest):** security, performance, architecture, correctness, test-quality, contracts, doctrine-delta — skipped: none
**Rounds:** 1
**Degraded:** no

---

## Summary

Five maintenance beads: a `lint.sh` standard-tier ceiling ratchet (770 -> 730) plus a new
SKILL.md frontmatter block-integrity check (check count 314 -> 372); a verbatim child-spawn
preamble backfilled into two `references/` files; dream check 14 (skill-uptake decay,
self-arming, emit-only); and a trigger precision/recall corpus over the 6 pipeline
conductors with the 4 `description:` fixes it produced.

Full 7-dimension panel (the diff touches `skills/`, so the doctrine-delta lens spawned on
top of the six). 20 findings after dedup. The panel's highest-value catch was not in the new
code at all: the preamble backfill landed **outside** the `Task(...)` prompt fences the
conductors actually construct, so the bead's own compliance target — "the conductor injects
the verbatim block into its constructed child prompts" — was not met by the edit that closed
it.

## Beads Completed

- ac-gcj.6 — lint.sh: ratchet Check 15 STANDARD_CEILING 770 -> 730 (c16b592)
- ac-mah — lint.sh: Check 3 validates SKILL.md frontmatter block integrity (aafe33a)
- ac-08k — inline verbatim child-spawn preamble in ac-beadify / ac-plan-init child prompts (5963b7c)
- ac-znk.9 — dream check 14: skill-uptake decay (9f09031; script half is `fd38012a` in the ROOT repo)
- ac-gcj.10 — trigger precision/recall corpus, B1 pilot over the 6 conductors (337589d)

## Changes

Batch under review: 9 files, +338 / -13 (`.beads/` excluded — 111/160 files in the raw range
were ledger churn).

Review fixes applied on top: 5 files, +62 / -33 — `lint.sh`,
`skills/ac-beadify/references/validators.md`, `skills/ac-plan-init/references/explorers.md`,
`skills/ac-review/SKILL.md`, `skills/dream/references/lint-checks.md`.

## Test Coverage

This repo has no unit-test suite; `lint.sh` **is** the executable guard, so the test-quality
lens audited whether the newly-added check can fail rather than auditing test files.

- `bash lint.sh` → exit 0, **372 checks, 0 failures** (unchanged count after fixes).
- `bash -n lint.sh` → syntax clean.
- `ubs lint.sh <md files>` → **no scanner ran** ("no supported languages detected"); UBS covers
  none of bash/markdown. Recorded as *not checked*, explicitly **not** a pass.
- Probe suite run in a disposable worktree (`/tmp/fmprobe-113231`, removed) against the
  repaired Check 3. RED where required: sentence-case colon-prose between keys; indented line
  above any mapping key; bare prose with no colon; symlinked `SKILL.md`; block never closed.
  GREEN where required: unmodified registry; minimal valid block whose closing `---` carries
  no trailing newline (the trailing-newline regression, now fixed).
- Ceiling check independently probed: appending ~800 lines to a standard-tier SKILL.md fails
  Check 15 correctly.

## Review

| Category       | Critical | High | Medium | Auto-Fixed |
| -------------- | -------- | ---- | ------ | ---------- |
| Security       | 0        | 1    | 0      | 1          |
| Performance    | 0        | 0    | 3      | 0          |
| Architecture   | 1        | 1    | 1      | 1          |
| Correctness    | 0        | 2    | 1      | 3          |
| Test-quality   | 1        | 1    | 0      | 2          |
| Contracts      | 1        | 1    | 3      | 2          |
| Doctrine-delta | 1        | 2    | 0      | 3          |
| **Total (deduped)** | **4** | **8** | **8** | **9** |

**VERDICT:** APPROVED

Every panel dimension reported (`reviewers_missing` empty, no retry needed). All 20 deduped
findings were dispositioned: 9 auto-fixed in place, 4 filed as beads, 3 rejected with
rationale, 4 subsumed by an applied fix. No `qa-blocker` and no blocking `decision` bead
remains open. The validation gate passes.

### Auto-Fixed Issues

**`lint.sh` — Check 3 (frontmatter block integrity)**

1. **Key-shape test admitted sentence-case prose** (Critical; correctness + test-quality
   consensus, probe-convicted). `^[A-Za-z_][A-Za-z0-9_-]*:` accepted `Note: this is prose`,
   `TODO: …`, `IMPORTANT: …` — the exact corruption class the check's own comment claims the
   discriminator is safe against. Tightened to `^[a-z][A-Za-z0-9_-]*:`, verified against the
   live key inventory (`name`, `description`, `accessory`, `tools`, `model`, `memory`,
   `disable-model-invocation`, `permissionMode` — all lowercase-initial), so it is a
   zero-false-positive tightening. Multi-word prose was already excluded by the space.
2. **Orphan indented lines passed unconditionally** (High; correctness + test-quality
   consensus). The `[[:space:]]*) continue` carve-out accepted any indented line with no
   mapping entry above it. Added an `fm_seen_key` guard; an indented line before the first key
   is now an error.
3. **Final line dropped when the file has no trailing newline** (High; correctness). The bare
   `while IFS= read -r fm_line` exits before the loop body on a partial final line, so a
   validly-closed block whose `---` lacked a trailing newline was reported as *never closed* —
   a false positive on well-formed input. Added `|| [ -n "$fm_line" ]`.
4. **Symlinked `SKILL.md` followed, and its content echoed** (High; security). `test -f`
   dereferences symlinks, so a PR adding `skills/<name>/SKILL.md` as a traversal symlink had
   its target scanned and the first non-conforming line embedded verbatim in the `fail()`
   message. `registry-lint.yml` runs `lint.sh` on `pull_request` and the repo is public, so
   this was a reachable file-disclosure primitive. Added an `[ -L ]` guard (fails loudly) and
   truncated the echoed line to 80 chars.

**`lint.sh` — provenance (doctrine-delta check 0)**

5. Runtime `echo` no longer bakes `ratcheted 2026-08-03` into text every future lint run
   prints — a leak that also guaranteed staleness at the next ratchet.
6. Both new comment blocks had their edit narrative (dates, bead IDs `ac-mah`/`ac-uvj`/
   `ac-gcj.6`, "repaired under", "RATCHETED … from 770 to 730") trimmed. The engineering
   rationale — corruption class, discriminator reasoning, the ratchet basis and the
   next-ratchet rule — is retained verbatim; only the story moved to the commit.

**Skill text**

7. **The preamble backfill was inert at the boundary it targets** (Critical; architecture,
   corroborated against the canon). `delegation-contract.md` § Child-spawn preamble defines
   compliance as *"neither conductor SKILL.md injects the verbatim block into its constructed
   child prompts"*. ac-08k placed the block in each reference file's **header**, above the
   `# Beadify Validators` / `# Plan Explorers` heading and outside all three `Task(...)`
   fences — and both conductors' SKILL.md say to use "the prompts in `references/…`,
   substituting {ARTIFACTS_DIR} / {PLAN_PATH}", i.e. the fenced block only. Fixed with an
   explicit instruction line above each copy directing the conductor to paste the block
   verbatim at the head of each `Task(...)` prompt. Chosen over duplicating the block into six
   fences (+132 lines of the same text) — the instruction achieves the canon's requirement at
   one line per file.
8. **`ac-review` body contradicted its own new description** (Medium; contracts). The
   description now claims dual-mode (feature branch OR trunk-direct batch) while line 7 still
   said "Feature-branch scoped" and the I/O contract's Input row still said "Feature branch
   with implementation commits". Both retargeted in place, net zero lines (this is a
   conductor-tier skill: 1061/1110).
9. **dream check 14's "carried verbatim" caveat was not verbatim** (Medium; contracts). The
   quoted blindness caveat dropped "tool" and the trailing "Verify before approving a
   demotion." sentence relative to the script's `CAVEAT` constant
   (`infrastructure/dream-cycle/skill_uptake_lint.py:81-83`). Reworded to quote accurately and
   to name the constant as authoritative rather than claim verbatim reproduction.

### Needs Decision

None. Nothing met the DESIGN_DECISION or SCOPE_ESCALATION bar — every residual has an
answerable engineering question, so all four were filed as work beads under a per-run review
epic rather than as `human-gate` decision beads.

- **ac-wrsb** (epic) — ac-review 2026-08-03 — batch-2 findings
- **ac-wrsb.1** (task, P2) — stale cross-refs: `ac-batch-close/SKILL.md` still calls
  ac-review's full panel "feature-branch / on-demand"; `delegation-contract.md`'s compliance
  note still flags the ac-08k backfill as outstanding against a closed bead. Both files sit
  outside this batch's pathspec, so not auto-fixed.
- **ac-wrsb.2** (task, P3) — `lint.sh` Check 3 hardening: ~300 process forks / 1.2-1.8s per
  run (measured), plus the residual key-shape gap (a single lowercase word + colon, e.g.
  `todo: fix this`, still passes). Closing it fully needs a design call — a real YAML parse was
  rejected because `pyyaml` is not guaranteed in CI and a parse-if-available check is a
  non-deterministic gate.
- **ac-wrsb.3** (investigation, P3) — the child-spawn preamble now exists in three divergent
  embedding forms (canon / two static verbatim copies / ~20 pointer-only consumers) with
  nothing enforcing mirror fidelity; the canon's own "pointer is insufficient" rule makes the
  majority form doctrinally non-compliant.
- **ac-wrsb.4** (task, P3) — the ratchet rule ("may only ever move DOWN",
  `ceil_to_10(max × 1.10)`) lives only in a comment. Raising `STANDARD_CEILING` to 900 today
  passes every check — confirmed.

### Rejected findings (recorded so they are not re-filed)

- **`ac-loop`'s new NOT-for clause points at a nonexistent `loop` skill** — filed Critical by
  contracts, **false positive**. The `loop` skill exists; it is a Claude Code **built-in**
  ("Run a prompt or slash command on a recurring interval"), not a registry skill, so a
  `find`/`ls` over `skills/` cannot see it. The clause is correct and is exactly the exclusion
  the trigger corpus was built to find.
- **Router-description growth (+343 bytes / ~85 tokens across 4 conductors)** — Medium,
  performance + contracts. Rejected: the growth is the *product* of the eval that justifies it,
  and 85 tokens against a 30.9 KB description corpus is a 1.0% delta buying four real routing
  fixes. The corpus's own deferred observation (strip the bare `(bd-pwt44)` from
  `ac-batch-close`'s description) is correctly scoped to a sweep, not this batch.
- **"Use the pointer pattern instead of duplicating the preamble"** — Medium, architecture +
  performance. Rejected: it inverts the canon, which rules pointer-only explicitly
  insufficient on recorded evidence (ac-loop RUN 20260719-102946-27401 — 3 children
  self-detached, 3 independently rediscovered the Agent Mail token rule). The legitimate
  version of this concern is drift enforcement, which is ac-wrsb.3.

### Verified-and-clean (claims the panel checked rather than assumed)

- The ceiling ratchet's arithmetic and cited basis: ac-hygiene measures **660** lines
  excluding the 6 `CONDUCTOR_SKILLS`; `ceil_to_10(660 × 1.10) = 730`. Next largest standard
  skill is ac-plan-init at 591 — no skill is near the new ceiling. All conductor-tier skills
  are under `CONDUCTOR_CEILING=1110`.
- Every arming-gate claim in dream check 14 against the real script: 28-day window, non-empty
  `skill_reads` gate, 50% coverage guard, denominator from `skills/*/SKILL.md` (not
  `skills/*/`), `~/.claude/logs/activity.db`, per-skill aggregation, emit-only behaviour,
  re-ablation gating, and the `WORKER:` stamp grammar (cross-checked against real ledger rows
  and `beads-standards`). Only the caveat wording diverged (fixed above).
- The trigger corpus's self-reported score: 60 judgment rows counted, 4 FAIL rows
  (3 precision / 1 recall), row grammar holds on every row, the findings table matches the
  inline verdicts, and all four claimed description edits are present in this diff.
- The two verbatim preamble copies are byte-identical to the canon, including every
  destructive-command / stash / bypass guardrail — the backfill weakened nothing. Its defect
  was placement, not content.
- `ac-merge` is genuinely not invoked on the trunk-direct path anywhere in the registry, so
  its narrowed description is accurate.
- No reintroduced historical block: `git log -S` on both preamble anchors shows this content
  was never previously present in either file, and it matches the ac-znk.5-decided shape.
- Reviewer tree hygiene: `git status` after the panel showed no reviewer-authored leakage into
  the shared checkout; the test-quality worktree was created and removed under `/tmp`.

## Known post-merge tails

- [ ] ac-wrsb.1: Stale cross-refs after ac-review dual-mode + ac-08k preamble backfill
- [ ] ac-wrsb.2: lint.sh Check 3 hardening — per-line fork cost + residual key-shape gap
- [ ] ac-wrsb.3: Child-spawn preamble now has 3 divergent embedding forms with no fidelity check
- [ ] ac-wrsb.4: STANDARD_CEILING ratchet rule is comment-only — nothing enforces ratchet-down
- [ ] ac-i5l9.1: ac-triage/ac-tidy scheduled worktree pattern contradicts ac-pipeline's 'no worktrees' invariant
- [ ] ac-i5l9.2: pipeline-proposal exclusion is bead-semantics canon written into ac-tidy's workflow core (3 sites)
- [ ] ac-i5l9.3: bead-work-concurrent-dir.test.sh executes unvalidated text extracted from SKILL.md

## Also carried (not this batch's beads)

The ROOT-repo sibling commit `fd38012a`
(`~/Repos/infrastructure/dream-cycle/skill_uptake_lint.py`) is the script half of ac-znk.9 and
was read as part of this review, but it is outside this repository — no fix was applied to it
cross-repo. It verified clean against every claim `skills/dream/references/lint-checks.md`
makes about it; the one divergence found (the `CAVEAT` wording) was fixed on the
agent-compounds side, which is the correct direction since the script docstring is declared
authoritative.
