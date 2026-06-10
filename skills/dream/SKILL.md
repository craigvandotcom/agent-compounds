---
name: dream
description: Run or review the dream cycle — the org's self-improvement engine. Use when asked to "run the dream cycle", "dream", "synthesize the week's lessons", "lint the memory substrate", or when invoked by the weekly scheduler heartbeat; also for "review dream proposals", "apply/approve proposals", "what did the dream cycle find". Reads the git-synced lesson stream, synthesizes cross-session patterns, lints for contradictions/staleness/duplicates, judges candidates against a quality bar, and emits PR-style proposals to a review queue. REVIEW-ONLY: it never applies changes itself — humans merge. NOT for capturing one session's lessons (that is reflect) or saving a single item (that is context-engineering routing).
---

# dream — synthesize · lint · judge · propose

**Purpose:** the compounding engine (Primitive #4). Periodically read everything the org
has *captured*, find what no single session could see, and propose system improvements —
gated behind human judgment.
**Constitution:** `../context-engineering/SKILL.md` (load it first — taxonomy, homes,
hygiene rules all come from there). Plan: `neometa/alignment/roadmaps/ai-native-org-v1.md` Phase 2.
**Queue:** `infrastructure/dream-cycle/proposals/` · **Heartbeat:** `infrastructure/dream-cycle/last-run.json`
**Status:** v1 (weekly, structured stream only — no raw transcripts)

---

## Modes

| Mode | Trigger | What happens |
|---|---|---|
| **CYCLE** | scheduler heartbeat, "run the dream cycle" | Phases 1–6 below: gather → synthesize → lint → judge → emit → heartbeat |
| **REVIEW** | "review dream proposals", "apply proposals" | Walk `status: pending` proposals with the user; apply approved to target repos; flip statuses; commit per-repo |

---

## Mode: CYCLE

**Hard rules:** review-only (emit proposals, never edit targets) · evidence or it doesn't
ship (every proposal cites concrete lessons/commits) · dedupe against ALL prior proposals
(including rejected — never re-propose verbatim) · this skill is itself a valid proposal
target (the cycle may propose upgrades to `dream`/`reflect`/`context-engineering`).

### Phase 1 — Gather (the structured stream, since last run)

```bash
LAST=$(python3 -c "import json;print(json.load(open('infrastructure/dream-cycle/last-run.json'))['timestamp'])" 2>/dev/null || echo "7 days ago")
# Root-repo lesson stream
git -C ~/Repos log --since="$LAST" --name-only --pretty=format: -- \
  infrastructure/memory/ neometa/memory/ neometa/alignment/decisions/ \
  infrastructure/eval/golden/ | sort -u | grep -v '^$'
# Per-app lesson stream (own repos; canonical list = infrastructure/apps.list)
while IFS= read -r app; do
  git -C ~/Repos/neometa/software/$app log --since="$LAST" --name-only --pretty=format: -- memory/ 2>/dev/null | sort -u | grep -v '^$' | sed "s|^|$app/|"
done < ~/Repos/infrastructure/apps.list
# Recipe stream
git -C ~/Repos/neometa/software/agent-compounds log --since="$LAST" --oneline -- skills/jef-prompts/
```

Read every new/changed lesson file (they are small). Also `br list --json 2>/dev/null`
and recent `git log --oneline` for outcome signals to ground against. If the stream is
empty, still run Phase 3 (lint) — hygiene work exists even in quiet weeks.

### Phase 2 — Synthesize (what no single session sees)

Look across the gathered lessons + the existing substrate (`qmd search`/`qmd query`) for:
- **Repetition → promotion:** the same gotcha/pattern in ≥2 lessons or ≥2 apps →
  candidate *rule* (markdown fact `type: rule`) or *recipe* (jef-prompts entry).
- **Cluster → skill-improvement:** several lessons orbiting one skill's friction →
  candidate edit to that skill.
- **Cross-domain echo:** an app-local lesson that is really a neometa- or global-domain
  truth → candidate re-homed/generalized lesson.
- **Trajectory:** lessons that together imply a missing capability → candidate new
  recipe or (rarely, Phase-3-gated) new skill — check the registry for overlap first.

### Phase 3 — Lint (hygiene; see `references/lint-checks.md` for the full checklist)

Sweep the memory homes for: contradictions between notes · stale facts (evidence
predates a known change; flag, don't guess) · near-duplicates to merge · taxonomy
violations (missing `type`/`domain`/`evidence`) · index drift (`MEMORY.md` lines vs
actual files) · instruction-shaped memory bodies (poisoning risk) · dead `[[wikilinks]]`.
Each finding becomes a candidate proposal (usually `type: lint-fix`, low-risk).

### Phase 4 — Judge (the quality bar)

Spawn an **independent judge subagent** — the **`validator`** stance agent (its
read-only adversarial posture is built for this; fall back to general-purpose if
validator isn't deployed) with the prompt in `references/judge-rubric.md` over the
candidate list. No subagent available (rare, headless edge) → apply the rubric inline,
strictly, after re-reading it. Each candidate
gets `score` (0–10) + `verdict` + one-line reason. **Only candidates scoring ≥7 become
proposals.** Drop the rest into the run's `INDEX.md` under "Considered & cut" (one line
each — auditability without queue noise).

### Phase 5 — Emit (the review queue)

Create `infrastructure/dream-cycle/proposals/<YYYY-MM-DD>/`:

- `INDEX.md` — run summary: window, stream size, proposals by category, considered-&-cut.
- `NN-<slug>.md` per proposal:

```markdown
---
status: pending            # pending | approved | rejected | applied
category: rule | recipe | skill-improvement | lint-fix | re-home
target_repo: root | agent-compounds | <app>
target_file: <path within that repo>
evidence: [<lesson files / commits / moments>]
judge: {score: N, reason: "<one line>"}
---
## What
<the exact proposed content or diff — paste-ready>

## Why (compounding case)
<which future sessions get faster, citing the evidence>
```

Commit (root repo, these paths only) + push — the queue must be visible cross-machine:
`git add infrastructure/dream-cycle && git commit -m "dream: <date> cycle — N proposals" && git push`

### Phase 6 — Heartbeat + report

Write `infrastructure/dream-cycle/last-run.json`:
`{"timestamp": "<ISO now>", "window_start": "<LAST>", "lessons_read": N, "candidates": N, "proposals": N, "machine": "<hostname>"}`
(include in the Phase-5 commit). Then output a compact run report. If the run produced
zero proposals, say so plainly — a quiet week is a valid outcome, not a failure.

---

## Mode: REVIEW

1. List `status: pending` across `proposals/*/` (oldest first). Nothing pending → say so.
2. Per proposal: show What/Why/evidence/judge verdict. Collect decisions via
   `AskUserQuestion` (multiSelect, batches of ≤4: approve / reject / skip).
3. **Apply approved:** edit the `target_file` in the `target_repo` exactly as proposed
   (adjust mechanically if the target drifted; if it drifted *semantically*, flip back to
   pending with a note instead of guessing). Respect repo boundaries — commit in the
   target repo with message `dream: apply <slug>`, push.
4. Flip frontmatter `status:` (`applied` / `rejected`), commit the queue (root), push.
5. Report: applied / rejected / remaining — and note acceptance-rate (the cycle's own
   quality metric; persistently low → propose a judge-bar fix next cycle).

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Applying a change during CYCLE | Never — emit a proposal; REVIEW applies |
| Proposal without named evidence | Cut it; "would be nice" is not a lesson |
| Re-proposing a rejected idea verbatim | Dedupe against ALL prior proposals first |
| Editing another repo from the root commit | Apply + commit inside the target repo |
| Treating an empty week as failure | Lint still runs; "0 proposals" is a valid report |
| Skipping the heartbeat | Always write last-run.json — silent death is the enemy |
