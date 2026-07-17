# Shared QA methodology (ac-qa-device + ac-qa-browser)

Platform-agnostic conventions for the QA twins. Each twin owns its toolchain,
core loop, and shell checklist; this file owns what they share so the two stay
in lockstep. Reference it from a twin as `_shared/qa-shared.md`.

The split:

| Plane                                                                                              | Owner                                            |
| -------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| Native shell (safe-area, splash, plugins, OAuth sheets, keyboard, deep links, lifecycle)           | **`ac-qa-device`** (`native-shell-checklist.md`) |
| Web shell (CORS, SPA routing, storage, service worker, console, responsive)                        | **`ac-qa-browser`** (`web-shell-checklist.md`)   |
| Depth levels · journey reuse · findings=beads · report schema · conductor/worker evidence protocol | **this file**                                    |

For hybrid (Capacitor) apps the device webview renders the **same bundle** as the
browser, so visual/DOM-matrix coverage stays cheap in the browser (`ac-qa-browser`);
the device twin proves only what the native shell adds. Don't QA the same DOM logic
twice — route by plane.

> **Whether to run a twin at all (and how deep)** is decided upstream by
> **`_shared/verification-gate.md`** — it classifies the wave diff and selects passes +
> depth so a one-line fix doesn't trigger a simulator boot. This file owns the _how_;
> that gate owns the _whether_. Conductors (`ac-pipeline` Verify stage, `ac-loop`,
> `ac-merge`'s smoke net) consult the gate, not this file, to decide selection.

## Depth levels

- **smoke** — build/serve, launch, first-paint, auth, primary journey. Run after
  changes that touch the relevant plane, before a ship gate.
- **full** — every journey in the app's `CORE/journeys/` walked + the twin's shell
  checklist + appearance spot-checks.
- **exhaustive** — full + every screen/control reachable, appearance matrix
  (dark/light × 2–3 type sizes), responsive/lifecycle matrix, perf sanity. Release-grade.

## Reusing the app's journeys

The app's `CORE/journeys/*.md` files are the **what** (flows, exact button labels,
checkpoints, edge cases). A QA twin is the **how**. To run a journey: follow its
happy path step-by-step, locating each step's control in the latest snapshot
(accessibility tree for device, DOM for browser) instead of trusting a stale ref.

**Journey docs drift.** When a label/flow in the doc doesn't match the live tree,
trust the tree, complete the journey via the real UI, and fix the doc as part of
the pass (that's a finding's resolution, not a blocker).

## Prod-write ban + secrets (the minimal package, Craig's decision)

**Admin/shared-data writes are never QA'd against prod.** Any action that
mutates cross-user shared data — canonical shared-data zone gates, the
research/retrigger pipeline, curator merge/amend, a zoning-model override, or
any other cross-user shared record — is proven against the **local stack**
(integration tests, or a browser drive against `pnpm dev` if a live UI walk is
genuinely needed) and never against prod. Prod stays the **default** target for
user-scoped journeys — the test account's own food/signal/wellness/settings
data — plus read-only smoke. Each journey doc's `prod_unsafe:` frontmatter key
names the concrete buttons/actions this applies to for that journey (an empty
list is a deliberate "nothing unsafe here" statement, not an omission) —
consult it before picking a target environment for a given journey.

**Secrets stay redacted.** Env values (API keys, credentials, tokens) are
always redacted in agent output, regardless of which environment is under test.

**Deferred by explicit decision, not rejected.** Heavier options considered for
this problem — a three-class data model, a seed/reset pipeline, CSP lockdown —
are DEFERRED-UNTIL-PAIN. Don't re-propose them from scratch; only re-open if
the minimal rule above stops being enough.

## Conductor / worker evidence protocol (both twins + ui-polish fan-out)

QA passes run as a **conductor + tester-subagent split**, never inline: the conductor
(the pass's spawned session) holds the manifest, verdicts, and gate decision; tester
subagents (`browser-tester` / `device-tester` agents) hold the per-journey execution
noise (snapshots, console output, screenshots). The conductor never drives the
browser/simulator itself and never holds raw page state — it spot-reads flagged
evidence files only. Rationale: exhaustive sweeps in one context suffer late-journey
attention decay and compaction risk, at conductor-model prices.

**Artifacts dir** — derive per `_shared/run-id.md` (prefixes `qa-browser` / `qa-device` /
`ui-polish`), never glob.

**Manifest before spawn.** The conductor writes `$ARTIFACTS_DIR/journeys-manifest.json`
BEFORE dispatching any worker — a dispatched journey with no verdict is a mechanical
partial failure, never a silent pass:

```json
{
  "run_id": "<RUN_ID or empty>",
  "app": "<app>",
  "depth": "smoke|full|exhaustive",
  "session_prefix": "qa-<app>-<RUN_ID>",
  "dispatched": [
    { "journey": "<name>", "lane": "parallel|sequential", "worker": "w1" }
  ],
  "skipped": {
    "<journey>": "<reason — visible skips only, per verification-gate.md>"
  }
}
```

**Verdict files.** Each worker writes `$ARTIFACTS_DIR/verdict-<journey>.json` as its
mandatory Output contract:

```json
{
  "journey": "<name>",
  "lane": "parallel|sequential",
  "session": "<session name>",
  "started_at": "<ISO8601>",
  "ended_at": "<ISO8601>",
  "status": "PASS|FAIL",
  "assertions": [
    {
      "assert": "<from journey proof.asserts>",
      "result": "PASS|FAIL",
      "evidence": "<path>"
    }
  ],
  "covered": ["<what was actually driven — undriven steps are NOT tested>"],
  "console_errors": "<summary or none>",
  "findings": [
    { "title": "", "severity": "qa-finding|qa-blocker", "repro": "" }
  ]
}
```

Evidence = **paths on disk** (screenshots under `$ARTIFACTS_DIR/evidence/`), never
inlined into the report.

**Completeness rule** (`_shared/delegation-contract.md` applies): bound each worker's
wait; manifest ⊖ verdict files = re-spawn each missing worker ONCE, then record it in
the QA_VALIDATION block as `status: FAIL` with `notes: stall — <journeys>`. Missing
output ≠ "no findings".

**Lanes + journey classification.** A journey's frontmatter field `mutates: true|false`
declares whether it writes app state (create/edit/delete, settings, transactions).
**Absent ⇒ `mutates: true`** (fail-safe: serialize — misclassification costs wall-clock,
never data races; app test accounts are typically shared). Parallel-eligible =
`mutates: false` and no `device_only_steps`. Browser twin: parallel lane cap **3**
concurrent workers (dev-server load), sequential lane for everything else. Device twin:
**sequential only** (simulator concurrency is flaky and collision-prone — see
`ac-qa-device/references/incidents.md`).

**Session naming + teardown.** Worker sessions are `qa-<app>-<RUN_ID>-w<N>` (or the
wave slug when no RUN_ID). Each worker tears down ONLY its own named session, on
success AND failure paths. The conductor sweeps leftovers matching its
`session_prefix` at pass end. Never `close --all`, never bare `pkill` (kills sibling
sessions — documented incidents).

**Aggregation.** The conductor merges verdicts into the single QA_VALIDATION block
below (`journeys_tested` from verdict statuses, `findings_filed` from filed beads,
`evidence` from verdict paths). Downstream consumers (ac-merge, ac-distribute) are
unchanged. Mechanical validation: `_shared/scripts/validate-qa-run.sh $ARTIFACTS_DIR`
asserts manifest⊖verdict completeness, parallel-lane overlap, and teardown.

## Findings = beads (file immediately, like failing tests)

A finding is anything where the app diverges from the journey docs' expected
behavior, plus a11y gaps and shell bugs. Do NOT bury findings in prose or
"note for later" — **file each as a bead the moment it's confirmed**, same session:

```bash
# CONFIRMED finding (root cause or solid repro) → a fix bead:
br create "fix(<area>): <finding title>" -t bug \
  -d "QA finding (<date>, <device|browser> QA): <repro + evidence + journey ref>" \
  --labels qa-finding,unrefined
# User-facing break or trapped state? Add the blocker label:  --labels qa-finding,qa-blocker,unrefined

# SUSPECTED finding (cause unknown, weak repro) → an investigation bead:
br create "investigate: <symptom>" -t investigation \
  -d "QA finding (<date>, <device|browser> QA): <observed + repro attempt>" \
  --labels qa-finding,unrefined
```

> **Always include `unrefined`** — a raw `br create` bead skips the refine gate unless it carries the `unrefined` label; without it the bead is treated as already-refined and gets implemented on a raw QA note. `unrefined` routes it through `ac-bead-refine` first.
>
> **Type is not automatically `bug`.** `-t bug` is a shipped **product** defect only. Test-gap / missing-coverage / infrastructure findings use `-t task` (or `-t investigation` if the cause is unconfirmed), NEVER `-t bug` — mistyping them inflates the preemptive bug lane.

**Type + label semantics (compose, not compete):**

- **Type** = kind of work. `bug` when confirmed — file the fix directly; no
  "confirm this" ceremony bead when the run already diagnosed it. `investigation`
  when genuinely unconfirmed — acceptance is "reproduce → spawn fix beads or
  document-and-close".
- **Label** = gating. `qa-blocker` gates the next merge (`ac-merge` refuses while
  open). `qa-finding` alone = real but shippable.
- **Lineage**: fix beads spawned by an investigation carry a typed dep —
  `br dep add <fix-id> <investigation-id> -t discovered-from` — then close the
  investigation.
- **Journey-doc drift is NOT a finding** — fix the doc inline during the run.
- A finding that turns out to be intended behavior is resolved by updating the
  journey doc and closing the bead (an expectation change, like updating a test).
- **In-wave fixes re-enter the unit gate.** When a QA finding is fixed in the same
  wave, the fix commit must re-run the touched path's unit tests **including the
  SIBLING test files that exercise that path** — not just the new spec written for
  the finding. A late fix that adds a gate/guard breaks the siblings that assumed
  the old behavior, and only CI catches it (BCA wave/023: footer-Upload gate fix →
  6 sibling specs red on the PR, 2026-07-02). Cheapest form: re-run the app's full
  affected-test command after the LAST commit, not the first.

## Reporting — the QA_VALIDATION block

Both twins emit the same block; the `platform:` field disambiguates which plane
was proven. Consumed by `ac-merge` (gates the PR) and `ac-distribute` (gates the
ship — it keys on `platform:` so a browser PASS can't satisfy a native ship gate).

```markdown
QA_VALIDATION:
platform: ios-simulator | android-emulator | browser-local | browser-preview | browser-production
target: [sim/emulator model + OS | browser + viewport]
app_build: [how built/served — command + branch/commit]
depth: smoke | full | exhaustive
journeys_tested: [list, with PASS/FAIL each]
shell_checklist: [items checked, PASS/FAIL — native-shell-checklist.md | web-shell-checklist.md]
appearance_matrix: [combos checked]
findings_filed: [bead ids created this run, qa-blocker flagged]
a11y_findings: [unlabeled controls / violations discovered]
perf_observations: [qualitative only — hangs, freezes, leaks, layout shift]
evidence: [screenshot/video paths]
status: PASS | FAIL
notes: [issues, platform-impossible flows skipped and why, journey-doc drift fixed]
```

> History: this block was `SIM_QA_VALIDATION` (device-only) until the browser twin
> landed (2026-06-18). The `platform:` field is the load-bearing addition — ship
> gates predicate on it.
