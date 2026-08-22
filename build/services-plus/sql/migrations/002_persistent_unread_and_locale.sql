-- Services+ migration 002: persistent unread badges and per-phone locale.
-- UPGRADE MIGRATION ONLY. Fresh installations already receive these tables
-- from sql/install.sql. Both statements are safe to re-run.

CREATE TABLE IF NOT EXISTS `phone_services_plus_preferences` (
    `phone_number` VARCHAR(15) NOT NULL,
    `locale` VARCHAR(5) NOT NULL DEFAULT 'en',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`phone_number`)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `phone_services_plus_read_state` (
    `owner_key` VARCHAR(100) NOT NULL,
    `scope` VARCHAR(32) NOT NULL,
    `company_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_read_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`owner_key`, `scope`, `company_id`)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
