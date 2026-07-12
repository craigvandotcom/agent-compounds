# Deterministic `$ARTIFACTS_DIR` — wave-slug key + run-id discriminator

Each pipeline stage keeps private scratch in `/tmp` (`$ARTIFACTS_DIR`: `progress.md`, findings,
consensus files). The rule: **a stage NEVER guesses which dir is its own.** It derives the dir
from keys it can compute, never by globbing `/tmp` and hoping (the newest-wins / "solo vs
parallel" heuristics caused real bugs — ac-land picking the wrong session's dir; ac-merge
orphaning a timestamped dir on resume).

## The key: the wave slug (already shared, already derivable)

Every stage of a wave is on the same wave branch, so the **wave slug is a deterministic shared
key needing no handshake** — both the producer (ac-implement) and the consumer (ac-land) compute
the identical dir:

```bash
WAVE_SLUG="$(git branch --show-current | tr '/' '-')"        # e.g. wave-004
ARTIFACTS_DIR="/tmp/<prefix>-${WAVE_SLUG}${RUN_ID:+-$RUN_ID}"
mkdir -p "$ARTIFACTS_DIR"
```

- **No globbing, no newest-wins, no detection.** Stable across compaction (re-derive from the
  branch). ac-land finds ac-implement's `progress.md` because they compute the same path.

## RUN_ID: the orchestrator's run scope (two jobs)

An **orchestrator always mints one `RUN_ID` per run** (ac-loop Phase 0:
`RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"`) and passes it (`RUN_ID=<id>`) to every stage it spawns.
It does two jobs:

1. **Parallel disambiguation** — two sessions on the *same* wave would otherwise both compute
   `/tmp/bead-work-wave-004`; distinct RUN_IDs keep them apart.
2. **Run scoping** — every dir this run created carries the RUN_ID suffix, so a consumer can
   safely gather *exactly this run's* dirs with a scoped glob (`/tmp/bead-work-*-$RUN_ID`),
   never a stale or foreign one. This is what lets **exit-land learn from all of a multi-wave run**.

`${RUN_ID:+-$RUN_ID}` appends it when present, nothing when absent. A standalone human run has no
RUN_ID and needs neither job (one session, one wave).

## Prefixes

| Stage(s) | prefix |
|---|---|
| ac-implement **+** ac-land (shared bead-work session) | `bead-work` |
| ac-review | `work-review` |
| ac-merge | `wave-merge` |
| ac-plan-init | `plan-init` (no wave yet → use the plan slug as the key) |
| ac-qa-browser | `qa-browser` |
| ac-qa-device | `qa-device` |
| ac-ui-polish | `ui-polish` |

## Dual-mode

- **Standalone (human):** one session, one wave → `RUN_ID` absent → `/tmp/bead-work-wave-004`.
- **In ac-loop, single session per wave (the common case):** identical — the wave slug suffices,
  no RUN_ID needed.
- **In ac-loop, parallel sessions on one wave:** ac-loop supplies a distinct `RUN_ID` per session.

## The ac-land exception (a consumer that can't self-derive)

ac-land runs **at loop-exit, after the final merge** — by then ac-merge has switched to `main`
and deleted the wave branch, so ac-land **cannot derive the wave slug from the current branch.**
This is precisely why it used to glob. Resolution order for ac-land:

1. **RUN_ID scopes it (loop exit).** ac-loop passes `RUN_ID`; ac-land gathers **all** of this
   run's wave dirs with the scoped glob `/tmp/bead-work-*-$RUN_ID` — safe because RUN_ID excludes
   foreign/stale dirs. The retrospective spans every wave the run shipped; teardown sweeps them.
   A single-wave run yields one dir on the same code path.
2. **Standalone fallback:** no key handed AND still on the wave branch (land run directly after
   implement) → derive `/tmp/bead-work-$(git branch --show-current | tr '/' '-')`.
3. **Last resort only:** neither available → newest `/tmp/bead-work-*` dir, with a logged warning
   that the dir was guessed. Never the primary path.

> Invariant: the dir is always `/tmp/<prefix>-<wave-slug>[-<run-id>]`, every term computed or
> handed in — never discovered by scanning `/tmp`. The old "detect parallel `*-$$` dirs"
> heuristic is retired, and the wrong-dir bug class with it.
