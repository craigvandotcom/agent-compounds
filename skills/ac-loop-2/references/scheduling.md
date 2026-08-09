# ac-loop-2 — Scheduling

**ac-loop-2 is not scheduled by default.** Its Phase-1 barrier (THE SITTING) needs a human,
so a headless run can only specify a wave and stop cleanly at C1. `ac-loop` remains the
scheduled autonomous conductor; do not repoint an existing `ac-loop-*` job at ac-loop-2
without a human decision.

A deliberate headless "specify only" run — board scan, beadify-all, refine-all to contract,
then stop at the barrier — is legitimate and configured in `infrastructure/jobs/<app>.json`:

```json
{
  "name": "ac-loop-2-spec-<app>",
  "prompt": "Load the ac-loop-2 skill and run PHASE 0 + PHASE 1 ONLY for <app>, then stop at the sitting (C1). Working directory: <app-path>.",
  "schedule": "0 5 * * *",
  "enabled_on": ["<hostname>"],
  "channel": "<slack-channel-id>"
}
```

Headless runs never `AskUserQuestion` — every decision falls through to advisory nudges and
open `human-gate` decision beads (Exhaust Rule). The channel ID is what the scheduler posts
nudges and the decision docket to.

Run `ac-triage` as a **separate** scheduled job ahead of any ac-loop-2 run. Triage feeds
beads onto the board; Phase 1 specifies them. Keep them decoupled so triage failures never
block shipping.

**Keep-awake for long runs (defence in depth).** A run that outruns the display-sleep timer
stalls silently when the Mac sleeps. Three layers, in priority order:

1. **Wrap the run in `caffeinate -ims`** — the primary mechanism.
2. **launchd watchdog + SessionEnd resume file** — restarts/resumes a dropped run.
3. **In-session `ScheduleWakeup`** — third, last-resort layer ONLY. It is in-memory and dies
   with the process, so sleep kills the wake chain
   (`schedulewakeup-in-memory-only-sleep-kills-chains`); never rely on it as the primary.
