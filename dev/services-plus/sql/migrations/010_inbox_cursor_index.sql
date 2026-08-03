ALTER TABLE `services_plus_inbox_conversations`
  ADD INDEX `idx_services_plus_inbox_company_number_activity` (`company_id`, `number_id`, `last_message_at`, `id`);

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (10, 'inbox_cursor_index');
