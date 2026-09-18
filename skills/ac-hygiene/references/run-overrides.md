## When to Use This

Use `/ac-hygiene` as the weekly quality pass per repo (`PANEL=full`) or a quick
between-session sweep (`PANEL=light`). For feature-specific review before merge, use
`/ac-review` on the feature branch diff.

**Standing weekly review of `main` (trunk-direct duty, C2).** Because fixes now land directly
on `main` with no PR diff to gate them, the weekly `PANEL=full` run doubles as the standing
review of `main`: **if no batch has shipped (no `.claude/reviews/batch/` commit) in >7 days,
the weekly hygiene run is the review of everything on `main` since the last `v*` tag** — it is
not optional in that window. This is the trunk-direct analogue of the pre-merge review a PR used
to force; when batches ship regularly, the verification gate covers `main` and
this weekly pass is the ordinary quality sweep on top.

**Baseline pointer only — `ac-prove` `probe` mode (Consumer Roster row (e)).** The weekly
review-main run consumes the latest `ac-prove` receipt in **`probe` mode ONLY** — a read-only
freshness check against `publish-checkpoint-gate.mjs` (`ac-prove` Step 1). This is **never** a
dispatch: hygiene never calls `ensure` or `ensure --fix-forward`, never triggers a fresh CI run,
and never fixes CI forward — proving `main` is a ship-path concern, not a review-pass concern.
It is also **never proof-of-green**: `probe` mode checks freshness only (condition 1 of
`ac-prove`'s three-condition trust rule — Canonical Receipt Contract) — the referenced run's
actual conclusion is unchecked and may be RED. Treat the receipt strictly as a baseline pointer
("here's roughly how fresh `main`'s last full proof is"), never as evidence that the codebase
this run is reviewing is CI-green.

---

## Flexibility / Overrides

- **"light"** in the prompt → 3-lens panel (Bug Hunter, Adversary, Test Warden), same rounds/rules
- **"headless" / scheduled** → no `AskUserQuestion` anywhere; full codebase, full panel; Exhaust Rule owns all decisions; Slack report mandatory
- **Scope override** — "hygiene on features/auth" → Specific-directory scope, no question asked
- **Round override** — "single round" / "quick pass" → MIN_ROUNDS=1 (accept: cross-round consensus disabled; deferred singles go straight to Phase 5 triage)

## Troubleshooting

- **Push blocked / collides** → `git pull --rebase` and re-push (never force-push over another session's committed work); if the pre-push build false-positives on foreign WIP, push with `--no-verify` (the round gate + post-push CI are the real verification)
- **Dirty tree at Phase 0** → EXPECTED under trunk-direct, NOT a blocker — inventory the foreign WIP, don't touch it, and pathspec-commit only your own files (Phase 3); only a genuine red flag (unexpected deletions, sensitive files) surfaces to the user
- **Agent dies / returns nothing** → note the lens as absent for the round and continue with the rest of the panel; re-spawn once if 2+ die
- **Quality gate fails on a fix** → revert that fix, mark non-auto-fixable, add to registry; never ship a red gate
- **Compaction mid-run** → `$ARTIFACTS_DIR/progress.md` + consensus registry are the recovery state (see Phase 0); commits already pushed to `main` hold all applied fixes (there is no branch — never sit on local-only commits)

---

## Remember

- **Codebase-wide, not feature-scoped** — agents explore freely (unless user constrains)
- **Fresh eyes each round** — direct agents to unexplored files in subsequent rounds
- **Removal ranks equal to additions** — stale/superseded/duplicate findings get the Deletion
  Mandate's routing (dup deletes outright, extract → `references/`, unique → holding-pen), not a flag-and-leave
- **Stamp-audit lens (weekly)** — spot-check `<!-- evidence: ... -->` stamps against real run history; an unsubstantiated claim is a finding
- **Auto-apply Critical/High + same-round consensus + cross-round consensus — defer the rest**
- **Round floor = MIN_ROUNDS=3, ABSOLUTE** — never finalize before round 3 (see Phase 4); ceiling MAX_ROUNDS=5
- **Lens-diverse consensus is rarer and stronger** — don't lower the bar; the registry + Phase 5 triage absorb the singles
- **Fixes commit directly to `main`** (trunk-direct — no hygiene branch, no worktree) under full H7 discipline while editing; commit=push, pathspec-limited to your own files; the close ceremony is `ac-publish`'s
- **Conductor triage before user** — auto-implement clear technical improvements; defer only genuine design decisions and scope escalations
- **Design decision gate every round** — UX-affecting or approach-transforming choices defer regardless of severity or consensus
- **Incremental in the loop, exhaustive at the boundary** — affected-only per round, full suite exactly once at Phase 5; format FIRST + auto-fix in both gates, commit WITHOUT `--no-verify` (§Format-first gate)
- **Deferred beads get an epic per run** (2+ beads); refine in-session after the close ceremony whenever ≥1 bead was created
- **Findings files + consensus registry survive compaction** — always read from `$ARTIFACTS_DIR`, not memory
- **Don't invent issues** — if the codebase is clean, say so and finish early

---

_Hygiene: the recurring codebase quality pass. For session closure: `/ac-land`._
