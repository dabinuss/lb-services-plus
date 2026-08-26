-- Services+ migration 007: give request types a dedicated stable technical
-- identifier. Fresh installations already receive this schema via install.sql.
-- Every operation is idempotent for safe re-runs.

SET @has_column = (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'phone_services_plus_request_types'
      AND column_name = 'identifier'
);
SET @sql = IF(@has_column = 0,
    'ALTER TABLE `phone_services_plus_request_types` ADD COLUMN `identifier` VARCHAR(100) NULL AFTER `name`',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- `icon` was historically used as the technical key. Preserve it exactly
-- (apart from the already case-insensitive lookup semantics) so existing
-- exports and Config.RequestTypeTemplates entries keep resolving.
UPDATE `phone_services_plus_request_types`
SET `identifier` = LOWER(TRIM(`icon`))
WHERE (`identifier` IS NULL OR TRIM(`identifier`) = '')
  AND `icon` IS NOT NULL
  AND TRIM(`icon`) <> '';

UPDATE `phone_services_plus_request_types`
SET `identifier` = CONCAT('request_type_', `id`)
WHERE `identifier` IS NULL OR TRIM(`identifier`) = '';

-- A missing UNIQUE constraint previously allowed duplicate keys. Keep the
-- oldest row's public key and give every later duplicate a deterministic,
-- collision-free suffix before adding the constraint.
UPDATE `phone_services_plus_request_types` t
JOIN (
    SELECT `identifier`, MIN(`id`) AS keep_id
    FROM `phone_services_plus_request_types`
    GROUP BY `identifier`
    HAVING COUNT(*) > 1
) duplicates ON duplicates.identifier = t.identifier AND t.id <> duplicates.keep_id
SET t.identifier = CONCAT(LEFT(t.identifier, 88), '_', t.id);

SET @is_nullable = (
    SELECT IS_NULLABLE FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'phone_services_plus_request_types'
      AND column_name = 'identifier'
    LIMIT 1
);
SET @sql = IF(@is_nullable = 'YES',
    'ALTER TABLE `phone_services_plus_request_types` MODIFY COLUMN `identifier` VARCHAR(100) NOT NULL',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_index = (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'phone_services_plus_request_types'
      AND index_name = 'request_type_identifier'
      AND non_unique = 0
);
SET @sql = IF(@has_index = 0,
    'ALTER TABLE `phone_services_plus_request_types` ADD UNIQUE KEY `request_type_identifier` (`identifier`)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
