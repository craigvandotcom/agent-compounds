# polish · seams mode

The loop is in `ac-polish/SKILL.md` and is the same in every mode. This file supplies only
what seams mode binds, and it is a MANDATORY load for a seams run.

Seams mode differs in what the reader READS and WRITES: it reads the CODE around a target and
writes FINDINGS into a plan. It fixes nothing. The plan goes to `ac-plan` for its approach,
then through the normal chain — plan discovery from code, the second source of plans beside
human intent. The seams on one object are ONE design problem: decided together in a plan, or
entrenched separately by piecemeal fixes.

## Bindings

| knob | seams mode |
| --- | --- |
| **TARGET** | a name — a phrase, symbol, column, file. Given as the argument → no prompt. Absent → ONE prompt before anything is read or spawned (below) |
| **ARTIFACT** | `_plans/<date>-seams-<slug>.md`, created from `references/seams-plan-template.md` — Problem · Confirmed · Seen once · Declined · Approach (empty) |
| **CHECKLIST** | `references/seams-checklist.md` |
| **READERS** | K blind readers per round (default 3), each sent `references/seams-reader-prompt.md` verbatim with `<TARGET>` and `<CHECKLIST>` filled — NOT the plan, NOT the round number, NOT prior findings. Their rows reach ARTIFACT only through MERGE |
| **VALIDATE** | every `found-by` command in the plan re-runs and reproduces; a row that fails is deleted whoever cited it. Facts are validated; judgement is not |
| **STAMP** | `polish-fixpoint.sh --mode seams` — keys under the `seams_` prefix, so the later `--mode plan` polish of the same file keeps its own stamp beside this one |

## The start prompt — only when no target is given

```
AskUserQuestion: "What should ac-seams study?"
  Aim — last week      what we just made worse     scripts/aim.sh --since 1w
  Aim — last 4 weeks   the recent drift            scripts/aim.sh --since 4w
  Aim — all time       where the debt lives        scripts/aim.sh --since 1y  (`all` behind it)
  Other → a typed target
```

Aim ranks candidates with the command beside each row; the human picks ONE — the second and
last prompt. Aim runs once per session: re-aiming inside a loop is a moving target.

## MERGE — the orchestrator writes the plan; readers never touch it

- Key rows by LOCATION (files · symbols), never prose. Duplicates in Confirmed → key on symbol.
- Count independent hits across all readers and rounds. **Confirmed = ≥2 hits. Seen once = 1
  hit, kept visible, never dropped** — a reproducing command is a true fact lacking a second
  opinion; the human may promote it at approval.
- Declined rows carry the reason and the command. A row that designs is discarded.
- Write flags, never hit counts, or the digest moves every round and nothing converges.

## Stop

A round whose K blind readers add no candidate and confirm nothing leaves the digest
unchanged; at round ≥ 2 the script stamps. K independent readers finding nothing new IS the
consensus for "nothing left". Blind because here the artifact is the verdict, not the subject:
a reader shown prior findings confirms them and looks nearby. New singletons every round
indict the CHECKLIST's silent-failure question, not the target.

## Hand-off — a converged findings plan with no approach is a dead end

END a STAMPED seams run by handing the plan to `ac-plan` for its Approach, or by queueing that
hand-off explicitly with the human. Do not finish by reporting success and stopping.
