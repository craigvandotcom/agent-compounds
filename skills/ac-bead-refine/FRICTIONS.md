---
skill: ac-bead-refine
created: 2026-07-22
last_pass: 2026-07-31
entries: 10
---

# ac-bead-refine — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## filed-beads-carry-drifted-anchors-and-false-premises
- skills: [ac-bead-refine]
- impact: M
- frequency: every-run
- recurrence: 1
- related: []
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-bead-refine
- status: open
- proposed_fix: keep (and make explicit in the workflow) the rule that EVERY cited `file:line` anchor and every quoted artifact in a bead must be re-verified against HEAD during refine, and that a falsified premise closes or rewrites the bead rather than being smoothed over. This is not overhead — it is the highest-yield thing refine does, and it paid off on every batch of this run.
- narrative: filed beads carried drifted `file:line` refs at a steady rate of ~3 per batch, every batch (RUN 20260722-085844-39967, 27 beads refined across 3 batches). Several carried outright FALSE premises, not just stale line numbers: bd-iahbm's cited test asserted the OPPOSITE of the claimed behavior; bd-nnzjv quoted a 500 response body that did not exist; bd-vyyaw requested a field the type does not have; bd-zz6ah claimed "all 8" when it was 4 of 8; bd-0q96x said "62 commits" when it was 145. Every one of these would have become wasted or wrong implementation had refine trusted the filing. Downstream sibling fact: `refined-spec-staleness-query-ground-truth-first` (the same class of drift, observed at implement time instead).

## acceptance-criteria-that-cannot-fail
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-bead-refine
- status: open
- proposed_fix: add a refine lens that asks of every acceptance criterion "can this check actually FAIL, and does it fail for the RIGHT reason?" Specifically flag (a) grep/pattern-shaped ACs, which encode intent but no structural constraint and both over-match and under-specify; and (b) any AC asserting a numeric DOM property without first establishing that the property is meaningful on the element type in question. Require a bite-proof (demonstrate the check RED) for any AC that is the sole evidence for a bead.
- narrative: two ACs this run specified checks that were vacuously true. bd-ket5c's grep-shaped AC over-matched an unrelated component AND failed to express the real structural constraint (that 212 of 278 DB-only families REQUIRE the fallback be removed) — only reading the call sites plus running a coverage query surfaced it. bd-145wb's AC prescribed `scrollWidth <= clientWidth` on an anchor element, but both are 0 on non-replaced inline elements, so the assertion passes no matter what the page does. A refined AC that cannot fail is worse than no AC: it launders an unverified change as verified.

## no-new-beads-guardrail-must-be-in-round-1-prompt
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: inline the no-new-beads guard-rail in the round-1 reviewer prompt, not round 2.
- narrative: reviewers independently proposed SPLITTING beads into new sibling beads, which the no-new-beads scope guard-rail forbids. The guard-rail was only stated in round-2 prompts, so child A's round-1 reviewers burned a full round proposing splits before being corrected — the cost of the omission. Once the guard-rail was moved into the round-1 prompt for later children (C, D), the friction was avoided entirely; those reviewers never proposed a split.

## late-round-findings-are-contradictions-from-earlier-patches
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [heavy-review-does-not-mean-converged]
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: explicitly scope the final refine round to hunt for contradictions INTRODUCED BY earlier rounds' own patches, not just fresh issues in the original draft.
- narrative: round-4 findings turned out to be self-contradictions that earlier rounds' own patches had introduced into the bead — not defects in the original filing. Patch-accumulation contradiction is the characteristic failure mode of a converging refine: each round's fix is locally correct but can silently break an earlier round's fix. Caught before shipping this run, but only because a round existed whose explicit job was to look for exactly this.

## heavy-review-does-not-mean-converged
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [late-round-findings-are-contradictions-from-earlier-patches]
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: do not treat a heavily reviewed draft as converged because the panel is tired — keep MIN_ROUNDS honest and let rounds run their full course even when earlier rounds reported clean.
- narrative: rounds 3 and 4 each found a REAL defect — a Critical AC self-contradiction in round 3, then a citation drift in round 4 — in text that rounds 1 and 2 had already "verified" clean. Those two extra rounds cost time beyond MIN_ROUNDS but earned their keep: had the refine stopped at round 2 on the strength of two clean passes, both defects would have shipped.

## deferred-br-writes-leave-reviewers-blind-to-br-show
- skills: [ac-bead-refine]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: when deferring DB mutations to an end-of-run flush, state explicitly in the reviewer prompt that `br` is stale for this run and point reviewers at the draft files instead of `br show`/`br lint`.
- narrative: holding `br` writes to an end-flush (to avoid mid-run DB churn) means reviewers cannot read `br show` for the bead under review — it still reflects the pre-refine state — and `br lint` shows stale failures mid-run that read as still-open problems. Reviewers had to be redirected to the draft files by hand, costing minor rework each time it wasn't anticipated.

## post-deploy-verification-ac-cannot-close-in-implement-run
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [acceptance-criteria-that-cannot-fail]
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: refine should split "code fix" and "deploy verification" into two separate beads up front, rather than making an un-runnable post-deploy AC the one that gates close on a code bead.
- narrative: prod-finding beads refined with POST-DEPLOY verification acceptance criteria cannot close within an implement run by construction — there is no deployed artifact yet to verify against. This run it cost 2 extra beads filed to carry the deploy-verification step, and 2 partial closes on the original beads. The AC here was not vacuous like `acceptance-criteria-that-cannot-fail` — it was meaningful, just scoped to a phase the implement run cannot reach.

## invented-third-risk-class-instead-of-existing-binary
- skills: [ac-bead-refine]
- impact: S
- frequency: rare
- recurrence: 1
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-07-29
- stage: ac-loop
- status: open
- proposed_fix: express nuance as an advisory recorded against the existing RISK-TOUCH/render-only binary, rather than inventing a new taxonomy to carry it — inventing taxonomy to express nuance is how doctrine rots.
- narrative: the conductor invented a "third risk class" to express a nuance that didn't cleanly fit either RISK-TOUCH or render-only, instead of accepting the binary and recording the nuance as an advisory alongside it. Cost one reviewer-round to catch and walk back.

## dcg-guard-blocks-the-skills-own-setup-snippet
- skills: [ac-bead-refine, ac-merge, ac-batch-close, ac-review, ac-qa-browser, ac-hygiene, ac-plan-clean, ac-plan-refine-internal, ac-plan-refine-external]
- impact: M
- frequency: every-run
- recurrence: 26
- related: []
- first_seen: 2026-07-21
- last_seen: 2026-07-29
- stage: ac-bead-refine
- status: open
- proposed_fix: one _shared doc (shell-guardrails.md) naming the blocked constructs and the sanctioned substitutes, referenced once from each affected skill, plus rewriting this skill's own dump-collection step to append via tee -a instead of a brace-group append-redirect. NOT six inline snippet patches (six spines = six net-growth events) and NOT inline examples (see narrative).
- narrative: the command guard rejects a stdout redirect whose target path is built from a shell variable, which is the shape of nearly every artifacts-dir write in the ac-* pipeline. Because the blocked lines are the skills' OWN provided setup lines, each child wastes about a call rediscovering the same workaround: ~15+ in RUN 20260721-133107-10979, 8+ in RUN 20260722-085844-39967, 5 in one interactive session 2026-07-26, and 3-of-4 refine children (~2 min + 2 retries each) in RUN 20260728-234407-54469 — cumulative 26+ across four consecutive runs. It bites wider than its name: the redirect operator is matched anywhere on the command line, so long quoted payloads (bead comment bodies, commit messages, inline SQL) are blocked with no redirect present; in-place editors (perl -i, sed -i) are blocked though they contain no redirect at all; and a trailing error-stream redirect on a compound command trips the same rule, so decorating the command is not a fix. Decisive constraint on the FIX SHAPE: the rules match on command TEXT, so documentation that quotes a blocked construct is itself blocked — two bead comments were rejected for merely describing one. That is why the guidance must live in a single carefully-worded _shared doc that names constructs instead of showing them, rather than as inline examples in nine files.

## ac-check-command-never-executed-during-refine
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [acceptance-criteria-that-cannot-fail, filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-07-31
- last_seen: 2026-07-31
- stage: ac-loop
- status: open
- proposed_fix: execute every AC check-command during refine — an AC whose command does not run is not refined. Verifying an AC's INTENT is not a substitute for running its literal check.
- narrative: two acceptance criteria encoded commands that were wrong at HEAD: one referenced a non-existent capacitor build target, the other a `grep -c` line-count assertion that every 404 in the app fails. Refinement verified the ACs' intent but never executed their check-commands, so both drifted commands passed refine unnoticed. Cost ~5 minutes each to disprove once actually run.
