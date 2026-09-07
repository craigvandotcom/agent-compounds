# Registry Audit — the judgment passes

The target is the *registry itself* — the prompt/skill corpus (canonically
`agent-compounds`), not any app's code. A registry rots in ways a code review
never sees: trigger collisions, divergent duplicates, dangling cross-refs,
doc↔disk drift. See **`../references/rot-vectors.md`** for the taxonomy of what
you're hunting and the false positives to expect.

The **mechanical** passes are lint Checks now: 24 (description length), 25
(retired names in live text), 26 (README ghost rows), 27 (instance tokens), 28
(path resolution), 30 (trigger collisions). Run `./lint.sh` first — read every
`FAIL:`, fix, and keep it green throughout; that surface is free and
deterministic. This workflow covers what no mechanical check catches.

Run this after several rounds of skill authoring/refactoring, or whenever the
catalog "feels" tangled. For app *code* cleanup use `/ac-hygiene`; for pipeline
state use `/ac-tidy`.

---

## I/O Contract

|                  |                                                                                  |
| ---------------- | -------------------------------------------------------------------------------- |
| **Input**        | A registry root (the dir whose `skills/` + `agents/` you audit; default = agent-compounds) |
| **Output**       | Judgment fixes committed (lint green); judgment calls surfaced to the human       |
| **Verification** | `lint.sh` exit 0; affected skills still resolve; commits are per-pass            |

## Phase 0: Scope

Confirm the registry root (default: this repo). `cd` there. Confirm it has
`skills/` and a `lint.sh` (the mechanical gate). Branch before editing:
`git switch -c chore/registry-hygiene-pass`.

---

## Pass 1 — Mechanical invariants (free, run first)

`./lint.sh` — read every `FAIL:`. These are the retired registry-audit
mechanical passes, now lint Checks 25–28 and 30 (retired names, README ghosts,
instance tokens, path resolution, trigger collisions), plus the rest of the
suite. **Fix each FAIL**, then re-run until green.

Fixes here are pure mechanical repair — apply directly. **Repo-boundary rule:**
some failures (e.g. consumer symlinks) live in *other* repos. Fix them on disk,
but commit each in its own repo — never across a boundary. If a consumer repo
has unrelated in-flight work, fix on disk and leave it **uncommitted + flagged**.

Commit Pass 1: `chore(hygiene): clear N registry-lint failures`.

---

## Pass 2 — Semantic dedup/drift audit (the high-value pass)

This is what no mechanical check catches. Use the workflow engine
**`dedup-drift-audit.js`** (beside this file) — it maps every skill, then runs
three analyzers (trigger collisions, dangling refs, divergent duplicates) over
the full map, then **adversarially verifies** each finding so intentional
cross-references aren't flagged.

To run it:
1. Discover the deployable skill names:
   `ls -d skills/*/ | sed 's|skills/||;s|/||' | grep -v '^_'`
2. Open `dedup-drift-audit.js`, set `ROOT`, and **inline** that list into
   `SKILLS`. Do NOT pass it via the Workflow `args` parameter — it has been
   seen arriving `undefined` in background runs (`workflow-tool-args-propagation`
   memory fact); inlining is reliable.
3. `Workflow({scriptPath: "skills/skill-builder/workflows/dedup-drift-audit.js"})`.
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
  Keep the boundary — don't let it grow code-review scope.
- **Mechanical first, free first.** `lint.sh` before any token spend.
- **Verify before believing.** The adversarial pass exists because intentional
  cross-references look like collisions to a naive scan.
- **Gate the judgment calls.** Reroute-vs-restore and demote-vs-keep are the
  human's; everything mechanical is yours.
- **Apply the lesson to yourself.** When you add or edit a skill during the sweep,
  give it a sharp, non-overlapping trigger surface — collisions are the #1 rot.

---

_Registry hygiene for the prompt corpus. For app-code health: `/ac-hygiene`. For pipeline state: `/ac-tidy`._
