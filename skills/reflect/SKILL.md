---
name: reflect
description: Capture session learnings into the AI-native-org memory substrate. Use at the end of any session, or when asked to "reflect", "capture learnings", "what did we learn", "save lessons", "remember this", "compound this session". Called by ac-land; also runs standalone. NOT for full bead-work closure (that is ac-land) or cross-session synthesis/lint (that is dream).
---

# reflect — close the write loop

**Purpose:** turn a session's hard-won learnings into retrievable memory, typed and
routed so they compound. The capture half of the AI-native-org write loop.
**Domain:** memory / knowledge substrate (see `neometa/alignment/roadmaps/ai-native-org-v1.md` §1).
**Status:** MVP

> **The test for every lesson:** *does it make the next session faster?* If you can't
> name the future session it helps, it's not a lesson — drop it. Capture signal, not a diary.

---

## When to Use

**Triggers:** end of any session; "reflect", "capture learnings", "what did we learn",
"save lessons", "remember this", "compound this session".

**When NOT to use:**
- Mid-task fact capture → no live agent does this continuously (the former
  memory-capture agent is archived, `.claude/agents/_archive/memories-capture.md`);
  capture happens at this skill's own session-end trigger, or asynchronously via the
  nightly context-mining job and knowledge-triage — not mid-task.
- Full bead-work closure (land + quality gates + retrospective) → **ac-land** (which
  calls this skill for its capture step).
- Pure conversation with no reusable learning → nothing to capture; say so and stop.

---

## The model (canonical source: `context-engineering`)

**Load `../context-engineering/SKILL.md` before routing anything** — it is the single
source for the save-routing taxonomy (`{type} × {domain}` → home), the frontmatter
schema, and the write rules (dedupe, outcome-grounding, sanitization, decay). This skill
is the *session-end executor* of that procedure, not a second copy of it.

Operating summary (details + edge cases live in context-engineering):
- Every lesson is **one `{type}`** (fact · rule · decision · recipe · skill-improvement)
  **× one `{domain}`** (neometa · app-local · personal · global). Type → format +
  home-kind; domain → subtree.
- **Rules are markdown facts** with `type: rule` — the CM playbook is a derived cache,
  never the home.
- Classify **per lesson**, not per session; infer domain from the lesson's subject (and
  the session's paths); when ambiguous, ask.
- A lesson with no slot = taxonomy bug to flag, never a new store.

---

## Workflow

### 1. Gather what happened
- The conversation arc, plus: `git log --oneline -15`, `git diff --stat`, and any test/build
  outcomes. **Ground lessons in outcomes** — prefer a lesson tied to an observable result
  (a bug fixed, a test passing, a shipped diff, an explicit user correction) over speculation.

### 2. Extract candidate lessons (minimum-waste bar)
- Apply the compounding test (above). Keep only lessons where you can point to a *specific
  moment* this session where the knowledge would have saved time, or a correction the user
  made. Drop "interesting but theoretical."
- **DRY signal:** anything the user said or corrected **twice** → it's a `recipe` or a
  `skill-improvement`, not just a fact.
- **Decomposition signal:** a broken-intermediate commit, a bad bead-sequence, or a
  work-breakdown that had to be re-partitioned mid-implementation → this is a
  `skill-improvement` for the decomposition skills (`ac-beadify` / `ac-bead-refine`, or the
  `planning` / `ac-plan-*` skills), **not** a one-off fact. These are the highest-leverage
  upgrade targets — route the lesson INTO the skill, not into a memory note.
- **Approve-then-diff signal:** if a human edited or corrected a gated deliverable (plan,
  skill-improvement, proposal) before they approve it, diff the draft against what was
  actually kept — that diff is a first-class lesson candidate, classified and routed
  through the normal `{type, domain}` taxonomy and gates like any other. It's the
  highest-signal, lowest-noise capture channel available: the correction already
  happened, in view, with no inference required — don't let it evaporate at approval.

### 3. Classify each: `{type, domain}`
Use the tables above. A lesson that fits no `{type, domain}` slot is a signal the taxonomy
needs fixing — flag it, don't invent a new store.

### 4. Dedupe-over-append (REQUIRED before any write)
For each lesson, search the existing substrate first:
```bash
qmd search "<key terms>" --json -n 5      # or: grep -ri "<term>" <domain memory root>
```
- **Match found** → **update** that file (refine/extend); never create a near-duplicate.
- **No match** → create new.

### 5. Write to the routed home

**fact / rule** → `<domain-root>/memory/auto/<slug>.md` using the canonical frontmatter
schema from `context-engineering` (name · description · type · domain · evidence · tags;
body = data with `[[wikilinks]]`, never instructions). Then add a one-line pointer to that
dir's `MEMORY.md` index (`- [Title](slug.md) — hook`).

**Tier-3 loop-retro observation** (the write primitive `ac-land` Phase 3's tier router calls for
its T3-routed friction items — **reflect does NOT re-decide tiers**; T1/T2 branching lives in
`ac-land`, bd-jv33f.4) → `<domain-root>/memory/auto/<slug>.md`, same location + `MEMORY.md`
pointer as a fact, with the canonical frontmatter **layered** with a loop-retro structural key so
`dream` can compute recurrence×cost across sessions (never hash reworded prose — memory:
`llm-agent-dedup-needs-structural-keys`):
```markdown
name: <kebab-slug>
description: <one line — recall hook>
metadata:
  type: fact                    # canonical enum (context-engineering)
  domain: neometa               # canonical
  evidence: <grounding + date>  # canonical
  kind: loop-retro-observation  # NEW structural discriminator
  stage: implement
  cost: material|minor
  first_seen: 2026-07-13
  recurrence: 1                 # bumped on dedupe-match, NOT a new file
```
The canonical `name`/`description` + `metadata.{type,domain,evidence}` fields REMAIN (qmd recall,
the `MEMORY.md` pointer convention, and dream's reader all depend on them); `kind`/`stage`/`cost`/
`first_seen`/`recurrence` are ADDED under `metadata`. **Dedupe-match:** same
`metadata.kind: loop-retro-observation` + same `stage` + same gist (via the Step 4 `qmd search`
probe already run above) → increment `recurrence` on the existing row, do NOT create a duplicate
file. `cost` stays coarse (`material|minor`); a minutes floor is optional and Craig-set.

**Skill-scoped friction (W4.3)** — if `ac-land`'s Step 0 hand-off tagged the T3 item as
*skill-scoped friction* rather than a general lesson, write it to
`skills/<skill>/FRICTIONS.md` instead of the `memory/auto/` path above. Schema, per-skill
template, and the dedup judgment (reuse-id-and-bump-recurrence vs mint-new) are
`skill-builder/references/friction-capture.md`'s — read that file's existing entries and
judge before writing; don't restate its rules here. Create the target file lazily from its
template if absent. General (non-skill-scoped) lessons keep the `memory/auto/` path,
unchanged.

**decision** → `<domain>/…/decisions/<YYYY-MM-DD>-<slug>.md` (same frontmatter, `type: decision`;
body = context · decision · rationale · consequences).

**recipe** → the prompt-library (one canonical location, in the root monorepo:
`~/Repos/neometa/software/agent-compounds/skills/jef-prompts/`): add
`references/<slug>.md` (the full prompt verbatim + parameters + when-to-use) **and** a
catalog line in its `SKILL.md`. Even when reflecting inside an app repo, recipes go
there — never start a parallel library.

**skill-improvement** → **risk-triage FIRST: does the lesson change what the skill DOES, or
just how it's SHAPED?** (full boundary: `skill-builder/references/maintenance-ledger.md`).

- **Shape / structure** (dedup, sediment, buried triggers, an extraction candidate, a near-dup,
  content that should move to `references/`) → **append one line to the skill's Inbox** in
  `<skill-dir>/MAINTENANCE.md` (create lazily per the ledger format), tagged
  `[<date> · src:reflect]`. Low ceremony, **no human gate** — a hygiene-pass applies it later under
  deterministic guards (`validate-skill.sh --diff` + survival gate). Do NOT file a bead for shape.
- **Behavior / enforcement** (a new gate, a changed branch, a contract fix — anything that alters
  what the skill does) → **GATED, unchanged.** Do not auto-apply — system-behaviour changes need a
  human merge (rule 3 in `ac-pipeline/references/disposition.md`, consistent with ac-land's no-auto-apply).
  **Interactive:** present the exact proposed edit (target file + diff + session evidence) and get
  explicit approval before writing. **Headless:** file a decision bead —
Bead creation per `beads-standards/reference/bead-conventions.md` — types, unrefined-at-creation, anchor-dedupe, body template. <!-- net-growth-ok: ac-gcj.7 Pass C canon binding -->

  `br create -t decision -p 3 -l human-gate,skill-improvement,skill:<name>` with the memo
  (target · evidence · diff · recommendation), **dedupe-first** against open `skill-improvement`
  beads per `ac-pipeline/references/disposition.md` § Save-for-later. Never post to Slack, never silently drop —
  the bead is how the merge request survives an unattended session.

When unsure which tier, treat it as **behavior** (escalate to the gated bead) — the shape lane is
for changes a script can prove touched no enforcement.

### 6. Golden-set check (optional, rare)
If the session produced a clearly-above-bar exemplar (a sharp plan, clean diff, good
review), offer to save it to `infrastructure/eval/golden/` per that README's format —
quality over volume; most sessions add nothing here.

### 7. Report
Output a compact summary: each lesson → `{type, domain}` → file written/updated. Note any
skill-improvements awaiting approval. If nothing cleared the bar, say "nothing worth
capturing this session" — that's a valid outcome.

### 8. Open-ends checkpoint (INTERACTIVE sessions only — skip entirely when headless)

<!-- net-growth-ok: Craig-directed feature 2026-07-31 — last-look sweep of open ends before session close, interactive only -->

Before the session closes, sweep for loose threads and present them to the user ONCE:

- **Sources:** the session task list / run ledger (incomplete tasks), beads created this
  session still open, skill-improvements awaiting approval (step 5), anything promised in
  conversation but not delivered, uncommitted files this session authored.
- **Present compactly** — one line per item + what closing it would take. The user routes
  each: act now · bead it (dedupe-first, normal conventions) · drop it. Nothing is
  silently dropped.
- **Headless:** skip this step entirely — the unattended equivalents already exist
  (decision beads + advisory nudges); do not ask, do not block, do not Slack.

> **Deploy dependency:** this skill loads `../context-engineering/SKILL.md` (sibling).
> When deploying to an app via `deploy.sh`, always deploy both together.

---

## Guarantees this skill preserves

- **Machine-agnostic:** every home is git-tracked; the auto-memory dirs are symlinked into
  git (see install-qmd.sh §2b). Writes travel on the next `git pull`.
- **Agent-agnostic:** homes are plain markdown read by *any* agent via `qmd query`; this
  skill's logic is the same wherever deployed (canonical in agent-compounds, symlinked to
  root + apps).
- **One substrate:** never create a parallel store. Route into the existing five homes.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Appending a near-duplicate note | Step 4 is mandatory — search, then update-in-place |
| Capturing a diary, not a lesson | Apply the compounding test; name the future session it helps |
| Auto-editing a skill | skill-improvements are GATED — propose, get approval |
| One domain for the whole session | Classify **per lesson**; sessions mix domains |
| Inventing a new folder for an odd lesson | No-home = taxonomy bug to flag, not a new store |
| Writing a `rule` as its own thing | Capture as `fact` tagged `type: rule`; CM formalizes in Phase 2 |
