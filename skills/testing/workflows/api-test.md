# API Route Test Workflow

Step-by-step guide for testing Next.js API route handlers.

---

## When to Write API Tests

- Route handler logic
- Request validation
- Response formatting
- Error handling
- Middleware behavior
- Authentication/authorization

---

## Step 1: Test File Setup

### Location

```
__tests__/api/[route-name].test.ts
```

### Imports

```typescript
import { NextRequest } from 'next/server';
import { POST, GET } from '@/app/api/[route-name]/route';

// Mock external dependencies
vi.mock('@/lib/supabase/server', () => ({
  createClient: vi.fn(() => mockSupabaseClient),
}));

vi.mock('@/lib/services/external-service', () => ({
  externalFn: vi.fn(),
}));
```

---

## Step 2: Request Helpers

### Creating Test Requests

```typescript
function createTestRequest(
  body: Record<string, unknown>,
  method: string = 'POST'
): NextRequest {
  return new NextRequest('http://localhost:3000/api/route-name', {
    method,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

function createGetRequest(
  searchParams: Record<string, string> = {}
): NextRequest {
  const url = new URL('http://localhost:3000/api/route-name');
  Object.entries(searchParams).forEach(([key, value]) => {
    url.searchParams.set(key, value);
  });
  return new NextRequest(url.toString(), { method: 'GET' });
}
```

### With Authentication

```typescript
function createAuthenticatedRequest(
  body: Record<string, unknown>,
  userId: string = 'test-user-123'
): NextRequest {
  return new NextRequest('http://localhost:3000/api/route-name', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer mock-token`,
      'X-User-Id': userId,
    },
    body: JSON.stringify(body),
  });
}
```

---

## Step 3: Test Structure

```typescript
describe('API: /api/route-name', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST', () => {
    describe('Request Validation', () => {
      it('should return 400 for missing required fields', async () => {});
      it('should return 400 for invalid data format', async () => {});
    });

    describe('Happy Path', () => {
      it('should process valid request and return 200', async () => {});
      it('should return expected response structure', async () => {});
    });

    describe('Error Handling', () => {
      it('should return 500 on database error', async () => {});
      it('should return 401 when unauthorized', async () => {});
    });
  });

  describe('GET', () => {
    // Similar structure
  });
});
```

---

## Step 4: Response Assertions

### Status Code Check

```typescript
it('should return 200 for valid request', async () => {
  mockService.process.mockResolvedValue({ data: 'result' });

  const request = createTestRequest({ validField: 'value' });
  const response = await POST(request);

  expect(response.status).toBe(200);
});
```

### Response Body Check

```typescript
it('should return correct response structure', async () => {
  mockService.process.mockResolvedValue({ id: '123', name: 'Test' });

  const request = createTestRequest({ validField: 'value' });
  const response = await POST(request);
  const body = await response.json();

  expect(body).toEqual({
    success: true,
    data: {
      id: '123',
      name: 'Test',
    },
  });
});
```

### Error Response Check

```typescript
it('should return error message for invalid input', async () => {
  const request = createTestRequest({ invalidField: 'bad' });
  const response = await POST(request);
  const body = await response.json();

  expect(response.status).toBe(400);
  expect(body).toEqual({
    success: false,
    error: expect.objectContaining({
      message: expect.any(String),
      code: 'VALIDATION_ERROR',
    }),
  });
});
```

---

## Step 5: Mocking Patterns

### Mock Supabase Client

```typescript
const mockSupabaseClient = {
  auth: {
    getUser: vi.fn(),
  },
  from: vi.fn(() => ({
    select: vi.fn().mockReturnThis(),
    insert: vi.fn().mockReturnThis(),
    update: vi.fn().mockReturnThis(),
    delete: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    single: vi.fn(),
  })),
};

// In test
mockSupabaseClient.auth.getUser.mockResolvedValue({
  data: { user: { id: 'user-123' } },
  error: null,
});
```

### Mock Database Query

```typescript
it('should insert and return new record', async () => {
  const mockFrom = mockSupabaseClient.from();
  mockFrom.insert.mockReturnThis();
  mockFrom.select.mockReturnThis();
  mockFrom.single.mockResolvedValue({
    data: { id: 'new-123', name: 'Test' },
    error: null,
  });

  const request = createTestRequest({ name: 'Test' });
  const response = await POST(request);

  expect(response.status).toBe(201);
  expect(mockFrom.insert).toHaveBeenCalledWith(
    expect.objectContaining({ name: 'Test' })
  );
});
```

### Mock External API

```typescript
vi.mock('@/lib/services/ai-service', () => ({
  analyzeImage: vi.fn(),
}));

import { analyzeImage } from '@/lib/services/ai-service';

it('should call AI service with image data', async () => {
  vi.mocked(analyzeImage).mockResolvedValue({
    ingredients: ['apple', 'banana'],
  });

  const request = createTestRequest({ image: 'base64data' });
  const response = await POST(request);

  expect(analyzeImage).toHaveBeenCalledWith('base64data');
  expect(response.status).toBe(200);
});
```

---

## Step 6: Testing Rate Limiting

```typescript
it('should enforce rate limits', async () => {
  mockRateLimiter.limit.mockResolvedValue({ success: false });

  const request = createTestRequest({ data: 'test' });
  const response = await POST(request);

  expect(response.status).toBe(429);
  const body = await response.json();
  expect(body.error.code).toBe('RATE_LIMITED');
});
```

---

## Step 7: Testing File Uploads

```typescript
function createFileUploadRequest(
  fileData: string,
  contentType: string
): NextRequest {
  return new NextRequest('http://localhost:3000/api/upload', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      file: `data:${contentType};base64,${btoa(fileData)}`,
    }),
  });
}

it('should validate file magic numbers', async () => {
  const invalidFile = createFileUploadRequest('invalid', 'image/jpeg');
  const response = await POST(invalidFile);

  expect(response.status).toBe(400);
  const body = await response.json();
  expect(body.error.code).toBe('INVALID_FILE_TYPE');
});
```

---

## Checklist

- [ ] All HTTP methods tested (GET, POST, PUT, DELETE)
- [ ] Request validation tested (missing/invalid fields)
- [ ] Happy path with correct response structure
- [ ] Error cases return appropriate status codes
- [ ] Database interactions mocked
- [ ] External services mocked
- [ ] Rate limiting behavior tested
- [ ] Auth requirements verified
