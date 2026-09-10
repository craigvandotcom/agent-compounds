# Board mode — the factory window

**You are the factory window.** Render the entire pipeline state — every stage, both sides
of the loop boundary — in one glance. You observe; you never act. The session opens with
this render; in `board` mode it is also the whole response. Inherits the skill's I/O
contract and principles: read-only, no prompts, no writes, unknowns render `?`.

## Phase 0 — scope

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

Inside a project → that repo. Asked "org-wide" → repeat the scan per `.beads/` repo (same
sweep list as the docket's org-wide sweep) and render one compact section per repo — flow
line + gate counts only, no itemization.

## Phase 1 — scan (read-only, parallel)

**Read the board per `ac-pipeline/references/board-scan.md`** (scans A beads · B plans ·
C backlog) — the shared pipeline read. Apply **no filter**: unlike the docket, keep BOTH
sides of the loop boundary (ready beads, in-flight waves, and `loop-ready` plans all render
here). The session reuses this same read; never scan twice.

**WIP:**

```bash
git fetch --prune --quiet 2>/dev/null
git branch -r | grep -E 'wave/'                                              # in-flight wave branches
gh pr list --state open --json number,title,headRefName,createdAt 2>/dev/null
gh run list --limit 3 --json status,conclusion,name,createdAt 2>/dev/null    # recent CI
```

Per wave branch, one cheap read: `git log origin/main..origin/<wave> --oneline | wc -l`
(commits ahead) + last-commit age. Skip anything expensive — this is a glance, not an audit.

**Journey debt** (Invariant 9, `ac-pipeline/references/verification-gate.md` §Journey
registry): per `CORE/journeys/*.md`, a non-peripheral journey (`criticality` ≥ `core`) with
no `last_pass` block is **missing**; with `last_pass` present, `skills/_tools/journey-stamp-check.sh`
decides **stale** vs current. Cheap read; org-wide sweep same as WIP.

**Friction sensors** (`skills/*/FRICTIONS.md`):
`python3 skills/skill-builder/scripts/friction-rollup.py --view trends` — the same shared
parse ac-align and dream run; derived at render time, never `--stamp`.

## Phase 2 — render

One shot, top-down. Omit an empty section with a single `—` line rather than dropping it
(the human should see the stage exists and is empty). Never itemize closed work beyond the
summary count.

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
queue lanes: any label with >5 open human-gate beads — count them, never itemize them
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

- **Counts first, detail second** — the two header lines are the whole dashboard in a
  glance; everything below is drill-down.
- Itemize only *open/active* things; cap any list at ~10 lines with `… +{N} more`. Flags
  are **observed, never acted on** — each gets a route in the footer, nothing more.
- The `🤖/🧑` split is the loop boundary made visible — it answers "is the factory running
  and what does it need from me" without opening the docket.
- When the board opens a session, the docket tiers below it are the drill-down; when `board`
  is invoked alone, stop after this render.

## Phase 3 — routing footer

Standalone `board` mode closes with pointers, not prompts — no `AskUserQuestion`, ever:

```
Act: gates/decisions → /ac-human-session · reconcile/re-prioritize → /ac-align · ship the ready work → /ac-implement
```

---
