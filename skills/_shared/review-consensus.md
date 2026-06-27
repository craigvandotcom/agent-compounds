# Review consensus doctrine (shared)

The canonical auto-apply cascade, design-decision gate, and deferred-finding lifecycle for
synthesizing **independent reviewer findings**. Single source of truth referenced by
`ac-review` (and any skill that synthesizes multi-reviewer output, e.g. `ac-hygiene`) so the
consensus logic can't silently diverge between them.

This operationalizes the *You can't self-validate — confidence requires independence*
through-thread in `ac-pipeline-builder`: agreement across independent agents/rounds is the
reliable signal, not any single reviewer's confidence.

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
