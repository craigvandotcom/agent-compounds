# The ac2 bead schema

The one bead contract: the shape `ac-beadify` compiles TO and refuses against (**no probe,
no bead**), the contract every `br create`/`br q` in this fleet satisfies at capture
whoever files, and the shape `ac-polish` grades with `bead-checklist.md`. Four sections,
all durable: an ac2 bead stores no tree-state that decays between authoring and claim.

Canon is cited, never restated here — bead taxonomy, status/priority, close reasons and
pipeline labels live in `beads-standards/reference/bead-conventions.md`; the human-gate
card shape lives in `reference/human-gate-template.md`; the test-tier slugs are the table
below; run and commit discipline in `ac-pipeline/references/` (`commit-discipline.md`,
`run-ledger.md`).

Two enforcers implement exactly this file — change the contract HERE first, then both:

- **Runtime** — `hooks/bead-capture-guard.py`, a PreToolUse Bash hook. Blocks a
  non-conforming `br create` an agent types, in any skill, in any repo.
- **Static** — `lint.sh` Check 19. Blocks a non-conforming TEMPLATE shipping in `skills/`,
  before any agent ever runs it.

The runtime gate catches what agents type. The static gate catches what the registry ships.
Neither alone is sufficient: a correct template can be typed wrong, and a stale template
poisons every future run that copies it. A `br` invoked as a child process (Node/TS
`execFileSync`) is invisible to the runtime hook — those paths enforce in code instead: make
provenance a REQUIRED field on the call site so an omission fails the type-check, rather
than filing an unattributed bead.

## Header fields

`title` · `type` · `priority` · deps (`blocks` / parent-child) · `labels` (risk tags as
needed: `migration` · `native`).
- Epic beads (`type: epic`) carry `## Success Criteria` plus probe-bearing
  `## Acceptance Criteria` — the epic's AC is the plan's silver bullet verbatim;
  the probes are what a worker pick closes against (D3).
- **Epic title: `<Name> — <what it implements>`**, written for a reader five years out who
  never saw the plan. Name: 2–4 plain words, ≤32 characters — the plan slug in words when it
  reads plainly, never an unexplained codename; the board shows only the Name. The clause
  (≥6 words): what the system does after this epic that it did not before — the mechanism,
  not the motive. `Machine settings file — tools read each machine's paths and org root from
  one gitignored machine.json`, not `One local settings file per machine`. Lint check 35
  rule 7 holds it.
- An epic reaches its children by **parent-child** (containment) only — containment alone
  already keeps the epic from being picked before its children close. Any `blocks` edge
  with an epic endpoint still fabricates a critical path and stays refused.
- A child never cites its parent epic in `## Consumes`; parent-child containment is the only
  epic relation and is not a closure premise.
- Edge direction is `<blocked> depends-on <blocker>`. A write that CLOSES a cycle is
  refused, rc 5 (measured on `br` 0.5.12) — only a lone reversed edge that closes no cycle
  lands silently, so read every edge back (`br dep cycles`, then `br show` on both ends).
- `br create` REJECTS `-f` alongside a title, rc 4 (measured on `br` 0.5.12): `-f` is a
  bulk `## Title` importer, not a body file — creation bodies go `-d "$(cat <file>)"`
  (`--description-file` is deliberately not adopted). That routes the body through the
  shell, so bead prose must stay dcg-safe (no command substitution, no unbalanced
  quoting). The capture guard reads the inline `-d` value, so a file/heredoc body is
  OPAQUE to it and its born-`Probe:` check fails open on exactly this form; the backstop
  is the committed-board check (`lint/checks/35-board-integrity.py`), which reads the
  landed body and refuses a probe-less implementable bead at the ledger commit. Only
  comments and receipts take `-f <file>`.

## Required axes

| Axis | Rule | Scope |
|---|---|---|
| `origin:<skill>` | The creating workflow — see § The origin label below. | EVERY bead |
| Readiness | One of `unrefined` / `human-gate`. `refined` is stamped exclusively by a refine pass on convergence and is never applied at creation, whatever readiness label rides beside it and whatever the type (epic included) — and it never rides beside `human-gate`: a human bead is not implementation-ready by definition, however the refine pass reads it. | Every NON-EPIC bead |
| Touchers | A `## Delivers` path that git TRACKS (on disk but untracked is NEW) and that is REFERENCED by another file owes, beneath its bullet, one line: ``touchers: `<command>` · owned by: <bead ids> \| out-of-scope: <reason>``. Command-derived, never remembered; no count is stored, so nothing goes stale — the command is re-run LIVE at stamp time and refused only if it now finds nothing. New files and unreferenced files owe nothing. One path per `## Delivers` bullet. Derived and checked by `skills/_tools/touchers.sh` (`derive` writes the line at beadify; `check` re-runs it): `stamp-refined.sh` § TOUCHERS LEG calls `check` at REFINE, not capture, and refuses `[unowned-touchers]` on a missing, malformed or zero-referrer line. VERIFIED at the DIFF: `skills/ac-implement/scripts/diff-closure.sh --bead <id>` greps the callers of what actually changed and refuses `[unowned-callers]` on any the line did not name — the declaration is the claim, the diff is the sensor (worker §5 · code-polish §1 · ac-review Phase 5). The `--bead` scope oracle is the bead's own `## Delivers` paths, diffed against `HEAD` rather than the branch's whole history — so a sibling's already-committed WIP in a shared swarm checkout cannot seed a symbol this bead's close depends on. Why: bead-polish measured a 16.2% repair rate from hand-listed consumer sets, and every serious 2026-08/09 defect was a caller nobody enumerated; a stored count added a SECOND way to go stale on top of that (measured: 15/19, 31/48, 24/42 artifacts downgraded on count alone) with the command already re-run live at every check — the count carried no information the command did not already carry. | Every bead, at refine |
| Probe | `## Acceptance Criteria` with at least one bullet of the shape ``Probe: `<command>` — tier: <slug>`` — born probe-bearing, so pickup has something runnable to verify against instead of a verdict someone will improvise later. Exempt: `epic` / `decision` / `investigation` by type, and any bead carrying the `human-gate` label regardless of type (the human ruling itself is the acceptance criterion — this is what makes an `ACTION:` card, typed `task`, legal with no `Probe:` line). A filer that cannot name a probe and is not a human-gate card files the bead as `investigation`, the type that says so — never as a probe-less task. See § The device rule below for work only a device can verify. | Every `bug` / `task` / `feature` bead, at creation, unless `human-gate` |

Put `origin:` FIRST in the label list. Epics are exempt from readiness: they are containers,
never picked up for implementation. This mirrors `ac-tidy`'s nightly readiness-label repair,
which fixes the same gap nightly for beads that predate or bypass the gate.

### The origin label

Every bead carries exactly one `origin:` label naming the workflow that created it.

| Label | Meaning |
|---|---|
| `origin:<skill>` | The skill that created the bead — `origin:ac-review`, `origin:ac-hygiene`, `origin:ac-beadify`, `origin:ac-triage`, `origin:ac-qa`, `origin:curate-foods`, `origin:dream`, `origin:reflect`, `origin:ac-land`, `origin:ac-align`, `origin:ac-prove`, `origin:ac-backlog`, `origin:ac-polish`. |
| `origin:manual` | Hand-authored, created outside any skill. |
| `origin:unknown` | Genuinely unattributable. Legal and honest — never guess, never invent a source. |

Not the same as `skill:<name>`, which names the bead's SUBJECT ("this bead is about
`ac-implement`") where `origin:` names its CREATOR — independent axes, a bead may carry
both. Also distinct from the field bead-conventions.md's § Lineage defines, which names the
SOURCE BEAD an escape traces to: `origin:` names the creating workflow, that field names the
source bead — complementary, not duplicates.

**Enforcement, three layers:**

1. **Creation gate** — `hooks/bead-capture-guard.py`, a PreToolUse Bash hook, blocks any
   `br create`/`br q` whose `-l/--labels` carries no `origin:` token, and one whose labels
   carry more than one (two is corrupt data, not two provenances — neither is repaired,
   both are refused at the moment of capture). Tokenizes with shlex, so a `br create`
   quoted inside a description or heredoc never false-blocks. Fails OPEN on unparseable
   shell: a guard must not wedge an unattended run.
2. **Scripted creation** — the hook cannot see `br` invoked as a child process from Node/TS.
   Those paths enforce in code instead: `origin` is a required field on the call site, so a
   call omitting it fails the TypeScript build.
3. **Refine backstop** — a bead that somehow reaches refine with no `origin:` label is
   REFUSED, never repaired: `stamp-refined.sh` downgrades it and names the missing label
   rather than inferring or guessing one. Refusing at refine, not just at creation, is what
   makes "one origin per bead, never zero" hold for beads that predate the gate too.

Nightly, `ac-tidy` REPORTS post-cutover beads still missing `origin:` — a guard bypass or a
stale template, never auto-labelled.

**Forward-only — no backfill.** Enforcement does not rewrite history. Most pre-cutover beads
carry no recoverable origin signal, so inventing one would fabricate provenance rather than
record it. The `ac-align` lint therefore excludes pre-cutover beads entirely; without that
exclusion the report drowns in rows nobody can honestly fix.

### The device rule (project-agnostic)

`device` means the AC needs a device runner to settle — never a stand-in for "hard to
automate". An AC that needs one writes its probe as
``Probe: `DEVICE VERDICT — <what the device must show>` `` and the bead carries the
`device` label. Each project declares its OWN device route in its own docs (a simulator
reachable over the network, a device farm, whatever that project actually has) — the shared
tooling never assumes one. Where a project has no such route, or the work needs a physical
device, the bead is a `human-gate` instead, never `device`: the card comes to the operator.

## Creation invocation

```bash
br create "<verb-first title>" -t <type> -p <0-4> \
  --labels "origin:<skill>,unrefined,<domain labels>" \
  -d "<body — typed sections per beads-standards § Body template contract>"
```

Titles that can begin with `-` (a markdown bullet) must use the equals form
`--title=<value>`: `br`'s clap parser rejects a bare positional or two-token flag value
starting with `-`.

## Subagent creates

A subagent files **NOTHING**. Every `br create` is refused — a human-gate fork included —
and the subagent returns the work to its coordinator as a **PROPOSED-BEAD** block for the
conductor to confirm and file: title · files · `User impact:` (and for a fork: gate reason ·
options · recommendation). The coordinator is the single writer of beads its workers
discover, so the batch boundary stays the one place new work enters the board. Enforcement:
`bead-capture-guard` refuses when it can identify a subagent — the `agent_id` stdin field, or
the ambient `AC_SUBAGENT=1` a harness wrapper sets.

## The four sections

| Section | Bar |
|---|---|
| `## Intent` | Why + rationale + context + boundary (what is explicitly OUT) + gotchas. Symbol and file names are welcome as hints; **line numbers are banned** — a `file:line` anchor decays before the claim and nothing cheap tells you it has. **The header is per type:** `bug` → `## Steps to Reproduce` (a bug's intent IS its repro), `epic` → `## Success Criteria` (an epic's intent IS what done looks like), everything else → `## Intent`. Same content, same four sections — `br lint` (v0.2.16) compiles those two per-type headers in and cannot be configured, so the schema meets it by naming, never by a fifth section. |
| `## Acceptance Criteria` | 3–7 falsifiable behavioural ACs, EACH naming its executable probe and tier (see below). Observable outcomes only. The header phrase is load-bearing for `br lint`: its matcher is case-insensitive and tolerates trailing text, but both words must appear. |
| `## Delivers` | The named artifacts this bead promises — the exact strings a dependent's `## Consumes` will cite. Paths, script names, receipts. **One path per bullet** (one `touchers:` line cannot own two), and a delivered path that git ALREADY TRACKS owes that line beneath its bullet — derive it with `skills/_tools/touchers.sh derive <path>`, never by hand (§ Required axes above). **Path-shaped Delivers is REQUIRED for `task`/`feature`/`epic` beads**: every bullet must carry a path-shaped token (`name.ext`) — a dotted child bead id (`<epic-id>.3`) is not one, and an epic's paths must exist at close — because close-evidence-check cross-references the close reason against exactly those tokens. A prose-only Delivers line is refused at compile — ac-beadify's refusal step applies this schema to every bead before creation, and a prose-only Delivers is a schema violation — because one that slips through makes every close of that bead unverified forever (`UNVERIFIABLE-DELIVERS`; audit the backlog with `skills/ac-pipeline/scripts/close-evidence-check.sh --list-unverifiable`). A bullet naming a path this bead DELETES reads `deleted-<kind>: <path>` (`deleted-doc:`, `deleted-script:`, …) — close-evidence-check checks the path is ABSENT at HEAD instead of present, the mirror image of every other bullet. |
| `## Consumes` | One `<blocker-id> -> <artifact>` per line, or the single word `none`. Every line needs a matching dependency edge and every edge a matching line (parity is graded). |

A compiled epic's AC is the plan's silver bullet verbatim. Every child AC quotes its plan
"Done when:" verbatim and adds only the probe. A deliverable split across several beads has
each child quote the parent line and add its own slice's values. "a test named X passes"
is not an AC — it names a test, not a behaviour.

Nothing else. There is no Scope, Proof, Notes or Discussion section — that content is either
`## Intent` or it is not durable.

## Closeout — the epic's last bead (D3/D8)

Every plan-derived epic gets one closeout bead, even with no one-shots — keyed off
`beadified:` absent, so a re-compile of a retired plan emits none.
Header: type `task`, title `closeout: <epic title>`, the epic's priority.
`## Intent` names the epic it closes. `## Consumes` one line per sibling
`<id> -> <its first Delivers path>` so parity holds; wire sibling→closeout `blocks` edges
and read them back like any other edge. The epic relation is parent-child containment only;
no epic-endpoint `blocks` edge is emitted.
`## Acceptance Criteria`: `test ! -e <path>` per one-shot the epic leaves behind, plus
`grep -q '^delivered:' <plan>` — tier: none. `## Delivers`: each deleted path plus the
plan path (the worker appends the `delivered:` line to the retired plan as it deletes).
One-shot touchers refusal (D4): beadify refuses a one-shot whose touchers reach outside
the epic's own children. `Detect:` lift (D7): a backtick `Detect:` rides the normal
no-probe refusal; prose ones are listed, never silently dropped, as
`assumption not compiled: <n>`.

## The probe rule

Every AC ends with its probe in exactly this form, on ONE line:

    Probe: `<command>` — tier: <tier>

- **Machine-extractable.** The command sits alone inside single backticks so a checker can
  lift it without a human reassembling it. Canonical extractor (run it on an extracted bead
  body, not on this file):

~~~sh
grep -o 'Probe: `[^`]*`' <bead-file> | sed 's/^Probe: `//; s/`$//'
~~~

- **Runnable as written.** `sh -c '<command>'` must reach completion with no syntax error
  and no *command not found* for its leading word. It does NOT mean the probe passes — at
  authoring every probe is RED by construction (see falsifiability in `bead-checklist.md`).
  Single-file form matters too: unit probes use `pnpm test:one <file>`, integration probes
  use `npx vitest run --config vitest.integration.local.config.mts <file>` — never
  `pnpm <script> -- <file>` (pnpm forwards the literal `--`) or `grep -c` as pass/fail.
- **Probing an artifact the bead has yet to create**, use the guarded form
  `test -x <path> && bash <path>` — the leading word exists today, the probe is honestly
  red until the artifact lands, and it becomes the real suite run the moment it does.
- **Tier** is one slug from the *Test-tier slugs* table
  (below): `standing-vitest` · `standing-harness` · `supabase-integration` · `e2e` · `none`.
- Prose fragments (`wc -l`, "diff the file", "grep for it") are NOT probes and `ac-beadify`
  refuses the bead.
- **`human-gate` beads are exempt** (§ Required axes above) — the recorded human decision IS
  the verification, not a command. A `decision`-typed gate is exempt by type already; an
  `ACTION:` card (typed `task`, `human-gate`-labelled) is exempt by this label.
- **Requires-env / Requires-command / Requires-file.** A probe that depends on something
  outside the tree it runs in — a service reachable only from a device, a binary not on
  every machine's `PATH`, a fixture file a probe reads but does not create — states that
  dependency on its own line beneath the AC: `Requires-env: <VAR>`, `Requires-command:
  <name>`, `Requires-file: <path>`. A gate reading the bead knows to check the dependency
  before running the probe, rather than reading an unrelated failure as the probe's own
  verdict.

WHY this is a rule and not advice: this pipeline's own refine found SEVEN broken probes
across seven rounds — five fail-open, two guaranteed false-fail, and the seventh was the
repair of the sixth. Every one had been authored without being run. Executing them
mechanically at round 7 recovered 2 runnable commands out of 14 beads. A probe a machine
cannot run is a probe nobody ran.

## Test-tier slugs

| Slug | Meaning |
|------|---------|
| `standing-vitest` | The repo's default unit/component gate (`pnpm test` / `pnpm test:all`) |
| `standing-harness` | The repo's bash proof harnesses (`*.test.sh`) named in its AGENTS.md Project Commands |
| `supabase-integration` | Local-stack DB suite (`pnpm test:integration:local` or the repo equivalent) |
| `e2e` | Playwright / device / browser journey suite |
| `none` | Docs, config, or prose — no executable suite applies |

An AC touching `supabase/migrations/**`, `lib/db/**`, or any SQL / RLS / RPC / GRANT
surface **MUST** name `supabase-integration`. `none` is valid only when no executable
suite can break. Each slug gets a one-line justification.

## Deleted relative to the six-element contract

| Gone | Where that work happens now |
|---|---|
| `## Anchors` | flight-check, at claim, once, on a fresh tree |
| `## Baselines` | flight-check's premise pass (artifact, environment, perishable claim) |
| the `Territory` header section + test-tier table | each AC's own tier; the close-time causal probe |
| `## Declared RED` | the AC's probe — RED is *recorded* at claim, not *promised* at authoring |
| `## Sequence + risk` | the dependency graph and the risk labels |
| Scope prose · `## Proof` | `## Intent`'s boundary; the close receipt |

## Example bead

Extract it as a standalone description body with:
`sed -n '/ac-example-bead:start/,/ac-example-bead:end/p' skills/beads-standards/reference/bead-schema.md`

<!-- ac-example-bead:start -->
title: ac-implement: close-gate refuses a close whose named probe never ran
type: task · priority: 1 · parent: `<epic-id>` · labels: none

## Intent
`br close` is reachable from any shell, so today "the named probe was actually executed" is
a habit of honest workers rather than a property of the system — which is exactly the class
of claim this pipeline exists to stop trusting. close-gate.sh reads the bead's ACs, greps
the bead's comments for the claim-time probe receipt, and refuses the close when the receipt
is absent. OUT of scope: judging whether the probe PASSED (the causal probe does that), and
any change to `br` itself. Gotcha: the gate is invoked from the worker's close step, not
from a git hook — a hook cannot see a DB-only close.

## Acceptance Criteria
- The gate ships as an executable script the worker loop can invoke.
  Probe: `test -x skills/ac-implement/scripts/close-gate.sh` — tier: none
- A close on a bead carrying no probe receipt is refused, and the refusal names the missing
  receipt rather than exiting silently.
  Probe: `test -x skills/ac-implement/scripts/close-gate.test.sh && bash skills/ac-implement/scripts/close-gate.test.sh` — tier: standing-harness
- The refusal emits the exact string the worker loop greps for, so the loop can branch on it.
  Probe: `grep -q 'CLOSE-REFUSED:' skills/ac-implement/scripts/close-gate.sh` — tier: none
- The close step of the skill invokes the gate, so the gate is on the write path and not
  merely available.
  Probe: `grep -q 'close-gate.sh' skills/ac-implement/SKILL.md` — tier: none

## Delivers
- gate: skills/ac-implement/scripts/close-gate.sh
  touchers: `rg -l -F "scripts/close-gate" . -g '!skills/ac-implement/scripts/close-gate.sh' -g '!node_modules/**' -g '!.beads/**' -g '!_plans/**' -g '!_backlog/**' -g '!_docs/**' -g '!docs/**' -g '!memory/**' -g '!CHANGELOG*'` · owned by: ac-qn7h.2
- harness: skills/ac-implement/scripts/close-gate.test.sh
  touchers: `rg -l -F "scripts/close-gate.test" . -g '!skills/ac-implement/scripts/close-gate.test.sh' -g '!node_modules/**' -g '!.beads/**' -g '!_plans/**' -g '!_backlog/**' -g '!_docs/**' -g '!docs/**' -g '!memory/**' -g '!CHANGELOG*'` · owned by: ac-qn7h.2
- wiring: the close step of skills/ac-implement/SKILL.md invokes the gate
  touchers: `rg -l -F "ac-implement/SKILL" . -g '!skills/ac-implement/SKILL.md' -g '!node_modules/**' -g '!.beads/**' -g '!_plans/**' -g '!_docs/**' -g '!docs/**' -g '!memory/**' -g '!CHANGELOG*'` · out-of-scope: the referrers cite the skill by path, not the close step this bead edits

## Consumes
- ac-qn7h -> skills/ac-pipeline/SKILL.md (the MODE / ON-FAILURE declaration this script conforms to)
<!-- ac-example-bead:end -->
