# Review: verification-gate CLASS_RUNTIME fix (ac-bxg)

**VERDICT:** APPROVED
**Run:** 20260719-185059-58770 · reviewer RusticSpring (claude-opus-4-8)
**Batch:** claim ac-bxg-20260719 — 1 bead (ac-bxg, P1 bug)
**Commit:** 6af076c — `fix(verification-gate): CLASS_RUNTIME fires on ANY runtime file in mixed filesets`
**Scope:** `skills/_shared/verification-gate.md` (1 file, +1/-1) — ZERO-RUNTIME docs-only diff
**Panel:** focused single-lens correctness (no full 6-body panel — ZERO-RUNTIME, no RISK-TOUCH; process weight matched to a one-line embedded-shell fix)

## Summary

| Category | Count |
|----------|-------|
| Critical | 0 |
| High     | 0 |
| Medium   | 0 |
| Low      | 0 |

No findings. Clean approve.

## The change

Line 70 CLASS_RUNTIME classifier, `grep -qvE '<doc/test/CI pattern>'` → `grep -vE '<pattern>' | grep -q .`.
Decouples quiet-short-circuit (`-q`) from invert (`-v`): the combined `-qvE` exits 0 only
when EVERY line fails the pattern, so a mixed doc+runtime fileset exited 1, leaving
CLASS_RUNTIME=0 and the runtime verification gate silently skipping — a violation of the
file's own never-silently-skip / ambiguity-counts-as-match invariant.

## Verification (all live, this env = ugrep 7.5.0 macOS shim)

- **Bug reproduced (old form):** mixed `a.md\nb.ts` → exit 1 → CLASS_RUNTIME=0 (confirmed real, not spurious).
- **AC1** — no `grep -qv`/`-qvE` (quiet+invert) combo remains in the file: PASS.
- **AC2** — mixed changeset → CLASS_RUNTIME=1 (order-independent): PASS.
- **AC3** — docs/test-only changeset → CLASS_RUNTIME=0; empty fileset → 0: PASS.
- **AC4** — behavior holds under the machine grep (ugrep 7.5.0): PASS.
- **Completeness** — tree-wide grep for the same `grep -qv` idiom: none elsewhere; fix is complete.
- **Consistency** — the positive `grep -qE` ANY-match forms elsewhere in the file are correct and correctly untouched.
- **Gate** — `lint.sh`: 314 checks, 0 failures.

## Decisions

None needed.
