-- Services+ migration 006: stable employee attribution and supporting daily
-- statistics indexes. Fresh installations already receive this schema via
-- install.sql. Every operation is idempotent for safe re-runs.

SET @has_column = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_messages' AND column_name = 'company_id'
);
SET @sql = IF(@has_column = 0,
    'ALTER TABLE `phone_services_plus_messages` ADD COLUMN `company_id` INT UNSIGNED NULL AFTER `channel_id`',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Company ownership is unambiguous for existing messages through
-- message -> channel -> number, so this part can be backfilled safely.
UPDATE `phone_services_plus_messages` m
JOIN `phone_services_plus_channels` ch ON ch.id = m.channel_id
JOIN `phone_services_plus_numbers` n ON n.id = ch.number_id
SET m.company_id = n.company_id
WHERE m.company_id IS NULL;

SET @has_column = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_messages' AND column_name = 'sender_identifier'
);
SET @sql = IF(@has_column = 0,
    'ALTER TABLE `phone_services_plus_messages` ADD COLUMN `sender_identifier` VARCHAR(100) NULL AFTER `sender`',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_column = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_calls' AND column_name = 'employee_identifier'
);
SET @sql = IF(@has_column = 0,
    'ALTER TABLE `phone_services_plus_calls` ADD COLUMN `employee_identifier` VARCHAR(100) NULL AFTER `employee_number`',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_index = (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_messages' AND index_name = 'company_sender_daily'
);
SET @sql = IF(@has_index = 0,
    'ALTER TABLE `phone_services_plus_messages` ADD INDEX `company_sender_daily` (`company_id`, `sender_type`, `created_at`, `sender_identifier`)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_index = (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_calls' AND index_name = 'company_state_daily'
);
SET @sql = IF(@has_index = 0,
    'ALTER TABLE `phone_services_plus_calls` ADD INDEX `company_state_daily` (`company_id`, `state`, `created_at`, `employee_identifier`)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_index = (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests' AND index_name = 'company_status_daily'
);
SET @sql = IF(@has_index = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD INDEX `company_status_daily` (`company_id`, `status`, `updated_at`, `employee_identifier`)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Keep company_id nullable on upgraded databases for compatibility with
-- external/legacy writers. Services+ itself always writes it from now on.
