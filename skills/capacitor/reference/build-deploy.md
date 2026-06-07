# Build & Deployment

Reference for native build, device runs, and App Store submission. Read at CI/CD or release time.

## Commands

```bash
# Sync web assets to native projects
npx cap sync

# Open native IDE
npx cap open ios
npx cap open android

# Build web first, then sync
pnpm build && npx cap sync

# Run on device (with live reload)
npx cap run ios --livereload --external
npx cap run android --livereload --external
```

## App Store Checklist

- Splash screen configured (`capacitor.config.ts`)
- Icons generated for all sizes (1024x1024 source)
- Bundle ID / package name set
- Signing certificates configured (iOS: provisioning profile, Android: keystore)
- Privacy manifest (iOS) / permissions declared
- `viewport-fit=cover` in meta tag for edge-to-edge

## Apple Privacy Manifest (`ios/App/App/PrivacyInfo.xcprivacy`)

Required for App Store submission (Spring 2024+). Structure:

- `NSPrivacyTracking` — `false` if no tracking
- `NSPrivacyCollectedDataTypes` — array of collected data type dicts (linked, not tracked, purpose)
- `NSPrivacyAccessedAPITypes` — array with reason codes (e.g., UserDefaults → CA92.1)

**This is app-specific.** Enumerate *your* app's collected data types (Photos, Health,
OtherUserContent, etc.) and accessed required-reason APIs (e.g. UserDefaults → CA92.1
for `@capacitor/preferences`) per app — keep the actual list in the app's **CORE**, and
update it whenever you add a plugin that touches a required-reason API or collect a new
data type.
