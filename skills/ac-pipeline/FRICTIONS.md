---
skill: ac-pipeline
created: 2026-08-03
last_pass: 2026-08-20
entries: 5
---

# ac-pipeline — friction log

<!-- Sensor log, not a work-surface. Never loaded with SKILL.md. On capture: read the
     entries below and judge same-vs-new before minting an id (see
     skill-builder/references/friction-capture.md § Deduplication) — do not append a
     duplicate root friction under a new id. -->

## dcg-blocks-the-skills-own-canonical-artifact-redirects
- skills: [ac-pipeline]
- impact: M
- frequency: every-run
- recurrence: see primary
- related: [dcg-blocks-the-skills-own-canonical-artifact-redirects]
- first_seen: 2026-08-03
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: see primary — resolve-then-paste literal paths, or route artifact writes through the Write tool. Sharpened by RUN 20260803-221658-19787: the substitute must be `tee`, not a "safer-looking" redirect. Once a command's destination is anything other than a pasted literal, the rule fires; a literal path held in a variable is still a variable.
- narrative: POINTER ENTRY, not a copy — see `dcg-blocks-the-skills-own-canonical-artifact-redirects` in `_archive/skills/ac-loop/FRICTIONS.md`, which is the PRIMARY and the only place occurrences are counted (per friction-capture.md § Routing: cross-cutting frictions are recorded once, with pointers in the secondary skills). Recorded here because RUN 20260803-113231-34132 established that ac-pipeline owns shared substrate inside the blast radius, not merely a downstream skill affected by it: `references/board-scan.md`'s Scan D/E blocks are guard-blocked verbatim, and the artifact-write shapes handed to every child through the delegation preamble are the same construct. A fix applied only to the individual phase skills leaves the shared substrate emitting the blocked shape to every child of every run.
  **RUN 20260803-221658-19787 (agent-compounds, 27 beads / 5 batches), +4 counted at the primary — the run that maps the rule's real boundary.** Four occurrences, and their value is that together they falsify the two folk-workarounds children keep re-inventing. (1) A `wc -l` reading from a variable-held path was blocked — the input side of a redirect is matched, not just the output side, so "I am only reading" is not an escape. (2) An error-stream redirect nested INSIDE a command substitution was blocked, confirming the rule matches anywhere on the line rather than at the top level, so wrapping the construct deeper does not hide it. (3) A `br list` write was blocked even though the destination path was a LITERAL that merely happened to be held in a variable — the guard cannot see that the variable's value is constant, so "make the path literal" only works if the literal is pasted at the call site; the child's successful substitute was `tee`, and `tee` should be named as THE sanctioned shape rather than left for each child to rediscover. (4) A write to a PID-suffixed scratch file was blocked for the same reason a RUN_ID-suffixed one is — process-unique names are dynamic by construction, so the standard "just use a unique temp file" advice collides head-on with this rule. Cost was ~4 blocked calls plus rediscovery time spread across four children. The pipeline-owned consequence: the delegation preamble and board-scan hand children shapes (1)-(4) directly, so every child pays this tax before it does any work, and the `tee` substitute is nowhere in the shared substrate.
  **RUN 20260820-005558-8974, +6 counted at the primary — six NEW shapes, and this entry's own capture was itself blocked while being written, which is the strongest possible evidence for the fix shape it already recommends.** (i) The redirect-truncate rule fires on a fat-arrow, on a self-closing JSX tag, and on an angle-bracket placeholder **INSIDE A QUOTED HEREDOC BODY** — so the standard "put the payload in a heredoc" advice does not clear it; the working shape is heredoc-to-a-LITERAL-file via the Write/Edit tool, then `cat`. (ii) A python `open(var, 'w')` is blocked; a pasted literal path in `open()` clears it. (iii) A `while read` loop containing an error-stream redirect is blocked as a dynamic redirect path — the lane's correct response was to change approach to explicit literal per-line calls after a separate pre-check pass, with no bypass attempted. (iv) A `br comments add` call carrying escaped quotes plus a discard redirect is blocked because the escaping makes the target unprovable; the sanctioned shape is `tee` the body to a file, pass it by command substitution, and drop the redirect entirely. (v) A truncating write to a variable-built artifacts path is blocked even when the skill's OWN init step supplied that line, and ac-bead-refine's warning about it sits on a DIFFERENT LINE from the init write, so it fired anyway — **a warning that is not adjacent to the line that emits the blocked shape does not prevent the block.** (vi) A compound python-plus-`br`-plus-redirect one-liner is blocked where splitting it into separate calls clears it. The pipeline-owned consequence is unchanged and now sharper: the substitutes must be stated as POSITIVE canonical shapes ON the line that emits them (`tee -a`, Write tool with a pasted literal path, one call per verb), never as a caveat elsewhere in the file — and the documentation must NAME constructs rather than show them, since showing them blocks the write.

## dcg-false-positives-on-angle-bracket-inside-quoted-prose
- skills: [ac-pipeline]
- impact: M
- frequency: frequent
- recurrence: see primary
- related: [dcg-false-positives-on-angle-bracket-inside-quoted-prose, dcg-blocks-the-skills-own-canonical-artifact-redirects]
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: see primary — write prose payloads to a literal temp file with the Write tool and pass them by command substitution, rather than inlining them. ac-pipeline's own stake: the delegation preamble and the disposition/close-reason templates it hands every child are exactly the long-prose payloads that trip this, so the sanctioned "payload goes in a file, never on the command line" shape belongs in the shared substrate, not in each phase skill.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is `dcg-false-positives-on-angle-bracket-inside-quoted-prose` in `_archive/skills/ac-loop/FRICTIONS.md`, where occurrences are counted. Recorded here for the same reason as the sibling above: the shapes originate in ac-pipeline-owned shared text. RUN 20260803-221658-19787 contributed three occurrences (counted at the primary) that widen the class well beyond the markdown blockquote the primary was minted from. (a) A command was blocked because the word `restore` appeared as an ordinary English verb in a quoted prose payload — the guard's destructive-operation matcher reads command TEXT, so a bead comment that merely *describes* restoring a file is indistinguishable from one that does it. (b) An arrow written in prose was tokenised as a redirect, with nothing being redirected. (c) A placeholder in angle brackets inside a bead description body was read as a redirect target. All three are the same root as the primary and all three landed on payloads whose SHAPE this skill supplies. Two operational points worth carrying: the failure is per-call and self-inflicted at compose time, so it is fully preventable by never putting prose on a command line; and guidance that tries to warn about these shapes by showing them is itself blocked, which is why the fix must name constructs rather than demonstrate them.

## delegation-brief-restates-bead-preconditions
- skills: [ac-pipeline]
- impact: H
- frequency: every-run
- recurrence: see primary
- related: [delegation-brief-restates-bead-preconditions, dispatch-scoped-from-spec-not-comment-history]
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: see primary — briefs POINT at the bead, never restate it. ac-pipeline's local half is the one that is mechanically checkable and belongs in `references/delegation-contract.md`: **a brief may state a fact only if it carries a citation — a commit SHA or a `br show` verdict. A narrative claim about work that is still in flight is not citable and must not be stated.** Add it as a compose-time rule next to the child-spawn preamble, with the escape phrasing for the uncitable case ("premise, NOT verified — check it") that the memory fact already recommends.
- narrative: POINTER ENTRY, not a copy — the PRIMARY is `delegation-brief-restates-bead-preconditions` in `_archive/skills/ac-loop/FRICTIONS.md`, where occurrences are counted. Recorded here because the contract this friction keeps violating is ac-pipeline's own: `references/delegation-contract.md` defines what a brief may contain and currently says nothing about citation, so every conductor re-derives the rule after paying for it. Local manifestation (RUN 20260804-202200-loop): a refine brief asserted a sibling bead's parts were being implemented concurrently when they had landed five days earlier; all three round-1 reviewers spent ~15 minutes refuting the brief before refining could start. The distinguishing feature versus the primary's earlier occurrences is that this claim was not stale — it was PREMATURE, composed from the dispatch plan before the implement child reported back — which is why the fix has to be a citation test rather than a freshness reminder.

## dispatch-scoped-from-spec-not-comment-history
- skills: [ac-pipeline, ac-loop]
- impact: M
- frequency: occasional
- recurrence: 1
- related: [delegation-brief-restates-bead-preconditions]
- first_seen: 2026-08-04
- last_seen: 2026-08-04
- stage: ac-loop
- status: open
- proposed_fix: state in `references/delegation-contract.md` that a dispatch is scoped from the WHOLE bead — spec AND comment history — and that any instruction to FILE something (a decision bead, a follow-up, a gate) must be checked against the bead's comment tail first, since that is where prior sessions record decisions, retractions and already-shipped verdicts. Cheap mechanical form: `br show <id>` including comments, and grep the tail for DECISION/SHIPPED/RETRACTED before composing an order to create anything.
- narrative: the conductor ordered an implement child to file a B2 atomicity DECISION bead. That decision had been recorded ON THE SAME BEAD five days earlier ("ATOMICITY DECISION: TWO-STEP, WITH A NAMED RACE WINDOW"). The child refused and was right; had it complied, a settled question would have been re-escalated to a human gate. Root cause is structural rather than careless: conductor triage surfaces the TITLE and DESCRIPTION, and a long refined bead's spec section reads as complete, so the comment tail — which is exactly where later sessions put corrections — is the part a compressing conductor never opens. Same shape as the board-truth defect this run's other findings cover (a session that finds work already shipped writes it into COMMENTS, where the next conductor's triage cannot see it), which is why the two fixes are complements: amend the TITLE when the truth changes, and read the COMMENTS when scoping.

## check-exit-status-before-believing-a-zero
- skills: [ac-pipeline, ac-loop-2, ac-loop-swarm, ac-bead-refine]
- impact: H
- frequency: every-run
- recurrence: 2
- related: [dcg-blocks-the-skills-own-canonical-artifact-redirects]
- first_seen: 2026-08-20
- last_seen: 2026-08-21
- stage: ac-loop-2
- status: open
- proposed_fix: add one clause to `references/shell-guardrails.md` and cite it from the delegation preamble — **a scan whose exit status was not checked reports UNKNOWN, never zero.** Three concrete sub-rules under it: check the status of any search you are about to treat as evidence; positive-control the sensor against a known hit before trusting an empty result; and never pass a path list, a long body, or a bead body through a bare shell variable under zsh — use an array or paste literals.
- narrative: FOUR distinct incidents across FOUR different agents in one run, all the same shape —
  a sensor returned zero and the zero was manufactured. (1) `rg` over an argument list containing
  one nonexistent directory ABORTS the whole invocation, so a multi-directory scan reported nothing
  found. (2) zsh does NOT word-split an unquoted `$DIRS`, so the scan searched a single concatenated
  nonexistent path; the same defect in `git add -- $PATHS` aborted a lane's commit with "HEAD did
  not advance". (3) A `*.tsx`-only glob missed `lib/*.ts`, where 6 real hits lived — a narrow glob
  is a wrong answer, not a partial one. (4) `printf '%s' "$long_bead_body" | grep` silently dropped
  content for 2 of 9 beads, reporting a six-element structural check as FAILING on intact beads.
  A fifth from the same run generalises past scans: `br comments <ID> add <text>`, the transposed
  argument form, exits 0-ish with only a "Hint: run br list" — **a failed write that looks like a
  successful one.** This is ac-pipeline's to own rather than any phase skill's, because the
  guardrails doc is the shared substrate every child reads and none of these are discoverable from
  the tools' own output. Canonical statement in the global memory substrate:
  `wrapper-exit-0-masks-real-outcome` (the mirror section, "check exit status before believing a
  zero"); sibling detector rule: `jq-index-returns-a-false-zero` — any check whose all-clear value
  equals its broken value needs a positive control.
  **+1 — a path list containing `[id]` or `(protected)` silently loses its arguments under zsh
  unless each path is quoted; glob metacharacters in a path are a live case of the same rule.**

## gate-reason-field-contract-is-unspecified
- skills: [ac-pipeline, ac-tidy]
- impact: M
- frequency: nightly
- recurrence: 2
- related: [wrapper-exit-0-masks-real-outcome]
- first_seen: 2026-08-19
- last_seen: 2026-08-21
- stage: docket-health
- status: open
- proposed_fix: Pick ONE authoritative field and make spec and code agree. Recommended: the
  DESCRIPTION is authoritative (a human must be able to find the reason without paging
  comments), `ac-tidy/SKILL.md:235` is corrected to say description-only, and a SECOND lint
  flags any bead whose COMMENTS contain `Gate-reason` while its description does not — the
  near-miss case, which is the one that currently fails silently. Widening the predicate to
  read comments is the tempting cheap fix and is wrong: a superseded reason in an old comment
  would silence the alarm permanently, trading a noisy alarm for a deaf one. Also sweep the
  other readers/writers of `Gate-reason` before changing anything — they exist in `ac-triage`,
  `ac-tidy`, `ac-review`, `beads-standards` and `human-gate-template.md`; only
  `board-scan.md:117` was ever checked as a machine PREDICATE.
- narrative: THE SPEC AND THE IMPLEMENTATION DISAGREE ABOUT WHICH FIELD CARRIES THE MARKER, so
  nobody writing a `Gate-reason` can be correct against both. `ac-tidy/SKILL.md:235` instructs
  the reader to flag beads whose "description + comments" lack the line;
  `ac-pipeline/references/board-scan.md:117` reads `(i.get('description') or '')` — description
  only. Live instance: `bd-next-segment-cache-upstream-report-ptejc` had its Gate-reason
  classified in full by the ac-loop-2 conductor of RUN 20260820-005558-8974, under a proper
  `## Gate-reason: action —` heading, INTO A COMMENT. It alarms every night regardless. Two
  siblings stamped in the same pass put theirs in the description and dropped out correctly.
  The convention is being applied inconsistently by conductors and humans alike, which says it
  is under-specified rather than that anyone was careless. Second, related defect from the same
  bead pair: the population is a MOVING TARGET and the original filing measured it with a capped
  `br list --limit 1000` against a 3077-issue board — a finite limit TRUNCATES SILENTLY. The
  filing said 2, a refine sweep found 4, an adversarial re-sweep 40 minutes later found 5,
  because a sibling lane of the same run stamped a new human-gate bead with no Gate-reason
  WHILE the bead was being refined. Always `--limit 0`, and treat any count as a snapshot of a
  board with concurrent writers. Source beads: bd-ivm4d, bd-afqj7.

## upstream-defect-reports-have-no-owner-or-cadence
- skills: [ac-pipeline]
- impact: L
- frequency: occasional
- recurrence: 2
- related: []
- first_seen: 2026-07-29
- last_seen: 2026-08-21
- stage: close-out
- status: open
- proposed_fix: Decide once whether reporting a third-party defect upstream is in the fleet's
  scope at all. If yes, name the owner and a cadence (e.g. batched at each land, or a monthly
  sweep) and give it a label so the beads do not accumulate on the human docket individually.
  If no, say so explicitly and close such findings with the local workaround recorded — which
  is what actually matters, since in every instance so far the workaround had already landed.
- narrative: Two upstream reports sat on the human docket for weeks each, both P3, both with
  local workarounds ALREADY LANDED so nothing was blocked. (1) bd-wplw0 — `br` mints
  dot-notation children via `--parent` and an open dot-child blocks the parent's close; source
  is not on this machine (`~/.local/bin/br` is a 10.9 MB prebuilt binary, v0.2.16) so no local
  fix was possible; mitigation landed as agent-compounds f7593e4 (`--parent` is containment
  only, provenance uses `-t discovered-from`). The open question worth reporting is whether
  blocking a parent's close on a CONTAINMENT edge is intended. Also bundled: mcp-agent-mail's
  `project_key` derivation fragments one checkout into 3+ keys. (2)
  bd-next-segment-cache-upstream-report-ptejc — a Next.js segment-cache search-precedence
  defect with no public issue filed. These linger because filing a public issue on someone
  else's repo under Craig's identity is genuinely an outward-facing act an agent must not take
  unilaterally — but nothing routes them either, so they age on the docket as permanent P3
  noise. The friction is the MISSING ROUTE, not either defect. Source beads: bd-wplw0,
  bd-next-segment-cache-upstream-report-ptejc.
