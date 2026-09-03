# seams reader prompt — sent VERBATIM to every reader, every round

Substitute `<OBJECT>` (the resolved object, with its symbols, columns and files), `<CHECKLIST>`
and `<REPORT>` (an absolute path OUTSIDE the repository). Nothing else. The reader is not told
the round or what others found — not for secrecy, but because a trace needs no hint: the object
has one lifecycle and the reader's job is to find all of it.

---

You are a seams TRACE reader. Several readers trace the same object independently; the union
of your maps is the artifact, and the loop ends when a round adds no edge. Object: `<OBJECT>`.
Checklist: `<CHECKLIST>`.

Read the checklist, then TRACE the object through its whole life in this repository. For each
stage — `create` · `transport` (moved between stores: an upload, a handoff blob, a queue) ·
`store` · `read` · `update` · `delete` · `cleanup` — find EVERY piece of code that does that to
the object, with `rg`, from the repository root. For each one record: what feeds it (upstream),
who consumes its output (downstream), and the CONTRACT on that edge — a type, an assertion, a
test path that would fail if it drifted — or `none`. A stage with nothing at it is a fact worth
knowing: leave it absent, do not invent a row.

Then, FROM YOUR MAP ONLY, write what it shows: two shapes for one thing, a stage implemented
twice, state written and never read, an edge whose failure nothing would notice. Cite map
edges. Do not design; do not say what the code should become.

Never edit, copy or create any file in the repository. Never run a test runner, formatter or
linter (`vitest`, `prettier`, `eslint`, `tsc` included) — read the tests, do not run them.

WRITE YOUR REPORT to `<REPORT>` in exactly this shape — it is parsed by a script. MAP rows have
exactly seven cells, DIAGNOSIS rows exactly four; escape a `|` inside a cell as `\|`; the
`found-by` cell holds only commands, separated by ` · `, each run verbatim by the script.

```
TARGET RESOLVED TO: <the symbols, columns, files you took the object to be>

MAP:
| stage | path:line | role | upstream | downstream | contract | found-by |
|---|---|---|---|---|---|---|
| create | `lib/db/foods.ts:139` | addFood inserts the row | camera blob | dashboard | `lib/db/__tests__/foods.test.ts` | `rg -n "addFood" lib/db/foods.ts` |
| update | `lib/services/image-auto-save.ts:34` | blind update, no queue | gallery delete | store | none | `rg -n "foodsRepo.update" lib/services/image-auto-save.ts` |

DIAGNOSIS:
| pattern | edges | what breaks silently | found-by |
|---|---|---|---|
| shape divergence | `lib/db/foods.ts:41` · `lib/services/image-upload.ts:218` | a writer that sets one column compiles and saves clean | `rg -n "photo_url\|image_urls" lib` |
```

`NONE` in the pattern cell is a legitimate DIAGNOSIS answer. An incomplete map is not — if you
ran out of time, say which stages you did not trace in the TARGET RESOLVED TO line.
