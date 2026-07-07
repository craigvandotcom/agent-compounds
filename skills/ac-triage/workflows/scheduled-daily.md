# ac-triage — Scheduled Daily Run (headless heartbeat)

## THIS PROMPT IS YOUR TASK — EXECUTE IMMEDIATELY

You are invoked by `pai-scheduler` to run the **`ac-triage`** skill against this app's
pipeline (the job's `cwd` is the app repo). Execute without user interaction.

**⚠️ AUTONOMOUS MODE — no human is watching.** There is **no `AskUserQuestion`** in this
run. Anything that needs a human becomes an ops/`human-gate` bead + a Slack mention —
never a prompt. Run every step by actually executing the commands; do NOT just describe them.

**Read `.claude/skills/ac-triage/SKILL.md` first, then the app's
`.claude/skills/CORE/triage.md`** (enabled sources, severity bar, fetch specifics, Slack
channel). This heartbeat is the *run skeleton*; the skill is the *behavior*.

---

## Run skeleton

### 0. Preflight

- **Branch guard (first, before any reads or writes):** `git branch --show-current` must
  equal `main`. If it doesn't — **ABORT the entire run**: Slack `degraded` with reason
  `branch-guard: <branch> checked out`, zero writes, retry next cycle.
- **Slack probe (before any mutation):**
  `"$HOME/Repos/infrastructure/tools/bin/slack-send" --channel <channel from CORE/triage.md> --dry-run`
  (absolute path — this job runs `cwd`'d into the app). If the channel doesn't resolve,
  fall back to `pi`.
- **No Agent-Mail reservation** — a raw scheduler `prompt_file` run is not a
  self-registering Agent-Mail entry point (`agent-mail-project-keying-gotcha`). The
  append-only write set (step 3) is the collision guard.

### 1. Run the skill (Phases 0–4, exactly per SKILL.md)

- Watermarks from `.claude/state/triage-watermarks.json`; advance a source's watermark
  ONLY after its successful fetch.
- Fetch every source CORE/triage.md marks live. **Configured-but-failing → escalate**
  (ops `human-gate` bead, deduped against open ones), never silent-skip, never advance
  that watermark.
- Cluster, severity-filter, dedupe against open beads AND open pool candidates.
- Route by shape: defects → beads, ALWAYS `unrefined` (**the Phase-3a readiness bar** —
  permalink + suspected commit + repro + verification path — is evidencing guidance, not a
  stamping decision; only `/ac-bead-refine` ever applies `refined`, and a
  refined-by-construction bead just converges there fast); themes → `_backlog/pool/`
  candidates with `status: candidate`.

### 2. Group + refine (per-run epic + in-session `ac-bead-refine`)

- **Per-run epic:** if this run created 2+ finding-beads (Phase 3a), group them under one
  epic (`br create -t epic "Triage <date> — findings"`, children linked via parent-child
  deps). 0–1 beads → no epic.
- **In-session refine, before the report:** if this run created ≥1 bead, run
  `ac-bead-refine` NOW — scoped to the epic if one exists, to the single bead otherwise.
  0 beads → skip. Triage never stamps `refined` itself — that comes from this
  `ac-bead-refine` invocation's own convergence (SKILL.md Phase 3c).

### 3. Report + persist (even on a zero-findings run)

- Write the Phase-4 report to `.claude/state/triage-last-run.md` — an empty run still
  writes it (proof-of-life; a dead scheduler and a quiet prod must not look identical).
- Post the same report via `slack-send` to the app's channel.

### 4. Commit + push (pathspec-scoped ONLY)

- Stage only what triage owns: `.beads/*.jsonl`, `.claude/state/`, `_backlog/pool/`.
  Never sweep unrelated dirty files (concurrent sessions share this checkout).
- Commit on `main` with `AGENT_NAME=<name>` inline; push with `--no-verify` (the
  pre-push build hook swallows background pushes) and **verify the origin SHA** after.

### 5. Degrade loudly

Any failed step → `slack-send` a `TRIAGE DEGRADED: <reason>` line to the app's channel.
Exit without partial watermark advances.
