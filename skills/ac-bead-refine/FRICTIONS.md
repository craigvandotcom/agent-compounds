---
skill: ac-bead-refine
created: 2026-07-22
last_pass: 2026-08-26
entries: 33
---

# ac-bead-refine — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## filed-beads-carry-drifted-anchors-and-false-premises
- skills: [ac-bead-refine, ac-loop-2]
- impact: M
- frequency: every-run
- recurrence: 5
- related: []
- first_seen: 2026-07-22
- last_seen: 2026-08-20
- stage: ac-bead-refine
- status: open
- proposed_fix: keep (and make explicit in the workflow) the rule that EVERY cited `file:line` anchor and every quoted artifact in a bead must be re-verified against HEAD during refine, and that a falsified premise closes or rewrites the bead rather than being smoothed over. This is not overhead — it is the highest-yield thing refine does, and it paid off on every batch of this run.
- narrative: filed beads carried drifted `file:line` refs at a steady rate of ~3 per batch, every batch (RUN 20260722-085844-39967, 27 beads refined across 3 batches). Several carried outright FALSE premises, not just stale line numbers: bd-iahbm's cited test asserted the OPPOSITE of the claimed behavior; bd-nnzjv quoted a 500 response body that did not exist; bd-vyyaw requested a field the type does not have; bd-zz6ah claimed "all 8" when it was 4 of 8; bd-0q96x said "62 commits" when it was 145. Every one of these would have become wasted or wrong implementation had refine trusted the filing. Downstream sibling fact: `refined-spec-staleness-query-ground-truth-first` (the same class of drift, observed at implement time instead).
  **RUN 20260803-113231-34132, +1 — drift is not only a FILING-time problem, it happens DURING the refine.** The shared checkout moved 5 commits mid-run under a width-2 conductor: `lint.sh` grew from 314 to 372 lines and its anchor lines shifted twice while beads referencing them were being authored. ~8 minutes of re-verification, and any bead that had been stamped `refined` an hour earlier was already stale. The sharpened rule this yields is about what a bead may CITE, not just when it is checked: beads must carry **grep targets, never line coordinates, and must never assert a check COUNT** (e.g. "lint.sh has 42 checks") — a target survives a moving trunk, a coordinate or a count does not. This is the cheap structural fix that makes the re-verification rule above less load-bearing.
  **RUN 20260803-221658-19787 — CONFIRMATION: the final-round re-execution of HEAD-anchored claims is now load-bearing under a shared checkout, not belt-and-braces.** Children that re-ran every HEAD-anchored claim in their FINAL round (rather than only at draft time) caught drift that had appeared during the refine itself, exactly as the previous run predicted. What this run adds is that the practice pays even when nothing about the bead changed: on a shared checkout with concurrent siblings, the tree moves under a stationary draft, so a claim verified in round 1 is not verified in round 4 and the elapsed time is the whole risk. The operating rule that follows is cheap and worth stating as sequence rather than diligence — **the last thing a refine does before stamping is re-execute its own citations**, because every check has a shelf life measured in sibling commits, and a stamp asserts freshness at stamp time rather than at check time.
  **RUN 20260811-113939-36193 (BCA, ac-loop-2 phase-gated), +1 — the first run to MEASURE the base
  rate, and it is 100%.** Anchors had drifted in EVERY bead audited, with 13 separate drifts in one
  bead. That converts this entry from "happens often" to "assume it, always": there is no bead
  population for which skipping the re-open is defensible, and a "verified" claim inherited from a
  prior refine round is not evidence of anything. Two further data points from the same run. (1) The
  adversarial break-attempt round caught a territory omission that would have shipped a
  self-contradictory, byte-parity-CI-enforced prompt pair asserting the OPPOSITE of Craig's ruling —
  a refine without that round would have stamped the bead refined. (2) Two refined beads had a FALSE
  central claim (bd-pntbn asserted missing dispositions; 26/26 beads carried them) and a DEAD premise
  (bd-a3b0p, closed as superseded) — so premise falsification is not a rare outcome of the check, it
  is a routine one. Recorded in ac-loop-2's log as a pointer entry: the same discipline is that
  skill's implementation-contract element 1, and this run is its strongest validation to date.

## acceptance-criteria-that-cannot-fail
- skills: [ac-bead-refine]
- impact: H
- frequency: every-run
- recurrence: 5
- related: [filed-beads-carry-drifted-anchors-and-false-premises, ac-check-command-never-executed-during-refine, line-oriented-checks-break-on-wrapped-text]
- first_seen: 2026-07-22
- last_seen: 2026-08-04
- stage: ac-bead-refine
- status: open
- proposed_fix: add a refine lens that asks of every acceptance criterion "can this check actually FAIL, and does it fail for the RIGHT reason?" Specifically flag (a) grep/pattern-shaped ACs, which encode intent but no structural constraint and both over-match and under-specify; and (b) any AC asserting a numeric DOM property without first establishing that the property is meaningful on the element type in question. Require a bite-proof (demonstrate the check RED) for any AC that is the sole evidence for a bead. **The bite-proof must be run BEFORE the work exists and its RED recorded** — a grep executed only after the fix proves nothing, and a grep whose pattern can match the fix's own comment or close reason is self-satisfying rather than vacuous, which is worse because it will go green for a change that did nothing.
- narrative: two ACs this run specified checks that were vacuously true. bd-ket5c's grep-shaped AC over-matched an unrelated component AND failed to express the real structural constraint (that 212 of 278 DB-only families REQUIRE the fallback be removed) — only reading the call sites plus running a coverage query surfaced it. bd-145wb's AC prescribed `scrollWidth <= clientWidth` on an anchor element, but both are 0 on non-replaced inline elements, so the assertion passes no matter what the page does. A refined AC that cannot fail is worse than no AC: it launders an unverified change as verified.
  **RUN 20260803-221658-19787, +4 — and the vacuous-AC class splits into two distinct shapes, only one of which the 2026-07-22 lens catches.** Escalated to H / every-run: four occurrences in one run, in refine output that had otherwise been executed. (1) *Self-satisfying:* a bead's bite-proof AC grepped for a phrase that the implementer's own fix COMMENT would contain — so the check goes green the moment anyone writes about the fix, whether or not the fix works. This is not the "cannot fail" shape the existing lens hunts; the check CAN fail, it just fails on the wrong thing, and the artifact that satisfies it is produced as a side effect of closing the bead. Bead comments, close reasons and commit messages are all inside the grep's blast radius, so any AC pattern that could appear in prose about the change is disqualified. (2) *Pre-green:* three ACs authored during refine were GREEN when first executed, before any implementation existed — the pattern already matched something in the tree. These passed the execute-at-draft mandate (the command ran, it returned successfully) while proving nothing at all, which is the precise gap between "the AC's command executes" and "the AC discriminates". The cheap mechanical fix follows from the pairing: **executing an AC is necessary but not sufficient — record its result at draft time and REJECT any AC that is already green**, because a check that is green before the work is a check that cannot testify about the work. That one rule catches shape (2) outright and most of shape (1).

## line-oriented-checks-break-on-wrapped-text
- skills: [ac-bead-refine, ac-implement, ac-review]
- impact: M
- frequency: frequent
- recurrence: 3
- related: [acceptance-criteria-that-cannot-fail, filed-beads-carry-drifted-anchors-and-false-premises, panel-undercounts-occurrences-of-a-multi-site-defect]
- first_seen: 2026-07-16
- last_seen: 2026-08-04
- stage: ac-bead-refine
- status: open
- proposed_fix: never let a refine-authored check depend on where a line break falls. Two rules: (a) a grep target must be a short distinctive fragment that cannot straddle a wrap — never a long sentence, and never read from a display-formatted source such as `br show`; read the underlying field with `--json` when the check needs the true text. (b) An occurrence COUNT must be derived position-wise (count matches, not matching lines) so a re-wrap of the source cannot change the answer. Sibling memory: `loop-retro-grep-test-scope-soft-wrap`.
- narrative: two occurrences this run, same root and opposite signs, which is what makes the pair worth one id. (1) FALSE NEGATIVE: an AC grepped for a phrase in `br show` output. `br show` hard-wraps its display at a fixed width, so the phrase was split across two physical lines and the grep reported "not found" for text that was present and correct — the check was reading a RENDERING, not the data. (2) FALSE POSITIVE: an occurrence-count check over source files reported a defect count that was wrong because the source had been re-wrapped; the same content spread across a different number of lines changed a line-based count. The child that hit it re-derived the count position-wise (matches, not lines) and got a stable answer that survives reformatting. The generalisation refine needs is that **any check keyed to physical lines is keyed to formatting**, and formatting is exactly what moves under a shared checkout, a prettier pass, or a display width. This extends the older `loop-retro-grep-test-scope-soft-wrap` memory (2026-07-16, +1 there): that entry's advice was to keep the target phrase on one line — an author-side fix that does not survive a formatter and cannot help at all when the source is a tool's wrapped display. The check-side fix (short fragments, `--json` for tool output, position-based counts) is the durable one. Related in effect but not in root: `panel-undercounts-occurrences-of-a-multi-site-defect` in ac-review's log — there a count was wrong because a reviewer sampled, here because the counting method was formatting-dependent; both cases end at the same remedy of re-deriving counts mechanically.

## sibling-specs-carry-byte-identical-boilerplate
- skills: [ac-bead-refine, ac-beadify]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-bead-refine
- status: open
- proposed_fix: when refining a set of sibling beads split from one epic, diff the drafts against each other before stamping and factor the shared preamble UP into the epic (or a single cited reference), leaving each child only the lines that are actually about that child. A cheap detector: if two sibling specs share a large run of byte-identical lines, the shared run belongs to the parent, not to each child.
- narrative: refine of one epic's sibling children produced roughly 125 byte-identical lines duplicated across the specs — shared context, shared conventions and shared verification preamble, restated verbatim in every child. Nothing was wrong in any single bead, which is why it survived the round: each spec read as complete and correct on its own. The costs are all downstream and all real. Every duplicated line is re-read by every implement child (paid at model prices, once per child), it is a spec-drift surface (a correction applied to one sibling silently leaves the others stating the old thing — the same drift mechanism this log already tracks at filing time), and it inflates the refine round itself because reviewers re-read the same paragraphs N times and can raise the same finding N times. It also hides the actual per-child difference in a wall of sameness, which is the part a reviewer most needs to see. Worth logging even though the run shipped fine: the duplication is invisible from inside any one bead and only shows up when the siblings are diffed against each other, so it will recur by default on every epic split unless the diff is an explicit step.

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
- recurrence: 2
- related: [heavy-review-does-not-mean-converged, final-round-audits-the-input-not-the-draft]
- first_seen: 2026-07-29
- last_seen: 2026-08-20
- stage: ac-loop
- status: open
- proposed_fix: explicitly scope the final refine round to hunt for contradictions INTRODUCED BY earlier rounds' own patches, not just fresh issues in the original draft.
- narrative: round-4 findings turned out to be self-contradictions that earlier rounds' own patches had introduced into the bead — not defects in the original filing. Patch-accumulation contradiction is the characteristic failure mode of a converging refine: each round's fix is locally correct but can silently break an earlier round's fix. Caught before shipping this run, but only because a round existed whose explicit job was to look for exactly this.
  **RUN 20260820-005558-8974, +1 — measured, and with a second mechanism.** One refine child found that **5 of its 13 premise failures were its OWN**, introduced while correcting others' — so on this sample the correcting rounds generated nearly 40% of the defects the final round had to catch. The new mechanism beside contradiction is **twin drift**: two sections of one bead stated opposing things because a multi-round edit touched one and not its twin. Both are cured by the same addition and neither is caught by hunting fresh issues: **a per-bead SELF-CONSISTENCY sweep in the final round** — read the stamped body end to end against itself, with the specific instruction to find pairs of sections that must agree and check that they do. Note the severity asymmetry that makes this worth a dedicated round: a wrong RETRACTION is worse than the original error, because it tells the implementer to stop looking, so a correcting round's own output is the highest-consequence text in the bead and the least audited.

## heavy-review-does-not-mean-converged
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 3
- related: [late-round-findings-are-contradictions-from-earlier-patches]
- first_seen: 2026-07-29
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: do not treat a heavily reviewed draft as converged because the panel is tired — keep MIN_ROUNDS honest and let rounds run their full course even when earlier rounds reported clean. The floor also protects against the CONDUCTOR's own errors, not just the panel's: a round that exists purely to re-examine an accepted objection is what catches a correct decision that was wrongly inverted.
- narrative: rounds 3 and 4 each found a REAL defect — a Critical AC self-contradiction in round 3, then a citation drift in round 4 — in text that rounds 1 and 2 had already "verified" clean. Those two extra rounds cost time beyond MIN_ROUNDS but earned their keep: had the refine stopped at round 2 on the strength of two clean passes, both defects would have shipped.
  **RUN 20260803-113231-34132, +1 — this time the floor caught the conductor, not the draft.** A refine child accepted a plausible reviewer objection at round 2 and INVERTED a decision that had been correct, without working through the git semantics it turned on (a newer base NARROWS the range, it does not widen it). The error survived the round in which it was made; only the fact that MIN_ROUNDS forced a further round surfaced and reverted it. Cost one full extra round. The generalisable point: a conductor that adopts a reviewer's objection without re-deriving the underlying semantics has introduced a defect no reviewer will flag — they agree with it — so the round floor is the only thing standing between that and the stamp.
  **RUN 20260803-221658-19787 — CONFIRMATION: the floor earned its keep again, and this run says why it must stay a FLOOR rather than a judgement call.** The point is the economics, not the incident: across six refine children, EVERY subset carried at least one premise failure, and the refine spend is what made the implement spend clean — zero implement sessions were wasted on dead ends across 27 beads. A floor is the right instrument precisely because the value is unevenly distributed and invisible in advance: nobody can tell which child's extra round is the one that pays, so a per-draft "this looks converged" call will systematically underspend on exactly the drafts that most need the round. Every prior instance in this cluster is a clean-looking round immediately preceding a real find. Recurrence bumped to 3; keep MIN_ROUNDS.

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
- related: [dcg-blocks-the-skills-own-canonical-artifact-redirects]
- first_seen: 2026-07-21
- last_seen: 2026-07-29
- stage: ac-bead-refine
- status: open
- proposed_fix: one _shared doc (shell-guardrails.md) naming the blocked constructs and the sanctioned substitutes, referenced once from each affected skill, plus rewriting this skill's own dump-collection step to append via tee -a instead of a brace-group append-redirect. NOT six inline snippet patches (six spines = six net-growth events) and NOT inline examples (see narrative).
- narrative: the command guard rejects a stdout redirect whose target path is built from a shell variable, which is the shape of nearly every artifacts-dir write in the ac-* pipeline. Because the blocked lines are the skills' OWN provided setup lines, each child wastes about a call rediscovering the same workaround: ~15+ in RUN 20260721-133107-10979, 8+ in RUN 20260722-085844-39967, 5 in one interactive session 2026-07-26, and 3-of-4 refine children (~2 min + 2 retries each) in RUN 20260728-234407-54469 — cumulative 26+ across four consecutive runs. It bites wider than its name: the redirect operator is matched anywhere on the command line, so long quoted payloads (bead comment bodies, commit messages, inline SQL) are blocked with no redirect present; in-place editors (perl -i, sed -i) are blocked though they contain no redirect at all; and a trailing error-stream redirect on a compound command trips the same rule, so decorating the command is not a fix. Decisive constraint on the FIX SHAPE: the rules match on command TEXT, so documentation that quotes a blocked construct is itself blocked — two bead comments were rejected for merely describing one. That is why the guidance must live in a single carefully-worded _shared doc that names constructs instead of showing them, rather than as inline examples in nine files.
  **Counting note (2026-08-03):** this entry and `dcg-blocks-the-skills-own-canonical-artifact-redirects` in ac-loop's log are the same root friction under two ids, minted independently. `dcg-blocks-…-artifact-redirects` is the PRIMARY (it carries the longer run-by-run recurrence log and already names the shared `ac-pipeline/references/board-scan.md` substrate); RUN 20260803-113231-34132's +8 occurrences were counted THERE, not here, to avoid double-weighting one friction at promotion. A future pass should merge the two ids rather than keep bumping both.

## ac-check-command-never-executed-during-refine
- skills: [ac-bead-refine]
- impact: H
- frequency: frequent
- recurrence: 3
- related: [acceptance-criteria-that-cannot-fail, filed-beads-carry-drifted-anchors-and-false-premises, declared-red-not-reconciled-against-territory-or-existing-tests]
- first_seen: 2026-07-31
- last_seen: 2026-08-20
- stage: ac-loop
- status: open (regressed — the 2026-08-01 fix did not hold)
- fix: `references/workflow.md` § Method now reads "Name AND EXECUTE the check for every AC" and requires the command to run against HEAD each round; § Remove `unrefined`, Stamp `refined` makes it a BLOCKING pre-stamp gate, so an unexecuted AC command cannot reach `refined`. An AC that genuinely cannot run here must be labelled unrunnable rather than left looking executable.
- proposed_fix: execute every AC check-command during refine — an AC whose command does not run is not refined. Verifying an AC's INTENT is not a substitute for running its literal check.
- narrative: two acceptance criteria encoded commands that were wrong at HEAD: one referenced a non-existent capacitor build target, the other a `grep -c` line-count assertion that every 404 in the app fails. Refinement verified the ACs' intent but never executed their check-commands, so both drifted commands passed refine unnoticed. Cost ~5 minutes each to disprove once actually run.
  **RUN 20260803-113231-34132, +1 — recurred TWO DAYS after the fix landed, in two independent children.** Child D: every one of 9 ACs drafted from reading rather than execution carried a defect (~15 min). Child F: 2 vacuous ACs and 2 wrong baselines, each corrected only by running the command, costing 2 extra rounds. So the § Method wording and the pre-stamp gate recorded above are NOT self-enforcing — a child can satisfy them by intending to and still draft-then-verify rather than execute-at-draft. This is why the lesson escalated out of this log: it is now the run's T2 decision bead **ac-ewgr.7** (mandate execute-at-draft for ACs *and* for preamble paste-sites in `ac-pipeline/references/delegation-contract.md`) — the scope widened beyond refine's own ACs, so the fix does not belong to this skill alone. Do not re-derive it here; track it there.
  **RUN 20260803-221658-19787 — CONFIRMATION: the mandate landed and worked on its first binding use.** ac-ewgr.7's execute-at-draft rule bound every refine child of this run, and the evidence is that it caught defects nothing else in the pipeline would have: a live P1 (a zsh pathspec collapse) that existed in the tree and in no bead, three of one child's own ACs, six of another's, and the run's largest premise failures — including failures in the FILER's output, not just the refiner's. That last part is the load-bearing generalisation: the mandate was argued from refine's own drafting errors, but it bites hardest on INHERITED claims, so its value scales with how much of a bead someone else wrote. Two boundary conditions this run also establishes, logged in full at `acceptance-criteria-that-cannot-fail`: executing an AC does not make it discriminating (three ACs ran clean and were already GREEN before any work existed), and an AC that greps for text the fix's own comment will contain satisfies the mandate while proving nothing. Execute-at-draft is therefore necessary and not sufficient — the missing half is recording the draft-time RESULT and rejecting any AC that starts green. Kept open on that basis rather than closed as fixed.
  **RUN 20260820-005558-8974, +1 — THE RUN'S SINGLE MOST RECURRENT LESSON, and it names the second missing half: what you EXECUTE and what you WRITE are different artifacts.** An AC was authored by ECHOING the command rather than pasting the one actually run; the two diverged by a lost `[" ]` terminator, which turned a genuinely-verified red check into one that **exits 0 on the broken tree**. Execute-at-draft was satisfied. The bead still shipped a check that cannot fail. It was caught only because an adversarial round re-executed every bite-proof **extracted from the FINAL BEAD TEXT**, not from shell history — which is the mandate this entry now needs: *re-extract and re-run every AC command from the stamped body before the stamp, as a separate step from drafting it.* Two more instances in the same run make the same point from the other direction, and both would have scored "present and specific" to a grep: a fabricated test count (AC said 14, the suite has 12) and a vacuous grep returning no hits today, so it passes on an empty diff. Three ACs, one sentence: **presence-checking an AC is not verification; only RUNNING it is** — and running the one you *wrote*, not the one you *meant*. Two authoring gotchas that produced always-passing checks in this run belong on the same line: `grep -c "(^|-)(organic|"` silently returns 0 read as a regex (use `grep -cF`), and any AC-embedded grep whose pattern looks like a regex must be `-F` or it ships a check that always passes. Finally, the same bar binds CORRECTIONS: a "correction" asserted as verified fact was itself wrong this run, and a WRONG RETRACTION IS WORSE THAN THE ORIGINAL ERROR because it tells the implementer to stop looking.

## br-update-has-no-description-file-flag
- skills: [ac-bead-refine]
- impact: M
- frequency: frequent
- recurrence: 3
- related: [dcg-guard-blocks-the-skills-own-setup-snippet]
- first_seen: 2026-08-03
- last_seen: 2026-08-13
- stage: ac-bead-refine
- status: open
- proposed_fix: there is no file-input flag for a bead description — the only safe apply path is a literal /tmp file written with the Write tool, verified present and non-empty, then passed via command substitution. Never pass `--description` from a missing path or an empty substitution: that WIPES the body. If a wipe happens, restore from the child artifact then redact. State this once at the refine apply step, because every failure mode is SILENT.
- narrative: two children independently expected `br update` to accept a description from a file and found the flag does not exist. The workaround (command substitution over a literal /tmp path) is also load-bearing for a second, unrelated reason, which is why this matters more than a missing convenience flag. (1) Child E caught pre-emptively that passing refined prose inline would have stored `$(...)` and `$$` sequences LITERALLY — the descriptions being applied contained the children's own verification loops, so every `$s` in them would have been silently eaten; a near-miss that would have shipped corrupted ACs to implement. (2) Child F needed the same substitution for a different reason: prose containing redirect characters is rejected by the command guard when inlined. One workaround, two independent failure modes it prevents, and neither is discoverable from the flag list.
  **RUN 20260813-235654-12053 (BCA, ac-loop-2 Phase 1), +1 — third failure mode, worse than the first two: a wipe, not a corruption.** `br update --description` sourced from a missing file emptied the body. Cost ~15 min. Recovery that worked: restore the body from the child's refine artifact, then redact. The apply-step check this entry already asked for was not in front of the conductor at the moment of the call; the missing-file case is now the reason it cannot stay advisory.

## tracing-gh-wrapper-prefixes-non-json-lines
- skills: [ac-bead-refine]
- impact: S
- frequency: occasional
- recurrence: 1
- related: []
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-bead-refine
- status: open
- proposed_fix: any AC or verification step that parses `gh` output must neutralise the fleet's tracing wrapper — prefix the invocation with an empty `GH_DEBUG=` and discard the error stream — or it will read as errored on a perfectly healthy call.
- narrative: this shell exports a tracing `gh` that prefixes non-JSON lines to its output. A verification step piping `gh` into `jq` therefore exited 5 (parse error) on a call that had actually succeeded. The failure mode is a FALSE ALARM, not a false green — the check reads as "errored" and a child either re-runs it or reports a problem that does not exist — so the cost is diagnostic time (~2 min here) rather than a shipped defect. Worth noting because the wrapper is environmental: the same AC command runs clean on a machine without it, so an AC verified elsewhere can fail here for reasons that have nothing to do with the bead.

## reviewer-prompts-must-explicitly-forbid-mutating-mcp-calls
- skills: [ac-bead-refine, ac-review]
- impact: H
- frequency: rare
- recurrence: 1
- related: [panel-reviewer-wrote-to-shared-checkout]
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-bead-refine
- status: open
- proposed_fix: a reviewer prompt must state the read-only constraint as an explicit prohibition that NAMES the mutating surfaces — including MCP tool calls, not just file edits — because "you are a reviewer" implies read-only to a human and to nobody else. Tool-restriction cannot be relied on here: the mutating capability was in the child's toolset.
- narrative: a round-1 reviewer removed a LIVE pre-commit guard from the shared repo via an MCP call while performing what it understood to be a read-only review. The prompt said "review"; it never said "make no mutating calls". Restored within the turn, so no work was lost, but the blast radius was a shared checkout with concurrent children and the removed thing was a safety guard — i.e. the one mutation whose absence is least likely to be noticed. Same family as `panel-reviewer-wrote-to-shared-checkout` in ac-review's log (a read-only stance mutating shared state through a capability nobody scoped away), but a distinct surface: that one went through git, this one through MCP, and the post-panel `git status` check shipped for the former would not have detected this at all.

## deferral-contract-does-not-say-who-commits
- skills: [ac-bead-refine]
- impact: S
- frequency: occasional
- recurrence: 1
- related: [deferred-br-writes-leave-reviewers-blind-to-br-show]
- first_seen: 2026-08-03
- last_seen: 2026-08-03
- stage: ac-loop
- status: open
- proposed_fix: the refine delegation must name the commit owner explicitly — "hold mutations" covers br writes AND git, and the conductor commits the ledger, not the child — since a child reading only "hold mutations" reasonably concludes the hold lifted once its own ceremony landed.
- narrative: a refine child committed the run ledger itself (07d189f) despite a hold-mutations instruction. Benign in outcome — the ceremony had already landed and the commit was correct in content — but it is contract drift, and on a shared checkout with width 2 an unexpected commit from a child is exactly the shape that swallows a sibling's in-flight work. The instruction was ambiguous rather than disobeyed: "hold mutations" was written with br writes in mind (see the related entry) and says nothing about git, so the child applied it to the surface it named.

## tr-shadowed-by-tmux-alias-in-interactive-zsh
- skills: [ac-bead-refine]
- impact: M
- frequency: every-run
- recurrence: 3
- related: [bash-isms-in-pasted-snippets-diverge-silently-under-zsh]
- first_seen: 2026-08-03
- last_seen: 2026-08-27
- stage: ac-bead-refine
- status: open — REOPENED 2026-08-27; the ac-e5a3 fix was site-scoped, not root-scoped
- proposed_fix: shipped — `workflow.md`'s `tr` invocations now call the binary explicitly rather than the bare name, so the fleet's interactive alias cannot shadow them (ac-e5a3: 8 invocations across 7 lines in 4 files).
- narrative: bare `tr` is aliased to tmux in the fleet's interactive zsh, so four `workflow.md` sites silently produced EMPTY STRINGS instead of the transformed values they computed. The values were CHILD_ID components, which meant the bd-baudw sibling-collision safety (distinct per-child artifact dirs) was degraded run-wide without any child seeing an error: two children hit it directly (~6 min, 3 retries, 4 orphaned /tmp dirs across siblings; one had to re-derive `paste -sd' '` as a substitute), and the rest inherited weakened isolation. Logged as resolved rather than omitted because the shape is the one this ledger exists to catch — a silently-empty result from a shadowed command name — and because the fix shipped the same day it was observed, which is the evidence trail a future promotion pass needs to see WORKED.
  REOPENED — RUN 20260827-221232-66808 GentleCave (ac-loop-swarm) hit `wc -l | tr -d ' '`
  failing with "open terminal failed: not a terminal", 24 days after this entry was marked
  resolved. The worker read that as a failed control; it is worse and more useful than that.
  ac-e5a3 did exactly what it claimed — it patched 8 named invocations across 7 lines in 4
  files — but the root cause is a fleet-wide interactive-zsh alias shadowing a POSIX binary,
  which is unbounded in scope. Patching the call sites known on 2026-08-03 cannot bind a call
  site written on 2026-08-27 in a different skill by a different agent. So `resolved` here
  asserted something the fix never established: it recorded SITE coverage and was read as ROOT
  coverage, and the ledger offered no way to tell those apart. The promotion pass would have
  counted this as a control that WORKED. Two things follow, and the second is the real one:
  (1) the fix must move to the root — unalias/`command tr` at the harness boundary, or a lint
  check that rejects bare `tr` in agent-authored shell, so new sites are covered by
  construction; (2) `status: resolved` needs to distinguish root-fixed from sites-patched,
  because a site-scoped fix silently degrades into a false all-clear the moment anyone writes
  new code — which is the precise shape this ledger exists to catch, now demonstrated on the
  ledger's own bookkeeping.

## final-round-audits-the-input-not-the-draft
- skills: [ac-bead-refine]
- impact: H
- frequency: frequent
- recurrence: 1
- related: [late-round-findings-are-contradictions-from-earlier-patches, heavy-review-does-not-mean-converged]
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: make the FINAL round's target the conductor's own DRAFT, not the original bead — "verify every factual claim in the text you are about to stamp, against the live tree/board" — and say so in the round prompt. The earlier rounds hunt gaps in the input; the last round audits the output. Without that switch, no round in the ceremony ever checks the thing that actually ships.
- narrative: the refine conductor's round-3 drafts had inherited reviewer summaries uncritically, and an audit OF THE DRAFT (rather than of the original bead) found **8 wrong factual claims** in text that was one step from being stamped refined. Cost a full round-3 rewrite of both bead bodies, ~20 minutes — but the alternative was shipping 8 false claims into beads that implement children would have treated as spec. The generalisable shape: reviewers report on the INPUT, the conductor writes the OUTPUT, and every round after round 1 is reviewing a document nobody has audited. This is the sibling of `late-round-findings-are-contradictions-from-earlier-patches` (there: the patches contradict each other; here: the patches assert things that are not true) and both are cured by the same switch of target in the last round. The claims were not sloppy paraphrase — they were reviewer summaries adopted verbatim, which is exactly the material a conductor is least likely to re-derive because it arrived already-formatted as a finding.

## findings-dropped-without-a-disposition-ledger
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [final-round-audits-the-input-not-the-draft, heavy-review-does-not-mean-converged]
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: require a per-finding DISPOSITION LEDGER in the refine artifact — every finding raised by any round gets exactly one of applied / rejected-with-reason / deferred-to-<bead>, and the round cannot close until each row has one. Silence must be impossible to confuse with a decision; a rejected finding with a stated reason is a cheap, honest outcome, an unlisted finding is not an outcome at all.
- narrative: two findings raised during refine were silently dropped — not rejected on the merits, just never carried forward into the next round's draft or the artifact. Nothing in the ceremony detects this: the panel reports findings, the conductor patches the draft, and the only record of what happened to any individual finding is whether its text happens to appear in the result. That makes "was this considered and rejected?" and "was this lost?" indistinguishable after the fact, for the conductor AND for the human reading the artifact later. Low cost this run (both were minor), but the failure mode is invisible by construction and scales with round count and panel width, so it will not announce itself in a run where the dropped finding mattered.

## write-the-patch-dry-run-beats-another-review-round
- skills: [ac-bead-refine]
- impact: H
- frequency: occasional
- recurrence: 1
- related: [acceptance-criteria-that-cannot-fail, final-round-audits-the-input-not-the-draft, filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-08-10
- last_seen: 2026-08-10
- stage: ac-bead-refine
- status: open
- proposed_fix: add a 4th, code-beads-only reviewer role — "write the smallest patch that would satisfy these ACs, then report what broke your assumptions" — run once convergence looks near, ADDITIVE to (not replacing) the existing Completeness/Implementability/Structure panel, which caught real independent defects in the same run's other batches (R25/R27).
- narrative: R20 refined 5 code beads (`rxngh.5/.6/.12/.13/.14`) through a full 3-reviewer panel with 0 premise deaths — and the panel still missed three criticals that ONE attempted write-the-patch dry-run caught: (i) `.12`'s AC was hollow — the real write site is `loadSlugSetOnce().then()`, not the site the AC named; (ii) `.6` cited `signup/route.ts`, which is DEAD CODE — the live door is `signup-form-client`; (iii) a Suspense boundary in `signup/page.tsx` is REQUIRED for static export and no reviewer noticed. All three are exactly the "can this actually fail / does it point at the live code" class this skill's existing `acceptance-criteria-that-cannot-fail` entry already tracks, but reached by a different lens: a prose review panel reasons ABOUT the fix, a dry-run patch attempt IS the fix and surfaces what the prose review can't see (a wrong write site, a dead-code target, a missing structural requirement) as soon as someone tries to actually make the change. Reconstructed from the run carrier — R20's own artifact dir did not survive the /tmp sweep (see the sibling ac-loop entry on artifact durability), so this narrative is a reconstruction, not a fresh read of the original artifact. evidence: ledger commits `118465a6` (R20 banked), `9d69c7f8` (batch35 closed); RUN 20260808-221219-47229, 2026-08-10. This was DEMOTED from a T2 improvement bead by ac-land's per-land cap of 1 (the T2 slot went to `ac-28nm`, /tmp artifact durability) — its recurrence should accrue here for `dream`'s ranking.

## unrunnable-ac-test-command-must-name-the-repo-runner
- skills: [ac-bead-refine, ac-loop-swarm]
- impact: M
- frequency: occasional
- recurrence: 2
- related: [ac-check-command-never-executed-during-refine, affected-graph-silently-subsets-explicit-test-selection]
- first_seen: 2026-08-10
- last_seen: 2026-08-21
- stage: ac-bead-refine
- status: open
- proposed_fix: an AC that names a test command must name a RUNNABLE one — `pnpm vitest run <path>` finds nothing repo-wide when `vitest-affected` narrows the include set, so ACs must specify `test:one` (or the repo's documented single-file runner), never a hand-composed vitest invocation. Second half, same root: transcribing a command at draft time BREAKS it — extract the command from the bead text verbatim and run THAT literal string, never a retyped variant.
- narrative: R19 (4 bug beads refine-full, commit `025df721`, RUN 20260808-221219-47229) hit both halves. This is a DIFFERENT root from `ac-implement`'s `affected-graph-silently-subsets-explicit-test-selection` (~line 51 there) — that entry is about `vitest-affected` under-selecting sibling mock files at IMPLEMENT time (a tool under-selection problem); this one is about an AC prescribing a test command that cannot resolve to any test AT ALL under the repo's runner wrapper (an authoring-time unrunnable-command problem), caught during REFINE before any implement child wastes a cycle on it. Judged same-family-but-distinct per friction-capture.md's dedup rule — a pointer to the ac-implement entry is recorded here for cross-reference, not a merge, since the two failure mechanisms and the stage they bite at are different.
  **+1 — a command can be unrunnable by ENVIRONMENT PROHIBITION, not only by runner-wrapper
  narrowing: an AC named a full-suite run, which is forbidden on a shared multi-worker checkout.
  Name a command runnable in the run's execution environment, not merely a command that resolves.**

## gate-liveness-ruling-must-read-the-targets-comment-tail
- skills: [ac-bead-refine]
- impact: L
- frequency: occasional
- recurrence: 1
- related: [filed-beads-carry-drifted-anchors-and-false-premises, comment-trusted-over-the-events-audit-trail, dispatch-scoped-from-spec-not-comment-history, board-truth-belongs-in-the-title-not-a-comment]
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: ac-bead-refine
- status: open
- proposed_fix: when a refine RULES on whether another bead is a live human gate (or on any state a human can change out-of-band), it must read that target bead's COMMENT TAIL newest-first, not body plus notes alone, and record the timestamp of the newest evidence it read. A ruling with no evidence timestamp cannot be TOCTOU-checked at execution time.
- narrative: NEAR-MISS, caught only by a downstream TOCTOU re-check. bd-kxcwr's refine ruled bd-bt9n8
  a genuine live human gate, reading its body and Notes. bd-bt9n8 carried a comment timestamped
  09:34:38Z recording Craig's ratification of 3 of 4 downgrades — posted 34 MINUTES BEFORE the refine
  ruled at 10:08. The row set actually awaiting Craig was EMPTY. Executing the ruling would have
  written a marker creating a FALSE gate, re-arming the exact reason-less-gate alarm that a sibling
  bead had spent its entire run clearing (62 reason-less gates down to 1). Caught only because the
  ledger lane's own AC8 re-checked at execution time instead of trusting the refine. The asymmetry
  that makes this worth a rule: a human's decision lands as a COMMENT — humans do not edit bead
  bodies — so the evidence layer a refine skips is precisely the layer human rulings live in. Note
  the deliberate tension with `comment-trusted-over-the-events-audit-trail` in ac-human-session's log
  (a comment is a CLAIM, the events table is the RECORD): these do not conflict, they compose. Read
  EVERY evidence layer and reconcile them; the failure in both cases was reading one layer and
  stopping. Filed bd-bt9n8-gate-ruling-overtaken-odrmg (P1 fork).

## element-4-must-name-the-firing-assertion
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [acceptance-criteria-that-cannot-fail]
- first_seen: 2026-08-14
- last_seen: 2026-08-14
- stage: converge
- status: open
- proposed_fix: when a bead's test file has more than one new test, element 4 (`## Declared RED`) must name the assertion that actually goes RED on revert — not a hollow sibling. Execute each candidate at draft time; stamp the one that fires.
- narrative: RUN 20260814-062417-51731 (BCA, ac-loop-2 Phase 3). bd-nx1s5 shipped two tests in
  `__tests__/unit/use-personal-zones.test.ts`: (1) `patchPersonalZonesCache` parent-must-not-flip-variant
  and (2) a parent-level insights upsert via `patchInsightsPersonalZonesCache`. Element 4 named
  test 1. The mutation probe found test 1 hollow (stays green with the fix reverted); test 2
  catches via the missing export. The bead is not hollow — a sibling assertion does catch —
  but the contract pointed the probe at the one that does not. Adjacent to
  `acceptance-criteria-that-cannot-fail` (vacuous AC) but a different write-site: element 4
  is the mutation-sampler input, and naming the file or the first test is not enough when
  only one assertion fires. Cost this run was minor (hollow% stayed 0/6; classified as
  improvement not reopen). Evidence: closed bd-nx1s5; repair commit `48a3abc8`.

## phase-skills-mandate-panels-a-subagent-cannot-spawn
- skills: [ac-bead-refine]
- impact: L
- frequency: every-run
- recurrence: 0
- related: [heavy-review-does-not-mean-converged]
- first_seen: 2026-08-14
- last_seen: 2026-08-14
- stage: refine
- status: open
- proposed_fix: see the primary entry.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is this same id in
  `_archive/skills/ac-loop/FRICTIONS.md`, where occurrences are counted (recurrence 32 as of
  RUN 20260814-213141-15553). Recorded here because land tagged this run's instance
  skill-scoped to ac-bead-refine. LOCAL MANIFESTATION: sequential 3-round refine with
  no Task tool, stamped `degraded-solo` rather than faking a panel. Independence lost
  as the primary already predicts. Not a new root — do not mint
  `no-task-tool-degraded-solo`.

## declared-red-not-reconciled-against-territory-or-existing-tests
- skills: [ac-bead-refine, ac-loop-swarm]
- impact: M
- frequency: frequent
- recurrence: 2
- related: [acceptance-criteria-that-cannot-fail, ac-check-command-never-executed-during-refine, element-4-must-name-the-firing-assertion]
- first_seen: 2026-08-20
- last_seen: 2026-08-21
- stage: ac-bead-refine
- status: open
- proposed_fix: add three mechanical pre-stamp checks on element 4. (1) RED-vs-Territory — every file the Declared RED instructs an edit to must appear in the bead's own `## Territory`; Territory wins on conflict. (2) RED-vs-existing — grep the target suite's full `it(` title list before authoring a RED; a bead spun out of a closed investigation inherits that investigation's tests. (3) RED-vs-extractor — if the assertion is extracted from source, state whether the extractor takes the FIRST match or ALL matches, and require ALL where the pattern can occur more than once.
- narrative: four independent Declared-RED defects in one run, each of which would have produced a
  HOLLOW PASS rather than a visible failure. (a) TWICE a declared RED was authored that already
  existed as a PASSING test committed under the bead's own closed origin bead — the RED was green
  the moment it was written. (b) bd-9uszd's RED prose instructed an edit to a file ABSENT from the
  bead's own Territory block; Territory won at implement time and the work became a discovery bead.
  (c) bd-l0mya's RED was under-specified against a source with THREE
  `@media (hover:none) and (pointer:coarse)` blocks — a first-match extractor returns section 5,
  which never mentions focus, so the check passes on a broken tree; the lane had to walk all three.
  (d) bd-ghgl0's RED was fabricated outright: a `getComputedStyle` assertion placed in a happy-dom
  tier that loads no CSS, replaced during refine with an executed source-scan RED. A fifth, adjacent
  shape from the same run: a CSS-SUPPRESSION bead's RED must assert the RESTORING rule WINS, not
  merely that the suppressing selector is gone — bd-l0mya's RED and AC1 would both have gone green
  on a fix that still left phones with no focus ring, because deleting the `:focus-visible`
  selectors does not defeat a sibling `:focus !important` rule at equal specificity. The common
  root across all five is that element 4 was written from the bead's own narrative rather than
  reconciled against the two artifacts that constrain it — the bead's Territory and the suite's
  existing tests — which is exactly the check that is mechanical and currently absent.
  **+1 — the reconciliation is AC-vs-Territory, not only RED-vs-Territory: acceptance criteria
  forbade by directory what the same bead's Territory listed in its production write set.**

## stamp-loop-stamps-deliberately-withheld-beads
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [deferral-contract-does-not-say-who-commits]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: ac-bead-refine
- status: open
- proposed_fix: give the canonical stamp loop an explicit WITHHELD-id gate — the loop iterates the target list MINUS the ids the child declared held back, and the child must emit that held-back list as a named output rather than as prose in its return.
- narrative: the skill's canonical stamp loop stamps every OPEN id in the target list. Four children
  in one run held a bead back deliberately (unbounded territory, no AC an empty diff cannot satisfy,
  a needed human architecture decision) and the loop as written would have stamped those beads
  `refined` anyway. The defect is silent in the worst possible direction: the held-back bead is
  precisely the one whose spec cannot support implementation, and stamping it makes it loop-eligible
  — so the failure converts a correct judgement into a dispatched child working an unrefinable bead.
  Held-back status currently survives only in the child's prose return, which nothing machine-reads.

## census-counts-governed-population
- skills: [ac-bead-refine]
- impact: H
- frequency: occasional
- recurrence: 1
- related: [filed-beads-carry-drifted-anchors-and-false-premises, acceptance-criteria-that-cannot-fail, element-4-must-name-the-firing-assertion]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: ac-bead-refine
- status: open
- proposed_fix: add a refine lens for any bead that settles a CANONICAL FORM — a key spelling, an enum value, a slug convention, a wire shape. The lens asks one question: which population will the resulting rule be applied to, and was THAT population the one counted? For anything a validator, migration or normaliser touches, the governed population is production rows, so the bead must carry a read-only production count, not a repository count. A census whose scope is unstated is not evidence and the bead does not stamp.
- narrative: bd-uf4m5 settled a canonical gate-key spelling as the SHORT form on a stated
  "129-vs-0 census". The census counted the TEST TREE. A read-only production census over all
  1005 canonical_ingredients rows found the exact inverse: 311/311 rows with a red_gate_triggers
  column carry the LONG form, and all 10040 SHORT instances are an inert never-firing skeleton.
  Had a repair followed the refined bead and retuned the validator to SHORT, it would have begun
  rejecting 100% of live production data. The refine round produced a correctly-formed,
  evidence-carrying, internally-consistent bead — every existing lens passed it — because no
  lens asks what the count was a count OF. A test tree is authored, so it counts whatever the
  last author wrote; production is accumulated, so it counts what the system has actually been
  doing, and for legacy data those two answers routinely invert. This is the sharpest known case
  of an evidenced bead being more dangerous than an unevidenced one: the number closed the
  question. Compounded by the run's declared-and-skipped integration tier — the only tier that
  could have contradicted the premise was declared in the bead's own Test-tier exposure and then
  not run (see `phase-3-global-pass-does-not-state-which-test-tiers-it-covers` in ac-loop-2).
  Fleet rule: `loop-retro-census-must-count-the-governed-population`; app fact:
  `bca-red-gate-key-spelling-long-in-production`.

## verifier-bead-is-hypothesis
- skills: [ac-bead-refine]
- impact: M
- frequency: occasional
- recurrence: see primary
- related: [filed-beads-carry-drifted-anchors-and-false-premises, census-counts-governed-population]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: ac-bead-refine
- status: open
- proposed_fix: see primary.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is `conductor-supplied-candidates-are-leads-not-findings`
  in `skills/ac-land/FRICTIONS.md`, where occurrences are counted. Same root: an upstream agent's
  OUTPUT is being read as an established finding rather than as a lead to falsify. LOCAL
  MANIFESTATION: a triage bead authored by a verifier agent had INVERTED both of its claims;
  refining it on its own terms and implementing it would have destroyed a real seam guard. The
  refine-side rule that follows is narrow and mechanical, and it is not the same as the anchor
  re-verification rule this file already carries: **a bead whose author was an agent, not a
  human, must have its central claim independently re-derived from the artifact before the bead
  is refined at all** — anchor freshness is not the question, claim TRUTH is. A verifier's output
  is a hypothesis with a bead ID; the ID is what makes it read as settled.

## territory-is-hand-listed-so-it-misses-symbol-consumers
- skills: [ac-bead-refine]
- impact: H
- frequency: per-run
- recurrence: 1
- related: []
- first_seen: 2026-08-20
- last_seen: 2026-08-21
- stage: refine
- status: open
- proposed_fix: Compute element 3 (Territory) as the git-grep UNION of the symbols the bead
  changes, instead of hand-listing files. For each symbol the bead's `## Delivers` names,
  grep the repo for its consumers and add every hit to the manifest — including test files,
  and including SECOND test suites for the same subject in different directories. Keep the
  hand list as a starting point, not as the answer. The cost of the grep is seconds; the cost
  of a miss is a full Phase-3 repair loop (re-dispatch plus re-verify).
- narrative: Element 3 is hand-listed by the refining agent, so it captures the files the
  author thought of and misses second-order consumers of the symbols the bead actually
  changes. RUN 20260820-005558-8974 measured repair% at 6/37 = 16.2% against <=10% guidance —
  the run's single worst metric. The conductor's own Phase-3 analysis found every one of the
  six repairs was a CONTRACT-BOUNDARY failure rather than a coding failure, and FOUR of the
  six reduce to one sentence: "a second file asserted the thing I changed and nobody looked."
  Those four were bd-chhin, bd-hof67, bd-lyh72, bd-uf4m5. Corroborating instance from the same
  run: the hook `use-form-submission` has TWO test suites in different directories, so a
  manifest naming one of them reads as complete while leaving the other to fail downstream.
  A hand-listed manifest is a memory test; a grep is a measurement. Source bead: bd-xo7c9.

## refine-mints-beads-that-launder-unproven-premises
- skills: [ac-bead-refine]
- impact: H
- frequency: occasional
- recurrence: 1
- related: [filed-beads-carry-drifted-anchors-and-false-premises]

- trigger: during a refine run the conductor spun bd-jxj42 out of bd-q7h0e to carry a
  "discharged" diagnosis forward, and Craig pushed back — "I don't know why you're creating
  new beads during the bead."
- cost: bd-jxj42 was filed with FIVE inherited claims and all five were false: wrong mechanism
  (named a guard the code path never reaches), "already discharged — do not re-derive" (the
  parent had explicitly written "plausible... unproven"), a regression window that predated the
  code by five weeks, two bisect commits touching neither relevant file, and an unverified row
  count. Repairing it took 3 rounds and 6 reviewers — more than the original diagnosis cost.
  Two further errors were found inside the conductor's own corrections, including a wrong file
  citation from a loose grep + `head -1`.
- root: two compounding gaps. (1) The skill had bead-CREATION mechanics (the split block) but no
  rule on WHEN NOT to create, so reviewers proposed new beads reflexively. (2) Nothing governed
  the EPISTEMIC status of what a child inherits — the act of filing launders a parent's
  hypothesis into settled fact, and the child then reads as agent-ready. A bead minted mid-run
  also never enters target-bead-ids.txt, so it skips the run's own rounds while the run reports
  success.
- proposed_fix: APPLIED 2026-08-26. workflow.md gains a "CREATING A BEAD DURING REFINE" ladder
  (fold in › record + surface › file; default DON'T) with a PREMISE INHERITANCE rule — carry the
  parent's hedge verbatim, and an inherited claim may sit in a binding section only if
  re-verified against HEAD this run; the title counts as a binding claim. Dedup strengthened from
  one grep to a full multi-noun sweep. Both round and final reports now name beads the run
  created as unreviewed artifacts ("none" is the good answer). SKILL.md carries a pointer row.
- narrative: this is the bead-scale twin of [[refine-lenses-sharpen-specs-not-premises]] — lenses
  optimise the answer inside a frame and never audit the frame. What actually caught it was
  prompting reviewers to FALSIFY rather than review; that framing is what the new rule
  institutionalises.

## cross-ac-self-contradiction-when-bead-defines-rule-and-declares-violation
- skills: [ac-bead-refine]
- impact: M
- frequency: rare
- recurrence: 1
- related: [filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-bead-refine
- status: open
- proposed_fix: add a cross-AC consistency check to the reviewer prompts — after per-element verification, ask "can every AC and the bead's own validation claim be true SIMULTANEOUSLY at the state this bead ships?"; a bead that both defines a pass/fail rule and honestly declares a currently-failing state needs an explicit pending/exemption bucket or its ACs contradict its own success claim.
- narrative: RUN 20260826-230057-6915, ac-on0y.4 — AC2 said "blocking + fail-open = lint failure" while AC4 required trauma_guard (blocking, truthfully fail-open) to carry a "conforming declaration" and Test Scope promised "lint green after landing". Unsatisfiable by construction; passed every anchor/baseline/element check in two rounds; caught round 3 by all three reviewers at once. Fix was a self-expiring PENDING-DECISION escape keyed to an open decision bead.

## freshness-field-acs-need-a-verified-write-path-and-write-cadence
- skills: [ac-bead-refine]
- impact: M
- frequency: rare
- recurrence: 2
- related: []
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-bead-refine
- status: open
- proposed_fix: for every AC that READS a timestamp/freshness/last-visited field, refine must verify (1) a write path exists — grep for an assignment/stamp site, not just the schema definition — and (2) the write fires on the CADENCE the AC's distinction needs — re-read the cited write-site's surrounding prose, not just grep the term.
- narrative: RUN 20260826-230057-6915, ac-on0y.3 — the staleness AC keyed on FRICTIONS.md last_pass, a field defined in the schema that NO mechanism writes (caught round 4 by cold-starting the mechanism). The round-4 fix then piggybacked the stamp on dream's status-flip, which fires only at REVIEW apply — interactive, "rarely runs", promoted-entries-only — which would leave visited-but-unpromoted ledgers stale forever (caught round 5 by reading the flip site's prose). Two distinct verification layers: existence, then cadence.

## ci-executed-checks-need-tool-and-trigger-tracing-to-the-exact-job
- skills: [ac-bead-refine]
- impact: M
- frequency: rare
- recurrence: 2
- related: []
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-bead-refine
- status: open
- proposed_fix: when a bead adds logic to a script that CI executes, refine verifies (1) every tool the logic shells out to exists IN THE JOB that runs the script (GH Actions jobs are isolated VMs — a sibling bead provisioning the tool in its own job proves nothing), and (2) the workflow's trigger paths include the inputs whose changes the logic must react to (a check that never re-runs on the mutation it gates is a gate that cannot fire).
- narrative: RUN 20260826-230057-6915, ac-on0y.4 twice — the PENDING-DECISION resolver first specified `br show` (a locally-installed Mach-O absent from ubuntu-latest; fixed by parsing committed .beads/issues.jsonl with preinstalled jq), and then its self-expiry had no trigger (registry-lint.yml paths filters exclude .beads/**, so closing the cited decision bead never re-ran the check). Both invisible to anchor/baseline verification; found by reading the workflow YAML's trigger block and tracing job boundaries.

## baseline-pasted-from-truncated-read-records-false-verified-claim
- skills: [ac-bead-refine]
- impact: S
- frequency: rare
- recurrence: 1
- related: [filed-beads-carry-drifted-anchors-and-false-premises]
- first_seen: 2026-08-26
- last_seen: 2026-08-26
- stage: ac-bead-refine
- status: open
- proposed_fix: a Baselines line quoting file content must come from a FULL read of the relevant block (or the whole file), never a head-limited peek; and every round that touches a bead re-diffs its pasted Baselines against live output — not against the prior finding's prose.
- narrative: RUN 20260826-230057-6915, ac-on0y.4 — the conductor's `sed -n 1,15p` peek at registry-lint.yml cut the pull_request paths list mid-block, and the 2-item misreading was transcribed into the bead as an executed, verified baseline. Survived one full round; caught in round 5 only because a reviewer re-derived the baseline independently via git log --follow. Same class the epic itself targets: a verified-looking claim that verified nothing.
