# The implementation contract (Phase 1 output schema)

The six elements every bead must carry before it may enter Phase 2. Phase 2 has no gates
**because** these are true; a bead missing any element is not a slightly-weaker bead, it is
an ungated bead with no contract behind it — hold it back a cycle instead.

Enforcement today is `references/delegation-prompts.md` § Spec-phase prompt, which demands
these elements verbatim from the current `ac-bead-refine`. Native support (a schema in
`beads-standards/reference/bead-conventions.md` + first-class refine output) is tracked by
bead `ac-ac-loop2-contract-native-support-fb8k`.

## The six elements

### 1. Verified anchors

Every `file:line` the spec cites was OPENED at the frozen HEAD, and the quoted text matches
what is there. A citation reconstructed from memory, from a grep hit's line number, or from
a sibling bead's spec is a **fabrication**, not an anchor.

- Record the HEAD sha the anchors were verified at. Phase 1 freezes HEAD precisely so this
  sha stays valid for the whole phase.
- Fail mode it prevents: a worker in Phase 2 opens `src/foo.ts:112`, finds unrelated code,
  and improvises. Improvisation inside a gate-free phase is unbounded.

### 2. Executed baselines

Every countable claim in the spec was RUN and the **literal output pasted**. Never a
reasoned or estimated count.

- "There are 14 call sites" → paste the command and its output.
- "This test currently passes" → paste the run.
- Fail mode it prevents: an AC written against a count that was never true, which a no-op
  can satisfy or which no work can satisfy.

### 3. Territory manifest

The exact list of files this bead may touch. It is the worker's **entire write permission**
in Phase 2 and the input to Phase 0's lane-disjointness computation on the next cycle.

- Paths, not globs, wherever the file exists today. A glob is permitted only for files the
  bead CREATES.
- A bead whose territory cannot be bounded is not ready — split it or send it to the docket.
- Fail mode it prevents: two workers in different lanes editing the same file with no gate
  between them.

### 4. Declared RED expectation

A written prediction of the pre-fix failure:

> "Test `<name>` added by this bead must FAIL before the fix, with approximately:
> `<error text / assertion shape>`"

Phase 3's mutation sampler consumes this **verbatim**: it reverts the fix and checks that
the declared failure actually appears. A test that stays green with its fix reverted is
**hollow** and its bead reopens.

- Beads that add no test declare `RED: n/a — <why>` (pure refactor, config, docs). The
  sampler skips them and they are excluded from the `hollow%` denominator.
- Fail mode it prevents: tests written to pass rather than to catch — the single most
  common way a green suite stops meaning anything.

### 5. Sequence position + risk flags

- **Sequence position** — this bead's index within its epic, so the lane coordinator
  dispatches in an order that respects intra-epic dependencies without a gate.
- **Risk flags** — zero or more of `migration` · `native` · `hot-tier` · `cold-tier`.
  `migration` and `native` route the bead to Phase 2's **serial risk queue**; `hot-tier`
  marks it as a candidate for the per-landing-check fallback if the cycle's `repair%`
  breaches its threshold.

### 6. No-op-proof acceptance criteria

Each AC is adversarially checked against one question: **could an empty diff satisfy this?**

- "The page loads without errors" → a no-op satisfies it. Reject.
- "`GET /api/foo` returns 404 for a deleted record (currently 200 — baseline pasted above)"
  → an empty diff cannot satisfy it. Accept.
- The adversarial round's job is to BREAK the ACs, not to bless them. A round that finds
  nothing on a multi-AC bead is a round that was not run adversarially.

## Worked example

```markdown
## Bead bd-x7k2 — reject expired share links at the API boundary

### Anchors (verified at HEAD 4f2a9c1)
- `src/app/api/share/[token]/route.ts:38` — `const link = await db.shareLink.find(token)`
- `src/lib/share/validate.ts:12` — `export function isRevoked(link: ShareLink)`

### Baselines (executed)
$ rg -n "isRevoked" src | wc -l
3
$ pnpm test src/lib/share/validate.test.ts
 ✓ 6 passed  (no expiry case present)

### Territory manifest
- src/app/api/share/[token]/route.ts
- src/lib/share/validate.ts
- src/lib/share/validate.test.ts

### Declared RED
Test `rejects a link past expires_at` must FAIL before the fix with approximately:
`AssertionError: expected 200 to be 410`

### Sequence + risk
Position 2 of 4 in epic share-hardening. Flags: hot-tier. (No migration, no native.)

### Acceptance criteria
- [ ] `GET /api/share/<expired>` returns 410 (baseline above: returns 200)
- [ ] `isRevoked` is unchanged in behaviour for non-expired links (existing 6 tests stay green)
- [ ] The expiry check runs BEFORE the DB read is serialised to the response body
```

Every line of that spec is checkable against the tree without asking its author a question.
That is the bar: **a worker in Phase 2 must never need to ask.**
