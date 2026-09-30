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
  (`br create --description-file` is deliberately not adopted; a rewrite is § Filing's). That routes the body through the
  shell, so bead prose must stay dcg-safe (no command substitution, no unbalanced
  quoting). The capture guard reads the inline `-d` value, so a file/heredoc body is
  OPAQUE to it and its born-`Probe:` check fails open on exactly this form; the backstop
  is the committed-board check (`lint/checks/35-board-integrity.py`), which reads the
  landed body and refuses a probe-less implementable bead at the ledger commit. Only
  comments and receipts take `-f <file>`.

## Creation invocation

The literal `br create` this skill files. Required axes and rules:
`beads-standards/reference/bead-create-contract.md` § Canonical invocation.

```bash
br create "<verb-first title>" -t <type> -p <0-4> \
  --labels "origin:ac-beadify,unrefined,<domain labels>" \
  -d "$(cat <file>)"
```

## Filing — placeholders and the read-back

A body that cites a bead not yet created carries a `__EPIC__` / `__B<n>__` placeholder.
**Prefer no second write:** create the epic first (its id is known before any child body is
written, so `__EPIC__` never needs to exist), then children blocker-first; children of a
fresh epic are numbered `<epic>.1…` in creation order, so predict each id, resolve, create,
and REFUSE if `--silent` returns another id. A body that still needs a forward id (a
touchers `owned by:` sibling, the closeout) is rewritten ONCE with
`br update <id> --description-file <resolved-file>` — verbatim and quoting-safe, never
`-d "$(cat …)"`; a resolver helper declares its loop variable `local`.

The filing ends in a gate, REFUSED unless it exits 0:
`skills/_tools/bead-readback.sh check <epic>=<file> <id>=<file> …` — reads each bead back
with `br show --json` and fails on a placeholder on the board, a board body that differs
from its file, or Consumes↔edge parity computed from the BOARD description (never from
local files). Measured 2026-09-28 (easy-mode bd-wyun): a resolver's non-`local` loop
variable retargeted every `br update` at B1; `br` persisted exactly what it was sent (no
`--force` half-length refusal was involved), 10 of 12 bodies kept placeholders, and a
parity read from the local resolved files printed `parity: OK`.

## The four sections

| Section | Bar |
|---|---|
| `## Intent` | Why + rationale + context + boundary (what is explicitly OUT) + gotchas. Symbol and file names are welcome as hints; **line numbers are banned** — a `file:line` anchor decays before the claim and nothing cheap tells you it has. **The header is per type:** `bug` → `## Steps to Reproduce` (a bug's intent IS its repro), `epic` → `## Success Criteria` (an epic's intent IS what done looks like), everything else → `## Intent`. Same content, same four sections — `br lint` (v0.2.16) compiles those two per-type headers in and cannot be configured, so the schema meets it by naming, never by a fifth section. |
| `## Acceptance Criteria` | 3–7 falsifiable behavioural ACs, EACH naming its executable probe and tier (see below). Observable outcomes only. The header phrase is load-bearing for `br lint`: its matcher is case-insensitive and tolerates trailing text, but both words must appear. |
| `## Delivers` | The named artifacts this bead promises — the exact strings a dependent's `## Consumes` will cite. **One bare path per bullet, and the bullet STARTS with it** — grammar in § The citation rule (one `touchers:` line cannot own two), and a delivered path that git ALREADY TRACKS owes that line beneath its bullet: trigger, shape and rationale in `beads-standards/reference/bead-create-contract.md` § Touchers — derive it with `skills/_tools/touchers.sh derive <path>`, never by hand. **Path-shaped Delivers is REQUIRED for `task`/`feature`/`epic` beads**: every bullet must carry a path-shaped token (`name.ext`) — a dotted child bead id (`<epic-id>.3`) is not one, and an epic's paths must exist at close — because close-evidence-check cross-references the close reason against exactly those tokens. A prose-only Delivers line is refused at compile — ac-beadify's refusal step applies this schema to every bead before creation, and a prose-only Delivers is a schema violation — because one that slips through makes every close of that bead unverified forever (`UNVERIFIABLE-DELIVERS`; audit the backlog with `skills/ac-pipeline/scripts/close-evidence-check.sh --list-unverifiable`). |
| `## Consumes` | One `<blocker-id> -> <artifact>` per line, or the single word `none`. **`<artifact>` is ONE bare path, first thing after the arrow** — § The citation rule. Every line needs a matching dependency edge and every edge a matching line (parity is graded). |

A compiled epic's AC is the plan's silver bullet verbatim. Every child AC quotes its plan
"Done when:" verbatim and adds only the probe. A deliverable split across several beads has
each child quote the parent line and add its own slice's values. "a test named X passes"
is not an AC — it names a test, not a behaviour.

### The citation rule

A `## Delivers` entry and the artifact half of a `## Consumes` line are one grammar, because a
dependent cites the Delivers entry VERBATIM — a compound Delivers line reproduces itself as a
compound Consumes line in every bead that consumes it:

    ## Delivers                        ## Consumes
    - <one path> [(gloss)]             - <blocker-id> -> <one path> [(gloss)]

One bare path, first thing on the entry. A gloss is allowed only as ONE trailing `(...)`
that names no second path. `- none` is the explicit empty section at either end.

    GOOD  - skills/_tools/touchers.sh
    GOOD  - skills/ac-polish/scripts/bead-artifact.py (the base_digest() function)
    BAD   - gate: skills/_tools/touchers.sh                                  LABEL-PREFIX
    BAD   - skills/_tools/touchers.sh and skills/_tools/touchers.test.sh     TWO-ARTIFACTS
    BAD   - skills/_tools/touchers.sh (sources skills/_tools/delivers-paths.sh) TWO-ARTIFACTS
    BAD   - skills/_tools/touchers.sh — the gate every stamp runs             PROSE
    BAD   - skills/<name>/SKILL.md                                            PLACEHOLDER
    BAD   - `skills/_tools/touchers.sh`                                       NOT-BARE

Why it is canon and not taste: a citation is an ARGUMENT to a gate, not a sentence.
flight-check tests the cited artifact with `-e`, close-evidence-check cross-references
Delivers tokens against the close reason, and touchers.sh derives one count per bullet — a
label, a second path or a placeholder is either tested as though it were the artifact or
tests nothing at all. A premise that cannot be named as a path is not a citation — put it
in `## Intent`, or make it an AC with a probe. Two artifacts are two lines.

A wrapped entry is folded before it is read, so a second artifact cannot hide past a line
break. The `touchers:` line beneath a Delivers bullet is structure, not part of the entry.

The one checker: `skills/_tools/citation-grammar.sh check <description-file>` (or
`artifact <export>` over a bead-artifact export). Bead-mode polish runs it every round
(`ac-polish/workflows/bead.md` VALIDATE). Measured 2026-09-27 (bd-1tq1, easy-mode): four
polish rounds converged on Delivers bullets with trailing prose while VALIDATE read only
element 4 and touchers, and only that app's pre-commit lint caught it.

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
| `## Territory` + test-tier table | each AC's own tier; the close-time causal probe |
| `## Declared RED` | the AC's probe — RED is *recorded* at claim, not *promised* at authoring |
| `## Sequence + risk` | the dependency graph and the risk labels |
| Scope prose · `## Proof` | `## Intent`'s boundary; the close receipt |

## Transitional exception (bootstrap seam)

Until `ac-implement` exists, ac2 beads are worked on the current path, whose implementer spawn
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
  Probe: `test -x skills/ac-implement/scripts/close-gate.test.sh && bash skills/ac-implement/scripts/close-gate.test.sh` — tier: standing-harness
- The refusal emits the exact string the worker loop greps for, so the loop can branch on it.
  Probe: `grep -q 'CLOSE-REFUSED:' skills/ac-implement/scripts/close-gate.sh` — tier: none
- The close step of the skill invokes the gate, so the gate is on the write path and not
  merely available.
  Probe: `grep -q 'close-gate.sh' skills/ac-implement/SKILL.md` — tier: none

## Delivers
- skills/ac-implement/scripts/close-gate.sh
  touchers: `rg -l -F "scripts/close-gate" . -g '!skills/ac-implement/scripts/close-gate.sh' -g '!node_modules/**' -g '!.beads/**' -g '!_plans/**' -g '!_backlog/**' -g '!_docs/**' -g '!docs/**' -g '!memory/**' -g '!CHANGELOG*'` → 4 · owned by: ac-qn7h.2
- skills/ac-implement/scripts/close-gate.test.sh
  touchers: `rg -l -F "scripts/close-gate.test" . -g '!skills/ac-implement/scripts/close-gate.test.sh' -g '!node_modules/**' -g '!.beads/**' -g '!_plans/**' -g '!_backlog/**' -g '!_docs/**' -g '!docs/**' -g '!memory/**' -g '!CHANGELOG*'` → 1 · owned by: ac-qn7h.2
- skills/ac-implement/SKILL.md (the close step invokes the gate)
  touchers: `rg -l -F "ac-implement/SKILL" . -g '!skills/ac-implement/SKILL.md' -g '!node_modules/**' -g '!.beads/**' -g '!_plans/**' -g '!_backlog/**' -g '!_docs/**' -g '!docs/**' -g '!memory/**' -g '!CHANGELOG*'` → 2 · out-of-scope: the referrers cite the skill by path, not the close step this bead edits

## Consumes
- ac-qn7h -> skills/ac-pipeline/SKILL.md (the MODE / ON-FAILURE declaration this script conforms to)
<!-- ac-example-bead:end -->
