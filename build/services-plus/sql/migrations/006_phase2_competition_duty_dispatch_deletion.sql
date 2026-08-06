-- Phase 2 category competition, duty lifecycle and dispatch deletion. Back up the database before applying.

ALTER TABLE `services_plus_requests`
  ADD COLUMN `deleted_at` TIMESTAMP NULL AFTER `cancelled_at`,
  ADD COLUMN `deleted_by` VARCHAR(96) NULL AFTER `deleted_at`;

ALTER TABLE `services_plus_inbox_conversations`
  ADD COLUMN `deleted_at` TIMESTAMP NULL AFTER `created_at`,
  ADD COLUMN `deleted_by` VARCHAR(96) NULL AFTER `deleted_at`;

ALTER TABLE `services_plus_inbox_messages`
  ADD COLUMN `deleted_at` TIMESTAMP NULL AFTER `created_at`,
  ADD COLUMN `deleted_by` VARCHAR(96) NULL AFTER `deleted_at`;

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (6, 'phase2_competition_duty_dispatch_deletion');
