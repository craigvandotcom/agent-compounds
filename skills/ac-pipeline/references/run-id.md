# Deterministic `$ARTIFACTS_DIR` — claim-id key + run-id discriminator

Each pipeline stage keeps private scratch in `/tmp` (`$ARTIFACTS_DIR`: `progress.md`, findings,
consensus files). The rule: **a stage NEVER guesses which dir is its own.** It derives the dir
from keys it can compute, never by globbing `/tmp` and hoping (the newest-wins / "solo vs
parallel" heuristics caused real bugs — ac-land picking the wrong session's dir; ac-merge
orphaning a timestamped dir on resume).

## ToC
- The key: the claim/batch id (trunk-direct — NOT the branch)
- Mint order: the claim id comes FIRST, .claim-id lands INSIDE the dir it keys
- RUN_ID: the orchestrator's run scope (two jobs) — mint-if-absent
- Prefixes
- Dual-mode
- The ac-land exception (a consumer that can't self-derive)

## The key: the claim/batch id (trunk-direct — NOT the branch)

Under trunk-direct, every conductor works directly on `main` — there is no wave branch, so
`WAVE_SLUG="$(git branch --show-current | tr '/' '-')"` collapses to the constant `main` for
every session. Keying the artifact dir on that constant would make every concurrent conductor
compute the identical `/tmp/bead-work-main` and clobber each other's scratch — this is exactly
the bug bd-u2lo1.9 re-keys away from. The wave-slug convention this doc used to document is
retired for every skill still under trunk-direct; it remains valid **only** on the legacy
branch path, `ac-merge` (see Prefixes, below), which still has an actual wave/feature branch to
key on.

The replacement key is the **CLAIM/BATCH ID**, minted once per claimed batch by
claim-at-selection (`ac-loop` Phase 1/2, or `ac-implement` Phase 1a standalone — precedent:
body-compass-app memory `claim-adopted-beads-before-planning`): format
`<first-claimed-bead-id>-<YYYYMMDD>` (e.g. `bd-u2lo1.1-20260712`). It is unique per batch
(a different first-claimed bead or a different day yields a different id), shared by every
stage that touches that batch, and requires no handshake beyond reading a file:

```bash
ARTIFACTS_DIR="/tmp/<prefix>-<claim-id>${RUN_ID:+-$RUN_ID}"   # generic single-session formula; fan-out
                                                             # stages insert a per-child key — see the
                                                             # `bead-work` / `bead-refine` rows under § Prefixes
mkdir -p "$ARTIFACTS_DIR"
```

- **No globbing, no newest-wins, no detection** for any stage that already has the claim id in
  hand. Stable across compaction — recover it from the `.claim-id` file, or from a TaskCreate
  description that baked in the literal resolved path, never by re-deriving from the branch
  (which no longer discriminates anything under trunk-direct).

## Mint order: the claim id comes FIRST, `.claim-id` lands INSIDE the dir it keys

There is an apparent chicken-and-egg here — the claim id is *written into*
`$ARTIFACTS_DIR/.claim-id`, but the dir's own name is *derived from* the claim id. The resolution
is a fixed sequence, always in this order:

1. **Mint the claim id** — `<first-claimed-bead-id>-<YYYYMMDD>`, computed from the already-known
   candidate bead list. Computing the string requires no mutation (only the actual `br update`
   claim requires mutating bead state) — so the id can be, and should be, computed *before* the
   dir is derived, even if the actual claim mutation hasn't fired yet.
2. **Derive `$ARTIFACTS_DIR` from it** (formula above).
3. **`mkdir -p "$ARTIFACTS_DIR"`.**
4. **Write `.claim-id` (first line = the claim id) and mirror it as the first line of
   `progress.md`'s header** — only now that the dir exists.

Every consuming skill's Phase 0 follows this order:

- A session that receives the claim id already minted — handed down by `ac-loop`'s delegation
  prompt (e.g. "claim id `bd-u2lo1.1-20260712`"), or recovered from an existing
  `$ARTIFACTS_DIR/.claim-id` on resume — skips straight to step 2.
- A standalone first-run session that has to mint its own computes the identical id *ahead of*
  Phase 1a's actual claim mutation, from the same unmutated, already-filtered ready-bead
  candidate list Phase 0 already gathered — so Phase 0's `$ARTIFACTS_DIR` and Phase 1a's later
  claim-at-selection write agree on the same path with no re-derivation and no mismatch.

## RUN_ID: the orchestrator's run scope (two jobs) — mint-if-absent

An **orchestrator always mints one `RUN_ID` per run** (ac-loop Phase 0:
`RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"`) and passes it (`RUN_ID=<id>`) to every stage it spawns. It
does two jobs:

1. **Parallel disambiguation** — two sessions working the *same* claimed batch (rare, but
   possible if a batch is split across sessions) would otherwise both compute
   `/tmp/bead-work-bd-u2lo1.1-<child-id>`; distinct RUN_IDs keep them apart. RUN_ID separates
   *runs*, never siblings inside one run — that is the per-child key's job (see § Prefixes).
2. **Run scoping** — every dir this run created carries the RUN_ID suffix, so a consumer can
   safely gather *exactly this run's* dirs with a scoped glob (`/tmp/bead-work-*-$RUN_ID`), never
   a stale or foreign one. This is what lets **ac-land learn from every batch a multi-batch run
   shipped.**

`${RUN_ID:+-$RUN_ID}` appends it when present, nothing when absent.

**Mint-if-absent is every consuming skill's Phase 0 responsibility.** If `RUN_ID` wasn't handed
down by an orchestrator (a standalone human run), mint one locally with the same formula —
`RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-$$}"` — rather than leaving it unset. This keeps the
dir-naming formula identical whether the skill runs standalone or orchestrated, and gives a
standalone run the same run-scoping safety net if it's later resumed or cross-referenced.

## Prefixes

| Stage(s) | prefix | notes |
|---|---|---|
| ac-implement **+** ac-land (shared bead-work session) | `bead-work` | keyed on the claim id (bd-u2lo1.9 re-keying) **plus a per-CHILD id** — `/tmp/bead-work-<claim-id>-<AGENT_NAME>-<pid>[-<run-id>]`, the child key computed by the child and applied UNCONDITIONALLY, never conditioned on the child knowing whether it is one of N (ac-wno). `RUN_ID` still trails LAST so ac-land's `/tmp/bead-work-*-$RUN_ID` glob keeps gathering every child of the run. Derivation: `ac-implement/SKILL.md` Phase 0 § Configuration. Proof: `ac-pipeline/scripts/bead-work-concurrent-dir.test.sh` |
| ac-review | `work-review` | keyed on a timestamp, not the claim id or branch — a review spans a batch **diff range** since the last review-mark, not a single claimed batch, so it never had a branch-collapse problem to fix |
| ac-batch-close (trunk-direct batch closing ceremony) | `batch-close` | keyed on the batch-anchor SHA (`ac-batch-close/SKILL.md` Phase 0) |
| ac-plan-init | `plan-init` | keyed on the plan slug — under trunk-direct there is no wave to key on, ever (no branch, no waiting for one to open); the plan slug is the permanent key here, not a placeholder "until a wave exists" |
| ac-qa-browser | `qa-browser` | |
| ac-qa-device | `qa-device` | |
| ac-ui-polish | `ui-polish` | |
| ac-bead-refine | `bead-refine` | keyed on a **per-CHILD** id — `<AGENT_NAME>-$$`, computed by the child, never accepted from the caller (bd-baudw). **The same corollary binds `bead-work`, and binds it UNCONDITIONALLY** (ac-wno: two implement children over ONE claimed batch derived the identical `/tmp/bead-work-<claim-id>-<RUN_ID>` and collided on progress.md — benign only by timing): EVERY implement child computes its own `<AGENT_NAME>-$$` key and inserts it BEFORE the RUN_ID suffix, whether or not the delegation prompt told it that it was fanned out — a child under context pressure failing to self-identify as one of N is precisely what produced that collision, so the safety may not be conditioned on it. This stage is fanned out: `ac-loop` runs up to `PARALLEL_WIDTH` refine children on disjoint bead subsets and hands them all the SAME `RUN_ID` **and** the same claim id, so neither key discriminates siblings — they collapsed onto one dir and clobbered each other's `beads-snapshot.json`, making a child stamp `refined` onto beads it never reviewed. `RUN_ID` still trails (`/tmp/bead-refine-<child-id>-<run-id>`) so the run-scoped glob keeps working. Proof: `ac-pipeline/scripts/bead-refine-concurrent-dir.test.sh` (sibling proof for the generic prefix formula: `ac-pipeline/scripts/run-id-concurrent-dir.test.sh`) |

> **Fan-out corollary (general).** The claim-id key is **batch-scoped** and `RUN_ID` is
> **run-scoped** — neither is child-scoped. Any stage a conductor fans out over subsets of
> one batch must add a discriminator the child computes for itself (Agent Mail identity
> and/or `$$`). Suffixing `RUN_ID` per child in the delegation prompt is **not** the fix:
> it is un-enforceable (the next conductor forgets), and it breaks the `-$RUN_ID` glob
> ac-land relies on.

`ac-merge` — the legacy branch path only (`.claude/legacy-branches.txt` projects: dependabot,
human feature branches) — still keys its `wave-merge` prefix on an actual wave/feature branch
slug. That's correct there and is deliberately untouched by this re-keying: it's a different,
still-live code path with a real branch to key on, not a stale reference.

## Dual-mode

- **Standalone (human):** one session, one claimed batch → `RUN_ID` absent (or minted locally
  per the mint-if-absent rule above) → `/tmp/bead-work-bd-u2lo1.1-<AGENT_NAME>-<pid>-20260712`
  (the per-child key is unconditional — a lone session carries it too).
- **In ac-loop, single session per batch (the common case):** identical — the claim id suffices,
  no cross-session disambiguation needed. `RUN_ID` is still minted at ac-loop's own Phase 0 and
  threaded through, purely for the loop-exit scoping job (below).
- **In ac-loop, parallel children on one batch (width >1):** ac-loop does **NOT** supply a
  distinct `RUN_ID` per child — `ac-loop/SKILL.md` Phase 0 mints exactly ONE `RUN_ID` per run
  and threads it verbatim into every child, by design (it identifies the run, not the child).
  Disambiguation is therefore the **child's** job, via the fan-out corollary above; a stage
  that assumes RUN_ID separates its siblings is assuming something ac-loop never promised
  (this stale assumption is what hid bd-baudw).

## The ac-land exception (a consumer that can't self-derive)

ac-land runs **at loop-exit, after the final batch-close** — by then the claiming session may be
long gone and ac-land itself never claimed anything, so it **cannot mint or independently
recompute a claim id.** This is precisely why it used to glob. Resolution order for ac-land:

1. **RUN_ID scopes it (loop exit).** ac-loop passes `RUN_ID`; ac-land gathers **all** of this
   run's dirs with the scoped glob `/tmp/bead-work-*-$RUN_ID` — safe because RUN_ID excludes
   foreign/stale dirs. The retrospective spans every batch the run shipped; teardown sweeps them.
   A single-batch run yields one dir on the same code path.
2. **Handed `ARTIFACTS_DIR` (single bead-work session, no RUN_ID)** — use verbatim.
3. **Last resort only:** neither available → newest `/tmp/bead-work-*` dir, with a logged warning
   that the dir was guessed. Never the primary path. There is no branch-based fallback step —
   trunk-direct means `main` is always there, so a "standalone session still sitting on the wave
   branch" case can no longer occur; that dead fallback was removed outright, not left dormant.

> Invariant: the dir is always `/tmp/<prefix>-<claim-id>[-<run-id>]`, every term computed, handed
> in, or (for ac-land only, as a genuine last resort) guessed with a logged warning — never
> silently discovered by scanning `/tmp`. The old "detect parallel `*-$$` dirs" heuristic is
> retired, and the wrong-dir bug class with it.
