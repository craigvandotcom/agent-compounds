# Mock Patterns Reference

Common mock patterns for this codebase, with correct and incorrect examples.

---

## Supabase Mock Verification

### The Problem

When testing functions that use Supabase, you need to:

1. Mock the Supabase client
2. Verify the mock was called correctly

**The trap:** Capturing mock references AFTER the function runs creates a NEW reference.

### Correct Pattern: Capture Before Consumption

```typescript
describe('updateUserPreferences', () => {
  it('should save preferences to database', async () => {
    // 1. Create mock chain with TRACKABLE references BEFORE act phase
    const eqMock = vi.fn().mockResolvedValue({
      data: { id: 'test-user-id', preferences: { setting: true } },
      error: null,
    });
    const updateMock = vi.fn().mockReturnValue({ eq: eqMock });

    // 2. Configure the mock ONCE
    mockSupabaseClient.from.mockReturnValueOnce({ update: updateMock });

    // 3. Act - this CONSUMES the mockReturnValueOnce
    await updateUserPreferences({ setting: true });

    // 4. Assert - use the SAME references captured in step 1
    expect(mockSupabaseClient.from).toHaveBeenCalledWith('users');
    expect(updateMock).toHaveBeenCalledWith(
      expect.objectContaining({
        preferences: expect.objectContaining({ setting: true }),
      })
    );
  });
});
```

### Wrong Pattern: Capture After Consumption

```typescript
// ❌ WRONG - This creates a NEW mock reference
it('broken test', async () => {
  mockSupabaseClient.from.mockReturnValueOnce({
    update: vi.fn().mockReturnValue({
      eq: vi.fn().mockResolvedValue({ data: {...}, error: null })
    })
  });

  await updateUserPreferences({ setting: true });

  // ❌ This calls from() AGAIN, returning the DEFAULT mock
  const updateMock = mockSupabaseClient.from().update;

  // ❌ This checks the DEFAULT mock, not the configured one
  expect(updateMock).toHaveBeenCalledWith(...);
  // Result: "Number of calls: 0"
});
```

---

## Mock Chaining for Supabase Queries

Supabase uses method chaining. Your mock must support the same chain.

### Read Operation (select → single)

```typescript
mockSupabaseClient.from.mockReturnValueOnce({
  select: vi.fn().mockReturnValue({
    single: vi.fn().mockResolvedValue({
      data: { id: 'user-id', preferences: {} },
      error: null,
    }),
  }),
});

const result = await getUserPreferences();
// Supabase call: from('users').select('preferences').single()
```

### Update Operation (update → eq)

```typescript
const eqMock = vi.fn().mockResolvedValue({
  data: { id: 'user-id' },
  error: null,
});
const updateMock = vi.fn().mockReturnValue({ eq: eqMock });
mockSupabaseClient.from.mockReturnValueOnce({ update: updateMock });

await updateUserPreferences({ setting: true });
// Supabase call: from('users').update({...}).eq('id', userId)
```

### Insert Operation (insert → select → single)

```typescript
mockSupabaseClient.from.mockReturnValueOnce({
  insert: vi.fn().mockReturnValue({
    select: vi.fn().mockReturnValue({
      single: vi.fn().mockResolvedValue({
        data: { id: 'new-id' },
        error: null,
      }),
    }),
  }),
});

const id = await createRecord();
// Supabase call: from('table').insert({...}).select().single()
```

---

## Multiple Supabase Calls in One Test

If your function makes multiple Supabase calls, configure multiple mocks:

```typescript
it('function that reads then writes', async () => {
  // First call: read
  mockSupabaseClient.from.mockReturnValueOnce({
    select: vi.fn().mockReturnValue({
      single: vi.fn().mockResolvedValue({
        data: { existing: 'data' },
        error: null,
      }),
    }),
  });

  // Second call: write
  const updateMock = vi.fn().mockReturnValue({
    eq: vi.fn().mockResolvedValue({ data: {}, error: null }),
  });
  mockSupabaseClient.from.mockReturnValueOnce({ update: updateMock });

  await functionThatReadsThenWrites();

  expect(updateMock).toHaveBeenCalled();
});
```

**Note:** `mockReturnValueOnce` is consumed in order. First call gets first mock, second call gets second mock.

---

## Thenable Chain Pattern (Variable-Depth Chains)

When mocking a chain that ends without a predictable terminal method (e.g., catch blocks that call `.update().eq().eq()` without `.select()` or `.single()`), make the chain object thenable. This lets `await chain` resolve after any number of chained method calls.

```typescript
function buildThenableChain(resolveValue: { error: Error | null }) {
  const chain = {
    update: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    // Thenable: await chain resolves regardless of chain depth
    then: (resolve: (v: typeof resolveValue) => void) => resolve(resolveValue),
  };
  return chain;
}
```

Use this instead of predicting the exact terminal method when the production code's chain depth can vary (e.g., error recovery paths that may or may not call `.select()`).

---

## Auth Mock Setup

Most Supabase operations need authenticated user:

```typescript
beforeEach(() => {
  vi.clearAllMocks();

  // Setup default auth mock
  mockSupabaseClient.auth.getUser.mockResolvedValue({
    data: { user: { id: 'test-user-id' } },
    error: null,
  });
});
```

### Testing Unauthenticated State

```typescript
it('should return null when not authenticated', async () => {
  mockSupabaseClient.auth.getUser.mockResolvedValue({
    data: { user: null },
    error: { message: 'Not authenticated' },
  });

  const result = await getUserPreferences();
  expect(result).toBeNull();
});
```

---

## Error State Mocking

```typescript
it('should handle database errors', async () => {
  mockSupabaseClient.from.mockReturnValueOnce({
    update: vi.fn().mockReturnValue({
      eq: vi.fn().mockResolvedValue({
        data: null,
        error: { message: 'Database connection failed' },
      }),
    }),
  });

  await expect(updateUserPreferences({ setting: true })).rejects.toThrow();
});
```

---

## Debugging Mock Issues

### "X is not a function"

**Cause:** Mock chain doesn't match what the code expects.

**Debug:**

```typescript
console.log('from returns:', mockSupabaseClient.from());
console.log('from().update:', mockSupabaseClient.from().update);
```

**Fix:** Ensure mock chain matches implementation's Supabase call chain.

### "Number of calls: 0"

**Cause:** Mock reference captured after consumption.

**Debug:**

```typescript
// Check how many times from() was called
console.log('from call count:', mockSupabaseClient.from.mock.calls.length);
```

**Fix:** Capture mock references BEFORE the act phase.

### Test Hangs/Timeouts

**Cause:** Async mock not resolving.

**Check:** Are you using `mockResolvedValue` (not `mockReturnValue`) for async results?

```typescript
// ❌ Wrong - returns sync value
.eq: vi.fn().mockReturnValue({ data: {}, error: null })

// ✅ Correct - returns Promise
.eq: vi.fn().mockResolvedValue({ data: {}, error: null })
```

---

## Quick Reference

| Pattern                 | When to Use                      |
| ----------------------- | -------------------------------- |
| `mockReturnValue`       | Sync return, reusable            |
| `mockReturnValueOnce`   | Sync return, single use          |
| `mockResolvedValue`     | Async return (Promise), reusable |
| `mockResolvedValueOnce` | Async return, single use         |
| `mockRejectedValue`     | Async error (rejected Promise)   |

---

## Template: Supabase Function Test

```typescript
describe('mySupabaseFunction', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockSupabaseClient.auth.getUser.mockResolvedValue({
      data: { user: { id: 'test-user-id' } },
      error: null,
    });
  });

  it('should do the thing', async () => {
    // 1. Create trackable mock references
    const finalMock = vi.fn().mockResolvedValue({
      data: {
        /* expected data */
      },
      error: null,
    });
    const chainMock = vi.fn().mockReturnValue({ final: finalMock });

    // 2. Configure supabase mock
    mockSupabaseClient.from.mockReturnValueOnce({ method: chainMock });

    // 3. Act
    const result = await mySupabaseFunction();

    // 4. Assert
    expect(mockSupabaseClient.from).toHaveBeenCalledWith('table_name');
    expect(chainMock).toHaveBeenCalledWith(/* expected args */);
    expect(result).toEqual(/* expected result */);
  });
});
```
