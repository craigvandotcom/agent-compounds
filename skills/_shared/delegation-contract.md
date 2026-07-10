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

**Applies to:** any `ac-*` skill that spawns background agents and continues —
notably `ac-review` (parallel reviewers) and `ac-merge` (waiting on PR
feedback/CI), plus `ac-loop`/`ac-qa-*` build monitors. Load this before writing a
spawn-and-continue step.
