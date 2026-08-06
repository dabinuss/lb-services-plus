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
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_services_plus_inbox_party` (`number_id`, `external_number`),
  UNIQUE KEY `uq_services_plus_inbox_channel` (`channel_id`),
  KEY `idx_services_plus_inbox_company` (`company_id`, `last_message_at`, `id`)
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

ALTER TABLE `services_plus_requests`
  ADD COLUMN `creator_number` VARCHAR(32) NULL AFTER `creator_identifier`,
  ADD COLUMN `request_label` VARCHAR(80) NOT NULL DEFAULT 'Request' AFTER `template_id`,
  ADD COLUMN `accepted_at` TIMESTAMP NULL AFTER `updated_at`,
  ADD COLUMN `completed_at` TIMESTAMP NULL AFTER `accepted_at`,
  ADD COLUMN `cancelled_at` TIMESTAMP NULL AFTER `completed_at`;

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (4, 'phase2_communications');
