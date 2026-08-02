ServicesPlus.Repository = ServicesPlus.Repository or {}

local Repository = ServicesPlus.Repository

local function decode(value, fallback)
    if type(value) == "table" then return value end
    if not value or value == "" then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and result or fallback
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
            numberRows[#numberRows + 1] = "(?, ?, ?, ?, ?, ?)"
            local row = { number.id, company.id, number.label, number.number, number.distribution, number.sharedInbox ~= false and 1 or 0 }
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
                (`id`, `company_id`, `label`, `number`, `distribution`, `shared_inbox`)
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
        ORDER BY `display_name`, `id`
        LIMIT ?
    ]=], { Config.MaxCompanies }) or {}
    local numbers = MySQL.query.await([=[
        SELECT `id`, `company_id`, `label`, `number`, `distribution`, `shared_inbox`
        FROM `services_plus_company_numbers`
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
            company.numbers[#company.numbers + 1] = {
                id = row.id,
                label = row.label,
                number = row.number,
                distribution = row.distribution,
                sharedInbox = row.shared_inbox == 1
            }
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
                    `requests_enabled` = VALUES(`requests_enabled`), `messages_enabled` = VALUES(`messages_enabled`), `dispatch_mode` = VALUES(`dispatch_mode`)
            ]=],
            values = { company.id, company.job, company.displayName, company.logo, company.backgroundImage, company.categoryId, company.description,
                company.location, company.openingHours, json.encode(company.keywords), company.requestsEnabled and 1 or 0,
                company.messagesEnabled and 1 or 0, company.dispatchMode }
        },
        {
            query = "DELETE FROM `services_plus_company_numbers` WHERE `company_id` = ?",
            values = { company.id }
        }
    }

    if #company.numbers > 0 then
        local rows = {}
        local values = {}
        for index, number in ipairs(company.numbers) do
            rows[#rows + 1] = "(?, ?, ?, ?, ?, ?)"
            local row = { ("%s-%d"):format(company.id, index), company.id, number.label, number.number, number.distribution, number.sharedInbox and 1 or 0 }
            for _, value in ipairs(row) do values[#values + 1] = value end
        end
        queries[#queries + 1] = {
            query = ([=[
                INSERT INTO `services_plus_company_numbers`
                    (`id`, `company_id`, `label`, `number`, `distribution`, `shared_inbox`)
                VALUES %s
            ]=]):format(table.concat(rows, ",")),
            values = values
        }
    end

    return MySQL.transaction.await(queries)
end

function Repository.DeleteCompany(companyId)
    return MySQL.update.await("DELETE FROM `services_plus_companies` WHERE `id` = ?", { companyId })
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
        SELECT r.`id`, r.`company_id` AS `companyId`, c.`display_name` AS `companyName`, r.`status`, r.`phase_id` AS `phaseId`, r.`payload`, r.`created_at`
        FROM `services_plus_requests` r
        JOIN `services_plus_companies` c ON c.`id` = r.`company_id`
        WHERE r.`creator_identifier` = ?
        ORDER BY r.`id` DESC LIMIT ?
    ]=], { identifier, limit }) or {}
    for _, request in ipairs(requests) do request.payload = decode(request.payload, {}) end
    return { calls = calls, requests = requests }
end
