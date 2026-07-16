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
   success from "it didn't error." A delegate that died after a terminal API
   error returns nothing; treat missing output as failure, not completion.
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
   § "Recurs on LOCAL long test runs" (RUN_ID=20260710-170558-52993 — an
   `ac-implement` session AND its `ac-merge` sibling both detached from a live local
   vitest run and stalled, each recovered only by a coordinator `SendMessage` poke).
   Recurred again 2026-07-16: a `ac-qa-browser` conductor ended its turn **twice**
   mid-run ("await the w6 completion event", `Monitor`-armed-then-exit) and needed
   two coordinator pokes; a foreground until-loop with generous Bash timeouts was
   the fix both times.

**Applies to:** any `ac-*` skill that spawns background agents and continues —
notably `ac-review` (parallel reviewers) and `ac-merge` (waiting on PR
feedback/CI), plus `ac-loop`/`ac-qa-*` build monitors — AND any skill/session that
backgrounds its OWN long-running command (test suite, build, CI poll) instead of
waiting for it in-shell (the self-detachment case in clause 5). Load this before
writing a spawn-and-continue OR a background-your-own-command step.
