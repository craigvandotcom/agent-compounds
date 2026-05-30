---
name: supabase
description: Supabase development with CLI, migrations, SDK patterns, and Postgres best practices. Use when writing SQL, designing schemas, running migrations, working with RLS, optimizing queries, or touching any Supabase integration code.
---

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
- General React patterns (use `react-best-practices`)
- Auth UI flows (use CORE + `_docs/specs/supabase-auth.md`)

---

## CLI Quick Reference

Supabase CLI v2.75.0 installed at `/home/van/.local/bin/supabase`.

### Prerequisites — Link to Remote

**We do NOT run a local Supabase Docker stack for development.** All development targets production directly.

**Exception — integration tests use a local stack.** `pnpm test:integration` (`__tests__/supabase-integration/`) runs against a local Supabase instance, not production. Before running these tests on a branch that adds migrations, sync local: `pnpm supabase db push --local`. Without this, tests will fail with "relation does not exist". The `--local` flag is safe — local-only writes, no production impact. The "no Docker stack" rule applies to feature/dev work; integration tests are the documented exception.

**Single-project strategy:** We use one production Supabase project. Migrations are written locally, reviewed by the agent, approved by the user, and pushed directly to production. Point-in-time recovery (PITR) on the Pro plan is the safety net for disasters.

| Project        | Ref                    | Name              | Region                 |
| -------------- | ---------------------- | ----------------- | ---------------------- |
| **Production** | `spilwpcqjncrxptqdggn` | body-compass-prod | Central EU (Frankfurt) |

> **Legacy dev project** (`ecvbexxmqlghzosgoiww`, body-compass-dev) exists but is not actively used. Available as a disposable sandbox if needed for destructive migration testing.

**Link to production** (most CLI commands require linking):

```bash
pnpm supabase:link
```

If you see `Cannot find project ref. Have you run supabase link?`, run the command above. Linking state is stored in `supabase/.temp/`.

Authentication is stored at `~/.supabase/access-token` (via `supabase login`). If you see `Access token not provided`, the user must run `supabase login` interactively.

### Agent Safety Rules

**All CLI commands target production directly.** There is no local DB safety net. PITR is the disaster recovery mechanism. Agents must follow these rules strictly.

**Run freely (read-only, no confirmation needed):**

- `supabase inspect db *` — performance stats, index usage, bloat, locks
- `supabase migration list` — compare local vs remote migration status
- `pnpm supabase:types` — regenerate TypeScript types from production schema
- `supabase db dump --schema-only` — export current production schema

**Run freely (local-only writes):**

- `supabase migration new <name>` — creates a local `.sql` file, no remote impact

**ASK USER FIRST (production writes — present SQL and wait for approval):**

- `pnpm supabase:push` — applies pending migrations to production (irreversible)
- `supabase db pull` — overwrites local migration files with production schema
- `supabase migration squash` — rewrites local migration history
- `supabase migration repair` — modifies remote migration history table
- `supabase functions deploy` — deploys edge functions to production

**NEVER run without explicit user request:**

- Any raw SQL against the production database
- Dropping tables, columns, or RLS policies
- Modifying auth configuration

**Migration workflow for agents:**

1. Write the migration SQL and show it to the user
2. Create the file with `supabase migration new`
3. Write the SQL into the file
4. Present the complete migration for review
5. Only run `pnpm supabase:push` after explicit user approval
6. After push, regenerate types with `pnpm supabase:types`

### Migrations

**Filename rule — numeric prefix only.** Migration files must start with a plain integer (e.g. `060_backfill.sql`), not a letter-suffixed variant like `060a_backfill.sql`. The Supabase CLI silently skips files whose prefix is not a pure integer — no error, no warning, they simply don't run on `db reset` or `db push`. If you need paired migrations (e.g. dry-run + apply), use consecutive integers (`060_dry_run.sql`, `061_apply.sql`). Always verify with `ls supabase/migrations/ | sort` before authoring a new file — the next free number is your target.

**Ingredient-name parsing lives in `fn_parse_ingredient_name()`** (migration 062). Future modifier backfills call this function instead of re-inlining the parsing state machine. Migrations 060 and 061 were deleted in bead bd-lw5m (never applied to production); the backfill itself is pending a separate, explicitly-approved migration since production is the only environment.

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

Output goes to stdout - redirect to `lib/supabase/types.ts`:

```bash
supabase gen types typescript --linked > lib/supabase/types.ts
```

Or use the npm script:

```bash
pnpm supabase:types
```

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
| `pnpm supabase:link`               | Link CLI to production project |
| `supabase functions deploy <name>` | Deploy edge function           |
| `supabase functions serve`         | Serve edge functions locally   |

### NPM Scripts

| Script                 | Purpose                                         |
| ---------------------- | ----------------------------------------------- |
| `pnpm supabase:link`   | Link CLI to production (`spilwpcqjncrxptqdggn`) |
| `pnpm supabase:push`   | Push pending migrations to production           |
| `pnpm supabase:types`  | Generate TS types from production schema        |
| `pnpm supabase:status` | List all projects in account                    |

**Workflow:**

```bash
# 1. Write migration
supabase migration new my_change
# 2. Edit the SQL file in supabase/migrations/
# 3. Review with agent, get user approval
# 4. Push to production
pnpm supabase:push
# 5. Regenerate types
pnpm supabase:types
```

---

## Migration Workflow

### Creating a New Migration

**Always run `supabase migration new` from BCA's directory** (this repo). `body-compass-app/supabase/migrations/` is the canonical migration host for ALL neoMeta apps on the shared Supabase project — ASA, USA, and MFA each have `supabase/migrations` as a symlink (mode 120000) pointing here. New files appear in their symlinked dirs immediately. (Locked 2026-05-23 by bd-c6gp epic; see `software/CLAUDE.md` > Cross-App Migrations.)

```bash
# 1. Create the migration file (always from body-compass-app/)
cd body-compass-app
supabase migration new add_food_tags

# 2. Edit the generated file in supabase/migrations/

# 3. Push to production (after user approval)
pnpm supabase:push

# 4. Generate updated types from production
pnpm supabase:types
```

**Filename convention:** `<timestamp>_<app-abbrev>_<name>.sql` for non-BCA migrations (e.g. `20260523190237_usa_initial.sql`). Three-letter app abbreviation makes ownership unambiguous when many apps land migrations to the same dir. BCA's own migrations may omit the prefix (`<timestamp>_<name>.sql`). Social-contract only — not CLI-enforced.

**Timestamp collisions:** If two engineers run `supabase migration new` in the same second, the second invocation fails loudly with filename collision. Engineer just retries — no allocator infrastructure needed.

**NNN\_ legacy files:** BCA's `001_*.sql` through `085_*.sql` stay as-is (renaming would break `schema_migrations` tracking). Mixed-format dir sorts correctly because 14-digit timestamps lexicographically follow 3-digit NNN\_ prefixes.

### Rules for Migrations

- **Never edit applied migrations** - create new ones to fix issues
- **Include RLS policies** in the same migration as the table they protect
- **Use `IF NOT EXISTS`** for idempotent DDL where appropriate
- **Name migrations descriptively:** `add_food_tags`, `fix_symptom_rls`, `create_correlations_table`
- **Keep migrations small and focused** - one logical change per file
- **Use transactions** (migrations run in a transaction by default)
- **Review SQL carefully before `db push`** - no local DB to test against
- **Before dropping/altering constraints:** Verify exact constraint name against the source migration file — names frequently differ from assumptions. Run `grep -r "CONSTRAINT" supabase/migrations/ | grep <table_name>` to confirm.
- **Smoke-testing a UNIQUE constraint in prod:** Don't enumerate insert columns by hand — you'll miss NOT NULL fields and trip 23502 (`not_null_violation`) before reaching the constraint. Copy an existing row via `%ROWTYPE` so every NOT NULL column is populated automatically:

  ```sql
  DO $$
  DECLARE r tier_transitions%ROWTYPE;
  BEGIN
    SELECT * INTO r FROM tier_transitions LIMIT 1;
    r.id := gen_random_uuid();  -- only override the PK
    BEGIN
      INSERT INTO tier_transitions VALUES (r.*);
      RAISE EXCEPTION 'SMOKE FAIL: duplicate insert succeeded';
    EXCEPTION WHEN unique_violation THEN
      NULL;  -- expected: 23505
    END;
  END $$;
  ```

  This proves the unique constraint actually fires (rather than failing on something else first). Concrete cost: bd-9veq.8 first smoke-test attempt enumerated keyspace + remembered NOT NULL columns; missed `lift_value, food_days, reaction_count, forward_rate`; hit 23502 in prod (~2 min retry). `%ROWTYPE` is robust to schema additions.

### Rolling Back

```bash
# NEVER revert remote - create a new forward migration instead
supabase migration new revert_food_tags
# Write the reverse SQL in the new migration
```

---

## Project Context

### Environment

- **Project:** Body Compass (bodycompass.app)
- **Production Ref:** `spilwpcqjncrxptqdggn` (single-project strategy, direct to prod)
- **Stack:** Next.js 15 + `@supabase/ssr` + TypeScript
- **Database:** PostgreSQL 17 (remote only, no local Docker)
- **Migrations:** Check current highest before creating: `ls supabase/migrations/*.sql | sort | tail -1` (numbering has gaps — never assume sequential)
- **Auth:** Email signup, no anonymous signups, JWT 1hr expiry
- **Safety net:** PITR (point-in-time recovery) on Pro plan

### Key Files

| File                         | Purpose                                                   |
| ---------------------------- | --------------------------------------------------------- |
| `lib/supabase/client.ts`     | Browser client (singleton, dual web/Capacitor strategy)   |
| `lib/supabase/server.ts`     | Server client (Next.js cookie-based)                      |
| `lib/supabase/middleware.ts` | Session refresh via `updateSession()`                     |
| `lib/supabase/types.ts`      | Auto-generated types (`Database`, `Tables<>`, etc.)       |
| `lib/db.ts`                  | All CRUD operations (foods, symptoms, users, preferences) |
| `supabase/config.toml`       | Project configuration (project_id, auth settings)         |

### Environment Variables

```
NEXT_PUBLIC_SUPABASE_URL=""              # Public API URL (production)
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=""  # Anon/publishable key (client-safe)
SUPABASE_SECRET_KEY=""                   # Service role key (server-only, never ship to client)

# Integration-test-only — local Supabase stack keys (see "Local Supabase keys in tests" below)
LOCAL_SUPABASE_SERVICE_KEY=""            # Local-stack service-role key from `supabase status -o env`
LOCAL_SUPABASE_PUBLISHABLE_KEY=""        # Local-stack anon key (optional; default-fallback in tests)
LOCAL_SUPABASE_URL=""                    # Defaults to http://127.0.0.1:54321
```

### Local Supabase keys in tests

`__tests__/supabase-integration/*.test.ts` files run against the local stack. The local Supabase CLI's docker image uses well-known dev keys (visible via `supabase status -o env`) — they are NOT production secrets and are identical across every developer's machine.

**BUT:** gitleaks (pre-commit hook) cannot distinguish well-known local keys from real secrets. Any `sb_secret_*` or `sb_publishable_*` literal in committed code will block the commit.

**Convention** (matches all existing `__tests__/supabase-integration/*.test.ts` files):

```ts
// Read local-stack keys from env — NEVER hardcode literals
const LOCAL_SUPABASE_URL =
  process.env.LOCAL_SUPABASE_URL ?? 'http://127.0.0.1:54321';
const LOCAL_SERVICE_ROLE_KEY = process.env.LOCAL_SUPABASE_SERVICE_KEY ?? '';
```

When a test needs to override the production-pointing `NEXT_PUBLIC_SUPABASE_*` env vars (because `__tests__/supabase-integration/setup.ts` loads `.env.local` which points at production), reassign from these LOCAL\_\* vars BEFORE any client construction:

```ts
// Force local stack BEFORE any createClient() call
process.env.NEXT_PUBLIC_SUPABASE_URL =
  process.env.LOCAL_SUPABASE_URL ?? 'http://127.0.0.1:54321';
process.env.SUPABASE_SECRET_KEY = process.env.LOCAL_SUPABASE_SERVICE_KEY ?? '';
process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY =
  process.env.LOCAL_SUPABASE_PUBLISHABLE_KEY ?? '';
```

`.env.local` must already contain `LOCAL_SUPABASE_SERVICE_KEY` (and optionally the others) — copy from `supabase status -o env` output once after `supabase start`.

**Never hardcode `sb_secret_*` / `sb_publishable_*` literals in committed code.** Gitleaks will block the commit. This has happened three times on this repo (bd-odwe.5 on 2026-05-20 was the most recent — recovery cost ~5 min).

### SDK Patterns We Follow

**Singleton browser client:**

```typescript
// lib/supabase/client.ts - cached at module scope
// Web: createBrowserClient from @supabase/ssr
// Native: createClient with Capacitor Preferences storage adapter
```

**All DB operations through `lib/db.ts`:**

```typescript
// Never create ad-hoc Supabase calls in components
// Always use lib/db.ts functions which handle:
// - Column selection via FOOD_COLUMNS / SYMPTOM_COLUMNS constants
// - User ID from supabase.auth.getUser() (never from request params)
// - Structured error objects preserving Supabase error details
// - Input sanitization (sanitizeUserNote for text fields)
```

**Upsert + `.select()` (CRITICAL):**

`.upsert()` without `.select()` returns `PostgrestResponse<never>` — `data` is always `null`. You MUST chain `.select()` to get the inserted/updated row back:

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
type Food = Tables<'foods'>;
type NewFood = TablesInsert<'foods'>;
```

### RLS Pattern

All tables enforce user isolation via `auth.uid() = user_id`:

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
