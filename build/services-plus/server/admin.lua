--[[
    Admin area (plan §50-58): companies, categories, request types, numbers,
    admin ceilings and boss assignment. Every callback here is gated by
    Admin.IsAdmin() - Services+ admin rights are independent of company
    boss rights (plan §58).
]]

Admin = {}

local ADMIN_REQUIRED_IDS = {
    ["admin:updateCategory"] = { "id" },
    ["admin:deleteCategory"] = { "id" },
    ["admin:updateCompany"] = { "id" },
    ["admin:deleteCompany"] = { "id" },
    ["admin:setCompanyCeiling"] = { "id" },
    ["admin:assignBoss"] = { "companyId", "playerId" },
    ["admin:createNumber"] = { "companyId" },
    ["admin:updateNumber"] = { "id" },
    ["admin:deleteNumber"] = { "id" },
    ["admin:enableNumber"] = { "id" },
    ["admin:updateRequestType"] = { "id" },
    ["admin:deleteRequestType"] = { "id" },
}

local ADMIN_OPTIONAL_IDS = {
    ["admin:createCompany"] = { "categoryId" },
    ["admin:updateCompany"] = { "categoryId" },
    ["admin:createRequestType"] = { "categoryId" },
    ["admin:updateRequestType"] = { "categoryId" },
}

local function isPositiveInteger(value)
    return type(value) == "number" and value == math.floor(value) and value > 0
end

--- Trims and validates a string against the database column's character
--- limit. Optional values normalize to nil; required values must meet min.
---@param value any
---@param minLength number
---@param maxLength number
---@param optional? boolean
---@return string? normalized
---@return boolean valid
local function validateString(value, minLength, maxLength, optional)
    if value == nil and optional then return nil, true end
    if type(value) ~= "string" then return nil, false end

    local normalized = value:match("^%s*(.-)%s*$")
    if normalized == "" and optional then return nil, true end

    if not IsValidUtf8Length(normalized, minLength, maxLength) then return nil, false end
    return normalized, true
end

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
        -- Every admin write uses a single table payload. Reject malformed
        -- clients here once instead of letting individual handlers discover
        -- nil/scalar payloads through exceptions.
        if name:sub(1, 9) ~= "admin:get" and type(select(1, ...)) ~= "table" then
            return reply(false)
        end

        local data = select(1, ...)
        local requiredIds = ADMIN_REQUIRED_IDS[name]
        for i = 1, #(requiredIds or {}) do
            if not isPositiveInteger(data[requiredIds[i]]) then return reply(false) end
        end
        local optionalIds = ADMIN_OPTIONAL_IDS[name]
        for i = 1, #(optionalIds or {}) do
            local value = data[optionalIds[i]]
            if value ~= nil and not isPositiveInteger(value) then return reply(false) end
        end
        fn(source, reply, ...)
    end)
end

-- Persistent service-wide settings. The request cleanup reads the value
-- from the same table, so changes apply without a resource restart.
adminCallback("admin:getServiceSettings", function(_, reply)
    local graceMinutes = tonumber(MySQL.scalar.await(
        "SELECT value FROM phone_services_plus_settings WHERE `key` = 'active_request_disconnect_grace_minutes'"
    )) or 5

    reply({ activeRequestDisconnectGraceMinutes = math.max(1, math.min(60, math.floor(graceMinutes))) })
end)

adminCallback("admin:updateServiceSettings", function(_, reply, data)
    local graceMinutes = data and tonumber(data.activeRequestDisconnectGraceMinutes)
    if not graceMinutes or graceMinutes % 1 ~= 0 or graceMinutes < 1 or graceMinutes > 60 then
        return reply(false)
    end

    MySQL.update.await([[
        INSERT INTO phone_services_plus_settings (`key`, value)
        VALUES ('active_request_disconnect_grace_minutes', ?)
        ON DUPLICATE KEY UPDATE value = VALUES(value)
    ]], { tostring(graceMinutes) })

    reply(true)
end)

-- Company branding is rendered directly by every player's NUI. Keep it
-- flexible (no domain allowlist), but only accept well-formed HTTPS URLs
-- that fit the DB column and don't point at obvious local/private targets.
-- This also rejects credentials and whitespace/control-character tricks.
---@param value any
---@return string? normalized
---@return boolean valid
local function optionalHttpsUrl(value)
    if value == nil or value == "" then return nil, true end
    if type(value) ~= "string" then return nil, false end

    value = value:match("^%s*(.-)%s*$")
    if value == "" then return nil, true end
    if #value > 255 or value:find("[%s%c]") or value:sub(1, 8):lower() ~= "https://" then
        return nil, false
    end

    local authority = value:sub(9):match("^([^/%?#]+)")
    if not authority or authority:find("@", 1, true) or authority:sub(1, 1) == "[" then
        return nil, false
    end

    local hostname, port = authority:match("^([^:]+):(%d+)$")
    if not hostname then
        if authority:find(":", 1, true) then return nil, false end
        hostname = authority
    elseif tonumber(port) < 1 or tonumber(port) > 65535 then
        return nil, false
    end

    hostname = hostname:lower()
    if hostname == "localhost" or hostname:sub(-6) == ".local" or hostname:sub(-10) == ".localhost" then
        return nil, false
    end

    local a, b, c, d = hostname:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if a then
        a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
        if a > 255 or b > 255 or c > 255 or d > 255
            or a == 0 or a == 10 or a == 127 or a >= 224
            or (a == 100 and b >= 64 and b <= 127)
            or (a == 169 and b == 254)
            or (a == 172 and b >= 16 and b <= 31)
            or (a == 192 and b == 168)
            or (a == 198 and (b == 18 or b == 19)) then
            return nil, false
        end
    else
        -- Reject abbreviated/legacy numeric host forms such as 127.1; URL
        -- parsers can canonicalize those back to a private IPv4 address.
        if not hostname:find("[^%d%.]") then return nil, false end

        if not hostname:find("%.") or hostname:sub(1, 1) == "." or hostname:sub(-1) == "."
            or hostname:find("..", 1, true) or hostname:find("[^%w%.%-]") then
            return nil, false
        end

        for label in hostname:gmatch("[^.]+") do
            if #label > 63 or label:sub(1, 1) == "-" or label:sub(-1) == "-" then return nil, false end
        end
    end

    return value, true
end

-- ---------------------------------------------------------------------------
-- Categories (plan §54)
-- ---------------------------------------------------------------------------

adminCallback("admin:getCategories", function(_, reply)
    reply(MySQL.query.await("SELECT * FROM phone_services_plus_categories ORDER BY sort_order ASC") or {})
end)

adminCallback("admin:createCategory", function(_, reply, data)
    local key, keyValid = validateString(data.key, 1, 50)
    local name, nameValid = validateString(data.name, 1, 50)
    local icon, iconValid = validateString(data.icon, 0, 100, true)
    if not keyValid or not nameValid or not iconValid then return reply(false) end

    local id = MySQL.insert.await(
        "INSERT INTO phone_services_plus_categories (`key`, name, icon, sort_order, competition_allowed) VALUES (?, ?, ?, ?, ?)",
        { key, name, icon or json.null, tonumber(data.sort) or 0, data.competitionAllowed and 1 or 0 }
    )

    Companies.ReloadAndNotify(nil, true)
    reply(id ~= nil)
end)

adminCallback("admin:updateCategory", function(_, reply, data)
    local name, nameValid = validateString(data.name, 1, 50)
    local icon, iconValid = validateString(data.icon, 0, 100, true)
    if not nameValid or not iconValid then return reply(false) end

    MySQL.update.await(
        "UPDATE phone_services_plus_categories SET name = ?, icon = ?, sort_order = ?, competition_allowed = ? WHERE id = ?",
        { name, icon or json.null, tonumber(data.sort) or 0, data.competitionAllowed and 1 or 0, data.id }
    )

    Companies.ReloadAndNotify(nil, true)
    reply(true)
end)

adminCallback("admin:deleteCategory", function(_, reply, data)
    -- Keep existing company/request-type assignments intact. The guarded
    -- DELETE is atomic, so a category cannot become used between a separate
    -- pre-check and the write and then be nulled by ON DELETE SET NULL.
    local affected = MySQL.update.await([[
        DELETE FROM phone_services_plus_categories
        WHERE id = ?
          AND NOT EXISTS (SELECT 1 FROM phone_services_plus_companies WHERE category_id = ?)
          AND NOT EXISTS (SELECT 1 FROM phone_services_plus_request_types WHERE category_id = ?)
    ]], { data.id, data.id, data.id })

    if not affected or affected == 0 then return reply(false) end
    Companies.ReloadAndNotify(nil, true)
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
    local job, jobValid = validateString(data.job, 1, 50)
    local name, nameValid = validateString(data.name, 1, 100)
    local mainNumber, numberValid = validateString(data.mainNumber, 1, 15)
    if not jobValid or not nameValid or not numberValid then return reply(false) end

    local existing = MySQL.scalar.await("SELECT id FROM phone_services_plus_companies WHERE job = ?", { job })
    if existing then return reply(false) end

    local icon, iconValid = optionalHttpsUrl(data.icon)
    local background, backgroundValid = optionalHttpsUrl(data.background)
    if not iconValid or not backgroundValid then return reply(false) end

    -- One transaction (plan review round 3 §8, matches this project's own
    -- rule on grouped writes): the company row and its mandatory Main
    -- number either both land or neither does. Previously a UNIQUE-number
    -- collision on the second insert alone could leave a company behind
    -- with no Main Phone Number at all - something the plan requires every
    -- company to have. LAST_INSERT_ID() picks up the first insert's id
    -- within the same transaction/connection, no need to thread it through
    -- manually.
    local success = MySQL.transaction.await({
        {
            [[
                INSERT INTO phone_services_plus_companies (job, name, category_id, icon, background, boss_grade, call_routing, request_routing)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ]],
            {
                job, name, data.categoryId or json.null, icon or json.null, background or json.null,
                tonumber(data.bossGrade) or 100, Config.DefaultCallRouting, Config.DefaultRequestRouting,
            },
        },
        {
            "INSERT INTO phone_services_plus_numbers (company_id, label, number, is_main) VALUES (LAST_INSERT_ID(), 'Main', ?, 1)",
            { mainNumber },
        },
    })

    if not success then return reply(false) end

    local companyId = MySQL.scalar.await("SELECT id FROM phone_services_plus_companies WHERE job = ?", { job })

    Companies.ReloadAndNotify(companyId)
    reply({ id = companyId })
end)

adminCallback("admin:updateCompany", function(_, reply, data)
    local name, nameValid = validateString(data.name, 1, 100)
    local icon, iconValid = optionalHttpsUrl(data.icon)
    local background, backgroundValid = optionalHttpsUrl(data.background)
    if not nameValid or not iconValid or not backgroundValid then return reply(false) end

    MySQL.update.await(
        "UPDATE phone_services_plus_companies SET name = ?, category_id = ?, icon = ?, background = ?, boss_grade = ?, enabled = ? WHERE id = ?",
        {
            name, data.categoryId or json.null, icon or json.null, background or json.null,
            tonumber(data.bossGrade) or 100, data.enabled and 1 or 0, data.id,
        }
    )

    Companies.ReloadAndNotify(data.id)
    reply(true)
end)

-- Soft-delete only (plan review round 4 §9, same reasoning as request
-- types): company_id/number_id cascade all the way down to messages and
-- call history, so a real DELETE here would take a company's entire chat
-- and call history down with it. Disabling instead just drops it out of
-- Companies.Reload()'s cache (and therefore the public app), while
-- admin:getCompanies still shows it (no WHERE enabled=1 there) so it can
-- be re-enabled later.
adminCallback("admin:deleteCompany", function(_, reply, data)
    MySQL.update.await("UPDATE phone_services_plus_companies SET enabled = 0 WHERE id = ?", { data.id })
    Companies.ReloadAndNotify(data.id)
    reply(true)
end)

adminCallback("admin:setCompanyCeiling", function(_, reply, data)
    -- Calls and messages have no company-wide boss toggle: the main number
    -- remains the guaranteed call endpoint/offline mailbox. Their effective
    -- values therefore follow the admin ceiling exactly. Requests do have a
    -- company toggle and only get forced off when the admin forbids them.
    MySQL.update.await([[
        UPDATE phone_services_plus_companies SET
            admin_calls_allowed = ?, calls_enabled = ?,
            admin_messages_allowed = ?, messages_enabled = ?,
            admin_requests_allowed = ?, requests_enabled = requests_enabled AND ?
        WHERE id = ?
    ]], {
        data.callsAllowed and 1 or 0, data.callsAllowed and 1 or 0,
        data.messagesAllowed and 1 or 0, data.messagesAllowed and 1 or 0,
        data.requestsAllowed and 1 or 0, data.requestsAllowed and 1 or 0,
        data.id,
    })

    Companies.ReloadAndNotify(data.id)
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
    local label, labelValid = validateString(data.label, 1, 50)
    local number, numberValid = validateString(data.number, 1, 15)
    if not labelValid or not numberValid then return reply(false) end

    local existing = MySQL.scalar.await("SELECT id FROM phone_services_plus_numbers WHERE number = ?", { number })
    if existing then return reply(false) end

    local id = MySQL.insert.await(
        "INSERT INTO phone_services_plus_numbers (company_id, label, number, calls_enabled, messages_enabled, mailbox_enabled) VALUES (?, ?, ?, ?, ?, ?)",
        { data.companyId, label, number, data.callsEnabled and 1 or 0, data.messagesEnabled and 1 or 0, data.mailboxEnabled and 1 or 0 }
    )

    if not id then return reply(false) end
    Companies.ReloadAndNotify(data.companyId)
    reply(true)
end)

-- Editing a number - including the main one (plan review round 6 §1: admin
-- previously had no way to fix a typo'd label or number on an existing
-- entry short of disabling it and creating a new one, which for the main
-- number wasn't even possible at all since that can't be deleted). Same
-- uniqueness check as admin:createNumber above, just excluding this number's
-- own row so saving it unchanged doesn't trip over itself.
adminCallback("admin:updateNumber", function(_, reply, data)
    local label, labelValid = validateString(data.label, 1, 50)
    local numberValue, numberValid = validateString(data.number, 1, 15)
    if not labelValid or not numberValid then return reply(false) end

    local existing = MySQL.scalar.await(
        "SELECT id FROM phone_services_plus_numbers WHERE number = ? AND id != ?",
        { numberValue, data.id }
    )
    if existing then return reply(false) end

    local number = MySQL.single.await(
        "SELECT company_id FROM phone_services_plus_numbers WHERE id = ?",
        { data.id }
    )
    if not number then return reply(false) end

    MySQL.update.await(
        "UPDATE phone_services_plus_numbers SET label = ?, number = ? WHERE id = ?",
        { label, numberValue, data.id }
    )

    Companies.ReloadAndNotify(number.company_id)
    reply(true)
end)

-- Soft-delete only (plan review round 5 §1, same reasoning as companies and
-- request types): number_id cascades all the way down to channels, messages
-- and call history, so a real DELETE here used to take that number's entire
-- chat and call history with it. Disabling instead just drops it out of
-- Companies.Reload()'s cache (so it stops ringing/receiving new messages),
-- while admin:getCompanies still lists it (no WHERE enabled=1 there) so it
-- can be re-enabled later.
adminCallback("admin:deleteNumber", function(_, reply, data)
    local number = MySQL.single.await("SELECT is_main, company_id FROM phone_services_plus_numbers WHERE id = ?", { data.id })
    if not number or DatabaseBoolean(number.is_main) then return reply(false) end -- plan §52: main number can't be removed

    MySQL.update.await("UPDATE phone_services_plus_numbers SET enabled = 0 WHERE id = ?", { data.id })
    Companies.ReloadAndNotify(number.company_id)
    reply(true)
end)

adminCallback("admin:enableNumber", function(_, reply, data)
    local number = MySQL.single.await("SELECT company_id FROM phone_services_plus_numbers WHERE id = ?", { data.id })
    if not number then return reply(false) end

    MySQL.update.await("UPDATE phone_services_plus_numbers SET enabled = 1 WHERE id = ?", { data.id })
    Companies.ReloadAndNotify(number.company_id)
    reply(true)
end)

-- ---------------------------------------------------------------------------
-- Request types (plan §55)
-- ---------------------------------------------------------------------------

adminCallback("admin:getRequestTypes", function(_, reply)
    reply(MySQL.query.await("SELECT * FROM phone_services_plus_request_types ORDER BY name ASC") or {})
end)

-- Every "special feature" a request type can expose. Only this list gates
-- what an admin can pick - what a given key actually *does* is entirely up
-- to its own feature module (request-types/taxi/server.lua for
-- 'taxi_pricing').
local VALID_FEATURES = { taxi_pricing = true }

local function normalizeRequestTypeIdentifier(value)
    if type(value) ~= "string" then return nil end
    local identifier = value:lower():match("^%s*(.-)%s*$")
    identifier = identifier:gsub("[^a-z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if identifier == "" or #identifier > 100 then return nil end
    return identifier
end

local function requestTypeParams(data)
    local name, nameValid = validateString(data.name, 1, 50)
    local description, descriptionValid = validateString(data.description, 0, 255, true)
    if not nameValid or not descriptionValid then return nil end

    local noteMode = ({ disabled = true, optional = true, required = true })[data.noteMode]
        and data.noteMode or "disabled"
    local passengerMode = ({ disabled = true, optional = true, required = true })[data.passengerMode]
        and data.passengerMode or "disabled"
    local countLabel, countLabelValid = validateString(data.countLabel, 0, 50, true)
    if not countLabelValid then return nil end
    countLabel = countLabel or "Passenger count"
    local feature = VALID_FEATURES[data.feature] and data.feature or json.null

    return {
        data.categoryId or json.null, name, description or json.null,
        data.locationMode or "auto", passengerMode ~= "disabled" and 1 or 0, passengerMode, countLabel,
        noteMode ~= "disabled" and 1 or 0, noteMode,
        data.competitionEnabled and 1 or 0, feature,
    }
end

adminCallback("admin:createRequestType", function(_, reply, data)
    local params = requestTypeParams(data)
    local requestedIdentifier = type(data.identifier) == "string" and data.identifier:match("^%s*(.-)%s*$") or ""
    local identifier = normalizeRequestTypeIdentifier(requestedIdentifier ~= "" and requestedIdentifier or data.name)
    if not params or not identifier then return reply(false) end
    if MySQL.scalar.await("SELECT id FROM phone_services_plus_request_types WHERE identifier = ?", { identifier }) then
        return reply(false)
    end
    table.insert(params, 3, identifier)

    local id = MySQL.insert.await([[
        INSERT INTO phone_services_plus_request_types
            (category_id, name, identifier, description, location_mode, passenger_count, passenger_mode, count_label, description_enabled, note_mode, competition_enabled, feature)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], params)

    Requests.Reload()
    reply(id ~= nil)
end)

adminCallback("admin:updateRequestType", function(_, reply, data)
    local params = requestTypeParams(data)
    if not params then return reply(false) end
    params[#params + 1] = data.enabled ~= false and 1 or 0
    params[#params + 1] = data.id

    MySQL.update.await([[
        UPDATE phone_services_plus_request_types SET
            category_id = ?, name = ?, description = ?, location_mode = ?,
            passenger_count = ?, passenger_mode = ?, count_label = ?, description_enabled = ?, note_mode = ?, competition_enabled = ?, feature = ?, enabled = ?
        WHERE id = ?
    ]], params)

    Requests.Reload()
    reply(true)
end)

-- Soft-delete only (plan review round 3 §9): request_type_id on
-- phone_services_plus_requests is ON DELETE CASCADE, so physically
-- deleting a type here used to take its entire request history - open,
-- active, and completed alike - down with it. Disabling instead just hides
-- it from Requests.GetTypesForCategory (new requests), while historical
-- rows and Requests.GetType(id) for already-open ones keep working exactly
-- as before.
adminCallback("admin:deleteRequestType", function(_, reply, data)
    MySQL.update.await("UPDATE phone_services_plus_request_types SET enabled = 0 WHERE id = ?", { data.id })
    Requests.Reload()
    reply(true)
end)
