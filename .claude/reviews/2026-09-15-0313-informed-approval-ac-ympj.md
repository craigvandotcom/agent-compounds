# Review Report: Informed approval at the plan seam (epic ac-ympj)

**Date:** 2026-09-15
**Mode:** standalone (batch-boundary contract, operator-named range)
**Range:** 751005a2ab9bfcc29faf2232a665f2a9faa629b2..3884c7b4df5e26fe1a3f236bf0bdc55f6689302e
**Plan:** _plans/_done/2026-09-14-1430-informed-approval-and-plan-seams.md
**Panel (manifest):** security, performance, architecture, correctness, test-quality, contracts — skipped: none
**Consensus:** consensus-round-1.json — 30 in the fix pool (6 Critical, 23 High, 1 Medium by same-location consensus), 8 deferred; reviewers_missing: none

## Summary

The batch shipped every deliverable of the plan: `plan-approve.sh` with `approve` / `ready` /
`check`, the per-stage vocabulary (`loop-ready` retired), no-invoke hand-offs in the plan lane,
ac-plan's vision-first procedure with its three references, the mechanical seams oracle, and the
stage-table rows. All thirteen beads and the epic closed through the close gate; the ledger is
committed at 1433fff; CI on the range fails only on `27-instance-tokens`, a baseline failure from
a commit outside this batch (d1e6476).

The panel found that the three pieces carrying the human gate — the script, the card grammar in
`decisions.md`, and the ac-human tap — do not agree with each other, and that the script's
integrity checks fail open in several ways. Every finding below was reproduced by running the
script against fixtures, or by mutation in a disposable worktree; none is a reading.

**VERDICT: NEEDS_DECISION.** Criticals remain; the fix is a follow-up epic (a closed epic accepts
no children), and one fork is the operator's.

## Beads Completed

ac-ympj.1 – ac-ympj.13, epic ac-ympj (closed by the terminal pick; its three probes green at HEAD).

## Changes

17 files, +884 / −185, excluding `.beads/`. Script + harness (`skills/_tools/plan-approve.sh`,
`.test.sh`); ac-plan spine and three references; ac-polish plan/bead/seams hand-offs and the plan
checklist; ac-beadify step 1 and hand-off; ac-human SKILL, action-loop, tiers-template; board-scan;
ac-board; stage-table. Plus the coordinator's test fix 3884c7b (git user.name injected via env).

## Test Coverage

`plan-approve.test.sh` 40 cases green locally and in CI. Test-quality mutation-probed it: 18
mutations survive the suite (all exit codes zeroed; five of six digest legs dropped; the
new-path exemption deleted; the env-fallback re-added under another name; four `ready`/`check`
preconditions weakened). The suite asserts stdout tokens only and every Decisions fixture is a
one-line card the shipped `decisions.md` never prescribes. Causal sufficiency held for .7 and
.10 (every probe string red at base, green at head); it does not hold for .1's AC5 ("both
polarities") and AC2 is token-only.

## Review

Findings, ordered by severity; `catch:` names the stage that should have caught it.

### Critical

1. **Digest fails open** — `plan-approve.sh` `_sha`: the NOT-GATED `exit 2` runs inside `$( )`, so
   with no sha256 tool on PATH the error text becomes the hash; approve, ready and check all exit 0
   and a rewritten Vision verifies. FIX · catch: implement (the assurance header promised
   fail-closed; nothing tested it).
2. **Frontmatter injection via the approver argument** — `awk -v` escape expansion turns `\n` in
   `$2` into new frontmatter keys; a never-polished plan reaches READY and OK. FIX · catch:
   implement.
3. **`## Success Criteria` (capital C, 5 of 15 live plans) is outside the digest** — its digest is
   sha256 of empty input; the criterion is rewritable after approval with `check` green. FIX ·
   catch: plan (A1's census named the variant class and the plan documented only `Deliverables
   (artifacts)`).
4. **Card grammar mismatch** — the parser needs a bold `**settled:` and one block per top-level
   bullet, while `decisions.md` (same batch) prescribes a plain `settled:` on a `state` sub-bullet
   with `vision` on a sibling sub-bullet. A real card with no vision quote is APPROVED; a fully
   cited real card is REFUSED `uncited-decision`. FIX · catch: beadify (bead-polish round 3
   declined this exact under-specification as "the regex is the script's business").
5. **The ac-human tap can never approve** — action-loop.md tells the tap to append a
   `DECISION (<human>): …` line then run `approve`; the new parser counts the card's own
   `needs-human` token, so the tap always refuses. FIX · catch: beadify (.2 and .1 were cut with no
   shared grammar bead).
6. **Harness asserts no exit codes and no real card shapes** — see Test Coverage. FIX · catch:
   close (close-gate ran the AC probes; the probes were greps).

### High

7. `## Seams` and the `Human gates:` line are outside the digest while the brief promises them
   covered; Seams rows can be rewritten post-approval. FIX · catch: plan.
8. APPROVED printed with zero keys written when line 1 is `--- ` (guard accepts trailing space, awk
   requires exact); `mv` status unchecked. FIX · catch: implement.
9. Gate predicates grep the whole file: a fenced example of `polish_rounds:` passes `not-polished`;
   a fenced mention of `## Seams` passes `no-seams`. FIX · catch: implement.
10. `seams-incomplete` matches by basename (one `SKILL.md` row covers every skill deliverable), drops
    root-level and markdown-linked paths silently, and demands rows for command references in
    touchers lines (the batch's own plan refuses on four paths, one of them `touchers.sh`). FIX ·
    catch: implement.
11. `seams-incomplete` silently no-ops outside a git worktree — APPROVED, not NOT-GATED; ac-human runs
    org-wide. FIX · catch: implement.
12. Decisions preamble scanned as card block 0 (a sentence mentioning `needs-human` blocks
    approval); indented sub-bullets split a card. FIX · catch: implement (same root as #4).
13. `board-scan.md` still carries the pre-batch `needs-human` grep while claiming it is "the SAME
    extraction"; board and gate now disagree. FIX · catch: implement (.2 owned the file).
14. Approver identity is unauthenticated: an autonomous run passing `git config user.name` mints
    a human-signed approval, and the shipped docs prescribe that call. DEFER → decision (the plan
    settled "default git user.name"; whether approval needs an interactive receipt is a design
    fork for the operator) · catch: plan.
15. ac-plan step 4 (seams scan) consumes the Deliverables step 5 writes. FIX (state that the
    conductor's intended deliverable set is the input, and `seams-incomplete` backstops drift) ·
    catch: polish (plan-polish declined it as "same shape as today").
16. Seams scan has no zero-toucher gate: 3 of 15 objects on this batch's own plan spawn a reader
    with an empty file list. FIX (skip the reader when the derived list is empty) · catch: plan.
17. `plan-seams-reader.md`'s framing paragraph, sent verbatim to readers, describes the deleted
    step 2 and contradicts its own Output section. FIX · catch: implement.
18. Stage-table declares the no-invoke rule for all rows; six non-plan-lane skills still invoke.
    DEFER → decision (scope the rule to the plan lane, or convert the other lanes) · catch: plan
    (the plan's D13 wrote the rule above the whole table).
19. Test harness: no negative polarity for five of six gated sections; no not-yet-created
    Deliverable fixture; env-fallback guard is a literal grep for two names; case 5 is
    cwd-dependent. FIX · catch: close.

### Medium (consensus)

20. A card carrying both `needs-human` and `**settled:` is APPROVED (settled checked first). FIX ·
    catch: implement.

### Deferred (8, from consensus)

- Per-claim confirmation readers unbatched (perf) — DEFER, fold into the seams-pass rework.
- ac-plan's loaded path grew 188% in `references/`, where Check 14 is blind — DEFER → hygiene
  decision on what becomes mode-scoped.
- Brief renders toucher-count ordering, per-row test status and improvements the plan file does
  not record; reader emits no disposition column — DEFER, fold into the seams-pass rework.
- `no-test-globs` unreachable (the conductor builds FILES, never passes globs) and plan-checklist's
  oracle needs globs nothing records — same rework.
- `ready`/`check` preconditions lack failing polarity; case 5 cwd-dependence — fold into #19.

### Checked, no finding

`loop-ready` fully retired from live skill text; the bare positional `plan-approve.sh <plan>` has no
caller; every "hand the … set" / "hands it to" auto-invoke phrase is gone; the five plan-lane
`Next` cells match their skills' hand-off lines; digest stable across a two-round re-polish;
`REFUSED regate Deliverables` on a Deliverables edit and READY on a Problem edit; `check`
non-zero at `approved`, on missing keys, and on a post-stamp gated edit; `plan-approve.sh`
timing 113 ms approve / 9 ms check on a 399-line plan.

## Known post-merge tails

- `ac-heyt` (an older epic, not this batch) bounces its terminal pick on a probe naming the
  renamed `scripts/run-all-harnesses.sh`; needs a refine pass to repoint the probe.
- `27-instance-tokens` CI failure from `skills/context-engineering/workflows/context-mining-daily.md`
  (commit d1e6476, outside this batch).
- Local `07-consumer-symlinks` failure from broken symlinks under another job's tmp tree.

## Also carried (not this batch's beads)

3884c7b — coordinator fix-forward: `plan-approve.test.sh` case 8 injects `user.name` through env so
CI, which has none configured, passes.

## Proposed follow-up (not yet filed — operator to confirm)

One follow-up epic, `discovered-from: ac-ympj`, with beads: (a) script hardening: fail-closed
digest, approver passed via ENVIRON not `-v`, exact frontmatter guard + checked `mv`,
frontmatter/section-scoped predicates, NOT-GATED outside a worktree, needs-human before settled;
(b) digest coverage: `## Success Criteria` prefix, `## Seams`, `Human gates:`; (c) one card
grammar — decide the shape in `decisions.md`, make the parser, board-scan's extraction and the
ac-human tap all read it; (d) `seams-incomplete` matches full paths from deliverable lines only;
(e) harness: exit codes, real-shaped fixtures, per-section negative polarity, fallback probe by
behaviour, cwd-independent; (f) seams pass: zero-toucher gate, deliverable-set ordering stated,
reader preamble, brief ↔ reader columns, globs recorded; plus two decision beads: approver
receipt (#14) and no-invoke rule scope (#18).
