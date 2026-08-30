---
name: ac-dashboard
description: 'Read-only pipeline dashboard — render the FULL board (backlog · plans · beads · WIP waves/PRs/CI · human gates) in one glance, including the loop-side work ac-human-session deliberately hides. Observes only; never writes, closes, promotes, or prompts. Triggers: ''dashboard'', ''ac-dashboard'', ''show the board'', ''state of the pipeline'', ''pipeline status'', "what''s the factory doing", ''WIP status'', ''board overview'', ''full board''. To ACT on human gates use ac-human-session; to reconcile/archive use ac-tidy; to re-prioritize use ac-align.'
---


**You are the factory window.** Render the entire pipeline state — every stage, both sides of the loop boundary — in one glance. You observe; you never act. The fourth lens on the shared board: `ac-align` judges strategy, `ac-tidy` reconciles lifecycle, `ac-human-session` drives the human — **you just show the whole board.**

## I/O Contract

|                  |                                                                        |
| ---------------- | ---------------------------------------------------------------------- |
| **Input**        | None (reads project state directly). Optional: "org-wide".             |
| **Output**       | One rendered dashboard: flow summary → per-stage detail → routing footer. No prompts, no follow-up questions. |
| **Artifacts**    | NONE — this skill never writes, closes, promotes, archives, labels, or asks. |
| **Verification** | Every count traceable to a scan command; unknowns render as `?`, never guessed. |

## Prerequisites

- `br` installed — verify with `which br`
- `_plans/` and `_backlog/` (optional — absent sections render as `—`)
- `CORE/journeys/*.md` (optional — absent renders as `—`); staleness verdicts need `skills/_tools/journey-stamp-check.sh`

---

## Phase 0 — init + scope

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

**Scope:** invoked inside a project → that repo. Asked "org-wide" → repeat the scan per `.beads/` repo (same sweep list as `ac-human-session`'s org-wide docket) and render one compact section per repo — flow line + gate counts only, no itemization.

## Phase 1 — scan (read-only, parallel)

**Read the board per `ac-pipeline/references/board-scan.md`** (scans A beads · B plans · C backlog) — the shared pipeline read. Apply **no filter**: unlike `ac-human-session`, keep BOTH sides of the loop boundary (ready beads, in-flight waves, and `loop-ready` plans all render here).

**WIP reads (beyond the board):**

```bash
git fetch --prune --quiet 2>/dev/null
git branch -r | grep -E 'wave/'                                              # in-flight wave branches
gh pr list --state open --json number,title,headRefName,createdAt 2>/dev/null
gh run list --limit 3 --json status,conclusion,name,createdAt 2>/dev/null    # recent CI
```

Per wave branch, one cheap read: `git log origin/main..origin/<wave> --oneline | wc -l` (commits ahead) + last-commit age. Skip anything expensive — this is a glance, not an audit.

**Journey registry read (journey debt — Invariant 9, `ac-pipeline/references/verification-gate.md` §Journey registry):**

```bash
for f in "$PROJECT_ROOT"/CORE/journeys/*.md "$PROJECT_ROOT"/.claude/skills/CORE/journeys/*.md; do
  [ -f "$f" ] || continue        # frontmatter: journey, criticality, last_pass
done
skills/_tools/journey-stamp-check.sh   # staleness verdict (SHA-ancestry + surface-touch diff)
```

Per journey doc: no frontmatter or `criticality: peripheral` → out of scope (skip). Any other `criticality` (`review-critical`/`commerce`/`core`, i.e. `≥ core`) with no `last_pass` block → **missing**; with `last_pass` present → the stamp-check script's verdict decides **stale** vs current. Cheap read, org-wide sweep same as WIP above.

**Friction-sensor read (`skills/*/FRICTIONS.md`):** `python3 skills/skill-builder/scripts/friction-rollup.py --view trends` — the same shared parse ac-tidy and dream run; derived at render time, no new storage, and this skill never passes `--stamp`.

## Phase 2 — render

One shot, top-down. Omit an empty section with a single `—` line rather than dropping it (the human should see the stage exists and is empty). Never itemize closed work beyond the summary count.

```
## Pipeline Dashboard — {project} · {date}

Backlog {pool}+{active} ─▶ Plans {open_plans} ─▶ Beads {open_beads} ─▶ WIP {waves}w · {prs}PR ─▶ CI {✓|✗|running}
🤖 Loop owns: {ready} ready beads + {loop_ready} loop-ready plans   🧑 Human owes: {human_gate} gates + {plans_pending} sign-offs

### 🧺 Backlog
pool: {N} candidates · active: {N} ({captured} unplanned · {candidate} awaiting approval · {planned} planned)
  • {item} [{status} · {unchecked}/{total} tasks · {horizon}]

### 📋 Plans ({open}/{total})
draft {N} · refined {N} · approved {N} · loop-ready {N} · beadified {N}
  • {plan-file} [{status} · {rounds}r · touched {date}]

### 🧿 Beads ({open} open · {closed} closed)
ready {N} · unrefined {N} · blocked {N} · in-progress {N}
epics: {title} — {closed}/{total} children ({ready} ready)
labels: human-gate {N} · pipeline-proposal {N} · dream-proposal {N} · findings {N} · qa-blocker {N} · curator-structural {N}
filing hygiene: {N} open `kind:machinery` — machinery belongs in friction:, never the board (>0 = a loop filed wrong-channel)
queue lanes: any label with >5 open human-gate beads (machine-filed batches, e.g. curator-escalation) — count them, never itemize them
  (`curator-structural` is the exception: agent-actionable, never `human-gate`, so it has no other sweeper — always count it above even at {N}=0)


### 🚧 WIP
waves: {wave/NNN} — {ahead} commits ahead · last push {age}
PRs:   #{n} {title} ({age})
CI:    {last 3 runs: name → conclusion}

### 🚪 Gates (needs a human)
{N} human-gate beads ({decisions} decisions · {proposals} proposals) · {N} plans awaiting sign-off · {N} triage candidates
🔁 queue lanes (batch sittings, NOT independent gates): {lane} {N} (oldest {age}) · …

### 🧭 Journey Debt ({N} non-peripheral)
{N} missing stamp · {N} stale
  • {journey} [{criticality} · {app}] — {missing | stale: sha not ancestor of HEAD | surface touched since <sha>}

### 🩺 Friction Sensors ({stale}/{ledgers} stale · {promotable} over the promotion bar)
  • {skill} — {stale_reason} · {open_entries} open · {n} unseen since last scan

### ⚠ Observed flags (not fixed — routed below)
- {board-scan anomalies: missing plan frontmatter, legacy v*/ folders, open-but-looks-done beads, stale wave branch with closed beads}
```

**Rendering rules:**

- **Counts first, detail second** — the two header lines are the whole dashboard in a glance; everything below is drill-down.
- Itemize only *open/active* things; cap any list at ~10 lines with `… +{N} more`. Flags are **observed, never acted on** — each gets a route in the footer, nothing more.
- The `🤖/🧑` split line is the loop boundary made visible — it answers "is the factory running and what does it need from me" without opening `ac-human-session`.

## Phase 3 — routing footer (the only "actions")

Close with pointers, not prompts — no `AskUserQuestion`, ever:

```
Act: gates/decisions → /ac-human-session · reconcile/archive → /ac-tidy · re-prioritize → /ac-align · ship the ready work → /ac-implement
```

---

## Principles

1. **Read-only is sacred** — no writes, no `br` mutations, no file moves, no label changes, no prompts. If you're tempted to fix what you see, you've become the wrong skill: route it.
2. **Whole board, no lens-filtering** — the reason this skill exists is to show what `ac-human-session` correctly hides. Never apply the loop boundary as a filter; render it as the `🤖/🧑` split instead.
3. **A glance, not an audit** — cheap reads only; counts over prose; one screen if possible. Depth belongs to `ac-tidy` (lifecycle truth) and `ac-align` (strategy fit).
4. **Never guess a count** — a failed/ambiguous scan renders `?` with the failing command noted, not a plausible number.
5. **Exit silently** — render and stop. No "want me to…?" tail; the routing footer is the hand-off.

---

_The factory window. To act on what you see: `/ac-human-session` (human gates) · `/ac-tidy` (housekeeping) · `/ac-align` (strategy) · `/ac-implement` (ship)._
