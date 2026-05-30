# Tests Audit Checklist

**Purpose:** Comprehensive test quality verification for any web/mobile application
**Domain:** Unit tests, component tests, E2E tests, coverage, CI/CD reliability
**Tech Stack:** Vitest, React Testing Library, Playwright, MSW, TypeScript

---

## Quick Reference Commands

```bash
# Run all tests
pnpm test

# Coverage report
pnpm test:coverage

# CI mode (for reliability testing)
pnpm test:ci

# E2E tests
pnpm test:e2e
pnpm test:e2e:ui

# Test specific file
pnpm test path/to/test.test.ts

# Watch mode for development
pnpm test:watch

# Check for memory leaks
pnpm test -- --detectLeaks --runInBand

# Test performance
time pnpm test
```

---

## Tests Audit Items

### [TEST-001] Verify Overall Test Coverage

**Description:** Ensure test coverage meets 80% target across statements, branches, functions, lines
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** TEST-Coverage

**Verification:**

1. Run: `pnpm test:coverage`
2. Check coverage report output for overall percentages
3. Verify: Statements ≥80%, Branches ≥80%, Functions ≥80%, Lines ≥80%
4. Identify files with <60% coverage
5. Generate HTML report: open `coverage/lcov-report/index.html`

**Expected Output:** Overall coverage ≥80% in all categories

**Deliverable:** Coverage report with gaps identified

---

### [TEST-002] Audit Uncovered Critical Paths

**Description:** Identify critical business logic with insufficient test coverage
**Severity:** CRITICAL
**Auto-fixable:** NO
**Parallel Group:** TEST-Coverage

**Verification:**

1. Review coverage report for critical files
2. Check: primary service files, core business logic, auth flows
3. Verify critical paths have >90% coverage
4. Look for uncovered branches in error handling
5. Prioritize: authentication, data integrity, AI integration

**Expected Output:** Critical paths have >90% coverage

**Deliverable:** List of critical uncovered code with priority ranking

---

### [TEST-003] Verify Test Diamond Distribution

**Description:** Ensure test distribution follows diamond (more component tests, fewer unit/E2E)
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** TEST-Architecture

**Verification:**

1. Count tests by type: `find __tests__ -name "*.test.ts*" | grep -c "unit\|component\|integration\|e2e"`
2. Expected ratio: Unit (10-20%), Component (60-70%), Integration (10-20%), E2E (5-10%)
3. Check component tests use real database (not mocked)
4. Verify unit tests only for complex algorithms
5. Verify E2E tests only for critical user journeys

**Expected Output:** Test distribution follows diamond pattern

**Deliverable:** Test distribution analysis

---

### [TEST-004] Audit Test Naming Conventions

**Description:** Verify tests follow three-part naming: describe() → describe() → it()
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** TEST-Quality

**Verification:**

1. Review test files for consistent structure
2. Check pattern: `describe('[Unit]', () => describe('[Scenario]', () => it('should [behavior] when [condition]')))`
3. Verify test names are descriptive (not "test 1", "works")
4. Look for unclear test names
5. Check nesting doesn't exceed 3 levels

**Expected Output:** All tests follow naming convention

**Deliverable:** List of tests needing better names

---

### [TEST-005] Verify AAA Pattern (Arrange-Act-Assert)

**Description:** Ensure tests clearly separate setup, execution, and verification
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Quality

**Verification:**

1. Review 10-20 random test files
2. Check for clear Arrange section (setup)
3. Verify single Act operation (one thing being tested)
4. Check Assert section (expectations)
5. Look for tests mixing concerns (multiple acts)

**Expected Output:** Tests follow AAA pattern

**Deliverable:** Examples of unclear test structure

---

### [TEST-006] Audit Mock Usage (External Only)

**Description:** Verify only external dependencies mocked, not internal modules
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** TEST-Mocking

**Verification:**

1. Search for mocks: `grep -r "vi.mock" __tests__/ --include="*.ts"`
2. Categorize: external (API, services) vs internal (business logic)
3. Verify internal modules NOT mocked (test real code)
4. Check database uses test instance (not mocked)
5. Verify external APIs properly mocked (Anthropic, Upstash)

**Expected Output:** Only external dependencies mocked

**Deliverable:** List of incorrectly mocked internal modules

---

### [TEST-007] Verify Supabase Test Database Setup

**Description:** Ensure component tests use real Supabase test database
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** TEST-Integration

**Verification:**

1. Check `__tests__/setup/test-utils.tsx` for Supabase client
2. Verify using test environment variables
3. Check database is cleaned between tests
4. Test: run component tests, verify real DB queries
5. Verify no test pollution (tests don't affect each other)

**Expected Output:** Component tests use real Supabase test DB

**Deliverable:** Supabase test setup verification

---

### [TEST-008] Audit API Mocking Strategy

**Description:** Verify external HTTP requests are properly mocked (MSW or custom mocks)
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Mocking

**Verification:**

1. Check `vitest.setup.ts` for API mocking approach (MSW or custom Vitest mocks)
2. Verify mocks exist for external services: Anthropic API, Upstash Redis
3. Check mocks provide realistic response shapes
4. Test: API route tests should use mocked responses
5. Verify no real external calls during tests (check for unmocked requests)

**Expected Output:** External APIs properly mocked, approach documented

**Deliverable:** API mocking strategy audit report

**Note:** This project may use custom Vitest mocks instead of MSW. Either approach is valid as long as external calls are properly isolated.

---

### [TEST-009] Verify Test Cleanup (beforeEach/afterEach)

**Description:** Ensure proper test isolation with cleanup between tests
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** TEST-Reliability

**Verification:**

1. Check for `beforeEach(() => vi.clearAllMocks())` in test files
2. Verify database cleanup in component tests
3. Look for shared state between tests (global variables)
4. Test: run tests in random order, verify all pass
5. Check for timers cleanup: `vi.useRealTimers()` in afterEach

**Expected Output:** Tests properly isolated, no pollution

**Deliverable:** Add cleanup where missing

---

### [TEST-010] Audit Flaky Tests

**Description:** Identify tests that fail intermittently
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** TEST-Reliability

**Verification:**

1. Run tests multiple times: `for i in {1..10}; do pnpm test:ci; done`
2. Identify tests that fail some runs but not others
3. Check for race conditions (async timing)
4. Look for missing `waitFor()` in async tests
5. Verify proper use of `await` in test code

**Expected Output:** Zero flaky tests, 100% reliability

**Deliverable:** List of flaky tests with potential causes

---

### [TEST-011] Verify CI Test Reliability

**Description:** Ensure tests pass consistently in CI environment
**Severity:** CRITICAL
**Auto-fixable:** NO
**Parallel Group:** TEST-Reliability

**Verification:**

1. Run: `pnpm test:ci` (CI mode with limited workers)
2. Check for failures that don't occur locally
3. Verify tests don't timeout in CI (increase timeout if needed)
4. Check for CI-specific issues (env vars, parallel execution)
5. Review recent CI runs for failure patterns

**Expected Output:** Tests pass reliably in CI (>99% success rate)

**Deliverable:** CI reliability report with failure analysis

---

### [TEST-012] Audit Test Execution Speed

**Description:** Verify test suite runs in reasonable time (<30s for Vitest, <2min for Playwright)
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Performance

**Verification:**

1. Run: `time pnpm test` (should be <30s)
2. Run: `time pnpm test:e2e` (should be <2min)
3. Identify slow tests: `pnpm test --verbose | grep "ms)"`
4. Check for unnecessary waits or sleeps
5. Verify parallel execution enabled

**Expected Output:** Vitest <30s, Playwright <2min

**Deliverable:** Slow test optimization opportunities

---

### [TEST-013] Verify Playwright Test Organization

**Description:** Ensure E2E tests focus on critical user journeys only
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** TEST-E2E

**Verification:**

1. Count E2E tests: `find __tests__/e2e -name "*.spec.ts" | wc -l`
2. Verify <15 E2E tests (only critical paths)
3. Check tests cover: login, primary create flow, main dashboard, offline mode
4. Look for tests that should be component tests
5. Verify no duplication with lower-level tests

**Expected Output:** 5-15 E2E tests covering critical journeys

**Deliverable:** E2E test audit with optimization suggestions

---

### [TEST-014] Audit Playwright Test Reliability

**Description:** Ensure E2E tests don't have race conditions or timeouts
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** TEST-E2E

**Verification:**

1. Run: `pnpm test:e2e` multiple times
2. Check for timeout errors or race conditions
3. Verify proper use of `waitFor` selectors
4. Look for hardcoded sleeps (anti-pattern)
5. Check test data cleanup between runs

**Expected Output:** E2E tests pass reliably (>95%)

**Deliverable:** Fix flaky E2E tests

---

### [TEST-015] Verify React Testing Library Best Practices

**Description:** Ensure component tests use RTL queries correctly
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Component

**Verification:**

1. Review component tests for query usage
2. Prefer accessible queries: `getByRole`, `getByLabelText`
3. Avoid: `getByTestId` (last resort only)
4. Check for `screen.debug()` left in tests (remove)
5. Verify no direct DOM manipulation (use RTL utilities)

**Expected Output:** Component tests follow RTL best practices

**Deliverable:** List of tests using suboptimal queries

---

### [TEST-016] Audit User Event vs FireEvent Usage

**Description:** Verify using `userEvent` instead of `fireEvent` for interactions
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Component

**Verification:**

1. Search for `fireEvent`: `grep -r "fireEvent" __tests__/ --include="*.test.ts*"`
2. Check if `userEvent` is more appropriate
3. Verify `userEvent.setup()` called before interactions
4. Test async interactions use `await user.click()` etc.
5. Check for proper cleanup of userEvent instances

**Expected Output:** Prefer `userEvent` over `fireEvent`

**Deliverable:** Convert fireEvent to userEvent where appropriate

---

### [TEST-017] Verify Accessibility Testing in Components

**Description:** Ensure component tests include accessibility checks
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Component

**Verification:**

1. Review component tests for accessibility assertions
2. Check for ARIA attribute testing: `toHaveAttribute('aria-label')`
3. Verify role testing: `getByRole('button')`
4. Look for keyboard navigation tests
5. Consider adding jest-axe for automated a11y checks

**Expected Output:** Component tests include accessibility verification

**Deliverable:** Add accessibility tests where missing

---

### [TEST-018] Audit API Route Test Coverage

**Description:** Verify all API routes have comprehensive tests
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** TEST-API

**Verification:**

1. List API routes: `find app/api -name "route.ts"`
2. Check corresponding tests exist in `__tests__/api/`
3. Verify tests cover: success cases, error cases, validation, auth
4. Check for edge cases: malformed input, unauthorized access
5. Verify tests use request/response mocking

**Expected Output:** All API routes have comprehensive tests

**Deliverable:** List of untested or under-tested API routes

---

### [TEST-019] Verify Error Handling Test Coverage

**Description:** Ensure error paths are tested, not just happy paths
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** TEST-Error-Handling

**Verification:**

1. Review tests for try-catch coverage
2. Check database error scenarios tested
3. Verify API failure scenarios (network errors, 500s)
4. Test invalid input handling
5. Check user-facing error messages tested

**Expected Output:** Error paths have >80% coverage

**Deliverable:** List of untested error scenarios

---

### [TEST-020] Audit Snapshot Test Usage

**Description:** Verify snapshot tests used sparingly and appropriately
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** TEST-Quality

**Verification:**

1. Find snapshots: `find __tests__ -name "*.snap"`
2. Check if snapshots are valuable (not brittle)
3. Verify snapshots for: complex data structures, API responses
4. Avoid: large component snapshots (prefer explicit assertions)
5. Check snapshots are reviewed (not blindly updated)

**Expected Output:** Minimal, valuable snapshot usage

**Deliverable:** Remove or replace brittle snapshots

---

### [TEST-021] Verify Test Data Factories

**Description:** Ensure reusable test data helpers exist and are used
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Quality

**Verification:**

1. Check for test data factories: `__tests__/fixtures/` or similar
2. Verify factories for: users, primary domain entities, secondary records
3. Look for repeated test data setup (DRY violation)
4. Check factories provide realistic data
5. Verify factories are easy to customize

**Expected Output:** Test data factories reduce duplication

**Deliverable:** Create or improve test data factories

---

### [TEST-022] Audit Test Documentation

**Description:** Verify complex tests have explanatory comments
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** TEST-Quality

**Verification:**

1. Review complex test files
2. Check for comments explaining non-obvious setup
3. Verify "why" is documented (not just "what")
4. Look for TODO comments indicating incomplete tests
5. Check test file has purpose comment at top

**Expected Output:** Complex tests are well-documented

**Deliverable:** Add comments to unclear tests

---

### [TEST-023] Verify No Skipped Tests

**Description:** Ensure no tests are skipped without justification
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** TEST-Coverage

**Verification:**

1. Search for skipped tests: `grep -r "test.skip\|it.skip\|describe.skip" __tests__/`
2. Check for justification comments
3. Verify skipped tests have GitHub issues
4. Test: unskip and check if tests pass
5. Remove or fix permanently skipped tests

**Expected Output:** No skipped tests, or justified with issues

**Deliverable:** Fix or document skipped tests

---

### [TEST-024] Audit Test Environment Configuration

**Description:** Verify Vitest and Playwright configurations are optimal
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Configuration

**Verification:**

1. Check `vitest.config.mts` for correct settings
2. Verify `testEnvironment: 'jsdom'` for component tests
3. Check coverage thresholds configured: 80% for all metrics
4. Review `playwright.config.ts` for proper setup
5. Verify environment variables loaded correctly

**Expected Output:** Test configurations optimized

**Deliverable:** Test config optimization recommendations

---

### [TEST-025] Verify Memory Leak Detection

**Description:** Ensure tests don't have memory leaks
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** TEST-Performance

**Verification:**

1. Run: `pnpm test -- --detectLeaks --runInBand`
2. Check for leak warnings in output
3. Identify tests with leaked memory
4. Look for missing cleanup (event listeners, timers)
5. Verify proper unmounting in component tests

**Expected Output:** No memory leaks detected

**Deliverable:** Fix tests with memory leaks

---

### [TEST-026] Audit Console Error/Warning Suppression

**Description:** Verify expected errors are suppressed, unexpected ones fail tests
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Quality

**Verification:**

1. Check `vitest.setup.ts` for console error handling
2. Verify expected React warnings suppressed
3. Check unexpected console.errors fail tests
4. Test: trigger error, verify test fails
5. Review suppression list for outdated entries

**Expected Output:** Proper console error handling

**Deliverable:** Update console error suppression logic

---

### [TEST-027] Verify Timezone Handling in Tests

**Description:** Ensure date/time tests work in any timezone
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Reliability

**Verification:**

1. Find date/time tests: `grep -r "Date\|format\|parse" __tests__/ --include="*.test.ts*"`
2. Check for hardcoded timezone assumptions
3. Verify using `date-fns` with explicit timezone
4. Test: run tests in different timezone (TZ=America/New_York)
5. Check mock dates use explicit timezone

**Expected Output:** Date/time tests timezone-independent

**Deliverable:** Fix timezone-dependent tests

---

### [TEST-028] Audit Database Seed Data Quality

**Description:** Verify test database seed data is realistic and comprehensive
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Integration

**Verification:**

1. Check `scripts/db-seed.ts` for seed data
2. Verify seed data covers: all relevant categories/states, edge cases, empty states
3. Check seed data is realistic (not "test user 1")
4. Verify seed script is idempotent (can run multiple times)
5. Test: run seed, verify app works with seed data

**Expected Output:** High-quality, realistic seed data

**Deliverable:** Improve seed data quality

---

### [TEST-029] Verify Test Code Coverage Excludes

**Description:** Ensure coverage excludes appropriate files (types, config, etc.)
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** TEST-Coverage

**Verification:**

1. Check `vitest.config.mts` for `coveragePathIgnorePatterns`
2. Verify excludes: `node_modules`, `__tests__`, `.next`, type files
3. Check excludes: config files, generated files
4. Review coverage report for noise (excluded files showing)
5. Verify important files NOT excluded

**Expected Output:** Coverage focuses on testable code

**Deliverable:** Update coverage excludes

---

### [TEST-030] Audit Code Coverage Reporting

**Description:** Verify coverage reports are generated and reviewed
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** TEST-Coverage

**Verification:**

1. Run: `pnpm test:coverage`
2. Check HTML report generated: `coverage/lcov-report/index.html`
3. Verify report highlights uncovered lines
4. Check if coverage tracked in CI (GitHub Actions)
5. Verify coverage trends monitored over time

**Expected Output:** Coverage reports actionable and monitored

**Deliverable:** Coverage reporting process documentation

---

### [TEST-031] Visual Regression Testing Setup

**Description:** Implement Playwright snapshot testing for automated visual regression (CI), distinct from agent-browser for manual visual review
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-E2E

**Verification:**

1. Setup Playwright snapshot testing for **automated regression tests** (CI pipeline)
2. Ensure consistent environment (same OS, browser, GPU)
3. Freeze dynamic content (timestamps, random IDs)
4. Mask user-specific data
5. Configure tolerances (threshold, maxDiffPixels)
6. Preload fonts, disable animations for stability

**Expected Output:** Visual regression tests stable and deterministic (automated CI)

**Deliverable:** Visual regression testing infrastructure

**Note:** For **manual visual review** and ad-hoc UI inspection, use agent-browser (see ui-audit.md). Playwright snapshots are for automated regression detection in CI, not for visual design review or accessibility checks.

---

### [TEST-032] Security Test Coverage Requirements

**Description:** Verify comprehensive security test coverage for critical attack vectors
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** TEST-Security

**Verification:**

1. Auth bypass: 100% (missing token, expired, invalid)
2. Input validation: 90% (XSS vectors, SQL patterns)
3. Rate limiting: 100% (burst, sustained, bypass attempts)
4. SSRF: 100% (internal IPs, metadata, DNS rebinding, IPv6)
5. Session security: 100% (expiry, refresh, cookie flags)

**Expected Output:** Security test coverage meets thresholds

**Deliverable:** Security test coverage report with gaps

---

### [TEST-033] Performance Regression Testing

**Description:** Implement automated performance thresholds in CI
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** TEST-Performance

**Verification:**

1. Bundle size thresholds in CI (fail if >10% increase)
2. LCP budget (<2.5s) enforcement
3. Database query performance (<500ms) tests
4. Memory leak detection in test suite
5. Track performance trends over time

**Expected Output:** CI enforces performance budgets

**Deliverable:** Performance regression test implementation

---

### [TEST-034] Mutation Testing Quality

**Description:** Implement mutation testing to detect dead tests
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Quality

**Verification:**

1. Setup Stryker for mutation testing
2. Run mutation tests on critical paths
3. Detect dead tests (tests that never fail when code mutated)
4. Track assertion density
5. Require 100% mutation coverage on critical paths

**Expected Output:** Mutation testing reveals test quality issues

**Deliverable:** Mutation testing setup and baseline

---

### [TEST-035] CI Pipeline Optimization

**Description:** Optimize CI test execution for speed and reliability
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-CI

**Verification:**

1. Implement test parallelization (reduce time)
2. Smart test selection (only affected tests)
3. Fail fast: security tests run first
4. Enable trace on first retry (debugging aid)
5. Monitor CI test execution time trends

**Expected Output:** CI tests run <2 minutes, optimized ordering

**Deliverable:** CI pipeline optimization implementation

---

### [TEST-036] Implement Claude API Mocking for AI Features

**Description:** Mock AI responses for deterministic testing of AI-powered features
**Severity:** CRITICAL
**Auto-fixable:** YES
**Parallel Group:** TEST-Mocking

**Verification:**

1. Create mock handlers for your app's AI/LLM API routes (e.g. image-analysis, content-generation, classification)
2. Mock location: `__tests__/mocks/anthropic.ts` or MSW handlers
3. Verify mock responses match actual Zod schemas (e.g. AnalysisResult, etc.)
4. Test error scenarios: rate limit (429), invalid response, timeout, malformed JSON
5. Verify no real API calls during test suite: `grep -r "ANTHROPIC_API_KEY" .env.test`
6. Check test isolation: mocks reset between tests

**Expected Output:** AI routes testable without real API calls, error scenarios covered

**Deliverable:** Claude API mock implementation with realistic response shapes

**Example Mock:**

```typescript
// __tests__/mocks/anthropic.ts
export const mockAnalysisResult = {
  items: [{ name: 'example-item', category: 'a', confidence: 0.95 }],
  label: 'Example Result',
  total_confidence: 0.92,
};
```

---

### [TEST-037] Service Worker Functionality Tests

**Description:** Verify service worker caching and offline behavior (PWA shipped commit 08b6a31)
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** TEST-E2E

**Verification:**

1. Test service worker registration succeeds: `navigator.serviceWorker.ready`
2. Verify cache strategies: cache-first for static, network-first for API
3. Test offline fallback page serves correctly
4. Verify cache invalidation on app update (version bump)
5. Use Playwright with service worker context: `context.serviceWorkers()`
6. Test: go offline mid-session, verify graceful degradation

**Expected Output:** SW registration, caching, and offline all tested

**Deliverable:** Service worker test suite in `__tests__/e2e/service-worker.spec.ts`

**Reference:** PWA shipped but no SW tests exist - critical gap

---

### [TEST-038] Automated Accessibility Testing in CI

**Description:** Run axe-core accessibility scans in CI pipeline
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** TEST-Accessibility

**Verification:**

1. Install: `pnpm add -D @axe-core/playwright`
2. Add to Playwright tests: `await expect(page).toHaveNoViolations()`
3. Configure axe rules: WCAG 2.1 AA level
4. Run on critical pages: login, dashboard, primary create flow, settings
5. Set CI to fail on critical/serious violations
6. Generate accessibility report artifact

**Expected Output:** axe-core runs in CI, catches 57% of WCAG issues automatically

**Deliverable:** Playwright accessibility tests with axe-core integration

**Example Test:**

```typescript
import AxeBuilder from '@axe-core/playwright';

test('dashboard has no accessibility violations', async ({ page }) => {
  await page.goto('/app');
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations).toEqual([]);
});
```

**Reference:** axe-core catches 57% of WCAG issues automatically

---

### [TEST-039] Test Data Factory Minimal Defaults

**Description:** Enforce minimal defaults pattern in test factories
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** TEST-Quality
**Blocked By:** [TEST-021]

**Verification:**

1. Review `__tests__/fixtures/` for factory patterns
2. Check factories use minimal required fields only
3. Verify no unnecessary associations (e.g. user → records when not needed)
4. Check factories are customizable via overrides
5. Verify realistic but minimal data (not "test user 1")
6. Test: create entity with factory, verify only essential fields populated

**Expected Output:** Factories follow minimal defaults principle

**Deliverable:** Refactored test factories with minimal, customizable defaults

**Reference:** Research shows over-specified factories slow tests and hide bugs

---

## Summary Template

After completing audit items, generate this summary:

```markdown
## Tests Audit Summary

**Date:** YYYY-MM-DD
**Auditor:** [Name/Tool]
**Scope:** [App Name] - Full Test Suite

### Test Coverage Metrics

| Category   | Current | Target | Status   |
| ---------- | ------- | ------ | -------- |
| Statements | XX%     | ≥80%   | ✅/⚠️/❌ |
| Branches   | XX%     | ≥80%   | ✅/⚠️/❌ |
| Functions  | XX%     | ≥80%   | ✅/⚠️/❌ |
| Lines      | XX%     | ≥80%   | ✅/⚠️/❌ |

### Test Distribution (Diamond)

| Test Type   | Count | Percentage | Target |
| ----------- | ----- | ---------- | ------ |
| Unit        | X     | XX%        | 10-20% |
| Component   | X     | XX%        | 60-70% |
| Integration | X     | XX%        | 10-20% |
| E2E         | X     | XX%        | 5-10%  |
| **Total**   | **X** | **100%**   | -      |

### Test Reliability

| Metric          | Value | Target | Status   |
| --------------- | ----- | ------ | -------- |
| Flaky Tests     | X     | 0      | ✅/⚠️/❌ |
| CI Success Rate | XX%   | >99%   | ✅/⚠️/❌ |
| Skipped Tests   | X     | 0      | ✅/⚠️/❌ |

### Test Performance

| Metric           | Duration | Target | Status   |
| ---------------- | -------- | ------ | -------- |
| Vitest Suite     | XX.Xs    | <30s   | ✅/⚠️/❌ |
| Playwright Suite | XX.Xs    | <120s  | ✅/⚠️/❌ |
| Total Test Time  | XX.Xs    | <150s  | ✅/⚠️/❌ |

### Findings by Severity

| Severity | Count | Auto-fixable |
| -------- | ----- | ------------ |
| CRITICAL | X     | Y            |
| HIGH     | X     | Y            |
| MEDIUM   | X     | Y            |
| LOW      | X     | Y            |
| INFO     | X     | Y            |

### Critical Coverage Gaps

**High-priority untested code:**

1. [File/function 1] - [Coverage %] - [Risk level]
2. [File/function 2] - [Coverage %] - [Risk level]
3. [File/function 3] - [Coverage %] - [Risk level]

### Recommendations

**Immediate (Critical/High):**

1. [Finding 1] - [Impact on reliability]
2. [Finding 2] - [Impact on reliability]

**Short-term (Medium):**

1. [Finding 1]
2. [Finding 2]

**Long-term (Low/Info):**

1. [Finding 1]

### Next Steps

1. Address CRITICAL coverage gaps immediately
2. Fix flaky tests to improve CI reliability
3. Optimize slow tests for faster feedback
4. Document accepted risks for unfixable issues
```
