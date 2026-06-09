---
name: reflect
description: Capture session learnings into the AI-native-org memory substrate. Use at the end of any session, or when asked to "reflect", "capture learnings", "what did we learn", "save lessons", "remember this", "compound this session". Writes typed, domain-routed, deduped lessons (facts/decisions/recipes) into git-tracked, qmd-indexed homes so the next session — on any machine, any agent — is faster. Called by ac-land; also runs standalone. NOT for mid-task notes (that is the memory-capture agent) or full bead-work closure (that is ac-land).
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

## The model (read once)

Every lesson is **one `{type}` × one `{domain}`**. Type picks the format + home-kind;
domain picks the subtree. This is the whole routing rule.

**Types**

| Type | Is it… | Home-kind |
|---|---|---|
| **fact** | a discrete true thing ("droid settings.json must be a symlink") | `…/memory/auto/<slug>.md` |
| **decision** | a choice + its rationale ("BCA is canonical migration host") | `…/decisions/<date>-<slug>.md` |
| **recipe** | a repeatable prompt/workflow said-or-done ≥twice | prompt-library entry |
| **skill-improvement** | a fix to how a skill/agent behaves | edit the skill file (**gated**) |
| **rule** | a generalizable coding constraint | _defer to CM_ — capture as a `fact` tagged `type: rule`; CM formalizes it in Phase 2 |

**Domains** (classify per-lesson, not per-session — one session can yield a global
tooling fact *and* a neoMeta decision):

| Domain | When the lesson is about… | Memory root | Decisions |
|---|---|---|---|
| **neometa** | the business, its apps, brand, content, books | `neometa/memory/` | `neometa/alignment/decisions/` |
| **personal** | life, PKM, journaling | `knowledge/` | — |
| **global** | tooling, agents, infra, the PAI system | `infrastructure/memory/` | `infrastructure/memory/` |

Infer domain from the lesson's subject (and the session's paths); when ambiguous, ask.

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

**fact** → `<domain-root>/memory/auto/<slug>.md`, then add a one-line pointer to that
dir's `MEMORY.md` index (`- [Title](slug.md) — hook`). Frontmatter:
```markdown
---
name: <kebab-slug>
description: <one-line — used for recall relevance>
metadata:
  type: fact            # or: rule
  domain: neometa       # neometa | personal | global
  evidence: <the outcome/moment that grounds this>
  tags: [bca, schema]   # optional
---

<the lesson. Link related memories with [[their-slug]].>
```

**decision** → `<domain>/…/decisions/<YYYY-MM-DD>-<slug>.md` (same frontmatter, `type: decision`;
body = context · decision · rationale · consequences).

**recipe** → the prompt-library: add `agent-compounds/skills/jef-prompts/references/<slug>.md`
(the full prompt verbatim + parameters + when-to-use) **and** a catalog line in
`jef-prompts/SKILL.md`. That skill is the canonical recipe home — never start a parallel one.

**skill-improvement** → **GATED.** Do not auto-apply. Present the exact proposed
edit (target file + diff + the session evidence) and get explicit approval before writing
— system behaviour changes need a human merge (consistent with ac-land's no-auto-apply rule).

### 6. Report
Output a compact summary: each lesson → `{type, domain}` → file written/updated. Note any
skill-improvements awaiting approval. If nothing cleared the bar, say "nothing worth
capturing this session" — that's a valid outcome.

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
