# Background delegation contract — spawn-and-exit safely

When you spawn a background subagent (or any async delegate) and move on, the
**resume chain can break silently**: the delegate pauses — on a build monitor, a
poll loop, an API hiccup, a paused sub-subagent — and never resumes. Silence then
*looks like progress*. This has recurred across 5+ sessions (memory:
`background-agent-resume-chains-break-silently`,
`background-agent-resume-chains-break-silently.md`).

**The contract — every time you delegate and don't block on the result inline:**

1. **Never hand off to an unbounded wait.** Bound every wait with a hard cap:
   poll on a fixed cadence up to N iterations, then act — do NOT `sleep` on an
   open-ended "monitor" and assume it will wake you.
2. **Arm a watchdog.** A deadline after which you assume failure and
   proceed/report, or a `sleep` + `SendMessage`-poke to nudge a silent delegate.
   The conductor's timer is the backstop, not the delegate's own promise.
3. **A stalled/silent delegate is a reportable OUTCOME, not a pause.** After the
   cap, surface `stall`/`no-return` explicitly and keep the parent moving —
   never let one quiet delegate freeze the whole run.
4. **Verify the actual result** (return value / artifact / journal), don't infer
   success from "it didn't error" — nor from the delegate SAYING so: **a declared
   done-state is a CLAIM, not evidence.** `completed` fires mid-flight, and children
   have died on a 529 while reporting success; verify the DECLARED artifact — stamp
   present, VERDICT written, commits in `git log`. Missing output = failure, not done.
   **A PARTIAL artifact is not the result either.** A still-live delegate's
   in-progress files are intermediate state: `pending`/unfilled fields mean NOT
   YET, not NEVER. **Poke first and wait for the answer; act on intermediate state
   only after the poke goes unanswered past the cap** — and prefer completing the
   delegate's work over redoing it. Evidence (RUN 20260729-170058-3584): a conductor
   triaged a stalled `ac-qa-browser` by reading its verdict files, saw 5 findings
   with no bead id, and filed all 5; the child then woke and filed its own richer 5
   → 4 duplicate beads plus 1 false P2 App-Store-compliance bead, all to retract.
5. **Self-detachment is a violation too — not just spawning-a-child-and-moving-on.**
   The failure mode is NOT limited to handing off to a *separate* subagent. The
   acting session backgrounding its OWN long-running local command — e.g. `pnpm
   test` / `vitest` via `run_in_background` + a `Monitor`, or a build/CI poll —
   and then **ending its turn** ("monitor armed, waiting for completion") is the
   same silent-stall pattern pointed at yourself: the turn ends, nothing resumes,
   and the silence reads as progress. If a local command is the thing you are
   waiting on, **wait for it in-shell**: a foreground until-loop (`pgrep`/poll on a
   fixed cadence) with a generous Bash timeout, not a background handle you detach
   from and hope wakes you. Evidence: `background-agent-resume-chains-break-silently.md`
   § "Recurs on LOCAL long test runs". The same failure also appears as a
   `Monitor`-armed-then-exit turn end ("await the completion event") needing
   coordinator pokes; a foreground until-loop with generous Bash timeouts was
   the fix both times.

**Applies to:** any `ac-*` skill that spawns background agents and continues —
notably `ac-review` (parallel reviewers) and `ac-merge` (waiting on PR
feedback/CI), plus `ac-loop`/`ac-qa-*` build monitors — AND any skill/session that
backgrounds its OWN long-running command (test suite, build, CI poll) instead of
waiting for it in-shell (the self-detachment case in clause 5). Load this before
writing a spawn-and-continue OR a background-your-own-command step.

---

## Child-spawn preamble (the child-side environment contract)

Clauses 1–5 above govern the CONDUCTOR. This section governs the CHILD — and the
rule is: **the conductor includes the preamble block below VERBATIM in every child
delegation prompt.** A pointer ("see delegation-contract.md") is NOT sufficient: a
fresh child acts before it reads, and every environment rule it must re-derive is
a rediscovered failure. Evidence (ac-loop RUN 20260719-102946-27401): with
pointer-only guidance, 3 distinct children self-detached and 3 independently
rediscovered the Agent Mail token rule; after the conductor began inlining these
clauses verbatim, recurrence dropped to zero for the rest of the run.

**Scope of the "a pointer is not sufficient" rule — both halves.** It binds the files that
**construct child prompts**: those must carry the block pasted verbatim, each one marked
with a `mirror:` marker citing this section, and `lint.sh` § Check 16 byte-compares every
such copy against the block below. For every other consumer — skills that merely cite this
document as doctrine and spawn nothing — **pointer-only reference is correct** and no copy
should be backfilled; the block is paid for by each child that reads it, so duplicating it
where no child is spawned is pure cost.

**The preamble (copy verbatim; substitute the child's `AGENT_NAME` — you mint it; ~240 words):**

> ENVIRONMENT CONTRACT (non-negotiable):
> - WAIT for your own long-running commands in-shell (foreground, generous Bash
>   timeout, or a foreground until-loop). Never arm a Monitor on your own command
>   and end your turn — if a completion event already fired, read it and CONTINUE.
> - Agent Mail: CHECK whether you hold `mcp__mcp-agent-mail__*` tools — assume neither way.
>   Usually you do NOT: then don't try to register, and your conductor owns reservations.
>   Either way, export the `AGENT_NAME` it gave you in each commit's own shell.
> - Touching beads (`br`/`bv`)? The canon is `beads-standards` (+ its
>   reference/bead-conventions.md for pipeline contracts) — read before inventing usage.
> - After every push: verify origin SHA == local HEAD before proceeding.
> - A guard block (dcg / pre-commit) means CHANGE APPROACH, never bypass. To DISCARD
>   a change: `git checkout HEAD -- <path>` AND unscoped `git stash` are both blocked —
>   use scoped `git stash push -- <paths>`; to read a pristine file, `git show <ref>:<path>`.
>   Destructive commands (rm / find -delete) take FULLY-LITERAL paths: resolve
>   first (`ls -d`), then paste literals — never `$VAR`, `$( )`, or a loop var.
>   /tmp literals + distinctive /tmp globs are allowed; home/repo `rm -rf` never
>   is — `git rm` if tracked, else gitignore-and-flag or ask the human.
> - Shared checkout: commit your bead's files (pathspec-scoped) the INSTANT its
>   ACs verify — minimal working-tree dwell; run `br` from the bead-board repo root.
> - Autonomous run: never AskUserQuestion — Exhaust Rule.
> - Return a structured `friction:` block (stage/cost/lesson/class; `[]` if clean).

Keep the preamble SHORT. It is loaded into every child prompt, so every added line
is paid on every delegation — high-recurrence behavioral clauses only. Tooling
trivia (CLI flag quirks, JSON shapes) stays in the memory substrate, not here:
those cost ~1 wasted call per hit, while a bloated preamble costs every child.
Amend this block only for a failure class observed across MULTIPLE children or
runs (recurrence ≥2 in the loop-retro carrier / memory bumps).

---

## Payloads point, contracts paste

This section governs the TASK PAYLOAD only — the env-contract preamble above
stays verbatim-pasted per its own evidence (a pointer-only preamble is
insufficient; a fresh child acts before it reads). Payloads are the opposite
case: conductors must not GENERATE payload context into N child prompts
(conductor output tokens × panel width) where one artifact file or one
deterministic command would do — a pasted payload is a drift vector as well as
a cost (children reading primary sources beat pasted briefs). Three rules for
every constructed child prompt:

1. **Literal paths, never vars.** Payload read lines carry fully-resolved
   literal paths/args at spawn time — never `$VAR`, `$( )`, or "the artifacts
   dir"; the child must be able to run the line verbatim.
2. **The payload read is numbered step 1 of the child prompt.** The child
   acquires its payload before any task instruction acts on it.
3. **Verdicts must cite the payload read.** Each child's output format carries
   one payload-citation field naming the literal path(s)/command from its read
   list — the completeness-validator tripwire: a verdict that cannot name its
   payload is a child that never read it.

**Payload transport — the invariant is NEVER paste bulk payload content
inline.** Transport is chosen by whether a deterministic primary source exists:

- **Command transport** — the payload is live repo/board state a command can
  regenerate deterministically: point children at that command with literal,
  resolution-anchored args (`br show <id>`, `git diff <sha-anchored range>`).
- **Artifact transport** — the payload is conductor-authored content with no
  primary source (e.g. `proposed-structure.md`): a written artifact file read
  by literal path is the correct transport, not a violation.

**Converted-prompt shape (exactly TWO edits per prompt; nothing else
restructures or renumbers):**

- **(i) Payload read list** — replace the pasted payload block(s) with a
  numbered list containing ONLY payload acquisitions, one line per payload:
  `1. Read <literal path>` (artifact transport) or `1. Run: git diff <literal
  resolved range>` (command transport). A multi-payload prompt gets ONE list
  replacing all its pasted blocks and their per-payload sub-headings; the
  prompt's existing task sections ARE the task — they stay unchanged,
  un-numbered, and nothing after the read list is renumbered.
- **(ii) Verdict citation** (rule 3) — the prompt's output format gains exactly
  one payload-citation field: a `**Payload read:**` line in markdown output
  formats; a top-level `"payload_read"` string key in JSON schemas (additive —
  conductors' findings merges ignore unknown keys).

**Anchor-assert gate:** any instruction that tells a future
conductor to paste a block "at/after `<anchor>`" is EXECUTED at authoring time — grep the
anchor inside the actual `Task(` prompt body (or fence) it names, not merely the file: an
anchor found only in a header instruction is the inert-paste failure mode (shipped 6/12
sites broken across two waves). Paste the grep + count as proof next to the instruction.

## Brief claims are HINTS — `br show` is authoritative

A delegation brief is written by a conductor at spawn time and read by a child at act
time. Everything factual in it — bead status, preconditions already satisfied, which
files are clean, which tools are available — may have drifted in between, or may have
been wrong when written.

**The child re-derives before acting:**
- Bead spec, status and ACs → `br show <id>` (never the brief's restatement).
- Working-tree/branch state → ask git, never the brief and never the filesystem
  (`git-state-checks-ask-git-not-the-filesystem`).
- Tool availability → probe it; a brief asserting a tool works is not a probe.

**Standing sanctions go in VERBATIM, not as a pointer.** A prose control reaches exactly
the agents whose prompt contains it — it does not cascade to grandchildren the conductor
never sees. If a rule must hold at arbitrary delegation depth, either machine-enforce it
(hook / dcg pack / pre-commit gate) or paste it verbatim into the leaf prompt.
