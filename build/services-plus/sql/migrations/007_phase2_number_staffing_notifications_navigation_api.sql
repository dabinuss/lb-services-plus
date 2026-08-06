ALTER TABLE `services_plus_company_numbers`
  ADD COLUMN `enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `shared_inbox`,
  ADD COLUMN `calls_enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `enabled`,
  ADD COLUMN `inbox_enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `calls_enabled`,
  ADD COLUMN `requests_enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `inbox_enabled`,
  ADD COLUMN `public_visible` TINYINT(1) NOT NULL DEFAULT 1 AFTER `requests_enabled`,
  ADD COLUMN `staffing_mode` ENUM('all','self_select','restricted','dispatch_only') NOT NULL DEFAULT 'all' AFTER `public_visible`;

CREATE TABLE IF NOT EXISTS `services_plus_number_subscriptions` (
  `number_id` VARCHAR(64) NOT NULL,
  `identifier` VARCHAR(96) NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`number_id`, `identifier`),
  KEY `idx_services_plus_number_subscriptions_identifier` (`identifier`, `number_id`),
  CONSTRAINT `fk_services_plus_number_subscription_number` FOREIGN KEY (`number_id`) REFERENCES `services_plus_company_numbers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `services_plus_requests`
  ADD COLUMN `target_number_id` VARCHAR(64) NULL AFTER `phase_id`,
  ADD COLUMN `location_x` DECIMAL(10,3) NULL AFTER `target_number_id`,
  ADD COLUMN `location_y` DECIMAL(10,3) NULL AFTER `location_x`,
  ADD COLUMN `external_source` VARCHAR(64) NULL AFTER `location_y`,
  ADD COLUMN `external_id` VARCHAR(96) NULL AFTER `external_source`,
  ADD UNIQUE KEY `uq_services_plus_request_external` (`external_source`, `external_id`);

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (7, 'phase2_number_staffing_notifications_navigation_api');
