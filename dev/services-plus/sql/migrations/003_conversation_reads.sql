-- Services+ migration 003: per-conversation read markers.
-- UPGRADE MIGRATION ONLY. Fresh installations receive this table from
-- sql/install.sql. Safe to re-run after migration 002.

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

-- Carry the aggregate markers from migration 002 into every existing chat,
-- preventing already-read history from becoming unread once this migration
-- switches the application to per-conversation counters.
INSERT INTO `phone_services_plus_conversation_reads`
    (`owner_key`, `viewer_scope`, `channel_id`, `last_read_id`)
SELECT rs.owner_key, 'customer', c.id, rs.last_read_id
FROM `phone_services_plus_read_state` rs
JOIN `phone_services_plus_channels` c ON c.contact_number = rs.owner_key
WHERE rs.scope = 'activity_messages'
ON DUPLICATE KEY UPDATE last_read_id = GREATEST(last_read_id, VALUES(last_read_id));

INSERT INTO `phone_services_plus_conversation_reads`
    (`owner_key`, `viewer_scope`, `channel_id`, `last_read_id`)
SELECT rs.owner_key, 'employee', c.id, rs.last_read_id
FROM `phone_services_plus_read_state` rs
JOIN `phone_services_plus_numbers` n ON n.company_id = rs.company_id
JOIN `phone_services_plus_channels` c ON c.number_id = n.id
WHERE rs.scope = 'company_messages'
ON DUPLICATE KEY UPDATE last_read_id = GREATEST(last_read_id, VALUES(last_read_id));
