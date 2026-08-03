ServicesPlus.Repository = ServicesPlus.Repository or {}

local Repository = ServicesPlus.Repository

local function decode(value, fallback)
    if type(value) == "table" then return value end
    if not value or value == "" then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and result or fallback
end

function Repository.LoadCategorySettings()
    local rows = MySQL.query.await("SELECT `id`, `definition` FROM `services_plus_categories`") or {}
    local result = {}
    for _, row in ipairs(rows) do result[row.id] = decode(row.definition, {}) end
    return result
end

function Repository.SaveCategorySettings(categoryId, definition)
    return MySQL.update.await([=[
        INSERT INTO `services_plus_categories` (`id`, `definition`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `definition` = VALUES(`definition`)
    ]=], { categoryId, json.encode(definition) }) ~= nil
end

function Repository.SeedConfiguredCompanies()
    if #Config.Companies == 0 then return end
    local existingCount = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM `services_plus_companies`")) or 0
    if existingCount > 0 then return end

    local companyValues = {}
    local companyRows = {}
    local numberValues = {}
    local numberRows = {}

    for _, company in ipairs(Config.Companies) do
        companyRows[#companyRows + 1] = "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        local values = { company.id, company.job, company.displayName, company.logo, company.backgroundImage, company.categoryId, company.description or "", company.location or "", company.openingHours or "", json.encode(company.keywords or {}), company.requestsEnabled and 1 or 0, company.messagesEnabled ~= false and 1 or 0, company.dispatchMode or "ring_all" }
        for _, value in ipairs(values) do companyValues[#companyValues + 1] = value end

        for _, number in ipairs(company.numbers or {}) do
            numberRows[#numberRows + 1] = "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            local row = { number.id, company.id, number.label, number.number, number.distribution, number.sharedInbox ~= false and 1 or 0,
                number.enabled ~= false and 1 or 0, number.callsEnabled ~= false and 1 or 0, number.inboxEnabled ~= false and 1 or 0,
                number.requestsEnabled ~= false and 1 or 0, number.publicVisible ~= false and 1 or 0 }
            for _, value in ipairs(row) do numberValues[#numberValues + 1] = value end
        end
    end

    MySQL.query.await(([=[
        INSERT INTO `services_plus_companies`
            (`id`, `job`, `display_name`, `logo`, `background_image`, `category_id`, `description`, `location`, `opening_hours`, `keywords`, `requests_enabled`, `messages_enabled`, `dispatch_mode`)
        VALUES %s
        ON DUPLICATE KEY UPDATE `job` = VALUES(`job`)
    ]=]):format(table.concat(companyRows, ",")), companyValues)

    if #numberRows > 0 then
        MySQL.query.await(([=[
            INSERT INTO `services_plus_company_numbers`
                (`id`, `company_id`, `label`, `number`, `distribution`, `shared_inbox`, `enabled`, `calls_enabled`, `inbox_enabled`, `requests_enabled`, `public_visible`)
            VALUES %s
            ON DUPLICATE KEY UPDATE `company_id` = VALUES(`company_id`)
        ]=]):format(table.concat(numberRows, ",")), numberValues)
    end
end

function Repository.LoadCompanies()
    local companies = MySQL.query.await([=[
        SELECT `id`, `job`, `display_name`, `logo`, `background_image`, `category_id`, `description`, `location`,
               `opening_hours`, `keywords`, `requests_enabled`, `messages_enabled`, `dispatch_mode`
        FROM `services_plus_companies`
        WHERE `deleted_at` IS NULL
        ORDER BY `display_name`, `id`
        LIMIT ?
    ]=], { Config.MaxCompanies }) or {}
    local numbers = MySQL.query.await([=[
        SELECT `id`, `company_id`, `label`, `number`, `distribution`, `shared_inbox`, `enabled`, `calls_enabled`,
               `inbox_enabled`, `requests_enabled`, `public_visible`
        FROM `services_plus_company_numbers`
        WHERE `deleted_at` IS NULL
        ORDER BY `company_id`, `label`, `id`
    ]=]) or {}
    local byId = {}
    for _, row in ipairs(companies) do
        local company = {
            id = row.id,
            job = row.job,
            displayName = row.display_name,
            logo = row.logo,
            backgroundImage = row.background_image,
            categoryId = row.category_id,
            description = row.description,
            location = row.location,
            openingHours = row.opening_hours,
            keywords = decode(row.keywords, {}),
            requestsEnabled = row.requests_enabled == 1,
            messagesEnabled = row.messages_enabled == 1,
            dispatchMode = row.dispatch_mode or "ring_all",
            numbers = {}
        }
        byId[company.id] = company
    end
    for _, row in ipairs(numbers) do
        local company = byId[row.company_id]
        if company then
            local number = {
                id = row.id,
                label = row.label,
                number = row.number,
                distribution = row.distribution,
                sharedInbox = row.shared_inbox == 1,
                enabled = row.enabled == 1,
                callsEnabled = row.calls_enabled == 1,
                inboxEnabled = row.inbox_enabled == 1,
                requestsEnabled = row.requests_enabled == 1,
                publicVisible = row.public_visible == 1
            }
            company.numbers[#company.numbers + 1] = number
        end
    end
    return byId
end

function Repository.GetEmployeeSettings(identifier, companyId)
    return MySQL.single.await([=[
        SELECT `dispatch_preference`, `explicit_leader`
        FROM `services_plus_employee_settings`
        WHERE `identifier` = ? AND `company_id` = ?
    ]=], { identifier, companyId })
end

function Repository.SaveDispatchPreference(identifier, companyId, enabled)
    MySQL.update.await([=[
        INSERT INTO `services_plus_employee_settings` (`identifier`, `company_id`, `dispatch_preference`)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `dispatch_preference` = VALUES(`dispatch_preference`)
    ]=], { identifier, companyId, enabled and 1 or 0 })
end

function Repository.UpdateNumberOperations(companyId, numbers)
    local queries = {}
    for _, number in ipairs(numbers or {}) do
        queries[#queries + 1] = {
            query = [=[
                UPDATE `services_plus_company_numbers`
                SET `enabled` = ?, `calls_enabled` = ?, `inbox_enabled` = ?, `requests_enabled` = ?, `public_visible` = ?, `distribution` = ?
                WHERE `id` = ? AND `company_id` = ?
            ]=],
            values = { number.enabled and 1 or 0, number.callsEnabled and 1 or 0, number.inboxEnabled and 1 or 0,
                number.requestsEnabled and 1 or 0, number.publicVisible and 1 or 0, number.distribution, number.id, companyId }
        }
    end
    return #queries == 0 or MySQL.transaction.await(queries)
end

function Repository.UpdateCompany(companyId, patch)
    return MySQL.update.await([=[
        UPDATE `services_plus_companies`
        SET `display_name` = ?, `logo` = ?, `background_image` = ?, `category_id` = ?, `description` = ?,
            `location` = ?, `opening_hours` = ?, `requests_enabled` = ?, `messages_enabled` = ?
        WHERE `id` = ?
    ]=], {
        patch.displayName, patch.logo, patch.backgroundImage, patch.categoryId, patch.description, patch.location,
        patch.openingHours, patch.requestsEnabled and 1 or 0, patch.messagesEnabled and 1 or 0, companyId
    })
end

function Repository.UpdateCompanyOperations(companyId, patch)
    return MySQL.update.await([=[
        UPDATE `services_plus_companies`
        SET `requests_enabled` = ?, `messages_enabled` = ?, `dispatch_mode` = ?
        WHERE `id` = ?
    ]=], { patch.requestsEnabled and 1 or 0, patch.messagesEnabled and 1 or 0, patch.dispatchMode, companyId })
end

function Repository.SaveCompany(company)
    local queries = {
        {
            query = [=[
                INSERT INTO `services_plus_companies`
                    (`id`, `job`, `display_name`, `logo`, `background_image`, `category_id`, `description`, `location`, `opening_hours`, `keywords`, `requests_enabled`, `messages_enabled`, `dispatch_mode`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE `job` = VALUES(`job`), `display_name` = VALUES(`display_name`),
                    `logo` = VALUES(`logo`), `background_image` = VALUES(`background_image`), `category_id` = VALUES(`category_id`), `description` = VALUES(`description`),
                    `location` = VALUES(`location`), `opening_hours` = VALUES(`opening_hours`), `keywords` = VALUES(`keywords`),
                    `requests_enabled` = VALUES(`requests_enabled`), `messages_enabled` = VALUES(`messages_enabled`), `dispatch_mode` = VALUES(`dispatch_mode`),
                    `deleted_at` = NULL, `deleted_by` = NULL
            ]=],
            values = { company.id, company.job, company.displayName, company.logo, company.backgroundImage, company.categoryId, company.description,
                company.location, company.openingHours, json.encode(company.keywords), company.requestsEnabled and 1 or 0,
                company.messagesEnabled and 1 or 0, company.dispatchMode }
        },
    }

    if #company.numbers > 0 then
        local rows = {}
        local values = {}
        local ids = {}
        for index, number in ipairs(company.numbers) do
            rows[#rows + 1] = "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            local numberId = number.id or ("%s-%d"):format(company.id, index)
            ids[#ids + 1] = numberId
            local row = { numberId, company.id, number.label, number.number, number.distribution, number.sharedInbox and 1 or 0,
                number.enabled and 1 or 0, number.callsEnabled and 1 or 0, number.inboxEnabled and 1 or 0,
                number.requestsEnabled and 1 or 0, number.publicVisible and 1 or 0 }
            for _, value in ipairs(row) do values[#values + 1] = value end
        end
        local deleteValues = { company.id }
        for _, id in ipairs(ids) do deleteValues[#deleteValues + 1] = id end
        queries[#queries + 1] = {
            query = ("UPDATE `services_plus_company_numbers` SET `deleted_at` = CURRENT_TIMESTAMP WHERE `company_id` = ? AND `deleted_at` IS NULL AND `id` NOT IN (%s)"):format(table.concat((function() local placeholders = {}; for _ = 1, #ids do placeholders[#placeholders + 1] = "?" end; return placeholders end)(), ",")),
            values = deleteValues
        }
        queries[#queries + 1] = {
            query = ([=[
                INSERT INTO `services_plus_company_numbers`
                    (`id`, `company_id`, `label`, `number`, `distribution`, `shared_inbox`, `enabled`, `calls_enabled`, `inbox_enabled`, `requests_enabled`, `public_visible`)
                VALUES %s
                ON DUPLICATE KEY UPDATE `company_id` = VALUES(`company_id`), `label` = VALUES(`label`), `number` = VALUES(`number`),
                  `distribution` = VALUES(`distribution`), `shared_inbox` = VALUES(`shared_inbox`), `enabled` = VALUES(`enabled`),
                  `calls_enabled` = VALUES(`calls_enabled`), `inbox_enabled` = VALUES(`inbox_enabled`), `requests_enabled` = VALUES(`requests_enabled`),
                  `public_visible` = VALUES(`public_visible`), `deleted_at` = NULL
            ]=]):format(table.concat(rows, ",")),
            values = values
        }
    else
        queries[#queries + 1] = { query = "UPDATE `services_plus_company_numbers` SET `deleted_at` = CURRENT_TIMESTAMP WHERE `company_id` = ? AND `deleted_at` IS NULL", values = { company.id } }
    end

    return MySQL.transaction.await(queries)
end

-- Soft-deleted companies and numbers keep their unique job/number values reserved
-- (see migration 011), so a new or revived record must not silently collide with one.
function Repository.JobInUse(job, excludeCompanyId)
    return MySQL.scalar.await("SELECT `id` FROM `services_plus_companies` WHERE `job` = ? AND `id` <> ? LIMIT 1", { job, excludeCompanyId or "" }) ~= nil
end

function Repository.NumberInUse(number, excludeNumberId)
    return MySQL.scalar.await("SELECT `id` FROM `services_plus_company_numbers` WHERE `number` = ? AND `id` <> ? LIMIT 1", { number, excludeNumberId or "" }) ~= nil
end

function Repository.DeleteCompany(companyId, actorIdentifier)
    return MySQL.update.await("UPDATE `services_plus_companies` SET `deleted_at` = CURRENT_TIMESTAMP, `deleted_by` = ? WHERE `id` = ? AND `deleted_at` IS NULL", { actorIdentifier, companyId })
end

function Repository.LoadSettings()
    local rows = MySQL.query.await("SELECT `setting_key`, `setting_value` FROM `services_plus_settings`") or {}
    local settings = {}
    for _, row in ipairs(rows) do settings[row.setting_key] = decode(row.setting_value, nil) end
    return settings
end

function Repository.UpdateSettings(settings)
    return MySQL.transaction.await({
        { query = "INSERT INTO `services_plus_settings` (`setting_key`, `setting_value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `setting_value` = VALUES(`setting_value`)", values = { "directoryTitle", json.encode(settings.directoryTitle) } },
        { query = "INSERT INTO `services_plus_settings` (`setting_key`, `setting_value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `setting_value` = VALUES(`setting_value`)", values = { "callsEnabled", json.encode(settings.callsEnabled) } },
        { query = "INSERT INTO `services_plus_settings` (`setting_key`, `setting_value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `setting_value` = VALUES(`setting_value`)", values = { "requestsEnabled", json.encode(settings.requestsEnabled) } }
    })
end

function Repository.CreateRequest(identifier, companyId, details, location)
    local payload = json.encode({ details = details, location = location })
    local requestId = MySQL.insert.await([=[
        INSERT INTO `services_plus_requests`
            (`creator_identifier`, `company_id`, `template_id`, `status`, `payload`)
        VALUES (?, ?, 'general', 'pending', ?)
    ]=], { identifier, companyId, payload })
    return requestId
end

function Repository.RecordCall(identifier, companyId, numberId)
    return MySQL.insert.await([=[
        INSERT INTO `services_plus_call_history`
            (`caller_identifier`, `company_id`, `number_id`, `result`, `metadata`)
        VALUES (?, ?, ?, 'initiated', '{}')
    ]=], { identifier, companyId, numberId })
end

function Repository.AttachCallHistory(identifier, companyId, numberId, queueId)
    if not identifier then return end
    MySQL.update.await([=[
        UPDATE `services_plus_call_history` SET `metadata` = JSON_OBJECT('queueId', ?)
        WHERE `id` = (SELECT `id` FROM (SELECT `id` FROM `services_plus_call_history`
          WHERE `caller_identifier` = ? AND `company_id` = ? AND `number_id` = ? AND `result` = 'initiated'
          ORDER BY `id` DESC LIMIT 1) latest)
    ]=], { queueId, identifier, companyId, numberId })
end

function Repository.GetMyActivity(identifier, limit)
    local calls = MySQL.query.await([=[
        SELECT h.`id`, h.`company_id` AS `companyId`, c.`display_name` AS `displayName`, n.`number`, h.`result`, h.`created_at`
        FROM `services_plus_call_history` h
        JOIN `services_plus_companies` c ON c.`id` = h.`company_id`
        JOIN `services_plus_company_numbers` n ON n.`id` = h.`number_id`
        WHERE h.`caller_identifier` = ?
        ORDER BY h.`id` DESC LIMIT ?
    ]=], { identifier, limit }) or {}
    local requests = MySQL.query.await([=[
        SELECT r.`id`, r.`company_id` AS `companyId`, c.`display_name` AS `companyName`, r.`request_label` AS `requestLabel`,
          r.`status`, r.`phase_id` AS `phaseId`, r.`target_number_id` AS `targetNumberId`, r.`payload`, r.`created_at`, r.`updated_at`
        FROM `services_plus_requests` r
        JOIN `services_plus_companies` c ON c.`id` = r.`company_id`
        WHERE r.`creator_identifier` = ? AND r.`deleted_at` IS NULL
        ORDER BY r.`id` DESC LIMIT ?
    ]=], { identifier, limit }) or {}
    for _, request in ipairs(requests) do request.payload = decode(request.payload, {}) end
    return { calls = calls, requests = requests }
end

function Repository.CreateCallQueue(entry)
    MySQL.insert.await([=[
        INSERT INTO `services_plus_call_queue`
            (`call_token`, `lb_call_id`, `caller_identifier`, `caller_number`, `company_id`, `number_id`, `status`, `offered_identifiers`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `lb_call_id` = COALESCE(VALUES(`lb_call_id`), `lb_call_id`)
    ]=], { entry.callToken, entry.lbCallId, entry.callerIdentifier, entry.callerNumber, entry.companyId, entry.numberId, entry.status, json.encode(entry.offeredIdentifiers or {}) })
    return MySQL.single.await("SELECT * FROM `services_plus_call_queue` WHERE `call_token` = ?", { entry.callToken })
end

function Repository.GetCallQueueByToken(token)
    return MySQL.single.await("SELECT * FROM `services_plus_call_queue` WHERE `call_token` = ?", { token })
end

function Repository.GetCallQueueByLbId(callId)
    return MySQL.single.await("SELECT * FROM `services_plus_call_queue` WHERE `lb_call_id` = ?", { callId })
end

function Repository.UpdateCallOffer(id, status, identifiers)
    MySQL.update.await("UPDATE `services_plus_call_queue` SET `status` = ?, `offered_identifiers` = ? WHERE `id` = ? AND `status` IN ('queued','offered')", { status, json.encode(identifiers or {}), id })
end

function Repository.AttachLbCall(token, callId, callerIdentifier, callerNumber)
    MySQL.update.await("UPDATE `services_plus_call_queue` SET `lb_call_id` = ?, `caller_identifier` = COALESCE(?, `caller_identifier`), `caller_number` = COALESCE(?, `caller_number`) WHERE `call_token` = ?", { callId, callerIdentifier, callerNumber, token })
end

function Repository.GetQueuedCalls(companyId, limit)
    return MySQL.query.await("SELECT * FROM `services_plus_call_queue` WHERE `company_id` = ? AND `status` = 'queued' ORDER BY `id` LIMIT ?", { companyId, limit }) or {}
end

function Repository.GetQueuePosition(numberId, queueId)
    return tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM `services_plus_call_queue` WHERE `number_id` = ? AND `status` IN ('queued','offered') AND `id` <= ?", { numberId, queueId })) or 0
end

function Repository.GetNumberQueue(numberId, limit)
    limit = math.max(1, math.min(math.floor(tonumber(limit) or 100), 250))
    return MySQL.query.await("SELECT `id`, `call_token` FROM `services_plus_call_queue` WHERE `number_id` = ? AND `status` IN ('queued','offered') ORDER BY `id` LIMIT ?", { numberId, limit }) or {}
end

function Repository.AcceptCallQueue(id, identifier)
    return MySQL.update.await([=[
        UPDATE `services_plus_call_queue`
        SET `status` = 'accepted', `assigned_identifier` = ?, `accepted_at` = CURRENT_TIMESTAMP
        WHERE `id` = ? AND `status` IN ('queued','offered') AND `assigned_identifier` IS NULL
    ]=], { identifier, id }) == 1
end

function Repository.RevertCallAcceptance(id, status, identifiers)
    return MySQL.update.await([=[
        UPDATE `services_plus_call_queue`
        SET `status` = ?, `assigned_identifier` = NULL, `accepted_at` = NULL, `offered_identifiers` = ?
        WHERE `id` = ? AND `status` = 'accepted'
    ]=], { status, json.encode(identifiers or {}), id }) == 1
end

function Repository.EndCallQueue(id, result)
    MySQL.update.await("UPDATE `services_plus_call_queue` SET `status` = 'ended', `ended_at` = CURRENT_TIMESTAMP WHERE `id` = ? AND `status` <> 'ended'", { id })
    MySQL.update.await("UPDATE `services_plus_call_history` SET `result` = ? WHERE JSON_UNQUOTE(JSON_EXTRACT(`metadata`, '$.queueId')) = ?", { result or "ended", tostring(id) })
end

function Repository.EndOpenCalls(result)
    local rows = MySQL.query.await("SELECT `id`, `assigned_identifier` FROM `services_plus_call_queue` WHERE `status` IN ('queued','offered','accepted')") or {}
    MySQL.update.await([=[
        UPDATE `services_plus_call_history` h
        JOIN `services_plus_call_queue` q
          ON JSON_UNQUOTE(JSON_EXTRACT(h.`metadata`, '$.queueId')) = CAST(q.`id` AS CHAR)
        SET h.`result` = ?
        WHERE q.`status` IN ('queued','offered','accepted')
    ]=], { result })
    MySQL.update.await("UPDATE `services_plus_call_queue` SET `status` = 'ended', `ended_at` = CURRENT_TIMESTAMP WHERE `status` IN ('queued','offered','accepted')")
    return rows
end

function Repository.GetCompanyCalls(companyId, cursor, limit)
    return MySQL.query.await([=[
        SELECT q.`id`, q.`caller_number` AS `callerNumber`, q.`number_id` AS `numberId`, q.`status`, q.`assigned_identifier` AS `assignedIdentifier`, q.`created_at`, q.`accepted_at`, q.`ended_at`
        FROM `services_plus_call_queue` q WHERE q.`company_id` = ? AND q.`id` < ? ORDER BY q.`id` DESC LIMIT ?
    ]=], { companyId, cursor, limit }) or {}
end

function Repository.UpsertConversation(companyId, numberId, externalNumber, channelId, preview)
    MySQL.update.await([=[
        INSERT INTO `services_plus_inbox_conversations` (`company_id`, `number_id`, `external_number`, `channel_id`, `last_message`, `last_message_at`)
        VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE `channel_id` = COALESCE(VALUES(`channel_id`), `channel_id`), `last_message` = VALUES(`last_message`), `last_message_at` = CURRENT_TIMESTAMP, `deleted_at` = NULL, `deleted_by` = NULL
    ]=], { companyId, numberId, externalNumber, channelId, preview })
    return MySQL.single.await("SELECT * FROM `services_plus_inbox_conversations` WHERE `number_id` = ? AND `external_number` = ?", { numberId, externalNumber })
end

function Repository.InsertInboxMessage(conversationId, message)
    return MySQL.insert.await([=[
        INSERT IGNORE INTO `services_plus_inbox_messages`
            (`conversation_id`, `lb_message_id`, `sender_number`, `sender_identifier`, `sender_type`, `body`, `attachments`, `coords`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]=], { conversationId, message.lbMessageId, message.senderNumber, message.senderIdentifier, message.senderType, message.body, json.encode(message.attachments or {}), message.coords and json.encode(message.coords) or nil })
end

function Repository.GetCompanyConversations(companyId, identifier, cursor, limit, numberId)
    local numberClause = numberId and "AND c.`number_id` = ?" or ""
    local params = { identifier, companyId }
    if numberId then params[#params + 1] = numberId end
    params[#params + 1] = cursor.lastMessageAt
    params[#params + 1] = cursor.lastMessageAt
    params[#params + 1] = cursor.id
    params[#params + 1] = limit
    return MySQL.query.await(([=[
        SELECT c.`id`, c.`number_id` AS `numberId`, n.`label` AS `numberLabel`, c.`external_number` AS `externalNumber`, c.`last_message` AS `lastMessage`, c.`last_message_at` AS `lastMessageAt`,
          (SELECT COUNT(*) FROM `services_plus_inbox_messages` m WHERE m.`conversation_id` = c.`id` AND m.`deleted_at` IS NULL AND m.`id` > COALESCE(r.`last_read_message_id`, 0)) AS `unreadCount`
        FROM `services_plus_inbox_conversations` c
        JOIN `services_plus_company_numbers` n ON n.`id` = c.`number_id`
        LEFT JOIN `services_plus_inbox_reads` r ON r.`conversation_id` = c.`id` AND r.`identifier` = ?
        WHERE c.`company_id` = ? AND c.`deleted_at` IS NULL AND n.`enabled` = 1 AND n.`inbox_enabled` = 1 AND n.`shared_inbox` = 1 %s
          AND (c.`last_message_at` < ? OR (c.`last_message_at` = ? AND c.`id` < ?))
        ORDER BY c.`last_message_at` DESC, c.`id` DESC LIMIT ?
    ]=]):format(numberClause), params) or {}
end

function Repository.GetCompanyUnreadCounts(companyId, identifier)
    local rows = MySQL.query.await([=[
        SELECT c.`number_id` AS `numberId`, COUNT(m.`id`) AS `count`
        FROM `services_plus_inbox_conversations` c
        JOIN `services_plus_company_numbers` n ON n.`id` = c.`number_id`
        JOIN `services_plus_inbox_messages` m ON m.`conversation_id` = c.`id` AND m.`deleted_at` IS NULL
        LEFT JOIN `services_plus_inbox_reads` r ON r.`conversation_id` = c.`id` AND r.`identifier` = ?
        WHERE c.`company_id` = ? AND c.`deleted_at` IS NULL AND n.`enabled` = 1 AND n.`inbox_enabled` = 1 AND n.`shared_inbox` = 1
          AND m.`id` > COALESCE(r.`last_read_message_id`, 0)
        GROUP BY c.`number_id`
    ]=], { identifier, companyId }) or {}
    local total, byNumber = 0, {}
    for _, row in ipairs(rows) do
        local count = tonumber(row.count) or 0
        total = total + count
        byNumber[row.numberId] = count
    end
    return total, byNumber
end

function Repository.GetCompanyUnseenCallSummary(companyId, seenCallId)
    local row = MySQL.single.await([=[
        SELECT COALESCE(SUM(`id` > ?), 0) AS `count`, COALESCE(MAX(`id`), 0) AS `latestId`
        FROM `services_plus_call_queue` WHERE `company_id` = ?
    ]=], { seenCallId, companyId }) or {}
    return tonumber(row.count) or 0, tonumber(row.latestId) or 0
end

function Repository.GetCitizenConversations(externalNumber, cursor, limit)
    return MySQL.query.await([=[
        SELECT c.`id`, c.`company_id` AS `companyId`, co.`display_name` AS `companyName`, co.`logo`, c.`number_id` AS `numberId`, n.`label` AS `numberLabel`, c.`last_message` AS `lastMessage`, c.`last_message_at` AS `lastMessageAt`, 0 AS `unreadCount`
        FROM `services_plus_inbox_conversations` c
        JOIN `services_plus_companies` co ON co.`id` = c.`company_id`
        JOIN `services_plus_company_numbers` n ON n.`id` = c.`number_id`
        WHERE c.`external_number` = ? AND c.`deleted_at` IS NULL AND c.`id` < ? ORDER BY c.`id` DESC LIMIT ?
    ]=], { externalNumber, cursor, limit }) or {}
end

function Repository.GetConversation(companyId, conversationId)
    return MySQL.single.await([=[
        SELECT c.*, n.`number` AS `company_number`, n.`shared_inbox` FROM `services_plus_inbox_conversations` c
        JOIN `services_plus_company_numbers` n ON n.`id` = c.`number_id`
        WHERE c.`company_id` = ? AND c.`id` = ? AND c.`deleted_at` IS NULL
    ]=], { companyId, conversationId })
end

function Repository.DeleteConversation(conversationId, companyId, identifier)
    return MySQL.update.await([=[
        UPDATE `services_plus_inbox_conversations` SET `deleted_at` = CURRENT_TIMESTAMP, `deleted_by` = ?
        WHERE `id` = ? AND `company_id` = ? AND `deleted_at` IS NULL
    ]=], { identifier, conversationId, companyId }) == 1
end

function Repository.GetMessageReactions(messageIds, actorKey)
    if #messageIds == 0 then return {} end
    local placeholders, params = {}, { actorKey }
    for _, messageId in ipairs(messageIds) do placeholders[#placeholders + 1] = "?"; params[#params + 1] = messageId end
    local rows = MySQL.query.await(([=[
        SELECT `message_id` AS `messageId`, `emoji`, COUNT(*) AS `count`, MAX(`actor_key` = ?) AS `mine`
        FROM `services_plus_inbox_message_reactions` WHERE `message_id` IN (%s)
        GROUP BY `message_id`, `emoji` ORDER BY MIN(`created_at`)
    ]=]):format(table.concat(placeholders, ",")), params) or {}
    local grouped = {}
    for _, row in ipairs(rows) do
        grouped[row.messageId] = grouped[row.messageId] or {}
        grouped[row.messageId][#grouped[row.messageId] + 1] = { emoji = row.emoji, count = tonumber(row.count) or 0, mine = row.mine == true or tonumber(row.mine) == 1 }
    end
    return grouped
end

function Repository.GetConversationMessages(conversationId, cursor, limit, actorKey)
    local rows = MySQL.query.await([=[
        SELECT `id`, `sender_number` AS `senderNumber`, `sender_type` AS `senderType`, `body`, `attachments`, `coords`, `created_at`
        FROM `services_plus_inbox_messages` WHERE `conversation_id` = ? AND `deleted_at` IS NULL AND `id` < ? ORDER BY `id` DESC LIMIT ?
    ]=], { conversationId, cursor, limit }) or {}
    local messageIds = {}; for _, row in ipairs(rows) do messageIds[#messageIds + 1] = row.id end
    local reactions = Repository.GetMessageReactions(messageIds, actorKey)
    for _, row in ipairs(rows) do row.attachments = decode(row.attachments, {}); row.coords = decode(row.coords, nil); row.reactions = reactions[row.id] or {} end
    return rows
end

function Repository.GetMessageContext(messageId)
    return MySQL.single.await([=[
        SELECT m.`id`, c.`id` AS `conversation_id`, c.`company_id`, c.`number_id`, c.`external_number`, n.`number` AS `company_number`, n.`shared_inbox`
        FROM `services_plus_inbox_messages` m
        JOIN `services_plus_inbox_conversations` c ON c.`id` = m.`conversation_id`
        JOIN `services_plus_company_numbers` n ON n.`id` = c.`number_id`
        WHERE m.`id` = ? AND m.`deleted_at` IS NULL AND c.`deleted_at` IS NULL
    ]=], { messageId })
end

function Repository.DeleteInboxMessage(messageId, identifier)
    return MySQL.update.await([=[
        UPDATE `services_plus_inbox_messages` SET `deleted_at` = CURRENT_TIMESTAMP, `deleted_by` = ?
        WHERE `id` = ? AND `deleted_at` IS NULL
    ]=], { identifier, messageId }) == 1
end

function Repository.ToggleMessageReaction(messageId, actorKey, emoji)
    local current = MySQL.scalar.await("SELECT `emoji` FROM `services_plus_inbox_message_reactions` WHERE `message_id` = ? AND `actor_key` = ?", { messageId, actorKey })
    if current == emoji then
        MySQL.update.await("DELETE FROM `services_plus_inbox_message_reactions` WHERE `message_id` = ? AND `actor_key` = ? AND `emoji` = ?", { messageId, actorKey, emoji })
    else
        MySQL.update.await([=[
            INSERT INTO `services_plus_inbox_message_reactions` (`message_id`, `actor_key`, `emoji`) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE `emoji` = VALUES(`emoji`), `updated_at` = CURRENT_TIMESTAMP
        ]=], { messageId, actorKey, emoji })
    end
    return Repository.GetMessageReactions({ messageId }, actorKey)[messageId] or {}
end

function Repository.MarkConversationRead(conversationId, identifier, messageId)
    MySQL.update.await([=[
        INSERT INTO `services_plus_inbox_reads` (`conversation_id`, `identifier`, `last_read_message_id`) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `last_read_message_id` = GREATEST(`last_read_message_id`, VALUES(`last_read_message_id`))
    ]=], { conversationId, identifier, messageId })
end

function Repository.GetRequestSettings(companyId)
    local row = MySQL.single.await("SELECT `settings` FROM `services_plus_company_request_settings` WHERE `company_id` = ?", { companyId })
    return row and decode(row.settings, {}) or nil
end

function Repository.SaveRequestSettings(companyId, settings)
    return MySQL.update.await([=[
        INSERT INTO `services_plus_company_request_settings` (`company_id`, `settings`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `settings` = VALUES(`settings`)
    ]=], { companyId, json.encode(settings) })
end

function Repository.CreateStructuredRequest(input)
    return MySQL.insert.await([=[
        INSERT INTO `services_plus_requests`
          (`creator_identifier`, `creator_number`, `company_id`, `template_id`, `request_label`, `status`, `phase_id`, `target_number_id`, `location_x`, `location_y`, `external_source`, `external_id`, `payload`)
        VALUES (?, ?, ?, ?, ?, 'pending', NULL, ?, ?, ?, ?, ?, ?)
    ]=], { input.identifier, input.phoneNumber, input.companyId, input.templateId, input.requestLabel, input.targetNumberId,
        input.locationX, input.locationY, input.externalSource, input.externalId, json.encode(input.values) })
end

function Repository.GetRequestByExternal(sourceName, externalId)
    if not sourceName or not externalId then return nil end
    local id = MySQL.scalar.await("SELECT `id` FROM `services_plus_requests` WHERE `external_source` = ? AND `external_id` = ?", { sourceName, externalId })
    return id and Repository.GetRequestByIdIncludingDeleted(id) or nil
end

local function getRequestById(requestId, includeDeleted)
    local row = MySQL.single.await([=[
        SELECT r.*, c.`display_name` AS `companyName` FROM `services_plus_requests` r
        JOIN `services_plus_companies` c ON c.`id` = r.`company_id` WHERE r.`id` = ? AND (? = 1 OR r.`deleted_at` IS NULL)
    ]=], { requestId, includeDeleted and 1 or 0 })
    if row then row.payload = decode(row.payload, {}) end
    return row
end

function Repository.GetRequestById(requestId)
    return getRequestById(requestId, false)
end

function Repository.GetRequestByIdIncludingDeleted(requestId)
    return getRequestById(requestId, true)
end

function Repository.GetCompanyRequests(companyId, cursor, limit, activeOnly)
    local statusClause = activeOnly and "AND r.`status` IN ('pending','active','returned')" or ""
    local query = ([=[
        SELECT r.`id`, r.`company_id` AS `companyId`, r.`template_id` AS `templateId`, r.`request_label` AS `requestLabel`, r.`status`, r.`phase_id` AS `phaseId`,
          r.`target_number_id` AS `targetNumberId`, r.`creator_number` AS `creatorNumber`, r.`payload`, r.`assigned_identifier` AS `assignedIdentifier`,
          r.`assigned_name` AS `assignedName`, r.`assigned_role` AS `assignedRole`, r.`location_x` AS `locationX`, r.`location_y` AS `locationY`,
          r.`external_source` AS `externalSource`, r.`external_id` AS `externalId`, r.`created_at`, r.`updated_at`
        FROM `services_plus_requests` r WHERE r.`company_id` = ? AND r.`deleted_at` IS NULL AND r.`id` < ? %s ORDER BY r.`id` DESC LIMIT ?
    ]=]):format(statusClause)
    local rows = MySQL.query.await(query, { companyId, cursor, limit }) or {}
    for _, row in ipairs(rows) do row.payload = decode(row.payload, {}) end
    return rows
end

function Repository.GetVisibleRequests(companyId, identifier, categoryId, competition, cursor, limit, allowedNumberIds)
    local numberPlaceholders, numberParams = {}, {}
    for _, numberId in ipairs(allowedNumberIds or {}) do
        numberPlaceholders[#numberPlaceholders + 1] = "?"
        numberParams[#numberParams + 1] = numberId
    end
    local lineClause = "r.`target_number_id` IS NULL"
    if #numberPlaceholders > 0 then lineClause = lineClause .. " OR r.`target_number_id` IN (" .. table.concat(numberPlaceholders, ",") .. ")" end

    if not competition then
        local params = { companyId, cursor, identifier }
        for _, value in ipairs(numberParams) do params[#params + 1] = value end
        params[#params + 1] = limit
        local rows = MySQL.query.await(([=[
            SELECT r.`id`, r.`company_id` AS `companyId`, r.`template_id` AS `templateId`, r.`request_label` AS `requestLabel`, r.`status`, r.`phase_id` AS `phaseId`,
              r.`target_number_id` AS `targetNumberId`, r.`creator_number` AS `creatorNumber`, r.`payload`, r.`assigned_identifier` AS `assignedIdentifier`,
              r.`assigned_name` AS `assignedName`, r.`assigned_role` AS `assignedRole`, r.`location_x` AS `locationX`, r.`location_y` AS `locationY`,
              r.`external_source` AS `externalSource`, r.`external_id` AS `externalId`, r.`created_at`, r.`updated_at`
            FROM `services_plus_requests` r
            WHERE r.`company_id` = ? AND r.`deleted_at` IS NULL AND r.`id` < ? AND (r.`assigned_identifier` = ? OR (%s))
            ORDER BY r.`id` DESC LIMIT ?
        ]=]):format(lineClause), params) or {}
        for _, row in ipairs(rows) do row.payload = decode(row.payload, {}) end
        return rows
    end

    local params = { cursor, categoryId, companyId, identifier, companyId, identifier }
    for _, value in ipairs(numberParams) do params[#params + 1] = value end
    params[#params + 1] = limit
    local rows = MySQL.query.await(([=[
        SELECT r.`id`, r.`company_id` AS `companyId`, c.`display_name` AS `companyName`, r.`template_id` AS `templateId`,
          r.`request_label` AS `requestLabel`, r.`status`, r.`phase_id` AS `phaseId`, r.`target_number_id` AS `targetNumberId`, r.`creator_number` AS `creatorNumber`, r.`payload`,
          r.`assigned_identifier` AS `assignedIdentifier`, r.`assigned_name` AS `assignedName`, r.`assigned_role` AS `assignedRole`,
          r.`location_x` AS `locationX`, r.`location_y` AS `locationY`, r.`external_source` AS `externalSource`, r.`external_id` AS `externalId`,
          r.`created_at`, r.`updated_at`
        FROM `services_plus_requests` r
        JOIN `services_plus_companies` c ON c.`id` = r.`company_id`
        WHERE r.`deleted_at` IS NULL AND r.`id` < ? AND c.`category_id` = ?
          AND (r.`company_id` = ? OR r.`assigned_identifier` = ? OR r.`status` IN ('pending','returned'))
          AND (r.`company_id` <> ? OR r.`assigned_identifier` = ? OR (%s))
        ORDER BY r.`id` DESC LIMIT ?
    ]=]):format(lineClause), params) or {}
    for _, row in ipairs(rows) do row.payload = decode(row.payload, {}) end
    return rows
end

function Repository.CountVisibleUnansweredRequests(companyId, identifier, categoryId, competition, allowedNumberIds)
    local numberPlaceholders, numberParams = {}, {}
    for _, numberId in ipairs(allowedNumberIds or {}) do
        numberPlaceholders[#numberPlaceholders + 1] = "?"
        numberParams[#numberParams + 1] = numberId
    end
    local lineClause = "r.`target_number_id` IS NULL"
    if #numberPlaceholders > 0 then lineClause = lineClause .. " OR r.`target_number_id` IN (" .. table.concat(numberPlaceholders, ",") .. ")" end

    local query, params
    if competition then
        query = ([=[
            SELECT COUNT(*) FROM `services_plus_requests` r
            JOIN `services_plus_companies` c ON c.`id` = r.`company_id`
            WHERE r.`deleted_at` IS NULL AND c.`category_id` = ? AND r.`status` IN ('pending','returned')
              AND (r.`company_id` <> ? OR r.`assigned_identifier` = ? OR (%s))
        ]=]):format(lineClause)
        params = { categoryId, companyId, identifier }
    else
        query = ([=[
            SELECT COUNT(*) FROM `services_plus_requests` r
            WHERE r.`company_id` = ? AND r.`deleted_at` IS NULL AND r.`status` IN ('pending','returned')
              AND (r.`assigned_identifier` = ? OR (%s))
        ]=]):format(lineClause)
        params = { companyId, identifier }
    end
    for _, value in ipairs(numberParams) do params[#params + 1] = value end
    return tonumber(MySQL.scalar.await(query, params)) or 0
end

function Repository.GetPendingRequestsByCategory(categoryId, limit)
    local rows = MySQL.query.await([=[
        SELECT r.*, c.`display_name` AS `companyName` FROM `services_plus_requests` r
        JOIN `services_plus_companies` c ON c.`id` = r.`company_id`
        WHERE c.`category_id` = ? AND r.`deleted_at` IS NULL AND r.`status` IN ('pending','returned')
        ORDER BY r.`id` LIMIT ?
    ]=], { categoryId, limit or 100 }) or {}
    for _, row in ipairs(rows) do row.payload = decode(row.payload, {}) end
    return rows
end

function Repository.AcceptRequest(requestId, employee, phaseId)
    return MySQL.update.await([=[
        UPDATE `services_plus_requests` SET `status` = 'active', `assigned_identifier` = ?, `assigned_name` = ?, `assigned_role` = ?, `phase_id` = ?, `accepted_at` = CURRENT_TIMESTAMP
        WHERE `id` = ? AND `status` IN ('pending','returned') AND `assigned_identifier` IS NULL
    ]=], { employee.identifier, tostring(employee.name or ""):sub(1, 100), tostring(employee.role or ""):sub(1, 100), phaseId, requestId }) == 1
end

function Repository.TransitionRequest(requestId, identifier, status, phaseId)
    local completed = status == "completed" and ", `completed_at` = CURRENT_TIMESTAMP" or ""
    return MySQL.update.await(("UPDATE `services_plus_requests` SET `status` = ?, `phase_id` = ? %s WHERE `id` = ? AND `assigned_identifier` = ? AND `status` = 'active'"):format(completed), { status, phaseId, requestId, identifier }) == 1
end

function Repository.CancelRequest(requestId, identifier)
    return MySQL.update.await([=[
        UPDATE `services_plus_requests` SET `status` = 'cancelled', `cancelled_at` = CURRENT_TIMESTAMP
        WHERE `id` = ? AND `creator_identifier` = ? AND `status` IN ('pending','active','returned')
    ]=], { requestId, identifier }) == 1
end

function Repository.DeleteRequest(requestId, companyId, identifier)
    return MySQL.update.await([=[
        UPDATE `services_plus_requests` SET `status` = 'deleted', `deleted_at` = CURRENT_TIMESTAMP, `deleted_by` = ?
        WHERE `id` = ? AND `company_id` = ? AND `deleted_at` IS NULL
    ]=], { identifier, requestId, companyId }) == 1
end

function Repository.ReturnRequest(requestId, identifier)
    return MySQL.update.await([=[
        UPDATE `services_plus_requests` SET `status` = 'returned', `assigned_identifier` = NULL, `assigned_name` = NULL, `assigned_role` = NULL, `phase_id` = NULL
        WHERE `id` = ? AND `assigned_identifier` = ? AND `status` = 'active'
    ]=], { requestId, identifier }) == 1
end

function Repository.AddRequestEvent(requestId, identifier, eventType, payload)
    MySQL.insert.await("INSERT INTO `services_plus_request_events` (`request_id`, `actor_identifier`, `event_type`, `payload`) VALUES (?, ?, ?, ?)", { requestId, identifier, eventType, json.encode(payload or {}) })
end

function Repository.RecoverActiveRequests()
    MySQL.update.await("UPDATE `services_plus_requests` SET `status` = 'returned', `assigned_identifier` = NULL, `assigned_name` = NULL, `assigned_role` = NULL, `phase_id` = NULL WHERE `status` = 'active'")
    MySQL.update.await("UPDATE `services_plus_call_queue` SET `status` = 'ended', `ended_at` = CURRENT_TIMESTAMP WHERE `status` IN ('queued','offered','accepted')")
end
