# plan-seams-reader.md — ac-plan's own seams reader prompt, sent VERBATIM to every reader

The per-object reader `ac-plan/SKILL.md` step 4 spawns is THIS prompt, not
`ac-polish/references/seams-reader-prompt.md` — that file's six blanks
(`<LENS>`, `<SUBJECT>`, `<FILES>`, `<MAPS>`, `<CHECKLIST>`, `<REPORT>`) are filled by seams
mode's own machinery (`seams-merge.py`, the maps ledger, the seams checklist), none of which
a plain `ac-plan` run has. This prompt is OBJECT LENS ONLY and repo-agnostic: no maps, no
checklist file, no merge script — one reader, one pass, output folded straight into the plan's
Deliverables / Out-of-scope / Problem sections. OUT: seams mode's own prompt and its aimer
(`scripts/aim.sh`) — a seams-mode run still uses those, unchanged.

Substitute `<OBJECT>` (the resolved object — its path and the symbols/columns that name it),
`<DELIVERABLES>` (the plan's `## Deliverables` section, verbatim, so the reader knows what the
plan is claiming to change), `<FILES>` (the DERIVED file list, below), and `<REPORT>` (an
absolute path OUTSIDE the repository). Nothing else.

## The fresh-reader rule

Carried verbatim from `ac-polish/SKILL.md`: **it carries NO memory of any earlier round; one
that has read the artifact is no second opinion.** This reader is spawned once, stateless, with
nothing but this prompt and the three substituted blanks — it has not seen the plan's Approach,
any prior draft of this table, or any earlier reader's report.

## Building `<FILES>` — the derived file list

The conductor builds `<FILES>` before spawning this reader; the reader does not derive it.
Two parts, concatenated into one list, each line tagged `SOURCE` or `TEST`:

1. **SOURCE** — the object's touchers: run `skills/_tools/touchers.sh derive <object-path>` to
   get its `<stem>\t<N>\t<command>`; run `<command>` and tag every line it prints `SOURCE`.
2. **TEST** — every test, journey and UI QA file naming the object, found with the globs the
   conductor passes in from the repo's own testing conventions (e.g. `**/*<object>*.test.*`,
   the journeys dir, the UI QA spec dir — repo-specific, never invented by this prompt). Tag
   every match `TEST`.

**`no-test-globs` refusal.** If the conductor gives this prompt NO test globs at all (not
"globs that matched nothing" — zero globs passed), REFUSE outright: emit `no-test-globs` as
the whole report and stop. Returning an empty tests line is silent and indistinguishable from
"the reader checked and found nothing"; refusing is not. If globs WERE given but none of them
matched any file, that is not a refusal — say so on the tests line (below): `none exists`.

## Sweep

The FILES are the whole search space — every SOURCE and TEST file listed. Open each, in list
order, with `rg` from the repository root. A row cites a line that reads or writes a field of
<OBJECT>. Never edit, copy or create any file in the repository. Never run a test runner,
formatter or linter — read tests, do not run them.

For each **SOURCE** file, classify its relationship to <OBJECT> as exactly one of:

- `reads` — the file reads a field of the object without writing it back.
- `writes` — the file constructs, mutates, or deletes a field of the object.
- `no seam` — the file is on the derived list (a toucher by name-match) but this sweep found
  no line that actually reads or writes a field of the object. `no seam` is a real finding —
  the touchers count over-includes a bare-word collision — and is never silently dropped.

Then, for each SOURCE row: `contract-on-drift` (a type, an assertion, a test path that would
fail if this file's shape of the object drifted, or `none`) and `breaks-if` (one line: the
observable failure if this file's edge to the object is removed or changed without updating
it — a hypothesis stated from the row, not designed).

For each **TEST** file, classify as exactly one of:

- `unchanged` — the test already covers the object's current shape; the plan's Deliverables
  do not touch what this test asserts.
- `must update` — the plan's Deliverables change something this test asserts on the object;
  the test will fail or fail to catch a regression unless it is updated alongside the plan.
- `none exists` — a glob was given, matched no file, and no test covers this slice of the
  object at all. (Distinct from `no-test-globs` above: globs existed, the search came up
  empty, and that emptiness is itself the finding.)

## Output

Write the report to `<REPORT>` in exactly this shape — parsed downstream by `ac-plan`:

```
OBJECT: <what this reader took <OBJECT> to be; anything it could not resolve>

SEAMS:
| path | reads\|writes\|no seam | contract-on-drift | breaks-if |
|---|---|---|---|
… one row per SOURCE file, in list order, none omitted

TESTS:
| path | unchanged\|must update\|none exists | why |
|---|---|---|
… one row per TEST file (or per test glob when none exists), in list order, none omitted

OUT-OF-PLAN:
| finding | deliverable compromised | priority |
|---|---|---|
… a row for every seam this sweep found that the plan's <DELIVERABLES> does not name and does
not cover — something a merge of this object's real seams would break that the plan as written
never mentions. Priority is P0 (silently breaks a stated Deliverable) · P1 (breaks a caller
outside the stated Deliverables but inside the swept files) · P2 (a latent gap — a `no seam` or
`none exists` row worth a human's attention) — only P0–P2 survive; anything weaker than P2 is
not a row here, it goes to DECLINED with its reason.

DECLINED:
| candidate | reason declined |
|---|---|
… everything this sweep looked at and chose NOT to raise — a `no seam` row already explained
above, a TEST row already `unchanged`, an OUT-OF-PLAN candidate below P2. A report with an
empty SEAMS or TESTS table and an empty DECLINED table is indistinguishable from an unstarted
sweep, so DECLINED is never optional.
```

## Confirming an OUT-OF-PLAN claim

An OUT-OF-PLAN row is a claim that the plan, as drafted, silently breaks something. Before the
conductor acts on it (folds it into Deliverables or Out-of-scope), send it to a **fresh second
reader** — stateless, no memory of this round, sent ONLY the object (`<OBJECT>`) and the one
claim (the OUT-OF-PLAN row's finding text) — and ask it to confirm or reject the claim from the
code alone, citing the line. A claim the second reader cannot reproduce from the object and the
code does not survive into the plan; log it in DECLINED with `unconfirmed` as the reason
instead. This mirrors seams mode's own rule that a claim answerable from the map is never taken
on the first reader's word alone.
