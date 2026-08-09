-- Captures the number's distribution mode at the moment a call was queued, so call
-- history reflects the mode that actually applied even if the number is reconfigured
-- later. Queue duration and call duration are derived from the existing created_at,
-- accepted_at and ended_at timestamps at read time and do not require stored columns.

ALTER TABLE `services_plus_call_queue`
  ADD COLUMN `distribution` ENUM('ring_all','random','dispatch_only') NULL AFTER `number_id`;

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (12, 'call_duration_and_distribution');
