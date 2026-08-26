-- Services+ migration 008: distinguish dispatch acceptance from the actual
-- billable service and persist periodically sampled journey distance.
-- Fresh installations already receive this schema via install.sql.

SET @has_column = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'phone_services_plus_requests'
      AND column_name = 'service_started_at'
);
SET @sql = IF(@has_column = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD COLUMN `service_started_at` TIMESTAMP NULL DEFAULT NULL AFTER `accepted_at`',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_column = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'phone_services_plus_requests'
      AND column_name = 'travelled_distance'
);
SET @sql = IF(@has_column = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD COLUMN `travelled_distance` FLOAT NOT NULL DEFAULT 0 AFTER `service_started_at`',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
