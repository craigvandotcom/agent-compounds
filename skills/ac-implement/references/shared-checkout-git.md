# Shared-checkout git recipe (trunk-direct)

**Canonical one-stop recipe** for pathspec commits + push on a shared `main`
checkout under concurrent sessions. Supersedes the split guidance that lived in:

- `ac-implement/SKILL.md` § Phase 1d pathspec commit + foreign-unstaged rebase block
- `body-compass-app/memory/auto/pull-rebase-blocked-by-foreign-wip-decision-ladder.md`
- Retro note: ALWAYS use `--pathspec-from-file` for paths containing `(...)` / `[...]`
  (route groups) — loop-retro 20260716-090110-36065 ~L263

**Never `git stash`.** Stash pops can surface other sessions' entries and corrupt
unrelated files (incident: stash-corruption). **Never `git add -A` / `git add .` /
`git commit -a`** — pathspec-only commits (H7d).

---

## Commit + push sequence

```bash
export GIT_IDENTITY_ENABLED=1
export AGENT_NAME=<your session name>   # re-assert every shell

# 1. Fetch + 0-behind check (preferred over pull --rebase when foreign WIP exists)
git fetch origin main
BEHIND=$(git rev-list --count HEAD..origin/main)
if [ "$BEHIND" = "0" ]; then
  : # nothing to integrate
else
  # See no-stash escalation ladder below before pull --rebase
  git pull --rebase origin main || true
fi

# 2. Pathspec commit (tracked files)
git commit -m "feat(scope): summary

Bead: <id>" -- path/to/file1 path/to/file2

# 2b. New untracked files: stage first, then pathspec-commit exactly those paths
git add path/to/new-file.ts
git commit -m "..." -- path/to/new-file.ts

# 2c. Paths with parentheses or brackets (Next.js route groups, etc.):
# NEVER put `app/(auth)/…` bare on the CLI — the shell eats the parens.
# Use --pathspec-from-file:
printf '%s\n' 'app/(auth)/login/page.tsx' 'app/(protected)/app/page.tsx' \
  > /tmp/pathspec-$$.txt
git commit -m "..." --pathspec-from-file=/tmp/pathspec-$$.txt
rm -f /tmp/pathspec-$$.txt

# 3. Push (commit = push under trunk-direct)
git push --no-verify origin main
git rev-parse HEAD
git ls-remote origin main   # must match
```

---

## No-stash escalation ladder (when rebase/push is blocked by foreign WIP)

Cheapest first — stop at the first that applies. **Never `git stash`.**

1. **`origin == HEAD` already → skip rebase entirely.**
   ```bash
   git fetch origin main
   [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] && git push --no-verify origin main
   ```

2. **0-behind (or only unstaged foreign WIP) → fast-forward push is safe.**
   ```bash
   git fetch origin main
   BEHIND=$(git rev-list --count HEAD..origin/main)
   if [ "$BEHIND" = "0" ]; then
     git push --no-verify origin main
   fi
   # Unstaged foreign files do NOT block a fast-forward push of YOUR commit.
   ```

3. **Foreign STAGED rename blocks merge → mixed reset (content-safe), then merge.**
   ```bash
   # Mixed reset leaves working tree untouched; only unstages.
   # ONLY unstage paths you did NOT author this session.
   git reset HEAD -- path/that/is/foreign
   git merge origin/main
   git push --no-verify origin main
   ```

4. **Foreign ledger churn blocking rebase → discard machine-local generated files you did not author.**
   ```bash
   # Safe examples: .beads/issues.jsonl, skills/*/workflows/last-run.json
   git checkout -- .beads/issues.jsonl   # only if YOU did not edit it this session
   git pull --rebase origin main
   git push --no-verify origin main
   ```

5. **Worst case — foreign WIP truly can't be reset → object-DB rebase via scratch index
   (never touch the working tree):**
   ```bash
   # Apply YOUR change onto origin/main in a throwaway index, commit-tree, push SHA.
   GIT_INDEX_FILE=/tmp/scratch-idx-$$ git read-tree origin/main
   # … stage your blob(s) into that index …
   # NEW=$(git commit-tree $(git write-tree) -p origin/main -m "…")
   # git push origin "$NEW":refs/heads/main
   # Leaves the dirty working tree completely alone.
   ```

---

## Rules

- Pathspec-limited commits for every trunk-direct agent commit (H7d).
- `--no-verify` on push is deliberate (pre-push full-tree build false-positives on
  foreign WIP); real verification is the per-commit gate + post-push CI.
- Never force-push `main`.
- Never stash. Never `git add -A`.
