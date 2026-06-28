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

## RUN_ID: only for parallel sessions on the SAME wave

The wave slug disambiguates *different waves*. It does **not** disambiguate two sessions working
the *same* wave concurrently (both would compute `/tmp/bead-work-wave-004`). That is the only
case needing more — and only an **orchestrator** knows it is spawning parallel work, so it
supplies the discriminator:

- The orchestrator (ac-loop) mints `RUN_ID` and passes it in the delegation prompt (`RUN_ID=<id>`)
  to each session in a parallel set. Readable, collision-free: `RUN_ID="$(date +%H%M%S)-$$"`.
- `${RUN_ID:+-$RUN_ID}` appends it when present, nothing when absent.
- A consumer (ac-land) that must read a specific parallel session's dir is handed the **same
  RUN_ID** in its delegation prompt — so it lands the right session, deterministically.

## Prefixes

| Stage(s) | prefix |
|---|---|
| ac-implement **+** ac-land (shared bead-work session) | `bead-work` |
| ac-review | `work-review` |
| ac-merge | `wave-merge` |
| ac-plan-init | `plan-init` (no wave yet → use the plan slug as the key) |

## Dual-mode

- **Standalone (human):** one session, one wave → `RUN_ID` absent → `/tmp/bead-work-wave-004`.
- **In ac-loop, single session per wave (the common case):** identical — the wave slug suffices,
  no RUN_ID needed.
- **In ac-loop, parallel sessions on one wave:** ac-loop supplies a distinct `RUN_ID` per session.

## The ac-land exception (a consumer that can't self-derive)

ac-land runs **at loop-exit, after the final merge** — by then ac-merge has switched to `main`
and deleted the wave branch, so ac-land **cannot derive the wave slug from the current branch.**
This is precisely why it used to glob. Resolution order for ac-land:

1. **Handed key wins.** The orchestrator MUST pass ac-land the dir(s) it should land —
   `ARTIFACTS_DIR=/tmp/bead-work-<wave-slug>[-<run-id>]` in the delegation prompt. ac-land uses
   it verbatim. (When a loop shipped multiple waves, ac-loop hands the set; see the open
   consolidation question in ac-loop.)
2. **Standalone fallback:** no key handed AND still on the wave branch (land run directly after
   implement) → derive `/tmp/bead-work-$(git branch --show-current | tr '/' '-')`.
3. **Last resort only:** neither available → newest `/tmp/bead-work-*` dir, with a logged warning
   that the dir was guessed. Never the primary path.

> Invariant: the dir is always `/tmp/<prefix>-<wave-slug>[-<run-id>]`, every term computed or
> handed in — never discovered by scanning `/tmp`. The old "detect parallel `*-$$` dirs"
> heuristic is retired, and the wrong-dir bug class with it.
