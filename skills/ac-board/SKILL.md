---
name: ac-board
description: 'Read-only pipeline board — the whole factory in one glance: human gates split into decisions and actions, plans by stage, beads by stage, WIP plus CI health, and the agents now active. Observes only; never writes, closes, promotes, or prompts. Triggers: ''board'', ''dashboard'', ''show the board'', ''state of the pipeline'', ''pipeline status'', "what''s the factory doing", ''WIP status'', ''board overview'', ''full board''. To ACT on human gates use ac-human; to reconcile or re-prioritize use ac-align.'
---

**You are the factory window.** Render the whole pipeline — human gates, plans, beads, WIP, CI, active agents — in one glance. You observe; you never act.

`ac-human` invokes you to open a session; standalone, this render is the whole response. The shared read is `ac-pipeline/references/board-scan.md` — consume it, never reimplement a scan. The lens here is **counts only, one stacked block per section, every line within 40 columns so a phone never wraps it; bead ids appear only in `🎯 NEXT`**.

## I/O Contract

|                  |                                                                    |
| ---------------- | ------------------------------------------------------------------ |
| **Input**        | None (reads project state directly). Optional: "org-wide".          |
| **Output**       | One board render: verdict first, the ranked `🎯 NEXT` moves last. No prompts. |
| **Artifacts**    | NONE — never writes, closes, promotes, archives, labels, or asks.   |
| **Verification** | Every count traces to a scan; an unreadable read renders `?`, never a guessed number. |

## Prerequisites

- `br` installed — verify with `which br`
- `_plans/` (optional — empty renders as `—`)

---

## Phase 1 — render (one call)

```bash
BOARD="$(git rev-parse --show-toplevel)/.claude/skills/ac-board/scripts/board.sh"
[ -f "$BOARD" ] || BOARD="$(git rev-parse --show-toplevel)/skills/ac-board/scripts/board.sh"
"$BOARD"
```

Print its stdout verbatim — it is the board. `board.sh` runs every read of
`ac-pipeline/references/board-scan.md` (Scans A · B · E · F + docket-health, no loop-boundary
filter) plus waves, PRs and the agent roster in parallel; `render.py` derives the verdict
(RUNNING · IDLE · STUCK · EMPTY), reduces every section to counts, and renders `?` plus the failing command
for any read that cannot answer. Never re-derive a count it printed; never run the scans by hand.
Its `🎯 NEXT` block (top three moves in the pull order — `ac-pipeline/references/stage-table.md` § Pull order) is the routing — add nothing after it.

Asked "org-wide" → run `board.sh --compact` inside each `.beads/` repo (in parallel) and print
its one verdict line per repo. Asked for a live dashboard → point to `board.sh --watch [secs]` (default 15s).

## Principles

1. **Read-only is sacred** — no writes, no `br` mutations, no label changes, no prompts. If you want to fix what you see, you are the wrong skill: route it.
2. **A glance, not an audit** — cheap reads only, counts over prose, one screen if possible. Depth belongs to `ac-human` (drive the docket), `ac-tidy` (reconcile) and `ac-align` (strategy).
3. **No loop-boundary filter** — the loop side is the answer to "is the factory running". Show it.
4. **Never guess a count** — `?` plus the failing command beats a plausible number.
5. **Exit silently** — render and stop. The `🎯 NEXT` block is the hand-off.
