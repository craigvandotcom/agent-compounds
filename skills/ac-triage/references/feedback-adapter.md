# Feedback Reports Adapter (source #6)

**Bead:** bd-vbmre.15 · **App:** Body Compass (schema `bca`, source #6 in `CORE/triage.md`)

Adapter spec for ingesting solicited in-app feedback from `public.feedback_reports` into the
beads pipeline. Distinct from source #3 (Supabase error-log clustering) — this reads
structured reports submitted voluntarily by users via the feedback UI.

---

## DB Contract

Table: `public.feedback_reports` (Supabase project `spilwpcqjncrxptqdggn`, schema `public` — moved from `bca` 2026-07-03 (BCA bd-k1b9v): `bca` is service_role-only, clients could never INSERT)

| Column            | Type                              | Notes                                                        |
| ----------------- | --------------------------------- | ------------------------------------------------------------ |
| `id`              | uuid PK                           | Row identity — NOT used as the dedup key (see Fingerprint)   |
| `user_id`         | uuid NOT NULL                     | RLS anchor; part of the dedup fingerprint                    |
| `category`        | text ('bug','feature','other')    | Drives the evidence-guard and bead type                      |
| `severity`        | text NULL                         | Bug path only                                                |
| `message`         | text                              | Part of the dedup fingerprint (normalized)                   |
| `context`         | jsonb                             | Route, build, platform, network, device, sentry_replay_id    |
| `screenshot_path` | text NULL                         | Evidence checked by the guard (see below)                    |
| `status`          | text default 'submitted'          | Server-owned: submitted → triaged → fixed                    |
| `linked_bead`     | text NULL                         | Loop-guard: set after bead creation; NULL = unclaimed         |
| `fixed_in_build`  | text NULL                         | Set by the ac-merge write-back hook (bd-vbmre.16)            |
| `created_at`      | timestamptz default now()         | Watermark column                                             |

**Auth:** service-role client (pointer: `SUPABASE_SERVICE_ROLE_KEY` in app env). The
`service_role` bypasses RLS — no `authenticated` policy is needed here.

---

## Adapter Method

### Step 0 — Watermark

Load the last-run watermark (timestamp of the most-recent row successfully claimed on the
prior run). On first run, use `NOW() - 30 days` as the bounded lookback.

Store the watermark in the triage run state alongside other source watermarks.

### Step 1 — Fetch unclaimed rows

```sql
SELECT id, user_id, category, severity, message, context, screenshot_path, created_at
FROM public.feedback_reports
WHERE linked_bead IS NULL
  AND created_at > <watermark>
ORDER BY created_at
```

`linked_bead IS NULL` is the PRIMARY loop-guard. The watermark is a secondary efficiency
gate — in case of a write-back failure on a prior run, the `linked_bead IS NULL` clause
re-catches any row that slipped through without being claimed.

### Step 2 — Evidence guard (before any dedup or bead creation)

For each row where `category = 'bug'`:

```
if context claims a screenshot (context->>'sentry_replay_id' is set, OR context has a
screenshot-indicating key) BUT screenshot_path IS NULL:
    SKIP this row — flag it in the run report as "evidence-incomplete"
    do NOT create a bead, do NOT claim (linked_bead stays NULL)
```

The exact check: if `context` contains a key signaling that a screenshot was intended
(e.g. any non-null screenshot-related key) but `screenshot_path IS NULL`, flag and skip.
A conservative implementation: for any `bug` row, if the submitted `context` includes a
key whose name contains "screenshot" with a non-null value, but `screenshot_path` is NULL,
flag it. Err on the side of flagging.

Non-bug rows (`feature`, `other`) do not require screenshots; skip the guard for them.

### Step 3 — Fingerprint dedup

Before creating a bead, compute the dedup fingerprint:

```
fingerprint = user_id + normalize(message) + category
```

`normalize(message)` = lowercase, collapse whitespace, strip leading/trailing whitespace,
strip punctuation. Goal: "App crashes when I tap photos" and "app crashes when I tap photos!"
produce the same fingerprint.

Maintain an **in-memory fingerprint set** for the current run. On each row:

1. Compute fingerprint.
2. If fingerprint is already in the set → skip (this row is a client retry re-INSERT).
   Log the skipped `id` in the run report as "deduped-duplicate".
3. If fingerprint is NOT in the set → add it and proceed to Step 4.

**Cross-run dedup:** the `linked_bead IS NULL` gate in Step 1 handles across-run dedup
(a prior run already claimed the original, so the re-INSERT is the only unclaimed copy).
Within-run in-memory dedup handles multiple re-INSERTs arriving in the same triage window.

### Step 4 — Create bead

For each surviving row, create a bead directly via `br create`, per the conventions in
`beads-standards/reference/bead-conventions.md` (`ac-bead-capture` is the human quick-capture skill and is
not invoked here):

```bash
br create \
  -t bug \
  --labels triage,feedback,unrefined \
  --title "<category>: <first 80 chars of message>" \
  --description "$(cat <<'EOF'
Source: public.feedback_reports / id=<id>
User: <user_id> (anonymized in title)
Category: <category> | Severity: <severity or 'n/a'>
Context: <context as compact JSON>
Screenshot: <screenshot_path or 'none'>
Created: <created_at>

Raw message:
<message>
EOF
)"
```

- Use `-t bug` for `category='bug'`; `-t investigation` for `category='other'`.
- `category='feature'` → `-t decision --labels triage,feedback,human-gate,unrefined` — the
  `human-gate` label is MANDATORY on the same command (`beads-standards` § Bead taxonomy:
  the label, not the type, is the sole gate; without it the decision is silently workable
  and closable by agents).
- The `triage,feedback,unrefined` labels are constant (`unrefined` routes every
  feedback bead through `ac-bead-refine` before any implementation pickup).
- Capture the new bead id returned by `br create` (e.g. `bd-xxxx`).

### Step 5 — Write-back (loop-guard claim)

After the bead is created, write `linked_bead` and update `status` back to the source row:

```sql
UPDATE public.feedback_reports
SET linked_bead = '<bead-id>',
    status      = 'triaged'
WHERE id = '<row-id>'
  AND linked_bead IS NULL   -- safety: only claim unclaimed rows
```

The `AND linked_bead IS NULL` guard prevents double-claiming if two concurrent triage
runs race (last-write-wins is safe since the same bead-id would be written, but the guard
makes the intent explicit).

**If the write-back fails:** log the failure in the run report. Do NOT unwind the bead —
the bead is the durable artifact; a failed write-back means the row will be re-processed on
the next run (and deduplicated by fingerprint within that run; the existing bead will be
found by cross-bead dedup before creating a duplicate). Retry the write-back on the next
scheduled run.

### Step 6 — Advance watermark

After processing all rows from this fetch, advance the watermark to the `created_at` of
the last successfully claimed row. If no rows were claimed (all skipped/flagged), do not
advance the watermark (so the same window is retried on the next run).

---

## Run report contribution

```
feedback-reports (source #6): <N> new rows fetched
  claimed:     <N> beads created + linked_bead set
  skipped:     <N> already claimed (linked_bead was set — should not appear due to WHERE clause, but guard)
  deduped:     <N> in-run fingerprint duplicates dropped (client retry re-INSERTs)
  flagged:     <N> bug rows with missing evidence (screenshot context mismatch)
watermark: <new watermark ISO timestamp>
```

---

## Unit test cases (consuming app: `__tests__/unit/triage-feedback-adapter.test.ts`)

These cases must ALL pass before this adapter ships in a wave. The test file lives in the
consuming app (body-compass-app). Reference this spec when authoring the tests.

### (a) New row → bead created + linked_bead set

**Setup:** `public.feedback_reports` contains one row with `linked_bead IS NULL`, `category='bug'`,
`screenshot_path` populated (or non-bug), `created_at > watermark`.

**Expected behavior:**
- `br create` called exactly once with `-t bug --labels triage,feedback`.
- `UPDATE public.feedback_reports SET linked_bead = '<bead-id>', status = 'triaged' WHERE id = '<row-id>'` executed.
- Run report shows `claimed: 1`.

### (b) Row with linked_bead already set → skipped

**Setup:** A row with `linked_bead = 'bd-xxxx'` (already claimed).

**Note:** This row should NOT appear in Step 1's fetch (`WHERE linked_bead IS NULL`). The
test verifies the WHERE clause is correct: the adapter must NOT call `br create` for this row.

**Expected behavior:**
- `br create` is NOT called.
- No UPDATE issued for this row.

### (c) Re-INSERTed duplicate (same user+normalized(message)+category, new id) → no second bead

**Setup:** Two rows in the fetch window, both with `linked_bead IS NULL`:
- Row A: `id='uuid-1'`, `user_id='user-1'`, `category='bug'`, `message='App crashes on open'`.
- Row B: `id='uuid-2'`, same `user_id`, same `category`, `message='App crashes on open!'` (client retry, new id).

**Expected behavior:**
- `br create` called exactly ONCE (for whichever row is processed first by `ORDER BY created_at`).
- The second row is fingerprint-deduplicated and skipped.
- Run report shows `claimed: 1`, `deduped: 1`.
- The second row's `linked_bead` remains NULL (it is NOT claimed — it's a phantom duplicate).

### (d) Bug row with screenshot context but screenshot_path IS NULL → skipped/flagged, no bead

**Setup:** A row with `category='bug'`, `context` containing a screenshot-indicating key
with a non-null value, but `screenshot_path IS NULL`.

**Expected behavior:**
- Evidence guard fires before dedup and bead creation.
- `br create` is NOT called for this row.
- No UPDATE issued.
- Run report shows `flagged: 1` with the row id listed.
- The row's `linked_bead` remains NULL (awaiting evidence fix, not silently dropped forever).

---

## Registering this adapter in CORE/triage.md

When wiring for a new app, add a row to the consuming app's `CORE/triage.md` sources table:

```
| 6 | **Feedback reports** | ⬜ adapter pending / ✅ live | service-role — see `supabase.md` |
```

And add a source-specifics entry:

```
- **Feedback reports (source #6):** solicited in-app user feedback in `<schema>.feedback_reports`.
  Query: `SELECT ... WHERE linked_bead IS NULL AND created_at > <watermark>`.
  Fingerprint dedup on user_id + normalized(message) + category (not id-only — client retries re-INSERT).
  Evidence guard: skip bug rows where context claims a screenshot but screenshot_path IS NULL.
  Write-back: SET linked_bead + status='triaged' after each bead creation (loop-guard).
  Write-back for status='fixed' + fixed_in_build is the ac-merge hook (bd-vbmre.16).
```

See `ac-merge/references/feedback-writeback-hook.md` for the status write-back half.
