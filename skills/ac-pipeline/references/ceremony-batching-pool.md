# Ceremony batching pool — mechanics (bd-chd5p.2)

Shared reference for **`ac-loop`** (owns per-close append + idle-drain) and **`ac-batch-close`**
(owns report-commit ack + drain). `ac-loop` SKILL.md § Ceremony batching pool holds the engagement
summary + hookpoints (the *when*); this file holds the full mechanics (the *how*). Read this before
executing any pool RMW / drain.

## ToC
- Pool state store (JSON shape)
- Concurrency (flock RMW)
- Fire opportunities · Selected set · Fire snapshot
- Report-commit ack · Ceremony failure · Drain sequence
- Risk override · Bug lane reconciled · Guard-rail · Refine-during-ceremony guard-rails · Fixtures

## Pool state store

```text
/tmp/loop-pool-<RUN_ID>.json     # RUN-scoped per ac-pipeline/references/run-id.md
                                 # NOT batch-close's per-anchor ARTIFACTS_DIR
```

**JSON shape:**

```json
{
  "pending":    [{ "bead_id": "bd-…", "pre_sha": "…", "close_sha": "…", "closed_at": "ISO-8601" }],
  "in_flight":  [{ "bead_id": "bd-…", "pre_sha": "…", "close_sha": "…", "closed_at": "ISO-8601" }],
  "risk_queue": [{ "bead_id": "bd-…", "pre_sha": "…", "close_sha": "…", "closed_at": "ISO-8601" }]
}
```

- `risk_queue` is durable and **never** merges into `pending`/`in_flight`.
- **count** = distinct IDs in `pending`; **first_close_ts** = `min(closed_at)` over
  `pending`; recompute after every mutation including failure re-merge.

## Concurrency (flock RMW)

Under single-conductor fan-out, any close writer may RMW the pool only while holding
`flock` on the pool file. Hold flock **only for the RMW** (not multi-minute CI).
Mid-ceremony closes land in `pending` or `risk_queue` only.

## Fire opportunities (when `in_flight` empty)

Fire when **ANY** of:

1. **soft-8:** `pending` count ≥ 8 (opportunity threshold)
2. **window:** `now - first_close_ts` ≥ ~3h
3. **line-floor:** cumulative changed-lines over the **selected drain prefix** exceeds
   **N ≈ 800** (absolute floor; tune later)

**hard-10** is the batch-size **ceiling** on the selected set, **not** a separate
opportunity trigger (soft-8 always fires first when `in_flight` is empty).

**Mutex:** if `in_flight` is non-empty, **do not fire again** — only append to
`pending` or `risk_queue`; re-evaluate only via the post-ack drain hook.

## Selected set (drain policy)

FIFO by `closed_at`; take the longest prefix of `pending` with **at most 10 beads**
whose cumulative changed-lines ≤ N≈800 (if the first bead alone exceeds N, take it
alone — hard-10 still caps count). That prefix is the selected set moved to
`in_flight`.

**Line-floor range** = union of selected members' stored `pre_sha..close_sha`
(`ac-pipeline/references/risk-classification.md` binding #2) — **not** raw
`<last-ceremony-anchor>..HEAD`.

## Fire snapshot

Under flock, only if `in_flight` empty: move selected set `pending` → `in_flight`;
never assign-overwrite non-empty `in_flight`; recompute `first_close_ts` from remaining
`pending`.

## Report-commit ack (ac-batch-close)

Remove **only this batch's `in_flight` IDs**. Never whole-file wipe. Non-pool
ceremonies (planned-wave, pure risk-solo with no snapshot) must not clear
`pending`/`in_flight`/`risk_queue` except as post-ack drain defines.

## Ceremony failure

Re-merge `in_flight` → `pending` (do not drop IDs); recompute
`first_close_ts = min(closed_at)`.

## Drain sequence

After ack, failure re-merge, or pre-cycle when idle — under flock, while `in_flight`
empty:

1. if `risk_queue` non-empty → dequeue FIFO head as risk sidecar; if `pending`
   non-empty also take selected set → `in_flight` and fire **mixed**; else fire
   **pure risk-solo**
2. else if any pool fire opportunity → selected set → `in_flight` → fire pool-only
3. else stop

## Risk override (binding #3)

Never add a risk bead to `pending`/`in_flight`. If `in_flight` empty → fire
immediately (same as drain step 1); if `in_flight` non-empty → append `risk_queue`
FIFO. Mixed range = union(`in_flight` ranges ∪ risk `pre_sha..close_sha`). Failure
re-merges only `in_flight`; risk never re-enters `pending`.

## Bug lane reconciled

Folding bug drain into the next cycle's **close ceremony** (CI + review-mark + report
only) is permitted; folding bug **implement** into a feature wave remains
**FORBIDDEN** (Rule 0 unchanged on implement fold).

## GUARD-RAIL

Per-cycle ac-review remains **unbatched**. Bisection cost capped by selected-set
(≤10 beads + line-floor).

## Refine-during-ceremony guard-rails

<!-- net-growth-ok: guard-rails extracted from ac-loop core (ac-znk.3) -->

Binding whenever refine children run concurrently with a ceremony (phase-pipelining
permissions, `ac-loop` § Phase pipelining permissions).

**Git ledger commit (mixed-state sanctioned).** The **ceremony** commits whatever
`.beads/issues.jsonl` state exists at report-commit time; refine children **never**
commit the ledger. Mixed-state commits are explicitly sanctioned — a ceremony may land
a ledger that includes labels/comments written by a concurrent refine child that
already flushed; that is expected and correct.

**Beads-DB mutation deferral (not merely flush).** `br` mutation verbs (`br update` /
`br close` / `br label` / `br comments add`) auto-flush to `.beads/issues.jsonl`. A
refine child running concurrently with a ceremony **defers its beads-DB MUTATIONS
entirely** until the ceremony's ledger commit has landed (not merely deferring
`br sync --flush-only`). The conductor owns the final flush+commit; children may
**read** the DB freely but **hold all writes** until the ceremony quiesces (or the
conductor re-flushes + re-commits after children quiesce). Memory:
`beads-ledger-shared-file-conductor-should-own-final-commit`.

## §5 fixtures (quick reference)

| Scenario | Expected |
| -------- | -------- |
| Fire only when `in_flight` empty | mutex holds |
| Fire moves `pending` → `in_flight` | snapshot under flock |
| Report-commit removes only `in_flight` | never whole-file wipe |
| Non-pool ceremony | leaves pool intact |
| Mid-ceremony close | lands in `pending` (or `risk_queue`) |
| Failure re-merge | restores `closed_at` window |
| Line-floor | union of members' `pre_sha..close_sha` |
| Risk | sidecar — never in `pending`/`in_flight` |
| Per-close classify | bead's own `pre_sha..close_sha`, not `..HEAD` |
| `features/**/__tests__/**`-only | ZERO-RUNTIME / not RISK-TOUCH (Item 0 test-path exclusion) |
