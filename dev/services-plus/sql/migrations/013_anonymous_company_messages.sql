-- LB Phone's `lb-phone:newCompanyMessage` event carries an `anonymous` flag when a
-- citizen messages a business with a hidden number. The real number is still needed
-- server-side (conversation grouping, employee replies via SendMessage), so it keeps
-- being stored; this column lets read paths hide it from employees the same way an
-- anonymous caller's number is already hidden in call history.

ALTER TABLE `services_plus_inbox_conversations`
  ADD COLUMN `anonymous` TINYINT(1) NOT NULL DEFAULT 0 AFTER `external_number`;

INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (13, 'anonymous_company_messages');
