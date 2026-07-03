# Feedback Write-back Hook (post-build-bump)

**Bead:** bd-vbmre.16 · **Hook site:** ac-merge Phase 0, immediately after "Commit the bump"

Closes the in-app feedback loop: when a wave merges and a `triage,feedback` bead ships,
this hook writes `status='fixed'` + `fixed_in_build=<build>` back to the originating
`public.feedback_reports` row so the user's client can pick it up on the next resume poll
and deliver a "fixed in build N" local notification.

This is net-new in agent-compounds — ac-merge/ac-land today only check/close beads; they
never write external rows. This hook is the first cross-system write-back in the pipeline.

---

## Why post-build-bump (not ac-land, not ac-distribute)

`fixed_in_build` needs the NEW build number — the monotonic integer incremented in the
"Version Bump" step of Phase 0. If the hook ran in ac-land (session closure, pre-merge),
the build number would be the stale prior value. ac-distribute is the distribution lane;
the hook's responsibility is "this build was produced by this merge" — that's the merge's
job, not the distributor's.

Sequence in Phase 0:

```
version bump (pnpm version ...) →
propagate to pbxproj (MARKETING_VERSION + CURRENT_PROJECT_VERSION = NEW_BUILD) →
commit the bump →
[THIS HOOK] write-back for triage,feedback beads →
push →
PR creation
```

---

## Prerequisites

- `NEW_BUILD` (integer): set in Phase 0 Version Bump from `CURRENT_PROJECT_VERSION + 1`.
  Available as a shell variable in the same Phase 0 context.
- `SUPABASE_SERVICE_ROLE_KEY` + Supabase project URL: from the app's env (`.env.local` for
  BCA; pointer is `supabase.md` in the app's CORE). Service-role bypasses RLS.
- `br` CLI authenticated (same session as the rest of ac-merge).

---

## Method

### Step 1 — Find triage,feedback beads that were closed in this wave

```bash
WAVE_BEADS=$(br list --json \
  | jq '[.issues[] \
    | select((.labels // []) | (index("triage") and index("feedback"))) \
    | select(.status == "closed")]')
```

If `WAVE_BEADS` is empty (`[]`), log "no triage,feedback beads in this wave — skip" and
exit the hook cleanly.

### Step 2 — For each bead, resolve the linked source row

For each bead in `WAVE_BEADS`:

1. Extract `linked_bead` from the bead's description or a dedicated field. The ac-triage
   feedback adapter writes the source row id into the bead description as:
   `Source: public.feedback_reports / id=<uuid>`. Parse it:

   ```bash
   SOURCE_ROW_ID=$(echo "<bead description>" | grep -oP 'id=\K[0-9a-f-]{36}')
   ```

2. If `SOURCE_ROW_ID` is empty or not a valid UUID: log a warning
   `"bead <bead-id>: linked_bead not found in description — skipping write-back"` and
   continue to the next bead. Do NOT abort the merge.

### Step 3 — Write status='fixed' + fixed_in_build to the source row

```sql
UPDATE public.feedback_reports
SET status         = 'fixed',
    fixed_in_build = '<NEW_BUILD>'
WHERE id           = '<SOURCE_ROW_ID>'
  AND linked_bead IS NOT NULL
```

The `AND linked_bead IS NOT NULL` guard ensures the row was properly claimed by ac-triage
before we mark it fixed; an unclaimed row would indicate a data inconsistency.

**Execution via service-role REST (no psql available in headless env):**

```bash
curl -s -X PATCH \
  "${SUPABASE_URL}/rest/v1/feedback_reports?id=eq.${SOURCE_ROW_ID}&linked_bead=not.is.null&schema=bca" \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{\"status\": \"fixed\", \"fixed_in_build\": \"${NEW_BUILD}\"}"
```

Or via the Supabase JS admin client if available in the triage runtime:

```typescript
const { error } = await adminClient
  .schema('bca')
  .from('feedback_reports')
  .update({ status: 'fixed', fixed_in_build: String(NEW_BUILD) })
  .eq('id', sourceRowId)
  .not('linked_bead', 'is', null);
```

### Step 4 — Handle failures

- If the UPDATE returns 0 rows updated: log `"write-back: row <id> not found or already fixed"`. Continue.
- If the UPDATE errors (network, auth): log the error. Do NOT abort the merge. The row
  remains at `status='triaged'`; the next triage run will not re-import it (linked_bead is
  set), but the user will not receive a notification until a manual correction or a re-run
  of this step (acceptable — merge integrity takes priority over notification delivery).

### Step 5 — Report

Log in the Phase 4 merge report:

```
Feedback write-back: <N> rows updated (status=fixed, fixed_in_build=<NEW_BUILD>)
  <N> warnings (missing linked_bead or row not found — see log)
```

---

## Build number for web-only waves

If the wave has no iOS pbxproj changes (web-only project, or "skip — no bump" chosen),
`NEW_BUILD` is not defined as an integer. Use the semver string `NEW_VERSION` instead:

```
fixed_in_build = 'v1.3.0'   (string, matches what the JS client reads from getBuildInfo())
```

The client's loop-back poll compares `fixed_in_build` as a string — any non-empty value
triggers a "fixed" notification. Document the string format per project.

---

## Unit test cases (consuming app: `__tests__/unit/merge-feedback-writeback.test.ts`)

These cases must ALL pass before this hook ships in a wave. Reference this spec when
authoring the tests in body-compass-app.

### (a) Merged triage,feedback bead → source row updated to status='fixed' + fixed_in_build set

**Setup:**
- One closed bead with labels `['triage', 'feedback']`.
- Bead description contains `Source: public.feedback_reports / id=<uuid>`.
- Source row in `public.feedback_reports` has `linked_bead` set (claimed), `status='triaged'`.
- `NEW_BUILD = 17`.

**Expected behavior:**
- Service-role UPDATE called with `{ status: 'fixed', fixed_in_build: '17' }` for the correct row id.
- UPDATE is NOT called for rows where `linked_bead IS NULL`.
- Phase 4 report shows `Feedback write-back: 1 rows updated`.

### (b) Wave with no triage,feedback beads → hook exits silently, no UPDATE

**Setup:** Wave beads have labels `['triage', 'sentry']` only (no `feedback` label).

**Expected behavior:**
- Hook executes with zero iterations.
- No UPDATE call issued.
- Report shows `Feedback write-back: 0 rows updated`.

### (c) Bead with missing linked_bead in description → warning logged, no UPDATE, merge continues

**Setup:**
- One closed bead with labels `['triage', 'feedback']`.
- Bead description does NOT contain a parseable `id=<uuid>` line.

**Expected behavior:**
- Warning logged: `"bead <id>: linked_bead not found in description — skipping write-back"`.
- No UPDATE call issued.
- Hook returns without error (merge is not aborted).

### (d) UPDATE returns 0 rows (row not found or already fixed) → warning logged, merge continues

**Setup:**
- Bead resolves to a `SOURCE_ROW_ID` that does not exist in the table (e.g. row was deleted).

**Expected behavior:**
- UPDATE executed but affects 0 rows.
- Warning logged: `"write-back: row <id> not found or already fixed"`.
- No exception thrown; merge continues normally.

---

## Cross-reference

- Source adapter spec: `ac-triage/references/feedback-adapter.md`
- BCA triage source registration: `body-compass-app/.claude/skills/CORE/triage.md` (source #6)
- Data model: `public.feedback_reports` — schema in the feedback-loop plan (`_plans/_done/2026-06-20-1734-feedback-learning-loop.md`)
- Client loop-back delivery: `features/feedback/lib/loopback.ts` in body-compass-app
