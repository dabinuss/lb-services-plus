-- Adds the access paths used by the per-requester open-request guard and the
-- bounded stale-open-request cleanup. Safe to run repeatedly.

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests'
      AND index_name = 'requester_status_created'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD INDEX `requester_status_created` (`requester_number`, `status`, `created_at`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests'
      AND index_name = 'status_created_id'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD INDEX `status_created_id` (`status`, `created_at`, `id`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
