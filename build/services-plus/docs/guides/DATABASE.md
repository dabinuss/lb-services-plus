# Database Operations

## Backup

Before installation, migration, rollback, or destructive administration work:

1. Stop `services-plus`.
2. Create a consistent database backup with the server provider's supported MySQL/MariaDB tooling.
3. Verify that the backup contains every table prefixed with `services_plus_` and the schema-version rows.
4. Record the deployed resource version and database engine version beside the backup.
5. Test restoration on a non-production database when possible.

## Migrations

The install schema is current through migration 014. Existing installations must apply each missing file from `sql/migrations/` in numeric order. Never skip a migration or apply a newer resource against an older schema.

Migration 011 stops physically deleting companies and company numbers. `adminDeleteCompany` and number removal now set `deleted_at` (and `deleted_by` on companies) instead, so call, request, and conversation history stays joinable and readable. Deleted company IDs, job links, and phone numbers remain reserved and are not reused automatically; saving a company or number with the same identifier revives the soft-deleted row.

Migration 012 adds a `distribution` column to `services_plus_call_queue`, capturing the number's distribution mode at the moment a call was queued. Queue and call duration are not stored; they are derived at read time from the existing `created_at`, `accepted_at`, and `ended_at` timestamps.

Migration 013 adds an `anonymous` column to `services_plus_inbox_conversations`. LB Phone's `newCompanyMessage` event carries an `anonymous` flag when a citizen messages a business with a hidden number; the real number is still stored (conversations are still grouped by it and employees can still reply), but read paths hide it from employees when this flag is set, the same way an anonymous caller's number is hidden in call history.

Migration 014 adds a `request_notification_actionable` column to `services_plus_companies` (default off). When enabled, incoming request offers for that company include Accept/Decline directly in the native notification and the full-screen in-app offer, the same way an incoming call is presented. When disabled, employees are only informed and must open the app to act on a request.

1. Stop `services-plus` and back up the database.
2. Check the current rows in `services_plus_schema_migrations`.
3. Apply only the missing migration files in ascending order.
4. Deploy the matching resource files.
5. Start the resource and confirm schema validation succeeds.
6. Test directory, duty, one call, one message, and one request workflow.

Migrations are not run automatically. This prevents an unexpected resource restart from changing production data.

## Rollback

SQL down-migrations are intentionally not provided because later migrations can transform or remove data. To roll back safely, stop the resource, restore the complete pre-migration backup, deploy the matching earlier resource version, and start the server. Do not manually decrement schema-version rows.

After restart, Services+ returns active requests to a safe pending state and ends open call queue records. Native LB Phone records remain owned by LB Phone.
