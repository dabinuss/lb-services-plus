-- Services+ migration 005: persistent badges for request status changes and
-- missed calls. Fresh installations already receive this table via install.sql.

CREATE TABLE IF NOT EXISTS `phone_services_plus_unread_events` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `scope` VARCHAR(32) NOT NULL,
    `owner_key` VARCHAR(100) NOT NULL DEFAULT '',
    `company_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `event_key` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `event_once` (`scope`, `owner_key`, `company_id`, `event_key`),
    KEY `badge_lookup` (`scope`, `owner_key`, `company_id`, `id`)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
