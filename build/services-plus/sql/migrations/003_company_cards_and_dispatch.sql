ALTER TABLE `services_plus_companies`
  ADD COLUMN `background_image` VARCHAR(500) NULL AFTER `logo`,
  ADD COLUMN `dispatch_mode` ENUM('ring_all','random','dispatch_only') NOT NULL DEFAULT 'ring_all' AFTER `messages_enabled`;

UPDATE `services_plus_companies`
SET `background_image` = `logo`
WHERE (`background_image` IS NULL OR `background_image` = '') AND `logo` IS NOT NULL;

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (3, 'company_cards_and_dispatch');
