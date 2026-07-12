# ac-prove — Scheduled Cron Entrypoint (ready, UNWIRED)

## STATUS — NOT YET LIVE

**This file is a spec, not an active heartbeat.** Consumer (b) — idle-cron `ac-prove` — is
**DEFERRED** per bd-pwt44.2's plan; this document ships the ready-to-wire entrypoint spec so a
future bead can attach it to `pai-scheduler` without redesigning it. **No `daily.json` entry
lands this plan** — do not register this workflow with the scheduler as part of shipping this
file. Treat everything below as "what the cron job will do once someone wires it," not "what
runs tonight."

---

## THIS PROMPT IS YOUR TASK — EXECUTE IMMEDIATELY (once wired)

When a future bead wires this up, `pai-scheduler` invokes the `ac-prove` skill in **`ensure`**
mode, at **`ci` depth** (the base full-suite proof itself — no `+qa` layer; `+qa` is a ship-path
concern, not an idle-cron one), against the app's current `main` HEAD. Execute without user
interaction.

**⚠️ AUTONOMOUS MODE — no human is watching.** There is no `AskUserQuestion` here. Anything
this run can't resolve itself becomes a bug bead + a Slack nudge — never a blocking prompt.

**Read `.claude/skills/ac-prove/SKILL.md` first** — it defines the freshness probe, dispatch,
Green Gate, and receipt-contract mechanics this heartbeat invokes. This file is the *run
skeleton*; the skill is the *behavior*.

---

## Run skeleton

### 0. Preflight

- **Branch guard:** `git branch --show-current` must equal `main`. Any other branch checked
  out → abort silently (this is a read/prove job, not a writer — no Slack noise needed for a
  branch-guard miss, just skip this cycle and let the next one retry).
- **Defer-if-busy:** if a `reason=prove` (or any `workflow_dispatch`) run is already
  `in_progress`/`queued` for this repo (`gh run list --workflow=quality-gate.yml
  --json status,event`), **defer this cycle entirely** — do not queue a second dispatch behind
  it, do not wait for it. Re-check next cycle. `ac-prove` is the sole dispatcher of
  `reason=prove`; this cron entrypoint must not contend with itself, `ac-publish`,
  `ac-distribute`, or a manual invocation for the same run slot.

### 1. Invoke `ac-prove`

```
ac-prove: ensure, ci depth, --ref <current main HEAD>
```

- **Mode is always `ensure` — NEVER `ensure --fix-forward`.** An idle-cron heartbeat is not a
  ship path; it must never commit a fix on its own authority. If the probe is stale, it
  dispatches and waits for the result — it does not touch the tree if that result is red.
- **`ci` depth** — the base full-suite proof only. No `+qa` device/browser layer on an idle
  cadence; that's reserved for the ship-time consumers (a/d in `SKILL.md`'s Consumer Roster).

### 2. On GREEN — silent

If `ac-prove` returns a green, tip-valid proof: **do nothing else.** No bead, no Slack message,
no report file. A healthy nightly proof is exactly the expected steady state — silence is the
correct signal. (Contrast `ac-tidy`/`ac-triage`'s "write a proof-of-life report even on zero
findings" pattern — that doesn't apply here; `ac-prove`'s own dispatched-run history on GitHub
Actions already IS the proof-of-life trail for this job.)

### 3. On RED — file a bug bead with STRUCTURAL dedup, one Slack nudge

If the dispatched full run comes back red (any Step-3 Green Gate failure the skill couldn't
resolve, since fix-forward is never invoked here):

1. **Dedup structurally before filing.** Never hash/compare the LLM-authored bug title or
   description text for dedup — those reword nightly even for the identical underlying failure
   (memory: `llm-agent-dedup-structural-keys`). Key the dedup on **structural** discriminators
   that are verified to exist on the actual CI payload, e.g.:
   - the failing job/step **name** (`gh run view <runId> --json jobs` → failed job's `name`)
   - the **first failing test file path** (or failing script name) parsed from the log
   - the run's **workflow + `reason=prove`** tag, so this never collides with an unrelated
     `batch-close`/`publish`/`loop-close` failure bead

   Search open bug beads for one matching that structural key
   (`br list --json --type bug --label ac-prove-nightly` or equivalent), closed matches still
   link (a closed match at any age is evidence this is a recurrence, not proof it's fixed) — but
   only **open** matches suppress filing a duplicate.
2. **No match →** file one:

   ```bash
   br create "ac-prove nightly: <structural failure key>" -t bug \
     --labels "ac-prove-nightly" -p 2 \
     --description "Nightly ensure-depth ac-prove run went red at <SHA/runId/URL>. <failing job/step + first failure>. Filed by the scheduled ac-prove heartbeat — fix-forward is never invoked from this path, so this needs a human/loop pickup."
   ```

3. **Match found (open) →** do not file a duplicate; optionally comment the new run's URL onto
   the existing bead for recurrence evidence.
4. **Exactly one Slack nudge per red cycle** (not per bead, not per retry) — a single card, even
   if this is a repeat of an already-open bead:

   ```bash
   slack-send --channel sofi --card \
     --title "ac-prove nightly: main is red" \
     --body "Nightly ensure-depth proof failed for <app> at <SHA>. <bead id or 'already tracked in <existing bead id>'>. Run: <URL>."
   ```

### 4. Never `--fix-forward` from this path

This heartbeat is read/dispatch-only. It must never invoke `ensure --fix-forward` — fixing
forward commits code, and an unattended cron job is not the place for autonomous fixes to a
red main. A red result here is a signal for a human or the loop to pick up, not something this
job resolves itself.

---

## Remember

- **UNWIRED** — this spec exists so a future bead can wire it without redesigning the shape;
  wiring it into `pai-scheduler`'s `daily.json` is explicitly **out of scope** for the bead that
  ships this file.
- **`ensure`, `ci` depth, never `--fix-forward`** — the three non-negotiables of this entrypoint.
- **Defer, don't queue, if busy** — never contend with another `reason=prove` dispatcher.
- **Silent on green, one structural bug bead + one Slack nudge on red** — no per-run noise on
  the happy path, no duplicate-bead spam on the unhappy one.
