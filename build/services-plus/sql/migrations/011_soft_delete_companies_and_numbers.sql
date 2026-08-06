-- Companies and company numbers were previously removed with a hard DELETE, which left
-- call history, request history and call queue rows pointing at identifiers that no longer
-- existed. Both tables now use the same soft-delete pattern already used for requests,
-- conversations and messages, so historical records stay readable after a company or a
-- number is removed. Deleted identifiers remain reserved and are not reused.

ALTER TABLE `services_plus_companies`
  ADD COLUMN `deleted_at` TIMESTAMP NULL AFTER `updated_at`,
  ADD COLUMN `deleted_by` VARCHAR(96) NULL AFTER `deleted_at`,
  ADD INDEX `idx_services_plus_companies_deleted` (`deleted_at`);

ALTER TABLE `services_plus_company_numbers`
  ADD COLUMN `deleted_at` TIMESTAMP NULL AFTER `public_visible`,
  ADD INDEX `idx_services_plus_numbers_deleted` (`company_id`, `deleted_at`);

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (11, 'soft_delete_companies_and_numbers');
