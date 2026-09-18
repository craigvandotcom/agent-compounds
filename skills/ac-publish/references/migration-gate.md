# Pending prod migrations

A promoted build reaches users the moment the alias moves. Every schema it depends on is
live before that, or the release ships code talking to a database that cannot answer it.

## The check

    supabase migration list --linked

Run it from the app checkout, before Phase 0. A repo migration with no REMOTE entry is
pending.

## The rule

Refuse the publish and name every pending migration. Do not promote, do not tag.

This gate never pushes. A human applies each migration and verifies it live against a
prediction written before the push. Use `supabase db push --include-all` when a pending
migration sorts before an already-applied version.

Override: `PENDING_MIGRATION_OVERRIDE=<reason>`. An unset variable is not an override.

## Why the proof leg cannot cover this

`ac-prove` replays migrations against a FRESH LOCAL stack. It proves they apply; it never
reads prod. A green suite therefore says nothing about what prod's schema holds, and a
from-scratch replay passes identically whether prod is current or ten migrations behind.

## Ordering

Apply one migration per transaction, heaviest alone. Hold any migration that drops a column
an installed app version still reads — shipped clients outlive a deploy.
