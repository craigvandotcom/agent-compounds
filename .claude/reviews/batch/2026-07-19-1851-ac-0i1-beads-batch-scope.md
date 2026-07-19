# Review: ac-0i1 --beads batch scope + tt9.5 art-direction placement residual

- **VERDICT:** APPROVED
- **Run:** 20260719-185059-58770 (autonomous ac-loop, trunk-direct)
- **Scope:** `06f9048..HEAD` — 4 files, 121 insertions
- **Batch beads:** `ac-mengto-distill-tt9.5` (validator sweep, 8/8 green) + folded `ac-0i1` (closed)
- **Commits:** `a1a7e31` (ac-0i1), `f5669e6` (tt9.5 residual)

## Summary by category

| Dimension | Findings | Result |
| --- | --- | --- |
| Correctness | 0 | pass |
| Security | 0 | pass |
| Performance | 0 | pass |
| Architecture | 0 | pass |
| Test-quality | 0 | pass |
| Contracts | 0 | pass |

Conductor-direct panel (surgical additive diff behind a new opt-in flag; core four + test-quality + contracts assessed inline).

## Findings

None. Auto-fixed: 0. Needs-decision: 0.

## Verification notes

**a1a7e31 — `--beads` batch scope (beads-closed-gate.sh):**
- **Parse:** mirrors `--progress` fail-loud guard (exit 2 on missing value); `tr ',' ' '` comma→space; repeatable accumulation via `${BEADS_SCOPE:+…}`. Correct.
- **Scoping:** `COMPLETENESS_IDS` = `sort -u` of `--beads` when given, else `IN_SCOPE_IDS`. Consumed by `check_progress_completeness` ONLY.
- **N>1 keying:** union-coverage runs only when `in_scope_count > 1`; with `--beads` it keys on batch size (L10b: 1-bead→skip; L11: 2-bead→runs, names only missing `bd-cur2`).
- **Open-check untouched:** `OPEN` uses `FULL_CLAIMED`; `warn_bead_bleed` uses `IN_SCOPE_IDS` — both stay identity-wide. A genuinely-open bead from any batch still blocks.
- **Back-compat:** without `--beads`, byte-identical (L10a anchors the pre-fix behavior as a regression fixture).
- **Tests:** L10a/L10b/L11 exercise the pass edge, the fail edge, and id-naming precision (excludes prior-batch + covered ids). Meaningful. Full suite **27/27 green**.
- **Call-sites:** both ac-loop gate invocations updated with `--beads` guidance comments.

**f5669e6 — art-direction-menu.md (tt9.5 residual):** placement-only. Corner-diagonals row relocated to the Vocabulary-only section; ruling text character-identical. Deltas limited to list-marker→bold-heading (sibling parity) + a placement-rationale parenthetical. No brand ruling changed.

## Validation gate

- `./lint.sh` → **314 checks, 0 failures**
- `beads-closed-gate.test.sh` → **27/27 pass**
- shellcheck unavailable (not in repo lint chain; not required)

**All project checks passing.**
