-- Services+ schema - UPGRADE MIGRATIONS ONLY. Do NOT run this against a
-- brand new database - use sql/install.sql for a fresh install instead,
-- whose CREATE TABLE statements already include everything below.
--
-- This file exists only for installs that ran an older sql/install.sql
-- before these columns/indexes existed (plan review round 5 §9: a fresh
-- Tebex customer install should never have to hand-edit SQL for a plain
-- MySQL vs. MariaDB syntax difference that migrating installs alone need to
-- worry about). Every block is safe to re-run.
--
-- Requires MySQL 8.0.29+ / MariaDB 10.0.2+ for "ADD COLUMN IF NOT EXISTS".
-- "ADD INDEX/KEY IF NOT EXISTS" further down is MariaDB-only (10.0.2+) -
-- plain MySQL does not support that syntax at all (a syntax error, not a
-- harmless no-op) - on plain MySQL, drop the "IF NOT EXISTS" from those
-- specific lines and just run this file once.

-- ---------------------------------------------------------------------------
-- Phase 3 migration.
-- ---------------------------------------------------------------------------
ALTER TABLE `phone_services_plus_companies`
    ADD COLUMN IF NOT EXISTS `admin_calls_allowed` TINYINT(1) NOT NULL DEFAULT 1 AFTER `requests_enabled`,
    ADD COLUMN IF NOT EXISTS `admin_messages_allowed` TINYINT(1) NOT NULL DEFAULT 1 AFTER `admin_calls_allowed`,
    ADD COLUMN IF NOT EXISTS `admin_requests_allowed` TINYINT(1) NOT NULL DEFAULT 1 AFTER `admin_messages_allowed`;

-- ---------------------------------------------------------------------------
-- Post-review hardening migration.
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

-- `number_contact` itself is NOT added here - a fresh install.sql already
-- declares it directly on CREATE TABLE, so adding it again here would be
-- both redundant for any install using this version of the file, and a
-- syntax error on plain MySQL (which doesn't support "ADD ... IF NOT
-- EXISTS" for keys/indexes at all). Installs that upgraded through an
-- earlier version of this file already picked it up from *that* run.
ALTER TABLE `phone_services_plus_channels`
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
-- Round 3 review migration.
-- ---------------------------------------------------------------------------
ALTER TABLE `phone_services_plus_request_types`
    ADD COLUMN IF NOT EXISTS `enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `competition_enabled`;

-- ---------------------------------------------------------------------------
-- Round 4 review migration.
-- ---------------------------------------------------------------------------
ALTER TABLE `phone_services_plus_messages`
    ADD COLUMN IF NOT EXISTS `sender_type` ENUM('customer', 'company') NOT NULL DEFAULT 'customer' AFTER `sender`;

-- Backfill existing rows for installs that had messages before sender_type
-- existed - anything not sent by the channel's own contact number was sent
-- by the company side.
UPDATE `phone_services_plus_messages` m
    JOIN `phone_services_plus_channels` c ON c.id = m.channel_id
SET m.sender_type = 'company'
WHERE m.sender <> c.contact_number;

-- ---------------------------------------------------------------------------
-- Round 5 review migration.
-- ---------------------------------------------------------------------------

-- Numbers now soft-delete the same way companies and request types already
-- do (plan review round 5 §1) - number_id cascades down to channels,
-- messages, and call history, so a real DELETE used to take all of that
-- with it. admin:deleteNumber now just clears this instead.
ALTER TABLE `phone_services_plus_numbers`
    ADD COLUMN IF NOT EXISTS `enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `mailbox_enabled`;
