# Review Report: ac-swarm landing + rename + v2 lint work

**Date:** 2026-09-10
**Mode:** standalone
**Range:** a2120d2a9c67ed6869bc1c3b04a151a6d9cb3fb7..6d02fe7cb819c424d8bc5d9e566a7bc7d9104984
**Plan:** none (multi-source: ac-human sitting, ac-implement swarm landing, concurrent v2 lint work)
**Panel (manifest):** security, performance, architecture, correctness — skipped: test-quality (factory/docs/shell; polish-fixpoint.test.sh is a shell harness), contracts (no product contract surface)
**Rounds:** 1
**Degraded:** no

---

## Summary

A factory/docs-only stretch: the ac-human rename, board-first/diet, the v2 lint rules (Check 35 probe axis, Check 34 ALL scope), three beads landed by coordinator override (`ac-1p7j.31`, `ac-wp8i.2`, `ac-wp8i.13`), plus concurrent-session ruff/CI fixes. No product surface — findings are factory/report-only, not shipped-defect beads.

## Beads Completed

- `ac-1p7j.31` — ac-polish `ui` mode over the ui checklist + six-mode gate
- `ac-wp8i.2` — `impact:<class>` placeholder on every automated-origin `br create` template
- `ac-wp8i.13` — board-scan docket-health counters + plan-approve receipt keys
- `ac-gwre` — Check 35 probe axis (closed duplicate; landed as `e2aead7`)

## Changes

`90 files changed, 593 insertions(+), 246 deletions(-)` — skills prose, lint checks/libs, shell tools, hooks text, harnesses.json, beads ledger.

## Test Coverage

- `bash lint.sh` — 0 failures (un-ported blocks + all v2 checks).
- `bash scripts/run-all-harnesses.sh` — 71 discovered · 71 passed · 0 failed · 0 quarantined.
- `consensus.py --round 1` — panel of 4, all reported.

## Review

| Category     | Critical | High | Medium | Routed |
| ------------ | -------- | ---- | ------ | ------ |
| Security     | 0        | 0    | 0      | 0      |
| Performance  | 0        | 0    | 2      | 2      |
| Architecture | 0        | 1    | 3      | 4      |
| Correctness  | 0        | 1    | 2      | 3      |
| **Total**    | 0        | 2    | 7      | 9      |

(Low: 1, architecture, left in the report per contract.)

**VERDICT:** APPROVED

Factory-only range; the review surface yields no product finding. All four dimensions reported; findings are report-only (no product bead warranted) per `review-dimensions.md` § Review surface.

### Fixed / Routed

Reviewer is read-only; nothing fixed in place. Routed as report-only (factory findings) / follow-up:

- [High] `lint/lib/consumers.py:47` — Check 07/12 SKIP-green disclosure never reaches `run.py`'s findings. Route: follow-up lint fix.
- [High] `hooks/delegation-reminder.md:4` — rewritten every-prompt payload points at `skills/CORE/tools.md`, which resolves nowhere on disk. Route: follow-up (the file is live in every session).
- [Medium] `hooks/delegation-reminder.md:0` — reformat deleted the standing git-boundary hot-lane guard.
- [Medium] `lint/run.py:151` — 07/12 bare-checkout SKIP promised "disclosed" but invisible to the runner.
- [Medium] `lint/lib/scope.py:125` — Check 34 ALL scope still skips a deletion-only diff (never intersects `os.walk`-derived ALL).
- [Medium] `lint/checks/35-board-integrity.py:66` — probe backstop hand-duplicates the capture guard's `IMPLEMENTABLE` set + `PROBE` regex.
- [Medium] `lint/checks/36-br-envelope.py:55` — route-count sense counts comment/header mentions, so the floor is met by prose.
- [Medium] `skills/ac-pipeline/references/board-scan.md:129` — docket-health reads every `_plans/*.md` full-text on every Scan A run.
- [Medium] `skills/ac-pipeline/references/board-scan.md:132` — beadify-refusals regex triplet rescans full plan text 3× per file.

### Needs Decision

none (no qa-blocker; no product `NEEDS_DECISION` item)

### All Findings

#### Security
None. No trust boundary, entry point, or credential path in the diff.

#### Performance
- [Medium] `board-scan.md:129` — `_plans/*.md` full-text glob per Scan A run (~11MB/21 files locally; the pipeline's most frequent read).
- [Medium] `board-scan.md:132` — the beadify-refusals decision regex runs 3× per plan file.

#### Architecture
- [High] `lint/lib/consumers.py:47` — SKIP-green disclosure lost at the `run.py` boundary.
- [Medium] `lint/lib/scope.py:125` — ALL-scope deletion-only-diff skip window.
- [Medium] `lint/checks/35-board-integrity.py:66` — duplicated guard constants.
- [Medium] `lint/checks/36-br-envelope.py:55` — floor met by comments.
- [Low] `lint/checks/07-consumer-symlinks.test.sh:86` — fixture asserts SKIP via a truncated grep.

#### Correctness
- [High] `hooks/delegation-reminder.md:4` — dead tool-registry pointer.
- [Medium] `hooks/delegation-reminder.md:0` — deleted git-boundary guard line.
- [Medium] `lint/run.py:151` — invisible SKIP disclosure.

## Also carried (not this batch's beads)

- `d903618` — delegation-reminder rewrite to the `<reminder>` hot-lane shape (concurrent session; two findings above).
- `9922092`, `8489667`, `84e3403`, `6d02fe7` — concurrent-session ruff-clean + consumer-less-CI SKIP fixes.
- `9fb8a93` — harness tier rename (concurrent).
- `180e2ba` — ac-human-session → ac-human rename (this session).
- `b62ff34`, `769a10d`, `e2aead7`, `70ea57f` — bead refinement + Check 35 landing (concurrent session).
- `cec5a20` — swarm commit-lane frictions logged (this session).
- `4c73958`, `6473e70` — human rulings from the ac-human sitting.
