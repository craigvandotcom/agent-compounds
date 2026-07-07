# Review Dimensions

The four reviewers. Each fills the placeholders in `reviewer-prompt-template.md`.
Spawn all four in parallel (one message, four Task calls).

---

## security

- **ROLE:** `security`
- **SKILL_HINT:** *If project has security skills:* `Read .claude/skills/<security-skill>/SKILL.md for security patterns.`
- **EVIDENCE:** What you read, what's wrong, why it's exploitable

**CHECKLIST:**

- OWASP Top 10 vulnerabilities (injection, XSS, CSRF, SSRF)
- Auth/authz bypass opportunities
- Hardcoded secrets or credentials
- Data exposure risks (PII leaks, verbose errors)
- Input validation gaps at system boundaries
- Insecure defaults (permissive CORS, missing rate limits)
- Dependency vulnerabilities (known CVEs in new deps)

---

## performance

- **ROLE:** `performance`
- **SKILL_HINT:** *If project has performance skills:* `Read .claude/skills/<perf-skill>/SKILL.md for optimization patterns.`
- **EVIDENCE:** What you measured/traced, why it's slow, what the impact is

**CHECKLIST:**

- N+1 queries or sequential awaits (waterfalls)
- Missing caching opportunities
- Unnecessary re-renders or recomputations
- Heavy imports that should be lazy/dynamic
- Missing pagination or unbounded queries
- Inefficient algorithms (O(n^2) where O(n) suffices)
- Bundle size impact (barrel imports, large deps)
- Missing indexes on queried columns

---

## architecture

- **ROLE:** `architecture`
- **SKILL_HINT:** *If project has architecture/coding skills:* `Read .claude/skills/<arch-skill>/SKILL.md for patterns.`
- **EVIDENCE:** What pattern is broken, how it deviates from codebase conventions

**CHECKLIST:**

- Pattern misalignment with existing codebase
- Single Responsibility Principle violations
- YAGNI violations (over-engineering, premature abstraction)
- Tight coupling between modules
- Circular dependencies or import cycles
- Wrong abstraction level (under/over-abstraction)
- Missing error handling at system boundaries
- Naming inconsistencies

Also hunt the three named anti-patterns in `_shared/anti-patterns.md` (evidence
destruction, coordinated workaround, unproven seam) — shared with ac-hygiene's
structural lens.

---

## correctness

- **ROLE:** `correctness`
- **SKILL_HINT:** *If project has testing skills:* `Read .claude/skills/<testing-skill>/SKILL.md for test patterns.`
- **EVIDENCE:** What you traced, the scenario that breaks, expected vs actual behavior

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

Also hunt the three named anti-patterns in `_shared/anti-patterns.md` (evidence
destruction, coordinated workaround, unproven seam) — shared with ac-hygiene's
bug-hunter lens.
</content>
