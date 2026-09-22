# Docket scan — what docket.sh reads, and the reads it leaves to you

The spine carries the pointers; this file carries the lens. `scripts/docket.sh` executes it —
never re-run these reads by hand.

## The Decision Docket lens (computed)

- **Collector:** open beads carrying `human-gate` OR `pipeline-proposal` OR `dream-proposal` —
  the union, not a pairing. On-docket = board-scan § Docket health's `on_docket`: `open` /
  `blocked` / `in_progress`, never `deferred`, never a future `defer_until`. (`qa-blocker` is a
  *merge* gate, agent-resolvable — never on the docket.)
- **Kind:** `issue_type` (`decision` → fork/approval/proposal cluster; `task` → do-in-the-world
  checklist), title prefix only when the type is absent (board-scan § Gate kind).
- **Freshness (anti-rot):** the newest `verified: <YYYY-MM-DD>` comment, against the machine's
  local calendar date — today → `(tap-ready)`, earlier → `⚠ stale — reverify`, none →
  `⚠ never verified — reverify`. Absence is never freshness.
- **Released history:** from the bead's `events` — `label_removed human-gate` followed by a
  DECISION / RULING / RELEASE comment counts one release → `⚠ released ×N`. A comment is a
  CLAIM; `events` is the RECORD (`docket-anti-rot.md`).
- **Memo:** a `decision` lacking all of `evidence:` / `consequence:` / `recommendation:` →
  `⚠ no memo`; lacking some → `⚠ gate-incomplete (no …)`.
- **Stray human-pending:** open non-gate beads whose body reads "waiting on" / "needs manual" /
  "requires account" / "human decision" — listed under `⚠ Also`; migrate each to a
  `human-gate` bead when you reach it.

## Org-wide

`docket.sh --org` runs `docket.sh --gates` in every `.beads/` repo in parallel. Repos come from
the environment — `REPOS_ROOT` + `APPS_LIST` (one workspace-relative app path per line) — else
from `engine/machine.sh`: the org root, its immediate children, this registry, and every deploy
target. A repo whose read fails renders `DEGRADED` or `?`, never silently absent. Each block
carries `unpushed ledger: N` — ledger commits not yet on the upstream (`NOT-CHECKED` without
one).

## Reads left to you

```bash
curl -s -o /dev/null -w "%{http_code}" "$PROD_URL" 2>/dev/null             # prod health
```

**`$PROD_URL` is per-project — resolve it, never hardcode.** Read the live domain from the
project's `AGENTS.md` / CORE or the deployed alias. Never probe a **retired** domain: a 🔴 that
is always red trains the human to ignore the 🔴 tier. PRs and CI come from the board render.
