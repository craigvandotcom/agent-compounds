# Already-beadified existence probe

`br list` is open-only by default — closed children of a shipped wave are
invisible unless `--all` is passed. Match title + labels + description, never
description-only.

```bash
PLAN_SLUG=$(basename "$PLAN_FILE" .md)
EXISTING=$(br list --all --limit 0 --json | jq --arg slug "$PLAN_SLUG" --arg file "$(basename "$PLAN_FILE")" '
  [.issues[] | select(
    ((.labels // []) | index("plan-" + $slug))
    or ((.title // "") | test($file; "i"))
    or ((.description // "") | test($file; "i"))
  )]
')
```

A `plan-<slug>` / `plan-${PLAN_SLUG}` hit → archive-and-skip (Phase 4 Archive
only; do not re-beadify). Any other non-empty hit → skip to Phase 4 (Verify).
Empty → continue from the recovered phase.
