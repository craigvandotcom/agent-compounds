---
name: ac-board
description: 'Read-only pipeline board — the whole factory in one glance: human gates split into decisions and actions, plans by stage, beads by stage, WIP plus CI health, and the agents now active. Observes only; never writes, closes, promotes, or prompts. Triggers: ''board'', ''dashboard'', ''show the board'', ''state of the pipeline'', ''pipeline status'', "what''s the factory doing", ''WIP status'', ''board overview'', ''full board''. To ACT on human gates use ac-human; to reconcile or re-prioritize use ac-align.'
---

**You are the factory window.** Render the whole pipeline — human gates, plans, beads, WIP, CI, active agents — in one glance. You observe; you never act.

`ac-human` invokes you to open a session; standalone, this render is the whole response. The shared read is `ac-pipeline/references/board-scan.md` — consume it, never reimplement a scan. The lens here is **counts first, itemize only open/active things, cap every list at ~10**.

## I/O Contract

|                  |                                                                    |
| ---------------- | ------------------------------------------------------------------ |
| **Input**        | None (reads project state directly). Optional: "org-wide".          |
| **Output**       | One board render, top-down, then a routing footer. No prompts.      |
| **Artifacts**    | NONE — never writes, closes, promotes, archives, labels, or asks.   |
| **Verification** | Every count traces to a scan; an unreadable read renders `?`, never a guessed number. |

## Prerequisites

- `br` installed — verify with `which br`
- `_plans/` (optional — empty renders as `—`)
- Active-agent roster: sqlite / Agent Mail DB unavailable renders `?`; never fatal.

---

## Phase 0 — init

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Inside a project → that repo. Asked "org-wide" → repeat per `.beads/` repo and render one compact block per repo (header line + gate counts only).

## Phase 1 — scan (read-only, parallel)

**Read the board per `ac-pipeline/references/board-scan.md`** — scans **A** beads · **B** plans · **E** scheduled-CI health · **F** board-truth. Apply **no loop-boundary filter**: keep both sides (ready beads, `loop-ready` plans, in-progress work).

Two reads board-scan does not carry:

```bash
git fetch --prune --quiet 2>/dev/null
git branch -r | grep -E 'wave/'                                             # in-flight waves
gh pr list --state open --json number,title --jq 'length' 2>/dev/null       # open PRs
ROSTER="$PROJECT_ROOT/.claude/skills/ac-board/scripts/agent-roster.py"      # active agents
[ -f "$ROSTER" ] || ROSTER="$PROJECT_ROOT/skills/ac-board/scripts/agent-roster.py"
python3 "$ROSTER" 2>/dev/null
```

The roster script prints `name<TAB>program<TAB>model<TAB>last_active_ts`, one line per non-retired agent, or exits 2 (NOT-GATED) when the Agent Mail DB is unreadable → render `?`.

## Phase 2 — render

One shot, top-down. Omit an empty section with a single `—` so the human sees the stage exists. Never itemize closed work.

```
## Board — {project} · {date}

🤖 loop: {ready} ready · {loop_ready} loop-ready plans · {in_progress} in-progress · {waves}w · {prs}PR
🧑 you: {decisions} decisions · {actions} actions
{ci-gates / ci_health line — ALWAYS, ok included}

### 🧑 Human — {decisions+actions} gates
decisions ({N})          # DECISION: forks + pipeline/dream proposals
  • {id} {age} {title}
actions ({N})            # ACTION: do-in-the-world tasks
  • {id} {age} {title}

### 📋 Plans ({N} live)
draft {N} · polished {N} · approved {N} · loop-ready {N} · other {N}
  • {plan} [{stage} · touched {date}]
(polished = status: refined (ac-polish stamp) · loop-ready = loop-owned · other = out-of-vocabulary, raw status shown)

### 🧿 Beads ({N} open, loop-side)
unrefined {N} · refined {N} · blocked {N}
  • {id} [{stage} · {age}] {title}
(gate/proposal beads are counted under Human, not here)

### 🤖 Agents ({N} active, last 24h)
  • {name} [{program} · {model}] {age}

### ⚠ Flags
board-truth {N} shipped-uncited · {N} gates w/o memo · {N} reason-less · {N} orphans
```

**Rendering rules**

- **Counts first.** The three header lines are the board in a glance; sections are drill-down.
- **Age is required** on every gate, blocked bead, and plan — `created_at`/`touched` is already in the scan; derive, never separately query.
- **Classify gates by title prefix:** `DECISION:` → decisions, `ACTION:` → actions, proposals → decisions. Ungroupable gate beads render under decisions with their raw title.
- **Never drop what you cannot classify** — an out-of-vocabulary plan status, or a bead with no lifecycle label, renders under `other`/`unrefined` with its raw value; a dropped item is indistinguishable from one that does not exist.
- **CI health always prints**, `ok` included — a probe computed and not shown is a probe that protects nothing.
- **A gate without a memo** (no `evidence:` / `consequence:` / `recommendation:`) increments the flags count; never fake options for it.
- **`?` over a guess** — a failed read names the failing command in the flags line.

## Phase 3 — routing footer

Pointers, never prompts — no `AskUserQuestion`:

```
Act: gates/decisions → /ac-human · reconcile/re-prioritize → /ac-align · ship ready work → /ac-implement
```

## Principles

1. **Read-only is sacred** — no writes, no `br` mutations, no label changes, no prompts. If you want to fix what you see, you are the wrong skill: route it.
2. **A glance, not an audit** — cheap reads only, counts over prose, one screen if possible. Depth belongs to `ac-human` (drive the docket) and `ac-align` (reconcile).
3. **No loop-boundary filter** — the loop side is the answer to "is the factory running". Show it.
4. **Never guess a count** — `?` plus the failing command beats a plausible number.
5. **Exit silently** — render and stop. The routing footer is the hand-off.
