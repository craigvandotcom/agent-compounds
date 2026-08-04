---
name: supabase
description: Supabase development. Use when writing or reviewing SQL and migrations, designing or modifying database schema, working with RLS policies, optimizing queries or indexes, using the Supabase CLI (supabase db, supabase migration), generating TypeScript types from schema, debugging database or auth issues, or touching lib/db.ts, lib/supabase/, or supabase/migrations/. NOT for UI component work (use web-design-guidelines for correctness, ac-ui-polish for polish), general React patterns or device storage (use capacitor), or auth UI flows (use CORE + auth spec).
---

> **Generic skill — method only, zero app facts.** This skill is symlinked from
> agent-compounds and shared across consuming apps. It contains technique and
> patterns, not project specifics. **App specifics (project refs, schema names,
> domain rules, feature flows, env values) → read this app's
> `.claude/skills/CORE/SKILL.md`** (and the `AGENTS.md` summary it indexes).
> Do not add app-specific facts to this file — they belong in CORE.

# Supabase

**Purpose:** CLI-driven Supabase development, migrations, SDK patterns, Postgres best practices
**Domain:** Database, auth, storage, edge functions, schema design, query optimization

---

## When to Use This Skill

**Intent Triggers:**

- Writing or reviewing SQL / migrations
- Designing or modifying database schema
- Working with RLS policies
- Optimizing query performance or indexes
- Using the Supabase CLI (`supabase db`, `supabase migration`, etc.)
- Generating TypeScript types from schema
- Debugging database or auth issues
- Touching `lib/db.ts`, `lib/supabase/`, or `supabase/migrations/`

**When NOT to Use:**

- UI component work (use `design-system`)
- General React patterns (use `capacitor`)
- Auth UI flows (use the app's CORE + its auth spec)

---

## CLI Quick Reference

The Supabase CLI is installed on the developer machine (verify version with
`supabase --version`). Per-app environment specifics (project ref, region, link
target, local-vs-prod strategy) live in that app's `CORE/supabase.md`.

### Prerequisites — Link to Remote

Most CLI commands require linking to a project. If you see `Cannot find project
ref. Have you run supabase link?`, run the app's link command (per its CORE).
Linking state is stored in `supabase/.temp/`.

Authentication is stored at `~/.supabase/access-token` (via `supabase login`). If
you see `Access token not provided`, the user must run `supabase login`
interactively.

> **Local vs. production strategy is per-app.** Some apps run a local Docker
> stack; some target production directly with PITR as the safety net. Read the
> app's `CORE/supabase.md` before deciding whether a command is safe to run.

### Agent Safety Rules

Treat the connected database as authoritative. When an app targets production
directly there is no local safety net, so the rules below are strict by default.

**Run freely (read-only, no confirmation needed):**

- `supabase inspect db *` — performance stats, index usage, bloat, locks
- `supabase migration list` — compare local vs remote migration status
- `supabase gen types typescript --linked` — regenerate TypeScript types
- `supabase db dump --schema-only` — export current schema

**Run freely (local-only writes):**

- `supabase migration new <name>` — creates a local `.sql` file, no remote impact

**ASK USER FIRST (production writes — present SQL and wait for approval):**

- `supabase db push` — applies pending migrations to the linked project (irreversible)
- `supabase db pull` — overwrites local migration files with remote schema
- `supabase migration squash` — rewrites local migration history
- `supabase migration repair` — modifies remote migration history table
- `supabase functions deploy` — deploys edge functions

**NEVER run without explicit user request:**

- Any raw SQL against a production database
- Dropping tables, columns, or RLS policies
- Modifying auth configuration

**Migration workflow for agents:**

1. Write the migration SQL and show it to the user
2. Create the file with `supabase migration new`
3. Write the SQL into the file
4. Present the complete migration for review
5. Only run the push after explicit user approval
6. After push, regenerate types

### Migrations

**Filename rule — timestamp prefix for new files.** New migration files use a
14-digit timestamp prefix (`YYYYMMDDHHMMSS_<name>.sql`). `supabase migration new
<name>` generates this format by default. Timestamps are globally unique, sort
chronologically, and never collide between apps sharing a migrations directory.

> Some apps have legacy integer-prefixed migrations (`NNN_*.sql`) that are
> grandfathered. The CLI **silently skips** files whose prefix is neither a pure
> integer nor a valid timestamp — no error, no warning. Always verify with
> `ls supabase/migrations/ | sort` before authoring a new file. Any app-specific
> legacy-prefix gotchas live in that app's `CORE/supabase.md`.

| Command                         | Purpose                                               |
| ------------------------------- | ----------------------------------------------------- |
| `supabase migration new <name>` | Create empty migration file in `supabase/migrations/` |
| `supabase migration list`       | List migrations (local files vs remote applied)       |
| `supabase migration squash`     | Squash migrations to single file                      |
| `supabase migration repair`     | Fix migration history table                           |
| `supabase db push`              | Push pending migrations to remote                     |
| `supabase db pull`              | Pull remote schema into local migrations              |
| `supabase db dump`              | Dump remote data or schema                            |

### Code Generation

| Command                                  | Purpose                                   |
| ---------------------------------------- | ----------------------------------------- |
| `supabase gen types typescript --linked` | Generate types from linked remote project |

Output goes to stdout — redirect to the app's generated-types file:

```bash
supabase gen types typescript --linked > lib/supabase/types.ts
```

(The app's CORE documents the exact output path and any npm-script wrapper.)

### Inspection & Debugging

| Command                                    | Purpose                                  |
| ------------------------------------------ | ---------------------------------------- |
| `supabase inspect db bloat`                | Estimate dead tuple space                |
| `supabase inspect db outliers`             | Slowest queries by total execution time  |
| `supabase inspect db calls`                | Most-called queries                      |
| `supabase inspect db index-stats`          | Index usage, scan counts, unused indexes |
| `supabase inspect db table-stats`          | Table sizes, row counts                  |
| `supabase inspect db locks`                | Current exclusive locks                  |
| `supabase inspect db long-running-queries` | Queries running >5 min                   |
| `supabase inspect db blocking`             | Queries blocking other queries           |
| `supabase inspect db vacuum-stats`         | Vacuum stats per table                   |

All inspect commands run against the linked remote project by default (requires `supabase link`).

### Project Management

| Command                            | Purpose                        |
| ---------------------------------- | ------------------------------ |
| `supabase link`                    | Link CLI to a project          |
| `supabase functions deploy <name>` | Deploy edge function           |
| `supabase functions serve`         | Serve edge functions locally   |

---

## Migration Workflow

### Creating a New Migration

```bash
# 1. Create the migration file
supabase migration new add_food_tags

# 2. Edit the generated file in supabase/migrations/

# 3. (apps with a local stack) Local-validate first — see the gate below

# 4. Push to remote (after user approval)
supabase db push

# 5. Generate updated types
supabase gen types typescript --linked > lib/supabase/types.ts   # or --local for the local stack
```

### Local-validate gate (risk-tiered) — for apps that run a local stack

The asymmetry: a migration's first execution against real data should never also
be its first execution *ever*. Where a local Docker stack exists, validate there
before `db push`. **Tier the discipline by blast radius — don't gate everything:**

| Migration class | Gate |
| --- | --- |
| RLS / privilege / `GRANT` · destructive (`DROP`, type changes) · data backfill | **REQUIRED** — local-validate must pass before `db push` |
| Additive + reversible (nullable column, new index, new table no one reads yet) | **Optional** — direct-to-prod-with-PITR is acceptable; forcing ceremony here is process for its own sake |

**Apply-timing (WHEN to push — `rule-migrations-expand-contract`):** EXPAND (additive) is pushed
**before/at the merge** of the code that depends on it (web deploys at merge against live prod
schema); CONTRACT (destructive) is **held** and applied only after old native builds age out, via
`ac-publish`'s migration gate. `db push` stays ASK-USER-FIRST either way — the rule times the ask.

The gate (an app encodes this as one script — e.g. `pnpm db:verify`):

```bash
supabase db reset      # ← replay ALL migrations from zero on a fresh local DB.
                       #   THIS is the reproducibility signal: green = the migration
                       #   applies in-sequence on a clean DB, not just on your drifted local.
<app local integration tests>   # RLS/escalation correctness — only surfaces against real Postgres
# then, separately: regenerate types (a tracked-file mutation — keep it OUT of the pass/fail gate)
```

Two principles keep this from rotting into false confidence:

- **Ephemeral, not warm.** Trust the *replay* (`db reset`), never the *contents*. A
  long-lived local DB that accretes state you start believing drifts from prod and
  gives you green-locally-red-in-prod. Reset before validating; treat local data as
  disposable.
- **Name the coverage hole.** Local can't cover everything — e.g. where local
  storage is disabled, bucket/`storage.objects` RLS is *not* locally testable and
  stays a Dashboard/runbook step. Local-green ≠ feature-safe; say what the gate does
  not cover. A disposable cloud dev project is the fallback for destructive tests
  local can't model.

Whether the gate is **required** for this app (and the exact script + local-stack
facts) is documented per-app in `CORE/supabase.md`.

> **Shared-project / cross-app migration hosting is per-ecosystem.** When several
> apps share one Supabase project, one app is typically designated the canonical
> migration host and siblings symlink to it; `supabase config push` is forbidden
> because it clobbers other apps' schema exposure. The host designation, symlink
> layout, and `<timestamp>_<app-abbrev>_<name>.sql` naming convention are
> documented per-app in `CORE/supabase.md` and in the ecosystem's
> `software/CLAUDE.md`. This generic skill does not name a host.

**Timestamp collisions:** If two engineers run `supabase migration new` in the
same second, the second invocation fails loudly with a filename collision.
Engineer just retries — no allocator infrastructure needed.

### Rules for Migrations

- **Never edit applied migrations** — create new ones to fix issues
- **Include RLS policies** in the same migration as the table they protect
- **Use `IF NOT EXISTS`** for idempotent DDL where appropriate
- **Name migrations descriptively:** `add_food_tags`, `fix_symptom_rls`, `create_correlations_table`
- **Keep migrations small and focused** — one logical change per file
- **Use transactions** (migrations run in a transaction by default)
- **Before `db push`:** if a local stack exists, run the local-validate gate above (required for RLS/destructive/backfill); if there is no local DB, review the SQL carefully by hand — it is the only check
- **Before dropping/altering constraints:** Verify the exact constraint name against the source migration file — names frequently differ from assumptions. Run `grep -r "CONSTRAINT" supabase/migrations/ | grep <table_name>` to confirm.
- **Smoke-testing a UNIQUE constraint against a populated DB:** Don't enumerate insert columns by hand — you'll miss NOT NULL fields and trip `23502` (`not_null_violation`) before reaching the constraint. Copy an existing row via `%ROWTYPE` so every NOT NULL column is populated automatically:

  ```sql
  DO $$
  DECLARE r my_table%ROWTYPE;
  BEGIN
    SELECT * INTO r FROM my_table LIMIT 1;
    r.id := gen_random_uuid();  -- only override the PK
    BEGIN
      INSERT INTO my_table VALUES (r.*);
      RAISE EXCEPTION 'SMOKE FAIL: duplicate insert succeeded';
    EXCEPTION WHEN unique_violation THEN
      NULL;  -- expected: 23505
    END;
  END $$;
  ```

  This proves the unique constraint actually fires (rather than failing on something else first). Enumerating columns by hand routinely misses NOT NULL fields and hits `23502` before the constraint is reached; `%ROWTYPE` is robust to schema additions.

### Rolling Back

```bash
# NEVER revert remote - create a new forward migration instead
supabase migration new revert_food_tags
# Write the reverse SQL in the new migration
```

---

## Local Supabase keys in integration tests

Apps that run integration tests against a **local** Supabase stack use the local
CLI's well-known dev keys (visible via `supabase status -o env`). These are NOT
production secrets and are identical across every developer's machine.

**BUT:** gitleaks (pre-commit hook) cannot distinguish well-known local keys from
real secrets. Any `sb_secret_*` or `sb_publishable_*` literal in committed code
will block the commit.

**Convention — read local-stack keys from env, NEVER hardcode literals:**

```ts
const LOCAL_SUPABASE_URL =
  process.env.LOCAL_SUPABASE_URL ?? ''; // no default port — each app uses a distinct local Supabase port range (org rule); hardcoding cross-wires apps
const LOCAL_SERVICE_ROLE_KEY = process.env.LOCAL_SUPABASE_SERVICE_KEY ?? '';
```

When a test needs to override production-pointing `NEXT_PUBLIC_SUPABASE_*` env
vars (because the test setup loads an `.env.local` that points at production),
reassign from the `LOCAL_*` vars BEFORE any client construction:

```ts
// Force local stack BEFORE any createClient() call
process.env.NEXT_PUBLIC_SUPABASE_URL =
  process.env.LOCAL_SUPABASE_URL ?? ''; // no default port — each app uses a distinct local Supabase port range (org rule); hardcoding cross-wires apps
process.env.SUPABASE_SECRET_KEY = process.env.LOCAL_SUPABASE_SERVICE_KEY ?? '';
process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY =
  process.env.LOCAL_SUPABASE_PUBLISHABLE_KEY ?? '';
```

`.env.local` must already contain `LOCAL_SUPABASE_SERVICE_KEY` (and optionally the
others) — copy from `supabase status -o env` output once after `supabase start`.

**Never hardcode `sb_secret_*` / `sb_publishable_*` literals in committed code** —
gitleaks will block the commit.

---

## SDK Patterns

**Singleton browser client:**

```typescript
// Cache the browser client at module scope.
// Web: createBrowserClient from @supabase/ssr
// Native (Capacitor): createClient with a Preferences storage adapter
```

**Route all DB operations through a single data-access module:**

```typescript
// Never create ad-hoc Supabase calls in components.
// A central db module should handle:
// - Column selection via shared column constants
// - User ID from supabase.auth.getUser() (never from request params)
// - Structured error objects preserving Supabase error details
// - Input sanitization for text fields
```

**Upsert + `.select()` (CRITICAL):**

`.upsert()` without `.select()` returns `PostgrestResponse<never>` — `data` is
always `null`. You MUST chain `.select()` to get the inserted/updated row back:

```typescript
const { data, error } = await supabase
  .from('table')
  .upsert(row, { onConflict: 'slug' })
  .select('id'); // REQUIRED to get inserted/updated row back

// If data is null/empty, the upsert was a no-op (blocked by WHERE clause)
if (!data || data.length === 0) return null;
```

Test mock pattern for upsert + select chain:

```typescript
const upsertMock = vi.fn().mockReturnValue({
  select: vi.fn().mockResolvedValue({
    data: [{ id: 'test-id' }],
    error: null,
  }),
});
mockFrom.mockReturnValue({ upsert: upsertMock });
```

**Type usage:**

```typescript
import type { Tables, TablesInsert, TablesUpdate } from '@/lib/supabase/types';
type Row = Tables<'my_table'>;
type NewRow = TablesInsert<'my_table'>;
```

---

## RLS Pattern

Standard pattern for user-owned tables — enforce isolation via `auth.uid() = user_id`:

```sql
-- Standard pattern for every user-owned table
alter table my_table enable row level security;

create policy "Users can view own data" on my_table
  for select to authenticated using (user_id = auth.uid());

create policy "Users can insert own data" on my_table
  for insert to authenticated with check (user_id = auth.uid());

create policy "Users can update own data" on my_table
  for update to authenticated using (user_id = auth.uid());

create policy "Users can delete own data" on my_table
  for delete to authenticated using (user_id = auth.uid());

-- Service role bypass for triggers/functions
create policy "Service role full access" on my_table
  for all to service_role using (true);
```

---

## Postgres Best Practices

From [supabase/agent-skills](https://github.com/supabase/agent-skills). Read reference files on-demand based on task.

### Categories by Priority

| #   | Category                     | Impact      | Files                          | When to Read                                         |
| --- | ---------------------------- | ----------- | ------------------------------ | ---------------------------------------------------- |
| 1   | **Query Performance**        | CRITICAL    | `references/query-*.md` (5)    | Writing queries, adding indexes, fixing slow queries |
| 2   | **Connection Management**    | CRITICAL    | `references/conn-*.md` (4)     | Connection pooling, timeouts, serverless scaling     |
| 3   | **Security & RLS**           | CRITICAL    | `references/security-*.md` (3) | RLS policies, privilege management, auth patterns    |
| 4   | **Schema Design**            | HIGH        | `references/schema-*.md` (6)   | Table design, data types, constraints, partitioning  |
| 5   | **Concurrency & Locking**    | MEDIUM-HIGH | `references/lock-*.md` (4)     | Transactions, deadlocks, lock contention             |
| 6   | **Data Access Patterns**     | MEDIUM      | `references/data-*.md` (4)     | N+1 elimination, batch ops, pagination, upsert       |
| 7   | **Monitoring & Diagnostics** | LOW-MEDIUM  | `references/monitor-*.md` (3)  | EXPLAIN ANALYZE, pg_stat_statements, vacuum          |
| 8   | **Advanced Features**        | LOW         | `references/advanced-*.md` (2) | Full-text search, JSONB indexing                     |

### Reference Index

**Query Performance (CRITICAL):**

- `query-missing-indexes.md` - Add indexes on WHERE/JOIN columns (100-1000x speedup)
- `query-composite-indexes.md` - Multi-column indexes for compound filters
- `query-covering-indexes.md` - INCLUDE columns to avoid table lookups
- `query-index-types.md` - B-tree vs GIN vs GiST vs BRIN selection
- `query-partial-indexes.md` - Conditional indexes for subset queries

**Connection Management (CRITICAL):**

- `conn-pooling.md` - PgBouncer, transaction vs session mode
- `conn-limits.md` - Max connections, pool sizing formula
- `conn-idle-timeout.md` - Reclaim idle connections
- `conn-prepared-statements.md` - When to use/avoid with pooling

**Security & RLS (CRITICAL):**

- `security-rls-basics.md` - Enable RLS, policy patterns, auth.uid()
- `security-rls-performance.md` - Index RLS filter columns, avoid function calls in policies
- `security-privileges.md` - Least privilege, role management

**Schema Design (HIGH):**

- `schema-data-types.md` - bigint over int, text over varchar, timestamptz
- `schema-primary-keys.md` - Identity columns, UUID strategies
- `schema-constraints.md` - CHECK, NOT NULL, unique constraints
- `schema-foreign-key-indexes.md` - Always index FK columns
- `schema-lowercase-identifiers.md` - Avoid quoted identifiers
- `schema-partitioning.md` - When and how to partition tables

**Concurrency & Locking (MEDIUM-HIGH):**

- `lock-short-transactions.md` - Keep transactions brief
- `lock-deadlock-prevention.md` - Consistent lock ordering
- `lock-advisory.md` - Application-level locks
- `lock-skip-locked.md` - Queue processing pattern

**Data Access Patterns (MEDIUM):**

- `data-n-plus-one.md` - Batch with ANY() or JOIN instead of loops
- `data-batch-inserts.md` - Multi-row INSERT, COPY for bulk
- `data-pagination.md` - Cursor-based over OFFSET pagination
- `data-upsert.md` - ON CONFLICT for upsert patterns

**Monitoring & Diagnostics (LOW-MEDIUM):**

- `monitor-explain-analyze.md` - Read query plans, identify bottlenecks
- `monitor-pg-stat-statements.md` - Track query performance over time
- `monitor-vacuum-analyze.md` - Autovacuum tuning, table bloat

**Advanced Features (LOW):**

- `advanced-full-text-search.md` - tsvector, GIN indexes, ts_rank
- `advanced-jsonb-indexing.md` - GIN on JSONB, containment operators
