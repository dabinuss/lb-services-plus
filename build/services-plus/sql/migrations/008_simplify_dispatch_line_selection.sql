DROP TABLE IF EXISTS `services_plus_number_subscriptions`;
DROP TABLE IF EXISTS `services_plus_number_employees`;

ALTER TABLE `services_plus_company_numbers`
  DROP COLUMN `staffing_mode`;

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (8, 'simplify_dispatch_line_selection');
