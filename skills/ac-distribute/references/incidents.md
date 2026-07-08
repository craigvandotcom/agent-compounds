# ac-distribute — incident log (narratives)

The full stories behind rules compressed in `../SKILL.md`. Read when you need the
evidence or history behind a rule — never required to run the workflows (each rule's
causal why stays inline in the SKILL.md at its point of use).

## 1. Paywall rejected four times despite green static checks (BCA, Guideline 2.1(b))

Five static-presence checks (dep installed, chunk bundled, key baked, plugin
registered) all passed while the paywall's purchase CTA sat disabled behind
placeholder data — through **four** consecutive App Review rejections. Every check
proved the code was *present*; none proved the surface *worked*. This is the origin of
the review-critical journey-stamp gate (`journey-stamp-check.sh --lane store`) and the
inline rule: runtime behavior, not static presence, is the only sufficient proof —
above all on COMMERCE surfaces (live store data + enabled CTA).

## 2. "Build shipped" claimed from an archive-only workflow (BCA, 2026-07-02)

BCA's merge-triggered native build on main was an archive-only build-health check —
it never uploaded to TestFlight. Its green run was read as "build shipped", and an
evening was burned discovering no build had ever reached ASC. Origin of the inline
rule: never claim "build shipped" from an archive success — the proof is the build
appearing in ASC with `processingState == VALID`, and CORE/distribution.md must state
explicitly whether the merge-triggered native build UPLOADS or is health-check-only.

## 3. `setup_ci` hijacked the user's keychain on a personal-Mac runner (BCA, 2026-07-03)

A lane using fastlane's `setup_ci` on a self-hosted personal Mac made
`fastlane_tmp_keychain` the user's DEFAULT keychain and dropped login from the search
list — breaking the owner's GUI session with system dialogs demanding the tmp
keychain's password (which is the empty string). Fine on ephemeral CI VMs; a footgun
on any personal machine. Fix ratified inline: restore in `after_all` AND `error` hooks
(`security list-keychains -s …login.keychain-db` + `default-keychain -s` +
`delete_keychain`). BCA's Fastfile is the reference implementation.

## 4. First headless store submit (BCA, 2026-06-17)

BCA's first production App Store submission was driven fully headless (fastlane
`submit` lane + read-only ASC-API preflight) and validated Workflow B end-to-end. It
also produced, live, every store-submit footgun now inline in the SKILL.md: a stuck
rejected `reviewSubmission` occupying the app's single review slot; a stray empty
`en-US` localization created by `deliver` from a local metadata mirror, blocking
review; `whatsNew` returning 409 `STATE_ERROR` for the first released version; an
indefinite build-PROCESSING hang (90+ min, WidgetKit extension) unstuck by a fresh
re-upload; and a submit lane silently resolving its version from a
`Dir.pwd`→package.json fallback, submitting the wrong version + build 1.

## 5. fastlane ratified over the asc-CLI (art-still, 2026-06-15)

The original distribution-stack plan said "NOT fastlane, use the `asc` CLI" — a stance
that predated discovering art-still had already standardized on a working fastlane
lane. Five live headless ship cycles (builds 2→6; match git-stored signing + Admin ASC
API key; no Apple 2FA at any point) proved the lane, and the decision was ratified:
wrap whatever build tool the app already uses; fastlane owns the build mile, the ASC
API owns the read/submit miles. art-still also supplied the concrete shapes now
genericized inline: the one-command push (`pnpm ship:testflight`), the monotonic
`CURRENT_PROJECT_VERSION` ×4 in pbxproj, and the `.env.release.local` +
`grep <project-ref> out/` prod-backend assertion. Full record + Phase-1 results:
`_DECISION-distribution-stack.md` (this directory).
