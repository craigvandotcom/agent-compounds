---
skill: beads-standards
created: 2026-07-22
last_pass: 2026-08-20
entries: 10
---

# beads-standards — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## br-non-tty-flake-in-compound-one-liners
- skills: [beads-standards]
- impact: S
- frequency: frequent
- recurrence: 4
- related: []
- first_seen: 2026-08-02
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: document the workaround once in beads-standards (likely § working cadence or the br cheatsheet): when `br` is chained inside a compound one-liner (`cmd && br ... && cmd`), it can fail with a "not a terminal" error — run the `br` call as its own separate Bash invocation, or pipe with `--json` where supported. Confirm the exact failing shapes before writing the rule (verify-doctrine-claims-against-live-tools).
- narrative: hit 3 independent times in one run (RUN 20260802-084558-9799, ac-loop-lite ablation —
  refine children r1 and r2, then a third occurrence in the implement lane): `br` invoked inside a
  compound shell one-liner errored with a "not a terminal" flake, forcing each child to re-run the
  command standalone. Cost per hit is one retry (~seconds), but three uncoordinated rediscoveries in
  a single run with ZERO doctrine anywhere in the registry (grep confirms no mention) makes it a
  documentation gap, not a tool bug we can fix here. Each child independently found the same
  workaround: separate invocation.
  **RUN 20260803-221658-19787, +1 — the trigger is broader than the `&&` chain this entry was minted
  from.** A review child hit the identical "not a terminal" failure with the call inside a `for` LOOP
  rather than an `&&` chain, and reached the same workaround independently (one invocation per call).
  That is a fourth uncoordinated rediscovery and it reframes the rule that still needs writing: the
  condition is not a particular chaining operator but any construct that costs the call its terminal,
  so doctrine phrased as "don't chain it with `&&`" would have failed to cover this occurrence. Phrase
  it as the positive form instead — a `br` call gets its own Bash invocation — which covers loops,
  chains, substitutions and pipes in one line. A pointer entry now sits in ac-review's log, since a
  panel finishing with a LIST of beads to walk is the shape that most invites the loop. Still
  undocumented anywhere in the registry, and per this entry's own `verify-doctrine-claims-against-live-tools`
  caveat the loop form is one more shape to confirm against the live tool before the rule is written,
  not a confirmation of the rule.

## br-lint-wants-success-criteria-where-doctrine-says-delivers
- skills: [beads-standards, ac-beadify, ac-bead-refine]
- impact: S
- frequency: frequent
- recurrence: 1
- related: []
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: decide and record which side gives, then make the other side quiet. Either `bead-conventions.md`'s epic template adopts the heading `br lint` expects, or the standard states explicitly that this particular lint warning is EXPECTED on epics authored to our conventions and is not to be actioned. Do not leave both in place: an unexplained warning on every correctly-authored epic is the shape that trains agents to ignore lint output wholesale.
- narrative: `br lint` warns that an epic is missing a `## Success Criteria` section, while `beads-standards/reference/bead-conventions.md` prescribes `## Delivers` for exactly that content. Both are "right" — the tool ships its own expectation, the convention is ours and deliberate — so an epic authored correctly against our doctrine is warned about by our own linter, every time. Warning-only, so nothing blocked and the run cost was zero; logged because the cost is not per-occurrence. A standing warning that correct work always produces is a broken detector: it teaches every agent that reads `br lint` output that some of it is noise, and the judgement of WHICH part is noise is then re-made by each agent under time pressure. That is how a real lint finding gets waved through later. Also a heading-drift hazard in its own right, since two names for one section means beads in the wild will carry both and any grep over epic structure has to know that. This is a doctrine-vs-tool divergence rather than a defect on either side, which is why it wants an explicit recorded decision rather than a fix.

## epic-endpoint-blocks-edges-make-children-unclaimable
- skills: [beads-standards, ac-beadify, ac-loop]
- impact: M
- frequency: occasional
- recurrence: 2
- related: []
- first_seen: 2026-07-22
- last_seen: 2026-07-22
- stage: ac-loop
- status: open
- proposed_fix: state explicitly in beads-standards § dependencies that an epic must NEVER be an endpoint of a `blocks` edge to its own children — parent/child containment is expressed with the `parent-child` dep type, and `blocks` is reserved for true ordering between peers. Add the repair recipe inline (`br dep remove <child> <epic>` then re-add as `parent-child`) so a conductor that hits it can fix it without re-deriving the diagnosis.
- narrative: hit TWICE in one day (2026-07-22, BCA final-push + infra-four batches). When an
  epic bead is wired as an endpoint of a `blocks` edge to its own children, the children become
  both unclaimable and unclosable — `br ready` never surfaces them (the epic "blocks" them and
  the epic cannot close until the children do), and a direct `br close` on a child is refused.
  The graph is a self-deadlock: containment was encoded as ordering. Each occurrence cost a
  diagnosis cycle before the conductor recognised the shape; the repair itself is trivial
  (`br dep remove` + re-add as `parent-child`). The standard currently documents the dep types
  but does not warn that mixing containment into `blocks` deadlocks the epic's whole subtree,
  so the mistake keeps getting re-made at beadify time and only surfaces at claim time.

## ledger-has-no-single-writer-duplicate-commit-stalls-automated-rebase
- skills: [beads-standards, ac-loop, ac-tidy]
- impact: H
- frequency: occasional
- recurrence: 1
- related: [beads-ledger-shared-file-conductor-should-own-final-commit]
- first_seen: 2026-07-27
- last_seen: 2026-07-27
- stage: session-protocol
- status: open
- proposed_fix: state in beads-standards § Session protocol that `.beads/issues.jsonl` is a DERIVED
  artifact of the DB with exactly ONE committer per scope, and that scopes must nest — within a run the
  conductor owns the final ledger commit; across scheduled jobs exactly one designated job commits it (or
  none, regenerating on demand). The standard currently PRESCRIBES flush-then-commit with no multi-writer
  warning at all, which is what licenses every job to commit it independently.
- narrative: an automated `git pull --rebase` started 07:33 and never finished, leaving the shared BCA
  checkout DETACHED mid-rebase for 8+ hours; ~26 agent sessions (including the one that found it) then
  committed onto that detached HEAD. Root cause was NOT a rebase problem: the dream job committed
  `.beads/issues.jsonl` plus tidy proposal files locally at 02:01, and the nightly tidy independently
  generated and PUSHED the SAME derived content. Replaying the dream commit onto the pushed one therefore
  produced an EMPTY commit; git stopped to ask --skip or --continue, and no operator existed to answer, so
  the process exited mid-rebase. Nothing was lost (the DB is the source of truth and every bead survived),
  but the checkout was wedged and every commit in the window landed orphaned. NOTE this is the trigger
  condition the 2026-07-14 memory `beads-ledger-shared-file-conductor-should-own-final-commit` was waiting
  for — it predicted a LOST update between children of one run and said that would be the moment to act.
  What actually fired was the mirror image: a DUPLICATE update between two independent SCHEDULED JOBS, which
  the conductor-owns-the-commit fix does not cover at all, because no conductor sits above both jobs.
  Hence the fix must be scoped per-writer-scope, not per-run.

## br-json-shapes-differ-across-subcommands
- skills: [beads-standards]
- impact: S
- frequency: frequent
- recurrence: 3
- related: [br-non-tty-flake-in-compound-one-liners, ready-filter-admits-epics-and-gate-reason-beads]
- first_seen: 2026-08-04
- last_seen: 2026-08-20
- stage: ac-loop
- status: open
- proposed_fix: document the shapes in the br cheatsheet: `br list --json` returns an OBJECT (`{issues:[…], total, limit, offset, has_more}`) and needs an explicit `--limit 0`; `br ready --json` and `br show --json` return BARE ARRAYS. Give the defensive filter form (`(.issues // .)`) so one jq expression survives both. Confirm against the live tool before writing (per `verify-doctrine-claims-against-live-tools`).
- narrative: a jq filter written for `br ready --json` errored with "Cannot index array with string" when reused against `br list --json`, because the two subcommands of the same CLI return different top-level shapes; `br list` additionally truncates unless given `--limit 0`, so a board scan silently under-reports without it. A third shape showed up in the same run from the refine side: a bead AC specified parsing `br show --json` as an object and was unbuildable as written because it too returns a bare array. Cost is one wasted call per rediscovery, but the shape is rediscovered independently by every agent that scripts a board scan, and nothing in the registry documents it. Knowledge captured meanwhile as the neoMeta memory fact `br-cli-json-shapes-and-body-quoting`; this entry tracks the doctrine gap that keeps making it necessary.
  **RUN 20260811-113939-36193 (BCA), +1 — same root (br subcommand defaults and shapes silently
  narrow or reshape the result set), and this time it cost a dispatched child.** Two confirmations
  and one addition. CONFIRMED: `br show --json` does return a bare array, as this entry already
  documents — an agent re-derived it at its own cost, which is the argument for finally writing the
  cheatsheet rather than logging the friction a third time. NEW AND WORSE: **`br list` hides CLOSED
  beads by default; `--all` is required.** This turns an existence probe into a false negative,
  which is the most expensive shape available — a conductor concluded a plan had zero beads and
  dispatched a beadify child, when the epic was 18/20 closed and shipped. The sound probe form is
  `br list --all --limit 0 --json` matched against title AND labels AND description; the run's probe
  matched a plan filename slug against descriptions only and missed beads titled from the plan's own
  heading. Both failures are silent: no warning, exit 0, an empty-looking board. Add `--all` to the
  cheatsheet line that already carries `--limit 0` — they are the same defect twice.
  **RUN 20260820-005558-8974 (BCA), +1 — the truncation half, now measured across FOUR independent
  lanes on a 3077-issue board.** An EXPLICIT `--limit 1000` truncates just as silently as the
  default and still exits 0: a count from a capped query is not a measurement. It corrupted
  bd-ivm4d's original filing and specK's first sweep, and a fifth agent reported the same class as
  "`br list --json` SAMPLES the board (1000 of 3073) and EXITS 0". The correct form is
  `--limit 0 --all` — a NUMBER in `--limit` is the bug, not a smaller number. Two hardening notes
  the cheatsheet line should carry: (1) an explicit large limit reads as diligence and is worse
  than the default, because the author has visibly thought about the cap and still capped;
  (2) `br ready --json` emits a BARE ARRAY where `br list --json` emits `{issues:[…]}`, which cost
  one silent wrong "none are ready" reading in this same run — the defensive `(.issues // .)` form
  in the proposed fix is what makes one filter survive both.

## br-d-body-is-shell-expanded
- skills: [beads-standards]
- impact: L
- frequency: frequent
- recurrence: 3
- related: [br-json-shapes-differ-across-subcommands, dcg-false-positives-on-angle-bracket-inside-quoted-prose]
- first_seen: 2026-08-04
- last_seen: 2026-08-20
- stage: ac-loop
- status: open
- proposed_fix: state the positive form in the br cheatsheet — **any `br` body text goes in a FILE and is passed with `-f <file>`** (`br create -f`, `br comments add <ID> -f`), never inline in `-d` or as a quoted argument. Cover the reason in one clause (the argument is shell text: backticks EXECUTE, and `<…>` placeholders parse as redirects) so the rule is not mistaken for style advice, and note the arg order `br comments add <ID> …` while writing it. Raise the severity language: this is command injection through a comment body, not a quoting nuisance.
- narrative: hit TWICE in one run by two different agents (RUN 20260804-202200-loop: the conductor at Phase 0, then a review child at bead-filing) and solved independently both times. A `br create -d "…"` body containing backticks and an angle-bracket placeholder triggered command substitution plus a redirect parse error; the failure message names shell syntax, so neither agent's first hypothesis was about the bead at all. `-f` avoids the whole class, including the dcg prose-payload false positives that the same inline shape triggers — two independent reasons for one rule, which is a good sign it belongs in doctrine rather than in each agent's scar tissue. Two uncoordinated rediscoveries in a single run with zero registry coverage is the same documentation-gap shape as `br-non-tty-flake-in-compound-one-liners` above.
  **RUN 20260820-005558-8974, +1 — the impact is not cosmetic and the surface is not just `create`.**
  Reported THREE times in one run against `br comments add <id> "…"`: backticks inside the
  double-quoted body are EXECUTED by zsh, not merely eaten. Once it silently deleted a word
  mid-sentence (a backticked term vanished from a stamped comment). Once, with real cost, it fired
  **TWO unintended `pnpm test` RUNS on the shared Mac while six lanes were live** — arbitrary
  execution triggered by prose an agent wrote about its own work, on a host where the side effect
  contended with every concurrent lane. Raise impact S→L accordingly. Safe shape, unchanged:
  a QUOTED heredoc to a file, then `-f <file>` (or `"$(cat file)"`).
  Two adjacent argument-order hazards belong on the same cheatsheet line, because both make a FAILED
  write look like a successful one: `br comment` is not a verb (it is `br comments add`), and
  `br comments <ID> add <text>` — the transposed form — exits 0-ish with only a "Hint: run br list".
  See `wrapper-exit-0-masks-real-outcome` in the global memory substrate for the general class.

## board-truth-belongs-in-the-title-not-a-comment
- skills: [beads-standards, ac-loop, ac-bead-refine]
- impact: H
- frequency: occasional
- recurrence: 1
- related: [dispatch-scoped-from-spec-not-comment-history]
- first_seen: 2026-08-05
- last_seen: 2026-08-05
- stage: ac-loop
- status: open
- proposed_fix: state in beads-standards that **a session finding a bead's work already shipped, partially shipped, or void AMENDS THE TITLE AND DESCRIPTION — a comment is not a board-truth mechanism.** Give the amended-title form so it is mechanical rather than a judgement call (prefix the residual scope: `[Parts A+B SHIPPED <sha>] <remaining scope>`). Pair it with the complement already logged in ac-pipeline: amend the TITLE when the truth changes, read the COMMENTS when scoping. Either half alone leaves a lane where truth is written where nobody reads.
- narrative: a bead consumed four agent sessions after the work it specified had merged. Each of the first three sessions discovered the shipped state correctly and recorded it in a bead COMMENT, leaving the description reading as unbuilt spec — and conductor triage surfaces the title and description, never the comment tail. So each next session read an unbuilt spec, dispatched an agent to build it, and rediscovered the same truth. The comment was a correct finding delivered through a channel with no reader: three uses, zero deliveries. Resolved on the fourth pass by rewriting the title rather than commenting again. Not one bead's accident — an adversarial HEAD-verified audit of the 10 refined ready bugs alongside it found 3 already shipped and 2 partial, so half the ready lane misrepresented its own state through the same mechanism. Logged against beads-standards because the standard prescribes where a close reason and a comment go but never says which field triage READS, so every session re-decides it and most choose the polite option.

## br-label-add-silently-noops-on-multiple-labels
- skills: [beads-standards]
- impact: S
- frequency: occasional
- recurrence: 1
- related: [br-json-shapes-differ-across-subcommands, br-non-tty-flake-in-compound-one-liners]
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: ac-loop
- status: open
- proposed_fix: state the working form in the br cheatsheet — labels are applied ONE PER CALL with an explicit `-l` flag each; passing several bare label words in a single `br label add` call is accepted, exits 0, and applies NOTHING. Pair it with the standing verify step (`br show` after labelling) since the CLI gives no signal.
- narrative: an agent labelled several beads in what looked like the obvious batch form and the
  labels never landed. There is no error, no warning, and a zero exit status, so the loss is
  invisible until something downstream filters on a label that is not there — which in a
  gate-counting run means a bead silently drops out of or into the wrong population. Cheap to fix
  once known, expensive to discover, and exactly the class the cheatsheet exists for.

## br-lint-scans-description-only-not-notes
- skills: [beads-standards]
- impact: S
- frequency: occasional
- recurrence: 1
- related: [br-lint-wants-success-criteria-where-doctrine-says-delivers, br-d-body-is-shell-expanded]
- first_seen: 2026-08-11
- last_seen: 2026-08-11
- stage: ac-bead-refine
- status: open
- proposed_fix: state in the br cheatsheet that `br lint` reads the DESCRIPTION field only and never reads notes, so every lint-required section must be folded into the description body — and, per `br-d-body-is-shell-expanded`, that body goes through a file rather than an inline argument.
- narrative: an agent added a lint-required section via `--notes`, re-ran `br lint`, and watched the
  same finding persist. The natural reading is that the fix failed or the linter is flaky; the
  actual cause is that notes are outside the linter's scan surface entirely. The wasted loop is
  short but it recurs per agent, and it interacts with the sibling finding above
  (`br-lint-wants-success-criteria-where-doctrine-says-delivers`): an agent chasing a heading-name
  mismatch while also writing to the wrong FIELD can conclude the linter is simply wrong and start
  ignoring it, which is the real cost.

## ready-filter-admits-epics-and-gate-reason-beads
- skills: [beads-standards, ac-loop-2]
- impact: M
- frequency: frequent
- recurrence: 1
- related: [br-json-shapes-differ-across-subcommands, board-truth-belongs-in-the-title-not-a-comment]
- first_seen: 2026-08-20
- last_seen: 2026-08-20
- stage: ac-loop-2
- status: open
- proposed_fix: define loop-eligibility in the standard as a THREE-clause filter, not one — `br ready` MINUS `type=epic` MINUS any bead whose description carries a `## Gate-reason` section — and state that a body-declared gate without the `human-gate` LABEL is a malformed bead the standard requires fixing, since only the label is machine-readable.
- narrative: `br ready` is treated across the pipeline as "the loop-eligible set", and it is not.
  Two classes leaked into a 94-bead input set in one run and consumed lane slots before the
  conductor caught them at lane construction. (1) bd-06opv.12 and bd-l1p5n both declare themselves
  human-gated IN THEIR BODIES — `## Gate-reason: fork`, "THE DECISION (this is why the bead is
  human-gated)" — but carried no `human-gate` label, so `br ready` returned them as work. The bead
  said the right thing to a human reader and nothing at all to the filter. (2) bd-vbmre and
  bd-dlqc1 are epic roll-ups with no ACs, no `## Delivers` and no `## Territory`; they are not
  implementable by construction and should never have entered the set. Both classes are silent —
  the beads look ready, the filter exits 0, and the cost only appears when an agent opens the bead
  and finds nothing to do. Related hazard observed in the same run and worth one sentence in the
  same doctrine line: `human-gate` correctness is not the only field the machine reads. A conductor
  repaired three reason-less gate beads, writing `Gate-reason` into the DESCRIPTION for two and
  into a COMMENT for the third; docket-health's predicate reads `.description` only, so the third
  stayed reason-less and kept alarming. Same root as
  `board-truth-belongs-in-the-title-not-a-comment` — a correct finding delivered through a channel
  with no reader — and the generalisable half is: when fixing N instances of a defect, verify the
  FIX SHAPE is identical across all N, because two verbs that both "add text to a bead" are not
  interchangeable to a machine.
