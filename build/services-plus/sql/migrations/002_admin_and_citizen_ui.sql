CREATE TABLE IF NOT EXISTS `services_plus_settings` (
  `setting_key` VARCHAR(64) NOT NULL,
  `setting_value` JSON NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`setting_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `services_plus_settings` (`setting_key`, `setting_value`) VALUES
  ('directoryTitle', JSON_QUOTE('Los Santos Services')),
  ('callsEnabled', 'true'),
  ('requestsEnabled', 'true')
ON DUPLICATE KEY UPDATE `setting_key` = VALUES(`setting_key`);

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (2, 'admin_and_citizen_ui');
