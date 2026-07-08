# ac-hygiene — incident narratives

Full narratives behind rules compressed to point-of-use form in SKILL.md. Read for
evidence/history only — the SKILL.md rules are binding on their own.

## 2026-07-06 — `git add -A` swept a 2.4 GB build dir into a commit

A hygiene run sat next to untracked orphans (a stale `.next.stale-*` build dir plus
scratch output). `git add -A` committed all of it: a 2.4 GB build directory landed in a
commit and broke the Turbopack build. Rule at point of use (SKILL.md Phase 3, commit
block): stage the exact files you changed — track your changed paths from the implementer
reports; never `git add -A` / `git add .`.

## 2026-07-06 — shared-checkout hygiene branch absorbed 4 concurrent human commits

A full run held HEAD on its hygiene branch for hours in a shared repo checkout. A human
(and scheduled agents commit the same way) committed to that checkout during the run; 4
concurrent human commits landed on the hygiene branch, entangling the PR. Rule at point
of use (SKILL.md Phase 0): run in a git worktree — the run gets its own checkout so this
cannot happen.
