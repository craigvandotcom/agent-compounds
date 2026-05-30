---
name: testing
description: Use when writing tests for TypeScript/Next.js code. Handles unit tests (Vitest), component tests (RTL), integration tests, and E2E tests (Playwright). Triggers on test, spec, coverage, mock, assertion.
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across all neoMeta apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# TypeScript Testing Skill

**Purpose:** Guide writing high-quality tests for the body-compass-app
**Stack:** Vitest, React Testing Library, Playwright, MSW, TypeScript

---

## When to Use This Skill

**Intent Triggers:**

- Writing new tests for components, hooks, or API routes
- Fixing failing tests or improving test coverage
- Adding integration or E2E tests
- Setting up mocks for external dependencies

**When NOT to Use:**

- General TypeScript questions (not testing-related)
- Production code without testing component

---

## Testing Architecture

### The Testing Diamond

```
        /\
       /E2E\        3-10 tests (production risks only)
      /------\
     /Component\    Majority of tests (real DB, mock externals)
    /------------\
   /   Unit       \  Complex algorithms only
  /----------------\
```

### Test Types & Locations

| Type        | Location                   | Tool         | Purpose                                |
| ----------- | -------------------------- | ------------ | -------------------------------------- |
| Unit        | `__tests__/unit/`          | Vitest       | Pure functions, utilities, algorithms  |
| Script unit | `__tests__/unit/<domain>/` | Vitest       | Exported functions from `scripts/*.ts` |
| Component   | `__tests__/components/`    | Vitest + RTL | React components with mocked deps      |
| Integration | `__tests__/integration/`   | Vitest       | API routes, middleware, DB operations  |
| API         | `__tests__/api/`           | Vitest       | Route handlers, request/response       |
| E2E         | `__tests__/e2e/`           | Playwright   | User journeys, critical paths          |

**Script tests:** Scripts that export testable functions (e.g., `runBatch`) go in `__tests__/unit/<domain>/`. Guard `main()` with `if (require.main === module)`.

**Feature-scoped component tests** are co-located: `features/<domain>/components/__tests__/`. Shared component tests: `components/<category>/__tests__/`. The top-level `__tests__/` directory is for unit tests (`unit/`), integration tests (`integration/`), API route tests (`api/`), and E2E tests (`e2e/`).

**Test location quick rule:** Uses `render()` + RTL DOM assertions → co-located `__tests__/` next to the component (feature or shared). Uses `renderHook()` only OR no React rendering → `__tests__/unit/`. When in doubt, follow the location of the nearest similar test.

---

## Core Patterns

### 1. Test Naming (Three-Part Convention)

```typescript
describe('[Unit Under Test]', () => {
  describe('[Scenario/Method]', () => {
    it('should [expected behavior] when [condition]', () => {
      // AAA pattern
    });
  });
});
```

### 2. AAA Pattern (Arrange-Act-Assert)

```typescript
it('should validate JPEG magic numbers', () => {
  // Arrange
  const jpegData = btoa('\xFF\xD8\xFF\xE0');
  const file = `data:image/jpeg;base64,${jpegData}`;

  // Act
  const result = validateMagicNumbers(file, 'image/jpeg');

  // Assert
  expect(result).toBe(true);
});
```

### 3. Component Testing with RTL

```typescript
import { render, screen, waitFor } from '@/__tests__/setup/test-utils';
import userEvent from '@testing-library/user-event';

it('should submit form without blocking', async () => {
  const user = userEvent.setup();
  render(<FoodEntryForm onAddFood={mockOnAddFood} />);

  // Autocomplete inputs render as role="combobox", not role="textbox"
  const input = screen.getByRole('combobox');
  await user.type(input, 'Spinach');
  await user.keyboard('{Enter}');

  const saveButton = screen.getByRole('button', { name: /add food/i });
  await user.click(saveButton);

  await waitFor(() => {
    expect(mockOnAddFood).toHaveBeenCalled();
  });
});
```

### 4. Mocking Strategy

**Mock EXTERNAL, test INTERNAL:**

| Mock                 | Don't Mock             |
| -------------------- | ---------------------- |
| External APIs        | Business logic         |
| Third-party services | Database (use test DB) |
| Upstash/Redis        | Internal modules       |
| Next.js navigation   | State management       |

**One factory per mock target per file.** Build a single flexible `makeMockSupabase(opts)` factory with sensible defaults rather than multiple specialized factories. Use an options object so individual tests can override specific behaviors. Avoid creating a second factory for edge cases — extend the first.

**Standard mock patterns:**

```typescript
// Mock service
vi.mock('@/lib/services/food-submission', () => ({
  processFoodSubmission: vi.fn(),
}));

// Mock Next.js router
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

// Supabase chainable mock — split read/write helpers with vi.hoisted()
const { mockFrom, mockSelect, mockUpdate } = vi.hoisted(() => ({
  mockFrom: vi.fn(),
  mockSelect: vi.fn(),
  mockUpdate: vi.fn(),
}));

function setupReadChain(opts: { data?: unknown[]; count?: number }) {
  const chain = {
    select: mockSelect.mockReturnValue({
      order: vi.fn().mockReturnValue({
        order: vi.fn().mockReturnValue({
          range: vi.fn().mockResolvedValue({
            data: opts.data ?? [], error: null, count: opts.count ?? 0,
          }),
        }),
      }),
    }),
  };
  mockFrom.mockReturnValue(chain);
}

function setupWriteChain(opts: { data?: unknown }) {
  mockFrom.mockReturnValue({
    update: mockUpdate.mockReturnValue({
      eq: vi.fn().mockReturnValue({
        select: vi.fn().mockReturnValue({
          single: vi.fn().mockResolvedValue({ data: opts.data, error: null }),
        }),
      }),
    }),
  });
}

// Sequential mock for routes with multiple from() calls (e.g., pre-flight + write)
function setupPreflightAndWrite(opts: {
  preflight: { data: unknown };
  write: { data: unknown };
}) {
  let callIndex = 0;
  mockFrom.mockImplementation(() => {
    callIndex++;
    if (callIndex === 1) {
      return {
        select: vi.fn().mockReturnValue({
          eq: vi.fn().mockReturnValue({
            single: vi.fn().mockResolvedValue({
              data: opts.preflight.data, error: null,
            }),
          }),
        }),
      };
    }
    return {
      update: mockUpdate.mockReturnValue({
        eq: vi.fn().mockResolvedValue({ data: opts.write.data, error: null }),
      }),
    };
  });
}
// Reset callIndex via vi.clearAllMocks() in beforeEach

// API route tests: dynamic import per-test prevents mock state leakage
it('should return 200 with list', async () => {
  setupReadChain({ data: [...], count: 5 });
  const { GET } = await import('@/app/api/admin/ingredients/route');
  const res = await GET(createMockRequest('/api/admin/ingredients'));
  // ...assertions
});

// Note: apiFetch (from @/lib/utils/api-client) calls global fetch internally.
// vi.stubGlobal('fetch', mockFetch) works transparently — use apiFetch in
// production code (required by lint rule), stub fetch in tests. No special mock needed.
```

### 5. Live HTTP / SDK Integration Tests

Any test file that makes real HTTP calls via a Node.js SDK (OpenAI, OpenRouter, Supabase service-role client, etc.) **MUST** start with `// @vitest-environment node` as the first line.

Without it, Vitest defaults to `happy-dom` (browser-like). SDKs that detect a browser environment will either reject initialization OR silently return a fallback response — the test passes but never calls the real service. The failure mode is a **silent green run**, not a thrown error.

```typescript
// @vitest-environment node  ← REQUIRED for any live SDK/HTTP test

import { describe, it, expect } from 'vitest';
import { checkCompound } from '@/lib/services/compound-check';

describe.skipIf(!process.env.OPENROUTER_API_KEY)('live model check', () => {
  // ...
});
```

Existing examples in this repo: `__tests__/integration/compound-check-golden.test.ts`, `__tests__/integration/diagnose-script-audit.test.ts`, `__tests__/integration/ingredient-lifecycle-reliability.test.ts`, `__tests__/integration/environment.test.ts`.

If a live integration test passes deterministically but the underlying SDK should be making network calls, suspect this annotation is missing.

### Admin API Route Pattern (Repeated Structure)

Admin PATCH/POST routes in `app/api/admin/ingredients/[slug]/` follow this order:

1. Auth: `checkAdminAuth({ rateLimitKey: '<route>', maxPerMin: 30 })`
2. Slug validation: `/^[a-z0-9-]{1,200}$/` → 404 if invalid
3. Body parse + zod validation → 400 if missing/invalid
4. Domain validation: check value against known vocabulary/enum → 400 if unknown
5. Fetch ingredient: `.from('canonical_ingredients').select('*').eq('slug', slug).single()` → 404
6. Pipeline guard: reject if `processing | zone_complete | tags_complete` → 409
7. Mutate: update `research_output` nested field + set `manual_override = true`
8. Return: structured response with `{ updated_item, changed_flag, current_state }`

Test pattern: `vi.hoisted()` + `setupReadChain()`/`setupWriteChain()` + per-test dynamic `import()`.
Reference: `gates/route.ts`, `tags/route.ts`, `retrigger/route.ts`.

---

## Quick Reference

### File Structure

```
__tests__/
  setup/
    vitest.setup.ts    # Global mocks, polyfills
    test-utils.tsx     # Custom render, providers
  unit/                # Pure function tests
  components/          # React component tests
  integration/         # Multi-module tests
  api/                 # Route handler tests
  e2e/                 # Playwright tests
```

### Test Scripts

```bash
pnpm test              # Affected files only (vitest-affected plugin)
pnpm test:one <file>   # Single file (plugin disabled, fastest)
pnpm test:all          # Full suite (plugin disabled)
pnpm test:watch        # Watch mode
pnpm test:coverage     # With coverage report
pnpm test:ci           # CI mode (coverage, limited workers)
pnpm test:e2e          # Playwright E2E tests
```

> **NEVER run `npx vitest` directly.** All `pnpm test*` commands route
> through `scripts/test.sh` which sets `--max-old-space-size=2048`.
> Without this cap, Vite's transform engine can balloon to 12GB+ and
> trigger the kernel cgroup OOM killer, killing the entire tmux pane.

### RTL Queries (Priority Order)

```typescript
// 1. Accessible queries (preferred)
screen.getByRole('button', { name: /submit/i });
screen.getByLabelText(/email/i);
screen.getByPlaceholderText(/search/i);
screen.getByText(/welcome/i);

// 2. Semantic queries
screen.getByAltText(/logo/i);

// 3. Test IDs (last resort)
screen.getByTestId('custom-element');
```

---

## Supporting Documentation

| File                           | When to Read                              |
| ------------------------------ | ----------------------------------------- |
| `workflows/unit-test.md`       | Writing unit tests for utilities          |
| `workflows/component-test.md`  | Testing React components                  |
| `workflows/api-test.md`        | Testing API route handlers                |
| `workflows/e2e-test.md`        | Writing Playwright E2E tests              |
| `reference/best-practices.md`  | Testing principles from goldbergyoni      |
| `reference/mocking-guide.md`   | Advanced mocking patterns                 |
| `reference/nextjs-patterns.md` | Next.js 15+ (Server Components, Suspense) |

---

## SSE / Streaming Tests

When testing SSE streaming routes or hooks that consume SSE streams:

- **MockNextRequest headers:** Use `Headers` (Fetch API, case-insensitive), NOT `Map`. `Map.get('Accept')` silently returns `null` when stored as `'accept'`. Reference: `__tests__/setup/vitest.setup.ts`.
- **Route tests:** Use `readSseEvents()` helper to consume `response.body` ReadableStream and parse `event:` + `data:` blocks. Reference: `__tests__/unit/resolve-endpoint.test.ts`.
- **Hook tests:** Use controlled `ReadableStream` with captured `enqueue`/`close` refs to verify intermediate state (e.g., earlyZones populated before resolved clears it). Reference: `__tests__/unit/use-ingredient-zoning-sse.test.ts`.
- **SWR mock:** Use `vi.mock('swr', async (importOriginal) => ({ ...(await importOriginal()), mutate: mockMutate }))` to replace only `mutate` without breaking SWR cache internals.
- **Wire-contract guard:** A handler test that injects mock events with a hardcoded event name does NOT validate the wire contract. When bd-8nse.1 landed, its client-side Layer 4 handler listened for event name `compound_defer` while the server emitted the event as `resolved` with `{status:'compound_defer'}` in the payload — the handler would have been completely dead code in production. Tests passed because they fed fake `compound_defer` events into the mock stream on the same side of the wire. Fix: (a) share the event name as an exported constant imported by BOTH the server route and the client handler, so a rename would break both tests simultaneously, OR (b) make the server-side test file cover event-name emission (e.g. `expect(events[0].event).toBe('compound_defer')`) and land it in the same bead as the client handler, never a follow-up.

## Common Mistakes

| Mistake                                                               | Fix                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Testing implementation details                                        | Test observable behavior (outputs, DOM)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Mocking internal modules                                              | Only mock external dependencies                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| No cleanup between tests                                              | Use `beforeEach(() => vi.clearAllMocks())`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Flaky async tests                                                     | Use `waitFor()` with proper assertions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Snapshot overuse                                                      | Guard with explicit assertions before snapshot                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Asserting Tailwind class names                                        | Use `data-zone`, `data-status` test attributes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Skipping edge cases                                                   | Test error paths, empty states                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Ignoring accessibility                                                | Test ARIA, keyboard nav, focus management                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Using `git stash` mid-session                                         | Never stash during active editing — `pop` can conflict with parallel changes and revert your work. Filter lint noise with grep instead.                                                                                                                                                                                                                                                                                                                                                                                            |
| Production delays slowing tests                                       | Use `const DELAY_MS = process.env.NODE_ENV === 'test' ? 0 : 1_000` to zero out retry/backoff delays in test mode                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Switching timer mode mid-test                                         | Create `userEvent.setup()` AFTER `vi.useRealTimers()`. During fake-timer phase, use `fireEvent.change()` for value changes. A userEvent instance bound to fake timers throws "timers APIs are not mocked" if reused after mode switch.                                                                                                                                                                                                                                                                                             |
| Trusting LLM-generated numerical reference values                     | For pure math modules (beta CDF, statistics, etc.), verify expected values against closed-form formulas, scipy, or Wolfram Alpha. LLM-generated values are frequently wrong for numerical functions.                                                                                                                                                                                                                                                                                                                               |
| Using `require()` inside functions expecting `vi.mock()` to intercept | Vitest with Vite only intercepts module-level ESM `import` statements and top-level `require()`. `require()` inside function bodies is NOT intercepted. Move to top-level ESM `import` for mockability. Safe for plugins with web fallbacks (e.g., `@capacitor/preferences`).                                                                                                                                                                                                                                                      |
| Missing mock updates after behavior change                            | When changing a function's contract (e.g., direct-write → read-merge-write, new parameters, different return type), grep `__tests__/` and `features/` for all test files that mock or import that function. Update ALL of them in the same change. Run `pnpm test:all` to catch downstream breakage — `pnpm test` (affected-only) will miss integration tests that don't directly import the changed file.                                                                                                                         |
| Mocking recursive functions with a global resolved value              | Use `mockImplementation((arg) => arg === target ? targetReturn : safeDefault)`. A global `mockResolvedValue` on a function that is called recursively on its own outputs makes every recursive call return the trigger condition, causing infinite loops and worker hangs. Scope the mock by argument so non-target inputs return a terminal value. Example: `checkCompound` returns `is_compound:true` only for the parent name; sub-ingredient recursive calls get `is_compound:false`.                                          |
| Trusting a memorized lint warning baseline after adding new files     | Re-count warnings explicitly each pass: `pnpm lint 2>&1 \| grep "problems"`. The warning count is session-state — adding new test files commonly introduces unused-var warnings that won't surface in `0 errors` checks. Report the actual current count and diff against the pre-bead baseline you observed at start, not a number remembered from earlier in the session (especially after compaction). Concrete cost: bd-9veq.3 reported "183 unchanged" when actual was 185 (+2 in new file); ~4 min to investigate and clean. |
