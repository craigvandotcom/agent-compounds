# ac-land Phase 4 — hand-off mechanics

## Session summary

Output for the user and next session:

```markdown
## Bead-Work Session Summary

**Beads Completed:** N (list IDs + titles)
**Beads Remaining:** M (from `br ready --json`)
**Commits:** K commits pushed

**Quality Gates:** All passing | Issues filed (list)

**Learnings Applied:** X upgrades (list targets)

**Open Issues:**

- (any filed beads or blockers)
```

**Present next session choice with `AskUserQuestion`** — interactive sessions only. When driven
headless by the ac-implement coordinator's Exit-Land prompt ("never `AskUserQuestion`"), skip
this ask entirely and just emit the summary — the loop, not a human, decides what runs next
(same carve-out as `ac-publish`):

```
AskUserQuestion(
  questions: [{
    question: "Session landed. What's next?",
    header: "Next step",
    multiSelect: false,
    options: [
      { label: "Start next wave", description: "Run /ac-plan or /ac-implement — {M} beads remaining, pick up the next wave" },
      { label: "Refine remaining beads", description: "Run /ac-polish — revise remaining beads before implementing the next wave" },
      { label: "Done for now", description: "Session over — nothing more to do until the next wave is picked up" }
    ]
  }]
)
```

Note: `ac-land` runs **LAST** — after the merge. Merging is the work; landing brings it to rest
(clean + wiser). When driven by the ac-implement swarm, land is the **guaranteed exit step for
every stop path**, so the loop is never "done" until it has landed. By the time landing runs,
THIS wave has already merged to main — there is nothing left to merge for it. The only next
steps are starting the next wave or stopping.

## Preserve the raw friction carrier (before teardown discards /tmp)

Copy it — `stage`/`cost`/`lesson`/`class` typing intact — into a git-tracked artifacts path
FIRST, mirroring the `.claude/reviews/batch/` convention already in use:

```bash
if [ -f "/tmp/loop-retro-${RUN_ID}.md" ]; then
  DEST=".claude/reviews/loop-retro"
  mkdir -p "$DEST"
  cp "/tmp/loop-retro-${RUN_ID}.md" "$DEST/loop-retro-${RUN_ID}.md"
  git add "$DEST/loop-retro-${RUN_ID}.md"
  git commit -m "ac-land: preserve raw friction carrier — RUN ${RUN_ID}" -- "$DEST/loop-retro-${RUN_ID}.md"
  git push origin main || { git pull --rebase origin main && git push origin main; }
fi
```