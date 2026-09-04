# The ac2 bead schema

The contract `ac-beadify` compiles TO and refuses against (**no probe, no bead**), and the
shape `ac-polish` grades with `bead-checklist.md`. Four sections, all durable: an ac2 bead
stores no tree-state that decays between authoring and claim.

Canon is cited, never restated here — taxonomy, status/priority, close reasons and
labels live in `beads-standards` (`reference/bead-conventions.md`); the test-tier
slugs are the table below; run and
commit discipline in `ac-pipeline/references/` (`commit-discipline.md`, `run-ledger.md`).

## Header fields

`title` · `type` · `priority` · deps (`blocks` / parent-child / `discovered-from`) ·
`labels` (risk tags as needed: `migration` · `native`).

- An epic reaches its children by **parent-child**, never `blocks` — containment is not
  ordering, and wiring it as `blocks` fabricates a critical path.
- Edge direction is `<blocked> depends-on <blocker>`. A reversed `br dep add` is SILENT, so
  read every edge back (`br dep cycles`, then `br show` on both ends).
- `br create` REJECTS `-f` alongside a title: creation bodies go `-d "$(cat <file>)"`. That
  routes the body through the shell, so bead prose must stay dcg-safe (no command
  substitution, no unbalanced quoting). Only comments and receipts take `-f <file>`.

## The four sections

| Section | Bar |
|---|---|
| `## Intent` | Why + rationale + context + boundary (what is explicitly OUT) + gotchas. Symbol and file names are welcome as hints; **line numbers are banned** — a `file:line` anchor decays before the claim and nothing cheap tells you it has. **The header is per type:** `bug` → `## Steps to Reproduce` (a bug's intent IS its repro), `epic` → `## Success Criteria` (an epic's intent IS what done looks like), everything else → `## Intent`. Same content, same four sections — `br lint` (v0.2.16) compiles those two per-type headers in and cannot be configured, so the schema meets it by naming, never by a fifth section. |
| `## Acceptance Criteria` | 3–7 falsifiable behavioural ACs, EACH naming its executable probe and tier (see below). Observable outcomes only. The header phrase is load-bearing for `br lint`: its matcher is case-insensitive and tolerates trailing text, but both words must appear. |
| `## Delivers` | The named artifacts this bead promises — the exact strings a dependent's `## Consumes` will cite. Paths, script names, receipts. |
| `## Consumes` | One `<blocker-id> -> <artifact>` per line, or the single word `none`. Every line needs a matching dependency edge and every edge a matching line (parity is graded). |

Nothing else. There is no Scope, Proof, Notes or Discussion section — that content is either
`## Intent` or it is not durable.

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
- **Probing an artifact the bead has yet to create**, use the guarded form
  `test -x <path> && bash <path>` — the leading word exists today, the probe is honestly
  red until the artifact lands, and it becomes the real suite run the moment it does.
- **Tier** is one slug from the *Test-tier slugs* table
  (below): `standing-vitest` · `supabase-integration` · `e2e` · `none`.
- Prose fragments (`wc -l`, "diff the file", "grep for it") are NOT probes and `ac-beadify`
  refuses the bead.

WHY this is a rule and not advice: this pipeline's own refine found SEVEN broken probes
across seven rounds — five fail-open, two guaranteed false-fail, and the seventh was the
repair of the sixth. Every one had been authored without being run. Executing them
mechanically at round 7 recovered 2 runnable commands out of 14 beads. A probe a machine
cannot run is a probe nobody ran.

## Test-tier slugs

| Slug | Meaning |
|------|---------|
| `standing-vitest` | The repo's default unit/component gate (`pnpm test` / `pnpm test:all`) |
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
| `## Territory` + test-tier table | each AC's own tier; the close-time causal probe |
| `## Declared RED` | the AC's probe — RED is *recorded* at claim, not *promised* at authoring |
| `## Sequence + risk` | the dependency graph and the risk labels |
| Scope prose · `## Proof` | `## Intent`'s boundary; the close receipt |

## Transitional exception (bootstrap seam)

Until `ac-implement` exists, ac2 beads are worked on the current path, whose engineer spawn
pastes `## Territory` verbatim with no fallback. Phase-0/1/2 beads therefore carry a
transitional `## Territory` list. It is dropped from Phase 3 on, and it is never graded by
`bead-checklist.md`.

## Example bead

Extract it as a standalone description body with:
`sed -n '/ac-example-bead:start/,/ac-example-bead:end/p' skills/ac-beadify/references/bead-schema.md`

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
  Probe: `test -x skills/ac-implement/scripts/close-gate.test.sh && bash skills/ac-implement/scripts/close-gate.test.sh` — tier: none
- The refusal emits the exact string the worker loop greps for, so the loop can branch on it.
  Probe: `grep -q 'refusing: no probe receipt' skills/ac-implement/scripts/close-gate.sh` — tier: none
- The close step of the skill invokes the gate, so the gate is on the write path and not
  merely available.
  Probe: `grep -q 'close-gate.sh' skills/ac-implement/SKILL.md` — tier: none

## Delivers
- gate: skills/ac-implement/scripts/close-gate.sh
- harness: skills/ac-implement/scripts/close-gate.test.sh
- wiring: the close step of skills/ac-implement/SKILL.md invokes the gate

## Consumes
- ac-qn7h -> skills/ac-pipeline/SKILL.md (the MODE / ON-FAILURE declaration this script conforms to)
<!-- ac-example-bead:end -->
