# Docket scan — the Decision Docket lens and the docket-only reads

Extracted from the spine 2026-09-12 (ac-1p7j.37). The spine carries the
pointers; this file carries the lens. Nothing here is load-bearing without
the spine's loop boundary — this lens applies AFTER the boundary filter.

## Your lens on the board

- **🔴 Decision Docket (PRIMARY)** = board beads matching `human-gate` OR `pipeline-proposal` OR `dream-proposal`, open. The first-class channel for human-required work — pre-staged with a memo (context, options + trade-offs, recommendation); agents enrich but **never** close them, so they survive every autonomous sweep until the human decides. The collector is the union, not a pairing — proposal beads do not need `human-gate` to appear. (`qa-blocker` is a *merge* gate, agent-resolvable — NOT human-gate, so it never appears here.)
  - **Applying a pipeline proposal:** invoke the owning skill (`ac-align`) in its INTERACTIVE flow. The skill's own gate re-confirms the moves against the *current* board (this late-binding re-prompt is intended, not a bug — do NOT add a bypass), then set the proposal file `status: applied` + `br close` the bead. **Verify the memo's HARM, not only its facts** — ask "what consumes this, and what breaks if I do nothing?" before working the list. A memo is an argument, not a finding.
  - **Discarding one:** set the proposal file `status: rejected` + `br close` the bead; do NOT invoke the owning skill.
  - **Verify before presenting (anti-rot):** human-gate beads outlive their work and memos freeze step-lists later waves can invalidate. Before surfacing an item, spend ~1 read confirming its live state. Present the *verified* remaining scope — often "already done → one tap to book it" — and fold corrections onto the bead as an enrichment comment.
    - **MANDATORY FIRST READ — the bead's own `events` table, before any other verification.** `sqlite3 .beads/beads.db "SELECT created_at,event_type,comment FROM events WHERE issue_id='<id>' ORDER BY created_at;"`. **A comment is a CLAIM; `events` is the RECORD.** `label_removed human-gate` followed by a DECISION/RULING/RELEASE comment means the bead was RELEASED — do not re-gate it, and NEVER re-gate one released more than once. Evidence: `references/docket-anti-rot.md`.
    - **FRESHNESS BOUND on `(tap-ready)` — DATE precision, three branches.** The nightly stamps a surviving gate with a `verified: <YYYY-MM-DD>` comment (`ac-align/workflows/nightly-reconcile.md`); read the newest stamp and render exactly one of three ways:
      - dated **TODAY** → `(tap-ready)`;
      - dated **earlier** → `⚠ stale — reverify` (do the ~1-read verification, re-stamp, then it is tappable);
      - **no stamp at all** → `⚠ never verified — reverify`. Absence is not freshness — never let an unstamped gate inherit `(tap-ready)`.
      "Today" is the **local calendar date** of the machine running the session. The day boundary is deliberately loose and that is not a bug: a false "stale" costs one read, the cheap direction to be wrong in.
- **Group the docket by gate kind — `issue_type` (`decision` vs `task`), title prefix as fallback** (`ac-pipeline/references/board-scan.md` § Gate kind): the two human-gate template kinds (`beads-standards` § Human-gate template) are presented grouped — forks/approvals/proposals in one cluster (one-tap choices), do-in-the-world tasks in another (checklists to run, often with a `best-done-when` hint).

## Extend the docket org-wide

At org level or asked "across everything", sweep ALL `.beads/` repos, not just this one. Roots come from the environment, never literals — `REPOS_ROOT` (the workspace root, e.g. `~/Repos`) and `APPS_LIST` (a file listing workspace-relative app paths, one per line):

```bash
for repo in "$REPOS_ROOT" $(while IFS= read -r a; do echo "$REPOS_ROOT"/$a; done < "$APPS_LIST"); do
  [ -d "$repo/.beads" ] || continue
  (cd "$repo" && br list --json --limit 0 2>/dev/null) | \
    jq --arg repo "$(basename $repo)" '[.issues[] | select((.labels // []) | (index("human-gate") or index("pipeline-proposal") or index("dream-proposal"))) | select(.status != "closed") | . + {repo: $repo}]'
done
```

## Non-board reads (session-specific — not in board-scan)

```bash
curl -s -o /dev/null -w "%{http_code}" "$PROD_URL" 2>/dev/null             # prod health
```

PRs and CI come from the board render (Phase 1) — do not re-probe them here.

**`$PROD_URL` is per-project — resolve it, never hardcode.** Read the project's live domain from its `AGENTS.md` / CORE, or the deployed alias. A **retired** domain must not be probed: a 🔴 that is always red trains the human to ignore the 🔴 tier.

Also flag open beads explicitly blocked on a human (notes "waiting on" / "needs manual" / "requires account" / "human decision") that aren't already `human-gate`.
