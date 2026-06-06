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

**Next:** Run again in a few sessions, or after major changes.
```
</content>
