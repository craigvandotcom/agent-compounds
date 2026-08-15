# ac-loop-2 — run carrier schema

The single per-run artifact the conductor writes to `/tmp/loop-retro-<RUN_ID>.md` before the
Exit-Land spawn. `ac-land` consumes it; `reflect` receives it as a literal path.

## Telemetry header — always present, clean run included

```
phase: <name> width=<requested> peak=<M> idle-slots=<K>   # one line per phase that ran
idle-reason: <token>          # only when K>0; one of the closed set below
barrier: <name> crossed=<HH:MM> held=<Nm>                 # one line per barrier
metrics: repair=<X>% (<r>/<b>) hollow=<Y>% (<h>/<s> sampled)
risk-queue: <n> bead(s) — <migration|native>:<pass|reverted> …
```

- `width` — the conductor's pick within the phase model's band (spec 5–6, build 6–9). Not
  a free per-run dial: ac-loop-2 has no width prompt; the band is fixed by the phase model,
  and the conductor apportions it across lanes as worker budgets.
- `peak` — the most children in flight at one moment in that phase, from the conductor's own
  dispatch record. Never the requested width.
- `idle-slots` — `width - peak`. A phase that never filled its width reports it here.
- `idle-reason` — closed set: `no-disjoint-lane` · `resource-contention` · `machine-cap` ·
  `queue-empty` · `barrier-wait`. An unexplained idle slot cannot drive a ramp decision.
- `barrier` — `held` is how long the phase waited at the barrier for its last child. The
  one number that says whether barriers are costing more than the gates they replaced.
- `metrics` — `repair%` and `hollow%` with their raw fractions. **Always written**, including
  a clean run: a metric printed only when it is bad cannot show a trend.

## Friction sections — conditional

One `## <phase>` section per phase that ran AND returned ≥1 friction item, each child's
`friction:` items listed under it. A phase returning only `friction: []` is omitted, so a
clean run yields a header-only carrier and `ac-land` never parses an empty section.

## Worked example — clean cycle

```
phase: spec width=6 peak=6 idle-slots=0
phase: build width=9 peak=8 idle-slots=1
idle-reason: no-disjoint-lane
barrier: phase-1 crossed=09:12 held=0m
barrier: build crossed=11:40 held=6m
metrics: repair=7% (2/29) hollow=0% (0/6 sampled)
risk-queue: 2 bead(s) — migration:pass native:pass
```

## Worked example — converge under strain

```
phase: spec width=5 peak=5 idle-slots=0
phase: build width=9 peak=9 idle-slots=0
barrier: phase-1 crossed=14:03 held=41m
barrier: build crossed=16:55 held=22m
metrics: repair=21% (6/28) hollow=17% (1/6 sampled)
risk-queue: 1 bead(s) — migration:reverted
```

The second shape is the one the phase model exists to make legible: a `held=22m` build
barrier says the slowest lane is the ceiling, and `repair=21%` with `hollow=17%` says the
spec phase — not the build phase — is where the next cycle's pressure belongs.
