# Component Test Workflow

Step-by-step guide for testing React components with Vitest and React Testing Library.

---

## When to Write Component Tests

- User interactions (clicks, typing, form submission)
- Conditional rendering
- State changes and UI updates
- Component integration with hooks
- Accessibility verification

---

## Step 1: Setup

### Location

```
__tests__/components/[component-name].test.tsx
```

### Imports

```typescript
import { render, screen, waitFor } from '@/__tests__/setup/test-utils';
import userEvent from '@testing-library/user-event';
import { ComponentName } from '@/features/[feature]/components/[component-name]';

// Mock external dependencies
vi.mock('@/lib/services/service-name', () => ({
  serviceFn: vi.fn(),
}));

vi.mock('sonner', () => ({
  toast: { success: vi.fn(), error: vi.fn() },
}));
```

---

## Step 2: Test Structure

```typescript
describe('ComponentName', () => {
  const mockOnAction = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Rendering', () => {
    it('should render initial state correctly', () => {});
    it('should display loading state', () => {});
    it('should show error state', () => {});
  });

  describe('User Interactions', () => {
    it('should handle button click', async () => {});
    it('should update on input change', async () => {});
    it('should submit form correctly', async () => {});
  });

  describe('Async Behavior', () => {
    it('should show loading during async operation', async () => {});
    it('should display success message', async () => {});
    it('should handle errors gracefully', async () => {});
  });
});
```

---

## Step 3: User Event Setup

```typescript
it('should submit form correctly', async () => {
  // Always setup userEvent at start of test
  const user = userEvent.setup();

  render(<FormComponent onSubmit={mockOnSubmit} />);

  // Find elements
  const nameInput = screen.getByRole('textbox', { name: /name/i });
  const submitButton = screen.getByRole('button', { name: /submit/i });

  // Interact
  await user.type(nameInput, 'Test Value');
  await user.click(submitButton);

  // Assert
  await waitFor(() => {
    expect(mockOnSubmit).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'Test Value' })
    );
  });
});
```

---

## Step 4: Query Priority

### Use in This Order

1. **Role queries** (most accessible)

```typescript
screen.getByRole('button', { name: /submit/i });
screen.getByRole('textbox', { name: /email/i });
screen.getByRole('heading', { level: 1 });
screen.getByRole('checkbox', { name: /agree/i });
```

2. **Label queries**

```typescript
screen.getByLabelText(/email address/i);
```

3. **Placeholder queries**

```typescript
screen.getByPlaceholderText(/search/i);
```

4. **Text queries**

```typescript
screen.getByText(/welcome/i);
```

5. **Test IDs (last resort)**

```typescript
screen.getByTestId('custom-element');
```

---

## Step 5: Async Handling

### waitFor for Async Updates

```typescript
await waitFor(() => {
  expect(screen.getByText(/success/i)).toBeInTheDocument();
});
```

### waitFor with Options

```typescript
await waitFor(
  () => {
    expect(mockFn).toHaveBeenCalled();
  },
  { timeout: 3000 }
);
```

### findBy for Async Elements

```typescript
// Combines getBy + waitFor
const element = await screen.findByText(/loaded content/i);
expect(element).toBeInTheDocument();
```

---

## Step 6: Testing Patterns

### Form Submission

```typescript
it('should call onSubmit with form data', async () => {
  const user = userEvent.setup();
  const onSubmit = vi.fn();

  render(<Form onSubmit={onSubmit} />);

  await user.type(
    screen.getByRole('textbox', { name: /email/i }),
    'test@example.com'
  );
  await user.click(screen.getByRole('button', { name: /submit/i }));

  await waitFor(() => {
    expect(onSubmit).toHaveBeenCalledWith({
      email: 'test@example.com',
    });
  });
});
```

### Error Display

```typescript
it('should display validation error', async () => {
  const user = userEvent.setup();

  render(<Form />);

  // Submit without filling required field
  await user.click(screen.getByRole('button', { name: /submit/i }));

  await waitFor(() => {
    expect(screen.getByText(/required/i)).toBeInTheDocument();
  });
});
```

### Conditional Rendering

```typescript
it('should show delete button only for owner', () => {
  render(<ItemCard isOwner={true} />);
  expect(screen.getByRole('button', { name: /delete/i })).toBeInTheDocument();
});

it('should hide delete button for non-owner', () => {
  render(<ItemCard isOwner={false} />);
  expect(screen.queryByRole('button', { name: /delete/i })).not.toBeInTheDocument();
});
```

### Loading States

```typescript
it('should show loading indicator', () => {
  render(<DataView isLoading={true} />);
  expect(screen.getByText(/loading/i)).toBeInTheDocument();
});

it('should hide loading after data loads', async () => {
  const { rerender } = render(<DataView isLoading={true} />);

  rerender(<DataView isLoading={false} data={mockData} />);

  expect(screen.queryByText(/loading/i)).not.toBeInTheDocument();
  expect(screen.getByText(mockData.title)).toBeInTheDocument();
});
```

---

## Common Anti-Patterns

| Anti-Pattern                        | Better Approach              |
| ----------------------------------- | ---------------------------- |
| `container.querySelector('.class')` | `screen.getByRole('button')` |
| Testing component state directly    | Test DOM output              |
| `fireEvent.click()`                 | `await user.click()`         |
| Multiple assertions in waitFor      | Single assertion per waitFor |
| Testing CSS classes                 | Test visual behavior         |

---

## Checklist

- [ ] Using `@/__tests__/setup/test-utils` render
- [ ] `userEvent.setup()` at test start
- [ ] Role-based queries preferred
- [ ] Async operations use `waitFor` or `findBy`
- [ ] Props/callbacks tested through UI
- [ ] Loading, error, success states covered
- [ ] `vi.clearAllMocks()` in beforeEach
