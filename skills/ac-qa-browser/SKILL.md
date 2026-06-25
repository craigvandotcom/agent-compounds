---
name: ac-qa-browser
description: Use when QA-ing the WEB app build in a browser — full journey validation against the real web shell (SPA routing, storage/session persistence, service worker, CORS, console hygiene, hydration, responsive viewports), appearance matrix, screenshot evidence. The web twin of ac-qa-device. Runs on any OS against a dev server or deployed URL. Triggers on "test web app", "browser QA", "QA in browser", "validate web build", "web smoke test", "QA the deployed app".
---

> **The web twin.** `ac-qa-browser` proves the web shell; `ac-qa-device` proves
> the native shell. Shared conventions — **depth levels, journey reuse,
> findings=beads, the `QA_VALIDATION` report** — live in **`_shared/qa-shared.md`**;
> both twins reference it so they stay in lockstep. This file owns the web/browser
> specifics only. The low-level `agent-browser` CLI mechanics it drives live in
> **`browser-testing/SKILL.md`** (this skill is the structured QA layer on top —
> depth levels, full-app crawl, gating report).

> **Generic skill — method only, zero app facts.** Symlinked from agent-compounds
> and shared across consuming apps. **App specifics (URLs, credentials, routes,
> journeys, viewport policy) → the consuming app's `.claude/skills/CORE/SKILL.md`** —
> journeys in `CORE/journeys/`, real URLs/creds in `CORE/journeys/environments.md`,
> the crawl route list in `CORE/journeys/routes.md`.

# Browser / Web-Shell QA Skill

Drive the **real web build** in a headless browser with a DOM see → act → assert
loop. Tooling: **`agent-browser`** (Vercel CLI — session-scoped daemon, interactive
snapshot with @refs, wait/click/fill/screenshot/errors). Mechanics + teardown rules:
`browser-testing/SKILL.md`.

## Platform note (read first)

Runs **anywhere** (any OS — no Mac needed). Requires either the app's dev server
running (`pnpm dev`, see the app's AGENTS.md) or a deployed URL (preview/production).
For hybrid (Capacitor) apps the browser renders the **same bundle** the native
webview does — so this twin owns the cheap, exhaustive DOM/visual coverage; route
native-shell concerns (safe-area, splash, plugins, OAuth sheets) to `ac-qa-device`.

## Layered QA model — what to test here

| Layer | Tool | Coverage | Cost |
| ----- | ---- | -------- | ---- |
| 1. **Browser (this skill)** | agent-browser | Exhaustive: every route, button, state, edge case + the web-shell checklist | Cheap, fast |
| 2. Native shell | `ac-qa-device` (agent-device + simctl) | Real native taps + native-shell checklist | Slower per action |

**Decision rule:** logic / layout / state / routing / console / responsive → here.
"Does the real app work when really *native*-touched" → `ac-qa-device`.

## Depth levels

Defined in **`_shared/qa-shared.md`**. Web specifics per level: **smoke** = serve →
open → auth → primary journey, zero console errors (run before merge of web-UI waves);
**full** adds every journey in `CORE/journeys/` + the `web-shell-checklist.md` +
responsive spot-checks; **exhaustive** adds the full-app crawl (every route in
`CORE/journeys/routes.md`), the appearance matrix (dark/light × viewport set), and a
console-clean assertion on every route.

## Toolchain

```bash
npm install -g agent-browser     # session-scoped headless Chrome; see browser-testing/SKILL.md
# the app's dev server: pnpm dev (or the command in the app's AGENTS.md)
```

## Core loop

```bash
S=qa-browser-<app>               # distinct, predictable session name (for unambiguous teardown)
DEV_STARTED=                     # set to 1 iff THIS skill starts the dev server (leave empty for a deployed URL)

# 0. Serve — start the app's dev server, backgrounded (skip when targeting a deployed URL)
#    pnpm dev >/tmp/qa-dev-$S.log 2>&1 &   # or the command in the app's AGENTS.md
#    DEV_STARTED=1 ; then wait until it's listening (curl/wait) before step 1

# 1. Open + set the app's viewport (mobile-first apps: check CORE viewport policy)
agent-browser --session $S open "<BASE_URL>"
agent-browser --session $S set viewport 390 844
agent-browser --session $S wait --load networkidle

# 2. SEE — interactive DOM tree with @refs (refs renumber every snapshot)
agent-browser --session $S snapshot -i

# 3. ACT — target by @ref from the LATEST snapshot
agent-browser --session $S click @e12
agent-browser --session $S fill @e7 "text"

# 4. ASSERT / SYNC
agent-browser --session $S wait --url "/dashboard"
agent-browser --session $S errors          # console errors — see discipline rule 4

# 5. EVIDENCE
agent-browser --session $S screenshot /tmp/qa-<route>.png

# 6. TEARDOWN — MANDATORY, even on the failure path (see below)
agent-browser --session $S close
# Kill the dev server THIS skill started. Subagent shells don't persist $! across
# tool calls, so match by process, not PID (use the app's dev command):
[ -n "$DEV_STARTED" ] && pkill -f "next dev" 2>/dev/null
```

### Discipline rules (non-negotiable)

1. **Teardown is mandatory and scoped.** Pair every `open` with a `close` of the
   **same session name**, on the success AND error paths (trap/finally). NEVER
   `close --all`. A daemon that dies without closing leaves a headless Chrome
   reparented to launchd spinning at ~100% CPU indefinitely (the 4-day / load-54
   incident). Full rationale + manual escape hatch: `browser-testing/SKILL.md`.
   **The same applies to the dev server you start in step 0** — a subagent's shell
   does not persist `$!` across tool calls, so an orphaned `next dev` (≈200% CPU)
   outlives the agent and starves a single-runner CI host (the 2026-06-24 load-30 /
   34-min-vitest-stall incident). Kill it by process on both paths:
   `pkill -f "next dev"` (use the app's dev command). Caveat — like the Chrome
   escape hatch, this kills ALL matching dev servers: fine when the agent is the
   only one running it; skip if a human has their own `pnpm dev` up.
2. **Refs renumber on every snapshot.** Re-snapshot after every navigation, route
   change, modal, or async state change — then use the NEW refs. Stale-ref taps are
   the top flake source.
3. **Checkpoint your fills.** After `fill`, snapshot-verify the value landed before
   submitting — fills can race route transitions and land nowhere.
4. **Console errors ARE findings.** Run `errors` after every route load and every
   mutation. A passing `wait` does not mean a clean console — React hydration
   mismatches, key warnings, failed fetches, and CORS errors all surface here and
   each is a bead. `console` (warnings) on exhaustive passes.
5. **Empty ≠ clean.** Before reading an empty list/zero-count as success, check the
   DOM for error-boundary nodes, "Retry" buttons, error toasts. An errored view
   greps like an empty one — the canonical false-clean.
6. **Catch toasts.** Transient (~4s) toast text after a mutation is a finding even
   when the operation eventually succeeded — poll the toast region briefly.
7. **Direct-navigate every route, don't just click through.** SPA bugs hide on cold
   deep-links: `open "<BASE_URL>/<route>"` directly tests routing, guards, and
   data-fetch on first paint (not just warm in-app nav).
8. **Responsive is a matrix, not a viewport.** Re-run the checklist at the app's
   declared viewport set (e.g. 320 / 390 / 428, + desktop if the app supports it);
   no horizontal scroll at any width.
9. **Screenshot hygiene for long sessions.** Downscale before reading
   (`sips -Z 1500 <png>`) — the model API caps images once a session carries many.

## Crawling the whole app (full-app / exhaustive pass)

The route list is the app's **`CORE/journeys/routes.md`** manifest (per-app data).
Use the shared **`_tools/crawl-and-capture`** primitive to visit every route, settle,
and screenshot at the viewport set with **guaranteed teardown** — then run `errors`
+ the web-shell checklist per route. The crawl primitive wraps the same `agent-browser`
discipline (one session, finally-close, never `--all`). The same captured screenshots
feed `ac-ui-polish`'s visual-conformance pass — capture once, consume twice.

## Web shell — what to check

Full list → **`web-shell-checklist.md`** (SPA routing, storage/session persistence,
service worker / PWA, CORS/network, console hygiene, hydration, responsive, forms,
loading/empty/error states). This is what the browser plane uniquely proves.

## Findings = beads

File each finding as a bead the moment it's confirmed — conventions, types, and
labels (`qa-finding` / `qa-blocker`) are in **`_shared/qa-shared.md`**. A web finding
is any divergence from the journey docs, plus console errors, web-shell bugs, and
responsive breaks. Tag bead descriptions with `browser QA`.

## Reporting

Emit the **`QA_VALIDATION`** block from `_shared/qa-shared.md` with:

- `platform: browser-local` (or `browser-preview` / `browser-production`)
- `target:` browser + viewport(s)
- `shell_checklist:` items from `web-shell-checklist.md`
- `perf_observations:` qualitative only — layout shift, slow first paint

Consumed by `ac-merge` (gates the PR on web-UI waves). **Never** satisfies the native
ship gate in `ac-distribute` — that gate predicates on `platform: ios-simulator`.

## Teardown

`agent-browser --session $S close` for every session you opened — the final step,
always, including the error path. Never `close --all`. (Full rationale + the runaway-
CPU failure mode: `browser-testing/SKILL.md` § Teardown.)

## Related files

- `_shared/qa-shared.md` — depth levels, journey reuse, findings=beads, `QA_VALIDATION` schema (shared with the twin)
- `web-shell-checklist.md` — what ONLY the web shell surfaces
- `browser-testing/SKILL.md` — the low-level `agent-browser` mechanics this skill wraps
- `ac-qa-device/SKILL.md` — the native-shell twin (Layer 2)
- `_tools/crawl-and-capture/` — the shared full-app crawl + screenshot primitive
- Consuming app's `CORE/journeys/` + `environments.md` + `routes.md` — the what
