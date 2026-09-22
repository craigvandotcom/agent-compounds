---
name: spawn-prompt-is-a-snapshot-spawn-after-sweep
description: a spawned worker's pasted prompt is a SNAPSHOT of worker.md taken at paste time — mid-run skill edits make later spawns carry stale canon (a stale §8 cost two workers a confusion read); and a conductor that spawns before its refly sweep completes idles a worker on a stamped-bead pool
metadata:
  type: fact
  domain: neometa
  evidence: "RUN acr-narrowing-w1 2026-09-22 (agent-compounds): bead aq10.2 rewrote ac-implement/references/worker.md §8 mid-run; two later worker spawns still carried the pre-aq10.2 §8 text (stale REVIEW: APPROVED demand) — both workers correctly followed the live file, so realized waste was one confusion read each; separately the conductor spawned worker C before running refly on a freshly premise-stamped key bead, idling it ~5 min."
  kind: loop-retro-observation
  stage: implement
  cost: minor
  first_seen: 2026-09-22
  recurrence: 1
tags: [ac-implement, spawn, snapshot, refly, worker-prompt, ac-loop]
---

The worker prompt is pasted verbatim at spawn, so it is a snapshot of `references/worker.md`
at that moment. Two corollaries:

- **Spawn after the sweep, never before.** A conductor that spawns while a PREMISE-FAILED
  prefix still sits on the pool's key bead idles the worker — the pool is frozen until
  `refly.sh` strips the stamp. Run Phase 0's refly sweep, verify the pool, THEN spawn.
- **A prompt may be stale; the live file is canon.** When a run's own beads edit the skill
  the worker prompt pastes (a self-referential wave — e.g. an epic that rewrites worker.md),
  later spawns carry the pre-edit text. Workers that re-read the live file once before
  their first §8 route waste one read; workers that trust the paste can do wrong work.
  The prompt already carries the re-read rule — keep it there.
