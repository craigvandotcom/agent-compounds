---
name: reflect
description: Capture session learnings into the AI-native-org memory substrate. Use at the end of any session, or when asked to "reflect", "capture learnings", "what did we learn", "save lessons", "remember this", "compound this session". Writes typed, domain-routed, deduped lessons (facts/decisions/recipes) into git-tracked, qmd-indexed homes so the next session — on any machine, any agent — is faster. Called by ac-land; also runs standalone. NOT for mid-task notes (that is the memory-capture agent), full bead-work closure (that is ac-land), or cross-session synthesis/lint (that is dream).
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
- Mid-task fact capture → the continuous **memory-capture agent** already does this.
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

**decision** → `<domain>/…/decisions/<YYYY-MM-DD>-<slug>.md` (same frontmatter, `type: decision`;
body = context · decision · rationale · consequences).

**recipe** → the prompt-library (one canonical location, in the root monorepo:
`~/Repos/neometa/software/agent-compounds/skills/jef-prompts/`): add
`references/<slug>.md` (the full prompt verbatim + parameters + when-to-use) **and** a
catalog line in its `SKILL.md`. Even when reflecting inside an app repo, recipes go
there — never start a parallel library.

**skill-improvement** → **GATED.** Do not auto-apply. Present the exact proposed
edit (target file + diff + the session evidence) and get explicit approval before writing
— system behaviour changes need a human merge (consistent with ac-land's no-auto-apply rule).

### 6. Golden-set check (optional, rare)
If the session produced a clearly-above-bar exemplar (a sharp plan, clean diff, good
review), offer to save it to `infrastructure/eval/golden/` per that README's format —
quality over volume; most sessions add nothing here.

### 7. Report
Output a compact summary: each lesson → `{type, domain}` → file written/updated. Note any
skill-improvements awaiting approval. If nothing cleared the bar, say "nothing worth
capturing this session" — that's a valid outcome.

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
