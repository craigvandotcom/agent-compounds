---
name: failed-br-create-can-leave-an-empty-bead
description: a br create that fails partway can leave a bead titled "…" with no body, labels or probe — it trips lint for every agent in the repo; verify it's abandoned, then close it obsolete with a TRIAGE-CLOSE comment
metadata:
  type: recipe
  domain: org
  evidence: 2026-09-27 session 89d56f7a — two empty beads (ac-jz35, ac-qmk6, created 0.26s apart) blocked an unrelated commit via lint check 35
  tags: [beads, br, lint]
---

A `br create` that fails partway can still leave a bead behind: title `"…"`, no
description, labels, probe or dependencies. It is an open bead like any other, so repo
lint (check 35, landing record on close) fails for **every** agent committing in that repo,
not just the one that created it.

**Recipe:**
1. Confirm it is abandoned: no assignee, not touched since creation, not referenced by
   any other bead or plan.
2. Close it with an `obsolete:` close reason.
3. Add a `TRIAGE-CLOSE:` comment citing `tree: <sha>` and whose ruling it was. That
   satisfies lint's landing-record rule for a close that shipped no work.

Two such beads created a fraction of a second apart point to one failed create that
was retried, not two real intents.
