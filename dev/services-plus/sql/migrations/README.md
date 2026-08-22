# Services+ database migrations

These files upgrade an existing Services+ database. A new installation uses
`../install.sql` instead.

Apply numbered migrations in ascending order, starting with the first version
that has not yet been applied:

1. `001_pre_1_0_to_1_0.sql` upgrades every schema that predates Services+ 1.0.
2. `002_persistent_unread_and_locale.sql` adds persistent badge read markers
   and per-phone notification language preferences.
3. `003_conversation_reads.sql` upgrades message badges to individual,
   persistent read markers for every conversation.

All migrations are idempotent and can safely be re-run. Migration 001 checks
`information_schema` before each schema change and supports both MySQL and
MariaDB without manual SQL edits. Future upgrades belong in a new numbered
file; migration files that have shipped must not be extended or rewritten.
