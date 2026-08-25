# ac-loop — Scheduling (PAI job config, triage decoupling, keep-awake layers)

ac-loop is designed to run as a scheduled PAI job (headless). Configure in `infrastructure/jobs/<app>.json`:

```json
{
  "name": "ac-loop-<app>",
  "prompt": "Load the ac-loop skill and run the autonomous shipping loop for <app>. Working directory: <app-path>.",
  "schedule": "0 */4 * * *",
  "enabled_on": ["<hostname>"],
  "channel": "<slack-channel-id>"
}
```

Headless runs never `AskUserQuestion` — all decisions fall through to advisory nudges + open `human-gate` decision beads by design (Exhaust Rule). The channel ID is used by the scheduler to post nudges and thread updates.

Run `ac-triage` as a **separate** scheduled job before `ac-loop` (e.g., 30 min earlier). Triage feeds beads into the board; the loop ships them. Keep them decoupled so triage failures don't block shipping.

**Keep-awake for overnight/headless runs (defence in depth).** A scheduled loop that outruns the display-sleep timer stalls silently when the Mac sleeps. Three layers, in priority order:

1. **Wrap the run in `caffeinate -ims`** (keep-awake) — the primary mechanism. This is what actually keeps a long headless loop alive across the night.
2. **launchd watchdog + SessionEnd resume file** — restarts / resumes a run that dropped.
3. **In-session `ScheduleWakeup`** — arm it ONLY as the third, last-resort layer. It is **in-memory and dies with the process**, so sleep kills the wake chain (memory: `schedulewakeup-in-memory-only-sleep-kills-chains`); never rely on it as the primary keep-awake.
