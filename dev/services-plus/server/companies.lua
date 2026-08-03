ServicesPlus.Companies = ServicesPlus.Companies or {}

local Companies = ServicesPlus.Companies
local cache = {}
local categorySettings = {}
local version = 0
local settings = { directoryTitle = "Los Santos Services", callsEnabled = true, requestsEnabled = true }

local function copyArray(values)
    local result = {}
    for i, value in ipairs(values or {}) do result[i] = value end
    return result
end

function Companies.Load()
    cache = ServicesPlus.Repository.LoadCompanies()
    categorySettings = ServicesPlus.Repository.LoadCategorySettings()
    local storedSettings = ServicesPlus.Repository.LoadSettings()
    settings.directoryTitle = storedSettings.directoryTitle or settings.directoryTitle
    settings.callsEnabled = storedSettings.callsEnabled ~= false
    settings.requestsEnabled = storedSettings.requestsEnabled ~= false
    version = version + 1
    ServicesPlus.Logger.Info("Company cache loaded", { count = Companies.Count(), version = version })
end

function Companies.GetSettings()
    return { directoryTitle = settings.directoryTitle, callsEnabled = settings.callsEnabled, requestsEnabled = settings.requestsEnabled }
end

function Companies.Count()
    local count = 0
    for _ in pairs(cache) do count = count + 1 end
    return count
end

function Companies.Get(companyId)
    return cache[companyId]
end

function Companies.FindByJob(job)
    for _, company in pairs(cache) do
        if company.job == job then return company end
    end
    return nil
end

function Companies.FindByNumber(value)
    for _, company in pairs(cache) do
        for _, number in ipairs(company.numbers) do
            if number.number == value or number.id == value then return company, number end
        end
    end
    return nil, nil
end

function Companies.GetCategoryList(locale)
    local categories = {}
    for id, category in pairs(ServicesPlus.Categories) do
        categories[#categories + 1] = {
            id = id,
            icon = category.icon,
            name = category.name[locale] or category.name.en,
            names = category.name,
            keywords = copyArray(category.keywords),
            hasRequestTemplates = #(ServicesPlus.RequestDefinitions.categoryTemplates[id] or {}) > 0,
            requestCompetition = categorySettings[id] and categorySettings[id].requestCompetition == true or false
        }
    end
    table.sort(categories, function(a, b) return a.name < b.name end)
    return categories
end

function Companies.GetCategoryRequestCompetition(categoryId)
    return categorySettings[categoryId] and categorySettings[categoryId].requestCompetition == true or false
end

function Companies.GetByCategory(categoryId)
    local result = {}
    for _, company in pairs(cache) do if company.categoryId == categoryId then result[#result + 1] = company end end
    return result
end

function Companies.UpdateCategoryCompetition(categoryId, enabled)
    if not ServicesPlus.Categories[categoryId] or type(enabled) ~= "boolean" then return false, "validation_failed" end
    local definition = categorySettings[categoryId] or {}
    definition.requestCompetition = enabled
    if not ServicesPlus.Repository.SaveCategorySettings(categoryId, definition) then return false, "category_update_failed" end
    categorySettings[categoryId] = definition
    return true
end

function Companies.GetAdminList()
    local result = {}
    for _, company in pairs(cache) do
        local item = Companies.ToPublic(company)
        item.job = company.job
        item.keywords = copyArray(company.keywords)
        result[#result + 1] = item
    end
    table.sort(result, function(a, b) return a.displayName < b.displayName end)
    return result
end

function Companies.ToPublic(company)
    local category = ServicesPlus.Categories[company.categoryId] or ServicesPlus.Categories.other
    local employeeCount = ServicesPlus.Employees and ServicesPlus.Employees.CountForCompany(company.id) or 0
    local numbers = {}
    for _, number in ipairs(company.numbers) do
        numbers[#numbers + 1] = {
            id = number.id,
            label = number.label,
            number = number.number,
            distribution = number.distribution,
            sharedInbox = number.sharedInbox,
            enabled = number.enabled,
            callsEnabled = number.callsEnabled,
            inboxEnabled = number.inboxEnabled,
            requestsEnabled = number.requestsEnabled,
            publicVisible = number.publicVisible,
            available = ServicesPlus.Employees and ServicesPlus.Employees.NumberHasCoverage(company.id, number, true) or false
        }
    end
    return {
        id = company.id,
        displayName = company.displayName,
        logo = company.logo,
        backgroundImage = company.backgroundImage,
        categoryId = company.categoryId,
        categoryName = category.name[Config.Locale] or category.name.en,
        description = company.description,
        location = company.location,
        openingHours = company.openingHours,
        keywords = copyArray(company.keywords),
        available = employeeCount > 0,
        employeeCount = employeeCount,
        requestsEnabled = company.requestsEnabled,
        hasRequestTemplates = #(ServicesPlus.RequestDefinitions.categoryTemplates[company.categoryId] or {}) > 0,
        messagesEnabled = company.messagesEnabled,
        dispatchMode = company.dispatchMode,
        primaryNumber = (function() for _, number in ipairs(numbers) do if number.enabled and number.callsEnabled and number.publicVisible then return number.number end end end)(),
        numbers = numbers,
        version = version
    }
end

function Companies.UpdateNumberOperations(companyId, updates)
    local company = cache[companyId]
    if not company then return false, "company_not_found" end
    local byId = {}
    for _, number in ipairs(company.numbers) do byId[number.id] = number end
    for _, update in ipairs(updates or {}) do
        local number = byId[update.id]
        if not number then return false, "number_not_found" end
    end
    if not ServicesPlus.Repository.UpdateNumberOperations(companyId, updates) then return false, "number_update_failed" end
    for _, update in ipairs(updates) do
        local number = byId[update.id]
        number.enabled = update.enabled
        number.callsEnabled = update.callsEnabled
        number.inboxEnabled = update.inboxEnabled
        number.requestsEnabled = update.requestsEnabled
        number.publicVisible = update.publicVisible
        number.distribution = update.distribution
    end
    version = version + 1
    return true, Companies.ToPublic(company)
end

function Companies.UpdateOperations(companyId, patch)
    local company = cache[companyId]
    if not company then return false, "company_not_found" end
    local affected = ServicesPlus.Repository.UpdateCompanyOperations(companyId, patch)
    if type(affected) ~= "number" then return false, "company_update_failed" end
    company.requestsEnabled = patch.requestsEnabled
    company.messagesEnabled = patch.messagesEnabled
    company.dispatchMode = patch.dispatchMode
    version = version + 1
    return true, Companies.ToPublic(company)
end

function Companies.SaveAdmin(company)
    local success = ServicesPlus.Repository.SaveCompany(company)
    if not success then return false, "company_save_failed" end
    Companies.Load()
    return true, Companies.ToPublic(cache[company.id])
end

function Companies.DeleteAdmin(companyId, actorIdentifier)
    if not cache[companyId] then return false, "company_not_found" end
    local success = ServicesPlus.Repository.DeleteCompany(companyId, actorIdentifier)
    if not success then return false, "company_delete_failed" end
    cache[companyId] = nil
    version = version + 1
    return true
end

function Companies.GetDeletedList()
    local result = {}
    for _, row in ipairs(ServicesPlus.Repository.GetDeletedCompanies(50)) do
        result[#result + 1] = { id = row.id, job = row.job, displayName = row.display_name, logo = row.logo, categoryId = row.category_id, deletedAt = row.deleted_at, deletedBy = row.deleted_by }
    end
    return result
end

function Companies.RestoreAdmin(companyId)
    if cache[companyId] then return false, "company_not_deleted" end
    if not ServicesPlus.Repository.RestoreCompany(companyId) then return false, "company_not_found" end
    Companies.Load()
    version = version + 1
    return true, Companies.ToPublic(cache[companyId])
end

function Companies.UpdateSettings(nextSettings)
    local success = ServicesPlus.Repository.UpdateSettings(nextSettings)
    if not success then return false end
    settings = nextSettings
    return true, Companies.GetSettings()
end

function Companies.GetPublicList()
    local result = {}
    for _, company in pairs(cache) do result[#result + 1] = Companies.ToPublic(company) end
    table.sort(result, function(a, b) return a.displayName < b.displayName end)
    return result
end

function Companies.Update(companyId, patch)
    local company = cache[companyId]
    if not company then return false, "company_not_found" end

    local affected = ServicesPlus.Repository.UpdateCompany(companyId, patch)
    if type(affected) ~= "number" then return false, "company_update_failed" end

    company.displayName = patch.displayName
    company.logo = patch.logo
    company.backgroundImage = patch.backgroundImage
    company.categoryId = patch.categoryId
    company.description = patch.description
    company.location = patch.location
    company.openingHours = patch.openingHours
    company.requestsEnabled = patch.requestsEnabled
    company.messagesEnabled = patch.messagesEnabled
    version = version + 1
    return true, Companies.ToPublic(company)
end
