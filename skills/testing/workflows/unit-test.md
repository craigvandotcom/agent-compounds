# Unit Test Workflow

Step-by-step guide for writing unit tests in body-compass-app.

---

## When to Write Unit Tests

- Pure functions with complex logic
- Utility functions (`lib/utils/`)
- Data transformations
- Validation logic
- Calculations/algorithms

**Skip unit tests for:**

- Simple one-liner functions
- Direct wrappers around external APIs
- React components (use component tests)

---

## Step 1: Identify Test Cases

### Input Categories

1. **Happy path** - Valid inputs, expected behavior
2. **Edge cases** - Boundary values, empty inputs
3. **Error cases** - Invalid inputs, malformed data
4. **Security cases** - Injection attempts, malicious data

### Example: Testing IP Extraction

```typescript
// Function: getClientIP(request: NextRequest): string

// Happy path
- Valid X-Forwarded-For header
- Valid CF-Connecting-IP header
- Multiple IPs in chain (return first)

// Edge cases
- Empty headers
- Whitespace in IP
- IPv6 addresses

// Error cases
- Invalid IP format
- Out of range octets
- Incomplete IP

// Security
- Header injection attempts
- XSS in header value
```

---

## Step 2: Create Test File

### Location

```
__tests__/unit/[feature-name].test.ts
```

### Structure

```typescript
/**
 * Unit Tests for [Feature Name]
 * Tests for [brief description]
 */

import { functionName } from '@/lib/utils/module-name';

// Mock dependencies (external only)
vi.mock('@/lib/utils/logger', () => ({
  logger: { debug: vi.fn(), warn: vi.fn(), error: vi.fn() },
}));

describe('[Function/Module Name]', () => {
  describe('[Method Name]', () => {
    // Group by scenario
  });
});
```

---

## Step 3: Write Tests (AAA Pattern)

### Basic Test

```typescript
it('should extract IP from X-Forwarded-For header', () => {
  // Arrange
  const request = createMockRequest({
    'x-forwarded-for': '203.0.113.195, 192.168.1.1',
  });

  // Act
  const ip = getClientIP(request);

  // Assert
  expect(ip).toBe('203.0.113.195');
});
```

### Parameterized Test

```typescript
const testCases = [
  { input: '0.0.0.0', expected: '0.0.0.0' },
  { input: '255.255.255.255', expected: '255.255.255.255' },
  { input: '127.0.0.1', expected: '127.0.0.1' },
];

testCases.forEach(({ input, expected }) => {
  it(`should accept boundary IP: ${input}`, () => {
    const request = createMockRequest({ 'x-forwarded-for': input });
    expect(getClientIP(request)).toBe(expected);
  });
});
```

### Async Test

```typescript
it('should handle concurrent validation requests', async () => {
  const promises = Array.from({ length: 100 }, () =>
    Promise.resolve(validateMagicNumbers(jpegFile, 'image/jpeg'))
  );

  const results = await Promise.all(promises);
  expect(results.every(result => result === true)).toBe(true);
});
```

---

## Step 4: Test Helpers

### Mock Request Factory

```typescript
function createMockRequest(headers: Record<string, string>): NextRequest {
  const url = 'http://localhost:3000/api/test';
  const request = new NextRequest(url);

  const mockHeaders = {
    get: (name: string) => headers[name.toLowerCase()] || null,
  };

  Object.defineProperty(request, 'headers', {
    value: mockHeaders,
    writable: false,
  });

  return request;
}
```

### Base64 Test Data

```typescript
// Valid JPEG
const jpegData = btoa('\xFF\xD8\xFF\xE0\x00\x10JFIF');
const jpegFile = `data:image/jpeg;base64,${jpegData}`;

// Valid PNG
const pngData = btoa('\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR');
const pngFile = `data:image/png;base64,${pngData}`;
```

---

## Step 5: Run and Verify

```bash
# Run specific test file
pnpm test __tests__/unit/[name].test.ts

# Run with coverage
pnpm test:coverage __tests__/unit/[name].test.ts

# Watch mode during development
pnpm test:watch __tests__/unit/[name].test.ts
```

---

## Checklist

- [ ] All input categories covered (happy, edge, error, security)
- [ ] AAA pattern followed consistently
- [ ] External dependencies mocked
- [ ] Test names describe scenario and expectation
- [ ] No flaky async behavior
- [ ] Tests run fast (<100ms per test)
