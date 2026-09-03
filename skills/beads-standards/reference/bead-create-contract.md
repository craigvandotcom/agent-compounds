# Bead creation contract — the single home

Every `br create` / `br q` in this fleet satisfies this contract, whoever files. Skills
carry their own template (type, body sections, domain labels differ by source); they do NOT
carry their own copy of the RULES. Point at this file with a `§` anchor instead.

Two enforcers implement exactly this list. Change the contract here first, then both:
- **Runtime** — `hooks/bead-capture-guard.py`, a PreToolUse Bash hook. Blocks a
  non-conforming `br create` an agent types, in any skill, in any repo.
- **Static** — `lint.sh` Check 19. Blocks a non-conforming TEMPLATE shipping in `skills/`,
  before any agent ever runs it.

The runtime gate catches what agents type. The static gate catches what the registry ships.
Neither alone is sufficient: a correct template can be typed wrong, and a stale template
poisons every future run.

## Required axes

| Axis | Rule | Scope |
|---|---|---|
| `origin:<skill>` | The creating workflow. `origin:manual` outside any skill; `origin:unknown` when genuinely unattributable — never guess. Canon: `origin-provenance.md`. | EVERY bead |
| Readiness | One of `unrefined` / `human-gate`. `refined` is stamped exclusively by a refine pass and is never applied at creation. | Every NON-EPIC bead |
| Touchers | A `## Delivers` path that EXISTS in the tree and is REFERENCED by another file owes, beneath its bullet, one line: ``touchers: `<command>` → <N> · owned by: <bead ids> \| out-of-scope: <reason>``. Command-derived, never remembered; the count must reproduce at stamp time. New files and unreferenced files owe nothing. Enforced at REFINE, not capture: `skills/_tools/stamp-refined.sh` § TOUCHERS LEG derives the trigger with `rg`, re-runs the command, and refuses `[unowned-touchers]` on a missing, malformed or stale line. VERIFIED at the DIFF: `skills/ac-implement/scripts/diff-closure.sh --bead <id>` greps the callers of what actually changed and refuses `[unowned-callers]` on any the line did not name — the declaration is the claim, the diff is the sensor (worker §5 · code-polish §1 · ac-review Phase 5). Why: bead-polish measured a 16.2% repair rate from hand-listed consumer sets, and every serious 2026-08/09 defect was a caller nobody enumerated. | Every bead, at refine |

Epics are exempt from readiness: they are containers, never picked up for implementation.
This mirrors `ac-tidy` Phase 2f, which repairs the same gap nightly for beads that predate
or bypass the gate.

## Not gated, and why

`kind:product` / `kind:machinery` is a DEFECT-filing axis, not a universal one — a feature,
an epic, or a plan task is not a defect, so the axis is meaningless there. `kind:machinery`
is additionally meant to be near-absent from the board by design. Gating it would force a
meaningless label onto most beads. Filing-hygiene reporting for it belongs to `ac-dashboard`.

## Canonical invocation

```bash
br create "<verb-first title>" -t <type> -p <0-4> \
  --labels "origin:<skill>,unrefined,<domain labels>" \
  -d "<body — typed sections per beads-standards § Body template contract>"
```

Put `origin:` FIRST in the label list. One origin per bead; two is corrupt data.

Titles that can begin with `-` (a markdown bullet) must use the equals form
`--title=<value>`: `br`'s clap parser rejects a bare positional or two-token flag value
starting with `-`. Scripted callers already do this — see `BrCreateOptions` in
body-compass-app `scripts/curate-foods/lib/br.ts`.

## Scripted callers

A `br` invoked as a child process (Node/TS `execFileSync`) is invisible to the runtime hook.
Those paths enforce in code: make provenance a REQUIRED field so a call site that omits it
fails the type-check, rather than filing an unattributed bead.
