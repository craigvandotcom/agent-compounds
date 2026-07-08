# Incidents behind the rules

Narrative provenance for enforcement lines in SKILL.md. Read only when questioning or
revising one of these rules.

## Native device capture reverses an earlier "no device capture" stance
An earlier version of this skill forbade device capture outright. That stance was
correct only for *web* surfaces: auditing the marketing *site pages* is browser work,
but refreshing the *app-screen mockups* embedded in them is native-app work. Hence
Option B (native device capture via `agent-device`) now exists alongside the browser
path.

## Why the browser script fails for native-app mockups (seeding invisibly no-ops)
A local `pnpm dev` web server rendered **demo/mock data** and **auto-authenticated a
fixed dev user**, so DB seeding had no effect on what rendered — captures looked fine
but showed the wrong data source. The native app build hits the real (prod) backend,
where the seeded account shows real data. Rule: seed the **account the native app
auto-uses**, in the backend the app actually points at (usually prod), not whatever
the web default is.

## Each MANDATORY-protocol item maps to a real escaped defect
1. **Seed FIRST** — a capture run reused week-old relative-date seed data; "Today"
   views shipped empty.
2. **Verify data is CURRENT in the app** — a capture was taken after seeding the DB
   but before the app refreshed; the shipped screenshots had blank recent days and a
   wrong streak count (cached pre-seed state).
3. **Every manifest slot** — an awkward-to-reach screen was skipped "for now"; the
   stale image sat on the live landing page next to freshly refreshed neighbours.
