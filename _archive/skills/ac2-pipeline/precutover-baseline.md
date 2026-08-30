# Pre-cutover baseline — defects by first-catch stage

The ac2 thesis is that verifying at the fresh moment (flight check at claim, causal probe at
close) catches defects EARLIER and cheaper than a refine ceremony does. A thesis with no
sensed variable is decoration, so this file records the variable BEFORE the cutover. After
the cutover, re-run the SAME commands and compare — "did ac2 help?" then has an answer that
is a measurement rather than an opinion.

**Window:** board inception `2026-06-13T13:32:14Z` → the pre-cutover commit
`5410d85d9d29c0f76c57b64b645027b79636ae85` (`5410d85`, 2026-08-27).
Every command below is anchored to that SHA, so each figure re-derives identically forever —
a baseline read from the working tree would drift the moment anyone touched the board.

**Vocabulary is FROZEN.** The buckets are the board's actual catch-stage label set —
`review-finding` · `ci-finding` · `qa-finding` · `hygiene-finding` · `prod-finding` — plus an
explicit `unknown`. An unrecorded stage is recorded as unknown. It is never inferred, never
back-filled, and no new stage token is minted.

## The measurement

| First-catch stage | Count | Meaning |
|---|---:|---|
| `review-finding` | 24 | caught by the factory's own review gate |
| `ci-finding` | 2 | caught by CI |
| `qa-finding` | 1 | caught by QA — **outside** the factory's own gates |
| `hygiene-finding` | 0 | caught by a hygiene pass |
| `prod-finding` | 0 | caught in production — **outside** the factory's own gates |
| `unknown` | 52 | defect-shaped (`issue_type: bug`) with no catch-stage label |
| **total** | **79** | the population: any bug, or any bead carrying a catch-stage label |

Buckets sum to the total: 24 + 2 + 1 + 0 + 0 + 52 = 79.

**EXTERNAL-VERDICT COUNT: 1** (`qa-finding` + `prod-finding`). This is the number the plan's
success criterion actually cares about: of 27 catch-stage-labelled findings, exactly ONE
arrived from outside the factory's own review/CI gates, and NONE from production. A factory
whose only critic is itself cannot discover that it is wrong. Supporting figure: the board
carries **2** `discovered-from` edges in total across 283 records.

## The commands (each figure re-derives from the one beside it)

Per stage — substitute the label:

~~~sh
git show 5410d85:.beads/issues.jsonl \
  | jq -r --arg l review-finding 'select((.labels // []) | index($l)) | .id' | sort -u | wc -l
~~~

The `unknown` bucket — defect-shaped, no catch-stage label (never inferred):

~~~sh
git show 5410d85:.beads/issues.jsonl \
  | jq -r 'select(.issue_type=="bug")
           | select(((.labels // []) | map(select(test("^(review|ci|qa|hygiene|prod)-finding$"))) | length) == 0)
           | .id' | sort -u | wc -l
~~~

The external-verdict count — the plan's real variable:

~~~sh
git show 5410d85:.beads/issues.jsonl \
  | jq -r 'select((.labels // []) | any(test("^(qa|prod)-finding$"))) | .id' | sort -u | wc -l
~~~

The total population — bugs plus anything catch-stage-labelled:

~~~sh
git show 5410d85:.beads/issues.jsonl \
  | jq -r 'select(.issue_type=="bug" or ((.labels // []) | any(test("^(review|ci|qa|hygiene|prod)-finding$"))))
           | .id' | sort -u | wc -l
~~~

Supporting figures — record count, `discovered-from` edges, and the window's start:

~~~sh
git show 5410d85:.beads/issues.jsonl | wc -l
git show 5410d85:.beads/issues.jsonl | jq -r '[.dependencies // [] | .[] | select(.type=="discovered-from")] | length' | awk '{s+=$1} END {print s+0}'
git show 5410d85:.beads/issues.jsonl | jq -r '.created_at' | sort | head -1
~~~

## Reading it after the cutover

Re-run every command above against the POST-cutover SHA in place of `5410d85` and compare
two things, in this order:

1. **The external-verdict share.** `(qa-finding + prod-finding) / catch-stage-labelled`.
   At baseline: 1/27. If ac2 works, this RISES — not because quality fell, but because
   verdicts from outside the factory start reaching the board at all. A flat 1/27 with more
   total findings means the factory is still only grading its own homework.
2. **The `unknown` share.** At baseline 52/79 of defect-shaped beads carry no catch stage,
   which is the honest statement that most defects were never attributed. If ac2's close-gate
   works, this FALLS, because attribution happens at close rather than never.

A drop in raw finding count is NOT evidence on its own — fewer findings is equally consistent
with a gate that stopped firing. Read it against the two shares above, or not at all.

**Method note.** `wc -l` output is quoted here without the usual `| tr -d ' '` trim: `tr` is
shadowed by a tmux alias in this fleet's interactive zsh, which makes the trimmed form fail
with "open terminal failed: not a terminal" for anyone re-running these by hand.
