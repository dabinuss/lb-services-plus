ALTER TABLE `services_plus_requests`
  ADD COLUMN `assigned_name` VARCHAR(100) NULL AFTER `assigned_identifier`,
  ADD COLUMN `assigned_role` VARCHAR(100) NULL AFTER `assigned_name`;

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (9, 'request_assignee_integration_contract');
