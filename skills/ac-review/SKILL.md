---
name: ac-review
description: 'Feature-branch code review — parallel 6-dimension panel (correctness/security/perf/architecture always + test-quality/contracts unless provably irrelevant), plus a 7th doctrine-delta lens gated on skills/ diffs, severity-based auto-fix + escalation. Triggers: ''review the branch'', ''work review'', ''code review this feature'', ''pre-merge review''.'
---


**You are the conductor.** A panel of up to seven reviewers hunts independently — the core four dimensions always, plus two diff-conditional lenses (test-quality, contracts), plus a 7th lens (doctrine-delta) that activates only when the diff touches `skills/`. You synthesize, auto-fix, and escalate. Feature-branch scoped — run after implementation, before merge.

For codebase-wide health checks, use `/ac-hygiene` instead.

---

## I/O Contract

|                  |                                                                                                            |
| ---------------- | ---------------------------------------------------------------------------------------------------------- |
| **Input**        | Feature branch with implementation commits (from `/ac-implement` or manual coding)                  |
| **Output**       | Review report in `.claude/reviews/` (default) or `.claude/reviews/pending/` (when `ac-batch-close` passes `report_dest` — staged for that ceremony to carry into the mark; **never** advances the review-mark itself), auto-fixed issues committed, NEEDS_DECISION items presented |
| **Artifacts**    | Reviewer findings in `$ARTIFACTS_DIR/round-1-*.json`, consensus in `consensus-round-1.json` + `consensus-registry.json`, progress in `progress.md` |
| **Verification** | All project checks pass (test, lint, type-check), fixes committed, decisions resolved or documented        |

## Prerequisites

- On `main` (primary, trunk-direct mode) — or on a branch listed in `.claude/legacy-branches.txt` (legacy mode)
- Implementation committed and pushed
- Project test/lint/type-check commands runnable

---

## Phase 0: Initialize

**MANDATORY FIRST STEP: Create task list with TaskCreate BEFORE starting.**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
```

### Configuration

```
# Mint RUN_ID if the orchestrator didn't hand one down (contract: _shared/run-id.md
# mint-if-absent rule) — keeps standalone and orchestrated runs on the same formula.
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"
# Timestamp-keyed, not branch- or claim-id-keyed: a review scopes a batch diff range since
# the last review-mark, not a single claimed batch, so it never had the trunk-direct
# branch-collapse problem (_shared/run-id.md § Prefixes).
ARTIFACTS_DIR=/tmp/work-review-$(date +%Y%m%d-%H%M%S)
```

```bash
mkdir -p "$ARTIFACTS_DIR"
echo "$ARTIFACTS_DIR"   # note the RESOLVED value — every later file write uses it literally
```

> **`$ARTIFACTS_DIR` is a variable, so every shell redirect into it is a dynamic-path write —
> the shape `dcg` blocks by design.** Produce files under it with the **Write tool on the
> resolved literal path** (or pipe into `tee <literal path>`), never a redirect or heredoc
> built from the variable (`_shared/shell-guardrails.md`). This is not style: a silently
> blocked write here is a silently degraded review downstream (bd-axeyx).

### Register Session Identity (Tier 1)

ac-review is a **Tier-1 session**: its Phase-4 auto-fix engineer edits product code and
Phase 6 commits + pushes. Mint a unique identity at review start so those fixes reserve
and commit under a real name instead of falling back to `FoggyCreek` (doctrine:
`_shared/agent-identity.md` — Tier 1 lifecycle: mint → reserve at work grain → release →
self-deregister). **Run the mint + token/export discipline per `_shared/agent-mail.md`
(§ Mint, § Export)** — capture `name` + `registration_token`; the reservation/release/
message calls below REQUIRE the token.

### Discover Project Commands

Read `AGENTS.md > Project Commands` for the project's toolchain. Map to workflow variables:

| Variable        | Source                              |
| --------------- | ----------------------------------- |
| `CMD_TEST`      | AGENTS.md > Project Commands > Test |
| `CMD_LINT`      | AGENTS.md > Project Commands > Lint |
| `CMD_TYPECHECK` | AGENTS.md > Project Commands > Type-check |
| `CMD_BUILD`     | AGENTS.md > Project Commands > Build |
| `CMD_FORMAT`    | AGENTS.md > Project Commands > Format |
| `CMD_QUALITY`   | AGENTS.md > Project Commands > Quality gate |

If AGENTS.md doesn't exist or is incomplete — i.e. the project is not the registry-standard Next.js/pnpm stack — read `references/stack-detection.md` and run its auto-detect probe.

If a command doesn't exist for this project, set it to empty and skip in validation phases.

### Create Workflow Tasks

```
TaskCreate(subject: "Phase 0: Initialize", description: "Discover commands, create tasks", activeForm: "Initializing review...")

TaskCreate(subject: "Phase 1: Gather context", description: "Branch safety, diff scope, plan context, baseline check", activeForm: "Gathering context...")

TaskCreate(subject: "Phase 2: Parallel review", description: "Assemble panel (core 4 + conditional test-quality/contracts), write manifest, spawn reviewers", activeForm: "Running parallel reviews...")

TaskCreate(subject: "Phase 3: Synthesize findings", description: "Dedup, consensus detection, severity-based auto-apply rules", activeForm: "Synthesizing findings...")

TaskCreate(subject: "Phase 4: Auto-fix", description: "Engineer sub-agent applies fixes, runs project tests", activeForm: "Applying auto-fixes...")

TaskCreate(subject: "Phase 5: Validation gate", description: "Run all discovered project checks", activeForm: "Running validation...")

TaskCreate(subject: "Phase 6: Commit report & fixes", description: "Generate review report, safety check, commit, push", activeForm: "Committing review...")

TaskCreate(subject: "Phase 7: Present decisions", description: "NEEDS_DECISION items via AskUserQuestion", activeForm: "Preparing decisions...")

TaskCreate(subject: "Phase 8: Final report + hand-off", description: "Summary, next step choice, cleanup", activeForm: "Generating final report...")
```

### Consensus Registry — owned by the script

No manual init. The Phase-3 consensus script (`scripts/consensus.py`) creates and maintains
`$ARTIFACTS_DIR/consensus-registry.json` — the cross-round memory of deferred single-reviewer
findings. Don't hand-keep a markdown table; the JSON registry is the source of truth.

### Compaction Recovery

If `$ARTIFACTS_DIR/progress.md` exists, parse its `### Phase N` entries to recover state. If
reviewer findings files (`round-*-*.json`) exist, skip to Phase 3 and (re-)run the consensus
script. `consensus-registry.json`, if present, already holds the deferred pool for cross-round
detection — the script reads it automatically.

**TaskUpdate(task: "Phase 0", status: "completed")**

---

## Phase 1: Gather Context

**TaskUpdate(task: "Phase 1", status: "in_progress")**

### Scope Detection (dual-mode, CRITICAL)

```bash
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
```

**On `main` (PRIMARY mode — trunk-direct):** scope is everything since the last
review-mark (the last commit that touched `.claude/reviews/batch/`):

> **`.claude/reviews/batch/` is written by EXACTLY ONE commit per ceremony — `ac-batch-close`'s
> Act 3 (bd-kudrb).** Your findings report goes to the sibling `.claude/reviews/pending/` (Phase 6
> § Report Destination), which this probe deliberately does not see. Never "helpfully" write into
> `batch/` from here: a second writer mid-batch makes this probe return a commit INSIDE the range
> it bounds and the batch silently under-scopes (one live case shrank a 7-commit batch to 2 and
> still reported success). **So this probe measures ACCEPTANCE, never coverage — what has actually
> been reviewed is Scan D's union of recorded `Range:` claims, `_shared/board-scan.md` (bd-zl1y5).**

```bash
REVIEW_MARK=$(git log -1 --format=%H -- .claude/reviews/batch/)

if [ -n "$REVIEW_MARK" ]; then
  DIFF_RANGE="$REVIEW_MARK..HEAD"
else
  # Bootstrap fallback: no batch review-mark exists yet
  LAST_TAG=$(git describe --tags --match 'v*' --abbrev=0)
  DIFF_RANGE="$LAST_TAG..HEAD"
fi

git diff $DIFF_RANGE --stat
git diff $DIFF_RANGE --name-only
```

**Standing weekly review of `main` — NOT ac-review's duty; it belongs to the weekly hygiene
run (plan C2).** If more than 7 days pass with no batch shipping (no new
`.claude/reviews/batch/` commit), the review of all of `main` since the last `v*` tag is driven
proactively by the weekly `ac-hygiene` `PANEL=full` run (its 7-lens panel IS that review) —
see `ac-hygiene/SKILL.md` § "When to Use This". ac-review owns only the *mechanism* for that
range (the bootstrap `DIFF_RANGE` above, `git describe --tags --match 'v*' --abbrev=0`), which
`ac-hygiene`'s close path and any standalone invocation reuse; it does not schedule or
self-trigger the standing review. Exactly one owner.

**On a branch (legacy mode):** read `.claude/legacy-branches.txt` (ignore blank lines
and `#`-comment lines):

```bash
LEGACY_FILE="$(git rev-parse --show-toplevel)/.claude/legacy-branches.txt"
IS_LEGACY=$(grep -vE '^[[:space:]]*(#|$)' "$LEGACY_FILE" 2>/dev/null | grep -Fx "$CURRENT_BRANCH" || true)
```

- **Listed** -> legacy scope, unchanged from pre-migration behavior:

  ```bash
  BASE_BRANCH=$(git merge-base --fork-point main HEAD 2>/dev/null && echo "main" || echo "master")
  DIFF_RANGE="$BASE_BRANCH...HEAD"
  git diff $DIFF_RANGE --stat
  git diff $DIFF_RANGE --name-only
  ```

- **Not listed -> HARD STOP.** Do not proceed, do not downgrade to a warning:

  ```
  ERROR: ac-review runs on main by default (trunk-direct migration). Branch
  "$CURRENT_BRANCH" is not in .claude/legacy-branches.txt. Either run the review on
  main (the primary mode) or add this branch to the allowlist if it genuinely needs
  legacy branch-relative review.
  ```

  Fire a Slack alert (`slack-send`) reporting the blocked branch, then STOP — never
  silently proceed or warn-only.

### Uncommitted Implementation Check

```bash
UNCOMMITTED=$(git diff --name-only | grep -v "^\.claude/" || true)

if [ -n "$UNCOMMITTED" ]; then
  echo "WARNING: Uncommitted implementation files detected!"
  echo "$UNCOMMITTED"
fi
```

If uncommitted files exist, ask user whether to commit them first or proceed reviewing only committed work.

### Load Plan Context (if exists)

```bash
ls -la _plans/*.md 2>/dev/null | head -5
```

If a plan exists, read it for success criteria, test specifications, and original requirements.

### Skill Routing

Scan changed files for domain keywords. Check `AGENTS.md > Available Skills` for relevant skills to include in reviewer prompts:

- DB/SQL/migrations -> database skills
- UI components/styling -> design-system skills
- React hooks/perf -> performance skills
- Security/auth -> security skills
- Tests -> testing skills

Include relevant skill paths in each reviewer prompt: `"Read .claude/skills/<skill>/SKILL.md for domain patterns."`

### Journey-Doc Sync Check (projects with CORE/journeys/)

If `.claude/skills/CORE/journeys/README.md` exists, compare the branch's
changed files against its "Mapping Changes to Journeys" table. For every
mapped path that changed, the matching journey doc should have been updated
in the same wave (journey docs are test artifacts — the QA agent validates
against them). Mapped UI change + untouched journey doc = a **finding**
(severity: medium), same class as a missing test update.

### Save Context

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Phase 1: Context

- **Branch:** {CURRENT_BRANCH}
- **Scope:** {DIFF_RANGE}
- **Changed files:** {count} files, {lines} lines
- **Plan:** {path or "none"}
- **Project commands:** {CMD_TEST}, {CMD_LINT}, {CMD_TYPECHECK}
- **Skills routed:** {list or "none"}
```

**TaskUpdate(task: "Phase 1", status: "completed")**

---

## Phase 2: Parallel Review

**TaskUpdate(task: "Phase 2", status: "in_progress")**

### Get Diff

```bash
git diff $DIFF_RANGE
```

### Diff Size Check

```bash
git diff $DIFF_RANGE --stat | tail -1
```

**If diff is very large (>2000 lines):** Ask user with `AskUserQuestion`:

```
question: "Large diff detected ({X} files, {Y} lines). How to proceed?"
header: "Scope"
options:
  - label: "Full review (Recommended)"
    description: "Review everything — may take longer"
  - label: "Key files only"
    description: "Review only the most critical files — suggest list"
  - label: "By directory"
    description: "Split into focused reviews per directory"
```

### Gather Project Context

Read project config files and `AGENTS.md` to build context for reviewers. Extract: framework, key dependencies, test framework, patterns used, language settings, architecture overview.

### Assemble the Panel

**Docs-only diff → docs-lens set (not the code four).** First check whether the diff
touches **only non-code paths** — every changed file under `_plans/`, `docs/`,
`references/`, or a bare `*.md`, with **zero** hits under `app|lib|scripts|supabase|features`.
If so, the code-shaped four (correctness/security/performance/architecture) do not apply;
spawn the **docs-lens set** from **`references/review-dimensions-docs.md`** instead —
**findings-integrity** (every claim cited), **consistency** (severity/priority/register
alignment, cross-doc contradictions), **discipline** (scope adherence — no fixes snuck into
a study/docs mission). Those lenses review the docs against **the org's own
documentation-standards skills** (`context-engineering`, `skill-builder`, the wiki/memory
doctrine) as their rubric source — declared standards, not improvised taste. Everything else
below (panel manifest, parallel spawn, consensus) works identically with the docs lenses
substituted for the code four. If the diff has ANY code, use the standard panel:

The panel is the six dimensions in **`references/review-dimensions.md`**. The **core four**
(security, performance, architecture, correctness) ALWAYS spawn. The two diff-conditional
lenses use **negative gating** — spawn by default, skip only when provably irrelevant:

- **test-quality** — skip ONLY if the diff contains zero test files AND zero runtime
  source (a docs/CI-only diff).
- **contracts** — skip ONLY if the diff touches no exported surface (no type/interface
  files, route handlers, exported function signatures, or docs).

Two cheap checks against the Phase-1 changed-file list. When in doubt, **spawn** — a
wasted reviewer costs one agent; a wrongly skipped lens is a silent coverage gap.

### Doctrine-Delta — the 7th, skills/-gated dimension

**Positive-gated — the inverse of test-quality/contracts above: SKIP unless the diff
touches any `skills/**` file.** Check the same Phase-1 changed-file list — zero paths
matching `skills/` -> skip this dimension entirely (a normal app review, or even a
docs-only review of non-skill docs, is unaffected). Any path matching `skills/` -> spawn
it as a 7th body **in addition to** whichever panel this phase already assembled (the
code four + conditional two, or the docs-lens set on a docs-only diff) — it stacks on
either, it never replaces a lens.

- **ROLE:** `doctrine-delta`
- **SKILL_HINT:** `Read skills/skill-builder/references/promotion-ladder.md,
  skills/skill-builder/references/friction-capture.md, and
  skills/skill-builder/workflows/hygiene-pass.md for the doctrine this dimension enforces.`
- **EVIDENCE:** The added block, its evidence stamp (or absence), and — for reintroduced
  content — the `git log -S "<snippet>"` churn hit proving it was cut before.
- **SKIP:** Unless the diff touches `skills/**` — spawn only then (gate above).

**METHOD:**

Three checks, each a promotion-ladder rule made adversarial:

1. **Proof-or-demotion citation.** Every content block ADDED to a SKILL.md's tier-1 core
   (not `references/`, not `workflows/`) must carry an evidence stamp
   (`<!-- evidence: <N green runs | probe-fact | Craig sign-off> -->` — the
   promotion-ladder's proof gate) OR the same diff carries a matching demotion — an
   equal-or-greater shrink elsewhere in that SKILL.md, or a `references/` file gaining
   the demoted content. No stamp and no demotion = a finding. A stamp citing a
   run/probe/sign-off that can't be verified as real is a separate finding — the gate
   verifies form, not truth; this dimension is the judgment backstop.
2. **No reintroduced historical blocks.** The diff doesn't re-add struck-through,
   deprecated, superseded, or holding-zone-quarantined content the registry has been
   purging. Check `git log -S "<snippet>"` (the churn guard from `hygiene-pass.md` A2)
   for any block that was cut before — a match is a finding regardless of rewording.
3. **No-net-growth / ceiling respect.** Net SKILL.md line growth across the diff needs
   the same evidence-or-demotion justification as check 1 (mirrors `lint.sh`'s
   no-net-growth gate) — this dimension judges whether the cited stamp is genuine and
   the content actually earns tier-1 core rather than `references/`. For a
   conductor-core skill, growth with no Craig sign-off notice (pre-mint) or that
   exceeds its minted ceiling (post-mint, per `promotion-ladder.md`) is a finding even
   with a stamp present.

**CHECKLIST:**

- Added SKILL.md core content with no evidence stamp and no offsetting demotion
- Evidence stamp present but citing a run/probe/sign-off that can't be verified as real
- Re-added content matching a prior `git log -S` cut (deprecated/historical/superseded block)
- Net SKILL.md line growth with no evidence-or-demotion justification
- Conductor-core skill growth exceeding its minted ceiling, or missing sign-off pre-mint

**SLUGS:** `missing-promotion-evidence`, `false-evidence-stamp`,
`reintroduced-historical-block`, `unjustified-net-growth`, `conductor-ceiling-breach`

### Panel scaling (ZERO-RUNTIME + no RISK-TOUCH — bd-chd5p.8 / Item 6a)

Body count may shrink **only** when classification proves the batch is safe. Keys on
**files touched** via `_shared/risk-classification.md` (ZERO-RUNTIME allowlist + no
RISK-TOUCH after test-path exclusion) — **never** on a self-declared
"doc/test/methodology" batch label. The run's Criticals were all on batches that
self-labeled low-risk; a label-keyed shrink would have let them through.

**Classifier (binding — Item 0):**

```bash
# DIFF_RANGE from Phase 1 scope detection
git diff --name-only $DIFF_RANGE
# Then apply risk-classification.md: RISK-TOUCH globs + test-path exclusion +
# ZERO-RUNTIME positive allowlist. Shrink-eligible ONLY if EVERY path is
# ZERO-RUNTIME AND no path is RISK after exclusion.
```

**Panel-scaling table — retained dimensions per tier:**

| Tier | Condition | Bodies | Dimensions retained |
| ---- | --------- | ------ | ------------------- |
| **Full (default)** | any RISK-TOUCH hit **OR** any non-ZERO-RUNTIME / runtime-source change | up to 6 | **core four** (security, performance, architecture, correctness) **ALWAYS** + test-quality + contracts (negative-gating skip rules above still apply) |
| **Shrink** | ZERO-RUNTIME **AND** no RISK-TOUCH (proved by `git diff --name-only`) | 2–3 | **core four still covered** (may share bodies; fewer bodies never silently drop a dimension) |
| **test-quality dedicated** | ANY test file present in the diff (`**/__tests__/**` or `**/*.{test,spec}.*`) | +1 body | **test-quality is its own dedicated body** — never merged into another body. The reduced-motion Critical was caught by a test-quality body tracing a self-defeating e2e; that probe does not survive a merged body. |

**Doctrine-delta stacks independently of this table** — its `skills/`-touch gate above
decides spawn/skip regardless of risk tier; it is not one of the panel-scaling
shrink/full tiers and is never dropped by a shrink.

**Rules (non-negotiable):**

1. **Core four ALWAYS** — fewer bodies never silently drop security / performance /
   architecture / correctness (this section's baseline rule at ~core-four ALWAYS).
2. **Any RISK-TOUCH hit, OR any runtime-source change → full 6-dimension panel, no
   shrink, ever.**
3. **test-quality is its own dedicated body whenever ANY test file is present** —
   even on a shrink-eligible ZERO-RUNTIME batch.
4. **GUARD-RAIL:** batch is shrink-eligible only if `git diff --name-only` proves
   ZERO-RUNTIME + no RISK-TOUCH per `_shared/risk-classification.md`. When in doubt,
   full panel.

**Write the panel manifest BEFORE spawning** — the Phase-3 consensus script validates
against it (a spawned dimension with no output = partial failure, never a silent pass), and
**refuses to run at all without it** (exit 3, `PANEL UNKNOWN`) rather than defaulting to a
smaller panel. This write is therefore load-bearing, not bookkeeping: when it was silently
eaten by a `dcg` block on 2026-07-31, the run fell back to the core four and dropped the
contracts and test-quality findings — one of them Critical (bd-axeyx).

<!-- net-growth-ok: bd-axeyx — the manifest write IS the control whose silent dcg-block degraded
     a live panel; the "how to write it so the guard accepts it" instruction has to sit AT the
     write site, and the exit-3 contract at the consensus call site. A reference-file pointer is
     what failed here: `_shared/shell-guardrails.md` already documented the fix and the inline
     snippet contradicted it. -->
**Use the Write tool, on the resolved literal path** — do NOT shell-redirect into
`$ARTIFACTS_DIR`. A heredoc or redirect whose target is built from a variable is exactly the
shape `core.filesystem:redirect-truncate-dynamic-path` blocks, and this snippet is the one
that got bitten (`_shared/shell-guardrails.md` § Sanctioned shapes). Echo `$ARTIFACTS_DIR`,
paste its resolved value into the Write call, and confirm the file exists before spawning.

Write `<resolved ARTIFACTS_DIR>/panel-round-1.json` with this content:

```json
{"round": 1,
 "spawned": ["security", "performance", "architecture", "correctness", "test-quality", "contracts"],
 "skipped": {}}
```

List only the roles you actually spawn; record each skipped lens in `skipped` with its
one-line reason (e.g. `"contracts": "no exported surface in diff"`). Add `"doctrine-delta"`
to `spawned` only when the diff touches `skills/**` (per its gate above); otherwise record
it in `skipped`, e.g. `"doctrine-delta": "no skills/ paths in diff"` — this keeps
`consensus.py`'s manifest-driven expectation accurate either way.

### Spawn the Panel Simultaneously

**CRITICAL: All spawned agents run IN PARALLEL using a single message with one Task call per dimension.**

Build each reviewer's prompt from **`references/reviewer-prompt-template.md`**, filling the placeholders from that dimension's row in **`references/review-dimensions.md`** — including `{METHOD}`, the dimension's hunting doctrine. For `doctrine-delta` (when spawned), fill the same placeholders from this file's **§ Doctrine-Delta — the 7th, skills/-gated dimension** above instead — it isn't in `review-dimensions.md` since it never applies to a non-skill diff. Substitute `{DIFF}` (the Phase-2 diff), `{ARTIFACTS_DIR}`, `{ROUND}` (`1` here), and `{N_OTHERS}` (spawned count minus one) into each.

- Each agent writes **JSON** to `$ARTIFACTS_DIR/round-1-{role}.json` (`round-1-security.json`, …) — machine-read by the Phase-3 consensus script, so the schema in the template is load-bearing.
- Include a dimension's `SKILL_HINT` line only if Phase-1 skill routing found a relevant skill.
- Competitive framing, the finding format, and limits (top 7, skip Low) are baked into the template — don't restate them.
- The `test-quality` reviewer runs probes (rerun/shuffle/sabotage) in its own disposable worktree — its prompt carries the isolation discipline; it never mutates the shared branch.

**Wait for all spawned reviewers to complete.** Bound the wait per
`_shared/delegation-contract.md`: a reviewer that returns nothing (died on a terminal API
error, or its resume chain broke) is a **failure to re-spawn or report**, not a silent pass —
verify a `round-1-{role}.json` exists for every manifest-listed role before synthesizing;
missing output ≠ "no findings." **When the RE-spawn keeps failing too (529/rate-limit/timeout), or you never had `Task` at all, stop retrying and read `_shared/degraded-mode.md` — it owns the bounded full-panel→smaller-panel→solo ladder and the `Degraded:` report field that keeps a solo verdict distinguishable from a panel one (bd-nreuv).**

**TaskUpdate(task: "Phase 2", status: "completed")**

---

## Phase 3: Synthesize

**TaskUpdate(task: "Phase 3", status: "in_progress")**

**THIS IS YOUR CORE WORK. Do not delegate synthesis.**

### Run Deterministic Consensus

The mechanical synthesis — dedup, same-round + cross-round consensus, the severity/consensus
auto-apply cascade, and partial-failure detection — runs in **code**, not prose, so consensus
can't be hallucinated over markdown. It implements `_shared/review-consensus.md`:

```bash
CONSENSUS="$(git rev-parse --show-toplevel)/.claude/skills/ac-review/scripts/consensus.py"
python3 "$CONSENSUS" --artifacts-dir "$ARTIFACTS_DIR" --round 1   # --round 2 for a Phase-5.5 round
```

It reads the `round-1-{role}.json` reviewer files, writes `consensus-round-1.json` + updates
`consensus-registry.json` (the cross-round memory — no manual table-keeping), and prints a
summary. Harness-agnostic: plain `python3`, stdlib only.

**Exit 3 = `PANEL UNKNOWN` — a hard stop, not a warning.** The script found no usable
Phase-2 panel manifest and **refuses to substitute a default panel**, because a check that
cannot state its own scope has not checked anything it can attest to; `unknown` never
collapses to `ok` (same doctrine as `_shared/board-scan.md` Scan E). Do NOT re-run with
`--expect` to make it go green — go back to Phase 2, write the manifest with the Write tool
on the literal path, confirm it exists, and re-run. If the panel genuinely cannot be
reconstructed, emit **`VERDICT: NEEDS_DECISION`** and say the panel was unconfirmable.

**Read the result (`consensus-round-1.json`) and act on each field:**

- **`panel_source` + `reviewers_expected` + `panel_skipped` → the denominator. Copy them
  verbatim into the report's `**Panel:**` line (Phase 6).** A degraded run must be visible
  after the fact, so the panel that ACTUALLY ran is reported, never the panel that was
  intended.
- **`reviewers_missing` non-empty → partial failure.** A missing dimension is the silent-PASS
  trap — never auto-fix-and-approve around it. **Retry once:** re-spawn the missing reviewer(s)
  (Phase 2, same `{ROUND}`) and re-run consensus. **If still missing:**
  - *Autonomous (`ac-loop`) run:* this is a **blocker** — `br create -t bug --labels qa-blocker`
    for the un-reviewed dimension, and emit **`VERDICT: NEEDS_DECISION`** (never `APPROVED`).
    The loop must not merge a wave a review dimension never saw.
  - *Interactive run:* surface the gap and let the user decide whether to proceed.

  A reviewer that emits malformed JSON degrades to this same path (the script's per-file
  parse-guard counts it as missing) — so ignoring the schema can never silently pass.
- **`auto_fix`** — the cascade is already applied (severity Critical/High, same-round consensus,
  or cross-round consensus). These go to Phase 4 as-is — with ONE conductor check:
  a **performance** finding rated Critical/High whose evidence carries no quantified
  impact estimate (N × unit cost weighed against the operation's real budget) is
  DOWNGRADED to Medium and re-routed through the deferred/design-decision gate, with
  the downgrade noted in the report — perf severities are the least grounded (reviewers
  pattern-match allocation/loop shapes without estimating magnitude; incident:
  `references/incidents.md`). Correctness/security severities are not subject to this check.
- **`deferred`** — single-reviewer Medium/Low, no consensus; the script has already carried them
  into `consensus-registry.json` for cross-round matching. **Apply the design-decision gate
  yourself** — the one judgment the script can't make: a choice with no objectively superior
  answer → pick the better option and move it into the change list; defer as `DESIGN_DECISION`
  (→ user in Phase 7) only if it **noticeably affects end-user experience** or **profoundly
  changes the development approach**. Minor choices (spacing, naming, style) → just pick the better one.
  <!-- mirror: _shared/review-consensus.md §Design-decision gate — edit there first -->

### Verdict comment (VERDICT grammar)

The consensus `VERDICT:` line is this review ceremony's verdict — record it on the
reviewed bead(s) as a structured comment per **`beads-standards` § Verification verdicts**
(exact CLI: `br comments add <id> "VERDICT: passed: <detail>"` — plural `comments`
subcommand only; do not invent a singular verb):
`VERDICT: passed:` for a clean `APPROVED`, `VERDICT: failed:` when the panel surfaced a
merge-blocking finding (`VERDICT: blocked:` for a `NEEDS_DECISION` partial-failure gate).
Review is a *verifier* ceremony — the panel/conductor writes the verdict, never the
implementer whose diff is under review (Goodhart guard). Every finding bead filed here
carries the `review-finding` catch-stage label **and** `discovered-from: <bead-id|unknown>`
linking it to the work that introduced the defect. When such a finding is later closed, its
`close_reason` cites the per-type evidence (`bug` → regression test, etc.) per
`_shared/bead-conventions.md` § Per-type close artifacts.

### Produce Numbered Change List

From the script's `auto_fix` plus any `deferred` items you resolved: target file, what to
change, severity, which reviewers flagged it (`reviewers`), auto-fixable or not. This is Phase 4's input.

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Phase 3: Synthesis

- **Total findings:** {count} ({Critical} Critical, {High} High, {Medium} Medium)
- **After dedup:** {count}
- **AUTO_FIX:** {count} (severity-based: {N}, consensus-based: {M})
- **NEEDS_DECISION:** {count}
- **Consensus areas:** {where reviewers agreed}
```

**TaskUpdate(task: "Phase 3", status: "completed")**

---

## Phase 4: Auto-Fix

**TaskUpdate(task: "Phase 4", status: "in_progress")**

### Correlated-Failure Escalation (LCA Repair — check BEFORE per-bead patching)

Before dispatching per-bead fixes, ask whether the findings are **correlated** — a
higher-leverage repair than patching each bead in isolation (ATG, arXiv 2607.01942).

**Detection rule.** Findings are *correlated* when **2 or more beads** in this batch fail
review/validation and share a **single root cause** — the same wrong assumption, contract, or
shared-parent decomposition error, not merely the same file. Signals: identical/near-identical
finding text across beads; failures all trace to one shared spec, type, or interface the parent
epic/plan defined; fixing one bead's symptom would obviously re-appear in its siblings.

**Escalation path (repair the parent once, not the children N times).** On a correlated
cluster:
1. Trace the failing beads to their **lowest common ancestor (LCA)** in the decomposition — the
   shared epic or plan node they were split from (walk `## Consumes` / dependency edges and the
   `discovered-from` / epic parent up to the first node they all descend from).
2. Escalate the fix to that parent: emit **`VERDICT: NEEDS_DECISION`** with a note routing the
   LCA node back to `/ac-bead-refine` (re-decompose the parent) rather than queuing N per-bead
   AUTO_FIX items. Repair the decomposition **once**, then regenerate the affected subgraph.
3. Do **not** hand-patch the correlated symptoms here — per-bead patches around a shared-parent
   defect leave the decomposition wrong and the bug re-emerges on the next bead off that parent.

**Frozen-region rule.** A parent-level repair **never reopens closed + verified beads**. Beads
already `closed` with delivered artifacts are frozen; the regeneration touches only the
still-open subgraph under the repaired LCA. Use the frozen beads' **`## Delivers` / downstream
`## Consumes`** lines to identify exactly what must be **re-checked** (not re-implemented): any
open bead consuming a frozen bead's artifact is re-verified against it after regeneration; the
frozen bead itself stays closed.

Uncorrelated findings (single-bead root cause) fall through to the normal per-item flow below.

### If No AUTO_FIX Items

Skip to Phase 5.

### If AUTO_FIX Items Exist

**Reserve the AUTO_FIX file list first (Tier 1).** The numbered change list from Phase 3
names every file the fix engineer will touch — reserve them at the work grain BEFORE
spawning the engineer, so a concurrent invocation sees them as held mid-fixup. Held until
released after the Phase 6 commit:

```
mcp__mcp-agent-mail__file_reservation_paths(
  project_key: CANONICAL_PROJECT_KEY,   // canonical "neometa/<app-dir>" key — key-format + never-absolute rule: _shared/agent-identity.md § Project key format
  agent_name: AGENT_NAME,               // the Tier-1 name minted in Phase 0
  paths: ["<every file in the AUTO_FIX numbered change list>"],
  ttl_seconds: 7200,
  exclusive: true
)
```

Spawn engineer with the AUTO_FIX list, using the prompt in **`references/engineer-fix-prompt.md`** with the Phase-4 `INTENT` ("Apply these fixes exactly as specified. Do NOT modify NEEDS_DECISION items.") and the `## Output` block kept (the result file is read back below).

### Verify Fixes

Read the engineer's result file. Confirm:
1. All AUTO_FIX items applied (or documented why not)
2. Project checks pass
3. No unintended side effects (review diff)

**If checks fail:** Revert the breaking fix and move that item to NEEDS_DECISION.

**TaskUpdate(task: "Phase 4", status: "completed")**

---

## Phase 5: Validation Gate

**TaskUpdate(task: "Phase 5", status: "in_progress")**

Run the cheap checks always; scale the **expensive** ones (full test, build) to the diff's
risk using the shared classifier in `_shared/verification-gate.md` (Step 1) — ac-review is a
branch review, **not** the green-main boundary (the exhaustive full-suite run is loop-close CI;
rationale: `references/incidents.md`).

```bash
{CMD_FORMAT}    # always (cheap)
{CMD_LINT}      # always (cheap)
{CMD_TYPECHECK} # always (cheap)
```

Then, by diff class (from the classifier):
- **`CLASS_RUNTIME` unset** (docs / tests / CI only) → skip `{CMD_TEST}` and `{CMD_BUILD}`; cheap checks suffice.
- **Runtime code, normal risk** → `{CMD_TEST}` (affected/standard); skip `{CMD_BUILD}` unless the wave touches build config or `CLASS_WEBUI`.
- **High-risk** (migration/`.sql`, auth, payments, release/version — the gate's high-risk row) → `{CMD_TEST}` scoped to the risk surface (never the full suite — that's the loop-close CI run) + `{CMD_BUILD}`.

**If all selected checks pass:** Continue to Phase 6.

**If any fail:**
- Fix the issue (small fixes directly, larger ones via engineer sub-agent)
- Re-run the failing command
- Only proceed after all pass OR user explicitly says "skip validation"

**TaskUpdate(task: "Phase 5", status: "completed")**

---

## Phase 5.5: Optional Convergence Round

**Only offer this if auto-fixes touched Critical or High issues.** Fixes are unverified until fresh reviewers confirm no new issues emerged.

```
AskUserQuestion(
  questions: [{
    question: "Auto-fixes touched {N} Critical/High issues. Run a verification round?",
    header: "Convergence",
    multiSelect: false,
    options: [
      { label: "Run verification round (Recommended)", description: "Spawn reviewers again to confirm fixes didn't introduce new issues" },
      { label: "Skip — trust the fixes", description: "Proceed to commit without re-review" }
    ]
  }]
)
```

**If verification round:** Re-run Phase 2-5 with the updated diff, re-applying the panel skip rules and writing a fresh `panel-round-2.json` manifest, spawning reviewers with `{ROUND}` = `2` so they write `round-2-{role}.json`. Include in reviewer prompts: "Previous round found and fixed: {list}. Check if fixes are correct and look for NEW issues only." Max 2 total rounds. In Phase 3, run `consensus.py --round 2` — it reads `consensus-registry.json` and auto-applies any finding that matches a prior-round deferred entry (cross-round consensus), with no manual registry-checking.

---

## Phase 6: Commit Report & Fixes

**TaskUpdate(task: "Phase 6", status: "in_progress")**

### Report Destination

Three destinations, and **none of them is `.claude/reviews/batch/`** (bd-kudrb). None advancing the mark does **not** mean none counts: all three are read by `_shared/board-scan.md` Scan D, so a root-dir report is full-weight review *coverage* — provided it carries a machine-parseable `**Range:**` line (bd-zl1y5).

| Invocation | Destination | Advances the review-mark? |
|---|---|---|
| Standalone / mid-batch (default) | `.claude/reviews/` root | No |
| `ac-batch-close` (passes `report_dest`) | `.claude/reviews/pending/` | No — `ac-batch-close`'s Act 3 carries it into `batch/` and THAT commit is the mark |
| `ac-publish` (passes `report_dest`) | `.claude/reviews/publish/` | No |

```bash
REPORT_DEST="${report_dest:-.claude/reviews/}"
# `pending/` (and `publish/`) may not exist yet in a repo that has only ever used the
# batch/ + root destinations — create it rather than failing the write (bd-kudrb).
mkdir -p "$REPORT_DEST"
```

Callers pass the destination via the delegation prompt, e.g. `report_dest=.claude/reviews/pending/`.

> <!-- net-growth-ok: bd-kudrb — this skill is the WRITER whose misrouted report caused the
> silent under-scoping; the prohibition has to sit at the write site, and the destination table
> replaces prose that only described two of the three real destinations. -->
> **Never write to `.claude/reviews/batch/` from this skill — not even when a caller asks you
> to (bd-kudrb).** That directory is the trunk-direct review-mark, and the anchor probe
> (`git log -1 --format=%H -- .claude/reviews/batch/`, used by `ac-batch-close` Act 1,
> `ac-loop` scope detection, `_shared/verification-gate.md`, and this skill's own Phase 1)
> takes the LATEST commit touching it. ac-review runs BEFORE `ac-batch-close` computes its
> anchor, so a report committed there mid-batch is returned as the anchor — a commit inside
> the range it is meant to bound. This bit four ceremonies in one day; each time only a
> hand-supplied step-back to the prior batch-close mark prevented a silently under-scoped
> batch. If a delegation prompt still says `report_dest=.claude/reviews/batch/` (a stale
> caller), write to `.claude/reviews/pending/` instead and say so in your summary.

### Generate Review Report

Create `${REPORT_DEST}YYYY-MM-DD-HHMM-[feature].md` using the template in **`references/report-template.md`** (summary table by category + auto-fixed + needs-decision + all findings). **The `**Range:**` line is MANDATORY and machine-parsed — full 40-char SHAs, `<base>..<head>`, no prose: an artifact without it is invisible to Scan D's coverage probe, i.e. the commits you just reviewed still read as unreviewed (bd-zl1y5).** **The `**Panel:**` line is equally MANDATORY and is copied verbatim from `consensus-round-{N}.json` (`panel_source` / `reviewers_expected` / `panel_skipped`) — the panel that actually ran, never a hardcoded list: that is what makes a degraded run visible after the fact (bd-axeyx).**

### Safety Check

```bash
git status --short
```

**If ANY deletions (D):** STOP and ask "About to delete {N} files. Is this intentional?" Wait for confirmation.

### Commit

```bash
export AGENT_NAME=<minted-name>   # re-assert inline — exports don't survive across bash calls; the pre-commit guard reads this
git add "${REPORT_DEST}YYYY-MM-DD-HHMM-[feature].md"
git add <files modified by auto-fixes>
git commit -m "$(cat <<'EOF'
review: [feature] - {N} issues fixed, {M} need decision

Auto-fixed: {count} ({Critical} Critical, {High} High, {consensus} consensus)
Needs decision: {count}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

**Release the AUTO_FIX reservation** — the auto-fix files are committed; release the same
paths reserved before Phase 4 so parallel sessions aren't starved (the Phase-0 identity is
deregistered later, in Phase 8):

```
mcp__mcp-agent-mail__release_file_reservations(
  project_key: CANONICAL_PROJECT_KEY,
  agent_name: AGENT_NAME,
  paths: ["<same paths passed to file_reservation_paths before Phase 4>"]
)
```

> **If the commit failed:** do NOT release reservations — the files still need work. Fix the
> commit, then release after a verified commit.

**TaskUpdate(task: "Phase 6", status: "completed")**

---

## Phase 7: Present Decisions

**TaskUpdate(task: "Phase 7", status: "in_progress")**

### Collect All Remaining Items

Combine two categories:

1. **NEEDS_DECISION items:** Non-auto-fixable findings that need judgment
2. **No-consensus findings:** Read the consensus registry — single-reviewer findings that never achieved cross-round consensus

### If Nothing Remains

Report auto-fix results and skip to Phase 8.

### Conductor Final Review (Triage)

**You (the conductor) now review each remaining item and classify it:**

| Category | Criteria | Action |
|---|---|---|
| `AUTO_IMPLEMENT` | There is a clearly superior technical answer — better correctness, robustness, performance, or maintainability. The improvement is unambiguous. | Implement it now. |
| `DESIGN_DECISION` | No objectively superior answer AND the choice would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and classify as `AUTO_IMPLEMENT`. | Defer to user. |
| `SCOPE_ESCALATION` | A technically superior option exists but requires profound structural change (new abstractions, large refactors, architectural pivots) that constitutes a strategic commitment. | Defer to user with scope context. |

**Default bias: `AUTO_IMPLEMENT`.** Most findings have a correct answer — pick it. Only classify as `DESIGN_DECISION` when you genuinely cannot determine a superior option on engineering merit AND the impact is user-visible or development-transformative. Only classify as `SCOPE_ESCALATION` when the blast radius is transformative, not merely "more work."
<!-- mirror: _shared/review-consensus.md §Conductor triage — edit there first -->

### Apply AUTO_IMPLEMENT Items

Spawn engineer for all `AUTO_IMPLEMENT` items using **`references/engineer-fix-prompt.md`** with the AUTO_IMPLEMENT `INTENT` ("each has been validated by the conductor as a clear technical improvement"). The `## Output` block is optional here — the conductor commits directly below.

Log each with rationale: why this is a clear technical improvement, not a design choice.

### Present Decisions to User (if any)

**If no DESIGN_DECISION or SCOPE_ESCALATION items remain:** Skip to commit.

**Exhaust rule (see `skills/_shared/bead-conventions.md`): nothing actionable leaves
this phase as prose.** Route by type before (or instead of) asking — confirmed defect,
out of this wave's scope → `br create -t bug --labels review-finding,unrefined`;
plausible-but-unverified concern an agent could chase → `br create -t investigation
--labels review-finding,unrefined`; genuine taste/product/risk fork → `decision` (mechanics
below). **ANCHOR DEDUPE — keyword search is not enough.** Before `br create`, take the finding's
primary `file:line` anchor and check whether an OPEN bead already carries it
(`br list --status open --limit 0 --json`, grep the descriptions for the path). Same file + same
symbol/line-range + same defect → **`br comments add` on the existing bead instead of creating a
second one**, and say it recurred. This mirrors `_shared/disposition.md` § Dedupe-before-filing,
which already governs skill-improvement beads — same rule, wider scope. Two reasons it matters:
parallel panels cannot see each other, so the same defect gets filed twice from one run (measured
2026-08-01: the identical `--conditions=react-server` gap for the same five scripts, filed the same
day by two sibling reviews); and **recurrence is the corroboration signal the auto-fix cascade runs
on** — a second sighting recorded as a comment promotes the finding, while a second sighting
recorded as a new bead just inflates the board and loses the evidence. Nits stay in the report.
**SEVERITY FLOOR — a Low-severity finding NEVER gets its own bead:** roll ALL of a run's Low findings into ONE rollup bead (one per run, `-t task --labels review-finding,unrefined`, each item a titled paragraph naming its file:line + the report it came from), and split an item out only if it later grows.
**ROLLUP CEILING — Low ONLY; Medium and above NEVER roll up.** One Medium+ finding = one bead. A
rollup is indivisible: it cannot be partially closed, partially prioritised, or partially drained,
so a `KEEP` on it says nothing about the items nobody checked. Measured 2026-08-01: 7-, 9- and
11-item Medium rollups reached triage where only 2 items could be verified and the other 9 rode
along unexamined under one id. If a set of Medium+ findings genuinely belongs together, group them
as an **epic with one child per finding** (`br dep add -t parent-child <finding-id> <epic-id>`) —
cohesion without indivisibility. The Low floor above is the deliberate exception: those are cheap
enough that board noise costs more than tracking precision buys, which is not true of Medium+. N separate P3 beads cost more board noise than they buy in tracking precision, and the finding lane inflates monotonically because nothing prunes it (bd-8ms5t: 55 open findings on 07-22, 102 by 07-30). Proven 2026-07-29: 9 Low findings from one review, one bead. **Always include
`unrefined`** (matches `ac-hygiene`) so the raw bead routes through `ac-bead-refine`
instead of being treated as already-refined. **`-t bug` = shipped product defect only;
test-gaps / missing coverage / infra findings use `-t task` or `-t investigation`, never
`-t bug`** — mistyping inflates the preemptive bug lane. **Every finding bead ships a
`## Test Scope` section with grep-verified anchors** (same bar as `ac-hygiene`;
`_shared/bead-conventions.md` §Body template): name the real file(s)/describe block(s) a
validator runs — grep each before citing it — plus the QA modality for user-facing surfaces.
You have the diff open right now; refine's Test Scope gate would otherwise author it cold.
A finding bead with no test plan is how the fix ends up shipping behind a test that cannot
fail (bd-mfr1d, bd-ghj12 — 2026-07-30).

> **Route the finding bead to an epic parent + stamp `post-merge` at creation** (§3 routing
> map, `_shared/bead-conventions.md` § Bead routing + § Claim semantics). Every
> `review-finding` bead created here is in-loop exhaust filed inside the batch's
> verify→review→close window, so on creation:
> 1. **Epic parent (§3 routing):** parent = **the epic whose beads were in the batch under
>    review**. If the batch **spanned epics**, route per-finding by **file/scope** (the epic
>    owning the file the finding lands in). If no batch epic applies, **fall back to a
>    per-run review epic** (`br create -t epic "ac-review <date> — findings"`, created once
>    per run, reused for the rest). Wire it: `br dep add -t parent-child <finding-id> <epic-id>` — the `-t` is **MANDATORY** (`br dep add` defaults to `-t blocks`, and a `blocks` edge with an epic endpoint is an I2 violation that makes the finding read as BLOCKED in `br ready`).
> 2. **`post-merge` at creation:** `br label add <finding-id> post-merge` — the finding was
>    filed before its parent batch merged, so the literal label keeps `beads-closed-gate.sh`
>    from counting it as a genuinely-open in-scope bead and blocking the batch's own close.
>    Stripped at the next claim (the strip-at-claim half of the lifecycle).
>
> This is additive: the `review-finding`, `unrefined`, and `discovered-from: <bead-id|unknown>`
> labels/linkage (above) are UNCHANGED — parent + `post-merge` are wired on top of them.

**Default (including all autonomous/headless runs): apply the Exhaust Rule.** Create a `decision` bead for each remaining item — do NOT ask:

```bash
br create -t decision --labels "human-gate,review-finding" \
  -t "DESIGN_DECISION: <title>" \
  --description "Context: <finding>\nOptions: <A vs B>\nRecommendation: <agent pick>"
# Block any downstream wave beads on it:
br dep add <downstream-bead-id> <decision-bead-id>
```

> **The `human-gate` label is MANDATORY at filing, not optional** (memory
> `decision-beads-need-human-gate-label-at-filing`; `beads-standards` § human-gate).
> `issue_type=decision` alone gates NOTHING — every label-keyed gate (bug-lane drain,
> beads-closed-gate, cleaning passes) keys on the LABEL. A `DECISION:`/`DESIGN_DECISION:`-titled
> or `decision`-typed bead created WITHOUT `human-gate` sits silently workable and can be
> auto-closed around the human. Do not hand-roll a `br create` that drops it. This has recurred
> 14+ times across sessions despite the template being correct — `ac-bead-refine`'s Phase 5
> title/label parity check (bd-7fqgi seam 2) is the backstop that catches any that still slip
> through, but the fix belongs here at the producer.

Then continue to Phase 8 — the loop runs on, the decision bead surfaces via `ac-human-session` when Craig reviews the docket.

**Only use AskUserQuestion when explicitly in an interactive session** (human is present at the terminal, NOT a scheduled or headless run):

```
AskUserQuestion(
  questions: [{
    question: "Auto-applied {N} fixes (severity + consensus + technical triage). {M} items need your decision:",
    header: "Decisions",
    multiSelect: true,
    options: [
      { label: "Fix A: <title>", description: "DESIGN_DECISION — {severity} — {reviewer}: {file}: {one-line summary}" },
      { label: "Fix B: <title>", description: "SCOPE_ESCALATION — {severity} — {reviewer}: {file}: {one-line summary}. Scope: {what the change entails}" }
    ]
  }]
)
```

**If more than 4 items:** Split across multiple `AskUserQuestion` calls (interactive only).

### Apply User-Approved Fixes

Spawn engineer for approved items using **`references/engineer-fix-prompt.md`** with the user-approved `INTENT` ("Apply these changes based on user decisions").

### Commit All Fixes

```bash
export AGENT_NAME=<minted-name>   # re-assert inline (Phase-0 identity) — exports don't survive across bash calls
git add <specific files>
git commit -m "$(cat <<'EOF'
review: implement fixes + decisions for [feature]

Auto-implemented (conductor triage): {count}
User decisions applied: {count}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

**TaskUpdate(task: "Phase 7", status: "completed")**

---

## Phase 8: Final Report + Hand-Off

**TaskUpdate(task: "Phase 8", status: "in_progress")**

> **VERDICT gate.** Emit `VERDICT: APPROVED` only if **every** holds: the last consensus run had
> `reviewers_missing` empty (every manifest-listed dimension reviewed, after at most one retry), all `auto_fix`
> items were applied and the validation gate passed, and no open `qa-blocker`/blocking decision
> bead remains. Otherwise emit `VERDICT: NEEDS_DECISION` — `ac-loop` stops instead of merging.

### Summary

```markdown
## Review Complete: [Feature]

**VERDICT:** APPROVED
**Status:** APPROVED
**Report:** `${REPORT_DEST}YYYY-MM-DD-HHMM-[feature].md`
**Rounds:** {count}

### Convergence

Round  Sec  Perf  Arch  Correct  Tests  Contracts  Doct  Total  Applied  Deferred
  1     {n}  {n}   {n}    {n}     {n}      {n}      {n}   {n}     {n}       {n}
  2     {n}  {n}   {n}    {n}     {n}      {n}      {n}   {n}     {n}       {n}

(mark a skipped dimension `—`, per the round's panel manifest — `Doct` is `—` on any
diff that doesn't touch skills/)

R1  {▓▓░░░████}  {total}
R2  {░████}      {total}  {-N%}

▓ Critical  ░ High  █ Medium

### Resolution

Found: {total} across {count} rounds
  ├─ Auto-applied (severity):      {n}  {bars}
  ├─ Auto-applied (same-round):    {n}  {bars}
  ├─ Auto-applied (cross-round):   {n}  {bars}
  ├─ Auto-implemented (conductor):  {n}  {bars}
  ├─ User-approved:                {n}  {bars}
  └─ Discarded (no consensus):     {n}  {bars}

### Changes Made

- {list key auto-fixes}

### Decisions Made

- {list decisions and outcomes, or "none needed"}

**All project checks passing.**
```

### Next Step

**If called from `ac-loop` (autonomous run):** Skip — exit after the summary. The loop reads `VERDICT:` from the output. On `main` (trunk-direct), `APPROVED` gates `ac-batch-close` proceeding — VERDICT semantics are unchanged, only the downstream consumer is: the loop no longer chains through `ac-merge`'s PR-merge step. On a legacy branch, `APPROVED` still chains to `ac-merge`. Either way, `NEEDS_DECISION` stops instead of proceeding.

**If called interactively (human present):**

```
AskUserQuestion(
  questions: [{
    question: "Review complete ({N} fixed, {M} decisions resolved). What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Close the wave (Recommended)", description: "Trunk-direct (default): run /ac-batch-close — CI verify, feedback triage, bead close. Legacy PR branch only: run /ac-merge" },
      { label: "Another review pass", description: "Run /ac-review again — fresh eyes on the updated code" },
      { label: "Manual review", description: "Done with automated review — you'll review manually" },
      { label: "Done for now", description: "Review saved — pick up later" }
    ]
  }]
)
```

### Cleanup

```bash
rm -rf "$ARTIFACTS_DIR"
```

**Self-deregister the Tier-1 identity (Layer 1)** — after the final commit and reservation
release, per `_shared/agent-mail.md` § Release + self-deregister.

**TaskUpdate(task: "Phase 8", status: "completed")**

---

## Flexibility & Overrides

**"Quick review"**
-> Spawn single comprehensive reviewer (Opus) instead of the specialized panel

**"Just report, don't fix"**
-> Skip Phase 4 (auto-fix), present all findings as report only

**"Docs-only wave"** (diff touches only non-code paths — `_plans/`, `docs/`,
`references/`, `*.md`; no `app|lib|scripts|supabase|features` hits)
-> Spawn the **docs-lens set** (findings-integrity / consistency / discipline) from
`references/review-dimensions-docs.md` instead of the code four — reviewed against the
org's documentation-standards skills (`context-engineering`, `skill-builder`, wiki/memory
doctrine). Auto-detected in Assemble the Panel; named here so it's discoverable, not
reinvented per docs wave.

**"Review these files only: [list]"**
-> Scope diff to specified files instead of full branch diff

**"Skip validation"**
-> Bypass Phase 5 validation gate

**"Skip convergence"**
-> Never offer Phase 5.5 verification round

---

## When to Use This vs /ac-hygiene

Routing is at the top (feature branch → here; codebase-wide → `/ac-hygiene`); hygiene's distinguishers: whole-codebase scope, between-session/weekly maintenance, a 7-lens Opus panel over 3+ rounds (vs the single-round 6-or-7-dimension diff panel here — opus on security/correctness, sonnet on architecture/performance — the 7th only on a skills/-touching diff), conductor fixes directly, hunts bugs/dead code/drift. The two test lenses are complementary, not duplicate: this skill's `test-quality` reviewer audits the tests a wave just wrote, at the gate, while the diff is small; hygiene's Test Warden rotates through the whole back-catalog. Use both: `ac-review` for pre-merge validation, `hygiene` for general health.

---

## Remember

<!-- diet: restated bullets deleted (ac-gcj.5 Remember diet, Craig ruling 2) — cut bullets have live body twins (grep-verified); the Remember-only rule survives below -->

- **One human touchpoint** — remaining no-consensus + NEEDS_DECISION items are presented ONCE in Phase 7, never per-round

---

_Work review: parallel reviewers, severity-based auto-fix, user-gated decisions. For codebase health: `/ac-hygiene`. For implementation: `/ac-implement`._
