# ac-loop — run carrier schema

The single per-run artifact the conductor writes to `/tmp/loop-retro-<RUN_ID>.md` before the
Exit-Land spawn. `ac-land` consumes it; `reflect` receives it as a literal path.

## Telemetry header — always present

```
width: requested=<N> peak=<M> idle-slots=<K>
idle-reason: <token>          # only when K>0; one of the closed set below
ceremony: <claim-id> <passes-run>    # one line per ceremony
```

- `requested` — the width the Phase-0 prompt settled on for this run.
- `peak` — the most children in flight at one moment, from the conductor's own dispatch
  record. Never the requested width.
- `idle-slots` — `requested - peak`. A run that never filled its width reports it here.
- `idle-reason` — closed set: `no-disjoint-work` · `resource-contention` · `machine-cap` ·
  `queue-empty`. An unexplained idle slot cannot drive a ramp decision.
- `ceremony` — one line each. A risk-carve-out solo names its trigger class
  (`migration` · `native` · `auth` · `persistence`).

## Friction sections — conditional

One `## <stage>` section per stage that ran AND returned ≥1 friction item, each child's
`friction:` items listed under it. A stage returning only `friction: []` is omitted, so a
clean run yields a header-only carrier.

## Worked example — clean run at width 2

```
width: requested=2 peak=2 idle-slots=0
ceremony: bd-u2lo1.1-20260807 qa-browser:smoke
```

## Worked example — width never reached

```
width: requested=3 peak=1 idle-slots=2
idle-reason: no-disjoint-work
ceremony: bd-x4kp2.1-20260807 ui-polish:scoped,qa-browser:smoke
ceremony: bd-m9qr7.2-20260807 qa-device:smoke   # risk solo: native
```

This second shape is the one that answers "is the dial too low, or is the work shape
wrong?" — the question the ramp decision could not previously ask.
