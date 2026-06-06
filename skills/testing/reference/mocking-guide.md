# Mocking Guide

Patterns and examples for mocking in tests (Supabase / Next.js).

---

## Core Principle

> Mock external boundaries, not internal code.

External boundaries:

- Third-party APIs (OpenAI, Stripe)
- Infrastructure services (Redis, external DBs)
- Browser APIs (camera, geolocation)
- Next.js framework internals

---

## Vitest Mock Patterns

### Module Mock (Top-Level)

```typescript
// Mock entire module
vi.mock('@/lib/services/ai-service', () => ({
  analyzeImage: vi.fn(),
  zoneIngredients: vi.fn(),
}));

// Import mocked module
import { analyzeImage } from '@/lib/services/ai-service';

// Configure in test
vi.mocked(analyzeImage).mockResolvedValue({ result: 'data' });
```

### Partial Mock

```typescript
vi.mock('@/lib/utils', () => ({
  ...(await vi.importActual('@/lib/utils')),
  specificFunction: vi.fn(),
}));
```

### Factory Mock

```typescript
vi.mock('@/lib/supabase/client', () => ({
  createClient: vi.fn(() => mockSupabaseClient),
}));

const mockSupabaseClient = {
  from: vi.fn(() => mockQuery),
  auth: { getUser: vi.fn() },
};
```

---

## Common Mocks (Supabase / Next.js)

### Supabase Client

```typescript
const mockSupabaseClient = {
  auth: {
    getUser: vi.fn(),
    getSession: vi.fn(),
    signInWithPassword: vi.fn(),
    signUp: vi.fn(),
    signOut: vi.fn(),
    onAuthStateChange: vi.fn(() => ({
      data: { subscription: { unsubscribe: vi.fn() } },
    })),
  },
  from: vi.fn(() => ({
    select: vi.fn().mockReturnThis(),
    insert: vi.fn().mockReturnThis(),
    update: vi.fn().mockReturnThis(),
    delete: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    order: vi.fn().mockReturnThis(),
    limit: vi.fn().mockReturnThis(),
    single: vi.fn(),
  })),
  channel: vi.fn(() => ({
    on: vi.fn().mockReturnThis(),
    subscribe: vi.fn(() => ({
      unsubscribe: vi.fn(),
    })),
  })),
};

vi.mock('@/lib/supabase/client', () => ({
  createClient: () => mockSupabaseClient,
}));
```

### Next.js Navigation

```typescript
const mockPush = vi.fn();
const mockReplace = vi.fn();

vi.mock('next/navigation', () => ({
  useRouter: () => ({
    push: mockPush,
    replace: mockReplace,
    prefetch: vi.fn(),
    back: vi.fn(),
    forward: vi.fn(),
    refresh: vi.fn(),
  }),
  usePathname: () => '/',
  useSearchParams: () => new URLSearchParams(),
}));
```

### Toast Notifications

```typescript
vi.mock('sonner', () => ({
  toast: {
    success: vi.fn(),
    error: vi.fn(),
    warning: vi.fn(),
    loading: vi.fn(),
    dismiss: vi.fn(),
  },
}));

// In test
const { toast } = require('sonner');
expect(toast.success).toHaveBeenCalledWith('Message');
```

### Upstash Redis/Ratelimit

```typescript
vi.mock('@upstash/redis', () => ({
  Redis: vi.fn().mockImplementation(() => ({
    get: vi.fn(),
    set: vi.fn(),
    del: vi.fn(),
    incr: vi.fn(),
  })),
}));

vi.mock('@upstash/ratelimit', () => ({
  Ratelimit: vi.fn().mockImplementation(() => ({
    limit: vi.fn().mockResolvedValue({ success: true }),
  })),
}));
```

### Logger

```typescript
vi.mock('@/lib/utils/logger', () => ({
  logger: {
    debug: vi.fn(),
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  },
}));
```

### Custom Hooks

```typescript
vi.mock('@/lib/hooks', () => ({
  useTodaysFoods: vi.fn(() => ({
    data: [],
    error: null,
    isLoading: false,
    retry: vi.fn(),
  })),
  useFoodStats: vi.fn(() => ({
    data: {
      greenIngredients: 5,
      yellowIngredients: 3,
      redIngredients: 2,
      totalIngredients: 10,
    },
    isLoading: false,
  })),
}));
```

---

## MSW (Mock Service Worker)

For API mocking in integration tests:

```typescript
import { rest } from 'msw';
import { setupServer } from 'msw/node';

const handlers = [
  rest.post('/api/analyze-image', (req, res, ctx) => {
    return res(
      ctx.json({
        success: true,
        data: { ingredients: ['apple', 'banana'] },
      })
    );
  }),

  rest.get('/api/foods', (req, res, ctx) => {
    return res(
      ctx.json({
        success: true,
        data: mockFoods,
      })
    );
  }),
];

const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

### Override Handler Per Test

```typescript
it('should handle API error', async () => {
  server.use(
    rest.post('/api/analyze-image', (req, res, ctx) => {
      return res(ctx.status(500), ctx.json({ error: 'Internal server error' }));
    })
  );

  // Test error handling
});
```

---

## Browser API Mocks

### Window.matchMedia

```typescript
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});
```

### IntersectionObserver

```typescript
global.IntersectionObserver = class IntersectionObserver {
  constructor() {}
  disconnect() {}
  observe() {}
  unobserve() {}
} as any;
```

### ResizeObserver

```typescript
global.ResizeObserver = class ResizeObserver {
  constructor() {}
  disconnect() {}
  observe() {}
  unobserve() {}
} as any;
```

### Fetch

```typescript
global.fetch = vi.fn(() =>
  Promise.resolve({
    ok: true,
    json: () => Promise.resolve({ data: 'response' }),
  })
) as ReturnType<typeof vi.fn>;
```

---

## Spy Patterns

### Spy on Method

```typescript
const consoleSpy = vi.spyOn(console, 'error').mockImplementation();

// After test
expect(consoleSpy).toHaveBeenCalledWith(expect.stringContaining('error'));
consoleSpy.mockRestore();
```

### Spy Without Replacement

```typescript
const fetchSpy = vi.spyOn(global, 'fetch');

// Original function still runs, but calls are tracked
expect(fetchSpy).toHaveBeenCalledWith('/api/data');
```

---

## Mock Reset Patterns

### Per Test

```typescript
beforeEach(() => {
  vi.clearAllMocks(); // Clear call history
});
```

### Complete Reset

```typescript
afterEach(() => {
  vi.resetAllMocks(); // Reset implementations too
});
```

### Restore Original

```typescript
afterAll(() => {
  vi.restoreAllMocks(); // Restore original implementations
});
```

---

## Troubleshooting

### Mock Not Working

1. Check import order (mock before import)
2. Verify module path matches exactly
3. Use `await vi.importActual` for partial mocks

### TypeScript Errors

```typescript
// Use vi.mocked() for type safety
vi.mocked(myFunction).mockReturnValue(value);

// Or cast explicitly
(myFunction as ReturnType<typeof vi.fn>).mockReturnValue(value);
```

### Async Mock Issues

```typescript
// Ensure async mock returns promise
mockFn.mockResolvedValue(data); // Success
mockFn.mockRejectedValue(new Error()); // Failure
```
