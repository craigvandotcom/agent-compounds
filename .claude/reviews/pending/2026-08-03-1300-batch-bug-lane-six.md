# Review Report: bug-lane six + ac-znk.3 Stage-1 registry work

**Date:** 2026-08-03
**Mode:** batch-close
**Range:** 3c8f5afcb52d1439f96354b71218ea201ee1bdfb..7b835c9fc1e182268562893ebcdff0f887abdb5a
**Plan:** none (`_plans/` is gitignored in this repo)
**Panel (manifest):** security, performance, architecture, correctness, test-quality, contracts, doctrine-delta — skipped: none
**Rounds:** 1
**Degraded:** no

---

## Summary

Trunk-direct review of the 34 commits since the last review-mark. Two bodies of work: (a)
this batch's six bug-lane fixes to `ac-tidy` / `ac-triage` / `ac-implement` /
`ac-batch-close` / `ac-beadify` / `ac-review`, all skill-text plus one new proof script;
(b) yesterday's already-shipped registry work — the ac-znk.3 Stage-1 demotion extraction
off `ac-loop`, the repo-wide provenance-strip sweep, and the new provenance doctrine +
lint/dream checks that sweep implements.

Full 7-lens panel: the standard core four, both diff-conditional lenses (the diff carries
runtime shell/python and exported skill contracts), plus the `skills/`-gated
doctrine-delta lens including its new check 0.

## Beads Completed

- `ac-tidy-tier2-gate-unsound-7ba` — ac-tidy Tier-2 archive gate unsound (proposal beads satisfied `N_matching`)
- `ac-triage-worktree-isolation-l3i` — ac-triage scheduled-daily gains ac-tidy's worktree preflight
- `ac-wno` — ac-implement per-child bead-work discriminator made unconditional + seam test
- `ac-gcj.9` — ac-beadify PLAN_PATH identified at Phase 0
- `ac-vqf` — ac-review resolves `consensus.py` by probing both roots
- `ac-d4r` — ac-batch-close Gather-Batch-Context writes converted to the sanctioned `tee` shape

## Changes

160 files changed, 7910 insertions(+), 1665 deletions(-) — of which 49 files /
963 insertions / 496 deletions are real content; the remainder is `.beads/.br_history`
JSONL churn.

## Test Coverage

`./lint.sh` — **314 checks, 0 failures** (post-fix). No test/type-check pipeline exists in
this repo (registry, no build).

The `test-quality` lens ran 5 probes in a disposable worktree against the batch's one new
test artifact and the changed `lint.sh` check, and returned **zero findings** — an
unusually strong result worth recording:

| Probe | Verdict |
| --- | --- |
| Rerun ×3, `bead-work-concurrent-dir.test.sh` | Stable, no flakiness |
| Sabotage — strip `CHILD_ID=` from ac-implement (derivation half) | RED (Cases 0, 1, 3) — correct |
| Sabotage — revert `run-id.md` "UNCONDITIONALLY" wording (doctrine half) | RED (Case 4 only) — assertion checks wording, not presence |
| Sabotage — reorder `CHILD_ID` after the RUN_ID suffix | RED (Cases 0 and 2 independently) — assertions not redundant |
| False-positive probe, `lint.sh` Check 5 | Skips gitignored paths, still FAILs on genuinely-missing non-ignored paths |

## Review

| Category      | Critical | High | Medium | Auto-Fixed |
| ------------- | -------- | ---- | ------ | ---------- |
| Security      | 0        | 0    | 1      | 0          |
| Performance   | 0        | 0    | 1      | 0          |
| Architecture  | 1        | 1    | 2      | 2          |
| Correctness   | 0        | 0    | 2      | 2          |
| Test-quality  | 0        | 0    | 0      | 0          |
| Contracts     | 0        | 1    | 2      | 3          |
| Doctrine-delta| 1        | 2    | 2      | 4          |
| **Total**     | **2**    | **4**| **10** | **11**     |

**VERDICT:** APPROVED

16 findings, 16 after dedup. 11 auto-fixed and validated; 3 filed as `review-finding`
beads; 2 recorded as accepted (below). No dimension missing, no retry needed.

### Auto-Fixed Issues

1. **[Critical] `ac-loop/references/delegation-prompts.md`** — the new Refine delegation
   prompt told children to "hold `br sync --flush-only`", which is precisely the
   insufficient interpretation the same batch's `ceremony-batching-pool.md` guard-rail
   warns against ("not merely deferring `br sync --flush-only`" — `br` mutation verbs
   auto-flush regardless). A child following the prompt verbatim could still corrupt a
   ceremony's ledger commit. Reworded to hold ALL `br` mutation verbs until the
   conductor's ledger commit lands, citing the canon by path.
2. **[Critical, consensus: architecture + doctrine-delta] `ac-tidy/SKILL.md`** — the
   bug-lane fix ADDED a dated incident narrative ("Four consecutive nights (2026-07-24,
   -26, -28, -29)…", plus a dated worked-example attribution) in the very batch that
   ratified "provenance never lives in skill text" and ran a strip sweep elsewhere.
   Narrative relocated to `ac-tidy/FRICTIONS.md` (the doctrine's own relocate-then-delete
   rule); the behavioral worked example stays. SKILL.md shrank.
3. **[High] `dream/references/lint-checks.md`** — Check 13 cited an "exemption taxonomy"
   in `structure-standard.md` including **"format-example dates"**, which does not exist
   in the source and directly contradicts it ("A date, a director, or a narrative clause
   is never exempt"). Check 13 is the automated weekly sweep for the provenance rule
   itself, so the drift would have waved through the exact violations it exists to catch.
   Invented exemption deleted; ledger-file clause clarified as scope, not in-text exemption.
4. **[High] `ac-loop/references/delegation-prompts.md`** — section headers narrated the
   edit's story (`## Refine prompt (ac-kb8 — was missing; lite run composed it from
   scratch)`). Verified `ac-kb8` greps nowhere else in `skills/`, `hooks/`, or `lint.sh`,
   so it fails the "bare rule-ID only when other files grep it as a name" exemption.
   Headers reduced to `## Refine prompt` / `## Beadify prompt`.
5. **[High] `lint.sh` Check 10/D2 — a check that could not fail.** The provenance-strip
   removed the `"(this sweep, 2026-07-03)"` string D2 asserts, so D2 should have gone
   loudly red. It did not. Root cause is a pre-existing shell bug: `grep -c` **prints** `0`
   *and* exits 1 on no-match, so `|| echo 0` appended a second line —
   `D2_COUNT` became the two-line string `"0\n0"`, `[ "$D2_COUNT" -lt 2 ]` threw
   "integer expression expected", evaluated false, and the `fail` branch never ran.
   Confirmed empirically. Two-part fix:
   - counting bug removed so the comparison receives a clean integer;
   - D2 **re-anchored** to the durable item names
     (`^- \[x\] \*\*(Land after merge|Conductor dedup)\*\*`) instead of a dated sweep
     annotation the provenance rule deliberately retires. Both items are still ticked, so
     the assertion is unchanged in meaning — only its anchor is now doctrine-stable.
   - **Negative control run:** unticking one item drops the count to 1 → RED; a missing
     file → RED. The check can now genuinely fail.
   - Swept the rest of `lint.sh`: the other 7 date occurrences are comments/messages, not
     assertions. This class is contained.
6. **[Medium] `ac-merge/SKILL.md:288`** — `br list --json > "$ARTIFACTS_DIR/beads.json"`,
   the dcg-blocked redirect-to-variable-path shape, was fixed in `ac-batch-close` by this
   batch (ac-d4r) but left live in its documented twin. Converted to the same `tee` shape.
7. **[Medium, 2 lenses] `ac-implement/SKILL.md:19`** — the I/O Contract Artifacts row still
   documented the pre-fix `/tmp/bead-work-<wave-slug>/` path after this batch's own Phase-0
   change made it `/tmp/bead-work-<claim-id>-<child-id>[-<run-id>]/`. Row updated.
8. **[Medium] `ac-implement/SKILL.md`** — net-positive tier-1 core addition with no
   `net-growth-ok` stamp. Minimal token added.
9. **[Medium] `ac-review/SKILL.md`** — doctrine-delta's new check 0 was added to METHOD but
   never wired into CHECKLIST or SLUGS, so a check-0 finding had no slug to file under.
   `provenance-leak` slug + one checklist bullet added.
10. **[Medium] `ac-triage/workflows/scheduled-daily.md`** — dated incident narrative
    (2026-07-27, "three consecutive cycles", blow-by-blow). Stripped to the rule form: a
    branch guard cannot work here because the checkout may legitimately sit on any branch
    or detached, and aborting forbids the writes needed to escalate.
11. **[Medium] `ac-review/SKILL.md`** — the check-0 addition tripped the no-net-growth
    gate; minimal `net-growth-ok` stamp added (same form as #8).

### Needs Decision

None escalated to a `decision` bead — every remaining item had a determinate resolution
that simply exceeded this review's authority to apply. Filed as `review-finding` beads
under per-run epic **`ac-i5l9`**, each labeled `review-finding,unrefined,post-merge` with
`discovered-from:` linkage and a grep-verified `## Test Scope`:

- **`ac-i5l9.1` [High, P2]** — ac-triage/ac-tidy's scheduled worktree pattern contradicts
  `ac-pipeline/SKILL.md`'s "Worktrees are deliberately rejected" invariant (:331, :345),
  with no carve-out on either side. Likely resolution: narrow the invariant to pipeline
  ceremonies and name the scheduled-heartbeat exception. Not auto-fixed because
  `ac-pipeline/SKILL.md` is conductor-core with a net-growth ceiling and the scoping is the
  pipeline owner's call.
- **`ac-i5l9.2` [Medium, consensus ×2, P2]** — the `pipeline-proposal` exclusion is
  bead-semantics domain canon restated at 3 sites in ac-tidy's workflow core instead of
  registered once in `beads-standards/reference/bead-conventions.md`. Fails the repo's own
  workflow/domain litmus. Not auto-fixed: edits another domain's canon plus a three-site
  collapse.
- **`ac-i5l9.3` [Medium→P3]** — `bead-work-concurrent-dir.test.sh` splices text grepped
  from `ac-implement/SKILL.md` into `bash -c`/`zsh -c` unvalidated. Two lenses disagreed
  here and the bead records the resolution: keep reading the real file (that property is
  what makes the sabotage probes convict) but assert the extracted lines match the expected
  shape before executing, so drift becomes a loud failure instead of silent execution.

### Accepted — recorded, not filed

- **[Medium, performance] `hooks/delegation-reminder.md` +4 lines (~55 tokens).** This is
  the hottest lane in the registry — `cat` on every `UserPromptSubmit` across claude/codex/
  droid at org and app scope. Quantified at ~100 prompts/day fleet-wide that is ~5,500
  extra tokens/day, recurring. Recorded rather than filed because the growth was the
  deliberate point of commit `eb6cdcd` (least-change edits rule + answer-first clause); the
  cost is real and now on the record, but reverting it would undo an intended change.
- **[Medium, security] test-script eval path** — filed as `ac-i5l9.3` above rather than
  auto-fixed; noted here because the naive fix (hardcoding a copy of the lines) would
  destroy the seam proof and reintroduce drift.

### Also noted (out of range, not a finding for this batch)

`skill-builder/references/structure-standard.md` § "The workflow/domain litmus (the second
discriminator — **ratified 2026-07-30, ac-znk.4**)" carries a dated provenance tail in the
heading of the very file that forbids provenance tails. Verified **not added in this
range** — pre-existing, so out of scope here. Worth catching on dream's next Check 13
weekly sweep.

## Known post-merge tails

- [ ] ac-i5l9.1: ac-triage/ac-tidy scheduled worktree pattern contradicts ac-pipeline's 'no worktrees' invariant
- [ ] ac-i5l9.2: pipeline-proposal exclusion is bead-semantics canon written into ac-tidy's workflow core (3 sites)
- [ ] ac-i5l9.3: bead-work-concurrent-dir.test.sh executes unvalidated text extracted from SKILL.md

## Also carried (not this batch's beads)

The range is 34 commits and carries substantially more than the six bug-lane beads:

- `9b62da1`, `a4f34ca` — **ac-znk.3 Stage-1 diet**: cluster command + pipelining guard-rails
  extracted from `ac-loop` core into `ac-pipeline/references/board-scan.md` +
  `ceremony-batching-pool.md`. `ac-loop/SKILL.md` net −52 lines. Verified two-sided
  (pointers + ToC entries + content all landed).
- `b7892bd`, `8bb0dfd`, `ec8f7b4`, `6093354` — **provenance-strip sweep** across the six
  conductor skills, the standard-tier ac-* skills, the pipeline/agent-mail/beads canons,
  and two residue tails. This sweep is what silently defeated lint D2 (auto-fix #5).
- `7963edf`, `456848d`, `3b52daf` — the **provenance doctrine** itself: structure-standard's
  third discriminator, ac-review's doctrine-delta check 0, and dream's Check 13 weekly
  corpus sweep.
- `7bc9277`, `4791bda` — **ac-znk.6**: `reflect` relocated to conductor level as a spawned
  final child. Verified fully wired across `ac-land` ↔ `ac-loop`.
- `3532347`, `b10d650` — sharpening batch A (ac-kb8 / ac-qsz / ac-wno partial).
- `a8823c3`, `698b2cd` — ac-znk.5: child-preamble beads line; beads-guard NOT earned.
- `c04f2ba`, `f7e7a80` — **loop-lite retired** (ablation complete, Craig-directed deletion).
- `d67f073`, `912362f` — ac-3jy: lint Check 5 tolerates gitignored diagram paths;
  unbreaks registry-lint CI red since 07-30. Probed clean by the test-quality lens.
- `eb6cdcd` — hot-lane hook edit (see Accepted above).
- `33965f3`, `c8f4b59`, `253d49b`, `591fc38` — ac-loop-lite run 20260802-084558-9799
  land-time snapshot, friction capture, and its A/B verdict.
- `.beads/` JSONL churn — 111 of the 160 changed files; ledger history, no review surface.

**Deliberate exclusion:** none. Nothing in the range was skipped.
