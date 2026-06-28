---
template_version: 2
---

# Triage — {{APP_NAME}} (per-app facts for `ac-triage`)

> **TEMPLATE.** Copy to the consuming app's `.claude/skills/CORE/triage.md` and fill in every
> `{{…}}`. The METHOD lives in `ac-triage/SKILL.md`; this file is ONLY this app's sources +
> bar. **Secrets are POINTED TO, never stored here.** Beads route to THIS repo's db.
> **On copy, replace the frontmatter above with:** `derived_from: ac-triage/triage.template.md`
> + `template_version: <version copied>` — the stamp `infra-sync` uses to detect drift.

## Enabled sources

| #   | Source                | Status                                  | Auth pointer                          |
| --- | --------------------- | --------------------------------------- | ------------------------------------- |
| 1   | **Sentry**            | {{✅ live / ⏳ teed up / ⬜ off}}        | `SENTRY_AUTH_TOKEN` + org/proj slugs  |
| 2   | **App Store Connect** | {{✅ / ⬜}} {{(native app only)}}        | Admin ASC API key — see `distribution.md` |
| 3   | **Supabase**          | {{✅ / ⬜}} schema `{{schema}}`          | service-role — see `supabase.md`      |
| 4   | **GitHub Issues**     | {{⬜ N/A private / ✅ OSS}}              | `gh` CLI                              |
| 5   | PostHog               | {{⬜ deferred}}                          | project key                           |
| 6   | **Feedback reports**  | {{⬜ adapter pending / ✅ live}}          | service-role — see `supabase.md`      |

A source that isn't configured is **skipped, not an error**. Flip to ✅ when its auth lands.

## Source specifics

- **Sentry (source #1):** {{web `@sentry/nextjs` live? native `@sentry/capacitor` wired?
  DSN where (Vercel secret / .env)? See `sentry-setup.md`. Fetch unresolved + regression
  issues sorted by `lastSeen`.}}
- **ASC beta feedback (source #2):** `GET /v1/apps/{{appId}}/betaFeedbackCrashSubmissions`
  (JWT from the `.p8`; **no `sort` on the nested path**); filter `createdDate > watermark`.
  {{Only if it's a native/TestFlight app.}}
- **Supabase (source #3):** error-level logs + auth failures for schema `{{schema}}`.
- **GitHub Issues (source #4):** {{private repo → N/A; OSS → `gh issue list`, loop-guarded.}}
- **Feedback reports (source #6):** solicited in-app user feedback in `{{schema}}.feedback_reports`.
  Query: `SELECT ... WHERE linked_bead IS NULL AND created_at > <watermark>`.
  Fingerprint dedup on `user_id + normalized(message) + category` (not id-only — client retries re-INSERT).
  Evidence guard: skip bug rows where `context` claims a screenshot but `screenshot_path IS NULL`.
  Write-back: `SET linked_bead, status='triaged'` after each bead (loop-guard).
  `status='fixed' + fixed_in_build` written by the ac-merge hook (bd-vbmre.16).
  Full spec: `ac-triage/references/feedback-adapter.md`.

## Severity bar (drop below this)

{{Crash on a primary journey ({{list this app's primary journeys}}) → always a bead. Other
crash with users ≥ N or freq ≥ M → bead. JS error with users ≥ K → bead. Single-occurrence
transient / known 3rd-party / sub-threshold → drop (list in the report, don't file).}}

## Dedupe fingerprint

{{Sentry: issue `culprit` + top in-app frame. ASC: error signature + screen.}} Search the
repo db for an open bead with the same fingerprint BEFORE creating — recurrence updates the
existing bead, never a duplicate. Label `triage,<source>` + carry the source record id (loop
guard).

## Cadence

{{Headless / VM-hosted; schedule once source #1 is live; run on demand until then.}}

## Maintaining this file

A **real file**, not a symlink — `deploy.sh` never overwrites it (filled values safe), so it
does **not** auto-update. When `template_version` advances upstream, `infra-sync` flags it as
stale. Reconcile by **grafting the new template sections in, PRESERVING every filled value, then
bumping `template_version`** — never auto-overwrite. App facts live here; method goes in
`ac-triage/SKILL.md` (symlinked — edit there, never per-app).
