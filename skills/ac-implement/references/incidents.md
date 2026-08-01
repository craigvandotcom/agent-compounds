# ac-implement — Incident Log

Full narratives behind SKILL.md's inline rules. Each rule keeps its causal why inline
and points here as `(incident: <slug> — references/incidents.md)`. Read an entry only
when you need the evidence behind a rule; the rules themselves bind without it.

## stash-corruption

Concrete incident (2026-04-08 wave/structured-modifiers session): `git stash && pnpm test && git stash pop` found nothing to save, then popped an unrelated stash entry from another branch and corrupted an unrelated plan file — forcing manual cleanup of merge-conflict markers in files unrelated to the session.

## wave-collision

Hit 2026-06-26: `git fetch --prune` had dropped merged waves' refs, so a refs-only scan of `refs/remotes/origin/wave/` reused a shipped wave number and produced a triple wave/001 collision. The fix is the union-of-three-sources scan (live refs ∪ merge messages on main ∪ tags) was implemented in `allocate-wave-branch.sh` — since DELETED with the branch ceremony (trunk-direct; see ac-batch-close § Removed): the incident is historical, the fix path no longer exists.

## baseline-preexisting

Concrete prior incident (2026-05-14 wave/curator): conductor recorded `13 failed across 3 files (3 known-pre-existing)` in progress.md and proceeded silently; user pushed back hard at land time ("why do we have failures? we should have none — why were they not addressed? and why do you persist in not addressing them?"). The 13 failures sorted into two clearly fixable buckets (env-override gap → production rate-limit, and schema-drift after migration rename) — neither was a mystery, both had deterministic fix paths. The "pre-existing = OK" framing collapsed under user scrutiny. Those two failure categories are now the first two entries on the baseline REJECT list.

## worktree-drift

Concrete prior incident (2026-05-09 wave/research-curator-prereqs / between bd-nxtl and bd-yvhn): conductor's spawned engineer detected the branch had flipped to `wave/loading-coherence` mid-session. Engineer correctly aborted; conductor wasted ~15 min recovering by inappropriately creating a worktree. Re-verifying branch in Phase 1a eliminates the failure mode entirely.

## bd-br-translation (RESOLVED — bv v0.18.0, 2026-07-16)

Incident 2026-06-12 wave/004: ran the emitted `bd` command, hit the `command not found: bd` error, re-ran with `br` — one wasted round-trip. **RESOLVED as of `bv v0.18.0`:** `bv --robot-next` now emits `claim_command: "br update <id> --status=in_progress"` natively (verified live 2026-07-16), so no translation is needed on `bv` ≥ 0.18. Kept as a dated historical note — the workaround applied only to `bv` ≤ 0.16; cross-machine version parity is assumed, not re-verified per run.

## env-blocked-claims

Concrete prior incident (2026-05-15 wave/v1-bootstrap): conductor claimed `owr.3` (P0) before recognising its spec called for `supabase migration up --local` against a local stack that doesn't exist on the project. One of the session's 8 bead slots was consumed before the env mismatch surfaced. Separately, `bv --robot-next` repeatedly recommended `n6a.2` whose remaining ACs are Mac-only — conductor had to manually filter via `br ready --json` jq each Phase 1a loop, ~4–6 min wasted across the session.

## stale-spec-claims

Concrete cost (2026-06-12 session, 10-bead env-mac run): fwb's spec ordered deletion of the entire dead scoring layer — impossible for 2 of its 3 sublayers (no live web twin existed; ~30 min engineer detour); 081.12's spec said "PluginHostSmokeTests currently has 2 UIDevice tests — extend it" — the file did not exist at all. Both were non-E9 beads.

## false-green-claims

2026-06-10 session: s1p.1 bundle claim, s1p.2 e2e claims — both false-green on first engineer rounds, caught only by conductor re-runs, ~75 min combined re-spawn cost.

## staged-sweep

See commit `f64db219` in wave/app-first-feel history for the canonical incident: a second session sharing the checkout swept staged files into its own commit before the staging session ran `git commit`.

## untracked-pathspec-close

Concrete cost (wave/001, bd-al8p.8): the new `ci-hygiene.test.ts` failed its pathspec commit; the `br close` in the SAME bash block then ran anyway and closed the bead before any commit landed.

## affected-graph-intersects-explicit-selection

**The tool reports green having run a subset of what you named.** `vitest-affected` intersects an
EXPLICITLY-NAMED file list with the git-diff set instead of honouring it, so `pnpm test fileA fileB
fileC` runs only the named files that also appear in the diff — and exits 0. Measured occurrences:
3× in RUN 20260714-170945-6308; 7-of-12 named files in RUN 20260728-234407-54469 (~4 min);
2-of-5 named suites in two independent implement children in RUN 20260729-170058-3584, one of which
reported GREEN on a per-bead gate that had run 40% of its evidence. `VITEST_AFFECTED_DISABLED=1` is
the working escape and children keep re-discovering it independently. Same family as `org-8f0`
(`ubs` exits 0 having checked nothing): **tools that report success without checking what you asked
them to check are the most expensive defects we have, because they are trusted.** An explicit file
list is exactly what an engineer reaches for when proving one specific bead, so the failure mode
lands squarely on the per-bead gate.

**Why the sibling-mock grep is the other half.** The per-file affected run under-selects sibling
*mock* files, so a fix that changes which client/method a route calls — or widens a shared interface
such as an optional `supabase?` on `AuthenticatedRequest` — breaks hand-rolled `requireAuth`/supabase
mocks only AFTER the commit. Costs: `bd-8b61b` put main briefly RED (`1c8ff1b8..074660cd`) plus 3
extra fix commits, because the per-file affected run missed 3 sibling mock files; `bd-7vta3` cost ~5
extra rounds for the same root cause. The knowledge already existed in memory
(`grep-consumers-before-widening-shared-interface`, `scan-siblings-and-cross-layer-gates`,
`hand-rolled-supabase-mocks`, `dynamic-import-breaks-affected-test-graph`) — it was simply not
ENFORCED at the implement-child gate.

**Why clause (3), the scope-contract half, is not redundant with clause (1).** Clause (1) tells the
engineer what to FIND; on a scope-contract-disciplined child, finding without permission is a dead
end. RUN 20260728-234407-54469: a scope contract naming only the files a fix TOUCHES stranded the
files that MOCK them, and the engineer was correctly refusing to edit them — ~1 extra conductor cycle.

**Not fixed at source.** `bd-fdy3n` (checked 2026-07-29, closed "premise dead") was about a CI
shallow-clone breaking `batch_anchor` scoping — a different defect. The explicit-selection
intersection is still live, so clause (2) stands as doctrine rather than a stopgap. Promotion note
from the approval: the real fix is upstream — either honour an explicit selection verbatim, or FAIL
LOUDLY when the plugin would drop named files.
