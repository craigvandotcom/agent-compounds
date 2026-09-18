## Phase 5: Finalize

### Conductor Final Review (Triage)

Read the consensus registry. Collect all remaining items:

1. **No-consensus findings:** Single-agent findings that never recurred across rounds
2. **DESIGN_DECISION items:** Findings deferred during rounds as genuine design decisions

**If nothing remains:** Skip — proceed to quality gate.

**Classify each remaining no-consensus finding:**

| Category | Criteria | Action |
|---|---|---|
| `AUTO_IMPLEMENT` | There is a clearly superior technical answer — better correctness, robustness, performance, or maintainability. The improvement is unambiguous. | Implement it now. |
| `DESIGN_DECISION` | No objectively superior answer AND the choice would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and classify as `AUTO_IMPLEMENT`. | Defer to user. |
| `SCOPE_ESCALATION` | A technically superior option exists but requires profound structural change that constitutes a strategic commitment. | Defer to user with scope context. |

**Default bias: `AUTO_IMPLEMENT`.** Most findings have a correct answer — pick it.

<!-- mirror: ac-pipeline/references/review-consensus.md §Conductor triage — edit there first -->

**Apply all `AUTO_IMPLEMENT` items** using Edit tool. Log each with rationale.

### Present Decisions to User (if any)

**If no `DESIGN_DECISION` or `SCOPE_ESCALATION` items remain:** Skip — proceed to quality gate.

**Exhaust rule (see `skills/beads-standards/reference/bead-conventions.md`):** nothing actionable
leaves as prose. Out-of-scope confirmed issues → `br create -t bug --labels
origin:ac-hygiene,hygiene-finding,unrefined,impact:<class>`. Worth-chasing uncertainties → `-t investigation`. Genuine
taste/product forks in an autonomous run (user not present) → `-t decision
--labels human-gate` with a pre-staged memo, then continue — never stall the
sweep on a question. Dedupe per the canon's anchor-dedupe rule
(`beads-standards/reference/bead-conventions.md` § Anti-inflation); nits stay in the report
(hygiene is the highest inflation risk — a bead is something you'd schedule).

> **`human-gate` is added ONLY when the body states a canonical `Gate-reason:` —
> `fork` · `authorization` · `intent` · `action`.** Those four reasons are the only
> legal add (`beads-standards` § human-gate owns the vocabulary); mechanical work is
> never gated by default, a fork is legal only when it passes the escalation test
> (`reference/human-gate-template.md` § The escalation test), `issue_type=decision`
> alone gates nothing — the LABEL is what every label-keyed gate reads, a fork that passes the test still needs `human-gate` plus the marker, and a dropped pair is silently workable/auto-closable around the human.
> `the refine lane`'s Phase 5 title/label parity check (bd-7fqgi) backstops any that slip.

**Bead bodies follow the template at creation** (bead-conventions § Body
template): typed headers (`## Steps to Reproduce` for bugs, `## Acceptance
Criteria`, `## Test Scope` with grep-verified anchors, `## Success Criteria` on
the epic) plus a durable evidence pointer (the run's PR, not `$ARTIFACTS_DIR`
paths — those are deleted at Cleanup). Writing the full body now costs a minute vs a
full refine round later — the in-session refine step then verifies instead of authoring.

**Per-run epic:** if this run created 2+ beads, group them under one epic
(`br create -t epic "Hygiene <date> — deferred findings" -l origin:ac-hygiene,impact:<class>`, children linked) so the
batch is refined together in-session (see "Refine the Run's Beads" below) and
shipped by the loop as orphan fixes. 0–1 beads → no epic (don't inflate).

**If items remain (user present):**

```
AskUserQuestion(
  questions: [{
    question: "Auto-applied {N} fixes (severity + consensus + technical triage). {M} items need your decision:",
    header: "Decisions",
    multiSelect: true,
    options: [
      { label: "Fix X: <title>", description: "DESIGN_DECISION — Round {R}, {severity} — {agent}: {file} — {one-line summary}" },
      { label: "Fix Y: <title>", description: "SCOPE_ESCALATION — {severity} — {agent}: {file} — {one-line summary}. Scope: {what it entails}" }
    ]
  }]
)
```

**If more than 4 items:** Split across multiple `AskUserQuestion` calls.

**Apply any user-approved fixes** using Edit tool.

### Quality Gate (exhaustive — pre-handoff sanity check)

```bash
# Order MIRRORS CI's Quality Gate exactly — format is the FIRST thing CI checks.
format (auto-fix, e.g. `pnpm format`) + type-check + lint + full test suite   # BLOCKING
```

This is the single exhaustive local run of the workflow (rounds ran affected-only). Format runs
FIRST as auto-fix; if it rewrites files you did NOT author, commit the formatting as part of
this run (rule + why: `ac-pipeline/references/verification-gate.md` §Format-first gate). If any check fails,
fix before proceeding. Commit any Phase-5 fixes (user-approved + AUTO_IMPLEMENT triage items)
directly to `main` (pathspec, push immediately; **no `--no-verify` on the commit**, `--no-verify`
on the push only — same rule as Phase 3).

**Note:** the close ceremony below (`ac-publish`) dispatches Tier 1 CI on the final SHA —
so this Phase-5 local run is a pre-handoff sanity check, not the last word. Keep it: catching a
red gate here, before handing off, is cheaper than catching it inside the CI dispatch.

### Close Ceremony (delegate to ac-publish)

There is **no branch to ship** — every fix is already committed and pushed to `main` (Phase 3).
The close ceremony is therefore batch-close style, not a merge:

**No commits landed (findings only)?** Skip to Report — nothing to close, no version bump.

**Otherwise: invoke `ac-publish`.** Do not build a third bespoke close mechanism and do not
route through a branch-merge path (dependabot, human PRs). `ac-publish` owns the trunk-direct close: version bump → Tier 1 CI dispatch +
fix-forward → tag → deploy verification. Delegation prompt:

> "Run ac-publish for this hygiene run's commits on `main`. Version bump = patch (existing
> hygiene-bumps-patch policy — accept without asking); the 5-lens panel already served as this
> batch's review — **pass the panel run report as the pre-supplied review artifact for Phase 1
> path (a)** (it carries an explicit `VERDICT:` line; stage it in `.claude/reviews/pending/` and
> carry it into `.claude/reviews/batch/` via your Act 3 commit — never write to `batch/` outside
> that single commit, bd-kudrb), so do NOT re-run `ac-review` on this same diff; uncertain CI feedback →
> decision beads (Exhaust Rule); no 'what's next?' after."

**Hand `ac-publish` the "Also carried (not hygiene fixes)" disclosure.** With no PR diff to
eyeball, foreign work that rode along is easy to miss — diff `main` since this run's first
hygiene commit (`git log --oneline <first-hygiene-sha>..HEAD`) and name any non-hygiene commit
(an `.env`/secret edit, a migration, another session's fix) as Also-carried content for the
batch-close report — do not silently drop it just because this run didn't author it.

- **Hygiene bumps `patch`** via `ac-publish` (unchanged policy — `ac-publish` is the
  trunk-direct bump owner, default patch unless explicitly frozen/skipped).
- **No CI on this repo:** `ac-publish`'s concern — it falls back to a local
  quality-gate-then-tag path when there's no `quality-gate.yml` dispatch to run.
- CI fails → `ac-publish` fixes forward on `main` and re-dispatches as part of its own
  triage loop; if unfixable this session it files a `qa-blocker`-style bead and reports it —
  never tag red.

### Refine the Run's Beads (in-session, after the close ceremony)

If this run created **≥1 bead**, run **`ac-polish` (bead mode)** NOW — scoped to the epic if one
exists (2+ beads), to the single bead otherwise — before the report, not "later": the
conductor still holds every finding, verdict, and triage rationale in context; a deferred
refine session re-derives it from cold, or can't. Run-specific notes for the reviewer prompts:

- Bead descriptions were written mid-run — file/line references predate the merged fixes.
  Reviewers must re-verify every reference against merged `main` and correct drift.
- The refine reviewers work in the shared `main` checkout (there is no hygiene worktree under
  trunk-direct); fixes are already committed and pushed to `main`.
- Give reviewers the evidence, not just the beads: `$ARTIFACTS_DIR` still exists (Cleanup
  runs later) — point the refine reviewers at the round findings files and consensus
  registry so they verify beads against the ORIGINAL evidence and severity rationale,
  not only against code.

Headless runs included — refinement is agent-satisfiable (genuine design forks already went
through this run's decision gates or carry `human-gate`). 0 beads → skip (nothing to
converge). Hygiene never stamps `refined` itself — that label comes from **this
`ac-polish` run**, on its own convergence, exactly like any other bead; hygiene's
role is to run it in-session while context is hot, not to earn the stamp on its behalf. On
convergence the `unrefined` labels come off and `refined` goes on, leaving the epic
implement-ready for the loop.

### Report

Produce the summary using the template in **`references/report-template.md`** (convergence table, resolution breakdown, areas reviewed, health assessment).

**Commit the run report to `.claude/reviews/` root** (the standalone/mid-batch review
destination — same rule as any non-batch-close `ac-review` invocation). *Hygiene itself* **must
NOT** write to `.claude/reviews/batch/`: that directory is the review-mark, and under the
single-writer invariant (bd-kudrb) **only `ac-publish`'s Act 3 commit may touch it** — not
hygiene, not `ac-review`. A hygiene run on its own is not a batch close; writing there would
spuriously advance the review-mark and make the next standing-review-of-`main` skip real commits,
and a write landing mid-ceremony would be returned by the anchor probe as a commit inside its own
range (silent under-scoping). (When this run *did* land fixes and closes them through
`ac-publish`, the panel report is handed to that ceremony as its Phase 1 review artifact —
path (a) — staged in `.claude/reviews/pending/`, and `ac-publish`, not hygiene, carries it
into `.claude/reviews/batch/` in its Act 3 commit; advancing the mark is then correct, because a
batch genuinely shipped and was reviewed.)

**Headless run:** post the summary via `slack-send` — this is a MANDATORY step, not optional
polish (confirm exit 0) — then skip the question below and proceed to Cleanup.

**Present next step choice with `AskUserQuestion`:**

```
AskUserQuestion(
  questions: [{
    question: "Hygiene review complete ({CURRENT_ROUND} rounds, {fixed} fixed, {deferred} deferred). What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Done", description: "Review complete — no further action needed" },
      { label: "Run again", description: "Another hygiene pass — agents explore different files" },
      { label: "Address deferred items", description: "Work through the items that needed judgment" }
    ]
  }]
)
```

### Cleanup

Remove the temp artifacts directory (safe — always under /tmp):

```bash
find "$ARTIFACTS_DIR" -mindepth 1 -delete && rmdir "$ARTIFACTS_DIR" 2>/dev/null || true
```
