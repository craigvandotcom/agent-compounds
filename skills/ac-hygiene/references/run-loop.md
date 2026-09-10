## REVIEW LOOP: Phases 1-4

### Phase 1: Spawn the Panel (parallel)

**All panel agents in a single message for parallel execution.**

Spawn the panel per `PANEL` (full = Bug Hunter, Adversary, Failure Engineer, Promise Keeper,
Test Warden; light = Bug Hunter + Adversary + Test Warden — all Opus) using the prompts in
**`references/reviewers.md`**, whose § THE BAR scopes every lens to the product surface.
Substitute `{SCOPE_CONTEXT}`, `{CURRENT_ROUND}`, and `{ARTIFACTS_DIR}`. Each writes to `$ARTIFACTS_DIR/round-{CURRENT_ROUND}-{role}.md`.
**Between rounds**, add the "Files already reviewed: {list}. Look elsewhere." line to each
prompt (see Phase 4).

### Phase 2: Synthesize

**Read ALL findings files for the round.** This is your core job — do not delegate.

Synthesis principles:

- **Consensus is high-signal** — 2+ agents flagging the same area is almost certainly real.
  Lens-diverse consensus is *rarer and stronger* — don't lower the bar to compensate;
  single-agent findings are what the consensus registry and Phase 5 triage are for.
- **Evidence over opinion** — findings need file paths and line numbers
- **Trim counts as much as fix** — a net-negative test count with coverage held is a good round (`references/reviewers.md` § Trim as hard as you fix)
- **Critical/High first** — skip Medium unless trivial to fix
- **Deletion mandate** — a finding of stale/superseded/duplicated content is not flag-and-leave;
  REMOVAL/demotion ranks as a first-class disposition, equal to additions/fixes, and follows the
  same auto-apply rules (severity/consensus, Phase 3) as any other change. Route the removal per
  `skill-builder/references/promotion-ladder.md` §What routes through the holding zone: a
  **duplicate** (verbatim twin survives elsewhere) deletes outright; a still-needed **extract**
  moves straight to `references/` with a pointer; **unique** content with no surviving twin is the
  only case that must route through the skill's `MAINTENANCE.md` holding-pen (review-by date +
  default resolution) before it can be git-deleted.

Produce a numbered change list. For each: target file, what to change, auto-fixable or not.

### Phase 3: Apply Fixes

**Auto-apply a fix if ANY condition is met:**

1. **Severity-based:** The issue is Critical or High severity — these are defects, not preferences
2. **Same-round consensus:** 2+ agents independently flagged the same issue (regardless of severity) — multi-agent agreement is high-signal
3. **Cross-round consensus:** A single-agent finding from THIS round matches a deferred finding in the consensus registry from a PREVIOUS round — recurrence across rounds is high-signal

<!-- mirror: ac-pipeline/references/review-consensus.md §The auto-apply cascade — edit there first -->

**Design decision gate (applies before all auto-apply rules):** If a finding represents a choice with no objectively superior technical answer, resolve it yourself — pick the better option. Only tag as `DESIGN_DECISION` and defer if the decision would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing values, naming conventions, implementation style) — just pick the better option and auto-apply.

<!-- mirror: ac-pipeline/references/review-consensus.md §Design-decision gate — edit there first -->

**Apply these immediately. Log them as "Auto-applied" in the progress file with the consensus type.**

After each batch of fixes — the **round gate** (incremental, per `ac-pipeline`
Invariant 2: incremental in the loop, exhaustive once at the boundary):

```bash
format (auto-fix, e.g. `pnpm format`) + type-check + lint + AFFECTED tests only   # BLOCKING
# Never run the full suite per round — it runs exactly once, at Phase 5, pre-merge.
```

Run **format FIRST and as an auto-fix** (`pnpm format` = `prettier --write .`, not
`format:check`) — CI checks formatting first over the *whole repo*, so one unformatted file
fails the entire gate ~10 min in; auto-fixing locally makes that impossible.
<!-- mirror: ac-pipeline/references/verification-gate.md §Format-first gate — edit there first -->

If checks fail, revert the breaking fix and note it as non-auto-fixable.

Then commit the round's fixes **directly to `main`** (trunk-direct — no hygiene branch;
small, revert-friendly, pathspec-limited commits) and **push immediately** (commit = push;
there is no branch holding the work safe in the interim):

```bash
git pull --rebase
git commit -m "chore(hygiene): round {CURRENT_ROUND} — {short summary}" -- <specific files>
git push --no-verify origin main
git rev-parse HEAD && git ls-remote origin main   # confirm the SHAs match after every push
```

> **Pathspec commits, never `git add -A`.** Use the `git commit -- <files>` form limited to the
> exact paths YOU changed (tracked from the implementer reports). Under trunk-direct another
> session's uncommitted WIP shares this checkout — a wildcard add sweeps that foreign work into
> your hygiene commit and misattributes it (`ac-implement` Phase 0 H7d). New (untracked)
> files need `git add <file>` first, then the pathspec commit of exactly that path.

> **Commit WITHOUT `--no-verify`; push WITH it.** The pre-commit hook runs `lint-staged`
> (prettier `--write` + eslint `--fix`) on your staged files and re-stages them — the cheap
> auto-format net that stops formatting-class CI failures; never bypass it on a commit.
> `--no-verify` is for the **push** only — under trunk-direct the heavy pre-push `pnpm build`
> reads the whole working tree and another session's uncommitted WIP can false-positive it
> (swallowing the push), so real verification for state you don't own comes from the round gate
> above plus post-push CI. **Race handling:** if `git push` collides, `git pull --rebase` and
> re-push — never force-push over another session's committed work.

**Defer remaining findings (DO NOT ask user per-round):**

After auto-applying, any remaining changes (Medium/Low severity AND only flagged by a single agent with no cross-round match) are added to the consensus registry — NOT presented to the user.

For each deferred finding, append to `$ARTIFACTS_DIR/consensus-registry.md`:

```markdown
| {CURRENT_ROUND} | {agent role} | {severity} | {file:line} | {one-line summary} |
```

**`DESIGN_DECISION` items** (choices that noticeably affect user experience or profoundly change development approach) are deferred regardless of severity or consensus — these skip the registry and go directly to the user in Phase 5.

### Phase 4: Convergence Check + Progress

Append to `$ARTIFACTS_DIR/progress.md`:

```markdown
### Round {CURRENT_ROUND}

- **Findings:** {count} total ({Critical} Critical, {High} High, {Medium} Medium)
- **Auto-fixed:** {count}
- **Deferred:** {count} (need judgment)
- **Consensus areas:** {where agents agreed}
- **Trajectory:** {assessment}
```

**Rule 1: if this round's agents found ANY Critical or High issues, you MUST run another round after applying fixes.** Fixes are unverified until the next round's agents confirm no new Critical/High issues emerge.

**Rule 2 (the round floor): the `MIN_ROUNDS=3` floor is ABSOLUTE** — cross-round consensus needs two later rounds for a deferral to recur in; see the config comment (Phase 0) and the first branch of the decision block below. Ceiling is `MAX_ROUNDS=5`.

```
# The floor is checked FIRST and is absolute — nothing exits before round 3.
IF CURRENT_ROUND < MIN_ROUNDS -> apply fixes, continue (increment CURRENT_ROUND)   # even on back-to-back zero-finding rounds
IF two consecutive rounds found ZERO findings (only reachable at CURRENT_ROUND >= MIN_ROUNDS) -> finalize early (panel is dry — stop burning agents)
IF agents found any Critical or High issues -> apply fixes, continue (increment CURRENT_ROUND)
IF only Medium or no new issues -> finalize (proceed to Phase 5)
IF CURRENT_ROUND >= MAX_ROUNDS -> force finalize (note unverified fixes)
IF this round found same issues as last round AND CURRENT_ROUND >= MIN_ROUNDS -> force finalize (agents are circling)
```

**Between rounds:** Each agent explores DIFFERENT files in the next round. Include in the next prompt: "Files already reviewed: {list from previous round findings}. Look elsewhere."
