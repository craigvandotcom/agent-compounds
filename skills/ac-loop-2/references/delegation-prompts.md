<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->

**Conductor: paste the block below VERBATIM at the head of EVERY prompt in this file — as
the FIRST lines of the constructed child prompt, above its opening line — substituting the
child's minted `AGENT_NAME`.** It is the child-side environment contract and a pointer to it
is explicitly insufficient (canon § Child-spawn preamble) — a preamble that stays in this
header and never enters the constructed prompt has not been delivered to any child.

ENVIRONMENT CONTRACT (non-negotiable):
- WAIT for your own long-running commands in-shell (foreground, generous Bash
  timeout, or a foreground until-loop). Never arm a Monitor on your own command
  and end your turn — if a completion event already fired, read it and CONTINUE.
- Agent Mail: CHECK whether you hold `mcp__mcp-agent-mail__*` tools — assume neither way.
  Usually you do NOT: then don't try to register, and your conductor owns reservations.
  Either way, export the `AGENT_NAME` it gave you in each commit's own shell.
- Touching beads (`br`/`bv`)? The canon is `beads-standards` (+ its
  reference/bead-conventions.md for pipeline contracts) — read before inventing usage.
- After every push: verify origin SHA == local HEAD before proceeding.
- A guard block (dcg / pre-commit) means CHANGE APPROACH, never bypass. To DISCARD
  a change: `git checkout HEAD -- <path>` AND unscoped `git stash` are both blocked —
  use scoped `git stash push -- <paths>`; to read a pristine file, `git show <ref>:<path>`.
  Destructive commands (rm / find -delete) take FULLY-LITERAL paths: resolve
  first (`ls -d`), then paste literals — never `$VAR`, `$( )`, or a loop var.
  /tmp literals + distinctive /tmp globs are allowed; home/repo `rm -rf` never
  is — `git rm` if tracked, else gitignore-and-flag or ask the human.
- Shared checkout: `git commit -- <your files>` the INSTANT its ACs verify —
  pathspec on the COMMIT, because scoping only the `add` still publishes the
  shared index. **Never `git add -A` / `git add .` / `git commit -a`** — they
  sweep a concurrent agent's staged work into your bead's commit, silently.
  Minimal working-tree dwell; run `br` from the bead-board repo root.
- Autonomous run: never AskUserQuestion — Exhaust Rule.
- Return a structured `friction:` block (stage/cost/lesson/class; `[]` if clean).

# ac-loop-2 delegation prompts

The verbatim child-prompt payloads each phase dispatches. Slots in `{BRACES}` are filled by
the conductor at dispatch.

The six-element implementation contract is native in
`beads-standards/reference/bead-conventions.md` § Implementation contract —
`ac-beadify` / `ac-bead-refine` emit and gate it. Spec-phase prompts below
point at that schema; they do not restate it. Edit the contract there.

## Spawn-site rule (binds every prompt below)

Every dispatched prompt carries an **explicit `AGENT_NAME=<name>`** — every child, claiming
or not. An unset `AGENT_NAME` degrades silently in two directions: an empty `CHILD_ID`
segment that collapses two children onto one artifacts path, or a fallback to the Tier-2
chore identity FoggyCreek. The conductor is the only agent that can set it.

Append this clause VERBATIM to every prompt below:

> `AGENT_NAME=<name>` — export it in every shell you commit from. ASSERT each segment of
> any identity you build from it is non-empty, and FAIL LOUDLY if not: never let an empty
> segment degrade to a shared path. Your run ledger is your `progress.md` — you hold no
> Task tools; the conductor owns the Task-tool ledger.

## Brief-claim rule (binds every prompt below)

Compose-time: state a fact only with a citation — a commit SHA or a `br show` verdict. A
claim about work still in flight is not citable. Write "premise, NOT verified" or wait for
the child's return. Never restate a bead's preconditions as established fact.

Dispatch-time: append this clause VERBATIM to every prompt below.

> This brief is a POINTER, not a substitute for the spec — read `br show <id>` in
> full. Any uncited claim here is a premise, not a fact; verify it against the
> primary source. If a stated premise is false, follow the bead's own acceptance
> criteria, not this brief.

---

## Spec-phase prompt (Phase 1 — refine)

> "Run ac-bead-refine scoped to {REFINE_SCOPE — an epic id, or an explicit bead-id list}.
> `TARGET_BEAD_IDS=<ids>` — refine EXACTLY these and stamp nothing else. `RUN_ID=<RUN_ID>`
> passed BARE, never per-child-suffixed; compute your own per-CHILD artifacts discriminator.
>
> **HEAD IS FROZEN for this phase.** You write to the beads DB only — no implementation
> commit, no file edit outside the beads ledger. Every anchor you verify stays valid because
> nothing moves under you. Record the HEAD sha you verified against.
>
> **Each bead you stamp `refined` MUST carry ALL SIX elements of the implementation
> contract** (`beads-standards/reference/bead-conventions.md` § Implementation contract,
> including `### Test-tier exposure` on element 3). A bead missing any element is NOT
> refined — leave it unrefined, comment why. Re-open every cited `file:line` at the
> frozen HEAD. Convergence discipline unchanged: execute-at-draft, `br lint` first,
> final adversarial round whose job is to BREAK the contract, not bless it.
>
> If you write a `progress.md`, its header MUST carry `KIND=refine` — you ship no code and
> close no beads, and the marker is what keeps your file out of the close gate's completeness
> union. Beads-DB rule (`ceremony-batching-pool.md` § Beads-DB mutation deferral — no
> ceremony is in flight, so the prep-hold does not bind): run your `br` verbs directly — the stamps ARE your
> deliverable, and the frozen HEAD means nothing collides. NEVER stage or commit `.beads/`
> or anything else — the conductor is the ledger's only git writer and commits at the barrier.
> Headless: no AskUserQuestion; a genuine fork becomes a decision bead (Exhaust Rule).
> Report ≤400 words: beads stamped with IDs, beads HELD BACK with the missing contract
> element named, premise failures found, + the structured `friction:` block (§ Child friction
> schema below)."

## Spec-phase prompt (Phase 1 — beadify)

> "Run ac-beadify on plan `{PLAN_PATH}` (status already verified loop-ready).
> `RUN_ID=<RUN_ID>`. HEAD is frozen — beads-DB writes only. Skip the user-approval asks
> (autonomous run): auto-apply Critical/High + consensus validator findings, log the rest.
> Do NOT proceed to refinement yourself — the conductor dispatches the refine children.
> Every bead you create must stamp implementation-contract elements 3 and 5
> (`## Territory` with `### Test-tier exposure`, `## Sequence + risk`) per
> `beads-standards/reference/bead-conventions.md` § Implementation contract; the
> refine child completes the other four. If you write a `progress.md`, its
> header MUST carry `KIND=beadify`. Same beads-DB rule + report + `friction:`
> contract as the refine prompt above."

---

## Lane-coordinator prompt (Phase 2)

> "You are the coordinator for epic lane `{LANE_ID}` in a phase-gated build phase.
> `RUN_ID=<RUN_ID>`, claim id `<claim-id>`, `CLAIM_ASSIGNEE=<AGENT_NAME>`.
> Your lane's beads, in sequence order: `<bead ids>`. Your lane's territory manifest is the
> union of their manifests: {LANE_TERRITORY}.
>
> **This phase has NO GATES.** No test gate, no type gate, no smoke, no build. The tree is
> shared with other lanes and is legitimately dirty with their in-flight work. Every global
> signal you might read is meaningless right now and is NOT yours to act on. A batched
> converge phase owns all of it after the barrier.
>
> Dispatch one worker per bead, respecting sequence position; workers may run concurrently
> within your lane only where their territories are disjoint. Keep workers lane-sticky —
> reuse a returning worker for the next bead in YOUR lane rather than spawning fresh.
>
> **Discoveries are FILED, never fixed.** Any adjacent defect, missing test, or better shape
> a worker finds becomes an `unrefined` bead (stamped `post-merge` at creation, parented into
> this epic) for the next cycle's spec phase. Fixing inline breaks one-bead-one-commit, which
> is the entire basis of the converge phase's attribution.
>
> **Migration and native beads are NOT yours** — return them to the conductor for the serial
> risk queue at the phase tail, even if they are in your lane's sequence.
>
> Beads-DB rule: run `br` verbs directly (discovery filings included) but NEVER stage or
> commit `.beads/` — the conductor is the ledger's only git writer and commits at the barrier.
> Your ledger is your `progress.md` (header: claim id, `TARGET_BEADS=<n>`, `KIND=implement`).
> Report ≤400 words: bead ids with their commit shas, beads returned to the risk queue,
> discovery beads filed with IDs, anything blocked, every Agent Mail identity used, + the
> structured `friction:` block."

## Build-worker prompt (Phase 2)

> "Implement bead `{BEAD_ID}` on the shared checkout. Read `br show {BEAD_ID}` in full — it
> carries a six-element implementation contract; that contract is your whole brief, and you
> should never need to ask a question. `AGENT_NAME=<name>`, `CLAIM_ASSIGNEE=<AGENT_NAME>`.
>
> **THREE RULES. There is no fourth.**
> **(a) Territory.** Write ONLY inside the bead's territory manifest: {TERRITORY — explicit
> list}. Not one file more, for any reason. If the fix genuinely needs a file outside it,
> STOP and return — do not widen your own permission.
> **(b) COMMIT MUTEX.** Take the global commit lock around add+commit+push. The git index and
> the push are the one unavoidable collision on a shared tree. **Commit root:** if this
> bead is `cross-repo` (or Repo ownership names agent-compounds / root ~/Repos), resolve
> `COMMIT_ROOT` with `git -C "$(realpath <an edited file>)" rev-parse --show-toplevel`
> and run add/commit/push **there**. A clean `git status` in the app checkout after a
> symlink edit means you have not committed yet
> (`ac-pipeline/references/commit-discipline.md` § Cross-repo). The lock lives at
> `$(git rev-parse --git-common-dir)/ac-loop2-commit.lock` of the commit-root repo.
> Never derive LOCK via `--git-dir` (worktree-private; would silently un-share the mutex).
> ```
> COMMIT_ROOT="${COMMIT_ROOT:-$PROJECT_ROOT}"
> LOCK="$(git rev-parse --git-common-dir)/ac-loop2-commit.lock"; locked=0
> echo "commit-mutex: $LOCK"
> _mutex_t0=$(date +%s)
> if mkdir "$LOCK" 2>/dev/null; then locked=1; else
>   # First mkdir ENOTDIR/EACCES: path permanently unusable — abort, do not burn the bound.
>   _parent="$(dirname "$LOCK")"
>   if [ ! -d "$_parent" ] || [ ! -w "$_parent" ]; then
>     echo 'FATAL: commit mutex path unusable' >&2; exit 2
>   fi
> fi
> if [ "$locked" != 1 ]; then
>   for _ in $(seq 1 240); do                     # 240*2s = 480s < 600s Bash cap
>     if mkdir "$LOCK" 2>/dev/null; then locked=1; break; fi
>     # Steal a stale lock: EXIT traps do not fire on SIGKILL/sleep — a dead holder blocks every lane.
>     find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null | grep -q . && rmdir "$LOCK" 2>/dev/null && continue
>     sleep 2
>   done
> fi
> [ "$locked" = 1 ] || { echo 'FATAL: commit mutex not acquired in 480s — report, do not commit' >&2; exit 2; }
> echo "commit-mutex: acquired in $(($(date +%s) - _mutex_t0))s path=$LOCK"
> trap 'rmdir "$LOCK" 2>/dev/null' EXIT
> # Never unquoted $PATHS (zsh default: no SH_WORD_SPLIT). Each path is its
> # own quoted argument on both git add -- and git commit --.
> # Do not read git commit / git push exit through a pipe.
> git add -- <your territory paths>
> HEAD_BEFORE=$(git rev-parse HEAD)
> git commit -m '<type>(<scope>): <subject> ({BEAD_ID})' -- <your territory paths>
> git push --no-verify
> # INSIDE the lock — after release a sibling's commit moves HEAD and false-fails this
> [ "$(git rev-parse HEAD)" != "$HEAD_BEFORE" ] || { echo 'FATAL: HEAD did not advance — commit landed nothing' >&2; exit 2; }
> [ "$(git rev-parse origin/<branch>)" = "$(git rev-parse HEAD)" ] || { echo 'FATAL: push not on origin' >&2; exit 2; }
> rmdir "$LOCK"; trap - EXIT
> ```
> Never `git add -A` / `git add .` / `git commit -a` — they sweep a concurrent agent's staged
> work into your commit, silently.
> **(c) Trust no global signal.** A local run scoped to your OWN files is permitted as
> advisory information only. It is NEVER blocking. Red output from anything outside your
> territory is a sibling's in-flight work, not a bug you found.
>
> **Anchors drift; quoted text does not.** Your bead's `file:line` anchors were verified at
> the Phase-1 freeze; earlier beads in your lane may have shifted lines since. Relocate by
> the QUOTED text — a moved line number is not a broken spec. If the quoted text itself is
> gone, STOP and return the bead as spec-stale; never improvise.
>
> **ONE BEAD = ONE COMMIT.** Do not fold a second bead, a drive-by cleanup, or a formatting
> sweep into it. The converge phase attributes failures by bisecting this commit range; a
> combined commit makes its own failures unattributable.
>
> Write the bead's test with its DECLARED RED expectation in mind — the declared failure will
> be sampled later by reverting your fix. A test that passes with the fix reverted is hollow
> and reopens this bead.
>
> Adjacent defects: FILE an `unrefined` bead (stamped `post-merge`), never fix. Hold all `br`
> mutation verbs until told the ledger is flushed. Report ≤200 words: commit sha, files
> touched, discovery bead ids, + the structured `friction:` block."

## Risk-queue prompt (Phase 2 tail — serial, one at a time)

> "Implement risk bead `{BEAD_ID}` (flags: {RISK_FLAGS}) SOLO. Nothing else is running.
> Same three worker rules and the same commit mutex as a build worker, PLUS an immediate
> local verification that must pass BEFORE you return:
> - **migration** — apply against the LOCAL stack and prove RED→GREEN: capture the failing
>   state before, apply, capture the passing state after. Paste both. A broken migration
>   poisons the shared local stack for every subsequent worker and cannot wait for the
>   converge phase — by then every downstream result is contaminated.
> - **native** — compile, then launch in the simulator. Paste both outcomes.
>
> If the verification fails, REVERT your commit (its own revert commit), reopen the bead with
> the output pasted in, and return. A revert here is a normal outcome, not an escalation.
> Report ≤200 words: commit sha, verification output, + the `friction:` block."

---

## Repair-worker prompt (Phase 3)

> "Repair failure cluster `{CLUSTER_ID}` on a QUIESCENT tree — the build phase is closed and
> nothing else is writing. Attributed failures: {FAILURES — each with its bisected first-bad
> commit and bead id}.
>
> **Unlike the build phase, you DO run checks per fix.** The tree is quiescent, so a gate
> costs nothing and catches everything: run the affected tests after each fix, and the
> type-check before you commit.
>
> Commit with a pathspec under the same commit mutex, citing BOTH the repair and the bead it
> repairs. Stay inside the union of the affected beads' territory manifests.
>
> If a fix cannot be made safe, REVERT the offending bead's commit (its own revert commit)
> and reopen that bead with the failure pasted in. Reverting is a normal outcome — do not
> escalate, do not widen scope, do not fix a second cluster.
>
> Report ≤300 words: fixes applied with commit shas, beads reverted+reopened with IDs,
> failures you could not attribute, + the structured `friction:` block."

---

## Batch-close prompt (Phase 4)

> "Run ac-batch-close for cycle `<claim-id>` (ac-loop-2 phase-gated run). CI config for this
> project: `<cached-answer>`. This pipeline has no review panel — the verification gate
> cleared this cycle, and standing code quality is ac-hygiene's lane on its own cadence. For
> uncertain CI-finding items: create decision beads (Exhaust Rule). Do not ask 'what's next?'
> after merge."

---

## Child friction schema

The `friction:` block every summary contract above asks for. Structured (not prose) so the
conductor can aggregate it mechanically and `dream` can key on `stage`/`cost` later. One list
item per phase-stage that hit friction; a clean stage returns `friction: []`. Lives INSIDE
the existing summary word cap — a slot in that summary, not a new unbounded field.

```
friction:
  - stage: build              # graph|spec|build|risk-queue|converge|verify
    cost: material|minor       # + optional "~Nmin" when quantifiable
    lesson: "territory manifest omitted the test file, worker had to return"
    class: defect|improvement|observation   # child's pre-classification HINT
```

`class` is a HINT only — `ac-land`/`reflect` re-adjudicate it against the objective bar;
never treat it as authoritative. This file is the ONE definition of the four keys.
