-- Phase 1 baseline. New installations should apply ../install.sql.
-- Existing pre-release installations may safely apply the same idempotent schema.
INSERT IGNORE INTO `services_plus_schema_migrations` (`version`, `name`)
VALUES (1, 'phase1_foundation');
