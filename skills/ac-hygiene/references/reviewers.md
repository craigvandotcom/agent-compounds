<!-- mirror: ac-pipeline/references/delegation-contract.md § Child-spawn preamble -- edit there first -->

**Conductor: paste the block below VERBATIM at the head of EACH of the seven `Task(...)`
prompts in this file, above its `First: read AGENTS.md` line, substituting the child's
minted `AGENT_NAME`.** It is the child-side environment contract and a pointer to it is
explicitly insufficient (canon § Child-spawn preamble) — a preamble that stays in this
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
- Shared checkout: commit your bead's files (pathspec-scoped) the INSTANT its
  ACs verify — minimal working-tree dwell; run `br` from the bead-board repo root.
- Autonomous run: never AskUserQuestion — Exhaust Rule.
- Return a structured `friction:` block (stage/cost/lesson/class; `[]` if clean).

# Hygiene Reviewers — the 7-lens panel

Spawn the panel in a **single message** (parallel). Each agent writes to
`$ARTIFACTS_DIR/round-{CURRENT_ROUND}-{role}.md`. Substitute `{SCOPE_CONTEXT}`,
`{CURRENT_ROUND}`, and `{ARTIFACTS_DIR}`. **Between rounds**, append to each prompt:
`Files already reviewed: {list from previous round findings}. Look elsewhere.`

**Panels:**
- `PANEL=full` (default, the weekly run): all 7 lenses below.
- `PANEL=light` (quick between-session pass): Bug Hunter + Explorer + Structural only.

All lenses share the rules that make consensus work: open-ended hunting (seed lists are
inspiration, never a checklist), evidence with file:line required, competitive framing,
top-7 findings / under 600 words, skip Low severity, never invent issues. Lenses are
*perspectives on the same codebase*, not divided territory — overlap is desired; two lenses
converging on the same file is the strongest signal the conductor gets.

---

## Agent 1: Bug Hunter (Opus)

```
Task(subagent_type: "general-purpose", model: "opus", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a bug hunter doing a "fresh eyes" review of this codebase. You compete with 6 other reviewers — only evidence-backed findings with file paths count.

## Scope
{SCOPE_CONTEXT or "Full codebase — you choose where to look."}

## Your Method

Earn the right to critique: before hunting, understand the terrain — entry points, data flow, what the system is for. If you can't describe how data flows through a module, that opacity is itself a finding.

Then explore with completely fresh eyes. Start wherever interests you — recent git activity, hot paths, complex modules — read files deeply, trace imports, and follow data flows across the full chain.

Look super carefully for real bugs — the kind that cause wrong results, silent failures, or data corruption. Two moves that pay off: (1) invariant analysis — list what must ALWAYS be true, then try to construct the scenario that violates it; unenforced invariants are bugs waiting to happen. (2) boundary probing — empty, null, zero, negative, huge, concurrent, out-of-order. Some areas worth considering: logic errors, race conditions, null hazards, swallowed exceptions, type assertion abuse — but follow your instincts, not a checklist.

Also read `ac-pipeline/references/anti-patterns.md` and hunt its three named anti-patterns — evidence destruction (swallowed errors), coordinated workaround (the same error silenced in ≥2 config layers), unproven seam (a bridge crossing with no un-mocked test) — real failure modes from a production incident, not speculative.

Rank what you find by Severity × Likelihood.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-bug-hunter.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/file:line
**Evidence:** What you read, what's wrong, why it's a problem
**Fix:** Specific change needed
**Auto-fixable:** YES | NO (YES = unambiguous single fix, NO = needs judgment)

Limit: top 7 findings. Skip Low severity. Under 600 words total.
If nothing found, say so — don't invent issues.
""")
```

## Agent 2: Explorer (Opus)

```
Task(subagent_type: "general-purpose", model: "opus", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a codebase explorer doing deep random investigation. You compete with 6 other reviewers — only evidence-backed findings with file paths count.

## Scope
{SCOPE_CONTEXT or "Full codebase — explore freely."}

## Your Method

Pick random starting points across the codebase and go deep. Read files thoroughly, follow import chains, trace data flows end-to-end, check callers and callees. Do this for 3-4 different entry points — let curiosity guide you.

You're looking for anything a fresh pair of eyes would catch — dead code, inconsistent patterns, missing error handling, stale comments, copy-paste drift, unnecessary dependencies. But don't limit yourself to these categories. If something feels off, investigate it. Trust your instincts.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-explorer.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/file:line
**Evidence:** What you traced, what's inconsistent/dead/wrong
**Fix:** Specific change needed
**Auto-fixable:** YES | NO

Limit: top 7 findings. Skip Low severity. Under 600 words total.
If nothing found, say so — don't invent issues.
""")
```

## Agent 3: Structural Reviewer (Opus)

```
Task(subagent_type: "general-purpose", model: "opus", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a structural reviewer checking architecture health. You compete with 6 other reviewers — only structural improvements backed by evidence count.

## Scope
{SCOPE_CONTEXT or "Full codebase — assess overall health."}

## Your Method

Read the project structure, then explore source directories with fresh eyes. Assess the overall health of the architecture — dependency cleanliness, test coverage, module boundaries, abstraction levels.

Think about structural integrity: are modules well-bounded? Are dependencies flowing in the right direction? Is there over-abstraction or under-abstraction? Are critical paths tested? But explore broadly — structural issues often hide in unexpected places. Trust your architectural intuition.

Also read `ac-pipeline/references/anti-patterns.md` and hunt its three named anti-patterns — evidence destruction (swallowed errors), coordinated workaround (the same error silenced in ≥2 config layers), unproven seam (a bridge crossing with no un-mocked test).

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-structural.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/file:line (or pattern across files)
**Evidence:** What you checked, what's wrong, why it matters
**Fix:** Specific change needed
**Auto-fixable:** YES | NO

Limit: top 7 findings. Skip Low severity. Under 600 words total.
If nothing found, say so — don't invent issues.
""")
```

## Agent 4: Adversary (Opus)

```
Task(subagent_type: "general-purpose", model: "opus", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a security-minded reviewer reading this codebase the way someone hostile would. You compete with 6 other reviewers — only evidence-backed findings with file paths count.

## Scope
{SCOPE_CONTEXT or "Full codebase — follow the trust boundaries."}

## Your Method

Find where the system trusts something it shouldn't. Map the trust boundaries first — where user input enters, where external data (APIs, webhooks, AI responses, file uploads) crosses into the system, where authentication becomes authorization — then walk them like an attacker with source access.

Some areas worth considering: authorization gaps (can user A reach user B's data? is the check at every layer or just the door?), injection paths, secrets in code or logs or client bundles, unvalidated external data trusted at type boundaries, information leakage through error messages, privileged code paths reachable without the privilege. But follow the data, not a checklist — the real finding is usually the boundary nobody thought of as a boundary.

Discipline: findings must be exploitable-in-principle with a concrete path — name the actor, the entry point, and what they get. No speculative best-practice nits. Static analysis only: read code and config, never fire payloads at running services.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-adversary.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/file:line
**Evidence:** The trust boundary, the concrete attack path (actor → entry → gain)
**Fix:** Specific change needed
**Auto-fixable:** YES | NO

Limit: top 7 findings. Skip Low severity. Under 600 words total.
If nothing found, say so — don't invent issues.
""")
```

## Agent 5: Failure Engineer (Opus)

```
Task(subagent_type: "general-purpose", model: "opus", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a failure engineer asking "how does this die?" of a codebase that works today. You compete with 6 other reviewers — only evidence-backed findings with file paths count.

## Scope
{SCOPE_CONTEXT or "Full codebase — hunt the failure modes."}

## Your Method

The other reviewers check whether the code is correct now. You check what happens over time and under stress. Three dimensions humans habitually ignore:

Temporal — what degrades over hours/days/months: leaks, unbounded growth (queues, tables, caches, logs), accumulated drift, state that rots imperceptibly, cache invalidation over long timescales.

Stress — what changes at 100x load or 0.1x: resource exhaustion, retry storms, timeout stacking, connection-pool starvation, cascade failures where one component's error handling takes down its neighbors, single points of failure.

Absence — the code that doesn't exist is often the bug: the error path never written, the cleanup never triggered, the validation never imagined, the rollback that isn't there. Trace failure propagation: when layer N fails, what actually happens at N+1 and N+2 — does it surface, or silently corrupt?

Follow your instincts on where fragility hides. A finding needs a concrete manifestation: when/how it bites, not just that it could.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-failure-engineer.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/file:line
**Evidence:** The failure mode and its concrete manifestation (when/how it bites)
**Fix:** Specific change needed
**Auto-fixable:** YES | NO

Limit: top 7 findings. Skip Low severity. Under 600 words total.
If nothing found, say so — don't invent issues.
""")
```

## Agent 6: Promise Keeper (Opus)

```
Task(subagent_type: "general-purpose", model: "opus", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a contract reviewer verifying that this codebase does what it claims. You compete with 6 other reviewers — only evidence-backed findings with file paths count.

## Scope
{SCOPE_CONTEXT or "Full codebase — audit the promises."}

## Your Method

Every type signature, doc comment, API shape, and function name is a promise. Broken promises are bugs that type-check. Hunt the gaps between claim and implementation:

Contracts — response shapes that don't match their types, documented parameters silently ignored, error responses that don't match the documented format, status codes that lie, function names that describe what the code used to do.

Stubs — placeholders, mocks, hardcoded returns, and TODO-shaped code living in production paths as if real. Half-implemented features that fail quietly instead of loudly.

Untested promises — the critical paths whose breakage nobody would notice: think blast radius, not coverage percentage. Where would a silent regression hurt most — auth, data integrity, money, user data? For each gap, say what test would catch it.

When claim and code disagree, judge which is right from apparent intent and usage, and say so. Follow your instincts on where promises rot — usually at module boundaries and in the code everyone assumes someone else owns.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-promise-keeper.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/file:line
**Evidence:** The promise (type/doc/name/API), the reality, which is right
**Fix:** Specific change needed (for untested promises: the concrete test to add)
**Auto-fixable:** YES | NO

Limit: top 7 findings. Skip Low severity. Under 600 words total.
If nothing found, say so — don't invent issues.
""")
```

## Agent 7: Test Warden (Opus)

```
Task(subagent_type: "general-purpose", model: "opus", prompt: """
First: read AGENTS.md for project context, coding standards, and conventions.

You are a test warden auditing whether the tests that exist are worth anything. You compete with 6 other reviewers — only evidence-backed findings with file paths count. Promise Keeper hunts MISSING tests; you audit the EXISTING ones. A bad test is worse than no test — it costs runtime and buys false confidence. Unlike the other lenses, you don't just read: you run experiments that prove a test is broken.

## Scope

{SCOPE_CONTEXT — if set, audit the tests in/near that scope. Otherwise, three slices in priority order:}

1. Fresh — tests touching code changed since the last hygiene run (find it via git log — most recent hygiene/* merge or hygiene commit; fall back to the last 30 days). New machine-written tests get caught here while the diff is small.
2. Rotation — this week's bucket of the full suite, so the back-catalog is provably covered every N weeks. Stateless and deterministic — no state file, derived from the date:
   N=10; BUCKET=$(( $(date +%V) % N ))   # a test file is in this week's bucket when cksum(path) % N == BUCKET
3. Instinct — leftover budget wherever suspicion leads: most-mocked files, slowest tests, tests that have never once failed.

## Your Method

Read first, experiment second. Read the slice and shortlist suspects (veins below), then spend a capped experiment budget — max ~10 probes — convicting the shortlist. Reading nominates; experiments convict.

The toolbox (probes):
- Rerun the suspect tests 2-3x on identical code. A test that flips is proven flaky.
- Shuffle — run them in random order (vitest: --sequence.shuffle with a seed; or the runner's equivalent). Fails only when shuffled = proven order-dependent.
- Sabotage — break the code a test claims to guard (empty the function body, flip a boundary, invert a condition — pick the ONE sabotage most likely to expose a hollow test), run just the covering tests, expect red. Still green = the tests assert nothing. That's proof, not opinion.

Isolation discipline (absolute): the other reviewers are reading this tree RIGHT NOW. Never sabotage or modify the shared tree. All destructive probes run in a disposable worktree — `git worktree add <tmpdir> HEAD`, experiment there, `git worktree remove --force <tmpdir>` when done. To you, the shared tree is read-only.

The reading veins, in rough payoff order:
- Cannot fail — no assertions; assertions inside conditionals/catch blocks; un-awaited async assertions; trivial truths (defined-only, length-only); snapshot-only tests reflexively regenerated on every change.
- Tautologies — expected values computed by the same logic as the code under test, or the test importing the SUT's own helper to build its expectation.
- Testing the mock — assertions that only echo arguments the test itself passed; asserting a stub returns its stubbed value; mocking the module under test; mock setup longer than the test body. The signature failure mode of machine-written tests — expect to find it. Cross-check `ac-pipeline/references/anti-patterns.md`'s unproven seam: a mocked boundary with no un-mocked test anywhere.
- Flakiness precursors — sleeps instead of polling, unseeded randomness, un-frozen clocks, real network in unit tests, shared mutable fixtures, order assertions on unordered collections, float equality. Prime sabotage/shuffle candidates.
- Zombies — long-skipped tests with no linked issue (git-blame the skip), commented-out tests, tests exercising deleted features or mocking removed modules.
- Classic smells only past threshold — assertion roulette at 3+ unmessaged assertions, eager tests calling 4+ distinct production functions, any test-body conditional logic. Below threshold, stay quiet: binary smell-flagging drowns the signal.

`audit/tests-audit.md` has rubric seeds — inspiration, not a checklist. Discipline: never nominate a test for deletion on coverage evidence alone — a sabotage probe that stays green IS deletion-grade evidence; for bloated-but-load-bearing tests, prescribe simplification instead.

## Output

Write findings to {ARTIFACTS_DIR}/round-{CURRENT_ROUND}-test-warden.md

For each finding:
## Finding N: Title
**Severity:** Critical | High | Medium
**File:** path/to/test-file:line
**Evidence:** What the test claims to guard, and the proof — probe result ("emptied calculateTotal, all 12 covering tests stayed green") or the specific reading
**Fix:** Specific change needed (strengthen assertion / un-mock the seam / simplify / delete)
**Auto-fixable:** YES | NO (deleting zombies and probe-convicted cannot-fail tests = YES; rewriting over-mocked or tautological tests = NO — a bad rewrite destroys the only regression protection that code has)

Limit: top 7 findings. Skip Low severity. Under 600 words total. State which probes you ran and their verdicts even when clean.
If nothing found, say so — don't invent issues.
""")
```
