# The implementation contract — loop-2 consumption

Schema (headers, bars, who emits what, test-tier slugs):
`beads-standards/reference/bead-conventions.md` § Implementation contract.
`ac-beadify` stamps elements 3+5; `ac-bead-refine` verifies all six and
withholds `refined` if any is missing. This file is only how **this loop
consumes** that schema.

## Freeze SHA

Phase 1 records `FREEZE_SHA=$(git rev-parse HEAD)` at phase open. Every
`## Anchors` header names that sha. A bead whose territory intersects
`git diff --name-only $FREEZE_SHA..HEAD` at the sitting goes back through
refine — the freeze is a label, not a lock (`FRICTIONS.md`
`frozen-head-is-not-enforceable-on-a-shared-checkout`).

## Mutation sampler (element 4)

Phase 3 reverts the bead commit, restores the test file, and checks the
**verbatim** `## Declared RED` text. A test that stays green is hollow
and reopens the bead. `RED: n/a` is excluded from the sample and from
`hollow%`. Mechanics: `references/converge-phase.md` § 5.

## Phase 3 tier report (element 3 sub-field)

A green is not reportable until the phase report lists every tier the
pass **covered** and every tier it **excluded**, with the command used.
If any bead's `### Test-tier exposure` names a tier the standing pass
does not run, that tier MUST be executed (repo command from AGENTS.md)
before those beads can be called green. A green whose scope is unstated
is not a green.

## Worked example

```markdown
## Bead bd-x7k2 — reject expired share links at the API boundary

## Anchors (verified at HEAD 4f2a9c1)
- `src/app/api/share/[token]/route.ts:38` — `const link = await db.shareLink.find(token)`
- `src/lib/share/validate.ts:12` — `export function isRevoked(link: ShareLink)`

## Baselines (executed)
$ rg -n "isRevoked" src | wc -l
3
$ pnpm test src/lib/share/validate.test.ts
 ✓ 6 passed  (no expiry case present)

## Territory
- src/app/api/share/[token]/route.ts
- src/lib/share/validate.ts
- src/lib/share/validate.test.ts

### Test-tier exposure
- standing-vitest — validate.test.ts is in the unit suite; the route is covered there
- (no supabase-integration — no migration / lib/db / SQL surface)

## Declared RED
Test `rejects a link past expires_at` must FAIL before the fix with approximately:
`AssertionError: expected 200 to be 410`

## Sequence + risk
Position 2 of 4 in epic share-hardening. Flags: hot-tier. (No migration, no native.)

## Acceptance Criteria
- [ ] `GET /api/share/expired` returns 410 (baseline above: returns 200)
- [ ] `isRevoked` is unchanged in behaviour for non-expired links (existing 6 tests stay green)
- [ ] The expiry check runs BEFORE the DB read is serialised to the response body
```

Every line of that spec is checkable against the tree without asking its author a question.
That is the bar: **a worker in Phase 2 must never need to ask.**
