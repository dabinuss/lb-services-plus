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
        if Framework.GetOnDuty(staff[i])
            and (not Employees or Employees.GetStatus(staff[i]) == "available") then
            return true
        end
    end

    return false
end

--- Public list for the overview screen (plan §5-7): only what the UI needs,
--- with availability pre-computed so the client never has to guess.
---@return table[]
function Companies.GetPublicList()
    local list = {}

    for id, company in pairs(companiesById) do
        local numbers = numbersByCompany[id] or {}
        local available = Companies.IsAvailable(id)

        if available or Config.UnavailableCompanyMode ~= "hide" then
            table.insert(list, {
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
                numbers = (function()
                    local out = {}
                    for i = 1, #numbers do
                        local n = numbers[i]
                        out[i] = {
                            id = n.id,
                            label = n.label,
                            number = n.number,
                            isMain = DatabaseBoolean(n.is_main),
                            callsEnabled = DatabaseBoolean(n.calls_enabled),
                            messagesEnabled = DatabaseBoolean(n.messages_enabled),
                        }
                    end
                    return out
                end)(),
            })
        end
    end

    table.sort(list, function(a, b) return a.name < b.name end)

    return list
end

function Companies.Initialize()
    seedIfEmpty()
    Companies.Reload()
end
