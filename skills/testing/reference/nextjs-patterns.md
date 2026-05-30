# Next.js 14+ Testing Patterns

## Testing Server Components

Server Components run on the server and cannot use hooks or browser APIs. Test them as async functions:

```typescript
import { render, screen } from '@testing-library/react';

// Server component (async)
async function ServerComponent({ id }: { id: string }) {
  const data = await fetchData(id);
  return <div>{data.title}</div>;
}

// Test as async
it('should render server component', async () => {
  const Component = await ServerComponent({ id: '123' });
  render(Component);
  expect(screen.getByText('Expected Title')).toBeInTheDocument();
});
```

## Testing Suspense Boundaries

```typescript
import { Suspense } from 'react';
import { render, screen, waitFor } from '@testing-library/react';

it('should show fallback then content', async () => {
  render(
    <Suspense fallback={<div>Loading...</div>}>
      <AsyncComponent />
    </Suspense>
  );

  // Initially shows fallback
  expect(screen.getByText('Loading...')).toBeInTheDocument();

  // Wait for content
  await waitFor(() => {
    expect(screen.getByText('Loaded Content')).toBeInTheDocument();
  });
});
```

## Testing React Query / Data Fetching

```typescript
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        retry: false, // Don't retry in tests
        gcTime: 0, // No caching in tests
      },
    },
  });

const wrapper = ({ children }: { children: React.ReactNode }) => (
  <QueryClientProvider client={createTestQueryClient()}>
    {children}
  </QueryClientProvider>
);

it('should fetch and display data', async () => {
  render(<DataComponent />, { wrapper });

  expect(screen.getByText('Loading...')).toBeInTheDocument();

  await waitFor(() => {
    expect(screen.getByText('Data loaded')).toBeInTheDocument();
  });
});
```
