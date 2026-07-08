# ac-merge incidents — full narratives

Evidence behind the deploy-verify rules in SKILL.md Phase 3 ("Verify the Deploy
Actually Shipped"). Read for provenance; the operative rules stay in the spine.

## simil8 — ~447-day silent Vercel production freeze

A broken main build fails silently on Vercel — prod just keeps serving the last good
build, with no alert. simil8's prod was frozen for ~447 days this way: react-virtuoso
was never added to package.json; every build since March 2025 failed; nobody knew.
Evidence: `simil8/memory/auto/simil8-vercel-production-frontend.md`.

This is why the Vercel deploy-verify step exists, why `● Error` must be surfaced
loudly and investigated (run `next build` locally — missing deps on lazily-compiled
routes are the classic cause), and why the session must never close claiming
"shipped" on an unverified deploy.

## BCA — archive health-check wording, 2026-07-02

BCA's Xcode Cloud archive on push to main is an archive-only HEALTH CHECK that never
reaches TestFlight. On 2026-07-02, report wording that implied a shippable build
existed (when only the health-check archive had run) cost BCA an evening. This is why
the report string is fixed and must not be paraphrased: when the merge-triggered
build is health-check-only, report "archive health-check green — no TestFlight build
produced; ship via the app's release lane" — never wording that implies a shippable
build exists.
