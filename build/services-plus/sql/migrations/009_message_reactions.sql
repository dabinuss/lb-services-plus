-- Services+ migration 009: persistent emoji reactions for messages.
-- Fresh installations already receive this table via install.sql.

CREATE TABLE IF NOT EXISTS `phone_services_plus_message_reactions` (
    `message_id` INT UNSIGNED NOT NULL,
    `reactor_key` VARCHAR(120) NOT NULL,
    `emoji` VARCHAR(16) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`message_id`, `reactor_key`, `emoji`),
    KEY `message_emoji` (`message_id`, `emoji`),
    CONSTRAINT `fk_sp_msg_reactions_message_id_v009`
        FOREIGN KEY (`message_id`) REFERENCES `phone_services_plus_messages` (`id`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
