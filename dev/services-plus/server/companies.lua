--[[
    In-memory cache of categories/companies/numbers (plan §65-66: only the
    persistent tables live in the DB, the cache just avoids re-querying on
    every app open). Rebuilt from the DB on start and whenever an admin
    changes something (phase 3).
]]

Companies = {}

local categories = {} -- ordered list
local companiesById = {}
local companiesByJob = {}
local numbersByCompany = {} -- companyId -> ordered list of numbers
local brandingMediaPolicy = nil

local function getBrandingMediaPolicy()
    if brandingMediaPolicy == nil then
        local ok, phoneConfig = pcall(function()
            return exports["lb-phone"]:GetConfig()
        end)
        brandingMediaPolicy = ok and PeekPlusMediaPolicy.Build(phoneConfig) or false
    end
    return brandingMediaPolicy ~= false and brandingMediaPolicy or nil
end

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= "lb-phone" then return end
    brandingMediaPolicy = nil
    if ServicesPlus and ServicesPlus.ready then
        SetTimeout(500, function()
            brandingMediaPolicy = nil
            Companies.Reload()
            Companies.NotifyDirectoryChanged(nil, false)
        end)
    end
end)

--- Normalizes optional remote company media. This is the single server-side
--- boundary used by admin writes, seeds, cached rows and direct query results.
---@param value any
---@return string? normalized
---@return boolean valid
function Companies.NormalizeMediaUrl(value)
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
        if not hostname:find("[^%d%.]") then return nil, false end
        if not hostname:find("%.") or hostname:sub(1, 1) == "." or hostname:sub(-1) == "."
            or hostname:find("..", 1, true) or hostname:find("[^%w%.%-]") then
            return nil, false
        end
        for label in hostname:gmatch("[^.]+") do
            if #label > 63 or label:sub(1, 1) == "-" or label:sub(-1) == "-" then return nil, false end
        end
    end

    local policy = getBrandingMediaPolicy()
    if not policy or not PeekPlusMediaPolicy.IsAllowed(value, policy) then return nil, false end
    return value, true
end

local function sanitizeCompanyMedia(company)
    if type(company) ~= "table" then return company end
    company.icon = Companies.NormalizeMediaUrl(company.icon)
    company.background = Companies.NormalizeMediaUrl(company.background)
    return company
end

local function seedIfEmpty()
    local categoryCount = MySQL.scalar.await("SELECT COUNT(*) FROM phone_services_plus_categories")

    if categoryCount == 0 and #Config.DefaultCategories > 0 then
        for i = 1, #Config.DefaultCategories do
            local cat = Config.DefaultCategories[i]
            MySQL.insert.await(
                "INSERT INTO phone_services_plus_categories (`key`, name, icon, sort_order, competition_allowed) VALUES (?, ?, ?, ?, ?)",
                { cat.key, cat.name, cat.icon, cat.sort, cat.competitionAllowed and 1 or 0 }
            )
        end
    end

    local companyCount = MySQL.scalar.await("SELECT COUNT(*) FROM phone_services_plus_companies")

    if companyCount == 0 and #Config.DefaultCompanies > 0 then
        for i = 1, #Config.DefaultCompanies do
            local company = Config.DefaultCompanies[i]
            local icon, iconValid = Companies.NormalizeMediaUrl(company.icon)
            local background, backgroundValid = Companies.NormalizeMediaUrl(company.background)
            if not iconValid or not backgroundValid then
                print(("^3[services-plus] ignored disallowed media URL for default company '%s'^7")
                    :format(tostring(company.job or company.name or i)))
            end
            local categoryId = company.category and MySQL.scalar.await(
                "SELECT id FROM phone_services_plus_categories WHERE `key` = ?", { company.category }
            ) or nil

            -- json.null, not plain nil, for anything before the table's last
            -- field - a bare nil there leaves a hole that breaks positional
            -- parameter binding.
            local companyId = MySQL.insert.await(
                "INSERT INTO phone_services_plus_companies (job, name, category_id, icon, background, boss_grade) VALUES (?, ?, ?, ?, ?, ?)",
                { company.job, company.name, categoryId or json.null, icon or json.null, background or json.null, company.bossGrade or 100 }
            )

            if company.mainNumber then
                MySQL.insert.await(
                    "INSERT INTO phone_services_plus_numbers (company_id, label, number, is_main) VALUES (?, 'Main', ?, 1)",
                    { companyId, company.mainNumber }
                )
            end
        end
    end
end

function Companies.Reload()
    categories = MySQL.query.await("SELECT * FROM phone_services_plus_categories ORDER BY sort_order ASC") or {}

    local companyRows = MySQL.query.await("SELECT * FROM phone_services_plus_companies WHERE enabled = 1") or {}
    -- The main number is the guaranteed offline mailbox for a company. Old
    -- rows may still contain disabled flags from versions where the boss UI
    -- allowed this switch, so repair them before rebuilding the cache. Extra
    -- numbers remain independently configurable.
    MySQL.update.await([[
        UPDATE phone_services_plus_numbers
        SET messages_enabled = 1, mailbox_enabled = 1
        WHERE is_main = 1 AND (messages_enabled <> 1 OR mailbox_enabled <> 1)
    ]])
    -- Soft-deleted numbers (plan review round 5 §1) drop out of this cache
    -- the same way a disabled company does - everything that reads a
    -- company's numbers through Companies.GetNumbers() (calls, hotlines,
    -- messaging, company settings) only ever sees live ones.
    local numberRows = MySQL.query.await("SELECT * FROM phone_services_plus_numbers WHERE enabled = 1 ORDER BY is_main DESC, id ASC") or {}

    companiesById = {}
    companiesByJob = {}
    numbersByCompany = {}

    for i = 1, #numberRows do
        local number = numberRows[i]
        numbersByCompany[number.company_id] = numbersByCompany[number.company_id] or {}
        table.insert(numbersByCompany[number.company_id], number)
    end

    for i = 1, #companyRows do
        local company = sanitizeCompanyMedia(companyRows[i])
        companiesById[company.id] = company
        companiesByJob[company.job] = company
    end

    print(("[services-plus] loaded %d categories, %d companies"):format(#categories, #companyRows))
end

--- Refresh only one company's cache entry after a company/number write. This
--- keeps ordinary settings changes independent of the total number of
--- companies and numbers on the server.
---@param companyId number
function Companies.Refresh(companyId)
    local id = tonumber(companyId)
    if not id then return false end

    local previous = companiesById[id]
    if previous then companiesByJob[previous.job] = nil end

    local company = MySQL.single.await(
        "SELECT * FROM phone_services_plus_companies WHERE id = ? AND enabled = 1",
        { id }
    )

    if not company then
        companiesById[id] = nil
        numbersByCompany[id] = nil
        return true
    end

    sanitizeCompanyMedia(company)

    MySQL.update.await([[
        UPDATE phone_services_plus_numbers
        SET messages_enabled = 1, mailbox_enabled = 1
        WHERE company_id = ? AND is_main = 1
          AND (messages_enabled <> 1 OR mailbox_enabled <> 1)
    ]], { id })

    local numbers = MySQL.query.await([[
        SELECT * FROM phone_services_plus_numbers
        WHERE company_id = ? AND enabled = 1
        ORDER BY is_main DESC, id ASC
    ]], { id }) or {}

    companiesById[id] = company
    companiesByJob[company.job] = company
    numbersByCompany[id] = numbers
    return true
end

---@return table[]
function Companies.GetCategories()
    return categories
end

---@param id number
function Companies.GetCategory(id)
    for i = 1, #categories do
        if categories[i].id == id then return categories[i] end
    end
    return nil
end

---@param id number
function Companies.GetById(id)
    return companiesById[id]
end

---@param job string
function Companies.GetByJob(job)
    return companiesByJob[job]
end

---@param source number
---@return table? company, table? job
function Companies.GetForPlayer(source)
    local job = Framework.GetJob(source)
    return job and companiesByJob[job.name] or nil, job
end

---@param companyId number
---@return table[]
function Companies.GetNumbers(companyId)
    return numbersByCompany[companyId] or {}
end

---@return table[]
function Companies.GetAll()
    local list = {}
    for _, company in pairs(companiesById) do
        list[#list + 1] = company
    end
    return list
end

---@param categoryId number
---@return table[]
function Companies.GetByCategory(categoryId)
    local list = {}
    for _, company in pairs(companiesById) do
        if company.category_id == categoryId then list[#list + 1] = company end
    end
    return list
end

---@param companyId number
---@return table? the main number row, if the company has one
function Companies.GetMainNumber(companyId)
    local numbers = numbersByCompany[companyId] or {}
    for i = 1, #numbers do
        if DatabaseBoolean(numbers[i].is_main) then return numbers[i] end
    end
    return nil
end

---@param companyId number
---@return boolean
function Companies.IsAvailable(companyId)
    local company = companiesById[companyId]
    if not company then return false end

    local staff = Framework.GetPlayersByJob(company.job)

    for i = 1, #staff do
        if Employees.IsLoggedIn(staff[i], companyId)
            and Framework.GetOnDuty(staff[i])
            and (not Employees or Employees.GetStatus(staff[i]) == "available") then
            return true
        end
    end

    return false
end

local function publicCompany(companyId)
    local company = companiesById[companyId]
    if not company then return nil end

    local available = Companies.IsAvailable(companyId)
    if not available and Config.UnavailableCompanyMode == "hide" then return nil end

    local numbers = numbersByCompany[companyId] or {}
    local publicNumbers = {}
    for i = 1, #numbers do
        local n = numbers[i]
        publicNumbers[i] = {
            id = n.id,
            label = n.label,
            number = n.number,
            isMain = DatabaseBoolean(n.is_main),
            callsEnabled = DatabaseBoolean(n.calls_enabled),
            messagesEnabled = DatabaseBoolean(n.messages_enabled),
        }
    end

    return {
        id = company.id,
        job = company.job,
        name = company.name,
        categoryId = company.category_id,
        icon = company.icon,
        background = company.background,
        available = available,
        callsEnabled = DatabaseBoolean(company.calls_enabled),
        messagesEnabled = DatabaseBoolean(company.messages_enabled),
        requestsEnabled = DatabaseBoolean(company.requests_enabled),
        callsAllowed = DatabaseBoolean(company.admin_calls_allowed),
        messagesAllowed = DatabaseBoolean(company.admin_messages_allowed),
        requestsAllowed = DatabaseBoolean(company.admin_requests_allowed),
        numbers = publicNumbers,
    }
end

---@param companyId number
---@return table?
function Companies.GetPublicCompany(companyId)
    return publicCompany(tonumber(companyId))
end

--- Public list for the overview screen (plan §5-7): only what the UI needs,
--- with availability pre-computed so the client never has to guess.
---@return table[]
function Companies.GetPublicList()
    local list = {}

    for id in pairs(companiesById) do
        local company = publicCompany(id)
        if company then list[#list + 1] = company end
    end

    table.sort(list, function(a, b) return a.name < b.name end)

    return list
end

--- Official cache invalidation path for already-open apps. A known company
--- is sent as one small upsert/removal delta; structural changes can request
--- a full directory/category snapshot instead.
---@param companyId? number
---@param categoriesChanged? boolean
function Companies.NotifyDirectoryChanged(companyId, categoriesChanged)
    local id = tonumber(companyId)
    local payload = {}

    if id then
        payload.companyId = id
        payload.company = Companies.GetPublicCompany(id) or false
    else
        payload.companies = Companies.GetPublicList()
    end

    if categoriesChanged then payload.categories = Companies.GetCategories() end
    TriggerClientEvent("services-plus:client:companiesChanged", -1, payload)
end

---@param companyId? number
---@param categoriesChanged? boolean
function Companies.ReloadAndNotify(companyId, categoriesChanged)
    if tonumber(companyId) then
        Companies.Refresh(companyId)
    else
        Companies.Reload()
    end
    Companies.NotifyDirectoryChanged(companyId, categoriesChanged)
end

function Companies.Initialize()
    seedIfEmpty()
    Companies.Reload()
end
