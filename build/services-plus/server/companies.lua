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
            local categoryId = company.category and MySQL.scalar.await(
                "SELECT id FROM phone_services_plus_categories WHERE `key` = ?", { company.category }
            ) or nil

            -- json.null, not plain nil, for anything before the table's last
            -- field - a bare nil there leaves a hole that breaks positional
            -- parameter binding.
            local companyId = MySQL.insert.await(
                "INSERT INTO phone_services_plus_companies (job, name, category_id, icon, background, boss_grade) VALUES (?, ?, ?, ?, ?, ?)",
                { company.job, company.name, categoryId or json.null, company.icon or json.null, company.background or json.null, company.bossGrade or 100 }
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
        local company = companyRows[i]
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
