# Deep Linking

**When to read:** Implementing universal links or custom URL scheme handling, testing deep links on simulator/device, or verifying associated domain configuration.

---

## Listen for Deep Links

```typescript
import { App } from '@capacitor/app';

// Handle links when app is already running
App.addListener('appUrlOpen', event => {
  const url = new URL(event.url);
  router.push(url.pathname + url.search);
});

// Handle launch URL (app opened from cold start via link)
const { url } = (await App.getLaunchUrl()) ?? {};
if (url) {
  const parsed = new URL(url);
  router.push(parsed.pathname + parsed.search);
}
```

---

## Test Deep Links

```bash
# iOS simulator
xcrun simctl openurl booted "myapp://food/123"

# Android emulator/device
adb shell am start -a android.intent.action.VIEW -d "myapp://food/123"
```

---

## Verify Associated Domains

```bash
curl https://myapp.example/.well-known/apple-app-site-association
curl https://myapp.example/.well-known/assetlinks.json
```

Both files must be reachable and valid for universal links (iOS) and app links (Android) to work.
