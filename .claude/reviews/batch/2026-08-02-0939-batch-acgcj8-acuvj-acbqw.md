# Review Report: Batch ac-gcj.8 + ac-uvj + ac-bqw (payloads-point conversion + frontmatter re-site + force-with-lease carve-out)

**Date:** 2026-08-02
**Mode:** batch-close
**Range:** 7998b719f5a81e64b4444e7a728b4b62a44e9bf1..5891d9615c09a6ee17a1d8c3611f081ccf0fd2d1
**Plan:** none (_plans/ gitignored in this repo)
**Panel (manifest):** findings-integrity, consistency, discipline, doctrine-delta — skipped: security=docs-only diff — docs-lens set substituted for the code four; performance=docs-only diff — docs-lens set substituted for the code four; architecture=docs-only diff — docs-lens set substituted for the code four; correctness=docs-only diff — docs-lens set substituted for the code four; test-quality=zero test files and zero runtime source in diff (skills/**/*.md only); contracts=no exported code surface — docs-only diff, docs-lens set covers doc contracts
**Rounds:** 1
**Degraded:** no

> **Scope note (bd-zl1y5):** the review-mark (`.claude/reviews/batch/`) last moved 2026-07-19
> (a8b125a) and no report since carries a `Range:` line, so the coverage frontier could not be
> reconstructed from artifacts. Scope was therefore taken from the conductor's batch definition
> (the three commits above), not the literal since-mark range (~150 commits spanning
> already-shipped batches). The intermediate acceptance/coverage gap is a pre-existing
> condition of the board, not this batch's.

---

## Summary

Three doc-canon beads: ac-gcj.8 (commit 5891d96) writes the "Payloads point, contracts paste"
canon into `ac-pipeline/references/delegation-contract.md` and converts both fan-out panels
(ac-beadify validators, ac-review reviewer template) from pasted payloads to point-based
payload reads with verdict citation keys; ac-uvj (commit bfe19b6) re-sites the Pass C
selection-brain binding line out of invalid YAML frontmatter into the body of ac-distribute
and ac-site-polish; ac-bqw (commit e3180ab) documents the branch-scoped `--force-with-lease`
carve-out in commit-discipline §Rules.

**Live-exercise note:** this review is itself the first live run of the converted
reviewer-prompt-template (resolved `DIFF_RANGE` string, step-1 `git diff` transport,
`payload_read` verdict key). The conversion worked in practice: all four reviewers ran the
diff themselves from the range string, and all four output files carried valid JSON. One
template seam observed (not a defect in this diff's mission, noted for the record): the
template's empty-findings example (`{"reviewer":"{ROLE}","round":{ROUND},"findings":[]}`)
omits the `payload_read` key, so empty verdicts lose the payload-citation tripwire; and the
template carries no read-only/banned-ops clause for reviewers (the ac-7rf Phase-3 tree check
is the only backstop). Both are nits below the severity floor — recorded here, not beaded.

## Beads Completed

- ac-gcj.8 — payloads point, contracts paste: delegation-contract § + both fan-out panel conversions (5891d96)
- ac-uvj — re-site Pass C selection-brain binding out of YAML frontmatter (bfe19b6)
- ac-bqw — branch-scoped --force-with-lease carve-out in commit-discipline §Rules (e3180ab)

## Changes

9 files changed, 85 insertions(+), 42 deletions(-) — all `skills/**/*.md`, no runtime code:
`ac-beadify/SKILL.md` + `references/validators.md`, `ac-distribute/SKILL.md`,
`ac-hygiene/SKILL.md`, `ac-pipeline/references/commit-discipline.md` +
`references/delegation-contract.md`, `ac-review/SKILL.md` +
`references/reviewer-prompt-template.md`, `ac-site-polish/SKILL.md`.

## Test Coverage

- `./lint.sh`: **314 checks, 0 failures** (docs-only diff — no test/build runtime per
  `verification-gate.md` Step 1: CLASS_RUNTIME unset, cheap checks suffice)
- SKILL.md net delta across the diff: +6/−24 (net shrink — no-net-growth gate unchallenged)
- Post-panel tree check (ac-7rf): clean — zero non-`.beads/` working-tree changes after the panel

## Review

| Category           | Critical | High | Medium | Auto-Fixed |
| ------------------ | -------- | ---- | ------ | ---------- |
| findings-integrity | 0        | 0    | 1      | 0          |
| consistency        | 0        | 0    | 0      | 0          |
| discipline         | 0        | 0    | 0      | 0          |
| doctrine-delta     | 0        | 0    | 1      | 0          |
| **Total (dedup)**  | 0        | 0    | 1      | 0          |

*(the two Medium rows are the same defect at the same file:line, cross-confirmed —
`consensus.py` same-location-consensus:doctrine-delta,findings-integrity)*

**VERDICT:** APPROVED

### Auto-Fixed Issues

None — the consensus cascade marked the one finding AUTO_FIX (same-round consensus), but this
run's contract is read-only on the diff (findings become beads, not fixes). Routed to
**ac-gcj.9** instead; deviation deliberate and conductor-directed.

### Needs Decision

None. No DESIGN_DECISION or SCOPE_ESCALATION items surfaced.

### All Findings

#### findings-integrity

- **[Medium] `skills/ac-beadify/SKILL.md:144` + `references/validators.md:9`** —
  `mis-sourced-citation`: `{PLAN_PATH}` described as "the literal plan-file path from
  Phase 1", but plan-file identification happens in `### Identify Plan File` (SKILL.md:45)
  under `## Phase 0: Initialize` (:24); Phase 1 (:100) assigns no PLAN_PATH. → **ac-gcj.9**

#### consistency

None. Verified clean: no leftover `{DIFF}`/`{PLAN_CONTENT}`/`{PROPOSED_STRUCTURE}`
placeholders anywhere in `skills/`; the frontmatter fix repairs a genuine YAML structure
violation (line sat between `name:` and `description:` keys, confirmed via
`git show 7998b71:`); `CODEBASE_CONTEXT` referenced nowhere after the ac-hygiene deletion;
the "exactly TWO edits per prompt" rule held across all four converted prompts.

#### discipline

None. All 9 changed files map to the three beads' `Delivers:` lists (no orphans); the
ac-hygiene section deletion is authorized as ac-gcj.8 work item 4; the compliance note's
non-compliance verdict correctly routes to existing open bead ac-08k rather than fixing
inline.

#### doctrine-delta

- **[Medium] `skills/ac-beadify/SKILL.md:144`** — same defect as findings-integrity's
  (same-location consensus): mislabeled phase reference in newly-added tier-1 core text,
  unverifiable by ac-gcj.8's grep-only presence ACs. → **ac-gcj.9**
- Clean otherwise: no reintroduced historical blocks (`git log -S` on the new section,
  `payload_read`, `DIFF_RANGE`, and the carve-out all show first introduction); relocated
  `net-growth-ok` stamps preserved, not minted; `delegation-contract.md` growth is
  `references/`-tier (exempt from the tier-1 stamp gate) and backed by closed bead ac-gcj.8.

## Known post-merge tails

- [ ] ac-gcj.9: ac-beadify PLAN_PATH mis-cites 'Phase 1' — plan file is identified in Phase 0

## Also carried (not this batch's beads)

Nothing — `git log --oneline 7998b71..5891d96` contains exactly the three bead commits
(bfe19b6, e3180ab, 5891d96) and `git diff --stat` shows only their 9 delivered files;
no concurrent-session, triage, or foreign-WIP changes ride in this range. Bead↔commit
mapping verified from commit trailers: bfe19b6→ac-uvj, e3180ab→ac-bqw, 5891d96→ac-gcj.8.
