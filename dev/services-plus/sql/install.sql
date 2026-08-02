CREATE TABLE IF NOT EXISTS `services_plus_schema_migrations` (
  `version` INT UNSIGNED NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_settings` (
  `setting_key` VARCHAR(64) NOT NULL,
  `setting_value` JSON NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_companies` (
  `id` VARCHAR(64) NOT NULL,
  `job` VARCHAR(64) NOT NULL,
  `display_name` VARCHAR(100) NOT NULL,
  `logo` VARCHAR(500) NULL,
  `background_image` VARCHAR(500) NULL,
  `category_id` VARCHAR(64) NOT NULL,
  `description` VARCHAR(500) NOT NULL DEFAULT '',
  `location` VARCHAR(150) NOT NULL DEFAULT '',
  `opening_hours` VARCHAR(100) NOT NULL DEFAULT '',
  `keywords` JSON NULL,
  `requests_enabled` TINYINT(1) NOT NULL DEFAULT 0,
  `messages_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `dispatch_mode` ENUM('ring_all','random','dispatch_only') NOT NULL DEFAULT 'ring_all',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_services_plus_companies_job` (`job`),
  KEY `idx_services_plus_companies_category` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_company_numbers` (
  `id` VARCHAR(64) NOT NULL,
  `company_id` VARCHAR(64) NOT NULL,
  `label` VARCHAR(80) NOT NULL,
  `number` VARCHAR(32) NOT NULL,
  `distribution` ENUM('ring_all','random','dispatch_only') NOT NULL DEFAULT 'ring_all',
  `shared_inbox` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_services_plus_number` (`number`),
  KEY `idx_services_plus_numbers_company` (`company_id`),
  CONSTRAINT `fk_services_plus_numbers_company` FOREIGN KEY (`company_id`) REFERENCES `services_plus_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_employee_settings` (
  `identifier` VARCHAR(96) NOT NULL,
  `company_id` VARCHAR(64) NOT NULL,
  `dispatch_preference` TINYINT(1) NOT NULL DEFAULT 0,
  `explicit_leader` TINYINT(1) NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`, `company_id`),
  KEY `idx_services_plus_employee_company` (`company_id`),
  CONSTRAINT `fk_services_plus_employee_company` FOREIGN KEY (`company_id`) REFERENCES `services_plus_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_number_employees` (
  `number_id` VARCHAR(64) NOT NULL,
  `identifier` VARCHAR(96) NOT NULL,
  PRIMARY KEY (`number_id`, `identifier`),
  CONSTRAINT `fk_services_plus_number_employee_number` FOREIGN KEY (`number_id`) REFERENCES `services_plus_company_numbers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_categories` (
  `id` VARCHAR(64) NOT NULL,
  `definition` JSON NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_request_templates` (
  `id` VARCHAR(64) NOT NULL,
  `category_id` VARCHAR(64) NOT NULL,
  `definition` JSON NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_services_plus_templates_category` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_request_template_fields` (
  `template_id` VARCHAR(64) NOT NULL,
  `field_id` VARCHAR(64) NOT NULL,
  `position` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `definition` JSON NOT NULL,
  PRIMARY KEY (`template_id`, `field_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_company_request_settings` (
  `company_id` VARCHAR(64) NOT NULL,
  `settings` JSON NOT NULL,
  PRIMARY KEY (`company_id`),
  CONSTRAINT `fk_services_plus_request_settings_company` FOREIGN KEY (`company_id`) REFERENCES `services_plus_companies` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_request_phases` (
  `id` VARCHAR(64) NOT NULL,
  `category_id` VARCHAR(64) NOT NULL,
  `position` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `definition` JSON NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_services_plus_phases_category` (`category_id`, `position`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_requests` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `creator_identifier` VARCHAR(96) NOT NULL,
  `company_id` VARCHAR(64) NOT NULL,
  `template_id` VARCHAR(64) NOT NULL,
  `assigned_identifier` VARCHAR(96) NULL,
  `status` VARCHAR(32) NOT NULL,
  `phase_id` VARCHAR(64) NULL,
  `payload` JSON NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_services_plus_requests_company_status` (`company_id`, `status`, `id`),
  KEY `idx_services_plus_requests_creator` (`creator_identifier`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_request_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `request_id` BIGINT UNSIGNED NOT NULL,
  `actor_identifier` VARCHAR(96) NULL,
  `event_type` VARCHAR(64) NOT NULL,
  `payload` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_services_plus_request_events_request` (`request_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_call_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `caller_identifier` VARCHAR(96) NULL,
  `company_id` VARCHAR(64) NOT NULL,
  `number_id` VARCHAR(64) NOT NULL,
  `employee_identifier` VARCHAR(96) NULL,
  `result` VARCHAR(32) NOT NULL,
  `metadata` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_services_plus_calls_company` (`company_id`, `id`),
  KEY `idx_services_plus_calls_caller` (`caller_identifier`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_request_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `request_id` BIGINT UNSIGNED NOT NULL,
  `company_id` VARCHAR(64) NOT NULL,
  `creator_identifier` VARCHAR(96) NOT NULL,
  `employee_identifier` VARCHAR(96) NULL,
  `result` VARCHAR(32) NOT NULL,
  `metadata` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_services_plus_request_history_company` (`company_id`, `id`),
  KEY `idx_services_plus_request_history_creator` (`creator_identifier`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_message_assignments` (
  `channel_id` BIGINT UNSIGNED NOT NULL,
  `company_id` VARCHAR(64) NOT NULL,
  `number_id` VARCHAR(64) NOT NULL,
  `employee_identifier` VARCHAR(96) NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`channel_id`),
  KEY `idx_services_plus_messages_company` (`company_id`, `updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `services_plus_settings` (`setting_key`, `setting_value`) VALUES
  ('directoryTitle', JSON_QUOTE('Los Santos Services')),
  ('callsEnabled', 'true'),
  ('requestsEnabled', 'true')
ON DUPLICATE KEY UPDATE `setting_key` = VALUES(`setting_key`);

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`) VALUES
  (1, 'phase1_foundation'),
  (2, 'admin_and_citizen_ui'),
  (3, 'company_cards_and_dispatch');
