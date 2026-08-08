# Commit discipline — shared-checkout git canon (H7d)

**The one home for trunk-direct commit rules.** Every skill that commits on a
shared checkout points here; none restates.

**H7d, the core rule:** only files YOU changed (and, under Agent Mail, reserved)
enter YOUR commits — **pathspec-mandatory**: `git commit -- <files>`. **Never
`git add -A` / `git add .` / `git commit -a`** — a wildcard add sweeps whatever
foreign WIP sits in the shared tree into your commit under your message
(incident: staged-sweep). Pathspec commits are atomic and self-documenting —
no staging window for another session to race. **Never `git stash`** — stash
pops can surface other sessions' entries and corrupt unrelated files
(incident: stash-corruption). Foreign uncommitted work: inventory it, never
touch it, never commit it "on their behalf".

---

## ToC
- Pre-commit deletion check
- Never blind-commit formatter output on markdown
- Commit + push sequence
- No-stash escalation ladder (when rebase/push is blocked by foreign WIP)
- Rules

## Pre-commit deletion check

Before any commit that could carry deletions, run `git status --short` and look for `D`
entries. **Unexpected deletions STOP the commit** — surface them ("about to delete X
files — intentional?") and wait for confirmation (interactive) or abort-and-report
(headless). Deletions you authored deliberately proceed; deletions you cannot explain
are someone else's work or an accident — never commit them. (Promoted from the
plan-chain safety check, Pass B station 1 — six skills carried copies.)

## Never blind-commit formatter output on markdown

**Diff a formatter's markdown output before committing it. Never run a repo-wide format and
commit the result unread.** Check the diff for prose that has become a pipe-delimited table
cell — that is the known failure mode.

The trap is that the corruption arrives disguised as the fix. A formatter absorbs prose
that abuts a table row into the table, so the format gate goes red, and the obvious remedy —
format, then commit — is what destroys the text. The correct fix is a blank line between the
table and the prose, THEN format. The prose stays visible, so review does not catch it.

Never format a file wholesale to fix one file's gate failure. Format the file you changed.

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
- `--force-with-lease` on a NON-main working branch (e.g. ac-merge's pre-PR wave-branch push, ac-merge/SKILL.md §Push) is the sanctioned exception — branch-scoped only, never `main`.
- Never stash. Never `git add -A`.
