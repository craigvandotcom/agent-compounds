# Review Dimensions

Three lenses, one bar, three bins. A review runs by hand over a range the operator
names (`ac-review <range>`) — one reviewer per lens: **correctness**, **test-quality**,
and one **risk** lens the diff chooses (security or contracts). A reviewer that cannot
clear the bar reports nothing; an empty report is the expected result.

## The bar

A finding is reportable only as a **demonstrated failure in ordinary operation**, or a
**violated acceptance criterion**, with a **reproducing command** anyone can re-run.

- **"Could be bypassed" counts only against a real adversary** — user input, auth,
  external data, PII, money. Never our own worker, never a cooperative operator, never
  a state only a hostile setup reaches.
- **The probe may not set up state a cooperative worker or a real user would not
  produce.** A precondition nobody reaches in ordinary operation is not a defect.
- Everything else — a hypothetical, a hardening idea, a preference — is not a finding.

## The three bins

Every candidate finding routes to exactly one bin:

| bin | what it is | where it goes |
|---|---|---|
| **Defect** | the bar is met — a demonstrated failure or a violated AC, with the reproducing command | a bead; the `impact:` label carries the demonstration |
| **Hardening** | real but not demonstrated, or reachable only through a contrived precondition | one line in the report — **never** a bead |
| **Nothing** | the lens checked and found nothing | ACCEPT, one line saying what was checked |

A finding that survives the verify round becomes a bead whose acceptance-criterion probe
IS the reproducing command, and its fix is checked by re-running that command — never by
a second review. A fix that adds a guard, mode or option waits for the operator through
the existing human-gate DECISION bead; a fix that deletes does not ask.

## The lenses

Each lens fills the `{...}` placeholders in `reviewer-prompt-template.md` from its block
below. A reviewer that dies is re-spawned ONCE; a spawned lens with no output file is a
partial failure, never a silent pass.

---

## correctness — against the plan and the bead ACs

- **ROLE:** `correctness`
- **SKILL_HINT:** *If project has testing skills:* `Read .claude/skills/<testing-skill>/SKILL.md for test patterns.`
- **EVIDENCE:** What you traced, the scenario that breaks, expected vs actual — or the plan clause the diff contradicts

**METHOD:**

Two moves. (1) **Plan fidelity and causal sufficiency.** Read the plan's `## Vision`
and `## Out of scope`; flag any diff in range that breaks them, with one mechanical
probe — net line change on the epic's named files after the plan's last deliverable
commit. Then, for every bead the range closes, ask whether THIS diff produces that
GREEN: a token meeting its grep is not the thing the AC describes, and the probe may
have flipped for another cause (a sibling's commit, an already-green AC). (2)
**Invariant analysis and absence.** List what must ALWAYS be true for the modules this
diff touches, then build the scenario that violates it; hunt the code that doesn't
exist — the error path never written, the cleanup never triggered, the rollback that
isn't there.

**YAGNI (moved here from the retired architecture lens):** does the diff add machinery
the plan did not ask for and no caller needs? A plan to remove things cannot quietly
grow. Fix order is delete > simplify > tighten an instruction > add code.

**LOOK FOR:**

- Logic errors and off-by-one mistakes; silent failures (wrong results, no error)
- Race conditions on shared state; null/undefined hazards
- Error paths that swallow exceptions; missing cleanup, stale closures
- Edge cases not handled (empty arrays, zero values, unicode)
- The plan clause the diff contradicts; net growth on the plan's named files

**SLUGS:** `logic-error`, `off-by-one`, `race-condition`, `null-hazard`,
`swallowed-exception`, `missing-edge-case`, `stale-closure`, `missing-cleanup`,
`missing-error-path`, `missing-validation`, `plan-drift`, `unproven-causation`

---

## test-quality — fixture-shape validity and mutation probes

- **ROLE:** `test-quality`
- **SKILL_HINT:** *If project has testing skills:* `Read .claude/skills/<testing-skill>/SKILL.md for test patterns.`
- **EVIDENCE:** What the test claims to guard, and the proof — the probe result (e.g. "emptied calculateTotal; every covering test stayed green") or the specific reading

**METHOD:**

Audit whether the tests this diff adds or changes are worth anything. A bad test is
worse than no test — it costs runtime and buys false confidence.

Read first, experiment second: shortlist suspects, then spend a capped probe budget —
**max ~5 probes**. Reading nominates; probes convict.

- **Fixture-shape validity.** Could each test's fixtures EXIST in production? A test
  over a row, state or input the pipeline can never persist asserts nothing; a suite
  that is green, mutation-sensitive and built on an impossible fixture is worthless
  anyway.
- **Sabotage.** Break the code a test claims to guard (empty the body, flip a boundary,
  invert a condition — the ONE sabotage most likely to expose a hollow test), run the
  covering tests, expect red. Still green = the test asserts nothing. That is proof,
  not opinion.
- **Rerun / shuffle.** A test that flips on identical code is flaky; one that fails
  only under `--sequence.shuffle` is order-dependent.
- **Cannot-fail and tautology.** No assertions; assertions inside conditionals or catch
  blocks; un-awaited async assertions; expected values computed by the SUT's own logic;
  assertions that only echo arguments the test itself passed.

**Isolation (absolute):** the shared tree is read-only to you. Destructive probes run
in a disposable worktree — `git worktree add <tmpdir> HEAD`, probe there,
`git worktree remove --force <tmpdir>` when done. Never `git stash` from a worktree
(it lands in the shared repo).

**No probe, no bead.** A test or guard may be reported as a Defect only when `evidence`
carries the mutation probe showing the guard cannot fail: revert the fix or delete the
guarded line, and the suite still passes. Without that probe, report nothing.

**SLUGS:** `hollow-test`, `impossible-fixture`, `testing-the-mock`, `tautological-test`,
`flaky-test`, `order-dependent-test`, `zombie-test`

---

## risk — security or contracts, chosen by the diff

Pick ONE risk lens by what the diff touches, never by habit:

- **security** when the diff touches a trust boundary — user input, auth, external
  data (APIs, webhooks, AI responses, file uploads), PII, money.
- **contracts** when the diff touches an exported surface — types, interfaces, route
  handlers, exported function signatures, docs.
- Neither, when the diff touches neither: report nothing rather than manufacture a lens.

### security

- **ROLE:** `security`
- **SKILL_HINT:** *If project has security skills:* `Read .claude/skills/<security-skill>/SKILL.md for security patterns.`
- **EVIDENCE:** The trust boundary, the concrete attack path (actor → entry point → what they gain), and the command that walks it

**METHOD:** Map the trust boundaries this diff touches FIRST — where user input enters,
where external data crosses into the system, where authentication becomes authorization —
then walk them like an attacker with source access. Follow the data, not the checklist:
the real finding is usually the boundary nobody thought of as a boundary. A finding must
be exploitable with a concrete path — name the actor, the entry point, and what they get.
**The bar applies here too:** a bypass reachable only by our own worker under a state a
real user never produces is Hardening, not a Defect.

**SLUGS:** `sql-injection`, `xss`, `csrf`, `ssrf`, `authz-bypass`, `secret-exposure`,
`pii-leak`, `unvalidated-input`, `insecure-default`, `vulnerable-dependency`

### contracts

- **ROLE:** `contracts`
- **SKILL_HINT:** *If project has API/type-convention skills:* `Read .claude/skills/<api-skill>/SKILL.md for contract patterns.`
- **EVIDENCE:** The promise (type/doc/name/API shape), the reality, and which one is right

**METHOD:** Every type signature, doc comment, API shape, and function name this diff
adds or edits is a promise. Broken promises are bugs that type-check. Hunt the gap
between claim and implementation; when claim and code disagree, judge which is right
from apparent intent and usage, and say so. Also hunt **stubs** — placeholders,
hardcoded returns, mocks and TODO-shaped code landing in production paths as if real.

**LOOK FOR:** Response shapes that don't match their declared types · documented
parameters silently ignored · error responses that don't match the documented format ·
names describing what the code used to do · stubs in production paths ·
high-blast-radius promises with no test that would catch a silent regression

**SLUGS:** `contract-drift`, `lying-signature`, `doc-mismatch`, `ignored-parameter`,
`lying-status-code`, `stale-name`, `stub-in-production`, `untested-promise`
