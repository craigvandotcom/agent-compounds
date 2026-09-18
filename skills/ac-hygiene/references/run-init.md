## Phase 0: Initialize

### Select Scope

**Interactive run** — ask user with `AskUserQuestion`:

```
question: "What should the review focus on?"
header: "Scope"
options:
  - label: "Full codebase (Recommended)"
    description: "Agents choose where to look — recent changes, hot paths, random exploration"
  - label: "Recent changes"
    description: "Focus on last N commits (asks how many)"
  - label: "Specific directory"
    description: "Constrain to a directory tree (asks which)"
```

If "Recent changes": ask for commit count, then `git log --oneline -N` to build scope context.
If "Specific directory": ask for path, then list source files in that directory to build scope context.

**Headless run** (scheduled job, or user said "run unattended"): skip the question —
`SCOPE=Full codebase`, `PANEL=full`, and every later `AskUserQuestion` in this workflow is
skipped too (the Exhaust Rule routes what would have been asked into beads).

### Configuration

```
SCOPE=<user selection or Full codebase>
SCOPE_CONTEXT=<commit list or directory listing, if scoped>
PANEL=full            # full = 5 lenses (weekly run) | light = 3 (quick pass, user asked for "light")
CURRENT_ROUND=1
MIN_ROUNDS=3          # ABSOLUTE floor — cross-round consensus needs recurrence opportunities; never finalize before this, even on consecutive zero-finding rounds
MAX_ROUNDS=5
# Mint RUN_ID if the orchestrator didn't hand one down (contract: ac-pipeline/references/run-id.md
# mint-if-absent rule) — keeps standalone and orchestrated runs on the same formula.
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
ARTIFACTS_DIR=/tmp/hygiene-${RUN_ID}   # RUN_ID carries the PID → no same-second collision (ac-pipeline/references/run-id.md)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
```

### Work Directly on Main (trunk-direct — no worktree, no hygiene branch)

Hygiene **conforms to trunk-direct**: there is no hygiene branch and no worktree. Auto-applied
fixes commit straight to `main` as pathspec commits under the **full H7 discipline** the
`ac-implement` Phase 0 spells out — the implementing-conductor concurrency rules apply to
hygiene whenever it is actively *fixing code* (hygiene is exempt from H7 **only** while purely
reading/filing beads, never while editing). The 5-lens panel below IS this run's pre-push
review, so there is **no separate review step** (branch policy: `ac-pipeline` § Branch policy).

```bash
git checkout main 2>/dev/null || true
git pull --rebase
git branch --show-current   # confirm `main` before doing anything else
```

**Dirty-tree rule (trunk-direct — H7d):** a non-empty `git status --short` is EXPECTED and is
**NOT a blocker** — every session shares one checkout on `main`, so another session's in-flight,
not-yet-committed work may be sitting there. **Inventory it; do not touch it.** Only files YOU
changed enter YOUR commits (pathspec-mandatory, Phase 3): never `git add -A`, never
`git add .`, never `git commit -a`, and **never `git stash`** (a stray `stash pop` writes
conflict markers into unrelated files — H7d, `ac-pipeline/references/commit-discipline.md`). Use `git diff HEAD` if you
need to isolate uncommitted-vs-committed state. If the inventory shows a genuine red flag
(unexpected deletions, sensitive files, something orphaned rather than in-flight), surface it to
the user before proceeding — otherwise proceed past it.

### Initialize Consensus Registry <!-- if dcg rejects this write, do NOT bypass: the guard blocks a redirect whose target path is variable-built — sanctioned shapes (tee, the Write tool) in ac-pipeline/references/shell-guardrails.md -->

```bash
tee "$ARTIFACTS_DIR/consensus-registry.md" >/dev/null <<'EOF'
# Consensus Registry

Tracks single-agent findings across rounds. If a finding recurs in a later round, it achieves cross-round consensus and is auto-applied.

## Deferred Findings

<!-- Format: | Round | Agent | Severity | File | Summary | -->
EOF
```

### Compaction Recovery

If `$ARTIFACTS_DIR/progress.md` exists, parse the last `### Round N` entry to recover `CURRENT_ROUND` (set to N+1). Previous rounds' fixes are already applied. If `$ARTIFACTS_DIR/consensus-registry.md` exists, read it to recover the deferred findings pool for cross-round consensus detection.

<!-- diet: "Gather Codebase Cont…" section -> deleted (ac-gcj.8) — orphaned: its saved context variable fed no prompt; all 7 lenses consume {SCOPE_CONTEXT}, set independently in Configuration -->

### Skill Routing

Scan codebase for domain keywords. Check `AGENTS.md > Available Skills` for relevant skills. Include skill paths in reviewer prompts where applicable.

### Coverage Audit (standing doctrine — projects with `CORE/journeys/`)

Mechanical, conductor-run, once per hygiene run (not per round, not an agent
lens) — the enumeration hole is that an untagged surface is silently
unprotected, which is the original failure one level up, so this can't be a
sampled hunt:

1. **RE-DERIVE the app's surface inventory from ground truth** — grep the live
   tree for routes (`app/**/page.tsx` or platform equivalent), nav entries,
   FABs, deep-link handlers, push-notification entry points. Never recall this
   from memory or a prior run's notes — derive it fresh from the current tree
   every time.
2. **Diff against the journey registry** — parse `CORE/journeys/*.md`
   frontmatter (`criticality`, `surfaces`; schema: `ac-pipeline/references/verification-gate.md`
   §Journey registry). A doc with no frontmatter defaults to `peripheral`.
3. **Untagged critical-looking surfaces become findings** — a derived surface
   with no matching journey doc, or one whose match reads `peripheral`/untagged
   while the surface name matches payment/auth/purchase/onboarding. File per
   `references/journey-coverage.md`: coverage gaps are unconfirmed leads
   (`investigation`, the probe-exempt type), and only actionable defects become
   beads — a conformance PASS is a ledger line, never a bead.

If `CORE/journeys/` doesn't exist for this app, skip — nothing to audit. This
same derivation is the starting point for the initial all-apps journey-tagging
sweep; the audit and the sweep share one inventory method so tags come from
ground truth, never memory.

### Knip Dead-Code / Unused-Dep Lens (weekly cadence only — `PANEL=full`)

Mechanical, conductor-run, once per hygiene run (not per round, not an agent lens) — same
shape as the Coverage Audit above. This lens runs alongside, not instead of, the standing
`command` cron entry ("Code Hygiene - Weekly knip sweep", Sat 05:30, root
`infrastructure/jobs/weekly.json)
— the cron job is a standalone tripwire; this lens is the conductor's own pass, wired into the
weekly panel run so findings feed the same triage/bead path as the other lenses.

1. **Run `pnpm knip`** from the app root. The committed `knip.json` is this lens's
   provenance for what gets filtered — framework false-positives are excluded there; don't
   re-litigate its exclusions per run.
2. **Surface real findings** (dead exports, unused files, unused/unlisted deps) as hygiene
   findings — real dead code becomes cleanup findings/beads exactly like the other lenses'
   output: route through Phase 5 triage (`AUTO_IMPLEMENT` for unambiguous dead-code removal,
   `br create -t task --labels origin:ac-hygiene,hygiene-finding,unrefined,impact:<class>` for anything needing a human look —
   e.g. an export that *looks* dead but may be a public API surface).
3. **Weekly cadence only** — this lens runs on `PANEL=full`; skip it on `PANEL=light` (the
   quick between-session sweep).

If the app has no `knip.json` / no `knip` devDependency, skip — nothing to run.

### Stamp-Audit Lens (weekly cadence only — `PANEL=full`)

Mechanical, conductor-run, once per hygiene run (not per round, not an agent lens) — same
shape as the two lenses above. This is the integrity check on the proof gate itself
(`skill-builder/references/promotion-ladder.md` §The ladder — tier-1 promotion needs "N green
runs that EXERCISE it... / probe-verified fact / operator sign-off"): a stamp is only as good as
the run history behind it, and nothing currently re-checks a stamp already resident in the tree
against reality.

1. **Grep every skill's SKILL.md/references for evidence stamps** — the
   `<!-- evidence: <N green runs | probe-fact | operator sign-off> -->` form (`ac-review`'s
   doctrine-delta dimension checks this shape at diff-time; this lens re-audits stamps already
   landed, not just new ones).
2. **Spot-check each claim against actual run history** — CI run logs, `.claude/reviews/batch/`
   commits, or dream recurrence records that plausibly exercised the stamped mechanism. A stamp
   claiming a green-run count the record can't substantiate, or a probe-fact stamp whose probe
   script no longer exists, is a finding regardless of the stamp's age.
3. **File it same as any stale-content finding** — route via the Deletion Mandate (Phase 2): pull
   the false claim (demote/delete per promotion-ladder.md) or downgrade the content it guards back
   to `references/`/holding-pen if the proof no longer holds.
4. **Weekly cadence only** — this lens runs on `PANEL=full`; skip it on `PANEL=light`.

### Friction Cluster-Walk Lens (weekly cadence only — `PANEL=full`)

Mechanical, conductor-run, once per hygiene run (not per round, not an agent lens) — same
shape as the three lenses above. The organic-surfacing half of W4.6
(`skill-builder/references/friction-capture.md`): this repo's own weekly quality pass is a
second, hygiene-cadence backstop over the friction sensor logs, alongside — never instead
of — `dream` Phase 2's weekly weighting pass (`dream/SKILL.md` § Phase 2, W4.5).

1. **Walk the `related` graph across every `skills/*/FRICTIONS.md`** — the graph is a free
   byproduct of capture-time dedup judgment (`friction-capture.md` § Deduplication), not
   something this lens builds; it only reads it, grouping ids into clusters the same way
   W4.5 does.
2. **Reuse W4.5's weight/threshold verbatim — do not redefine them here:**
   `weight(id) = impact_num × frequency_num × recurrence`, threshold `weight >= 12`
   (`dream/SKILL.md` § Phase 2 is the single definition; cite it, don't fork it).
3. **An over-bar cluster files directly** as `br create -t task --labels
   origin:ac-hygiene,hygiene-finding,skill-improvement,unrefined,impact:<class> -d "Friction cluster-walk: <id(s)> —
   <cluster's proposed_fix(es)>. weight=<N>, skills=<list>."` — deduped via `br search`
   first, same as any other hygiene finding (Exhaust Rule). This is the direct,
   no-judge-round path; it does not replace dream's judged/gated proposal path, it
   catches the same signal on a different cadence so a cluster surfaces without anyone
   manually reading FRICTIONS.md.
4. **Weekly cadence only** — this lens runs on `PANEL=full`; skip it on `PANEL=light`.

If no skill in this repo has a `FRICTIONS.md` yet, skip — nothing to walk.

### Create Workflow Tasks (run ledger)

**One task per major section — the ledger exists for CLARITY + ACCOUNTABILITY**, so every
section you'd report on gets its own line (not a 3-phase skeleton). Create the fixed tasks
below at Phase 0; **ADD a "Round N" task at the start of each review round** (rounds are
dynamic — 3 floor, up to 5 — so the ledger grows to the real shape instead of pre-committing
to a round count or showing phantom rounds). `TaskUpdate` each to `in_progress` when you start
it and `completed` when done; put live detail in the description (per round: finding counts +
commit SHA), so a glance at the ledger shows exactly where the run is.

Ledger contract: `ac-pipeline/references/run-ledger.md` — one task per section, advance as you go; ledger = run position, never work items.

```
# Fixed tasks — create upfront at Phase 0:
TaskCreate("Initialize — scope, confirm on main (trunk-direct), consensus registry, baseline gate")

If TaskCreate is unavailable (subagent / fan-out path), track the ledger inline in progress.md; this is a sanctioned equivalent, not a deviation.
TaskCreate("Coverage audit — surface inventory vs journey registry; file journey-gap beads")
TaskCreate("Triage deferred findings + file bead epic (Exhaust Rule)")
TaskCreate("Exhaustive quality gate — format → type-check → lint → full suite")
TaskCreate("Close ceremony — delegate to ac-publish")
TaskCreate("Refine the epic's beads in-session — ac-polish (bead mode)")
TaskCreate("Report — hygiene summary + Slack (headless)")
TaskCreate("Cleanup / teardown — artifacts")

# Per-round task — create ONE as each round begins (not upfront):
TaskCreate("Round {N} — 5-lens panel → synthesize → auto-apply → gate → commit")
# On completion, TaskUpdate its description: "{C}/{H}/{M} findings, {n} auto-fixed, commit {sha}"
```

With a 3-round run that's 11 tasks; a 5-round run, 13. **TaskUpdate("Initialize", in_progress)**
now, and mark it `completed` at the end of Phase 0. Sub-skills invoked by the Ship and Refine
tasks (`ac-publish`, `ac-polish`) run their OWN ledgers — do not duplicate their steps here;
this ledger tracks the hygiene run's top-level sections only.
