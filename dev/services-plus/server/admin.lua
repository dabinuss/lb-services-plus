--[[
    Admin area (plan §50-58): companies, categories, request types, numbers,
    admin ceilings and boss assignment. Every callback here is gated by
    Admin.IsAdmin() - Services+ admin rights are independent of company
    boss rights (plan §58).
]]

Admin = {}

---@param source number
---@return boolean
function Admin.IsAdmin(source)
    if IsPlayerAceAllowed(source, Config.AdminAcePermission) then
        return true
    end

    for i = 1, #Config.AdminIdentifiers do
        if GetPlayerIdentifierByType(source, "license") == Config.AdminIdentifiers[i] then
            return true
        end
    end

    return false
end

---@param name string
---@param fn fun(source: number, reply: fun(...), ...)
local function adminCallback(name, fn)
    RegisterCallback(name, function(source, reply, ...)
        if not Admin.IsAdmin(source) then return reply(false) end
        fn(source, reply, ...)
    end)
end

-- ---------------------------------------------------------------------------
-- Categories (plan §54)
-- ---------------------------------------------------------------------------

adminCallback("admin:getCategories", function(_, reply)
    reply(MySQL.query.await("SELECT * FROM phone_services_plus_categories ORDER BY sort_order ASC") or {})
end)

adminCallback("admin:createCategory", function(_, reply, data)
    if type(data.key) ~= "string" or data.key == "" or type(data.name) ~= "string" or data.name == "" then
        return reply(false)
    end

    local id = MySQL.insert.await(
        "INSERT INTO phone_services_plus_categories (`key`, name, icon, sort_order, competition_allowed) VALUES (?, ?, ?, ?, ?)",
        { data.key, data.name, data.icon or json.null, tonumber(data.sort) or 0, data.competitionAllowed and 1 or 0 }
    )

    Companies.Reload()
    reply(id ~= nil)
end)

adminCallback("admin:updateCategory", function(_, reply, data)
    MySQL.update.await(
        "UPDATE phone_services_plus_categories SET name = ?, icon = ?, sort_order = ?, competition_allowed = ? WHERE id = ?",
        { data.name, data.icon or json.null, tonumber(data.sort) or 0, data.competitionAllowed and 1 or 0, data.id }
    )

    Companies.Reload()
    reply(true)
end)

adminCallback("admin:deleteCategory", function(_, reply, data)
    MySQL.update.await("DELETE FROM phone_services_plus_categories WHERE id = ?", { data.id })
    Companies.Reload()
    reply(true)
end)

-- ---------------------------------------------------------------------------
-- Companies (plan §51, §53)
-- ---------------------------------------------------------------------------

adminCallback("admin:getCompanies", function(_, reply)
    local companies = MySQL.query.await("SELECT * FROM phone_services_plus_companies ORDER BY name ASC") or {}
    local numbers = MySQL.query.await("SELECT * FROM phone_services_plus_numbers ORDER BY is_main DESC, id ASC") or {}

    for i = 1, #companies do
        companies[i].numbers = {}
    end

    local byId = {}
    for i = 1, #companies do byId[companies[i].id] = companies[i] end

    for i = 1, #numbers do
        local company = byId[numbers[i].company_id]
        if company then table.insert(company.numbers, numbers[i]) end
    end

    reply(companies)
end)

adminCallback("admin:createCompany", function(_, reply, data)
    if type(data.job) ~= "string" or data.job == "" or type(data.name) ~= "string" or data.name == "" or type(data.mainNumber) ~= "string" or data.mainNumber == "" then
        return reply(false)
    end

    local existing = MySQL.scalar.await("SELECT id FROM phone_services_plus_companies WHERE job = ?", { data.job })
    if existing then return reply(false) end

    local companyId = MySQL.insert.await([[
        INSERT INTO phone_services_plus_companies (job, name, category_id, icon, background, boss_grade, call_routing, request_routing)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.job, data.name, data.categoryId or json.null, data.icon or json.null, data.background or json.null,
        tonumber(data.bossGrade) or 100, Config.DefaultCallRouting, Config.DefaultRequestRouting,
    })

    if not companyId then return reply(false) end

    MySQL.insert.await(
        "INSERT INTO phone_services_plus_numbers (company_id, label, number, is_main) VALUES (?, 'Main', ?, 1)",
        { companyId, data.mainNumber }
    )

    Companies.Reload()
    reply({ id = companyId })
end)

adminCallback("admin:updateCompany", function(_, reply, data)
    MySQL.update.await(
        "UPDATE phone_services_plus_companies SET name = ?, category_id = ?, icon = ?, background = ?, boss_grade = ?, enabled = ? WHERE id = ?",
        {
            data.name, data.categoryId or json.null, data.icon or json.null, data.background or json.null,
            tonumber(data.bossGrade) or 100, data.enabled and 1 or 0, data.id,
        }
    )

    Companies.Reload()
    reply(true)
end)

adminCallback("admin:deleteCompany", function(_, reply, data)
    MySQL.update.await("DELETE FROM phone_services_plus_companies WHERE id = ?", { data.id })
    Companies.Reload()
    reply(true)
end)

adminCallback("admin:setCompanyCeiling", function(_, reply, data)
    -- A ceiling turned off also pulls the company's own toggle down with it
    -- (plan §34) - a boss can't stay opted into something the admin just banned.
    MySQL.update.await([[
        UPDATE phone_services_plus_companies SET
            admin_calls_allowed = ?, calls_enabled = calls_enabled AND ?,
            admin_messages_allowed = ?, messages_enabled = messages_enabled AND ?,
            admin_requests_allowed = ?, requests_enabled = requests_enabled AND ?
        WHERE id = ?
    ]], {
        data.callsAllowed and 1 or 0, data.callsAllowed and 1 or 0,
        data.messagesAllowed and 1 or 0, data.messagesAllowed and 1 or 0,
        data.requestsAllowed and 1 or 0, data.requestsAllowed and 1 or 0,
        data.id,
    })

    Companies.Reload()
    reply(true)
end)

---@param data { companyId: number, playerId: number }
adminCallback("admin:assignBoss", function(_, reply, data)
    local company = Companies.GetById(data.companyId)
    local target = tonumber(data.playerId)

    if not company or not target or GetPlayerName(target) == nil then
        return reply(false)
    end

    reply(Framework.SetJob(target, company.job, company.boss_grade))
end)

-- ---------------------------------------------------------------------------
-- Phone numbers (plan §52)
-- ---------------------------------------------------------------------------

adminCallback("admin:createNumber", function(_, reply, data)
    if type(data.label) ~= "string" or data.label == "" or type(data.number) ~= "string" or data.number == "" then
        return reply(false)
    end

    local existing = MySQL.scalar.await("SELECT id FROM phone_services_plus_numbers WHERE number = ?", { data.number })
    if existing then return reply(false) end

    local id = MySQL.insert.await(
        "INSERT INTO phone_services_plus_numbers (company_id, label, number, calls_enabled, messages_enabled, mailbox_enabled) VALUES (?, ?, ?, ?, ?, ?)",
        { data.companyId, data.label, data.number, data.callsEnabled and 1 or 0, data.messagesEnabled and 1 or 0, data.mailboxEnabled and 1 or 0 }
    )

    Companies.Reload()
    reply(id ~= nil)
end)

adminCallback("admin:deleteNumber", function(_, reply, data)
    local number = MySQL.single.await("SELECT is_main FROM phone_services_plus_numbers WHERE id = ?", { data.id })
    if not number or number.is_main == 1 then return reply(false) end -- plan §52: main number can't be removed

    MySQL.update.await("DELETE FROM phone_services_plus_numbers WHERE id = ?", { data.id })
    Companies.Reload()
    reply(true)
end)

-- ---------------------------------------------------------------------------
-- Request types (plan §55)
-- ---------------------------------------------------------------------------

adminCallback("admin:getRequestTypes", function(_, reply)
    reply(MySQL.query.await("SELECT * FROM phone_services_plus_request_types ORDER BY name ASC") or {})
end)

local function requestTypeParams(data)
    return {
        data.categoryId or json.null, data.name, data.icon or json.null, data.description or json.null,
        data.locationMode or "auto", data.passengerCount and 1 or 0, data.descriptionEnabled and 1 or 0,
        data.competitionEnabled and 1 or 0,
    }
end

adminCallback("admin:createRequestType", function(_, reply, data)
    if type(data.name) ~= "string" or data.name == "" then return reply(false) end

    local id = MySQL.insert.await([[
        INSERT INTO phone_services_plus_request_types
            (category_id, name, icon, description, location_mode, passenger_count, description_enabled, competition_enabled)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], requestTypeParams(data))

    Requests.Reload()
    reply(id ~= nil)
end)

adminCallback("admin:updateRequestType", function(_, reply, data)
    local params = requestTypeParams(data)
    params[#params + 1] = data.id

    MySQL.update.await([[
        UPDATE phone_services_plus_request_types SET
            category_id = ?, name = ?, icon = ?, description = ?, location_mode = ?,
            passenger_count = ?, description_enabled = ?, competition_enabled = ?
        WHERE id = ?
    ]], params)

    Requests.Reload()
    reply(true)
end)

adminCallback("admin:deleteRequestType", function(_, reply, data)
    MySQL.update.await("DELETE FROM phone_services_plus_request_types WHERE id = ?", { data.id })
    Requests.Reload()
    reply(true)
end)
