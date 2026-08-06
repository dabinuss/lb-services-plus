-- Phase 2 media and message reactions. Back up the database before applying.

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

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (5, 'phase2_media_reactions');
