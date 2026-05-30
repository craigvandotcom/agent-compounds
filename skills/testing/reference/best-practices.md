# Testing Best Practices

Adapted from [goldbergyoni/javascript-testing-best-practices](https://github.com/goldbergyoni/javascript-testing-best-practices) and [goldbergyoni/nodejs-testing-best-practices](https://github.com/goldbergyoni/nodejs-testing-best-practices).

---

## The Golden Rule

> Design tests for simplicity. Testing code is not production code - make it short, dead-simple, flat, and delightful to work with.

Tests should require minimal cognitive effort. If you need to think hard to understand a test, it's too complex.

---

## Section 1: Test Anatomy

### 1.1 Three-Part Naming

Structure: `[Unit] [Scenario] [Expectation]`

```typescript
// Bad
it('test add', () => {});

// Good
describe('Products Service', () => {
  describe('Add new product', () => {
    it('should set status to pending approval when no price specified', () => {});
  });
});
```

### 1.2 AAA Pattern

```typescript
it('should calculate discount correctly', () => {
  // Arrange - setup data
  const product = { price: 100, category: 'electronics' };
  const discount = { percent: 20, minPurchase: 50 };

  // Act - execute (typically 1 line)
  const result = calculateDiscount(product, discount);

  // Assert - verify (typically 1 line)
  expect(result).toBe(80);
});
```

### 1.3 Declarative Assertions

```typescript
// Bad - imperative
const found = items.find(i => i.id === 'test-id');
expect(found !== undefined).toBe(true);

// Good - declarative
expect(items).toContainEqual(expect.objectContaining({ id: 'test-id' }));
```

### 1.4 Black-Box Testing

Test only public methods. Implementation details can change; behavior should not.

```typescript
// Bad - testing internal state
expect(component.state.isLoading).toBe(false);

// Good - testing observable output
expect(screen.queryByText(/loading/i)).not.toBeInTheDocument();
```

---

## Section 2: Test Types

### The Testing Diamond

```
        ╱╲
       ╱E2E╲         Few tests (3-10)
      ╱──────╲
     ╱Component╲     Most tests
    ╱────────────╲
   ╱   Unit       ╲  Only for complex logic
  ╱────────────────╲
```

**Principle:** Start with component/integration tests, not unit tests.

### Five "Exit Doors" to Test

1. **Response** - HTTP status, response schema
2. **State Changes** - Database modifications
3. **External Calls** - Third-party API requests
4. **Message Queues** - Events published
5. **Observability** - Logging, metrics

---

## Section 3: Mocking Strategy

### Mock External, Not Internal

| Mock                    | Don't Mock       |
| ----------------------- | ---------------- |
| External APIs           | Business logic   |
| Third-party SDKs        | Database layer   |
| File system (sometimes) | Internal modules |
| Network calls           | State management |

### Why Real Databases

> "Test doubles can't verify SQL correctness, actual query performance, or data integrity constraints"

Use production-like databases with performance tuning:

- `fsync=off` for faster writes
- In-memory/tmpfs for speed
- One migration per test run

---

## Section 4: Test Data

### Use Factories

```typescript
// Bad - inline data
const user = { id: '1', name: 'Test', email: 'test@example.com' };

// Good - factory with defaults
const createUser = (overrides = {}) => ({
  id: faker.string.uuid(),
  name: faker.person.fullName(),
  email: faker.internet.email(),
  ...overrides,
});

const user = createUser({ name: 'Custom Name' });
```

### Data Isolation

Each test operates on isolated data. Don't share state between tests.

```typescript
beforeEach(() => {
  // Fresh data for each test
  testData = createTestDataset();
});

afterEach(async () => {
  // Clean up test data
  await cleanupTestData(testData.id);
});
```

---

## Section 5: Async Testing

### Avoid Fixed Timeouts

```typescript
// Bad
await new Promise(r => setTimeout(r, 1000));
expect(result).toBe(expected);

// Good
await waitFor(() => {
  expect(result).toBe(expected);
});
```

### Test Race Conditions

```typescript
it('should handle concurrent requests correctly', async () => {
  const promises = Array.from({ length: 100 }, (_, i) =>
    service.process({ id: i })
  );

  const results = await Promise.all(promises);

  expect(new Set(results.map(r => r.id)).size).toBe(100);
});
```

---

## Section 6: Error Testing

### Test Error Paths

```typescript
it('should throw when input is invalid', async () => {
  await expect(service.process(null)).rejects.toThrow('Invalid input');
});

it('should return error response for malformed request', async () => {
  const response = await POST(createBadRequest());

  expect(response.status).toBe(400);
  expect(await response.json()).toEqual({
    success: false,
    error: expect.objectContaining({
      code: 'VALIDATION_ERROR',
    }),
  });
});
```

### Don't Catch Everything

Let unexpected errors bubble up. Only catch errors you explicitly expect.

---

## Section 7: Performance

### Target Test Speed

| Type        | Target | Max   |
| ----------- | ------ | ----- |
| Unit        | <10ms  | 50ms  |
| Component   | <100ms | 500ms |
| Integration | <500ms | 2s    |
| E2E         | <5s    | 30s   |

### Parallel Execution

Run independent tests in parallel:

```typescript
// vitest.config.mts
{
  maxWorkers: '50%',  // Use half available cores
}
```

---

## Section 8: Organization

### Group by Feature

```
__tests__/
├── unit/
│   ├── utils.test.ts
│   └── validation.test.ts
├── components/
│   ├── form.test.tsx
│   └── button.test.tsx
├── integration/
│   └── api-flow.test.ts
└── e2e/
    └── user-journey.spec.ts
```

### One Assert Per Test (Usually)

```typescript
// Bad - multiple assertions make failures unclear
it('should process order', () => {
  expect(result.status).toBe('complete');
  expect(result.total).toBe(100);
  expect(result.items).toHaveLength(3);
});

// Good - focused tests
it('should set status to complete', () => {
  expect(result.status).toBe('complete');
});

it('should calculate total correctly', () => {
  expect(result.total).toBe(100);
});
```

---

## Section 9: CI/CD Integration

### Test in CI

```yaml
# Run tests before deploy
steps:
  - run: pnpm test:ci
  - run: pnpm test:e2e
```

### Coverage Thresholds

```typescript
// vitest.config.mts
{
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70,
    },
  },
}
```

---

## Quick Reference

| Principle      | Do                      | Don't                   |
| -------------- | ----------------------- | ----------------------- |
| Test behavior  | Observable outputs      | Implementation details  |
| Mock scope     | External dependencies   | Internal modules        |
| Data setup     | Factories with defaults | Inline hardcoded data   |
| Async handling | waitFor, findBy         | setTimeout, sleep       |
| Assertions     | Declarative matchers    | Imperative conditionals |
| Test speed     | Fast, parallel          | Slow, sequential        |
| Coverage       | Critical paths first    | 100% for its own sake   |
