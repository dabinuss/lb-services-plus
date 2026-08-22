-- Services+ migration 001: pre-1.0 installations -> 1.0 schema.
-- UPGRADE MIGRATION ONLY. Do NOT run this against a
-- brand new database - use sql/install.sql for a fresh install instead,
-- whose CREATE TABLE statements already include everything below.
--
-- This file exists only for installs that ran an older sql/install.sql
-- before these columns/indexes existed. Every block is safe to re-run, on
-- both plain MySQL and MariaDB (plan review round 6 §2, §6): earlier
-- versions of this file used "ADD COLUMN/INDEX IF NOT EXISTS", which plain
-- MySQL doesn't support at all for indexes (a syntax error, not a harmless
-- no-op) and needed hand-editing per block to work around. Every block
-- below instead checks information_schema itself and only runs the ALTER
-- when genuinely missing - no client-specific syntax, nothing to edit by
-- hand regardless of which MySQL/MariaDB version this runs against.

-- ---------------------------------------------------------------------------
-- Phase 3 migration.
-- ---------------------------------------------------------------------------

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_companies' AND column_name = 'admin_calls_allowed'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_companies` ADD COLUMN `admin_calls_allowed` TINYINT(1) NOT NULL DEFAULT 1 AFTER `requests_enabled`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Request notes can now be disabled, optional or required. Existing enabled
-- note fields retain their previous optional behavior.
SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_request_types' AND column_name = 'note_mode'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_request_types` ADD COLUMN `note_mode` ENUM(''disabled'', ''optional'', ''required'') NOT NULL DEFAULT ''disabled'' AFTER `description_enabled`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE `phone_services_plus_request_types`
SET note_mode = 'optional'
WHERE description_enabled = 1 AND note_mode = 'disabled';

-- Passenger count previously behaved as a required field whenever enabled.
SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_request_types' AND column_name = 'passenger_mode'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_request_types` ADD COLUMN `passenger_mode` ENUM(''disabled'', ''optional'', ''required'') NOT NULL DEFAULT ''disabled'' AFTER `passenger_count`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE `phone_services_plus_request_types`
SET passenger_mode = 'required'
WHERE passenger_count = 1 AND passenger_mode = 'disabled';

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_request_types' AND column_name = 'count_label'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_request_types` ADD COLUMN `count_label` VARCHAR(50) NOT NULL DEFAULT ''Passenger count'' AFTER `passenger_mode`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- `icon` was the old admin-facing technical identifier field. It is now
-- generated from the display name and no longer editable in the UI.
UPDATE `phone_services_plus_request_types`
SET icon = TRIM(BOTH '_' FROM LOWER(
    REPLACE(REPLACE(REPLACE(REPLACE(TRIM(name), ' ', '_'), '-', '_'), '/', '_'), '__', '_')
));

-- Built-in Medical update and News preset. Location is captured
-- automatically for every request by server/requests.lua.
INSERT IGNORE INTO `phone_services_plus_categories` (`key`, name, icon, sort_order, competition_allowed)
VALUES ('news', 'News', 'news', 70, 0);

UPDATE `phone_services_plus_request_types` t
    JOIN `phone_services_plus_categories` c ON c.id = t.category_id
SET t.passenger_count = 1, t.passenger_mode = 'required',
    t.count_label = 'Number of injured people', t.note_mode = 'disabled', t.description_enabled = 0
WHERE c.`key` = 'medical' AND t.icon = 'medical_emergency';

INSERT INTO `phone_services_plus_request_types`
    (category_id, name, icon, description, location_mode, passenger_count, passenger_mode,
     count_label, description_enabled, note_mode, competition_enabled)
SELECT c.id, 'Breaking News', 'breaking_news', 'Report breaking news at your current location.',
       'auto', 0, 'disabled', 'Passenger count', 0, 'disabled', 0
FROM `phone_services_plus_categories` c
WHERE c.`key` = 'news'
  AND NOT EXISTS (
      SELECT 1 FROM `phone_services_plus_request_types` t WHERE t.icon = 'breaking_news'
  );

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_companies' AND column_name = 'admin_messages_allowed'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_companies` ADD COLUMN `admin_messages_allowed` TINYINT(1) NOT NULL DEFAULT 1 AFTER `admin_calls_allowed`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_companies' AND column_name = 'admin_requests_allowed'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_companies` ADD COLUMN `admin_requests_allowed` TINYINT(1) NOT NULL DEFAULT 1 AFTER `admin_messages_allowed`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- Post-review hardening migration.
-- ---------------------------------------------------------------------------

-- De-duplicate any channels created before the UNIQUE constraint below
-- existed (a race in getOrCreateChannel could produce two channels for the
-- same number+contact pair) - keeps the oldest one, reassigns its messages.
UPDATE `phone_services_plus_messages` m
    JOIN `phone_services_plus_channels` dup ON dup.id = m.channel_id
    JOIN `phone_services_plus_channels` keep
        ON keep.number_id = dup.number_id
        AND keep.contact_number = dup.contact_number
        AND keep.id < dup.id
SET m.channel_id = keep.id;

DELETE dup FROM `phone_services_plus_channels` dup
    JOIN `phone_services_plus_channels` keep
        ON keep.number_id = dup.number_id
        AND keep.contact_number = dup.contact_number
        AND keep.id < dup.id;

-- Moving duplicate-channel messages can make the retained channel's cached
-- preview and sort timestamp older than its actual newest message. Rebuild
-- both once from the newest message per retained channel.
UPDATE `phone_services_plus_channels` c
    JOIN `phone_services_plus_messages` newest ON newest.channel_id = c.id
    LEFT JOIN `phone_services_plus_messages` newer
        ON newer.channel_id = newest.channel_id
        AND (
            newer.created_at > newest.created_at
            OR (newer.created_at = newest.created_at AND newer.id > newest.id)
        )
SET c.last_message = LEFT(newest.content, 100), c.updated_at = newest.created_at
WHERE newer.id IS NULL;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_channels' AND index_name = 'contact_archived_updated'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_channels` ADD INDEX `contact_archived_updated` (`contact_number`, `archived_by_contact`, `updated_at`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_channels' AND index_name = 'number_archived_updated'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_channels` ADD INDEX `number_archived_updated` (`number_id`, `archived_by_company`, `updated_at`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_messages' AND index_name = 'channel_created'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_messages` ADD INDEX `channel_created` (`channel_id`, `created_at`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_calls' AND column_name = 'lb_call_id'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_calls` ADD COLUMN `lb_call_id` BIGINT UNSIGNED DEFAULT NULL AFTER `number_id`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_calls' AND index_name = 'company_created'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_calls` ADD INDEX `company_created` (`company_id`, `created_at`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_calls' AND index_name = 'customer_created'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_calls` ADD INDEX `customer_created` (`customer_number`, `created_at`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_calls' AND index_name = 'lb_call_id'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_calls` ADD INDEX `lb_call_id` (`lb_call_id`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests' AND index_name = 'company_status_created'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD INDEX `company_status_created` (`company_id`, `status`, `created_at`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests' AND index_name = 'requester_created'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD INDEX `requester_created` (`requester_number`, `created_at`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests' AND index_name = 'employee_status'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD INDEX `employee_status` (`employee_identifier`, `status`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- Round 3 review migration.
-- ---------------------------------------------------------------------------

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_request_types' AND column_name = 'enabled'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_request_types` ADD COLUMN `enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `competition_enabled`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- Round 4 review migration.
-- ---------------------------------------------------------------------------

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_messages' AND column_name = 'sender_type'
);
-- Doubled single quotes to escape them inside the outer '...' string literal
-- this whole DDL is built as (`''customer''` -> literal `'customer'` once
-- PREPARE parses it).
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_messages` ADD COLUMN `sender_type` ENUM(''customer'', ''company'') NOT NULL DEFAULT ''customer'' AFTER `sender`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Backfill existing rows for installs that had messages before sender_type
-- existed - anything not sent by the channel's own contact number was sent
-- by the company side. Harmless to re-run - a second pass just re-derives
-- the same values.
UPDATE `phone_services_plus_messages` m
    JOIN `phone_services_plus_channels` c ON c.id = m.channel_id
SET m.sender_type = 'company'
WHERE m.sender <> c.contact_number;

-- ---------------------------------------------------------------------------
-- Round 5 review migration.
-- ---------------------------------------------------------------------------

-- Numbers now soft-delete the same way companies and request types already
-- do (plan review round 5 §1) - number_id cascades down to channels,
-- messages, and call history, so a real DELETE used to take all of that
-- with it. admin:deleteNumber now just clears this instead.
SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_numbers' AND column_name = 'enabled'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_numbers` ADD COLUMN `enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `mailbox_enabled`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- Round 6 review migration.
-- ---------------------------------------------------------------------------

-- `number_contact` (plan review round 6 §2): a genuinely old install that
-- upgraded through the pre-information_schema version of this file never
-- actually got this UNIQUE constraint added - that earlier version assumed
-- every upgrader already had it and only ran the de-dup UPDATE/DELETE
-- above, not the ALTER itself (which didn't exist as a real, executable
-- statement in that version at all, plain-MySQL-safe or otherwise). Without
-- it, getOrCreateChannel's INSERT IGNORE race-safety (see server/main.lua)
-- silently stops doing anything - two concurrent opens can produce two
-- channels for the same number+contact pair again, same bug the dedup
-- above was originally written to clean up after.
SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_channels' AND index_name = 'number_contact'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_channels` ADD UNIQUE KEY `number_contact` (`number_id`, `contact_number`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- `(channel_id, id)` (plan review round 6 §5): getMessages' cursor
-- pagination now queries `WHERE channel_id = ? AND id < ? ORDER BY id DESC`
-- (see server/main.lua) - `channel_created (channel_id, created_at)` above
-- doesn't serve that as well as an index built around the actual column the
-- query filters and orders by. Only matters at real scale, but costs
-- nothing to have from here on.
SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_messages' AND index_name = 'channel_id_id'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_messages` ADD INDEX `channel_id_id` (`channel_id`, `id`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- Active-request disconnect grace period and persistent admin settings.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `phone_services_plus_settings` (
    `key` VARCHAR(50) NOT NULL,
    `value` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`key`)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

INSERT IGNORE INTO `phone_services_plus_settings` (`key`, `value`)
VALUES ('active_request_disconnect_grace_minutes', '5');

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests' AND column_name = 'employee_disconnected_at'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD COLUMN `employee_disconnected_at` TIMESTAMP NULL DEFAULT NULL AFTER `employee_identifier`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*) FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests' AND index_name = 'disconnected_status'
);
SET @ddl := IF(@idx_exists = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD INDEX `disconnected_status` (`status`, `employee_disconnected_at`)',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- Request-type "special features" (e.g. taxi Taxameter pricing). See
-- sql/install.sql's phone_services_plus_company_features/_requests comments
-- for what each piece is for.
-- ---------------------------------------------------------------------------

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_request_types' AND column_name = 'feature'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_request_types` ADD COLUMN `feature` VARCHAR(50) DEFAULT NULL AFTER `enabled`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS `phone_services_plus_company_features` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL,
    `request_type_id` INT UNSIGNED NOT NULL,
    `feature` VARCHAR(50) NOT NULL,
    `config` JSON NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `company_type_feature` (`company_id`, `request_type_id`, `feature`),
    FOREIGN KEY (`company_id`) REFERENCES `phone_services_plus_companies`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`request_type_id`) REFERENCES `phone_services_plus_request_types`(`id`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests' AND column_name = 'accepted_at'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD COLUMN `accepted_at` TIMESTAMP NULL DEFAULT NULL AFTER `description`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests' AND column_name = 'pickup_distance'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD COLUMN `pickup_distance` FLOAT DEFAULT NULL AFTER `accepted_at`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (
    SELECT COUNT(*) FROM information_schema.columns
    WHERE table_schema = DATABASE() AND table_name = 'phone_services_plus_requests' AND column_name = 'feature_data'
);
SET @ddl := IF(@col_exists = 0,
    'ALTER TABLE `phone_services_plus_requests` ADD COLUMN `feature_data` JSON DEFAULT NULL AFTER `pickup_distance`',
    'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
