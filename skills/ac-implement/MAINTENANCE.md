---
skill: ac-implement
archetype: orchestrator
---

# ac-implement — maintenance ledger

## Editing references/worker.md

- worker.md is pasted verbatim into every worker: it holds runtime rules only, never
  authoring rules or discovery narrative.
- Execute every command it spells once against the live harness before it ships, and record
  that as an `EXEC-PROOF:` comment on the shipping bead.
- A command that would change state destructively (`br update <id> --status blocked`) is
  verified against the live tool's interface instead, and the receipt names it.
