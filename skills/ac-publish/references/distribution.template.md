---
template_version: 1
---

# Distribution — {{APP_NAME}} (per-app facts for `ac-publish`)

> **TEMPLATE.** Copy to the consuming app's `.claude/skills/CORE/distribution.md` and fill in
> every `{{…}}`. Delete rows/sections that don't apply. The METHOD lives in the `ac-publish`
> skill (its SKILL.md); this file is ONLY this app's facts. **Secrets are POINTED TO,
> never stored here.** **On copy, replace the frontmatter above with:**
> `derived_from: ac-publish/distribution.template.md` + `template_version: <the version you
> copied>` — that stamp is how `infra-sync` detects when this file has drifted behind the template.

## App store

The store lane. Everything in it is headless except the build mile (**only the build mile
is Mac-bound** — submit and monitor run anywhere the ASC API key exists).

### App identity

|                   |                                                            |
| ----------------- | ---------------------------------------------------------- |
| Bundle ID         | `{{com.example.app}}`                                       |
| ASC App ID        | `{{numeric app id — App Store Connect}}`                    |
| Apple Team ID     | `{{TEAMID}}` (FASTLANE_TEAM_ID / ITC_TEAM_ID)              |
| Distribution cert | `Apple Distribution: {{name}} ({{TEAMID}})` (managed by match) |
| TestFlight        | {{closed/internal `distribute_external: false` | open}}     |

### Signing — {{fastlane match | other}}

- **Signing repo:** `{{github.com/owner/signing-repo}}` (private; encrypted certs + profiles;
  shared across machines + CI). {{Often the org-shared signing repo.}}
- **MATCH_PASSWORD / equivalent:** {{password manager + `ios/App/fastlane/.env` (gitignored)}}.
- **Seed/refresh:** `{{bundle exec fastlane signing}}` (creates on first run, readonly in CI).

### Auth (headless)

- **ASC API key:** key id `{{KEYID}}`, **{{Admin}}** access, issuer `{{issuer-uuid}}`.
- **`.p8` location:** `{{~/.appstoreconnect/private_keys/AuthKey_KEYID.p8}}` (chmod 600, out
  of the repo). NEVER commit the `.p8`. Custom env names if the Fastfile uses them (see the
  signing gotcha: the app's lane may use `ASC_API_KEY_P8` rather than the generic
  `APP_STORE_CONNECT_API_KEY_PATH` — pin the actual names in the Fastfile).

### Versioning + build number (the Capacitor footgun)

- **package.json** = web/dev semver (`{{x.y.z}}`), INDEPENDENT of the store version.
- **iOS `MARKETING_VERSION`** = store marketing version (`{{1.0}}`).
- **iOS `CURRENT_PROJECT_VERSION`** = build number, **MUST increment every upload** (`{{N}}`).
- **Owner + bump mechanism:** {{who/what increments it — a ship script? manual? agvtool?}}
  ← pin this; duplicate-build upload errors are the classic footgun.

### Build prerequisites

- **Ruby/toolchain:** {{Homebrew Ruby for fastlane; `bundle install`}}.
- **PROD web env:** {{if `.env.local` is backendless, how prod env is injected before the
  build; the verification grep}}.

### Run a release

```bash
{{pnpm ship:testflight   # or: cd ios/App && bundle exec fastlane release}}
```

{{Describe the one-command path if one exists, and the underlying lane. Note the sim-QA-PASS
precondition (ac-qa) and the build-number bump.}}

### Store footguns (verify mechanically, never by memory)

- [ ] Build number increments every upload — build numbers are monotonic; the ship contract reads the uploaded number back
- [ ] codesign-verify the `.app` INSIDE the `.xcarchive`
- [ ] `ITSAppUsesNonExemptEncryption` set (HTTPS-only) so builds auto-clear compliance
- [ ] Admin ASC API key (headless, no 2FA)
- [ ] prod backend baked into the web build before archiving
- Wrap whatever build lane the app already has — never introduce a second build tool.
- The sim-QA gate is mechanical — a fresh PASS artifact, not a memory; `NOT-GATED` is not a pass.
- A direct submit never bypasses proof: the proof leg runs first (with `+qa` for a store
  submission), and building/submitting consumes its RETURNED proven SHA — never the stale
  input ref.
- Store ids come from `factory.json` `store.*` — never app literals in skill text.

## Web targets

The web lane. The web target **promotes the staged deployment built from the proven SHA —
it never rebuilds**: locate the staged production-target build keyed by the proven SHA and
promote it; then verify the live domain SERVES the proven SHA (an identity check of the
alias's own deployment metadata — never a version-string grep). Promoting a preview build
ships preview env vars — always confirm the build is production-target before promoting.
After the promote, the production-branch domain auto-assignment flag is re-asserted AND
read back — a PATCH nobody re-reads is unverified state. Mechanics: `references/web-promote.md`.

## Maintaining this file

This is a **real file**, not a symlink — `deploy.sh` never overwrites it, so your filled values
are safe. It also means it does **not** auto-update: when `template_version` advances upstream,
`infra-sync` flags this file as stale. To reconcile, **graft the new template sections in by
hand/agent, PRESERVE every filled value, then bump `template_version`** — never auto-overwrite.
App-specific facts live here; method improvements belong in `ac-publish` (symlinked —
edit there, which propagates to all apps; NEVER edit a symlinked file per-app).
