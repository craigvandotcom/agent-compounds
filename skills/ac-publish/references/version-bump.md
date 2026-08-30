# Version Propagation (native build surfaces)

**This file is the SOLE named owner of `CURRENT_PROJECT_VERSION` (the iOS build number)
bumping.** It happens once per wave, at merge time, in lockstep with the marketing-version
(`MARKETING_VERSION`) bump below. `ac-distribute` does NOT own or re-bump this counter — its
ship gate verifies the merge already bumped it and defers here (see
`skills/ac-distribute/SKILL.md` Workflow A Step 1). The only bump `ac-distribute`/
`CORE/distribution.md` may own is a same-version **upload-retry** increment, when a build
number is rejected/stuck and must move without a new marketing version — that is a narrow,
per-app exception, not a competing owner.

After `pnpm version <bump> --no-git-tag-version` updates `package.json`, propagate to
the surfaces that `package.json` alone doesn't reach, then commit (see SKILL Phase 0).

## Propagate the version (iOS + native build number)

`package.json` alone does not reach the App Store binary or the client/Sentry telemetry header. Three additional surfaces need to move in lockstep — only iOS files are touched at this step; the JS surface (`NEXT_PUBLIC_APP_VERSION`) is auto-derived from `package.json` at build time via `next.config.mjs` and needs no script.

```bash
# iOS marketing version (CFBundleShortVersionString) — visible in App Store + Settings.app
# Four occurrences in project.pbxproj (Debug + Release × App + Pods/share-extension target groups).
sed -i.bak -E "s/MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+(;)/MARKETING_VERSION = ${NEW_VERSION}\1/g" \
  ios/App/App.xcodeproj/project.pbxproj
rm -f ios/App/App.xcodeproj/project.pbxproj.bak

# iOS build number (CFBundleVersion) — App Store Connect requires monotonic increment
# per upload, INDEPENDENT of semver. Bump even on a patch release.
CURRENT_BUILD=$(grep -m1 -oE 'CURRENT_PROJECT_VERSION = [0-9]+' ios/App/App.xcodeproj/project.pbxproj | grep -oE '[0-9]+')
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i.bak -E "s/CURRENT_PROJECT_VERSION = ${CURRENT_BUILD};/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" \
  ios/App/App.xcodeproj/project.pbxproj
rm -f ios/App/App.xcodeproj/project.pbxproj.bak

# Verify all four MARKETING_VERSION + CURRENT_PROJECT_VERSION refs updated
grep -c "MARKETING_VERSION = ${NEW_VERSION};" ios/App/App.xcodeproj/project.pbxproj   # expect 4
grep -c "CURRENT_PROJECT_VERSION = ${NEW_BUILD};" ios/App/App.xcodeproj/project.pbxproj  # expect 4
```

If either grep returns less than 4, STOP and surface to user — pbxproj layout has changed and the sed pattern needs updating.

> **JS surface (no script needed):** `next.config.mjs` injects `NEXT_PUBLIC_APP_VERSION` from `package.json` at build time, which feeds the `X-Client-Version` HTTP header (`lib/utils/api-client.ts`) and the Sentry `client_version` tag (`sentry.client.config.ts`). If those references move, this assumption breaks — re-verify when touching either file.
>
> **Android (when added):** `android/app/build.gradle` will have `versionName` (semver) + `versionCode` (monotonic int). Add the parallel sed block here when the Android target is introduced.

> **Capacitor-specific:** the iOS/Android propagation applies to apps with a native Capacitor shell. For web-only projects, `package.json` + the JS surface is the whole story — skip the pbxproj/gradle steps.
</content>
