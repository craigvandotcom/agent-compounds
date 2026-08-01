# Design references — how target-state visuals travel the pipeline

**The rule (promoted from ac-plan-init's capture rule, Pass B station 1 — five skills
cited it there):** when a human shares a visual reference (screenshot, mockup, design
comp) as the TARGET to build toward, save it IMMEDIATELY to
`docs/design-refs/<surface>-<source>-reference.<ext>` — NOT under `.claude/` (one
harness's mount) — and cite that exact path in the receiving artifact. **Never describe
it into prose instead**: the file is the spec artifact; a reference
described-but-not-committed silently drops geometry (shape, radius, spacing) between
research doc and implementation.

Distinct from agent-captured CURRENT state (`_plans/research/…-baseline-screenshot-*.png`)
— that is the baseline; `docs/design-refs/` is the human-shared target.

Per-stage duties:

- **Capture** (`ac-plan-init` research docs, `ac-backlog` items, `ac-bead-capture`
  notes): save on receipt, cite the path in the doc/`## Notes`.
- **Beadify / refine** (`ac-beadify`, `ac-bead-refine`): a UI bead derived from a
  visual reference MUST carry the reference-image path in `## Acceptance Criteria` —
  a missing path is a **refine-blocking gap**; the Completeness Reviewer checks it and
  AC drift against the source doc's geometry.
- **Consume** (`ac-ui-polish`, implementation): read the file, not a paraphrase.
