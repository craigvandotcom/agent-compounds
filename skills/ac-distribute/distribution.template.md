# Distribution — {{APP_NAME}} (per-app facts for `ac-distribute`)

> **TEMPLATE.** Copy to the consuming app's `.claude/skills/CORE/distribution.md` and fill in
> every `{{…}}`. Delete rows/sections that don't apply. The METHOD lives in
> `ac-distribute/SKILL.md`; this file is ONLY this app's facts. **Secrets are POINTED TO,
> never stored here.**

## App identity

|                   |                                                            |
| ----------------- | ---------------------------------------------------------- |
| Bundle ID         | `{{com.example.app}}`                                       |
| ASC App ID        | `{{numeric app id — App Store Connect}}`                    |
| Apple Team ID     | `{{TEAMID}}` (FASTLANE_TEAM_ID / ITC_TEAM_ID)              |
| Distribution cert | `Apple Distribution: {{name}} ({{TEAMID}})` (managed by match) |
| TestFlight        | {{closed/internal `distribute_external: false` | open}}     |

## Signing — {{fastlane match | other}}

- **Signing repo:** `{{github.com/owner/signing-repo}}` (private; encrypted certs + profiles;
  shared across machines + CI). {{Often the org-shared signing repo.}}
- **MATCH_PASSWORD / equivalent:** {{password manager + `ios/App/fastlane/.env` (gitignored)}}.
- **Seed/refresh:** `{{bundle exec fastlane signing}}` (creates on first run, readonly in CI).

## Auth (headless)

- **ASC API key:** key id `{{KEYID}}`, **{{Admin}}** access, issuer `{{issuer-uuid}}`.
- **`.p8` location:** `{{~/.appstoreconnect/private_keys/AuthKey_KEYID.p8}}` (chmod 600, out
  of the repo). NEVER commit the `.p8`. Custom env names if the Fastfile uses them (see the
  art-still gotcha: `ASC_API_KEY_P8` not `APP_STORE_CONNECT_API_KEY_PATH`).

## Versioning + build number (the Capacitor footgun)

- **package.json** = web/dev semver (`{{x.y.z}}`), INDEPENDENT of the store version.
- **iOS `MARKETING_VERSION`** = store marketing version (`{{1.0}}`).
- **iOS `CURRENT_PROJECT_VERSION`** = build number, **MUST increment every upload** (`{{N}}`).
- **Owner + bump mechanism:** {{who/what increments it — a ship script? manual? agvtool?}}
  ← pin this; duplicate-build upload errors are the classic footgun.

## Build prerequisites

- **Ruby/toolchain:** {{Homebrew Ruby for fastlane; `bundle install`}}.
- **PROD web env:** {{if `.env.local` is backendless, how prod env is injected before the
  build; the verification grep}}.

## Run a release

```bash
{{pnpm ship:testflight   # or: cd ios/App && bundle exec fastlane release}}
```

{{Describe the one-command path if one exists, and the underlying lane. Note the sim-QA-PASS
precondition (ac-qa-simulator) and the build-number bump.}}

## Footguns checklist (verify against ac-distribute/SKILL.md)

- [ ] Build number increments every upload
- [ ] codesign-verify the `.app` INSIDE the `.xcarchive`
- [ ] `ITSAppUsesNonExemptEncryption` set (HTTPS-only) so builds auto-clear compliance
- [ ] Admin ASC API key (headless, no 2FA)
- [ ] prod backend baked into the web build before archiving
