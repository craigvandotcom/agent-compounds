---
name: worktrees
description: Manage git worktrees for parallel development with Claude Code agents. Use when setting up isolated development environments, running parallel agents on different features, or recovering from interrupted sessions.
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across all neoMeta apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Worktrees Skill

**Purpose:** Manage git worktrees for parallel development with Claude Code agents.

---

## When to Use Worktrees

Worktrees enable multiple Claude Code sessions to work on the same codebase in parallel:

- **Parallel feature development** - Multiple agents on different features simultaneously
- **Isolated experiments** - Test risky changes without affecting main development
- **Code review workflows** - Review PR while continuing other work
- **Long-running tasks** - Agent works on complex feature while you continue in main

**Key benefit:** Each worktree is a full working directory with its own `node_modules`, allowing truly independent builds and tests.

---

## Workflow Integration

**Worktrees are managed automatically by our workflow commands:**

| Command  | Worktree Action                                             |
| -------- | ----------------------------------------------------------- |
| `/work`  | Creates worktree (Phase 1) - prompts for worktree vs branch |
| `/merge` | Cleans up worktree (Phase 9) - removes worktree after merge |

**Standard flow:**

```
/work → (creates worktree) → implement → /work-review → /merge → (cleanup)
```

**You rarely need manual worktree commands.** The workflow handles creation and cleanup automatically. Use manual commands only for:

- Parallel sessions outside the standard workflow
- Recovery from interrupted sessions
- Manual exploration/experiments

---

## Quick Reference (Manual Commands)

```bash
# Create worktree (ALWAYS use this, never git worktree directly)
.claude/scripts/worktree-manager.sh create feat-my-feature

# List all worktrees
.claude/scripts/worktree-manager.sh list

# Cleanup worktree (must cd out first!)
cd /path/to/main/repo
.claude/scripts/worktree-manager.sh cleanup .worktrees/feat-my-feature
```

---

## Critical Configuration

### pnpm Branch-Specific Lockfiles

**Problem:** Without this, worktrees share lockfiles and can have version mismatches that cause cryptic build failures.

**Solution:** `pnpm-workspace.yaml` configures branch-specific lockfiles:

```yaml
# Creates branch-specific lockfiles (e.g., pnpm-lock.feat-security-audit.yaml)
gitBranchLockfile: true

# Merge all branch lockfiles when on main
mergeGitBranchLockfilesBranchPattern:
  - main
  - release*
```

This ensures `package.json` and lockfile always travel together.

### ESLint Root Configuration

Prevent ESLint from finding configs in parent directories:

```json
{
  "root": true,
  ...
}
```

Already configured in `.eslintrc.json`.

---

## Worktree Manager Features

The `worktree-manager.sh` script handles:

1. **Environment files** - Copies `.env`, `.env.local`, `.env.test`, `.env.development.local`
2. **Dependency installation** - Runs `pnpm install` with branch-specific lockfile
3. **Safety checks** - Prevents cleanup with uncommitted changes
4. **Active worktree protection** - Prevents removing worktree you're currently in
5. **Gitignore management** - Ensures `.worktrees/` is ignored

---

## Directory Structure

```
project/
├── .worktrees/                          # All worktrees live here
│   ├── feat-camera-capture/             # Worktree 1
│   │   ├── node_modules/                # Independent dependencies
│   │   ├── .env.local                   # Copied from main
│   │   └── pnpm-lock.feat-camera-capture.yaml  # Branch lockfile
│   └── feat-security-audit/             # Worktree 2
│       └── ...
├── pnpm-lock.yaml                       # Main lockfile
├── pnpm-lock.feat-camera-capture.yaml   # Branch lockfile (travels with branch)
└── pnpm-workspace.yaml                  # Branch lockfile config
```

---

## Troubleshooting

### Build fails with cryptic ENOENT errors

**Symptom:**

```
Error: ENOENT: no such file or directory, open '.next/browser/default-stylesheet.css'
```

**Cause:** Version mismatch between `package.json` and lockfile (pnpm selected wrong lockfile).

**Check:**

```bash
grep '"next"' package.json
grep 'next@' pnpm-lock*.yaml | head -5
```

**Fix:** If versions don't match:

```bash
rm -rf node_modules .next
pnpm install
```

### "Found multiple lockfiles" warning

**Symptom:**

```
⚠ Warning: Found multiple lockfiles. Selecting /path/to/main/pnpm-lock.yaml.
```

**Cause:** pnpm isn't using branch-specific lockfile.

**Fix:** Ensure `pnpm-workspace.yaml` has `gitBranchLockfile: true` and run:

```bash
pnpm install
```

### ESLint plugin conflicts

**Symptom:**

```
⨯ ESLint: Plugin "@next/next" was conflicted between ...
```

**Cause:** ESLint finding configs from parent directories.

**Fix:** Ensure `.eslintrc.json` has `"root": true`.

### Cannot remove worktree

**Symptom:**

```
ERROR: Cannot remove active worktree!
```

**Fix:** You must `cd` out of the worktree first:

```bash
cd /path/to/main/repo
.claude/scripts/worktree-manager.sh cleanup .worktrees/feat-name
```

### Uncommitted changes block cleanup

**Symptom:**

```
ERROR: Uncommitted changes detected in worktree!
```

**Fix:** Commit, stash, or discard changes:

```bash
# Option 1: Commit
cd .worktrees/feat-name && git add -A && git commit -m "WIP"

# Option 2: Stash
cd .worktrees/feat-name && git stash

# Option 3: Discard
cd .worktrees/feat-name && git checkout -- .
```

---

## Best Practices

### 1. Always Use worktree-manager.sh

**Never** call `git worktree add` directly. The manager script:

- Copies environment files
- Installs dependencies with correct lockfile
- Sets up proper isolation

### 2. One Agent Per Worktree

Each Claude Code session should work in its own worktree to prevent:

- File conflicts
- Lock contention
- State confusion

### 3. Short-Lived Worktrees

**Using the workflow (recommended):** `/merge` automatically cleans up worktrees in Phase 9.

**Manual cleanup** (for parallel sessions or interrupted workflows):

```bash
# Must cd out of worktree first
cd /main/repo

# Cleanup worktree
.claude/scripts/worktree-manager.sh cleanup .worktrees/feat-quick-fix

# Delete branch if no longer needed
git branch -d feat-quick-fix
```

### 4. Merge Lockfiles Before PR

When ready to merge to main:

```bash
pnpm install --merge-git-branch-lockfiles
```

Or let it happen automatically when you checkout main (per `mergeGitBranchLockfilesBranchPattern`).

### 5. Check Disk Space

pnpm uses hard links from global store, so worktrees are efficient:

- npm/yarn: ~2GB per worktree
- pnpm: ~50MB per worktree

But `.next` build caches can grow. Clean periodically:

```bash
rm -rf .worktrees/*/next
```

---

## pnpm Global Store Efficiency

pnpm's content-addressable store means packages are downloaded once and hard-linked:

```bash
# See store location
pnpm store path

# Clean unused packages
pnpm store prune
```

This makes worktrees highly efficient - multiple worktrees share the same downloaded packages.

---

## References

- **Lesson doc:** `_docs/lessons/2026-01-23-worktree-pnpm-lockfile-conflicts.md`
- **pnpm branch lockfiles:** https://pnpm.io/git_branch_lockfiles
- **pnpm settings:** https://pnpm.io/settings
- **Git worktree guide:** https://agmazon.com/blog/articles/technology/202601/git-worktree-guide-en.html
- **IndyDevDan worktree video:** https://www.youtube.com/watch?v=f8RnRuaxee8

---

## Key Insight

> The version in `package.json` and the version resolved in the lockfile must match. When they don't, build tools can fail in ways that don't obviously point to version mismatches. pnpm's branch-specific lockfiles ensure they always travel together.
