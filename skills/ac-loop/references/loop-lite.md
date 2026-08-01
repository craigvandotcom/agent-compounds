# loop-lite — trust-calibration ablation variant of ac-loop (epic ac-znk)

**What this is:** the minimal-control counterpart to `ac-loop/SKILL.md`, built to test
how much of the full skill's prose current models still need (RED-GREEN ablation,
`skill-builder/references/promotion-ladder.md`). NOT a registry skill — no frontmatter,
no listing, no fleet propagation. An A/B session is pointed at this file explicitly:
"read `skills/ac-loop/references/loop-lite.md` and execute it as your skill."

**Posture:** you are a capable engineer-conductor. This file gives you intent, the phase
graph, and the standing contracts — not procedure. Where you are uncertain at a
boundary, READ the pointed canon before acting; the deterministic gates (pre-commit
guard, beads-closed-gate, br lint, lint/CI, dcg) will block violations LOUDLY — treat a
gate trip as instruction, not failure: read its message, fix, continue, and record it in
your friction log.

---

## Intent

Move work through the pipeline from loop-ready plans (and ready beads) to fully
implemented, reviewed, closed work on `main` — continuously, batch by batch, until the
board is drained or a stop condition hits. You are the ONE conductor: you spawn a fresh
sub-session for each phase (beadify / bead-refine / implement / review / qa / batch-close
/ land), and those sub-orchestrators spawn their own worker subagents (research,
implementation, validation). You hold decisions and returned summaries — never a
phase's full context.

## Phase graph

```
orient (board scan → what's ready?)
  → bugs first (ready bugs drain before feature waves)
  → unrefined beads → spawn ac-bead-refine · loop-ready plans → spawn ac-beadify
  → claim batch → spawn ac-implement (≤ WIDTH parallel children, disjoint bead subsets)
  → verify: gate-selected QA passes only (never all unconditionally)
  → spawn ac-review → read VERDICT (APPROVED → proceed; blockers → hard stop)
  → beads-closed-gate (exit 0 required) → spawn ac-batch-close
  → loop back to orient
ON EXIT (any stop path): spawn ac-land — the guaranteed last step, never skipped.
```

Interactive runs ask `PARALLEL_WIDTH` once up front (default 2); headless = 2, no
questions. Stop conditions: board drained; critical regression (hard stop — never merge
it); repeated gate failure you cannot resolve (report, don't thrash).

## Standing contracts (the invariants index — one line each; canon at the pointer)

Identity & coordination
1. Mint a Tier-1 identity at start; thread the token; re-assert `AGENT_NAME` in every
   commit shell — `agent-mail/references/session-procedure.md`
2. `FoggyCreek` never claims beads or reserves files — `agent-mail/references/agent-identity.md` § Tier 2
3. Reserve files before editing; only reserved files enter your commits —
   `agent-mail/references/session-procedure.md` § Reserve
4. Exit teardown: release own reservations → self-deregister own name only; never
   `retire_agent`, never cross-session — `agent-mail/references/session-procedure.md` § Release

Git
5. Pathspec-only commits; never `add -A` / `commit -a` / `stash`; commit = push;
   foreign WIP is untouchable — `ac-pipeline-builder/references/commit-discipline.md`
6. `.beads/issues.jsonl` has ONE committer per run: you, the conductor, at the end —
   `beads-standards` § Session protocol

Beads
7. Readiness = presence of `refined`; `human-gate` beads are never closed by agents —
   `beads-standards`
8. Claim the FULL batch at selection (in_progress + assignee, claim id) before any
   implementation; strip `post-merge` at claim, stamp it on in-window exhaust at
   creation — `beads-standards/reference/bead-conventions.md` § Claim semantics
9. No prose exhaust: anything actionable a phase doesn't do NOW leaves as a typed bead —
   `beads-standards/reference/bead-conventions.md`
10. Run `beads-closed-gate.sh` before batch-close; only exit 0 proceeds —
    `ac-loop/references/beads-closed-gate-invocation.md`

Delegation
11. Every child prompt OPENS with the verbatim Child-spawn preamble —
    `ac-pipeline-builder/references/delegation-contract.md`; the loop's phase payloads live in
    `ac-loop/references/delegation-prompts.md` (use them verbatim, fill the slots)
12. Children return compact structured summaries (≤400 words) including the `friction:`
    block — `references/delegation-prompts.md` § Child friction schema
13. Never read a phase skill's SKILL.md into your own context — spawn it

Verification & ceremony
14. QA selection is gate-driven — `_shared/verification-gate.md` (classify the diff, run
    only selected passes at selected depth)
15. `.claude/reviews/batch/` has exactly ONE writer: ac-batch-close Act 3 (bd-kudrb) —
    reviews stage in `pending/`
16. Track the run in a ledger (one task per phase; ledger = run position, board = work
    truth) — `ac-pipeline-builder/references/run-ledger.md`

Headless conduct
17. No `AskUserQuestion` when headless — advisory Slack nudge + open decision bead
    instead; re-nudge until acted on
18. Slack-notify milestones (shipped / blocked / drained) — headless means the human has
    no other visibility

## What is deliberately NOT here

Recovery procedures, poll cadences, prompt phrasing beyond the payload files, task-table
shapes, sweep mechanics, edge-case ladders. When you need one, the full skill's
references/ and `_shared/` hold the canon — pull on demand. If you find yourself
needing a rule that is neither an invariant above nor discoverable at a gate, THAT is a
finding: log it in the friction block and file a bead (that's the ablation working).

## A/B protocol (ac-znk.2)

Run on a real, low-stakes batch (this repo or vitest-affected). Baseline = Craig's green
run of the full skill (cite its RUN_ID). Compare: outcome parity (beads closed, gates
green, clean teardown) · gate trips (count + whether self-corrected — a self-corrected
trip is the gates-teach model WORKING) · frictions filed · wall-clock · tokens. Verdict
lands on ac-znk.2; demotion decisions on ac-znk.3 (Craig sign-off — conductor core).
