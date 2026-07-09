# Review consensus doctrine (shared)

The canonical auto-apply cascade, design-decision gate, and deferred-finding lifecycle for
synthesizing **independent reviewer findings**. Single source of truth referenced by
`ac-review` (and any skill that synthesizes multi-reviewer output, e.g. `ac-hygiene`) so the
consensus logic can't silently diverge between them.

This operationalizes the *You can't self-validate — confidence requires independence*
through-thread in `ac-pipeline-builder`: agreement across independent agents/rounds is the
reliable signal, not any single reviewer's confidence.

This is the **code-findings instantiation of `disposition.md`** (the shared AUTO / HUMAN /
DISREGARD rule). Its default-AUTO bias is rule 2 there — safe because findings ride a branch
through tests/CI/review/merge, not because reviewers are trusted. `ac-land`/`reflect`'s
no-auto-apply for skill/doctrine edits is rule 3 (no downstream gate) — the two defaults are
the same rule, not a contradiction.

## The auto-apply cascade

Tag a finding `AUTO_FIX` if **any** condition holds:

1. **Severity-based** — Critical or High. These are defects, not preferences.
2. **Same-round consensus** — 2+ reviewers independently flagged the same issue (any
   severity). Multi-agent agreement is high-signal.
3. **Cross-round consensus** — a single-reviewer finding from THIS round matches a deferred
   finding in the consensus registry from a PREVIOUS round. Recurrence across rounds is
   high-signal.

## Design-decision gate (applies BEFORE the cascade)

If a finding is a choice with no objectively superior technical answer, **resolve it yourself —
pick the better option and auto-apply.** Defer as `DESIGN_DECISION` only if the choice would
**noticeably affect the end-user experience** or **profoundly change the development approach**.
Minor choices (spacing values, naming conventions, implementation style) → just pick the better
one.

## Conductor triage (final review of remaining items)

After the cascade and any auto-fix pass, the conductor reviews each remaining item
(NEEDS_DECISION + no-consensus findings) and classifies it:

| Category | Criteria | Action |
|---|---|---|
| `AUTO_IMPLEMENT` | There is a clearly superior technical answer — better correctness, robustness, performance, or maintainability. The improvement is unambiguous. | Implement it now. |
| `DESIGN_DECISION` | No objectively superior answer AND the choice would **noticeably affect the end-user experience** or **profoundly change the development approach**. Minor design choices (spacing, naming, style) — just pick the better option and classify as `AUTO_IMPLEMENT`. | Defer to user. |
| `SCOPE_ESCALATION` | A technically superior option exists but requires profound structural change (new abstractions, large refactors, architectural pivots) that constitutes a strategic commitment. | Defer to user with scope context. |

**Default bias: `AUTO_IMPLEMENT`.** Most findings have a correct answer — pick it. Only classify as `DESIGN_DECISION` when you genuinely cannot determine a superior option on engineering merit AND the impact is user-visible or development-transformative. Only classify as `SCOPE_ESCALATION` when the blast radius is transformative, not merely "more work."

## Deferred-finding lifecycle

- **Single-reviewer Medium/Low, no cross-round match** → append to the consensus registry; do
  NOT tag `NEEDS_DECISION` yet. It may reach cross-round consensus if a verification round runs.
- **`DESIGN_DECISION` items** → skip the registry; surface to the user. On an autonomous run,
  defer them as decision beads per the Exhaust Rule (`_shared/bead-conventions.md`) rather than
  blocking on `AskUserQuestion`.

## Consensus registry format

A markdown table at `$ARTIFACTS_DIR/consensus-registry.md`, one row per deferred finding:

```
| {round} | {reviewer} | {severity} | {file:line} | {one-line summary} |
```

**Cross-round match key:** `file:line` + finding category. A new-round finding whose key
matches a prior row achieves cross-round consensus → auto-apply.
