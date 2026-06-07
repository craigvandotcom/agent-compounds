# Distribution-Stage Discipline (MEDIUM-HIGH)

Per `software/CLAUDE.md` and `alignment/distribution-philosophy.md`, work sequences by distribution stage. **Don't pre-build for later stages** — that's how solo-built apps die under their own complexity before getting a single user.

The patterns below are tempting from day one but are **canonical Stage 3-4 infrastructure**. Only reach for them when cohort signal validates the pain:

| Pattern                                | Earliest stage to build     | Trigger to reactivate                                               |
| -------------------------------------- | --------------------------- | ------------------------------------------------------------------- |
| IndexedDB local-first + sync engine    | Stage 3                     | ≥10 WAU report concrete offline-write pain OR cold-cache >300ms P50 |
| Dead-letter queue for sync failures    | Stage 3                     | Real-world data shows constraint drift fires often enough           |
| `_wipe_intent` ledger + resume-on-boot | Stage 3                     | Sub-second kill mid-wipe becomes a real reported issue              |
| IDB epoch + backfill-on-eviction       | Stage 3                     | Eviction proves real in cohort telemetry                            |
| Background fetch / periodic sync       | Stage 3+ (and never on iOS) | Apple-review battery scrutiny worth the cost                        |
| Affiliate / partner dashboards         | Stage 3                     | Active creator deals in flight                                      |
| Custom analytics / observability       | Stage 2+                    | Manual measurement no longer scales                                 |

**At Stage 0–1**, the right Capacitor "feels native" surface area is:

1. The cold-start auth bootstrap (`cold-start-auth.md`) — kills the worst visible bug.
2. Optimistic writes on top of server-first (`optimistic-writes.md`) — delivers ~70% of the perceived "app feel" gain at ~40% of the work.
3. Native polish: haptics, page transitions, swipe-to-delete, pull-to-refresh, keyboard avoidance, 44pt touch targets, `:hover` suppression in native build, `App.resume` SWR refetch.

That's it. If you find yourself designing a sync queue + DLQ + wipe ledger at Stage 0, **stop** — you're solving a problem you don't have yet.

## IndexedDB delete blocks indefinitely (when you eventually ship it)

When/if Stage 3 work activates IDB, this is the one trap that bites everybody:

```typescript
// indexedDB.deleteDatabase BLOCKS indefinitely if any other connection holds the DB.
// Module-scope handles, service workers — anything.
async function wipeIDB() {
  await idbAdapter.closeAll(); // close all known module-scope connections first
  return new Promise(resolve => {
    const req = indexedDB.deleteDatabase('app-db');
    req.onsuccess = resolve;
    req.onblocked = () => {
      // Don't hang forever — log + continue. Orphan DB cleans up on next boot.
      setTimeout(() => {
        Sentry.captureMessage('IDB delete blocked');
        resolve();
      }, 2000);
    };
  });
}
```

Without `closeAll()`, the delete sits there forever; without the `onblocked` timeout, your sign-out flow deadlocks.
