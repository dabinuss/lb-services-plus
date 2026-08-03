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
  `deleted_at` TIMESTAMP NULL,
  `deleted_by` VARCHAR(96) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_services_plus_companies_job` (`job`),
  KEY `idx_services_plus_companies_category` (`category_id`),
  KEY `idx_services_plus_companies_deleted` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_company_numbers` (
  `id` VARCHAR(64) NOT NULL,
  `company_id` VARCHAR(64) NOT NULL,
  `label` VARCHAR(80) NOT NULL,
  `number` VARCHAR(32) NOT NULL,
  `distribution` ENUM('ring_all','random','dispatch_only') NOT NULL DEFAULT 'ring_all',
  `shared_inbox` TINYINT(1) NOT NULL DEFAULT 1,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `calls_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `inbox_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `requests_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `public_visible` TINYINT(1) NOT NULL DEFAULT 1,
  `deleted_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_services_plus_number` (`number`),
  KEY `idx_services_plus_numbers_company` (`company_id`),
  KEY `idx_services_plus_numbers_deleted` (`company_id`, `deleted_at`),
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
  `creator_number` VARCHAR(32) NULL,
  `company_id` VARCHAR(64) NOT NULL,
  `template_id` VARCHAR(64) NOT NULL,
  `request_label` VARCHAR(80) NOT NULL DEFAULT 'Request',
  `assigned_identifier` VARCHAR(96) NULL,
  `assigned_name` VARCHAR(100) NULL,
  `assigned_role` VARCHAR(100) NULL,
  `status` VARCHAR(32) NOT NULL,
  `phase_id` VARCHAR(64) NULL,
  `target_number_id` VARCHAR(64) NULL,
  `location_x` DECIMAL(10,3) NULL,
  `location_y` DECIMAL(10,3) NULL,
  `external_source` VARCHAR(64) NULL,
  `external_id` VARCHAR(96) NULL,
  `payload` JSON NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `accepted_at` TIMESTAMP NULL,
  `completed_at` TIMESTAMP NULL,
  `cancelled_at` TIMESTAMP NULL,
  `deleted_at` TIMESTAMP NULL,
  `deleted_by` VARCHAR(96) NULL,
  PRIMARY KEY (`id`),
  KEY `idx_services_plus_requests_company_status` (`company_id`, `status`, `id`),
  KEY `idx_services_plus_requests_creator` (`creator_identifier`, `id`),
  UNIQUE KEY `uq_services_plus_request_external` (`external_source`, `external_id`)
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

CREATE TABLE IF NOT EXISTS `services_plus_call_queue` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `call_token` VARCHAR(96) NOT NULL,
  `lb_call_id` BIGINT NULL,
  `caller_identifier` VARCHAR(96) NULL,
  `caller_number` VARCHAR(32) NULL,
  `company_id` VARCHAR(64) NOT NULL,
  `number_id` VARCHAR(64) NOT NULL,
  `status` ENUM('queued','offered','accepted','declined','ended') NOT NULL DEFAULT 'queued',
  `assigned_identifier` VARCHAR(96) NULL,
  `offered_identifiers` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `accepted_at` TIMESTAMP NULL,
  `ended_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_services_plus_call_token` (`call_token`),
  KEY `idx_services_plus_call_queue` (`number_id`, `status`, `id`),
  KEY `idx_services_plus_call_company` (`company_id`, `status`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_inbox_conversations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `company_id` VARCHAR(64) NOT NULL,
  `number_id` VARCHAR(64) NOT NULL,
  `external_number` VARCHAR(32) NOT NULL,
  `channel_id` BIGINT NULL,
  `last_message` VARCHAR(500) NOT NULL DEFAULT '',
  `last_message_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` TIMESTAMP NULL,
  `deleted_by` VARCHAR(96) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_services_plus_inbox_party` (`number_id`, `external_number`),
  UNIQUE KEY `uq_services_plus_inbox_channel` (`channel_id`),
  KEY `idx_services_plus_inbox_company` (`company_id`, `last_message_at`, `id`),
  KEY `idx_services_plus_inbox_company_number_activity` (`company_id`, `number_id`, `last_message_at`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_inbox_messages` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `conversation_id` BIGINT UNSIGNED NOT NULL,
  `lb_message_id` BIGINT NULL,
  `sender_number` VARCHAR(32) NOT NULL,
  `sender_identifier` VARCHAR(96) NULL,
  `sender_type` ENUM('citizen','employee') NOT NULL,
  `body` VARCHAR(2000) NOT NULL DEFAULT '',
  `attachments` JSON NULL,
  `coords` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` TIMESTAMP NULL,
  `deleted_by` VARCHAR(96) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_services_plus_lb_message` (`lb_message_id`),
  KEY `idx_services_plus_inbox_messages` (`conversation_id`, `id`),
  CONSTRAINT `fk_services_plus_inbox_message_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `services_plus_inbox_conversations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_inbox_reads` (
  `conversation_id` BIGINT UNSIGNED NOT NULL,
  `identifier` VARCHAR(96) NOT NULL,
  `last_read_message_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`conversation_id`, `identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `services_plus_inbox_message_reactions` (
  `message_id` BIGINT UNSIGNED NOT NULL,
  `actor_key` VARCHAR(140) NOT NULL,
  `emoji` VARCHAR(16) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`message_id`, `actor_key`),
  KEY `idx_services_plus_reactions_message` (`message_id`, `emoji`),
  CONSTRAINT `fk_services_plus_reaction_message` FOREIGN KEY (`message_id`) REFERENCES `services_plus_inbox_messages` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `services_plus_settings` (`setting_key`, `setting_value`) VALUES
  ('directoryTitle', JSON_QUOTE('Los Santos Services')),
  ('callsEnabled', 'true'),
  ('requestsEnabled', 'true')
ON DUPLICATE KEY UPDATE `setting_key` = VALUES(`setting_key`);

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`) VALUES
  (1, 'phase1_foundation'),
  (2, 'admin_and_citizen_ui'),
  (3, 'company_cards_and_dispatch'),
  (4, 'phase2_communications'),
  (5, 'phase2_media_reactions'),
  (6, 'phase2_competition_duty_dispatch_deletion');
INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`) VALUES
  (7, 'phase2_number_staffing_notifications_navigation_api'),
  (8, 'simplify_dispatch_line_selection'),
  (9, 'request_assignee_integration_contract'),
  (10, 'inbox_cursor_index'),
  (11, 'soft_delete_companies_and_numbers');
