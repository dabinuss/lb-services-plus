-- Incoming requests previously always forced the phone/app open on the receiving
-- employee's client. That is gone now; requests behave like calls (a notification,
-- never a forced takeover). This column lets a company opt into an actionable
-- notification (Accept/Decline buttons, and the in-app call-style screen when the app
-- is already open) instead of a purely informational one - meant for companies where
-- speed matters (taxi, PD, EMS), not the default for every company.

ALTER TABLE `services_plus_companies`
  ADD COLUMN `request_notification_actionable` TINYINT(1) NOT NULL DEFAULT 0 AFTER `dispatch_mode`;

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (14, 'request_notification_actionable');
