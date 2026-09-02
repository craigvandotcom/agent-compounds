# seams-checklist — the question set a blind reader runs over a target's code

The loop that runs this (K blind readers per round, VALIDATE by re-running commands, consensus
at two independent hits, fixpoint on the plan's digest) is `ac-polish/workflows/seams.md`.
This file is only the questions. **New singletons every round indict THIS FILE, not the target.**

**You are blind by design.** You see the target and this file — not the plan, not the round,
not what anyone else found. A seam two blind readers reach separately is evidence; a seam one
reader confirms because it was shown it is not.

**SEVERITY GATE — a toucher is a seam ONLY if its failure is silent or its shape is unasserted.**
A call site that fails loudly under an existing test is not a finding; it is DECLINED, with the
test path.

## Scope — you decide; the data leads

Follow the target's DATA: who writes it, stores it, reads it, deletes it. Do not follow the
import graph — that is the whole app. Exclude prose paths: docs, plans, backlog, memory,
changelogs, snapshots, lockfiles, generated types. There is no declared scope; your `found-by`
commands are the scope you chose, and they are what a second reader re-runs.

## The four questions — each answered by a command you ran

1. **Shape.** Do every writer and every reader agree on the object's shape? Two shapes for one
   thing (a column and its fallback, a type and its `any`) is connascence of meaning.
   `rg -n '<symbol>' -g '!**/*.test.*' -g '!**/__tests__/**'` per shape — compare the sets.
2. **Lifecycle.** Stages: create · store · read · update · delete · cleanup. Name the code at
   each stage. **An empty stage is a HOLE row** — the finding is the absence.
   `rg -n '<symbol>'` grouped by path; assign every hit a stage.
3. **Touchers.** Who else writes here, and do they know about each other? Two writers with no
   shared contract is a seam even when both are correct today — but ONLY if you can name what
   would drift and show nothing asserts it. "Consistent today, unasserted" with no named
   drift is DECLINED.
   `rg -n '(insert|update|upsert|delete|save|write)[^;]*<symbol>|<symbol>[[:space:]]*[:=]'`
4. **Silent failure.** If this edge breaks, what notices? A test path that would fail, or `none`.
   `rg -l '<symbol>' -g '**/*.test.*' -g '**/__tests__/**'` — and what each one asserts.

## The findings row — every cell, or no row

A table row, parsed by `scripts/seams-merge.py` (the reader prompt shows the exact shape):
`| class | seam | locations (path:line …) | what breaks silently | found-by (the exact command) | what notices (test path \| none) |`

- `class` is `breaks today` (a reachable silent failure) or `unasserted` (agrees by coincidence,
  nothing catches drift). The plan's Approach treats them differently: fixes versus contracts.
- No `found-by` → not a row. A remembered list is how the slate's caller count came up short.
- No design. "Should unify to…" is `ac-plan`'s sentence, not yours. State the seam, cite code.

## DECLINED — mandatory

Everything you looked at and judged NOT a seam, with why and the command. An empty DECLINED on
a non-trivial target is a finding against the reader.
