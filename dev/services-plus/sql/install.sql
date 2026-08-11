-- Services+ schema. Run once against the same database lb-phone uses.
-- Table prefix `phone_services_plus_` keeps this fully separate from
-- lb-phone's own `phone_services_*` tables (the native Companies app).

CREATE TABLE IF NOT EXISTS `phone_services_plus_categories` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `key` VARCHAR(50) NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `icon` VARCHAR(100) DEFAULT NULL,
    `sort_order` INT NOT NULL DEFAULT 0,
    `competition_allowed` TINYINT(1) NOT NULL DEFAULT 0,

    PRIMARY KEY (`id`),
    UNIQUE KEY `key` (`key`)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `phone_services_plus_companies` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `job` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `category_id` INT UNSIGNED DEFAULT NULL,

    `icon` VARCHAR(255) DEFAULT NULL,
    `background` VARCHAR(255) DEFAULT NULL,
    `boss_grade` INT NOT NULL DEFAULT 100,

    `calls_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `messages_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `requests_enabled` TINYINT(1) NOT NULL DEFAULT 1,

    -- Admin ceilings (plan §34, §53): the maximum a company is allowed to
    -- enable. The *_enabled columns above are the company's own toggle and
    -- can never exceed these.
    `admin_calls_allowed` TINYINT(1) NOT NULL DEFAULT 1,
    `admin_messages_allowed` TINYINT(1) NOT NULL DEFAULT 1,
    `admin_requests_allowed` TINYINT(1) NOT NULL DEFAULT 1,

    `call_routing` VARCHAR(10) NOT NULL DEFAULT 'all',
    `request_routing` VARCHAR(10) NOT NULL DEFAULT 'all',

    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `job` (`job`),
    FOREIGN KEY (`category_id`) REFERENCES `phone_services_plus_categories`(`id`) ON DELETE SET NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `phone_services_plus_numbers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL,

    `label` VARCHAR(50) NOT NULL,
    `number` VARCHAR(15) NOT NULL,
    `is_main` TINYINT(1) NOT NULL DEFAULT 0,

    `calls_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `messages_enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `mailbox_enabled` TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (`id`),
    UNIQUE KEY `number` (`number`),
    FOREIGN KEY (`company_id`) REFERENCES `phone_services_plus_companies`(`id`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `phone_services_plus_channels` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `number_id` INT UNSIGNED NOT NULL,
    `contact_number` VARCHAR(15) NOT NULL,

    `last_message` VARCHAR(100) DEFAULT NULL,
    `archived_by_contact` TINYINT(1) NOT NULL DEFAULT 0,
    `archived_by_company` TINYINT(1) NOT NULL DEFAULT 0,

    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    -- One channel per (number, contact) - closes the race where two
    -- concurrent openConversation calls could otherwise create two channels
    -- for the same pair (plan review §7). getOrCreateChannel() relies on
    -- this via INSERT IGNORE.
    UNIQUE KEY `number_contact` (`number_id`, `contact_number`),
    FOREIGN KEY (`number_id`) REFERENCES `phone_services_plus_numbers`(`id`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `phone_services_plus_messages` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `channel_id` INT UNSIGNED NOT NULL,

    `sender` VARCHAR(15) NOT NULL,
    `content` VARCHAR(1000) NOT NULL,
    `pos_x` FLOAT DEFAULT NULL,
    `pos_y` FLOAT DEFAULT NULL,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    FOREIGN KEY (`channel_id`) REFERENCES `phone_services_plus_channels`(`id`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Call history (plan §38). Populated passively from lb-phone's own
-- lb-phone:newCall/callAnswered/callEnded events (see server/calls.lua) -
-- Services+ never places calls itself, it only logs the ones it resolved a
-- target number for. `state` does not distinguish missed vs. declined - both
-- collapse to 'missed' since lb-phone does not expose that distinction.
CREATE TABLE IF NOT EXISTS `phone_services_plus_calls` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `company_id` INT UNSIGNED NOT NULL,
    `number_id` INT UNSIGNED NOT NULL,

    -- lb-phone's own call id, so callAnswered/callEnded can update this row
    -- straight from the database instead of an in-memory callId->row map
    -- that a Services+ restart mid-call would lose (plan review round 2 §2).
    `lb_call_id` BIGINT UNSIGNED DEFAULT NULL,

    `customer_number` VARCHAR(15) NOT NULL,
    `employee_number` VARCHAR(15) DEFAULT NULL,
    `state` VARCHAR(10) NOT NULL DEFAULT 'ringing', -- ringing | answered | missed

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ended_at` TIMESTAMP NULL DEFAULT NULL,

    PRIMARY KEY (`id`),
    FOREIGN KEY (`company_id`) REFERENCES `phone_services_plus_companies`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`number_id`) REFERENCES `phone_services_plus_numbers`(`id`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Standalone framework fallback (see server/framework.lua). Unused for
-- ESX/QBCore/Qbox, where jobs already live in the framework's own tables.
CREATE TABLE IF NOT EXISTS `phone_services_plus_standalone_jobs` (
    `identifier` VARCHAR(100) NOT NULL,
    `job` VARCHAR(50) NOT NULL,
    `grade` INT NOT NULL DEFAULT 0,

    PRIMARY KEY (`identifier`)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Request system (plan §11-16, §36, phase 2). Request types are seeded per
-- category the same way categories/companies are (see server/requests.lua);
-- `company_id` on a request stays NULL while a competition request is still
-- up for grabs and is only set once an employee accepts it.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `phone_services_plus_request_types` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category_id` INT UNSIGNED DEFAULT NULL,

    `name` VARCHAR(50) NOT NULL,
    `icon` VARCHAR(100) DEFAULT NULL,
    `description` VARCHAR(255) DEFAULT NULL,

    `location_mode` VARCHAR(10) NOT NULL DEFAULT 'auto',
    `passenger_count` TINYINT(1) NOT NULL DEFAULT 0,
    `description_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `competition_enabled` TINYINT(1) NOT NULL DEFAULT 0,

    -- Soft-delete only (plan review round 3 §9): request_type_id on
    -- phone_services_plus_requests is ON DELETE CASCADE, so a physical
    -- delete here would take the type's entire request history - open,
    -- active and historical alike - down with it. "Deleting" a type from
    -- the admin area just clears this instead.
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,

    PRIMARY KEY (`id`),
    FOREIGN KEY (`category_id`) REFERENCES `phone_services_plus_categories`(`id`) ON DELETE SET NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `phone_services_plus_requests` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `request_type_id` INT UNSIGNED NOT NULL,
    `company_id` INT UNSIGNED DEFAULT NULL,

    `requester_number` VARCHAR(15) NOT NULL,
    `employee_identifier` VARCHAR(100) DEFAULT NULL,
    `status` VARCHAR(10) NOT NULL DEFAULT 'open',

    `pos_x` FLOAT DEFAULT NULL,
    `pos_y` FLOAT DEFAULT NULL,
    `passenger_count` INT DEFAULT NULL,
    `description` VARCHAR(255) DEFAULT NULL,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    FOREIGN KEY (`request_type_id`) REFERENCES `phone_services_plus_request_types`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`company_id`) REFERENCES `phone_services_plus_companies`(`id`) ON DELETE SET NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Phase 3 migration. Safe to re-run: only adds these columns if they're
-- missing, for installs that ran this file before phase 3 existed.
-- Requires MySQL 8.0.29+ / MariaDB 10.0.2+ for "ADD COLUMN IF NOT EXISTS".
-- ---------------------------------------------------------------------------
ALTER TABLE `phone_services_plus_companies`
    ADD COLUMN IF NOT EXISTS `admin_calls_allowed` TINYINT(1) NOT NULL DEFAULT 1 AFTER `requests_enabled`,
    ADD COLUMN IF NOT EXISTS `admin_messages_allowed` TINYINT(1) NOT NULL DEFAULT 1 AFTER `admin_calls_allowed`,
    ADD COLUMN IF NOT EXISTS `admin_requests_allowed` TINYINT(1) NOT NULL DEFAULT 1 AFTER `admin_messages_allowed`;

-- ---------------------------------------------------------------------------
-- Post-review hardening migration. Safe to re-run. Requires MariaDB
-- 10.0.2+ for "ADD ... IF NOT EXISTS" (MySQL 8.0.29+ only covers ADD COLUMN,
-- not ADD INDEX/KEY - on plain MySQL, drop the "IF NOT EXISTS" here if it
-- errors and just run this block once).
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

ALTER TABLE `phone_services_plus_channels`
    ADD UNIQUE KEY IF NOT EXISTS `number_contact` (`number_id`, `contact_number`),
    ADD INDEX IF NOT EXISTS `contact_archived_updated` (`contact_number`, `archived_by_contact`, `updated_at`),
    ADD INDEX IF NOT EXISTS `number_archived_updated` (`number_id`, `archived_by_company`, `updated_at`);

ALTER TABLE `phone_services_plus_messages`
    ADD INDEX IF NOT EXISTS `channel_created` (`channel_id`, `created_at`);

ALTER TABLE `phone_services_plus_calls`
    ADD COLUMN IF NOT EXISTS `lb_call_id` BIGINT UNSIGNED DEFAULT NULL AFTER `number_id`,
    ADD INDEX IF NOT EXISTS `company_created` (`company_id`, `created_at`),
    ADD INDEX IF NOT EXISTS `customer_created` (`customer_number`, `created_at`),
    ADD INDEX IF NOT EXISTS `lb_call_id` (`lb_call_id`);

ALTER TABLE `phone_services_plus_requests`
    ADD INDEX IF NOT EXISTS `company_status_created` (`company_id`, `status`, `created_at`),
    ADD INDEX IF NOT EXISTS `requester_created` (`requester_number`, `created_at`),
    ADD INDEX IF NOT EXISTS `employee_status` (`employee_identifier`, `status`);

-- ---------------------------------------------------------------------------
-- Round 3 review migration. Safe to re-run.
-- ---------------------------------------------------------------------------
ALTER TABLE `phone_services_plus_request_types`
    ADD COLUMN IF NOT EXISTS `enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `competition_enabled`;
