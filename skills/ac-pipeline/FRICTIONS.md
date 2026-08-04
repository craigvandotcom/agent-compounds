---
skill: ac-pipeline
created: 2026-08-03
last_pass: 2026-08-04
entries: 2
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
- narrative: POINTER ENTRY, not a copy — see `dcg-blocks-the-skills-own-canonical-artifact-redirects` in `skills/ac-loop/FRICTIONS.md`, which is the PRIMARY and the only place occurrences are counted (per friction-capture.md § Routing: cross-cutting frictions are recorded once, with pointers in the secondary skills). Recorded here because RUN 20260803-113231-34132 established that ac-pipeline owns shared substrate inside the blast radius, not merely a downstream skill affected by it: `references/board-scan.md`'s Scan D/E blocks are guard-blocked verbatim, and the artifact-write shapes handed to every child through the delegation preamble are the same construct. A fix applied only to the individual phase skills leaves the shared substrate emitting the blocked shape to every child of every run.
  **RUN 20260803-221658-19787 (agent-compounds, 27 beads / 5 batches), +4 counted at the primary — the run that maps the rule's real boundary.** Four occurrences, and their value is that together they falsify the two folk-workarounds children keep re-inventing. (1) A `wc -l` reading from a variable-held path was blocked — the input side of a redirect is matched, not just the output side, so "I am only reading" is not an escape. (2) An error-stream redirect nested INSIDE a command substitution was blocked, confirming the rule matches anywhere on the line rather than at the top level, so wrapping the construct deeper does not hide it. (3) A `br list` write was blocked even though the destination path was a LITERAL that merely happened to be held in a variable — the guard cannot see that the variable's value is constant, so "make the path literal" only works if the literal is pasted at the call site; the child's successful substitute was `tee`, and `tee` should be named as THE sanctioned shape rather than left for each child to rediscover. (4) A write to a PID-suffixed scratch file was blocked for the same reason a RUN_ID-suffixed one is — process-unique names are dynamic by construction, so the standard "just use a unique temp file" advice collides head-on with this rule. Cost was ~4 blocked calls plus rediscovery time spread across four children. The pipeline-owned consequence: the delegation preamble and board-scan hand children shapes (1)-(4) directly, so every child pays this tax before it does any work, and the `tee` substitute is nowhere in the shared substrate.

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
- narrative: POINTER ENTRY, not a copy — the PRIMARY is `dcg-false-positives-on-angle-bracket-inside-quoted-prose` in `skills/ac-loop/FRICTIONS.md`, where occurrences are counted. Recorded here for the same reason as the sibling above: the shapes originate in ac-pipeline-owned shared text. RUN 20260803-221658-19787 contributed three occurrences (counted at the primary) that widen the class well beyond the markdown blockquote the primary was minted from. (a) A command was blocked because the word `restore` appeared as an ordinary English verb in a quoted prose payload — the guard's destructive-operation matcher reads command TEXT, so a bead comment that merely *describes* restoring a file is indistinguishable from one that does it. (b) An arrow written in prose was tokenised as a redirect, with nothing being redirected. (c) A placeholder in angle brackets inside a bead description body was read as a redirect target. All three are the same root as the primary and all three landed on payloads whose SHAPE this skill supplies. Two operational points worth carrying: the failure is per-call and self-inflicted at compose time, so it is fully preventable by never putting prose on a command line; and guidance that tries to warn about these shapes by showing them is itself blocked, which is why the fix must name constructs rather than demonstrate them.
