# Assurance declarations — the birth requirement for any new mechanism

**Owner-hosted canon.** Two consumers point here, neither copies: `skill-builder`'s
authoring standards (birth requirement for new mechanisms) and the app-layer gate-audit
doctrine (NOT-GATED refusal shapes). Governing rule:
`infrastructure/memory/auto/an-assurance-claim-without-a-loop-is-decoration.md`.

> **A claim without a feedback loop is decoration. Delete > Construct > Sense.**
> "Wired" and "working" are different claims. A mechanism that cannot fail visibly is
> not a control — it is a comment with a shebang.

## The four fields

Every mechanism declares these AT BIRTH. In `hooks/hooks.json` they live in the entry's
`assurance` object; elsewhere, as a greppable comment block in the file itself.

| Field | Says | Why it cannot be inferred |
|---|---|---|
| `PROBE` | how you would show it is alive | a mechanism nobody can test is untestable by construction |
| `SCHEDULE` | what triggers it, and how often | an unscheduled proof test is documentation (lint Check 20) |
| `MODE` | `blocking` \| `advisory` | event/matcher shape cannot distinguish them — advisory `skill-edit-guard` and blocking `bead-capture-guard` are BOTH `PreToolUse` |
| `ON-FAILURE` | `open` \| `closed` | fail-open is a design choice; undeclared, it is discovered during an incident |

**Fail-open is legal only for `MODE: advisory`.** A blocking mechanism declaring
`ON-FAILURE: open` needs exactly one of two escapes, each with its own sensor:

- **`PENDING-DECISION: <bead-id>`** — the fail-open is an UNRESOLVED fork. Valid only
  while that bead is `issue_type == "decision"` AND `status == "open"`, resolved by
  parsing the committed `.beads/issues.jsonl` (no `br` dependency — `br` is a local
  binary absent from CI runners). **Self-expiring:** citing a closed, missing, or
  non-decision bead FAILS lint. A ruled decision must be executed, not squatted on, and
  a stray open task cannot host the escape. `.beads/**` is in the registry-lint trigger
  paths so closing the cited bead actually re-runs the check.
- **`BACKSTOP: <named mechanism>`** — the fail-open is a RULED design with something
  else catching what slips through. When the value names a path, that path must EXIST:
  a backstop nobody kept is not a backstop. Use this ONLY for a decided design, never
  to dodge a fork that is genuinely open.

## Orphan roles

An executable with no wiring entry declares why it is there, or lint fails it:
`ASSURANCE-ROLE: utility|test-harness` plus `CALLER: <its real caller>`, or
`ASSURANCE-ROLE: orphan` plus the `PENDING-DECISION` escape above. An undeclared
executable reads as coverage — which is exactly how `hooks/on-file-write.sh` sat with
zero wiring references and nobody noticed.

## NOT-GATED — the refusal shape

When a gate cannot verify, it must say so and FAIL. Silence is never success.

- Exit `2` + the literal token `NOT-GATED` (or `NOT-CHECKED`) — distinct from a pass (`0`)
  and from a substantive refusal (`1`), so logs stay greppable.
- **Scanned-nothing is not a pass.** Assert coverage, not just exit status: files-scanned
  == files-passed, discovered > 0, non-empty results. `ubs` scanning zero supported files
  prints a clean report; a suite killed by `bail` reads as passed.
- **A stale exemption must fail.** Quarantines, skips, and escapes each carry a sensor
  that fires when they stop applying — a quarantined test that starts PASSING fails the
  run (`scripts/run-all-harnesses.sh`), a closed decision bead invalidates its escape.

Enforcement: `lint.sh` Check 18 (a guard can fire) · Check 20 (a proof test is run) ·
Check 21 (a mechanism declares its failure semantics), each with a `*.test.sh` harness
that the `harnesses` CI job executes.
