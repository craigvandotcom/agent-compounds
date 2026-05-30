# E2E Test Workflow

Step-by-step guide for writing Playwright end-to-end tests.

---

## When to Write E2E Tests

- Critical user journeys (login, checkout, core features)
- Cross-page navigation flows
- Authentication/session handling
- Production-risk scenarios
- Browser-specific behavior

**Keep E2E tests minimal:** 3-10 tests covering critical paths.

---

## Step 1: Test File Setup

### Location

```
__tests__/e2e/[journey-name].spec.ts
```

### Basic Structure

```typescript
import { test, expect } from '@playwright/test';

test.describe('User Journey Name', () => {
  test.beforeEach(async ({ page }) => {
    // Setup: navigation, mocks, console monitoring
  });

  test('should complete primary flow', async ({ page }) => {
    // Test steps
  });
});
```

---

## Step 2: Console Error Monitoring

```typescript
test.beforeEach(async ({ page }) => {
  const consoleErrors: string[] = [];

  page.on('console', msg => {
    if (msg.type() === 'error') {
      const text = msg.text();
      // Filter known non-critical errors
      if (
        !text.includes('Manifest') &&
        !text.includes('deprecated') &&
        !text.includes('getUserMedia')
      ) {
        consoleErrors.push(text);
      }
    }
  });

  // Attach to page for later assertion
  (page as any).consoleErrors = consoleErrors;
});

// In test
const consoleErrors = (page as any).consoleErrors || [];
expect(consoleErrors).toHaveLength(0);
```

---

## Step 3: Browser API Mocking

### Camera/MediaDevices

```typescript
await page.addInitScript(() => {
  Object.defineProperty(navigator, 'mediaDevices', {
    writable: true,
    value: {
      getUserMedia: () =>
        Promise.resolve({
          getVideoTracks: () => [{ stop: () => {} }],
          getAudioTracks: () => [],
          getTracks: () => [{ stop: () => {} }],
        }),
      enumerateDevices: () =>
        Promise.resolve([
          {
            deviceId: 'camera1',
            kind: 'videoinput',
            label: 'Mock Camera',
            groupId: 'group1',
          },
        ]),
    },
  });
});
```

### Geolocation

```typescript
await page.addInitScript(() => {
  Object.defineProperty(navigator, 'geolocation', {
    writable: true,
    value: {
      getCurrentPosition: success =>
        success({
          coords: { latitude: 52.3676, longitude: 4.9041 },
        }),
    },
  });
});
```

---

## Step 4: Navigation & Authentication

### Handling Auth Redirects

```typescript
test('should handle unauthenticated access', async ({ page }) => {
  await page.goto('/app/protected-page');

  // Check if redirected to login
  const isOnLogin = page.url().includes('/login');

  if (isOnLogin) {
    // Verify login page loads
    await expect(page.getByRole('heading', { name: /sign in/i })).toBeVisible();
    return;
  }

  // If authenticated, continue with test
  await expect(page).toHaveURL('/app/protected-page');
});
```

### Skipping When Auth Required

```typescript
test('should complete authenticated flow', async ({ page }) => {
  await page.goto('/app/dashboard');

  if (page.url().includes('/login')) {
    test.skip(true, 'Requires authentication - skipping');
    return;
  }

  // Test authenticated behavior
});
```

---

## Step 5: Element Location Strategies

### Multiple Fallback Selectors

```typescript
const elementSelectors = [
  page.getByRole('button', { name: /save/i }),
  page.getByText(/save changes/i),
  page.locator('[data-testid="save-button"]'),
  page.locator('button[type="submit"]'),
];

let foundElement = null;
for (const selector of elementSelectors) {
  try {
    if (await selector.isVisible({ timeout: 2000 })) {
      foundElement = selector;
      break;
    }
  } catch {
    continue;
  }
}

if (foundElement) {
  await foundElement.click();
}
```

### Waiting for Network

```typescript
// Wait for all network requests to settle
await page.waitForLoadState('networkidle');

// Wait for specific API response
const responsePromise = page.waitForResponse(
  response => response.url().includes('/api/data') && response.ok()
);
await page.click('button');
await responsePromise;
```

---

## Step 6: Test Patterns

### Form Interaction

```typescript
test('should submit form successfully', async ({ page }) => {
  await page.goto('/app/form');

  // Fill form
  await page.getByRole('textbox', { name: /name/i }).fill('Test User');
  await page.getByRole('textbox', { name: /email/i }).fill('test@example.com');

  // Submit
  await page.getByRole('button', { name: /submit/i }).click();

  // Verify success
  await expect(page.getByText(/success/i)).toBeVisible();
});
```

### Navigation Flow

```typescript
test('should navigate through multi-step process', async ({ page }) => {
  await page.goto('/app/wizard/step-1');

  // Step 1
  await page.getByRole('button', { name: /next/i }).click();
  await expect(page).toHaveURL('/app/wizard/step-2');

  // Step 2
  await page.getByRole('button', { name: /next/i }).click();
  await expect(page).toHaveURL('/app/wizard/step-3');

  // Complete
  await page.getByRole('button', { name: /finish/i }).click();
  await expect(page).toHaveURL('/app/wizard/complete');
});
```

### Screenshot on Failure

```typescript
test('should render correctly', async ({ page }) => {
  await page.goto('/app/dashboard');

  // Playwright auto-captures on failure with config:
  // screenshot: 'only-on-failure'

  await expect(page.getByRole('main')).toBeVisible();
});
```

---

## Step 7: Running Tests

```bash
# Run all E2E tests
pnpm test:e2e

# Run with UI mode (debugging)
pnpm test:e2e:ui

# Run specific test file
pnpm test:e2e __tests__/e2e/auth-flow.spec.ts

# Run in headed mode (see browser)
pnpm test:e2e:headed

# Run with debug mode
pnpm test:e2e:debug
```

---

## Playwright Config Reference

```typescript
// playwright.config.ts
export default defineConfig({
  testDir: './__tests__/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',

  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 10000,
  },

  webServer: {
    command: 'pnpm build && pnpm start',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },

  timeout: 30 * 1000,
  expect: { timeout: 5 * 1000 },
});
```

---

## Checklist

- [ ] Test file uses `.spec.ts` extension
- [ ] Console errors monitored and asserted
- [ ] Browser APIs mocked as needed
- [ ] Auth redirects handled gracefully
- [ ] Multiple selector fallbacks for resilience
- [ ] Network waits where appropriate
- [ ] Tests work both authenticated and unauthenticated
- [ ] No hard-coded waits (`waitForTimeout`)
