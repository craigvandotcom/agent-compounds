---
name: ac-qa
description: 'Use when QA-ing an app build through journeys — browser (web shell) or device (native shell). One engine, two workflows: workflows/browser.md (agent-browser — SPA routing, storage/session, service worker, CORS, console, hydration, responsive) and workflows/device.md (agent-device + simctl — real native taps, keyboard, safe-area, splash, plugins, system sheets, deep links, push, appearance). Depth levels, journey reuse, findings=beads, and the conductor/worker evidence protocol are shared. Triggers on "QA the app", "test web app", "browser QA", "device QA", "simulator QA", "test native app", "validate the build", "web smoke test", "native smoke test", "QA on iOS". NOT for writing unit/component/E2E tests (testing), ad-hoc UI bug repro (ui-debug), or visual polish (ui-elevate).'
---

> **One engine, two workflows.** `workflows/browser.md` proves the web shell;
> `workflows/device.md` proves the native shell. Shared conventions — **depth
> levels, journey reuse, findings=beads, the `QA_VALIDATION` report, the
> conductor/worker evidence protocol** — live in **`references/qa-shared.md`**;
> both workflows reference it so they stay in lockstep. Each workflow owns its
> toolchain specifics only.

> **Generic skill — method only, zero app facts.** Symlinked from agent-compounds
> and shared across consuming apps. **App specifics (URLs, credentials, routes,
> journeys, bundle id, build command, simulator target, viewport policy) → the
> consuming app's `.claude/skills/CORE/SKILL.md`** — journeys in `CORE/journeys/`,
> web facts in `CORE/journeys/environments.md` + `routes.md`, native facts in
> `CORE/journeys/native.md`.

# QA Skill — one engine, two workflows

**You are the conductor. You never drive the browser or the simulator yourself.**
Journeys run in **implementer** subagents (the workers; the journey prompt is the
lens) — one journey per worker, each reporting a structured verdict file. You hold
the manifest, the verdicts, the gate decision, and the report; workers hold the DOM
snapshots, console noise, accessibility trees, and screenshots. The full evidence
protocol (manifest schema, verdict schema, lanes, completeness rule, session naming)
is **`references/qa-shared.md` § Conductor / worker evidence protocol** — read it now.
**No `Task` tool, or spawns still failing after 2 retries/rung → you have NO workers:**
read `ac-pipeline/references/degraded-mode.md` before writing the manifest.

## Workflows

| Workflow                  | Tool                  | Proves                                                                                          | Runs on   |
| ------------------------- | --------------------- | ----------------------------------------------------------------------------------------------- | --------- |
| `workflows/browser.md`    | agent-browser         | Web shell: SPA routing, storage/session persistence, service worker, CORS, console, responsive  | any OS    |
| `workflows/device.md`     | agent-device + simctl | Native shell: real taps, keyboard, safe-area, splash, plugins, system sheets, deep links, push  | macOS     |

**Decision rule:** logic / layout / state / routing / console / responsive → browser.
"Does the real app work when really _native_-touched" → device.

## Layered QA model

| Layer                | Tool                        | Coverage                                                     | Cost              |
| -------------------- | --------------------------- | ------------------------------------------------------------ | ----------------- |
| 1. Browser (DOM)     | agent-browser               | Exhaustive: every route, button, state, edge case            | Cheap, fast       |
| 2. Native shell      | agent-device + simctl       | Every journey happy-path with real native taps               | Slower per action |
| 3. DOM-in-shell      | Appium webview context      | DOM truth inside the real shell (origin/cookies/storage)     | Flaky; escape hatch only |

For hybrid (Capacitor) apps the webview renders the **same bundle** the browser
does — so exhaustive DOM-matrix coverage stays in Layer 1. Layer 2 proves what only
the native shell can: real touch pipeline, keyboard, safe-area, splash/cold-start,
plugin bridge, system sheets, deep links, lifecycle. Full list →
`references/native-shell-checklist.md`.

## Depth levels

Defined in **`references/qa-shared.md`** (smoke / full / exhaustive). Per-workflow
specifics: `workflows/browser.md` § Depth levels, `workflows/device.md` § Depth
levels. **Flag-gated journeys need a flag-ON build at every level** —
`references/qa-shared.md` § Flag-gated paths need a flag-ON build; an env-gated path
that is off in every environment is unverified by construction, so sign it off only
with a flag-ON pass or an explicit UNVERIFIED record.

## Conductor flow

The shared shape; each workflow file owns its toolchain-specific steps.

1. **Orient + serve/build (yours, once).** Selection + depth arrive from
   `ac-pipeline/references/verification-gate.md` (standalone human runs: consult it
   yourself, or honor an explicit depth request). Mint RUN_ID if the orchestrator
   didn't hand one down (contract: `ac-pipeline/references/run-id.md` mint-if-absent
   rule) and derive `ARTIFACTS_DIR`. Browser: serve a local **production** build.
   Device: Platform Gate, then build + install. **Serve/build failure = non-run
   (ac-61zh.1):** write `$ARTIFACTS_DIR/unverified_tiers.txt`
   (`references/qa-shared.md` § non-run artifact) and hand off.
2. **Manifest.** Write `$ARTIFACTS_DIR/journeys-manifest.json` **BEFORE any spawn** —
   including `skipped` with reasons. Validator key is `dispatched[]` (not
   `workers[]`); required fields per row: at least `journey`, `lane` (see
   `ac-pipeline/scripts/validate-qa-run.sh` + qa-shared example).
3. **Dispatch.** One worker per journey via the workflow's prompt template
   (`references/journey-tester-prompt.md` for browser,
   `references/device-journey-prompt.md` for device). Browser: parallel lane (cap 3)
   + sequential lane. Device: sequential only. Bound every wait
   (`ac-pipeline/references/delegation-contract.md`) — a silent worker past the cap
   is a `stall`, not a pause.
4. **Collect + file beads AS EACH VERDICT LANDS** — never batch filing to the end.
   Stamp the id back into the verdict's `findings[].bead`. Missing output ≠
   "no findings"; re-spawn each missing worker once.
5. **Aggregate + report.** Emit the **`QA_VALIDATION`** block
   (`references/qa-shared.md`). VERDICT writeback when the manifest lists
   `proves: [<bead-id>, …]`. Mechanical self-check:
   `ac-pipeline/scripts/validate-qa-run.sh "$ARTIFACTS_DIR" --baseline-findings
   "$BASELINE_FINDINGS"` must exit 0, AFTER the writeback.
6. **Teardown sweep (mandatory).** Close sessions, stop the server / reset the sim,
   and delete rows the run created. Each workflow owns its sweep.

## Findings = beads

File each finding as a bead the moment it is confirmed — conventions, types, and
labels (`qa-finding` / `qa-blocker`) are in **`references/qa-shared.md`**. Workers
report findings in their verdict files with `"bead": "pending"`; **the conductor
files the beads** (deduped), stamps the id back, and never leaves a `pending` entry.
Tag bead descriptions with `browser QA` or `device QA`; each filed bead carries
`discovered-from: <bead-id|unknown>`.

### Verdict comment (VERDICT grammar)

When the `QA_VALIDATION` pass completes, the conductor records the ceremony's
outcome as a structured **VERDICT comment** on each bead it validated —
`VERDICT: passed:` (journey PASS), `VERDICT: failed:` (a QA finding), or
`VERDICT: blocked:` (infra-flaky / NO-STAMP) — per the grammar in
**`beads-standards` § Verification verdicts**. QA is a _verifier_ ceremony: the
conductor writes the verdict from the verdict files (workers/implementers never do —
Goodhart guard).

## Journey stamps (last_pass)

After a journey **PASS**, update its `last_pass` frontmatter block in
`CORE/journeys/<name>.md` — `build`, `sha`, `date`, `platform` — committed with the
QA artifacts in the same run that emits `QA_VALIDATION`. The conductor writes stamps
from verdicts (workers never edit files). A **FAIL** never writes a stamp; an
infra-flaky drive is a **NO-STAMP**, never FAIL, never PASS. Schema + staleness rule:
`ac-pipeline/references/verification-gate.md` §Journey registry.

**Conflict rule:** `last_pass` is last-writer-wins. On a merge conflict, keep the
NEWER stamp (compare `date`, then `build`) — never hand-merge a hybrid stamp.

## Related files

- `references/qa-shared.md` — depth levels, journey reuse, findings=beads, `QA_VALIDATION` schema, **conductor/worker evidence protocol** (manifest/verdict schemas, lanes, session naming)
- `ac-pipeline/references/verification-gate.md` — selection + depth, journey registry schema (`mutates:`, `last_pass`)
- `ac-pipeline/scripts/validate-qa-run.sh` — mechanical pass validation
- `references/journey-tester-prompt.md` · `references/device-journey-prompt.md` — the worker prompt templates
- `references/driver-browser.md` · `references/driver-device.md` — low-level tool mechanics (worker-side)
- `references/native-shell-checklist.md` · `references/web-shell-checklist.md` — what ONLY each shell surfaces
- `_tools/crawl-and-capture/` — the shared full-app crawl + screenshot primitive
- Consuming app's `CORE/journeys/` + `environments.md` + `routes.md` + `native.md` — the what
