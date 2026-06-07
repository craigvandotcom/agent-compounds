# Optimistic Writes + Thin Repo Pattern (HIGH)

The pattern that makes an app feel native without a sync engine. SWR provides everything needed.

## The pattern

```typescript
import useSWR, { useSWRConfig } from 'swr';

await mutate(swrKey, async () => foodsRepo.create(payload), {
  optimisticData: current => [...(current ?? []), optimisticEntry],
  rollbackOnError: true,
  revalidate: false,
});
```

- Entry appears instantly in the UI (`optimisticData`).
- On server reject, SWR rolls back automatically (`rollbackOnError`).
- Honest rollback toast: **"Couldn't save — your input was not preserved. Try again."** Do NOT offer a "try again" button unless you actually saved the draft — the optimistic rollback removed it.

## Thin repo abstraction — introduce it FROM THE START

Even if the implementation is just Supabase passthrough today, introduce a `<domain>Repo` indirection from day one:

```typescript
// lib/data/repos/foods-repo.ts
export const foodsRepo = {
  list: () => supabase.from('foods').select('*'),
  create: payload => supabase.from('foods').insert(payload),
  update: (id, patch) => supabase.from('foods').update(patch).eq('id', id),
  delete: id => supabase.from('foods').delete().eq('id', id),
};
```

**Why it matters:** when you later swap the internals for IDB-backed local-first (see `distribution-stage.md`), every action hook keeps working — internals-only swap. Without the indirection, every callsite has to change.

**API matches the SERVICE, not generic CRUD.** If a domain has upsert semantics (single row per user per day, etc.), the repo mirrors that — don't pretend it's a CRUD log table.
