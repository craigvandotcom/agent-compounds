# ac-align — alignment report template

Write one report per run (Phase 5). Omit sections with zero items.

```markdown
## Pipeline Alignment Report

### Strategy Summary
- **Core value prop:** {one sentence}
- **Current target milestone:** {milestone}
- **Strategy gaps noted:** {list or "none"}

### Orphans ({N} items — don't serve strategy)
| Item | Location | Recommendation |
|------|----------|----------------|
| {title} | {backlog/plan/bead} | Defer to v{N} / archive |

### Missing Execution ({N} gaps)
| Strategy Demand | Missing Item | Suggested Action |
|----------------|--------------|-----------------|
| {demand} | nothing in pipeline | Add to _backlog or /ac-plan |

### Missequenced Items ({N} items)
| Item | Current Position | Should Be | Reason |
|------|-----------------|-----------|--------|
| {title} | {current stage} | {earlier/later} | {brief reason} |

### Sequencing Notes
{1–3 observations about crystallization order and downstream impact}

### Strategy Gaps
{List any internal strategy inconsistencies or missing strategy elements}
```