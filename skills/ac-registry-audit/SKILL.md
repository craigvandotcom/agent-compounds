---
name: ac-registry-audit
description: Make the skill/agent REGISTRY itself watertight — audit the prompt corpus (agent-compounds) for trigger collisions, divergent duplicates, dangling cross-refs, and doc↔disk drift, then apply mechanical fixes and gate the judgment calls. Triggers: 'registry audit', 'audit the skill registry', 'registry hygiene', 'watertight the registry', 'dedup the skills', 'skill collision check', 'clean up agent-compounds'. NOT for app source code (use ac-hygiene for codebase health, ac-review for a feature branch), pipeline state / beads / backlog (use ac-tidy), or a single domain audit of app code (use audit).
---

**You are the conductor.** The target is the *registry itself* — the prompt/skill
corpus (canonically `agent-compounds`), not any app's code. A registry rots in
ways a code review never sees: trigger collisions, divergent duplicates, dangling
cross-refs, doc↔disk drift. You run a four-pass sweep — cheapest/most-mechanical
first — and keep `lint.sh` green throughout. See **`references/rot-vectors.md`**
for the taxonomy of what you're hunting and the false positives to expect.

Run this after several rounds of skill authoring/refactoring, or whenever the
catalog "feels" tangled. For app *code* cleanup use `/ac-hygiene`; for pipeline
state use `/ac-tidy`.

---

## I/O Contract

|                  |                                                                                  |
| ---------------- | -------------------------------------------------------------------------------- |
| **Input**        | A registry root (the dir whose `skills/` + `agents/` you audit; default = agent-compounds) |
| **Output**       | Mechanical fixes committed (lint green); judgment calls surfaced to the human    |
| **Verification** | `lint.sh` exit 0; affected skills still resolve; commits are per-pass            |

## Phase 0: Scope

Confirm the registry root (default: this repo). `cd` there. Confirm it has
`skills/` and a `lint.sh` (the mechanical gate). Branch before editing:
`git switch -c chore/registry-hygiene-pass`.

---

## Pass 1 — Mechanical invariants (free, run first)

1. `./lint.sh` — read every `FAIL:`. These are deterministic: dead-pattern greps,
   `/ac-*` cross-ref resolution, frontmatter `name`==dirname, disk→README
   presence, consumer symlink health.
2. Broken-symlink scan across consumers (lint Check 7 covers the registered ones).
3. **Fix each FAIL**, then re-run until `lint: N checks, 0 failures`.

Fixes here are pure mechanical repair — apply directly. Note: lint is
**one-directional** on README (disk→README) — also check for README→disk
**ghosts** (rows for skills that no longer exist) by hand; lint won't flag them.

**Repo-boundary rule:** some failures (e.g. consumer symlinks) live in *other*
repos. Fix them on disk, but commit each in its own repo — never across a
boundary. If a consumer repo has unrelated in-flight work, fix on disk and leave
it **uncommitted + flagged**, don't commit into a busy working tree.

Commit Pass 1: `chore(hygiene): clear N registry-lint failures`.

---

## Pass 2 — Semantic dedup/drift audit (the high-value pass)

This is what no mechanical check catches. Use the workflow engine
**`workflows/dedup-drift-audit.js`** — it maps every skill, then runs three
analyzers (trigger collisions, dangling refs, divergent duplicates) over the full
map, then **adversarially verifies** each finding so intentional cross-references
aren't flagged.

To run it:
1. Discover the deployable skill names:
   `ls -d skills/*/ | sed 's|skills/||;s|/||' | grep -v '^_'`
2. Open `workflows/dedup-drift-audit.js`, set `ROOT`, and **inline** that list
   into `SKILLS`. Do NOT pass it via the Workflow `args` parameter — it has been
   seen arriving `undefined` in background runs (`workflow-tool-args-propagation`
   memory fact); inlining is reliable.
3. `Workflow({scriptPath: "skills/ac-registry-audit/workflows/dedup-drift-audit.js"})`.
   Iterate by editing the file + re-running.

It returns `{ totalRaw, confirmedCount, confirmed[] }` — each confirmed finding
carries `kind`, `severity`, `skills`, `detail`, `recommendation`, and
`needsHumanDecision`. The verify pass typically kills a third+ as false positives.

---

## Pass 3 — Registry tooling review

The only real *code* in the registry is its shell/JS tooling (`deploy.sh`,
`lint.sh`, `_tools/`). Spawn a **validator** subagent to review those files for
correctness + portability (BSD-vs-GNU on macOS) + silent-failure hazards. Apply
only fail-safe, non-functional hardening directly (guards, exit-code checks,
`/usr/bin/find` consistency); verify with `bash -n` + a `--dry-run` deploy + lint.
Behavior-changing fixes → gate (Pass 4).

---

## Pass 4 — Apply, gated

Split every Pass-2/3 finding by `needsHumanDecision`:

- **Mechanical** (`needsHumanDecision=false`) — trigger-surface tightening,
  dead-ref repair, README reconciliation, frontmatter alignment. Apply directly.
  **When tightening a trigger surface, sharpen the *description* and add explicit
  "NOT for X (use Y)" carve-outs** — that is the routing layer the model reads.
- **Judgment calls** (`needsHumanDecision=true`) — restore-vs-reroute a deleted
  skill, demote-vs-keep a duplicate, etc. **Never auto-decide.** Present each with
  options via `AskUserQuestion`, then apply per the answer.

After each batch: `./lint.sh` must be 0 failures; `bash -n` / `node --check` any
touched scripts. Commit per logical pass with a clear message. Leave the branch
for the human to review as a diff (offer to push + open a PR).

---

## Report

Summarize: lint delta (before→after), confirmed findings by kind/severity,
mechanical fixes applied, judgment calls and their resolutions, and anything left
uncommitted in other repos. If the registry was already clean, say so plainly.

---

## Remember

- **Registry ≠ codebase.** This audits the prompt corpus; `ac-hygiene` audits code.
  Keep the boundary — don't let this skill grow code-review scope.
- **Mechanical first, free first.** `lint.sh` before any token spend.
- **Verify before believing.** The adversarial pass exists because intentional
  cross-references look like collisions to a naive scan.
- **Gate the judgment calls.** Reroute-vs-restore and demote-vs-keep are the
  human's; everything mechanical is yours.
- **Apply the lesson to yourself.** When you add or edit a skill during the sweep,
  give it a sharp, non-overlapping trigger surface — collisions are the #1 rot.

---

_Registry hygiene for the prompt corpus. For app-code health: `/ac-hygiene`. For pipeline state: `/ac-tidy`._
