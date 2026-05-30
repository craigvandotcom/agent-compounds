# Testing & Debugging Capacitor

**When to read:** Writing Vitest mocks for Capacitor plugins, debugging native WebView issues, diagnosing crashes, or setting up platform-specific test helpers.

---

## Vitest Mocking (BCA uses Vitest)

```typescript
import { vi, describe, it, expect } from 'vitest';

// Mock Capacitor core
vi.mock('@capacitor/core', () => ({
  Capacitor: {
    isNativePlatform: vi.fn(() => true),
    getPlatform: vi.fn(() => 'ios'),
    isPluginAvailable: vi.fn(() => true),
  },
}));

// Mock specific plugin
vi.mock('@capacitor/camera', () => ({
  Camera: {
    getPhoto: vi.fn().mockResolvedValue({
      webPath: 'test-photo.jpg',
      format: 'jpeg',
    }),
  },
  CameraResultType: { Uri: 'uri' },
}));

// Platform-specific test helper
async function mockPlatform(platform: 'ios' | 'android' | 'web') {
  const { Capacitor } = await import('@capacitor/core');
  vi.mocked(Capacitor.getPlatform).mockReturnValue(platform);
  vi.mocked(Capacitor.isNativePlatform).mockReturnValue(platform !== 'web');
}
```

---

## WebView Debugging

Enable WebView debugging (required for Safari/Chrome inspector). Dev only — disable for production:

```typescript
// capacitor.config.ts
const config: CapacitorConfig = {
  ios: { webContentsDebuggingEnabled: true },
  android: { webContentsDebuggingEnabled: true },
};
```

| Platform    | Tool                                                           |
| ----------- | -------------------------------------------------------------- |
| Web         | Chrome DevTools (standard)                                     |
| iOS         | Safari Web Inspector → Develop menu → Simulator/Device         |
| Android     | `adb logcat \| grep -i capacitor` or Chrome `chrome://inspect` |
| Live reload | `npx cap run ios --livereload --external`                      |

---

## Crash Diagnosis

```bash
# iOS simulator crash stream
xcrun simctl spawn booted log stream --level debug | grep -i crash

# Android fatal errors
adb logcat *:E | grep -i "fatal\|crash"
```

---

## E2E Testing

- **Playwright** — web simulation (already in BCA testing skill)
- **Appium/WebdriverIO** — native E2E on device/emulator (for true native validation)
