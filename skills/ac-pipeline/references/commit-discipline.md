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
- Cross-repo skill/infra beads (commit-root)
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

## Cross-repo skill/infra beads (commit-root)

**The board that holds the ticket is not always the git repo that holds the files.**
App boards (body-compass-app especially) file `cross-repo` beads whose `## Repo
ownership` names `agent-compounds` (shared skills, via the app's `.claude/skills/*`
symlinks) or root `~/Repos` (infra/jobs). The **app loop must implement them** —
the target repo's beads db does not contain these IDs, so they are invisible there.
Skipping them in the app loop is how they sit in limbo.

**Detect:** label `cross-repo`, **or** the bead body names `CROSS-REPO` / `Repo
ownership` pointing at a repo that is not `git rev-parse --show-toplevel` of the
checkout you claimed from.

**Commit in the repo that tracks the bytes, on that repo's mainline.** Resolve
the target: `git -C "$(realpath <edited-file>)" rev-parse --show-toplevel`.
A BCA checkout's `.claude/skills/ac-tidy` is a symlink — editing it dirties
**agent-compounds**, not BCA. `git status` in BCA staying clean is the signal
you are about to close a bead against an empty commit. Run `git status` in the
resolved target before committing.

**Never one commit across a repo boundary.** A bead that edits both an app file
and a skill file is two pathspec commits (app repo, then target repo), then one
`br close` citing both SHAs. Skill/markdown-only diffs skip app gates (`pnpm
test` / `test:all` / `type-check` / the build hook) — the gate is the bead's
own grep/diff ACs. Reserve files in **both** Agent Mail projects (board repo +
target repo) before editing.

**Do not open a BCA `wave/*` branch for these.** Doctrine and skill text go
to the target's `main`.

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
- `cross-repo` beads: commit in the repo that tracks the files (see § Cross-repo).
