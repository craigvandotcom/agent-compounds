---
name: dream
description: Run the dream session — the org's deliberate self-improvement review, human-run and unscheduled. Use when asked to "run the dream cycle", "dream", "synthesize the week's lessons", "lint the memory substrate", "review the dream dockets", or "what did the dream cycle find"; also when ac-human's friction or memory card offers it. The session reads both ranked dockets (memory-rollup — knowledge substrate, friction-rollup — friction ledger, both computed live), rules each item with the human, and fixes approved items in-session for the human to review. NOT for capturing one session's lessons (that is reflect) or saving a single item (that is context-engineering routing).
---

# dream — human judgment over the ranked docket

**Purpose:** the compounding engine (Primitive #4), run as a deliberate human session.
**Constitution:** `../context-engineering/SKILL.md` (load it first — taxonomy, homes,
hygiene rules all come from there).
**Dockets (input):** `scripts/memory-rollup.py --json` (knowledge substrate) +
`../skill-builder/scripts/friction-rollup.py --root <repo> --view dream` (friction ledger) —
computed live on every read, never stored. `<repo>` is the current repo when it has
`skills/*/FRICTIONS.md`, else the registry: the logs ac-human's cards read. **Status:** MANUAL.

---

## What dream is

A human-run session with the agent present. Nothing in dream runs unattended; no cron
invokes it. The jobs in `<your-deployment>/jobs/weekly.json` sit disabled (see The polish
gate). A session starts because a human starts it — usually from ac-human's offer.

## Session workflow — three phases

### Phase 1 — GATHER

Run both rollups (above). Scan ledgers changed since the last session — friction logs,
memory homes, wiki, pending proposals. Verify each item's premise at HEAD; an item whose
premise no longer holds leaves the docket.

### Phase 2 — JUDGE (with the operator)

Rule each ranked item: **fix now** · **won't fix** · **later**. Capture every ruling in
**EXACT phrasing — never paraphrase**: the words are the decision, and a paraphrase is a
new decision nobody ruled on.

### Phase 3 — FIX (in-session)

- **Fix now:** make the change, show the diff, commit on the operator's approval. One
  commit per repo, never across a repo boundary. A behaviour change ships with its test
  or the command that proves it.
- **Close in the same commit:** the friction entry's `status: promoted` (memory item:
  its resolution), citing the change.
- **Too big for the session** (a new tool, a redesign, more than a few files): capture it
  with `ac-backlog`; never start it here.
- **Won't fix:** `status: wontfix` plus the ruling. **Later:** leave it; it re-ranks.
- **Close the session:** `friction-rollup.py --root <repo> --stamp` (records `last_pass`),
  then a **gap analysis** — what the substrate still doesn't know. The next GATHER
  starts there.

## The polish gate

Automation does not scale back up — crons, filing, auto-tier — until the manual loop
has run enough sessions to trust its output. While the `weekly.json` jobs sit disabled,
dream stays a human session.

## Common mistakes

| Mistake | Fix |
|---|---|
| Running dream unattended | Never — a session is a human sitting with the agent |
| Paraphrasing a ruling | Capture in the exact phrasing — a paraphrase is a new ruling |
| Filing a bead for a fix that fits the session | Fix it now; `ac-backlog` is for work too big for it |
| Fixing an item whose premise already died | Verify at HEAD first |
| Landing a fix without closing its entry | The status change and the fix are one commit |
