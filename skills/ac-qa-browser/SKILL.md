---
name: ac-qa-browser
description: Use when QA-ing the WEB app build in a browser — full journey validation against the real web shell (SPA routing, storage/session persistence, service worker, CORS, console hygiene, hydration, responsive viewports), appearance matrix, screenshot evidence. The web twin of ac-qa-device. Runs on any OS against a local production build (via scripts/qa/serve-prod.sh) or a deployed URL — never the pnpm dev server. Triggers on "test web app", "browser QA", "QA in browser", "validate web build", "web smoke test", "QA the deployed web app".
---

> **The web twin.** `ac-qa-browser` proves the web shell; `ac-qa-device` proves
> the native shell. Shared conventions — **depth levels, journey reuse,
> findings=beads, the `QA_VALIDATION` report, the conductor/worker evidence
> protocol** — live in **`ac-pipeline/references/qa-shared.md`**; both twins reference it so they
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
**`ac-pipeline/references/qa-shared.md` § Conductor / worker evidence protocol** — read it now.
**No `Task` tool, or spawns still failing after 2 retries/rung → you have NO workers:
read `ac-pipeline/references/degraded-mode.md` before writing the manifest (bd-nreuv).**

## Platform note (read first)

Runs **anywhere** (any OS — no Mac needed). Requires either a **local production
build** served via **`scripts/qa/serve-prod.sh`** (per-HEAD + input-hash cache; see
bd-chd5p.4) or a deployed URL (preview/production).
For hybrid (Capacitor) apps the browser renders the **same bundle** the native
webview does — so this twin owns the cheap, exhaustive DOM/visual coverage; route
native-shell concerns (safe-area, splash, plugins, OAuth sheets) to `ac-qa-device`.

> **QA server target — local-PROD only, NEVER `pnpm dev` (doctrine, bd-yey1z).**
> Browser QA MUST target a local **production** build via `scripts/qa/serve-prod.sh`
> or a deployed URL — never the Next.js dev server. Under sustained QA load the dev
> server's Fast-Refresh watcher enters a rebuild storm (~10 min in it began serving
> 0-byte 200s with CPU/RSS climbing until killed); a prod build (`next start`) was
> proven stable for 5 concurrent + sequential workers (bd-yey1z, 2026-07-12).
>
> **Do not re-implement the cache in this skill** — delegate to `serve-prod.sh`.
> The script refuses ANY dirty tree (incl. untracked); commit/clean before QA.
> Cache key = HEAD_SHA + fingerprint of `.env*` + `pnpm-lock.yaml` (not SHA-only).

## Layered QA model — what to test here

| Layer                       | Tool                                         | Coverage                                                                    | Cost              |
| --------------------------- | -------------------------------------------- | --------------------------------------------------------------------------- | ----------------- |
| 1. **Browser (this skill)** | browser-tester workers driving agent-browser | Exhaustive: every route, button, state, edge case + the web-shell checklist | Cheap, fast       |
| 2. Native shell             | `ac-qa-device` (agent-device + simctl)       | Real native taps + native-shell checklist                                   | Slower per action |

**Decision rule:** logic / layout / state / routing / console / responsive → here.
"Does the real app work when really _native_-touched" → `ac-qa-device`.

## Depth levels

Defined in **`ac-pipeline/references/qa-shared.md`**. Web specifics per level: **smoke** = the
registry-selected journeys (gate's affected-list; always includes auth + primary),
zero console errors; **full** adds every journey in `CORE/journeys/` + the
`web-shell-checklist.md` + responsive spot-checks; **exhaustive** adds the full-app
crawl (every route in `CORE/journeys/routes.md`), the appearance matrix (dark/light ×
viewport set), and a console-clean assertion on every route. **Flag-gated journeys need a flag-ON build at every level** — `qa-shared.md` § Flag-gated paths need a flag-ON build; an env-gated path that is off in every environment is unverified by construction, so sign it off only with a flag-ON pass or an explicit UNVERIFIED record.

## Conductor flow

### Phase 0 — Orient + serve

- Selection + depth arrive from `ac-pipeline/references/verification-gate.md` (a conductor upstream
  already consulted it; standalone human runs: consult it yourself, or honor the
  human's explicit depth request).
- Mint RUN_ID if the orchestrator didn't hand one down (contract: `ac-pipeline/references/run-id.md`
  mint-if-absent rule — the same `qa-<app>-<RUN_ID>` session names below already
  assume RUN_ID exists): `RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"`.
- Derive `ARTIFACTS_DIR` per `ac-pipeline/references/run-id.md` (prefix `qa-browser`);
  `mkdir -p "$ARTIFACTS_DIR/evidence"`.
- **You own the local server** (workers never start/stop it): if targeting local,
  serve a **production build — never `pnpm dev`** (bd-yey1z doctrine, above) via the
  app's cached serve script (do **not** raw `pnpm build && pnpm start` — that burns
  ~1–1.5h/run and skips the SHA+input-hash key):
  ```bash
  # Requires a CLEAN tree (git status --porcelain empty, incl. untracked).
  # Dirty → script exits non-zero; commit or clean first. dcg blocks a variable-built redirect target: if the log redirect below is rejected, do NOT bypass — pipe into tee instead (ac-pipeline/references/shell-guardrails.md).
  scripts/qa/serve-prod.sh 2>&1 | tee "$ARTIFACTS_DIR/server.log" >/dev/null &
  SERVER_PID=$!
  SERVER_STARTED=1
  # Wait until it answers; record BASE_URL (default http://localhost:3000).
  # Capture fingerprints from the script's stdout (also in server.log):
  #   SERVED_SHA=…  INPUT_HASH=…  CACHE_KEY=…  ENV_FINGERPRINT=…  CACHE_HIT=0|1
  # Fold SERVED_SHA + INPUT_HASH/ENV_FINGERPRINT into QA evidence so ceremonies
  # can verify build↔commit↔env identity.
  ```
  Deployed URL → skip the build/serve, `SERVER_STARTED` empty. Tear down the same
  `next start` / serve-prod process (not any `pnpm dev`) at Phase-final.

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
- Write `$ARTIFACTS_DIR/journeys-manifest.json` (schema: `ac-pipeline/references/qa-shared.md`)
  **BEFORE any spawn** — including `skipped` with reasons (e.g. `surfaces: native` only).
  **Validator key is `dispatched[]`** (not `workers[]`) — one entry per journey /
  verdict basename even when one worker runs multiple journeys. Required fields per
  row: at least `journey`, `lane` (see `validate-qa-run.sh` + qa-shared example).

### Phase 2 — Seed auth

Each worker authenticates its own session; the dependable path is **replaying the
app's login flow** (route + credentials from `CORE/journeys/environments.md`) inside
the worker's session. The agent-browser Auth Vault (`auth save`/`auth login`) may be
tried first as a shortcut, but workers MUST verify they actually landed
authenticated (e.g. on `/app`) before starting — the vault has reported success
without applying the session (0-for-4 across the 2026-07-12 shakedown; also
`--password-stdin` needs a TTY). Login replay stays parallel across workers.

> **Concurrent same-account hazard — assign per-worker accounts, or serialize
> auth-sensitive waves** (bd-iro5f, 2026-07-14). When N parallel workers all authenticate
> as the SAME account against a shared Supabase, refresh-token rotation across the
> concurrent same-account sessions — compounded by dev-server HMR/Fast-Refresh churn
> resetting auth singletons — produces spurious `SIGNED_OUT` / 401-on-authenticated-request
> / session-expired events in the workers (observed in all 4 workers on run
> 20260714-170945; each recovered instantly on re-login, proving credentials valid). These
> findings are CONFOUNDED, not real defects. Mitigation, best-first:
> - **PRIMARY — per-worker accounts:** give each parallel worker its OWN test account so
>   no two concurrent sessions share a refresh-token family. Source the pool from the app's
>   `CORE/journeys/environments.md` (an `accounts:`/worker-account list) and assign one per
>   worker in the manifest (`account` field per parallel entry), passed via `{AUTH_PROFILE}`.
>   **Provisioning the extra accounts is a human/Craig step** — until the pool exists, fall back:
> - **INTERIM — serialize auth-sensitive waves:** set a `serialize_auth: true` manifest flag
>   that forces the parallel lane to run sequentially (one active session at a time) whenever a
>   per-worker account pool is NOT provisioned, OR run against a quiescent dev server / local
>   Supabase with a seeded account (no HMR churn). Serialize is the cheap stopgap; per-worker
>   accounts is the robust answer.

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
- Bound every wait (`ac-pipeline/references/delegation-contract.md`): cap per-worker wait at ~10 min
  of polling; a silent worker past the cap is a `stall` outcome, not a pause.

### Phase 4 — Collect + completeness

Diff the manifest against `$ARTIFACTS_DIR/verdict-*.json`. Missing verdicts →
re-spawn each missing worker ONCE (fresh session name, suffix `r2`). Still missing →
record as stall (qa-shared.md completeness rule). **Missing output ≠ "no findings".**
If a parallel worker's verdict shows connection-refused/server-overload symptoms,
drop the remaining parallel lane to sequential and note it in the report.

**File each verdict's beads AS IT LANDS, here — not in Phase 5 (bd-xx9yv).** Filing used to
be a Phase-5 batch, so every finding sat as prose in a `bead: pending` artifact until one
late step ran; when a conductor stalled between the two, 5 findings looked orphaned, got
double-filed by the triaging parent, and cost 4 retractions + 1 false compliance bead. Read
each verdict as it appears, file its action-worthy findings, and **stamp the id back into the
verdict's `findings[].bead`** (dedupe against what you have already filed, not a batch
pre-pass). No verdict leaves this phase with a `pending` finding.

### Phase 5 — Aggregate + report

- Confirm every verdict `findings[]` entry carries a real bead id or an explicit
  `not-bead-worthy: <reason>` (filed in Phase 4; conventions: qa-shared.md — you file them,
  not the workers). A leftover `pending` here means Phase 4 was skipped — file it now.
  - **Clean-env re-confirmation rule (bd-iro5f):** a `SIGNED_OUT` / 401-on-authenticated-request
    / session-expired finding produced during a CONCURRENT same-account run is NOT blocker-class
    on its own — it is likely confounded by refresh-token rotation + HMR churn (see Phase 2). Before
    filing any such finding as `qa-blocker`, re-confirm it in a clean environment (per-worker
    account, or a serialized single-session run, or a quiescent/local-Supabase run). File at
    reduced severity with a "needs clean-env re-confirmation" note if you cannot re-run it clean.
- Write journey `last_pass` stamps for PASSes (rules: §Journey stamps below).
- Emit the **`QA_VALIDATION`** block (qa-shared.md): `journeys_tested` from verdict
  statuses, `evidence` from verdict paths, `platform: browser-local` (or
  `browser-preview`/`browser-production`), `target:` browser + viewport(s),
  `shell_checklist:` from the checklist worker, `perf_observations:` qualitative.
- Mechanical self-check: `ac-pipeline/scripts/validate-qa-run.sh "$ARTIFACTS_DIR"` must
  exit 0 (completeness, concurrency, teardown).

### Phase 6 — Teardown sweep (mandatory, both paths)

Workers close their own sessions; you sweep the stragglers:

```bash
agent-browser session list | grep -F "qa-<app>-<RUN_ID>" || true   # should be empty
# close any leftover BY NAME (never `close --all`):
agent-browser --session <leftover> close
# Kill-by-PORT teardown (bd-g4ktj) — pkill -f "next start" does NOT match pnpm start's
# real process (`next-server`); port stayed bound 2×. Prefer port from BASE_URL
# (default 3000) or SERVED port printed by serve-prod.sh.
if [ -n "$SERVER_STARTED" ]; then
  PORT="${PORT:-3000}"
  # Prefer port embedded in BASE_URL when present
  if [ -n "${BASE_URL:-}" ]; then
    PORT=$(printf '%s' "$BASE_URL" | sed -E 's#.*:([0-9]+).*#\1#' | grep -E '^[0-9]+$' || echo "$PORT")
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | xargs kill 2>/dev/null || true
  else
    # fallback only — primary is port kill
    kill "${SERVER_PID:-}" 2>/dev/null || true
  fi
fi
```

**Delete worker-created data rows (mandatory — the conductor owns this, not the workers)**
(bd-wlpbk). Mutating journeys create real rows (food entries, etc.) in the test account, and
workers deliberately DO NOT self-clean them (`references/journey-tester-prompt.md` § Teardown:
"leave cleanup to the conductor's sweep") — so a leftover row survives every run unless YOU
delete it here. It is a "leave the account as found" violation and pollutes the next run's
baseline (incident: `QA Smoke Test 20260716-w2` entry left in test@neometa.app). Concretely:

1. Confirm no QA run is still in flight (this run's workers are all closed, per the session
   sweep above).
2. Query the test account for rows created during THIS run's window — e.g. entries whose
   title/name matches the run's QA marker, or `created_at` within `[run_start, now]` (for BCA:
   psql via `CURATE_POSTGRES_URL`, `foods` table — memory `bca-tables-public-schema-curate-psql-access`;
   or the app's admin/UI).
3. Delete them by id, then re-query to confirm zero remain. Record the deleted-row count in
   the QA report.

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
**`ac-pipeline/references/qa-shared.md`**. Workers report findings in their verdict files with
`"bead": "pending"`; **the conductor files the beads** (deduped) **in Phase 4, as each
verdict lands** — not at pass end — and stamps the id back into the verdict. Tag bead
descriptions with `browser QA`.

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
Schema + staleness rule: `ac-pipeline/references/verification-gate.md` §Journey registry.

**Conflict rule:** `last_pass` is last-writer-wins. On a merge conflict, keep
the NEWER stamp (compare `date`, then `build`) — never hand-merge a hybrid
stamp. An infra-flaky drive (daemon crash, stuck load, a selector that only
fails once) is the same **NO-STAMP**, never FAIL, never PASS — file a `qa-infra`
bead instead (same rule as `ac-qa-device`).

## Related files

- `ac-pipeline/references/qa-shared.md` — depth levels, findings=beads, `QA_VALIDATION` schema, **conductor/worker evidence protocol** (manifest/verdict schemas, lanes, session naming)
- `ac-pipeline/references/verification-gate.md` — selection + depth, journey registry schema (`mutates:`, `last_pass`)
- `ac-pipeline/scripts/validate-qa-run.sh` — mechanical pass validation
- `references/journey-tester-prompt.md` — the worker prompt template (the old inline core loop lives here now)
- `web-shell-checklist.md` — what ONLY the web shell surfaces
- `browser-testing/SKILL.md` — low-level `agent-browser` mechanics (worker-side)
- `ac-qa-device/SKILL.md` — the native-shell twin (Layer 2)
- `_tools/crawl-and-capture/` — the shared full-app crawl + screenshot primitive
- Consuming app's `CORE/journeys/` + `environments.md` + `routes.md` — the what
