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
> that gate owns the _whether_. Conductors (`ac-loop`,
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

## Flag-gated paths need a flag-ON build

**A code path behind a `NEXT_PUBLIC_*` or env gate that is OFF in every environment is
UNVERIFIED BY CONSTRUCTION** — no test and no QA pass in this matrix has ever executed it.
Before signing off a journey that is flag-gated: either **(a)** run at least one pass against
a build with the flag ON, or **(b)** record the path explicitly as **UNVERIFIED** in the QA
report and treat its first enablement as a first-run, not a re-run. **"Flag is off everywhere"
is zero evidence, not low risk** — it is a reason to ADD that build, not to skip the path.
**Audit flag-dark ERROR branches first**: they are the least-observed code in the system.

Both directions bite. `NEXT_PUBLIC_SIGNUP_ENABLED` OFF in every environment meant every gate
rendered `SignupDisabled` while signup was 100% broken in prod for months (bd-zszse/bd-lxyzl).
The same flag ABSENT from `.env.capacitor` did the inverse: `NEXT_PUBLIC_*` is inlined at build
time, so absent reads as ENABLED and native shipped a live signup form web had disabled
(bd-native-signup-flag-divergence-stewq — caught because device QA looked, not by any gate).

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

> **Schema contract (bd-g4ktj):** the validator
> (`_shared/scripts/validate-qa-run.sh`) reads **flat `dispatched[]`** —
> `.dispatched[].journey` / `.dispatched[].lane` / …. Do **not** write a top-level
> `workers[]` array as the completeness key (that produces false missing-verdict /
> null iterate). **One `dispatched[]` row per journey** (= one `verdict-<journey>.json`
> basename) even when a single worker runs 2–3 journeys back-to-back.

**Verdict files.** Each worker writes `$ARTIFACTS_DIR/verdict-<journey>.json` as its
mandatory Output contract:

```json
{
  "journey": "<name>",
  "lane": "parallel|sequential",
  "session": "<session name>",
  "started_at": "<ISO8601>",
  "ended_at": "<ISO8601>",
  "status": "PASS|FAIL|INCONCLUSIVE",
  "assertions": [
    {
      "assert": "<from journey proof.asserts>",
      "result": "PASS|FAIL|NOT_PROVABLE_IN_<HARNESS>",
      "evidence": "<path>"
    }
  ],
  "covered": ["<what was actually driven — undriven steps are NOT tested>"],
  "console_errors": "<summary or none>",
  "findings": [
    {
      "title": "",
      "severity": "qa-finding|qa-blocker",
      "repro": "",
      "bead": "bd-xxxxx | pending | not-bead-worthy: <reason>"
    }
  ]
}
```

Evidence = **paths on disk** (screenshots under `$ARTIFACTS_DIR/evidence/`), never
inlined into the report.

**INCONCLUSIVE is a real third state, not a soft PASS (bd-muutz).** `NOT_PROVABLE_IN_<HARNESS>`
(e.g. `NOT_PROVABLE_IN_BROWSER`) is the honest assertion result when the harness structurally
cannot observe the surface — see `verification-gate.md` §Step 1b. **A journey with any such
result among its `proof.asserts` MUST NOT be `PASS`: it is `INCONCLUSIVE` — no `last_pass`
write, and the residue gets a tracking bead.** For downstream gates INCONCLUSIVE counts as
not-yet-verified, never as a pass (fail-safe: `ac-merge`/`ac-distribute` read PASS/FAIL only,
so an INCONCLUSIVE journey can never make the pass-level `status:` PASS on its own strength).
Observed: a browser worker correctly returned NOT_PROVABLE_IN_BROWSER on 2 of 3 paywall
assertions while the journey verdict still read PASS — recording a native-only payment change
as browser-verified.

> Scope, so this does not swallow the two residues that already work: a step declared in
> `proof.device_only_steps` is **known, human-reviewed** residue — keep the existing handling
> (exclude from `covered`, say why in `notes`); it does not make the journey INCONCLUSIVE. An
> infra-flaky drive stays `status: FAIL` + empty findings + an infra-flake note (deliberately
> stricter). `NOT_PROVABLE_IN_<HARNESS>` is for the third case: a `proof.asserts` entry the
> harness turns out to be structurally unable to observe, **undeclared** — the one that used to
> read PASS.

**Every finding carries a `bead` field — no ambiguous sentinel (bd-xx9yv).** Legal values: a
real id, `pending` (worker wrote it, conductor has not filed yet), or `not-bead-worthy:
<reason>` (a deliberate decision). **Never `none`** — it conflates the two, and a conductor
triaging a stalled child read 5 `none` findings as orphaned and filed all 5; the child then
woke and filed its own richer 5 → 4 duplicates + 1 false P2 compliance bead to retract.
Workers still never touch the ledger (single-writer); the conductor files and stamps the id
back, so `pending` is a resumable state, not a silent loss. **File as each verdict LANDS, not
in one batch at pass end** — per `rule-known-action-capture-beads-not-prose`, a finding whose
bead depends on a single late aggregation step orphans when that step dies. Guard:
`validate-qa-run.sh` fails a run that still has `pending`/`none` findings.

**Visual evidence goes to Slack as UPLOADED IMAGES, never a `/tmp` path in a card**
(Craig's standing directive, 2026-07-17 — memory `visual-evidence-send-to-slack-not-paths`).
Craig owns visual sign-off but acts from his phone: a `/tmp` path in a Slack card is
unreachable and transient, so whenever a pass produces a screenshot that needs his eyes,
UPLOAD the actual image:

```bash
slack-send -c C0AQ7964ZU6 "<context>" --file a.png b.png   # #sofi
```

- **Message BEFORE `--file`** — argparse is greedy, so the message becomes the
  upload's `initial_comment`; a message placed after `--file` is swallowed as a filename.
- **Required context** (in that message): bead id, commit SHA, what changed, and what
  specifically needs Craig's judgment (e.g. "stop position / band height is yours").
- **Only the LIVE decision surface** — send the current shots, skip superseded ones.
- **Send when evidence is produced, or at the batch ceremony** — don't batch across
  ceremonies. A conductor may upload directly, or relay a worker's evidence path.

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
  -d "QA finding (<date>, <device|browser> QA): <repro + evidence + journey ref>
      ## Test Scope (real test file/describe anchors — grep them first — plus the
      QA modality + journey checkpoint this finding came from)" \
  --labels qa-finding,unrefined
# User-facing break or trapped state? Add the blocker label:  --labels qa-finding,qa-blocker,unrefined

# SUSPECTED finding (cause unknown, weak repro) → an investigation bead:
br create "investigate: <symptom>" -t investigation \
  -d "QA finding (<date>, <device|browser> QA): <observed + repro attempt>" \
  --labels qa-finding,unrefined
```

> **Always include `unrefined`** — a raw `br create` bead skips the refine gate unless it carries the `unrefined` label; without it the bead is treated as already-refined and gets implemented on a raw QA note. `unrefined` routes it through `ac-bead-refine` first.
>
> **Always emit `## Test Scope` with grep-verified anchors** (same bar as `ac-hygiene`; `_shared/bead-conventions.md` §Body template) — the real file(s)/describe block(s) a validator runs, each grepped before it is cited, plus the QA modality (`browser: <journey>.md §<checkpoint>` / `device: …`) this finding surfaced from. You have the journey and the repro in hand right now; refine's Test Scope gate would otherwise have to author it cold, and a finding bead with no test plan is how the fix ships behind a test that cannot fail.
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
journeys_tested: [list, with PASS/FAIL/INCONCLUSIVE each]
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
