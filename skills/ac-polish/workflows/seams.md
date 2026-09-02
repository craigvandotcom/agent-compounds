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
| **ARTIFACT** | `<STATE>/plan.md` during the loop, from `references/seams-plan-template.md`. Below the marker it holds CANDIDATE ROWS ONLY — first-seen text, id order — written by `scripts/seams-merge.py`, never by hand. Hits, declines, verifications live in `<STATE>/ledger.json`; decline-only rows in `<STATE>/declined.md`. So the digest moves iff a candidate is added or dropped. `printf '*\n' > <STATE>/.ignore` first, so readers' `rg` never surfaces it. Copied to `_plans/<date>-seams-<slug>.md` at hand-off |
| **CHECKLIST** | `references/seams-checklist.md` |
| **READERS** | K blind readers per round (default 3), each sent `references/seams-reader-prompt.md` verbatim with `<TARGET>`, `<CHECKLIST>` and `<REPORT>` (= `<STATE>/reports/r<N>-<letter>.md`) filled — NOT the plan, NOT the round number, NOT prior findings. Their rows reach ARTIFACT only through MERGE |
| **VALIDATE** | `seams-merge.py round … --validate --repo <root>` re-runs every new row's `found-by`; a row is dropped iff none of its commands reproduces. Facts are validated; judgement is not |
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

## MERGE — one command per round, after the K reports land

```
scripts/seams-merge.py round --state <STATE> --artifact <STATE>/plan.md --round <N> \
    --repo <root> --validate <STATE>/reports/r<N>-*.md
```

It keys rows by LOCATION (files cited, overlap ≥ half the smaller set), never prose; records
each reader's hits; keeps the first-seen text; sends decline-only rows to the sidecar; drops
rows no command reproduces; and prints `new=<n>` — the discovery signal. A reader that reports
`ARTIFACT SEEN: yes` still adds candidates but its hits do not count toward consensus. A row
that designs is discarded by the orchestrator before the merge. Then record the round with
`polish-fixpoint.sh` as the SKILL.md loop says — every artifact change is a round to the
script, or the next `--pre` fires as an out-of-band amendment.

## Stop — the stamp means discovery converged

A round whose K blind readers add no candidate leaves the digest unchanged; at round ≥ 2 the
script stamps. That is the measurement: three independent readers found nothing new. Blind
readers discover well and reach consensus badly (dogfood 2026-09-02: rounds 1–3 found 11,
rounds 4–9 found 2), so consensus is NOT more blind rounds — it is the post-stamp work below.
Bound-exhausted or cycling hands off unstamped, exactly as in every other mode. New singletons
every round indict the CHECKLIST's silent-failure question, not the target.

## After the stamp — consensus, then hand-off

1. **Verify singletons.** Each row with one counting hit goes to two fresh verifiers who are
   GIVEN the row and asked to confirm or refute the fact and the silence with a command:
   `seams-merge.py verify --id <cNNN> --reader <name> --verdict confirm|refute [--command …]`.
   Two confirmations promote; one refutation with a reproducing command archives.
2. **Targeted pass, if warranted.** A singleton that resolved the target to an object the
   majority did not (a handoff blob beside a column) is a NEW seams run with that object as
   TARGET — its own loop, its own stamp — not extra rounds of this one.
3. **`seams-merge.py handoff`** writes Confirmed (≥2 distinct counting readers, or verifier
   confirmations) · Seen once · an empty Declined table · an empty Approach, and archives every
   declined row to `<STATE>/declined-archive.md`. The orchestrator then asks the human to
   promote or drop each Seen-once row, rewrites the Problem paragraph to cluster the Confirmed
   rows into the few questions the Approach must answer once, moves only the Declined rows
   that CONSTRAIN the Approach (a designed backstop, a tested invariant, a reachability limit)
   into the plan, and copies the artifact to `_plans/` with frontmatter naming rounds and verdict.

## Hand-off — a converged findings plan with no approach is a dead end

END every seams run, stamped or not, by invoking `ac-plan` with the findings file as its
problem statement, or by queueing that hand-off explicitly with the human. `ac-plan` writes
the Approach and every remaining ac2 section into the same file, then hands it to
`ac-polish plan`. Do not finish by reporting success and stopping.
