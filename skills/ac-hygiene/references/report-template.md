# Hygiene Report Template

Phase 5 final report.

```markdown
## Hygiene Review Summary

**Scope:** {full codebase | recent N commits | directory}
**Rounds:** {CURRENT_ROUND}

### Convergence

Round  Bug Hunter  Explorer  Structural  Total  Applied  Deferred
  1      {n}         {n}       {n}        {n}     {n}       {n}
  2      {n}         {n}       {n}        {n}     {n}       {n}
  3      {n}         {n}       {n}        {n}     {n}       {n}

R1  {▓▓░░░████}  {total}
R2  {░████}      {total}  {-N%}
R3  {██}         {total}  {-N%}

▓ Critical  ░ High  █ Medium

### Resolution

Found: {total} across {CURRENT_ROUND} rounds
  ├─ Auto-applied (severity):      {n}  {bars}
  ├─ Auto-applied (same-round):    {n}  {bars}
  ├─ Auto-applied (cross-round):   {n}  {bars}
  ├─ Auto-implemented (conductor):  {n}  {bars}
  ├─ User-approved:                {n}  {bars}
  └─ Discarded (no consensus):     {n}  {bars}

### Areas Reviewed

- {list key files/directories agents explored}

### Health Assessment

- Tests: {PASS/FAIL}
- Type-check: {PASS/FAIL}
- Lint: {PASS/FAIL}
- Build: {PASS/FAIL}

**VERDICT:** {APPROVED — every consensus finding auto-applied or deferred to a bead, no unresolved blocker | NEEDS_DECISION — an unresolved blocker / `qa-blocker` remains (named above)}

<!-- The VERDICT line lets this report serve as ac-batch-close's Phase 1 review artifact
     (path (a)) when a hygiene run's fixes are closed via ac-batch-close — same severity bar,
     no re-review of the same diff. -->

**Next:** Run again in a few sessions, or after major changes.
```
</content>
