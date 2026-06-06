# Flywheel Land Command

Session closure protocol - ensure all work is committed and pushed.

## Purpose

"Land the Plane" ensures no work is stranded locally. Critical for agentic workflows where different agents/sessions pick up work.

## Mandatory Steps

### 1. File Remaining Work

```
- Create issues/tasks for any incomplete work
- Document loose ends and next steps
- Update task statuses
```

### 2. Run Quality Gates (if code changed)

```bash
pnpm type-check
pnpm lint
pnpm test
pnpm build:check
```

If any fail: file P0 issues for failures.

### 3. Update Task/Bead Status

```
- Close completed tasks/beads
- Mark blockers on incomplete items
- Update progress notes
```

### 4. Git Operations (NON-NEGOTIABLE)

```bash
git pull --rebase
git add <specific files>  # Not -A
git commit -m "..."
git push
git status  # Must show "up to date with origin"
```

### 5. Sync External State (if using beads)

```bash
bd sync  # Export DB to JSONL
git add .beads/
git commit -m "chore: sync beads state"
git push
```

### 6. Clean State

```bash
git stash clear  # If stashes exist
git branch --merged | xargs git branch -d  # Prune merged branches
```

### 7. Verify

```bash
git status  # Clean working tree
git log --oneline -1  # Latest commit pushed
```

### 8. Hand Off

Output brief summary for next session:

```
## Session Summary

**Completed:**
- [List completed work]

**In Progress:**
- [List incomplete work with blockers]

**Next Session:**
- [Recommended next steps]

**Open Issues:**
- [Any filed issues/tasks]
```

## Critical Rules

- **NEVER** stop before `git push`
- **NEVER** say "ready to push when you are" - agent MUST push automatically
- If push fails, resolve and retry until successful
- If tests fail, file issues but still push other changes

## Why This Matters

> "Based on Steve Yegge's workflow, 'Land the Plane' ensures no work is stranded locally. This is critical for agentic workflows where different agents/sessions pick up work."

Every session must leave the repo in a clean, pushed state so the next agent (or human) can continue seamlessly.

## Reference

See: `.claude/skills/CORE/references/land-the-plane.md`
