# Browser / Web-Shell QA Workflow

> **The browser workflow of `ac-qa`.** Shared conventions — depth levels,
> findings=beads, the `QA_VALIDATION` report — live in the `ac-qa` spine
> (`SKILL.md`) and `references/qa-shared.md`. This file owns the web/browser
> specifics only: the generator/healer model over `e2e/journeys/`, plus
> exploratory depth. The low-level `agent-browser` CLI mechanics live in
> **`references/driver-browser.md`** (loaded by exploratory workers, not by you).

> **Generic skill — method only, zero app facts.** Symlinked from agent-compounds
> and shared across consuming apps. **App specifics (URLs, credentials, routes,
> journeys, viewport policy) → the consuming app's `.claude/skills/CORE/SKILL.md`** —
> journeys in `CORE/journeys/`, real URLs/creds in `CORE/journeys/environments.md`,
> the crawl route list in `CORE/journeys/routes.md`.

# Browser / Web-Shell QA Workflow

**You are the generator and the healer. You never pass a journey yourself.**
Journey specs live in the app at `e2e/journeys/*.spec.ts`, generated from the
app's `CORE/journeys/*.md` — one spec per journey, assertions from the
journey's `proof.asserts`, device-only and prod-unsafe steps excluded by
rule, never by silence (each exclusion named in the spec header). The
generator writes specs; the healer repairs them. CI passes them — journey
stamps derive from CI results, never from an agent pass. Exploratory depth
survives for what specs cannot cover (see § Exploratory depth); everything
else runs unmanned.

No `Task` tool, or spawns still failing after 2 retries/rung → you have NO
workers: read `ac-pipeline/references/degraded-mode.md` before writing the
manifest (bd-nreuv).

## Platform note (read first)

Runs **anywhere** (any OS — no Mac needed). Requires either a **local production
build** served via **`scripts/qa/serve-prod.sh`** (per-HEAD + input-hash cache; see
bd-chd5p.4) or a deployed URL (preview/production).
For hybrid (Capacitor) apps the browser renders the **same bundle** the native
webview does — so this twin owns the cheap, exhaustive DOM/visual coverage; route
native-shell concerns (safe-area, splash, plugins, OAuth sheets) to the `workflows/device.md` workflow.

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

## Layered QA model — what proves what here

| Layer                        | Prover                                       | Coverage                                                                    |
| ---------------------------- | -------------------------------------------- | --------------------------------------------------------------------------- |
| 1. **Journeys (generated)**  | CI (quality-gate workflow) on `e2e/journeys/` | Every journey's asserts, ARIA-first, from CORE definitions                  |
| 2. **Exploratory**           | implementer workers driving agent-browser    | What specs cannot cover: new-surface sweeps, crawl, appearance matrix       |
| 3. Native shell              | `workflows/device.md` (agent-device + simctl) | Real native taps + native-shell checklist                                   |

**Decision rule:** specified journey behavior → the generated specs. Unspecified,
new, or visually-judged surface → exploratory. "Does the real app work when
really _native_-touched" → the device workflow.

## Depth levels

Defined in **`ac-qa/references/qa-shared.md`**. Web specifics per level: **smoke** = the
registry-selected journey specs; **full** adds every spec in `e2e/journeys/` + the
`references/web-shell-checklist.md` + responsive spot-checks; **exhaustive** adds an
exploratory crawl (every route in `CORE/journeys/routes.md`), the appearance matrix
(dark/light × viewport set), and a console-clean assertion on every route.
**Flag-gated journeys need a flag-ON build at every level** — `qa-shared.md` § Flag-gated paths need a flag-ON build; an env-gated path that is off in every environment is unverified by construction, so sign it off only with a flag-ON pass or an explicit UNVERIFIED record.

## Generator flow

- Selection per depth (above), from the app's `CORE/journeys/`. One spec per
  journey at `e2e/journeys/<name>.spec.ts`, assertions from the journey's
  `proof.asserts` only. Shared login/URL helpers live beside the existing
  suite — import them, never duplicate them. Skip cleanly (`test.skip`) when
  credentials are absent; never fake a session.
- Exclusions are named in the spec header: device-only steps, prod-unsafe
  writes, and state the test cannot manufacture stay out WITH their reason.
  An exclusion without a reason is a silent pass and is refused in review.
- Validate locally before committing: serve a **production build — never
  `pnpm dev`** (bd-yey1z doctrine, § Platform note) and run the new specs to
  green. Local green is validation, never proof — it earns the commit, not
  the stamp.
- Commit the specs with the app repo's own lane. CI owns the run from here.

### Phase 0 — Orient + serve (generator and healer both need it)

- Mint RUN_ID if the orchestrator didn't hand one down (contract:
  `ac-pipeline/references/run-id.md` mint-if-absent rule).
- **You own the local server**: serve a **production build — never `pnpm dev`**
  (bd-yey1z doctrine, above) via the app's cached serve script (do **not** raw
  `pnpm build && pnpm start` — that burns ~1–1.5h/run and skips the
  SHA+input-hash key):
  ```bash
  # Requires a CLEAN tree (git status --porcelain empty, incl. untracked).
  # Dirty → script exits non-zero; commit or clean first. If dcg rejects the log
  # redirect, pipe into tee — never bypass (ac-pipeline/references/shell-guardrails.md).
  # Never wrap serve-prod.sh or its next-server in timeout(1) or any SIGTERM-ing
  # wrapper: the kill surfaces as a browser "Failed to fetch", not as infra.
  # Teardown is the port-kill below.
  scripts/qa/serve-prod.sh 2>&1 | tee "$ARTIFACTS_DIR/server.log" >/dev/null &
  SERVER_PID=$!
  SERVER_STARTED=1
  # Wait until it answers; record BASE_URL (default http://localhost:3000).
  # Capture fingerprints from the script's stdout (also in server.log):
  #   SERVED_SHA=…  INPUT_HASH=…  ENV_FINGERPRINT=…  CACHE_KEY=…  ENV_FINGERPRINT=…  CACHE_HIT=0|1
  # Fold SERVED_SHA + INPUT_HASH/ENV_FINGERPRINT into QA evidence so ceremonies
  # can verify build↔commit↔env identity.
  ```
  Deployed URL → skip the build/serve, `SERVER_STARTED` empty. Tear down the same
  `next start` / serve-prod process (not any `pnpm dev`) at the end. **Serve failure
  = non-run (ac-61zh.1):** non-zero serve or dead URL → STOP, write
  `$ARTIFACTS_DIR/unverified_tiers.txt` (qa-shared.md § non-run artifact), hand off.

## Healer flow — healing is the only agent touch after generation

CI red on a journey spec is either UI drift (the app moved, the assert didn't)
or a real defect (the assert is right, the app is wrong). Tell them apart by
reproducing against a local prod build (§ Phase 0 — Orient + serve), then:

- **Drift → heal the spec:** update selectors/assertions to the new UI, keeping
  the journey's `proof.asserts` as the authority — a healed spec that no longer
  asserts its journey's assert is a weakened spec, not a healed one. Never
  weaken an assertion to force green (delete the assertion, widen a matcher to
  meaninglessness, branch on build flavor): a red you cannot heal honestly is a
  finding, not a spec defect.
- **Defect → file the bead:** `qa-finding`/`qa-blocker` per qa-shared.md, with
  `discovered-from:` and the failing spec path; the app fix lands through the
  normal implement lane, and the spec goes green behind it.
- Re-run the healed spec locally to green and commit through the app repo's
  lane. CI re-runs to green → stamp (see § Journey stamps). More than one
  healing per spec per fortnight indicts the spec-generation recipe, not the
  app — say so in the report (plan assumption 6).

**Concurrent-session confounds still apply to local parallel runs** (bd-iro5f):
`SIGNED_OUT` / 401-on-authenticated-request findings from concurrent
same-account sessions are CONFOUNDED until re-confirmed in a clean
single-session run — file at reduced severity with a "needs clean-env
re-confirmation" note if you cannot re-run clean.

## Exploratory depth — what specs cannot cover

Specs prove specified behavior. New surfaces, the full-app crawl (every route
in `CORE/journeys/routes.md`), the appearance matrix (dark/light × viewport
set), and console-clean on every route still need eyes: run them as
exploratory workers built from **`references/journey-tester-prompt.md`**, one
worker per sweep, findings filed as beads per § Findings = beads. The crawl
primitive is `_tools/crawl-and-capture`; the surface list is
`references/web-shell-checklist.md`.

### Teardown sweep (mandatory, both paths)

Exploratory workers close their own sessions; you sweep the stragglers:

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

**Delete exploratory-created data rows (mandatory — you own this, not the workers)**
(bd-wlpbk). Mutating exploratory runs create real rows (records, etc.) in the test
account, and workers deliberately DO NOT self-clean them
(`references/journey-tester-prompt.md` § Teardown: "leave cleanup to the conductor's
sweep") — so a leftover row survives every run unless YOU delete it here. It is a "leave
the account as found" violation and pollutes the next run's baseline. Concretely:

1. Confirm no exploratory run is still in flight (all worker sessions closed, per the
   session sweep above).
2. Query the test account for rows created during THIS run's window — e.g. entries whose
   title/name matches the run's QA marker, or `created_at` within `[run_start, now]`
   (psql or another direct-DB path against the app's data table for this journey;
   or the app's admin/UI).
3. Delete them by id, then re-query to confirm zero remain. Record the deleted-row count in
   the QA report.

## Explorer discipline (mirrored into the tester prompt — edit both together)

The rules exploratory workers run under live in
**`references/journey-tester-prompt.md`** (refs renumber per snapshot; checkpoint
fills; console errors ARE findings; empty ≠ clean; catch toasts; direct-navigate
routes; responsive is a matrix; screenshot hygiene; close only your own session).
Low-level CLI mechanics + the runaway-Chrome teardown rationale:
`ac-qa/references/driver-browser.md`.

## Web shell — what to check

Full list → **`references/web-shell-checklist.md`** (SPA routing, storage/session persistence,
service worker / PWA, CORS/network, console hygiene, hydration, responsive, forms,
loading/empty/error states). This is what the browser plane uniquely proves — owned
by exploratory sweeps at full/exhaustive depth.

## Findings = beads

Conventions, types, and labels (`qa-finding` / `qa-blocker`) are in
**`ac-qa/references/qa-shared.md`**. Exploratory workers report findings in their
verdict files with `"bead": "pending"`; **you file the beads** (deduped) **as each
verdict lands** — not at pass end — and stamp the id back into the verdict. Tag bead
descriptions with `browser QA`. CI spec failures arrive already attributed to a spec
path: heal the spec (drift) or file the app defect — never re-file the spec redness
itself as a finding.

### Verdict comment (VERDICT grammar)

When a CI run or an exploratory sweep completes, record the ceremony's outcome as
a structured **VERDICT comment** on each bead it validated — `VERDICT: passed:` (CI
green), `VERDICT: failed:` (a QA finding), or `VERDICT: blocked:` (infra-flaky /
NO-STAMP) — per the grammar in **`beads-standards` § Verification verdicts**. QA is
a _verifier_ ceremony: you write the verdict from CI results and verdict files
(implementers never do — Goodhart guard). Each filed `qa-finding` bead also carries
`discovered-from: <bead-id|unknown>` linking the escape to the work that introduced it
(`unknown` when it can't be pinned).

## Journey stamps (last_pass) — from CI, never from agent passes

After CI greens a journey spec, update its `last_pass` frontmatter block in
`CORE/journeys/<name>.md` — `build`, `sha`, `date`, `platform: browser-ci` — from
the CI run's evidence (run id, commit sha, date), committed with the next lane
commit. A local generator/healer green earns the spec commit, never the stamp. A
**FAIL** never writes a stamp — the bead trail covers failures; a stamp is proof
of success only.
Schema + staleness rule: `ac-pipeline/references/verification-gate.md` §Journey registry.

**Conflict rule:** `last_pass` is last-writer-wins. On a merge conflict, keep
the NEWER stamp (compare `date`, then `build`) — never hand-merge a hybrid
stamp. An infra-flaky result (daemon crash, stuck load, a selector that only
fails once in CI) is the same **NO-STAMP**, never FAIL, never PASS — file a `qa-infra`
bead instead (same rule as the device workflow).

## Related files

- `ac-qa/references/qa-shared.md` — depth levels, findings=beads, `QA_VALIDATION` schema
- `ac-pipeline/references/verification-gate.md` — selection + depth, journey registry schema (`mutates:`, `last_pass`)
- `references/journey-tester-prompt.md` — the exploratory worker prompt template
- `references/web-shell-checklist.md` — what ONLY the web shell surfaces
- `ac-qa/references/driver-browser.md` — low-level `agent-browser` mechanics (worker-side)
- `workflows/device.md` — the native-shell workflow (Layer 2)
- `_tools/crawl-and-capture/` — the shared full-app crawl + screenshot primitive
- Consuming app's `CORE/journeys/` (the journey definitions) + `e2e/journeys/` (the generated specs) + `environments.md` + `routes.md`
