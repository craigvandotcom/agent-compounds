---
name: dream
description: Run or review the dream cycle — the org's self-improvement engine. Use when asked to "run the dream cycle", "dream", "synthesize the week's lessons", "lint the memory substrate", or when invoked by the weekly scheduler heartbeat; also for "review dream proposals", "apply/approve proposals", "what did the dream cycle find". CYCLE mode emits proposals only; REVIEW mode applies human-approved proposals. NOT for capturing one session's lessons (that is reflect) or saving a single item (that is context-engineering routing).
---

# dream — synthesize · lint · judge · propose

**Purpose:** the compounding engine (Primitive #4). Periodically read everything the org
has *captured*, find what no single session could see, and propose system improvements —
gated behind human judgment.
**Constitution:** `../context-engineering/SKILL.md` (load it first — taxonomy, homes,
hygiene rules all come from there). Plan: `neometa/alignment/roadmaps/ai-native-org-v1.md` Phase 2.
**Queue:** `infrastructure/dream-cycle/proposals/` · **Heartbeat:** `infrastructure/dream-cycle/last-run.json`
**Status:** v1 LIVE (weekly, structured stream only) · v2 daily raw-transcript mining
DESIGNED (`Mode: CYCLE-DAILY` below; activates after transcript replication v2-a lands)

---

## Modes

| Mode | Trigger | What happens |
|---|---|---|
| **CYCLE** | scheduler heartbeat, "run the dream cycle" | Phases 1–6 below: gather → synthesize → lint → judge → emit → heartbeat |
| **CYCLE-DAILY** | daily scheduler (v2; after v2-a), "mine the transcripts" | Precondition check (verify, don't clean) → raw-transcript mining funnel → reuses Phases 2/4/5; consumes the `infra-maintain` health report. See the mode section below |
| **REVIEW** | "review dream proposals", "apply proposals" | Walk `status: pending` proposals with the user; apply approved to target repos; flip statuses; commit per-repo |

**Auto-act tier (the gate-skip).** Not every proposal needs Craig's tap. The daily queue job
(`.claude/skills/dream/workflows/dream-daily.md` — relocated from the archived
`_agent-pi/workflows/dream-daily.md` in memory-wiki-upgrade Phase 2c) classifies each
proposal **deterministically**
(`infrastructure/dream-cycle/classify.py`) into `auto` or `gated` (everything judgment-laden).
`auto` has two shapes: **Tier-1** (a pure new-memory-note ADD to root, judge ≥9 — append-only)
and **Tier-0** (a `lint-fix` the script can *re-derive and apply itself* — e.g. `index-prune`;
zero LLM trust, verification is the gate). It applies the `auto` tier unattended and files
`gated` ones as `human-gate` decision beads in their target repos (`file-beads.py`), worked via
`ac-human-session` (the decision docket); Slack is a digest nudge, not the decision surface. The
autonomy axis is **reversibility × judgment, not cadence** —
lossless/mechanical → auto; lossy (merge/summarise) or judgment-laden → gated. Policy + the
exact predicate: `references/auto-act-rubric.md`; architecture:
`neometa/alignment/decisions/2026-06-26-tiered-memory-autonomy.md`. CYCLE itself still **never
applies** — it only emits; the auto-apply lives in the daily job (Stage-1 autonomy = deterministic hygiene only).

---

## Mode: CYCLE

**Hard rules:** review-only (emit proposals, never edit targets) · evidence or it doesn't
ship (every proposal cites concrete lessons/commits) · dedupe against ALL prior proposals
(including rejected — never re-propose verbatim) · this skill is itself a valid proposal
target (the cycle may propose upgrades to `dream`/`reflect`/`context-engineering`).

### Create Workflow Tasks (run ledger — CYCLE mode)

**One task per phase — this ledger is scheduler-run, so it's the only proof-of-life until
the Phase-6 heartbeat writes.** Create these upfront; `TaskUpdate` each to `in_progress`
when its phase starts and `completed` when it ends. The Phase-4 judge subagent (validator
stance) keeps its own scope — this ledger tracks CYCLE's top-level phases only. (CYCLE-DAILY,
still DESIGNED not live, reuses Phases 2/4/5 unchanged when it activates — its own ledger,
if any, is a future addition, not this one.)

```
TaskCreate("Gather lessons — structured stream since last run")
TaskCreate("Synthesize patterns — repetition, clusters, cross-domain echoes, promotions")
TaskCreate("Lint substrate — contradictions, staleness, duplicates, taxonomy, registry")
TaskCreate("Judge candidates — validator-stance rubric, score >=7 to proposal")
TaskCreate("Emit proposals — write the review queue, commit + push")
TaskCreate("Heartbeat + report — last-run.json, run summary")
```

**TaskUpdate("Gather lessons", in_progress)**

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
# Calibration rollup (observe-loop signal; tolerate absence — it lands as a parallel
# work item, never fail this phase on it)
python3 ~/Repos/infrastructure/telemetry/telemetry.py rollup 2>/dev/null || echo "(telemetry rollup unavailable this run — note it in INDEX.md, don't fail the phase)"
```

Read every new/changed lesson file (they are small). Also `br list --json 2>/dev/null`
and recent `git log --oneline` for outcome signals to ground against. If the stream is
empty, still run Phase 3 (lint) — hygiene work exists even in quiet weeks.

Capture the rollup's calibration markdown block (acceptance rate — trailing 4 weeks,
**gated-proposals-only** scope, denominator stated) — Phase 5 folds it verbatim into
this run's `INDEX.md`. If the command was absent or failed, carry forward a one-line
"telemetry rollup unavailable" note instead; don't block the cycle on it.

**TaskUpdate("Gather lessons", completed)**
**TaskUpdate("Synthesize patterns", in_progress)**

### Phase 2 — Synthesize (what no single session sees)

Look across the gathered lessons + the existing substrate (`qmd search`/`qmd query`) for:
- **Repetition → promotion:** the same gotcha/pattern in ≥2 lessons or ≥2 apps →
  candidate *rule* (markdown fact `type: rule`) or *recipe* (jef-prompts entry).
- **Loop-retro observation mining (recurrence×cost → bounded promotion):** scan the keyed
  loop-retro corpus — `memory/auto/` rows carrying `metadata.kind: loop-retro-observation`
  (written by `reflect`'s Tier-3 primitive, bd-jv33f.5) — and compute
  `score = recurrence × cost_weight` per row (`cost_weight`: `material` = 3, `minor` = 1; the
  constant is tunable, not load-bearing). Rank by score and promote ONLY the **top 3** that ALSO
  clear a **`recurrence ≥ 2` floor** — a single-session one-off never promotes; it waits for a
  second occurrence. Hold the rest (their `recurrence` keeps accruing for a later run). Promoted
  rows become candidates that flow through the SAME Phase 4 judge → Phase 5 emit path as every
  other candidate (`file-beads.py` files them as `human-gate,dream-proposal` beads, unchanged) —
  this is a ranking sub-step, NOT a second mining mechanism. Both CYCLE and CYCLE-DAILY run
  Phase 2, so both get it.
- **Cluster → skill-improvement:** several lessons orbiting one skill's friction →
  candidate edit to that skill.
- **Decomposition/sequencing cluster → the pipeline decomposition skills:** lessons about
  broken-intermediate commits, bad bead-sequencing, or work-breakdowns that needed
  re-partitioning → target `ac-beadify` / `ac-bead-refine` (bead-level) or the `planning` /
  `ac-plan-*` skills (plan-level). These own how work is split, so baking the fix here compounds
  far more than a memory fact (parallel-execution doctrine §7).
- **Cross-domain echo:** an app-local lesson that is really a neometa- or global-domain
  truth → candidate re-homed/generalized lesson.
- **Trajectory:** lessons that together imply a missing capability → candidate new
  recipe or (rarely, Phase-3-gated) new skill — check the registry for overlap first.
- **Promotion → escalation (the L3-outgrows-retrieval check; see context-engineering
  PROMOTION & DEMOTION):** an L3 lesson that is **recurring + stable + broadly applicable**
  has outgrown retrieval → propose escalating it UP a layer — to a skill (L2) or a context
  file (L0/L1) **at the right ALTITUDE** (narrowest subtree covering its consumers). High bar
  (promotion buys always-on cost); **MOVE not copy** (the proposal must reduce the L3 fact to
  a pointer). Also scan non-memory git edits — a fix repeated across commits, a hand-rolled
  procedure — for the same escalation. Inverse: an always-on line edited repeatedly → propose
  **demotion** to L3.

**TaskUpdate("Synthesize patterns", completed)**
**TaskUpdate("Lint substrate", in_progress)**

### Phase 3 — Lint (hygiene; see `references/lint-checks.md` for the full checklist)

**Scope note (since 2026-06-26):** the **mechanical, lossless** checks (Tier-0 — e.g.
`index-prune`) now run **daily** in the Context Mining job and auto-apply via the 02:00 queue.
Phase 3's weekly job covers the **semantic / lossy** checks (Tier-2 — contradiction, staleness,
near-duplicate *merges*, cross-altitude duplication), all emitted `gated`. Don't re-do the
daily mechanical sweep here; if you notice mechanical drift the daily job missed, that's a
finding about the daily job.

Sweep the memory homes for: contradictions between notes · stale facts (evidence
predates a known change; flag, don't guess) · near-duplicates to merge (**ouroboros
guard applies** — a merge proposal must carry the full `git diff` of what it erases;
see `references/lint-checks.md`) · taxonomy violations (missing `type`/`domain`/`evidence`) ·
index drift (`MEMORY.md` lines vs actual files) · instruction-shaped memory bodies
(poisoning risk) · dead `[[wikilinks]]` · **cross-altitude duplication** (the same rule
restated at app *and* sub-domain/root level → propose collapsing to the narrowest
covering level + pointers, per the ALTITUDE rule) · **wiki↔facts contradiction** (a
`neometa/wiki/` page's claim vs the current text of the fact/decision it cites — always
gated, per `[[rule-proposals-become-beads]]`; `references/lint-checks.md` check 11).
Also run the registry self-lint: `~/Repos/neometa/software/agent-compounds/lint.sh`
(dead refs, doc/disk conformance, consumer symlink health) — any FAIL line is a
lint candidate. Each finding becomes a candidate proposal (usually `type: lint-fix`,
low-risk).

#### Hot-lane (L0–L2) lint — stack-wide, GATED (Phase-1.6 gap closed)

Beyond the substrate (L3) sweep above, Phase 3 also lints the **hot lane** — L0 entry
files, L1 CORE, L2 skills/agents, and hook-injected files — the every-turn context whose
rot is silent (nothing breaks; every session just reads a lie). Two passes, both feeding
the SAME gated proposal queue:

1. **Mechanical (stack-wide):** run `infrastructure/tools/bin/hot-lane-lint` (the L0–L2
   analog of the daily registry self-lint, generalized across ALL deploy targets, not just
   agent-compounds). It checks pointer-path resolution, projection symlink health, the
   **regeneration test** (`harness-sync.sh --all --check`, per conformance-checklist
   §Projections — invoked here), and budget/roster/hook/app-list drift. HARD failures
   (broken pointer/symlink) exit non-zero; SOFT warnings (L0 >150, CORE >200, roster/hook/
   drift) are emitted as findings. Fold its `--json` output into the run `INDEX.md`. (Use
   `--no-regen` if the weekly slot is tight; the regen test also runs in the projection
   health job.)
2. **Semantic:** sweep `references/stack-lint.md` (altitude · no-learnings-in-hot-lane ·
   skill selectability · task-overlap · stale-claims · PLACEMENT-ladder) — the judgment
   checks the grep half can't reduce. Seed the reads with the mechanical WARNs' line
   numbers.

**Every L0–L2 finding is emitted as a GATED proposal — NEVER auto-applied**, however
mechanical it looks (unlike the daily Tier-0 substrate sweep, which auto-applies lossless
fixes). A hot-lane line propagates to every session, so the blast radius earns a human read
(context-engineering PLACEMENT: "L0–L2 changes are gated, rare"). These findings flow into
the same Phase 4 judge / Phase 5 emit path as the substrate candidates below.

**TaskUpdate("Lint substrate", completed)**
**TaskUpdate("Judge candidates", in_progress)**

### Phase 4 — Judge (the quality bar)

Spawn an **independent judge subagent** — the **`validator`** stance agent (its
read-only adversarial posture is built for this; fall back to general-purpose if
validator isn't deployed) with the prompt in `references/judge-rubric.md` over the
candidate list. **No independent judge available (rare, headless edge) → never
self-judge.** The candidate is automatically HUMAN-gated and its proposal frontmatter
is marked `judge: skipped` — the gate the missing judge would have provided is
replaced by a human one, not by the generating context judging itself. Each candidate
that does get judged
gets `score` (0–10) + `verdict` + one-line reason. **Only candidates scoring ≥7 become
proposals.** Drop the rest into the run's `INDEX.md` under "Considered & cut" (one line
each — auditability without queue noise).

**TaskUpdate("Judge candidates", completed)**
**TaskUpdate("Emit proposals", in_progress)**

### Phase 5 — Emit (the review queue)

Create `infrastructure/dream-cycle/proposals/<YYYY-MM-DD>/`:

- `INDEX.md` — run summary: window, stream size, proposals by category, considered-&-cut,
  and the **calibration block** captured in Phase 1 (acceptance rate — trailing 4 weeks,
  gated-proposals-only scope, denominator stated) or the one-line "rollup unavailable"
  note if `telemetry.py` hasn't landed on this machine yet.
- `NN-<slug>.md` per proposal:

```markdown
---
status: pending            # auto: pending→applied · gated: pending→(bead filed)→applied|rejected
bead: <id>                 # decision bead in target_repo's db (filed by the daily file-beads.py)
category: rule | recipe | skill-improvement | lint-fix | re-home
summary: <ONE plain-English line — what approving this DOES; this is the Slack card body>
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

Always write `summary:` — it seeds the decision bead's framing and the digest nudge. State
the *effect* ("Adds a memory rule so future X stops re-debugging Y"), not the file path. A
purpose-built line is the difference between a graspable docket item and an opaque one.

**Each gated proposal becomes a decision bead** in its `target_repo`'s beads db (the proposal
FILE is the memo artifact; the BEAD is the action handle — status authority lives in the bead,
the docket is the single action surface; see `../_shared/bead-conventions.md`). **Filing is
deterministic and headless:** the daily queue job runs `infrastructure/dream-cycle/file-beads.py`,
which files only `gated` + `pending` + unfiled proposals (full memo inline for private repos,
pointer-only for the public agent-compounds db), writes the bead id back into `bead:`, and
commits per-repo. So **CYCLE does not file beads itself** — emit the proposal files with an empty
`bead:` slot and the daily filer picks them up (auto-tier proposals are applied, never filed).
This closes the old "headless cycle left beads unfiled" gap — the filer is the safety net, not
an interactive REVIEW that rarely runs. Repo → path: `root` = `~/Repos` · `agent-compounds` =
`~/Repos/neometa/software/agent-compounds` · `<app>` = `~/Repos/neometa/software/<app>`. The
equivalent manual command, if you ever file one interactively:

```bash
cd <target_repo_path> && br create "dream: <slug>" -t decision \
  --labels "human-gate,dream-proposal" \
  --description "Memo: <abs path to NN-<slug>.md>. <one-line What>. Judge: <score>/10."
```

Public-db caution (already handled by `file-beads.py`): agent-compounds beads publish —
neutral titles, pointer-only descriptions (the conventions file has the rule).

**CYCLE-DAILY go/no-go decision bead (data-gated, file ONCE).** The transcript-mining v2
build (`Mode: CYCLE-DAILY`) is deliberately *not* built on a hunch — it waits for gap-trend
data. Once `infrastructure/dream-cycle/gap-history.jsonl` **spans ≥28 days** (first→last
date) **and no open-or-closed bead for this decision exists yet**, file a single
**human-gate decision bead** in the **root** repo carrying the empirical number, so Craig can
decide *ship-v2a* vs *keep-the-reflect-gap-backstop* on evidence rather than intuition. It
carries: the **median substantive-unreflected sessions/week** (from the gap-history rollup),
**2–3 example sessions** (session ids + one-line what-they-did, from a `reflect_gap.py --all`
sample), and a checklist line for the **one-time transcript-durability verification** (cass
archive + weekly gdrive coverage — the transcript-durability finding; if inadequate, bump the
gdrive backup to nightly). File it, don't decide it — this is a gate, not an auto-build.
Idempotency marker = the bead's stable title below (search before filing so a re-run never
double-files):

```bash
# gate: gap-history spans >=28d AND the decision bead does not already exist
SPAN=$(python3 - <<'PY'
import json,datetime,pathlib
p=pathlib.Path.home()/ "Repos/infrastructure/dream-cycle/gap-history.jsonl"
ds=sorted(json.loads(l)["date"] for l in p.read_text().splitlines() if l.strip()) if p.exists() else []
d=lambda s:datetime.date.fromisoformat(s)
print((d(ds[-1])-d(ds[0])).days if len(ds)>=2 else 0)
PY
)
EXISTS=$(br list --json --limit 1000 | jq -r '.issues[]?.title' | grep -c "CYCLE-DAILY go/no-go" || true)
if [ "$SPAN" -ge 28 ] && [ "$EXISTS" -eq 0 ]; then
  cd ~/Repos && br create "dream: CYCLE-DAILY go/no-go (transcript-mining v2)" -t decision \
    --labels "human-gate,dream-proposal" \
    --description "Median substantive-unreflected sessions/wk: <N> (gap-history since <date>). Examples: <2-3 session ids + one-liners>. Decide: ship v2-a transcript mining vs keep the reflect-gap backstop. Checklist: verify transcript durability (cass archive + weekly gdrive; bump to nightly if inadequate)."
fi
```

Commit (root repo, these paths only) + push — the queue must be visible cross-machine:
`git add infrastructure/dream-cycle && git commit -m "dream: <date> cycle — N proposals" && git push`
(also `git add .beads` in this root commit if the CYCLE-DAILY decision bead was filed above —
it lives in root's db; target-repo bead dbs for other proposals: commit `.beads/` in each
target repo touched, separately — never across repo boundaries.)

**TaskUpdate("Emit proposals", completed)**
**TaskUpdate("Heartbeat + report", in_progress)**

### Phase 6 — Heartbeat + report

Write `infrastructure/dream-cycle/last-run.json`:
`{"timestamp": "<ISO now>", "window_start": "<LAST>", "status": "ok"|"empty"|"error", "lessons_read": N, "candidates": N, "proposals": N, "machine": "<hostname>"}`
(include in the Phase-5 commit). **`status` is the honest outcome, not a proxy for
proposal count:** `ok` = every phase completed and the cycle emitted ≥1 proposal;
`empty` = every phase completed with **zero** proposals — a quiet week is a first-class
valid outcome, never dressed up as `ok`; `error` = a phase could not complete
(precondition failure, judge unreachable, write/push failure, uncaught exception) — still
write `last-run.json` with whatever counts were reached and `status: error`, and still
emit a run report describing what broke (this is the field the nightly dead-man's-switch
check reads for stale/failed runs — this skill only writes it honestly, it doesn't
implement that check). Then output a compact run report. If the run produced zero
proposals, say so plainly — a quiet week is a valid outcome, not a failure.

**TaskUpdate("Heartbeat + report", completed)**

---

## Mode: CYCLE-DAILY  (v2 — raw-transcript mining)

**Status:** DESIGNED (roadmap Phase 2.v2); the **full** transcript-mining funnel activates
once transcript replication (v2-a) lands. Until then the weekly **CYCLE** above is the live
synthesis path. Full how-to: `references/transcript-mining.md` · signal types:
`references/signal-taxonomy.md`.

**LIVE today — the reflect-gap backstop (the cheap half of the coverage win).** The daily
Context Mining job already closes the biggest hole without waiting on v2-a:
`infrastructure/dream-cycle/reflect_gap.py` deterministically lists *substantive but
unreflected* sessions from the day's transcripts (a session that did work — or decided
something in pure conversation, leaving zero git signal — yet never ran `reflect`). The job
**mines exactly those transcripts** (the transcript is the only remaining context; a finished
session's live window is gone — mine it, never "re-run reflect"). This + the existing git-diff
pass is the daily capture backstop; the full marker-funnel over *all* transcripts is the v2-a
upgrade. Architecture: `neometa/alignment/decisions/2026-06-26-tiered-memory-autonomy.md`.

An **evolution of CYCLE, not a rewrite** — Phases 2 (synthesize) / 4 (judge) / 5 (emit)
are reused unchanged. Two changes: a cheap **precondition check** runs first, and **gather
widens to raw transcripts + git outcomes** (every agent, every day, incl. non-pipeline
conversations — the coverage win over the curated v1 stream).

**dream does NOT do infra maintenance.** Cleaning, index refresh, and health checks belong
to the separate **`infra-maintain`** job (the "cleaning" process — distinct from the
"remembering" one; sleep runs both in one nightly window, in sequence). The scheduler runs
hygiene *before* dream; dream **consumes hygiene's health report**, it does not perform the work.

**Precondition (not maintenance — verify, don't clean).** Confirm inputs are fresh: indexes
updated within the window (`qmd status`, `cass status`) and the night's `infra-maintain` health
report exists. If a precondition fails (stale index, hygiene didn't run, replication didn't
converge), do NOT fix it — **record it as a finding** (it's a high-priority learning signal)
and proceed with what's available.

**Mine (review-only — the funnel; never feed whole transcripts to the LLM):**
segment delta (since `last-run.json`) → **cheap pre-filter** (grep error/negation/outcome
markers) → **redaction filter** (scrub into the LLM input; raw canon stays pristine) →
**LLM-extract** candidate segments via the **signal taxonomy** → **CASS dedup** →
**Phase 4 judge** → **Phase 5 emit**. Sources span two axes — intent (transcripts + agent-mail)
and outcome (git + **the `infra-maintain` health report** + v2.1 sockets: CI/Sentry/PM2/beads).
A hygiene-detected problem (oomd kill, leaked secret, disk-pressure event) is mineable signal.

**Sources — two axes:** intent = `~/.claude/projects/` + `~/.codex/sessions/` (the replica) +
agent-mail · outcome = git (grounding layer) + [v2.1 sockets]. Richest lessons at the join.

**Guardrails:** `gitleaks` gates **emit** (proposals are the only thing reaching a shared
remote; transcripts replicate privately, never touch git) · mine the cycle's own **review
outcomes**, not its deliberation (self-reference) · review-only stands — Stage 1 autonomy is
deterministic hygiene only; judgment-laden work is always a proposal.

**Trigger:** daily `pai-scheduler` job on the VM (never a raw PM2 cron — the dead-`qmd-watcher`
lesson). **Replaces the weekly CYCLE once daily coverage is proven** — and only then is
`/reflect` retired from `ac-land`'s forced flow (don't remove old capture before new is proven).

---

## Mode: REVIEW

Dream proposals are decision beads — REVIEW is the dream-flavored slice of the
**decision docket** (`/ac-human-session` surfaces the same beads org-wide; either
entry point works, the contract is identical).

### Create Workflow Tasks (run ledger — REVIEW mode)

**One task per numbered step below — this is a separate ledger from CYCLE's** (REVIEW is
its own invocation, walking the docket interactively rather than emitting to it). Create
these upfront; `TaskUpdate` each to `in_progress` when its step starts and `completed` when
it ends.

```
TaskCreate("List proposals — open dream-proposal beads, oldest first")
TaskCreate("Present + collect decisions — AskUserQuestion, batches of <=4")
TaskCreate("Apply approved — edit target_file in target_repo, commit")
TaskCreate("Close out — record decision, close bead, flip frontmatter, push")
TaskCreate("Report — applied/rejected/remaining + acceptance rate")
```

**TaskUpdate("List proposals", in_progress)**

1. List open `dream-proposal` beads across the beads repos (root, agent-compounds,
   apps): per repo `br list --json --limit 1000 | jq '[.issues[] | select(.labels // [] |
   index("dream-proposal")) | select(.status != "closed")]'` — oldest first.
   Legacy fallback: `status: pending` proposal files with no `bead:` id (pre-docket
   runs) — review them the same way, and file the missing bead. **Also pick up files
   already carrying `status: approved` / `status: rejected`** — those were pre-decided by
   Craig via the Slack triage buttons (Increment 3, `infrastructure/slack/post-proposals.py`).
   Nothing open and nothing pre-decided → say so.

**TaskUpdate("List proposals", completed)**
**TaskUpdate("Present + collect decisions", in_progress)**

2. Per proposal: read the memo file (What/Why/evidence/judge verdict), present.
   **Pre-decided proposals (`status: approved`/`rejected` from the Slack buttons) skip the
   question** — the human already chose: apply the approved, record the rejected, no re-ask.
   For the rest, collect decisions via `AskUserQuestion` (multiSelect, batches of ≤4:
   approve / reject / skip).

**TaskUpdate("Present + collect decisions", completed)**
**TaskUpdate("Apply approved", in_progress)**

3. **Apply approved:** edit the `target_file` in the `target_repo` exactly as proposed
   (adjust mechanically if the target drifted; if it drifted *semantically*, leave the
   bead open with an enrichment comment instead of guessing). Respect repo boundaries —
   commit in the target repo with message `dream: apply <slug>`, push.

**TaskUpdate("Apply approved", completed)**
**TaskUpdate("Close out", in_progress)**

4. **Close out per bead-conventions:** record the decision
   (`br comments add <id> "DECISION (<human>): <choice> — <why>"`), close the bead
   (approved-and-applied or rejected alike — the comment trail is the record), set the
   file's frontmatter `status:` to **`applied`** (terminal success — distinguishes
   "approved" from "actually landed") or `rejected`, commit the queue (root) + each touched
   `.beads/` (own repo), push. (Note: the daily queue job applies the `auto` tier and any
   `status: approved` backlog automatically — REVIEW is the interactive path for `gated`.)

**TaskUpdate("Close out", completed)**
**TaskUpdate("Report", in_progress)**

5. Report: applied / rejected / remaining — and note acceptance-rate (the cycle's own
   quality metric; persistently low → propose a judge-bar fix next cycle).

**TaskUpdate("Report", completed)**

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
| Emitting a proposal file without its decision bead | The bead IS the action handle — a file alone is invisible to the docket |
| Strategy/secrets in an agent-compounds bead | That db is PUBLIC — neutral title + pointer; memo stays private |
