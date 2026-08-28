-- Services+ schema - FRESH INSTALL ONLY. Run this once against the same
-- database lb-phone uses, on a brand new install with none of these tables
-- yet. Table prefix `phone_services_plus_` keeps this fully separate from
-- lb-phone's own `phone_services_*` tables (the native Companies app).
--
-- Every CREATE TABLE below already reflects the current, final schema (no
-- ALTER TABLE needed after this file on a fresh install). If you're
-- *upgrading* an existing Services+ database instead, do NOT re-run this
-- file - apply the numbered files in `sql/migrations/` instead (see that
-- directory's README, plan review round 5 §9).

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

    -- Soft-delete only (plan review round 4 §9): company_id cascades all the
    -- way down to numbers, channels, messages and call history, so a real
    -- DELETE here would take a company's entire chat and call history with
    -- it. "Deleting" a company from the admin area just clears this instead.
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

    -- Soft-delete only (plan review round 5 §1): number_id cascades down to
    -- channels, messages, and call history, so a real DELETE here would take
    -- that number's entire chat and call history with it - exactly the same
    -- reasoning as `phone_services_plus_companies.enabled` above. Admin's
    -- "remove number" action just clears this instead.
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,

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
    -- for the same pair. getOrCreateChannel() relies on this via INSERT IGNORE.
    UNIQUE KEY `number_contact` (`number_id`, `contact_number`),
    KEY `contact_archived_updated` (`contact_number`, `archived_by_contact`, `updated_at`),
    KEY `number_archived_updated` (`number_id`, `archived_by_company`, `updated_at`),
    FOREIGN KEY (`number_id`) REFERENCES `phone_services_plus_numbers`(`id`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `phone_services_plus_messages` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `channel_id` INT UNSIGNED NOT NULL,
    -- Denormalized for bounded company analytics. The channel/number FKs
    -- remain the authoritative conversation relationship.
    `company_id` INT UNSIGNED NOT NULL,

    `sender` VARCHAR(15) NOT NULL,
    -- Stable employee identity for company messages. NULL for customers and
    -- trusted company-level exports that do not impersonate an employee.
    `sender_identifier` VARCHAR(100) DEFAULT NULL,
    -- Which *side* sent this - the UI aligns chat bubbles by this, not by
    -- comparing `sender` against the viewer's own number (that only ever
    -- worked for the one employee who actually sent it, plan review round
    -- 4 §3). `sender` itself is kept server-side only, for logging/audit -
    -- it is never sent back to any client (plan review round 5 §5).
    `sender_type` ENUM('customer', 'company') NOT NULL DEFAULT 'customer',
    `content` VARCHAR(1000) NOT NULL,
    `pos_x` FLOAT DEFAULT NULL,
    `pos_y` FLOAT DEFAULT NULL,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    -- channel_created still serves openConversation's own
    -- `ORDER BY created_at DESC` page-0 fetch (see server/main.lua) -
    -- channel_id_id is what getMessages' `WHERE channel_id = ? AND id < ?
    -- ORDER BY id DESC` cursor pagination actually wants (plan review round
    -- 6 §5): built around the column it filters and orders by, not created_at.
    KEY `channel_created` (`channel_id`, `created_at`),
    KEY `channel_id_id` (`channel_id`, `id`),
    KEY `company_sender_daily` (`company_id`, `sender_type`, `created_at`, `sender_identifier`),
    FOREIGN KEY (`channel_id`) REFERENCES `phone_services_plus_channels`(`id`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Emoji reactions are separate from message content so they can be toggled
-- independently and counted without rewriting the original message row.
CREATE TABLE IF NOT EXISTS `phone_services_plus_message_reactions` (
    `message_id` INT UNSIGNED NOT NULL,
    `reactor_key` VARCHAR(120) NOT NULL,
    `emoji` VARCHAR(16) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`message_id`, `reactor_key`, `emoji`),
    KEY `message_emoji` (`message_id`, `emoji`),
    CONSTRAINT `fk_sp_msg_reactions_message_id_v009`
        FOREIGN KEY (`message_id`) REFERENCES `phone_services_plus_messages`(`id`) ON DELETE CASCADE
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
    `employee_identifier` VARCHAR(100) DEFAULT NULL,
    `state` VARCHAR(10) NOT NULL DEFAULT 'ringing', -- ringing | answered | missed

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ended_at` TIMESTAMP NULL DEFAULT NULL,

    PRIMARY KEY (`id`),
    KEY `company_created` (`company_id`, `created_at`),
    KEY `company_state_daily` (`company_id`, `state`, `created_at`, `employee_identifier`),
    KEY `customer_created` (`customer_number`, `created_at`),
    KEY `lb_call_id` (`lb_call_id`),
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

-- Service-wide admin settings. Values are strings so future settings can
-- share this small table without one schema migration per new option.
CREATE TABLE IF NOT EXISTS `phone_services_plus_settings` (
    `key` VARCHAR(50) NOT NULL,
    `value` VARCHAR(255) NOT NULL,

    PRIMARY KEY (`key`)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

INSERT IGNORE INTO `phone_services_plus_settings` (`key`, `value`)
VALUES ('active_request_disconnect_grace_minutes', '5');

-- Per-phone language used by server-generated LB Phone notifications.
-- Keeping this separate from Config.Locale lets two players use different
-- languages on the same server.
CREATE TABLE IF NOT EXISTS `phone_services_plus_preferences` (
    `phone_number` VARCHAR(15) NOT NULL,
    `locale` VARCHAR(5) NOT NULL DEFAULT 'en',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`phone_number`)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Persistent high-water marks for realtime badges. `owner_key` is the
-- customer's current phone number for Activity, and the framework player
-- identifier for employee-side Company badges. company_id is deliberately
-- not a foreign key: 0 denotes personal Activity and employee read history
-- should survive a company being soft-deleted.
CREATE TABLE IF NOT EXISTS `phone_services_plus_read_state` (
    `owner_key` VARCHAR(100) NOT NULL,
    `scope` VARCHAR(32) NOT NULL,
    `company_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `last_read_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`owner_key`, `scope`, `company_id`)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- State transitions need their own monotonic ids: request rows retain their
-- id while changing status, and call rows can become missed after their id
-- was already marked as seen. event_key makes repeated lifecycle delivery
-- idempotent while every player keeps an independent marker in read_state.
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

-- Per-conversation read markers. Unlike the aggregate area markers above,
-- these allow every chat row to expose its own unread counter. Customers
-- are keyed by phone number; employees by their stable framework identifier.
CREATE TABLE IF NOT EXISTS `phone_services_plus_conversation_reads` (
    `owner_key` VARCHAR(100) NOT NULL,
    `viewer_scope` VARCHAR(16) NOT NULL,
    `channel_id` INT UNSIGNED NOT NULL,
    `last_read_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`owner_key`, `viewer_scope`, `channel_id`),
    KEY `channel_scope` (`channel_id`, `viewer_scope`),
    FOREIGN KEY (`channel_id`) REFERENCES `phone_services_plus_channels`(`id`) ON DELETE CASCADE
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
    -- Stable public/API key. Unlike the display name, this never changes
    -- after creation and is not overloaded with presentation concerns.
    `identifier` VARCHAR(100) NOT NULL,
    `icon` VARCHAR(100) DEFAULT NULL,
    `description` VARCHAR(255) DEFAULT NULL,

    `location_mode` VARCHAR(10) NOT NULL DEFAULT 'auto',
    `passenger_count` TINYINT(1) NOT NULL DEFAULT 0,
    `passenger_mode` ENUM('disabled', 'optional', 'required') NOT NULL DEFAULT 'disabled',
    `count_label` VARCHAR(50) NOT NULL DEFAULT 'Passenger count',
    `description_enabled` TINYINT(1) NOT NULL DEFAULT 0,
    `note_mode` ENUM('disabled', 'optional', 'required') NOT NULL DEFAULT 'disabled',
    `competition_enabled` TINYINT(1) NOT NULL DEFAULT 0,

    -- Soft-delete only (plan review round 3 §9): request_type_id on
    -- phone_services_plus_requests is ON DELETE CASCADE, so a physical
    -- delete here would take the type's entire request history - open,
    -- active and historical alike - down with it. "Deleting" a type from
    -- the admin area just clears this instead.
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,

    -- Technical key of the "special feature" this type exposes (e.g.
    -- 'taxi_pricing'), NULL for none. Only request-types/taxi/server.lua
    -- (and any future feature module) knows what a given key means or reads
    -- phone_services_plus_company_features for it - this column is just the
    -- admin-facing on/off switch per type, same role admin_*_allowed plays
    -- for companies.
    `feature` VARCHAR(50) DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `request_type_identifier` (`identifier`),
    FOREIGN KEY (`category_id`) REFERENCES `phone_services_plus_categories`(`id`) ON DELETE SET NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Generic per-company, per-request-type feature config (e.g. a taxi
-- company's Taxameter billing mode/rate). `config` is opaque JSON that only
-- the feature module named by `feature` interprets - this table itself
-- doesn't know or care what's inside it, the same way
-- phone_services_plus_settings doesn't know what its values mean beyond a
-- string. Kept separate from phone_services_plus_companies/_request_types
-- (plan discussion) so those stay generic across every business type
-- instead of accumulating one column per feature.
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

CREATE TABLE IF NOT EXISTS `phone_services_plus_requests` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `request_type_id` INT UNSIGNED NOT NULL,
    `company_id` INT UNSIGNED DEFAULT NULL,

    `requester_number` VARCHAR(15) NOT NULL,
    `employee_identifier` VARCHAR(100) DEFAULT NULL,
    `employee_disconnected_at` TIMESTAMP NULL DEFAULT NULL,
    `status` VARCHAR(10) NOT NULL DEFAULT 'open',

    `pos_x` FLOAT DEFAULT NULL,
    `pos_y` FLOAT DEFAULT NULL,
    `passenger_count` INT DEFAULT NULL,
    `description` VARCHAR(255) DEFAULT NULL,

    -- Feature bookkeeping (request-types/taxi/server.lua and friends), all
    -- NULL/zero for requests whose type has no feature. accepted_at tracks
    -- dispatch acceptance; service_started_at begins the actual billable
    -- service (for taxis: arrival at pickup). travelled_distance is sampled
    -- periodically during that service, never once from accept to pickup.
    -- pickup_distance remains only for backwards compatibility with rows
    -- written before the real journey meter. feature_data freezes the tariff
    -- at acceptance and later stores the final result.
    `accepted_at` TIMESTAMP NULL DEFAULT NULL,
    `service_started_at` TIMESTAMP NULL DEFAULT NULL,
    `travelled_distance` FLOAT NOT NULL DEFAULT 0,
    `pickup_distance` FLOAT DEFAULT NULL,
    `feature_data` JSON DEFAULT NULL,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    KEY `company_status_created` (`company_id`, `status`, `created_at`),
    KEY `requester_created` (`requester_number`, `created_at`),
    KEY `requester_status_created` (`requester_number`, `status`, `created_at`),
    KEY `status_created_id` (`status`, `created_at`, `id`),
    KEY `employee_status` (`employee_identifier`, `status`),
    KEY `company_status_daily` (`company_id`, `status`, `updated_at`, `employee_identifier`),
    KEY `disconnected_status` (`status`, `employee_disconnected_at`),
    FOREIGN KEY (`request_type_id`) REFERENCES `phone_services_plus_request_types`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`company_id`) REFERENCES `phone_services_plus_companies`(`id`) ON DELETE SET NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Upgrading an existing Services+ install instead of setting one up fresh?
-- Apply the numbered files in sql/migrations/ instead of this file - see
-- that directory's README.
