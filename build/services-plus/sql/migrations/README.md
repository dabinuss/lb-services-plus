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
4. `004_request_abuse_hardening.sql` adds indexes for bounded open-request
   creation and expiry cleanup.
5. `005_unread_activity_events.sql` adds persistent, race-safe badge events
   for request status changes and missed calls.
6. `006_stable_employee_stats.sql` stores stable employee identities for
   calls/messages and adds the indexes used by daily employee statistics.
7. `007_request_type_identifiers.sql` separates stable request API keys from
   presentation icons and enforces their uniqueness.
8. `008_billable_service_tracking.sql` starts fare calculation at the actual
   service phase and stores sampled journey distance.
9. `009_message_reactions.sql` adds persistent per-user emoji reactions to
   Services+ messages.

Unread activity events deliberately have no age-only cleanup; see
`UNREAD_RETENTION.md` before adding a retention job.

All migrations are idempotent and can safely be re-run. Migration 001 checks
`information_schema` before each schema change and supports both MySQL and
MariaDB without manual SQL edits. Future upgrades belong in a new numbered
file; migration files that have shipped must not be extended or rewritten.
