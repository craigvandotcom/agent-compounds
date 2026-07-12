# Feedback Write-back Hook (post-build-bump / two-phase)

**Beads:** bd-vbmre.16 (original one-shot) · bd-pwt44.3 (two-phase pending-write, batch-close
side) · bd-pwt44.6 (finalize-at-publish, deferred/not yet landed)

**Hook sites (two, one per model):**
- **Legacy one-shot** — `ac-merge` Phase 0, immediately after "Commit the bump" (PR-merge path,
  dependabot/human legacy branches — unchanged, still in use).
- **Two-phase (trunk-direct)** — `ac-batch-close` Act 3 (pending-write) + `ac-publish` Phase 0/4
  mint (finalize — bd-pwt44.6, not yet implemented as of this doc revision).

Closes the in-app feedback loop: when a `triage,feedback` bead ships, this hook writes back to
the originating `public.feedback_reports` row so the user's client can pick it up on the next
resume poll and deliver a "fixed in build N" local notification.

This is net-new in agent-compounds — ac-merge/ac-land today only check/close beads; they
never write external rows. This hook is the first cross-system write-back in the pipeline.

---

## Two models, same table, different timing

**Table:** `public.feedback_reports` (moved out of the `bca` schema —
`20260703161500_feedback_reports_move_to_public.sql`; memory
`bca-tables-public-schema-curate-psql-access`). `status` is an unconstrained
`TEXT NOT NULL DEFAULT 'submitted'` column, server/service_role-owned — **no migration is
needed** to introduce a new status value.

**Client trigger:** `features/feedback/lib/loopback.ts:190`,
`isNowFixed = row.status === 'fixed'`. The client fires the user-facing "fixed in build N"
notification the **instant** `status` becomes exactly the string `'fixed'`. This is the one
constraint every write path below has to respect: never write the literal `'fixed'` until a
real build number exists to attach to it.

### Model A — Legacy one-shot (`ac-merge`, PR-merge path — unchanged)

`ac-merge` has a version bump baked into the same merge that closes the bead, so it can write
the final state in one step: `status='fixed'` + `fixed_in_build=<NEW_BUILD>`. This is
`runFeedbackWritebackHook` in the implementation module (unchanged by bd-pwt44.3 — see
Implementation below).

### Model B — Two-phase (trunk-direct: `ac-batch-close` + `ac-publish`)

Under trunk-direct, `ac-batch-close` no longer bumps a version (that moved to `ac-publish`
Phase 0, mint-at-publish — `version-bump-defaults-to-patch`). A batch-close ceremony therefore
has **no build number** at the moment its `triage,feedback` beads close. Writing `'fixed'` here
would fire the client notification weeks early, with a null/placeholder build. So the write-back
splits into two phases:

- **Phase 1 — pending (bd-pwt44.3, THIS is what ships in `ac-batch-close` Act 3):** write
  `status='fixed_pending_release'`, leave `fixed_in_build` NULL. This value is deliberately NOT
  `'fixed'`, so `loopback.ts`'s `isNowFixed` check does not match — no notification fires, no
  client code change is required. Implementation: `runFeedbackPendingWriteHook`.
- **Phase 2 — finalize (bd-pwt44.6, DEFERRED — not implemented as of this doc revision):** at
  `ac-publish`, once a real release version/build number is minted, sweep every row with
  `status='fixed_pending_release'` (a state-based query, not a time-window one — a time-window
  cutoff could orphan rows accumulated across multiple batches) and write
  `status='fixed'` + `fixed_in_build=<the minted version>`. THIS is the write that fires the
  client's notification, now correctly timed at ship with a real build number. Not built yet;
  do not assume it exists.

Both phases share the same never-abort-on-write-failure policy and the same bead-filtering/
row-resolution mechanics as Model A — only the target `status` value (and whether
`fixed_in_build` is set) differs.

---

## Why post-build-bump / post-mint (not ac-land, not ac-distribute)

`fixed_in_build` needs a real build number. For Model A that's the monotonic integer
incremented in ac-merge's own "Version Bump" step (Phase 0) — if the hook ran in ac-land
(session closure, pre-merge) the build number would be the stale prior value. For Model B,
there IS no build number at batch-close time at all (mint moved to `ac-publish`), which is
exactly why batch-close can only do the pending half. ac-distribute is the distribution lane;
"this build was produced by this merge/publish" is the merge's/publish's job, not the
distributor's.

Model A sequence (`ac-merge` Phase 0, unchanged):

```
version bump (pnpm version ...) →
propagate to pbxproj (MARKETING_VERSION + CURRENT_PROJECT_VERSION = NEW_BUILD) →
commit the bump →
[HOOK] runFeedbackWritebackHook — one-shot fixed + fixed_in_build →
push →
PR creation
```

Model B sequence (`ac-batch-close` Act 3, then later `ac-publish`):

```
ac-batch-close Act 1 (CI dispatch) → Act 2 (light review) →
Act 3: [HOOK] runFeedbackPendingWriteHook — fixed_pending_release, no build →
        commit + push the batch report
  ... (time passes, more batches, no build number exists yet) ...
ac-publish Phase 0 (mint R) → ... → [HOOK, bd-pwt44.6, not yet built] finalize sweep:
        fixed_pending_release rows → fixed + fixed_in_build=R's version
```

---

## Method (both phases share Steps 1-2; diverge at Step 3)

### Step 1 — Find triage,feedback beads that were closed (this batch / this wave)

```bash
CANDIDATE_BEADS=$(br list --json \
  | jq '[.issues[] \
    | select((.labels // []) | (index("triage") and index("feedback"))) \
    | select(.status == "closed")]')
```

If `CANDIDATE_BEADS` is empty (`[]`), log "no triage,feedback beads in this batch — skip" and
exit the hook cleanly.

### Step 2 — For each bead, resolve the linked source row

For each bead in `CANDIDATE_BEADS`:

1. Extract `linked_bead` from the bead's description or a dedicated field. The ac-triage
   feedback adapter writes the source row id into the bead description as:
   `Source: public.feedback_reports / id=<uuid>`. Parse it:

   ```bash
   SOURCE_ROW_ID=$(echo "<bead description>" | grep -oP 'id=\K[0-9a-f-]{36}')
   ```

2. If `SOURCE_ROW_ID` is empty or not a valid UUID: log a warning
   `"bead <bead-id>: linked_bead not found in description — skipping write-back"` and
   continue to the next bead. Do NOT abort the batch-close/merge.

### Step 3 — Write the phase-appropriate patch to the source row

**Model A (legacy one-shot, `runFeedbackWritebackHook`):**

```sql
UPDATE public.feedback_reports
SET status         = 'fixed',
    fixed_in_build = '<NEW_BUILD>'
WHERE id           = '<SOURCE_ROW_ID>'
  AND linked_bead IS NOT NULL
```

**Model B Phase 1 (`ac-batch-close`, `runFeedbackPendingWriteHook`):**

```sql
UPDATE public.feedback_reports
SET status         = 'fixed_pending_release'
WHERE id           = '<SOURCE_ROW_ID>'
  AND linked_bead IS NOT NULL
```

**Model B Phase 2 (`ac-publish`, bd-pwt44.6 — NOT YET IMPLEMENTED, spec for the future bead):**

```sql
UPDATE public.feedback_reports
SET status         = 'fixed',
    fixed_in_build = '<MINTED_VERSION>'
WHERE status       = 'fixed_pending_release'
```

The `AND linked_bead IS NOT NULL` guard (Models A and B Phase 1) ensures the row was properly
claimed by ac-triage before we mark it fixed/pending; an unclaimed row would indicate a data
inconsistency. Model B Phase 2's sweep is state-based (`WHERE status='fixed_pending_release'`)
rather than scoped to a single wave/batch, since pending rows can accumulate across several
batch-closes before the next publish.

**Execution via service-role REST (no psql available in headless env) — Model A shown, Model B
Phase 1 drops the `fixed_in_build` field from the body:**

```bash
curl -s -X PATCH \
  "${SUPABASE_URL}/rest/v1/feedback_reports?id=eq.${SOURCE_ROW_ID}&linked_bead=not.is.null" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{\"status\": \"fixed\", \"fixed_in_build\": \"${NEW_BUILD}\"}"
```

Or via the Supabase JS admin client if available in the runtime:

```typescript
const { error } = await adminClient
  .from('feedback_reports')
  .update({ status: 'fixed', fixed_in_build: String(NEW_BUILD) }) // Model A
  // .update({ status: 'fixed_pending_release' })                 // Model B Phase 1
  .eq('id', sourceRowId)
  .not('linked_bead', 'is', null);
```

### Step 4 — Handle failures

- If the UPDATE returns 0 rows updated: log `"write-back: row <id> not found or already fixed"`. Continue.
- If the UPDATE errors (network, auth): log the error. Do NOT abort the batch-close/merge. The
  row remains at its prior status; the next triage run will not re-import it (linked_bead is
  set), but the user will not receive a notification until a manual correction or a re-run of
  this step (acceptable — merge/batch-close integrity takes priority over notification
  delivery).

### Step 5 — Report

**Model A** (in the merge report):

```
Feedback write-back: <N> rows updated (status=fixed, fixed_in_build=<NEW_BUILD>)
  <N> warnings (missing linked_bead or row not found — see log)
```

**Model B Phase 1** (in the batch-close report):

```
Feedback pending-write: <N> rows marked fixed_pending_release
  <N> warnings (missing linked_bead or row not found — see log)
```

---

## Build number for web-only waves (Model A only)

If the wave has no iOS pbxproj changes (web-only project, or "skip — no bump" chosen),
`NEW_BUILD` is not defined as an integer. Use the semver string `NEW_VERSION` instead:

```
fixed_in_build = 'v1.3.0'   (string, matches what the JS client reads from getBuildInfo())
```

The client's loop-back poll compares `fixed_in_build` as a string — any non-empty value
triggers a "fixed" notification. Document the string format per project. Not applicable to
Model B Phase 1 (no `fixed_in_build` is written at all in that phase).

---

## Unit test cases (consuming app: `__tests__/unit/merge-feedback-writeback.test.ts`)

These cases must ALL pass before either hook ships. Reference this spec when authoring/
extending the tests in body-compass-app.

### Model A — `runFeedbackWritebackHook` (unchanged, legacy one-shot)

#### (a) Merged triage,feedback bead → source row updated to status='fixed' + fixed_in_build set

**Setup:**
- One closed bead with labels `['triage', 'feedback']`.
- Bead description contains `Source: public.feedback_reports / id=<uuid>`.
- Source row in `public.feedback_reports` has `linked_bead` set (claimed), `status='triaged'`.
- `NEW_BUILD = 17`.

**Expected behavior:**
- Service-role UPDATE called with `{ status: 'fixed', fixed_in_build: '17' }` for the correct row id.
- UPDATE is NOT called for rows where `linked_bead IS NULL`.
- Report shows `Feedback write-back: 1 rows updated`.

#### (b) Wave with no triage,feedback beads → hook exits silently, no UPDATE

**Setup:** Wave beads have labels `['triage', 'sentry']` only (no `feedback` label).

**Expected behavior:**
- Hook executes with zero iterations.
- No UPDATE call issued.
- Report shows `Feedback write-back: 0 rows updated`.

#### (c) Bead with missing linked_bead in description → warning logged, no UPDATE, merge continues

**Setup:**
- One closed bead with labels `['triage', 'feedback']`.
- Bead description does NOT contain a parseable `id=<uuid>` line.

**Expected behavior:**
- Warning logged: `"bead <id>: linked_bead not found in description — skipping write-back"`.
- No UPDATE call issued.
- Hook returns without error (merge is not aborted).

#### (d) UPDATE returns 0 rows (row not found or already fixed) → warning logged, merge continues

**Setup:**
- Bead resolves to a `SOURCE_ROW_ID` that does not exist in the table (e.g. row was deleted).

**Expected behavior:**
- UPDATE executed but affects 0 rows.
- Warning logged: `"write-back: row <id> not found or already fixed"`.
- No exception thrown; merge continues normally.

### Model B Phase 1 — `runFeedbackPendingWriteHook` (bd-pwt44.3, batch-close pending-write)

Mirrors (a)-(d) above with the phase-appropriate patch:

#### (a) Closed triage,feedback bead → source row updated to status='fixed_pending_release', NO fixed_in_build

**Setup:** same as Model A (a), no `NEW_BUILD` needed (this hook takes no build argument).

**Expected behavior:**
- Service-role UPDATE called with `{ status: 'fixed_pending_release' }` (no `fixed_in_build`
  field at all) for the correct row id.
- UPDATE is NOT called for rows outside the triage+feedback label set.

#### (b) Batch with no triage,feedback beads → hook exits silently, no UPDATE

Same as Model A (b).

#### (c) Bead with missing linked_bead in description → warning logged, no UPDATE, batch-close continues

Same as Model A (c) — never aborts the batch-close.

#### (d) UPDATE returns 0 rows → warning logged, batch-close continues, never throws

Same as Model A (d).

### Model B Phase 2 — finalize sweep (bd-pwt44.6, NOT YET IMPLEMENTED)

Out of scope for this doc revision — bd-pwt44.6 will add its own test cases for the
`WHERE status='fixed_pending_release'` sweep + `fixed_in_build` stamp when it lands.

---

## Cross-reference

- Source adapter spec: `ac-triage/references/feedback-adapter.md`
- BCA triage source registration: `body-compass-app/.claude/skills/CORE/triage.md` (source #6)
- Data model: `public.feedback_reports` — schema originated in the feedback-loop plan
  (`_plans/_done/2026-06-20-1734-feedback-learning-loop.md`), table relocated to `public` by
  `20260703161500_feedback_reports_move_to_public.sql`
- Client loop-back delivery: `features/feedback/lib/loopback.ts` in body-compass-app
- Two-phase model context: `agent-compounds/skills/ac-batch-close/SKILL.md` Act 3 (Phase 1),
  `agent-compounds/skills/ac-publish/SKILL.md` (Phase 2, once bd-pwt44.6 lands)
