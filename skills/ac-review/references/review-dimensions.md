# Review Dimensions

The six-dimension panel. Each dimension fills the placeholders in
`reviewer-prompt-template.md`. The **core four** (security, performance, architecture,
correctness) ALWAYS spawn. The **two diff-conditional lenses** (test-quality, contracts)
spawn by default and are skipped only when provably irrelevant — see each SKIP rule.
Gating is negative on purpose: the failure mode of a wrong gate is one wasted reviewer,
never a silent coverage gap.

Spawn the whole panel in parallel (one message, one Task call per spawned dimension),
and record what was spawned/skipped in the **panel manifest**
(`$ARTIFACTS_DIR/panel-round-{ROUND}.json` — see SKILL.md Phase 2). `consensus.py` reads
the manifest to know which reviewers to expect; a spawned dimension with no output file
is a partial failure, never a silent pass.

**SLUGS** are the suggested `category` values — the consensus key. Reviewers may coin a
slug for an unlisted defect class, but should prefer these when they fit so same-round
and cross-round consensus can match.

---

## security

- **ROLE:** `security`
- **SKILL_HINT:** *If project has security skills:* `Read .claude/skills/<security-skill>/SKILL.md for security patterns.`
- **EVIDENCE:** The trust boundary, the concrete attack path (actor → entry point → what they gain)

**METHOD:**

Map the trust boundaries this diff touches FIRST — where user input enters, where
external data (APIs, webhooks, AI responses, file uploads) crosses into the system,
where authentication becomes authorization — then walk them like an attacker with
source access. Follow the data, not the checklist: the real finding is usually the
boundary nobody thought of as a boundary.

Discipline: a finding must be exploitable-in-principle with a concrete path — name the
actor, the entry point, and what they get. No speculative best-practice nits.

**CHECKLIST:**

- OWASP Top 10 vulnerabilities (injection, XSS, CSRF, SSRF)
- Auth/authz bypass opportunities (is the check at every layer, or just the door?)
- Hardcoded secrets or credentials
- Data exposure risks (PII leaks, verbose errors)
- Input validation gaps at system boundaries
- Insecure defaults (permissive CORS, missing rate limits)
- Dependency vulnerabilities (known CVEs in new deps)

**SLUGS:** `sql-injection`, `xss`, `csrf`, `ssrf`, `authz-bypass`, `secret-exposure`,
`pii-leak`, `unvalidated-input`, `insecure-default`, `vulnerable-dependency`

---

## performance

- **ROLE:** `performance`
- **SKILL_HINT:** *If project has performance skills:* `Read .claude/skills/<perf-skill>/SKILL.md for optimization patterns.`
- **EVIDENCE:** What you measured/traced, the quantified impact (N × unit cost weighed against the operation's real budget)

**METHOD:**

Estimate before you rate. For each suspected hotspot, quantify the impact: N × unit
cost, weighed against the operation's real budget (hot request path? one-time build
step? nightly cron?). An O(n²) over a bounded n of 12 is not a finding.

Discipline: **a Critical/High rating REQUIRES a quantified impact estimate in the
evidence — without one, rate it Medium.** The conductor downgrades unquantified
Critical/High performance findings anyway (`references/incidents.md`), so supply the
estimate or the honest severity.

**CHECKLIST:**

- N+1 queries or sequential awaits (waterfalls)
- Missing caching opportunities
- Unnecessary re-renders or recomputations
- Heavy imports that should be lazy/dynamic
- Missing pagination or unbounded queries
- Inefficient algorithms (O(n^2) where O(n) suffices — on unbounded n)
- Bundle size impact (barrel imports, large deps)
- Missing indexes on queried columns

**SLUGS:** `n+1-query`, `waterfall-await`, `missing-cache`, `rerender-storm`,
`heavy-import`, `unbounded-query`, `missing-pagination`, `inefficient-algorithm`,
`bundle-bloat`, `missing-index`

---

## architecture

- **ROLE:** `architecture`
- **SKILL_HINT:** *If project has architecture/coding skills:* `Read .claude/skills/<arch-skill>/SKILL.md for patterns.`
- **EVIDENCE:** What pattern is broken or what propagation you traced — how it deviates from codebase conventions, or what happens at layer N+1 when N fails

**METHOD:**

Check the diff against the codebase's existing patterns first — convention alignment
beats abstract ideals. Then trace **failure propagation** across every boundary the
diff crosses: when layer N fails, what actually happens at N+1 and N+2 — does the
failure surface, or silently corrupt? The error path that doesn't exist at a boundary
is an architecture finding, not a style note.

**CHECKLIST:**

- Pattern misalignment with existing codebase
- Single Responsibility Principle violations
- YAGNI violations (over-engineering, premature abstraction)
- Tight coupling between modules
- Circular dependencies or import cycles
- Wrong abstraction level (under/over-abstraction)
- Missing error handling at system boundaries (trace the propagation, don't just note the absence)
- Naming inconsistencies

Also hunt the three named anti-patterns in `ac-pipeline/references/anti-patterns.md` (evidence
destruction, coordinated workaround, unproven seam) — shared with ac-hygiene's
structural lens.

**SLUGS:** `pattern-drift`, `srp-violation`, `premature-abstraction`, `tight-coupling`,
`circular-dependency`, `wrong-abstraction`, `missing-boundary-error-handling`,
`naming-inconsistency`

---

## correctness

- **ROLE:** `correctness`
- **SKILL_HINT:** *If project has testing skills:* `Read .claude/skills/<testing-skill>/SKILL.md for test patterns.`
- **EVIDENCE:** What you traced, the scenario that breaks, expected vs actual behavior

**METHOD:**

Two moves that pay off: (1) **invariant analysis** — list what must ALWAYS be true for
the modules this diff touches, then try to construct the scenario that violates it; an
unenforced invariant is a bug waiting to happen. (2) **boundary probing** — empty,
null, zero, negative, huge, concurrent, out-of-order.

Also hunt **absence** — the code that doesn't exist is often the bug: the error path
never written, the cleanup never triggered, the validation never imagined, the
rollback that isn't there, in the code this diff introduces.

**CHECKLIST:**

- Logic errors and off-by-one mistakes
- Silent failures (wrong results without errors)
- Race conditions on shared state
- Null/undefined hazards
- Error paths that swallow exceptions
- Type assertions hiding real issues (as any, ! operator abuse)
- Edge cases not handled (empty arrays, zero values, unicode)
- State management issues (stale closures, missing cleanup)
- Missing test coverage for new functionality

Also hunt the three named anti-patterns in `ac-pipeline/references/anti-patterns.md` (evidence
destruction, coordinated workaround, unproven seam) — shared with ac-hygiene's
bug-hunter lens.

**SLUGS:** `logic-error`, `off-by-one`, `race-condition`, `null-hazard`,
`swallowed-exception`, `type-assertion-abuse`, `missing-edge-case`, `stale-closure`,
`missing-cleanup`, `missing-error-path`, `missing-validation`, `missing-test-coverage`

---

## test-quality

- **ROLE:** `test-quality`
- **SKILL_HINT:** *If project has testing skills:* `Read .claude/skills/<testing-skill>/SKILL.md for test patterns.`
- **EVIDENCE:** What the test claims to guard, and the proof — probe result ("emptied calculateTotal, all covering tests stayed green") or the specific reading
- **SKIP:** Only when the diff contains **zero test files AND zero runtime source** (docs/CI-only diff). Otherwise spawn.

**METHOD:**

Audit whether the tests this diff adds or changes are worth anything. A bad test is
worse than no test — it costs runtime and buys false confidence. Machine-written tests
are the expected failure mode here: testing the mock, tautologies, cannot-fail
assertions. Scope: test files in the diff, plus the covering tests of runtime code the
diff touched (if the diff adds runtime code with NO covering tests, that gap belongs to
correctness/contracts — you audit the tests that exist).

Read first, experiment second: shortlist suspects from the reading veins below, then
spend a capped probe budget — **max ~5 probes** — convicting the shortlist. Reading
nominates; probes convict.

The probes:
- **Rerun** suspect tests 2–3× on identical code. A test that flips is proven flaky.
- **Shuffle** — run them in random order (vitest: `--sequence.shuffle` with a seed, or
  the runner's equivalent). Fails only when shuffled = proven order-dependent.
- **Sabotage** — break the code a test claims to guard (empty the function body, flip a
  boundary, invert a condition — pick the ONE sabotage most likely to expose a hollow
  test), run just the covering tests, expect red. Still green = the test asserts
  nothing. That's proof, not opinion.

Isolation discipline (absolute): the conductor and other reviewers are working on this
branch RIGHT NOW. Never sabotage or modify the shared tree. All destructive probes run
in a disposable worktree — `git worktree add <tmpdir> HEAD`, probe there,
`git worktree remove --force <tmpdir>` when done. To you, the shared tree is read-only.

The reading veins, in rough payoff order:
- **Cannot fail** — no assertions; assertions inside conditionals/catch blocks;
  un-awaited async assertions; trivial truths (defined-only, length-only);
  snapshot-only tests reflexively regenerated on every change.
- **Tautologies** — expected values computed by the same logic as the code under test,
  or the test importing the SUT's own helper to build its expectation.
- **Testing the mock** — assertions that only echo arguments the test itself passed;
  asserting a stub returns its stubbed value; mocking the module under test; mock setup
  longer than the test body. Cross-check `ac-pipeline/references/anti-patterns.md`'s unproven seam: a
  mocked boundary with no un-mocked test anywhere.
- **Flakiness precursors** — sleeps instead of polling, unseeded randomness, un-frozen
  clocks, real network in unit tests, shared mutable fixtures, order assertions on
  unordered collections, float equality.
- **Zombies** — skipped tests with no linked issue, commented-out tests, tests mocking
  modules this diff just removed or renamed.

Discipline: never nominate a test for deletion on reading alone — a sabotage probe that
stays green IS deletion-grade evidence. Probe-convicted cannot-fail tests and zombies:
`auto_fixable: true`. Over-mocked or tautological tests needing a rewrite:
`auto_fixable: false` — a bad rewrite destroys the only regression protection that code
has. State which probes you ran and their verdicts even when clean.

**SLUGS:** `hollow-test`, `testing-the-mock`, `tautological-test`, `flaky-test`,
`order-dependent-test`, `zombie-test`, `flakiness-precursor`

---

## contracts

- **ROLE:** `contracts`
- **SKILL_HINT:** *If project has API/type-convention skills:* `Read .claude/skills/<api-skill>/SKILL.md for contract patterns.`
- **EVIDENCE:** The promise (type/doc/name/API shape), the reality, and which one is right
- **SKIP:** Only when the diff touches **no exported surface** — no type/interface files, route handlers, exported function signatures, or docs. Otherwise spawn.

**METHOD:**

Every type signature, doc comment, API shape, and function name this diff adds or edits
is a promise. Broken promises are bugs that type-check. Hunt the gap between claim and
implementation; when claim and code disagree, judge which is right from apparent intent
and usage, and say so in the finding.

Also hunt **stubs**: placeholders, hardcoded returns, mocks, and TODO-shaped code
landing in production paths as if real — half-implemented features that fail quietly
instead of loudly.

For **untested promises**, think blast radius, not coverage percentage: where would a
silent regression in this diff's claims hurt most — auth, data integrity, money, user
data? For each gap, name the concrete test that would catch it.

**CHECKLIST:**

- Response shapes that don't match their declared types
- Documented parameters silently ignored
- Error responses that don't match the documented format; status codes that lie
- Function/endpoint names describing what the code used to do
- Stubs, hardcoded returns, or mock data in production paths
- Half-implemented features that fail quietly
- High-blast-radius promises with no test that would catch a silent regression

**SLUGS:** `contract-drift`, `lying-signature`, `doc-mismatch`, `ignored-parameter`,
`lying-status-code`, `stale-name`, `stub-in-production`, `untested-promise`
