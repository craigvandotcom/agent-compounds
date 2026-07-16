---
name: ac-qa-browser
description: Use when QA-ing the WEB app build in a browser — full journey validation against the real web shell (SPA routing, storage/session persistence, service worker, CORS, console hygiene, hydration, responsive viewports), appearance matrix, screenshot evidence. The web twin of ac-qa-device. Runs on any OS against a local production build (pnpm build && pnpm start) or a deployed URL — never the pnpm dev server. Triggers on "test web app", "browser QA", "QA in browser", "validate web build", "web smoke test", "QA the deployed app".
---

> **The web twin.** `ac-qa-browser` proves the web shell; `ac-qa-device` proves
> the native shell. Shared conventions — **depth levels, journey reuse,
> findings=beads, the `QA_VALIDATION` report, the conductor/worker evidence
> protocol** — live in **`_shared/qa-shared.md`**; both twins reference it so they
> stay in lockstep. This file owns the web/browser specifics only. The low-level
> `agent-browser` CLI mechanics live in **`browser-testing/SKILL.md`** (loaded by
> the tester workers, not by you).

> **Generic skill — method only, zero app facts.** Symlinked from agent-compounds
> and shared across consuming apps. **App specifics (URLs, credentials, routes,
> journeys, viewport policy) → the consuming app's `.claude/skills/CORE/SKILL.md`** —
> journeys in `CORE/journeys/`, real URLs/creds in `CORE/journeys/environments.md`,
> the crawl route list in `CORE/journeys/routes.md`.

# Browser / Web-Shell QA Skill

**You are the conductor. You never drive the browser yourself.** Journeys are
executed by `browser-tester` subagents (the workers) — one journey per worker, each
in its own named `agent-browser` session, reporting a structured verdict file. You
hold the manifest, the verdicts, the gate decision, and the report; workers hold the
DOM snapshots, console noise, and screenshots. The full evidence protocol (manifest
schema, verdict schema, lanes, completeness rule, session naming) is
**`_shared/qa-shared.md` § Conductor / worker evidence protocol** — read it now.

## Platform note (read first)

Runs **anywhere** (any OS — no Mac needed). Requires either a **local production
build** served (`pnpm build && pnpm start`) or a deployed URL (preview/production).
For hybrid (Capacitor) apps the browser renders the **same bundle** the native
webview does — so this twin owns the cheap, exhaustive DOM/visual coverage; route
native-shell concerns (safe-area, splash, plugins, OAuth sheets) to `ac-qa-device`.

> **QA server target — local-PROD only, NEVER `pnpm dev` (doctrine, bd-yey1z).**
> Browser QA MUST target a local **production** build (`pnpm build && pnpm start`)
> or a deployed URL — never the Next.js dev server. Under sustained QA load the dev
> server's Fast-Refresh watcher enters a rebuild storm (~10 min in it began serving
> 0-byte 200s with CPU/RSS climbing until killed); a prod build (`next start`) was
> proven stable for 5 concurrent + sequential workers (bd-yey1z, 2026-07-12). The
> dev server is not a QA target and QA must never gate on its Fast-Refresh behavior.
> `pnpm dev` is for interactive development only.

## Layered QA model — what to test here

| Layer                       | Tool                                         | Coverage                                                                    | Cost              |
| --------------------------- | -------------------------------------------- | --------------------------------------------------------------------------- | ----------------- |
| 1. **Browser (this skill)** | browser-tester workers driving agent-browser | Exhaustive: every route, button, state, edge case + the web-shell checklist | Cheap, fast       |
| 2. Native shell             | `ac-qa-device` (agent-device + simctl)       | Real native taps + native-shell checklist                                   | Slower per action |

**Decision rule:** logic / layout / state / routing / console / responsive → here.
"Does the real app work when really _native_-touched" → `ac-qa-device`.

## Depth levels

Defined in **`_shared/qa-shared.md`**. Web specifics per level: **smoke** = the
registry-selected journeys (gate's affected-list; always includes auth + primary),
zero console errors; **full** adds every journey in `CORE/journeys/` + the
`web-shell-checklist.md` + responsive spot-checks; **exhaustive** adds the full-app
crawl (every route in `CORE/journeys/routes.md`), the appearance matrix (dark/light ×
viewport set), and a console-clean assertion on every route.

## Conductor flow

### Phase 0 — Orient + serve

- Selection + depth arrive from `_shared/verification-gate.md` (a conductor upstream
  already consulted it; standalone human runs: consult it yourself, or honor the
  human's explicit depth request).
- Mint RUN_ID if the orchestrator didn't hand one down (contract: `_shared/run-id.md`
  mint-if-absent rule — the same `qa-<app>-<RUN_ID>` session names below already
  assume RUN_ID exists): `RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"`.
- Derive `ARTIFACTS_DIR` per `_shared/run-id.md` (prefix `qa-browser`);
  `mkdir -p "$ARTIFACTS_DIR/evidence"`.
- **You own the local server** (workers never start/stop it): if targeting local,
  serve a **production build — never `pnpm dev`** (bd-yey1z doctrine, above): build
  once, then start it backgrounded —
  `pnpm build && pnpm start >"$ARTIFACTS_DIR/server.log" 2>&1`. Set `SERVER_STARTED=1`,
  wait until it answers; record `BASE_URL` (default `http://localhost:3000`). Deployed
  URL → skip the build/serve, `SERVER_STARTED` empty. Tear down the same `pnpm start`
  process (not any `pnpm dev`) at Phase-final.

### Phase 1 — Select journeys, assign lanes, write the manifest

- Journey list per depth (above), from the app's `CORE/journeys/`.
- **Lane assignment** (qa-shared.md): `mutates: false` in journey frontmatter AND no
  `proof.device_only_steps` → `parallel` lane; everything else (including journeys
  with no frontmatter) → `sequential`. Parallel cap **3** concurrent workers.
- **Batching:** >8 eligible journeys → group route-adjacent small journeys onto one
  worker (a worker may run 2–3 journeys back-to-back in its one session; it still
  writes one verdict file PER journey).
- Exhaustive extras run as dedicated workers: one **crawl worker**
  (`_tools/crawl-and-capture` over `routes.md` + per-route `errors`) — read-only by
  construction, so **parallel-lane eligible** (useful: many apps' journey sets skew
  heavily mutating, leaving the parallel lane thin) — and one **checklist worker**
  (`web-shell-checklist.md` + appearance matrix) — drives forms, so sequential.
- Write `$ARTIFACTS_DIR/journeys-manifest.json` (schema: qa-shared.md) **BEFORE any
  spawn** — including `skipped` with reasons (e.g. `surfaces: native` only).

### Phase 2 — Seed auth

Each worker authenticates its own session; the dependable path is **replaying the
app's login flow** (route + credentials from `CORE/journeys/environments.md`) inside
the worker's session. The agent-browser Auth Vault (`auth save`/`auth login`) may be
tried first as a shortcut, but workers MUST verify they actually landed
authenticated (e.g. on `/app`) before starting — the vault has reported success
without applying the session (0-for-4 across the 2026-07-12 shakedown; also
`--password-stdin` needs a TTY). Login replay stays parallel across workers.

### Phase 3 — Dispatch workers

Build each worker's prompt from **`references/journey-tester-prompt.md`** (fill
`{JOURNEY_FILE}`, `{BASE_URL}`, `{SESSION_NAME}`, `{DEPTH}`, `{ARTIFACTS_DIR}`,
`{AUTH_PROFILE}`). Dispatch to the **`browser-tester`** agent — a dedicated
narrow-tool agent; do not re-pin its model.

- **Parallel lane:** spawn up to 3 workers in a single message (one Task call per
  worker). As each returns, dispatch the next until the lane drains.
- **Sequential lane:** one worker at a time, in journey-registry order
  (criticality-descending).
- Session names: `qa-<app>-<RUN_ID>-w<N>` (wave slug when no RUN_ID) — assign in the
  manifest, pass via `{SESSION_NAME}`.
- Bound every wait (`_shared/delegation-contract.md`): cap per-worker wait at ~10 min
  of polling; a silent worker past the cap is a `stall` outcome, not a pause.

### Phase 4 — Collect + completeness

Diff the manifest against `$ARTIFACTS_DIR/verdict-*.json`. Missing verdicts →
re-spawn each missing worker ONCE (fresh session name, suffix `r2`). Still missing →
record as stall (qa-shared.md completeness rule). **Missing output ≠ "no findings".**
If a parallel worker's verdict shows connection-refused/server-overload symptoms,
drop the remaining parallel lane to sequential and note it in the report.

### Phase 5 — Aggregate + report

- File beads from verdict `findings` (conventions: qa-shared.md — you file them, not
  the workers; dedupe across verdicts first).
- Write journey `last_pass` stamps for PASSes (rules: §Journey stamps below).
- Emit the **`QA_VALIDATION`** block (qa-shared.md): `journeys_tested` from verdict
  statuses, `evidence` from verdict paths, `platform: browser-local` (or
  `browser-preview`/`browser-production`), `target:` browser + viewport(s),
  `shell_checklist:` from the checklist worker, `perf_observations:` qualitative.
- Mechanical self-check: `_shared/scripts/validate-qa-run.sh "$ARTIFACTS_DIR"` must
  exit 0 (completeness, concurrency, teardown).

### Phase 6 — Teardown sweep (mandatory, both paths)

Workers close their own sessions; you sweep the stragglers:

```bash
agent-browser session list | grep -F "qa-<app>-<RUN_ID>" || true   # should be empty
# close any leftover BY NAME (never `close --all`):
agent-browser --session <leftover> close
[ -n "$SERVER_STARTED" ] && pkill -f "next start" 2>/dev/null   # only the local-prod server YOU started; skip if a human runs their own
```

## Worker discipline (mirrored into the tester prompt — edit both together)

The rules the workers run under live in **`references/journey-tester-prompt.md`**
(refs renumber per snapshot; checkpoint fills; console errors ARE findings;
empty ≠ clean; catch toasts; direct-navigate routes; responsive is a matrix;
screenshot hygiene; close only your own session). Low-level CLI mechanics + the
runaway-Chrome teardown rationale: `browser-testing/SKILL.md`.

## Web shell — what to check

Full list → **`web-shell-checklist.md`** (SPA routing, storage/session persistence,
service worker / PWA, CORS/network, console hygiene, hydration, responsive, forms,
loading/empty/error states). This is what the browser plane uniquely proves — owned
by the checklist worker at full/exhaustive depth.

## Findings = beads

Conventions, types, and labels (`qa-finding` / `qa-blocker`) are in
**`_shared/qa-shared.md`**. Workers report findings in their verdict files; **the
conductor files the beads** (deduped). Tag bead descriptions with `browser QA`.

### Verdict comment (VERDICT grammar)

When the `QA_VALIDATION` pass completes, the conductor records the ceremony's outcome as
a structured **VERDICT comment** on each bead it validated — `VERDICT: passed:` (journey
PASS), `VERDICT: failed:` (a QA finding), or `VERDICT: blocked:` (infra-flaky / NO-STAMP)
— per the grammar in **`beads-standards` § Verification verdicts**. QA is a _verifier_
ceremony: the conductor writes the verdict from the verdict files (workers/implementers
never do — Goodhart guard). Each filed `qa-finding` bead also carries
`discovered-from: <bead-id|unknown>` linking the escape to the work that introduced it
(`unknown` when it can't be pinned).

## Journey stamps (last_pass)

After a journey **PASS**, update its `last_pass` frontmatter block in
`CORE/journeys/<name>.md` — `build`, `sha`, `date`, `platform: browser-local`
(or `browser-preview` / `browser-production`) — committed together with the QA
artifacts in the same run that emits `QA_VALIDATION`. The conductor writes stamps
from verdicts (workers never edit files). A **FAIL** never writes a stamp — the bead
trail covers failures; a stamp is proof of success only.
Schema + staleness rule: `_shared/verification-gate.md` §Journey registry.

**Conflict rule:** `last_pass` is last-writer-wins. On a merge conflict, keep
the NEWER stamp (compare `date`, then `build`) — never hand-merge a hybrid
stamp. An infra-flaky drive (daemon crash, stuck load, a selector that only
fails once) is the same **NO-STAMP**, never FAIL, never PASS — file a `qa-infra`
bead instead (same rule as `ac-qa-device`).

## Related files

- `_shared/qa-shared.md` — depth levels, findings=beads, `QA_VALIDATION` schema, **conductor/worker evidence protocol** (manifest/verdict schemas, lanes, session naming)
- `_shared/verification-gate.md` — selection + depth, journey registry schema (`mutates:`, `last_pass`)
- `_shared/scripts/validate-qa-run.sh` — mechanical pass validation
- `references/journey-tester-prompt.md` — the worker prompt template (the old inline core loop lives here now)
- `web-shell-checklist.md` — what ONLY the web shell surfaces
- `browser-testing/SKILL.md` — low-level `agent-browser` mechanics (worker-side)
- `ac-qa-device/SKILL.md` — the native-shell twin (Layer 2)
- `_tools/crawl-and-capture/` — the shared full-app crawl + screenshot primitive
- Consuming app's `CORE/journeys/` + `environments.md` + `routes.md` — the what
