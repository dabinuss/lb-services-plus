ServicesPlus.Api = ServicesPlus.Api or {}

local Api = ServicesPlus.Api
local subscribers = {}

local function requirePhone(source)
    if ServicesPlus.Bridge.HasEquippedPhone(source) then return nil end
    return ServicesPlus.Error("phone_required", "An equipped phone is required.", false)
end

local function validateString(value, minimum, maximum)
    return type(value) == "string" and #value >= minimum and #value <= maximum
end

local function buildUserState(source)
    local player, company = ServicesPlus.Employees.ResolveEmployment(source)
    local duty = ServicesPlus.Employees.Get(source)
    local employment = nil
    if player and company then
        employment = {
            companyId = company.id,
            companyName = company.displayName,
            isLeader = duty and duty.isLeader or ServicesPlus.Bridge.IsLeader(player, company),
            onDuty = duty ~= nil,
            employee = ServicesPlus.Employees.ToPublic(duty),
            activeEmployees = duty and ServicesPlus.Employees.GetPublicForCompany(company.id) or {}
        }
    end
    return {
        source = source,
        name = player and player.name or GetPlayerName(source),
        isServerAdmin = ServicesPlus.Bridge.IsServerAdmin(source),
        employment = employment
    }
end

function Api.getInitialState(source)
    local phoneError = requirePhone(source)
    if phoneError then return phoneError end
    ServicesPlus.Employees.ValidateEmployment(source)
    subscribers[source] = true
    return ServicesPlus.Ok({
        apiVersion = ServicesPlus.Constants.ApiVersion,
        locale = Config.Locale,
        framework = ServicesPlus.Bridge.GetName(),
        settings = ServicesPlus.Companies.GetSettings(),
        companies = ServicesPlus.Companies.GetPublicList(),
        categories = ServicesPlus.Companies.GetCategoryList(Config.Locale),
        currentUser = buildUserState(source)
    })
end

function Api.enterDuty(source)
    local phoneError = requirePhone(source)
    if phoneError then return phoneError end
    local success, result = ServicesPlus.Employees.EnterDuty(source)
    if not success then return ServicesPlus.Error(result, "Company access could not be verified.", false) end
    return ServicesPlus.Ok({ employee = result, currentUser = buildUserState(source), companies = ServicesPlus.Companies.GetPublicList() })
end

function Api.leaveDuty(source)
    local success, errorCode = ServicesPlus.Employees.LeaveDuty(source, "logout")
    if not success then return ServicesPlus.Error(errorCode, "Finish or return active work before leaving duty.", false) end
    return ServicesPlus.Ok({ currentUser = buildUserState(source), companies = ServicesPlus.Companies.GetPublicList() })
end

function Api.updateStatus(source, payload)
    if type(payload) ~= "table" then return ServicesPlus.Error("invalid_payload", "Invalid status payload.", false) end
    ServicesPlus.Employees.ValidateEmployment(source)
    local success, result = ServicesPlus.Employees.UpdateStatus(source, payload.status)
    if not success then return ServicesPlus.Error(result, "The status could not be changed.", false) end
    return ServicesPlus.Ok(result)
end

function Api.toggleDispatch(source, payload)
    if type(payload) ~= "table" then return ServicesPlus.Error("invalid_payload", "Invalid dispatch payload.", false) end
    ServicesPlus.Employees.ValidateEmployment(source)
    local success, result = ServicesPlus.Employees.ToggleDispatch(source, payload.enabled)
    if not success then return ServicesPlus.Error(result, "Dispatch could not be changed.", false) end
    return ServicesPlus.Ok(result)
end

function Api.updateCompanyOperations(source, payload)
    if type(payload) ~= "table" or type(payload.patch) ~= "table" or type(payload.companyId) ~= "string" then
        return ServicesPlus.Error("invalid_payload", "Invalid company payload.", false)
    end
    ServicesPlus.Employees.ValidateEmployment(source)
    local employee = ServicesPlus.Employees.Get(source)
    if not employee or not employee.isLeader or employee.companyId ~= payload.companyId then
        return ServicesPlus.Error("forbidden", "Leader access is required.", false)
    end

    local patch = payload.patch
    if type(patch.requestsEnabled) ~= "boolean" or type(patch.messagesEnabled) ~= "boolean"
        or not ServicesPlus.Constants.DistributionModes[patch.dispatchMode] then
        return ServicesPlus.Error("validation_failed", "Invalid operational settings.", false)
    end

    local success, result = ServicesPlus.Companies.UpdateOperations(payload.companyId, patch)
    if not success then return ServicesPlus.Error(result, "The company could not be updated.", true) end
    for target in pairs(subscribers) do
        TriggerClientEvent("services-plus:client:push", target, {
            type = "company.updated",
            version = result.version,
            timestamp = os.time(),
            payload = result
        })
    end
    return ServicesPlus.Ok(result)
end

function Api.startCompanyCall(source, payload)
    local phoneError = requirePhone(source)
    if phoneError then return phoneError end
    if type(payload) ~= "table" or type(payload.companyId) ~= "string" then
        return ServicesPlus.Error("invalid_payload", "Invalid call payload.", false)
    end
    local settings = ServicesPlus.Companies.GetSettings()
    local company = ServicesPlus.Companies.Get(payload.companyId)
    if not settings.callsEnabled or not company or ServicesPlus.Employees.CountForCompany(company.id) == 0 then
        return ServicesPlus.Error("company_unavailable", "The company is not available for calls.", false)
    end
    local number = company.numbers[1]
    if type(payload.numberId) == "string" then
        for _, candidate in ipairs(company.numbers) do
            if candidate.id == payload.numberId then number = candidate break end
        end
    end
    if not number then return ServicesPlus.Error("number_unavailable", "No company number is configured.", false) end
    local player = ServicesPlus.Bridge.GetPlayer(source)
    if not player then return ServicesPlus.Error("player_unavailable", "Player identity could not be resolved.", true) end
    ServicesPlus.Repository.RecordCall(player.identifier, company.id, number.id)
    return ServicesPlus.Ok({ number = number.number, companyId = company.id })
end

function Api.getEmployeeContact(source, payload)
    local phoneError = requirePhone(source)
    if phoneError then return phoneError end
    local targetSource = type(payload) == "table" and tonumber(payload.targetSource) or nil
    if not targetSource or targetSource == source then
        return ServicesPlus.Error("invalid_target", "A different active employee is required.", false)
    end
    ServicesPlus.Employees.ValidateEmployment(source)
    local caller = ServicesPlus.Employees.Get(source)
    local target = ServicesPlus.Employees.Get(targetSource)
    if not caller or not target or caller.companyId ~= target.companyId then
        return ServicesPlus.Error("forbidden", "The employee is not active in your company.", false)
    end
    local ok, number = pcall(function()
        return exports["lb-phone"]:GetEquippedPhoneNumber(targetSource)
    end)
    if not ok or type(number) ~= "string" or number == "" then
        return ServicesPlus.Error("phone_unavailable", "The employee has no equipped phone.", false)
    end
    return ServicesPlus.Ok({ number = number })
end

function Api.createRequest(source, payload)
    local phoneError = requirePhone(source)
    if phoneError then return phoneError end
    if type(payload) ~= "table" or type(payload.companyId) ~= "string"
        or not validateString(payload.details, 3, 1000) or not validateString(payload.location or "", 0, 150) then
        return ServicesPlus.Error("validation_failed", "Request details are invalid.", false)
    end
    local settings = ServicesPlus.Companies.GetSettings()
    local company = ServicesPlus.Companies.Get(payload.companyId)
    if not settings.requestsEnabled or not company or not company.requestsEnabled then
        return ServicesPlus.Error("requests_disabled", "Requests are not enabled for this company.", false)
    end
    local player = ServicesPlus.Bridge.GetPlayer(source)
    if not player then return ServicesPlus.Error("player_unavailable", "Player identity could not be resolved.", true) end
    local requestId = ServicesPlus.Repository.CreateRequest(player.identifier, company.id, payload.details, payload.location or "")
    if not requestId then return ServicesPlus.Error("request_failed", "The request could not be created.", true) end
    return ServicesPlus.Ok({ id = requestId, companyId = company.id, companyName = company.displayName, status = "pending", details = payload.details, location = payload.location or "", createdAt = os.date("!%Y-%m-%dT%H:%M:%SZ") })
end

function Api.getMyActivity(source, payload)
    local phoneError = requirePhone(source)
    if phoneError then return phoneError end
    local player = ServicesPlus.Bridge.GetPlayer(source)
    if not player then return ServicesPlus.Error("player_unavailable", "Player identity could not be resolved.", true) end
    local limit = type(payload) == "table" and tonumber(payload.limit) or 20
    limit = math.max(1, math.min(math.floor(limit or 20), 50))
    return ServicesPlus.Ok(ServicesPlus.Repository.GetMyActivity(player.identifier, limit))
end

local function requireAdmin(source)
    local phoneError = requirePhone(source)
    if phoneError then return phoneError end
    if ServicesPlus.Bridge.IsServerAdmin(source) then return nil end
    ServicesPlus.Logger.Warn("Rejected Services+ admin action", { source = source })
    return ServicesPlus.Error("forbidden", "Server administrator access is required.", false)
end

local function validateAdminCompany(input)
    if type(input) ~= "table" or not validateString(input.id, 2, 64) or not input.id:match("^[a-z0-9][a-z0-9_-]+$")
        or not validateString(input.job, 1, 64) or not validateString(input.displayName, 2, 100)
        or not validateString(input.logo or "", 0, 500) or not validateString(input.backgroundImage or "", 0, 500) or not validateString(input.description or "", 0, 500)
        or not validateString(input.location or "", 0, 150) or not validateString(input.openingHours or "", 0, 100)
        or type(input.categoryId) ~= "string" or not ServicesPlus.Categories[input.categoryId]
        or type(input.requestsEnabled) ~= "boolean" or type(input.messagesEnabled) ~= "boolean" or not ServicesPlus.Constants.DistributionModes[input.dispatchMode]
        or type(input.keywords) ~= "table" or #input.keywords > 20 or type(input.numbers) ~= "table" or #input.numbers > 10 then
        return nil
    end
    if (input.logo or "") ~= "" and not (input.logo or ""):match("^https?://") then return nil end
    if (input.backgroundImage or "") ~= "" and not (input.backgroundImage or ""):match("^https?://") then return nil end
    if (input.logo or ""):match("[%c\"']") or (input.backgroundImage or ""):match("[%c\"']") then return nil end
    local numbers = {}
    for _, number in ipairs(input.numbers) do
        if type(number) ~= "table" or not validateString(number.label, 1, 80) or not validateString(number.number, 1, 32)
            or not ServicesPlus.Constants.DistributionModes[number.distribution] or type(number.sharedInbox) ~= "boolean" then return nil end
        numbers[#numbers + 1] = { label = number.label, number = number.number, distribution = number.distribution, sharedInbox = number.sharedInbox }
    end
    local keywords = {}
    for _, keyword in ipairs(input.keywords) do
        if not validateString(keyword, 1, 40) then return nil end
        keywords[#keywords + 1] = keyword
    end
    return { id = input.id, job = input.job, displayName = input.displayName, logo = input.logo or "", backgroundImage = input.backgroundImage or "", categoryId = input.categoryId,
        description = input.description or "", location = input.location or "", openingHours = input.openingHours or "", keywords = keywords,
        requestsEnabled = input.requestsEnabled, messagesEnabled = input.messagesEnabled, dispatchMode = input.dispatchMode, numbers = numbers }
end

function Api.getAdminState(source)
    local adminError = requireAdmin(source)
    if adminError then return adminError end
    return ServicesPlus.Ok({ companies = ServicesPlus.Companies.GetAdminList(), settings = ServicesPlus.Companies.GetSettings(), categories = ServicesPlus.Companies.GetCategoryList(Config.Locale), framework = ServicesPlus.Bridge.GetName() })
end

function Api.adminSaveCompany(source, payload)
    local adminError = requireAdmin(source)
    if adminError then return adminError end
    local company = validateAdminCompany(type(payload) == "table" and payload.company or nil)
    if not company then return ServicesPlus.Error("validation_failed", "One or more company fields are invalid.", false) end
    if not ServicesPlus.Companies.Get(company.id) and ServicesPlus.Companies.Count() >= Config.MaxCompanies then
        return ServicesPlus.Error("company_limit_reached", "The configured company limit has been reached.", false)
    end
    local success, result = ServicesPlus.Companies.SaveAdmin(company)
    if not success then return ServicesPlus.Error(result, "The company could not be saved.", true) end
    ServicesPlus.Employees.RevalidateCompany(company.id)
    for target in pairs(subscribers) do TriggerClientEvent("services-plus:client:push", target, { type = "company.updated", version = result.version, timestamp = os.time(), payload = result }) end
    return ServicesPlus.Ok(result)
end

function Api.adminDeleteCompany(source, payload)
    local adminError = requireAdmin(source)
    if adminError then return adminError end
    if type(payload) ~= "table" or type(payload.companyId) ~= "string" then return ServicesPlus.Error("invalid_payload", "Invalid company identifier.", false) end
    local success, result = ServicesPlus.Companies.DeleteAdmin(payload.companyId)
    if not success then return ServicesPlus.Error(result, "The company could not be deleted.", true) end
    ServicesPlus.Employees.RemoveCompany(payload.companyId)
    for target in pairs(subscribers) do TriggerClientEvent("services-plus:client:push", target, { type = "company.deleted", timestamp = os.time(), payload = { id = payload.companyId } }) end
    return ServicesPlus.Ok({ id = payload.companyId })
end

function Api.adminUpdateSettings(source, payload)
    local adminError = requireAdmin(source)
    if adminError then return adminError end
    local settings = type(payload) == "table" and payload.settings or nil
    if type(settings) ~= "table" or not validateString(settings.directoryTitle, 2, 80)
        or type(settings.callsEnabled) ~= "boolean" or type(settings.requestsEnabled) ~= "boolean" then
        return ServicesPlus.Error("validation_failed", "Global settings are invalid.", false)
    end
    local success, result = ServicesPlus.Companies.UpdateSettings({ directoryTitle = settings.directoryTitle, callsEnabled = settings.callsEnabled, requestsEnabled = settings.requestsEnabled })
    if not success then return ServicesPlus.Error("settings_update_failed", "Settings could not be updated.", true) end
    for target in pairs(subscribers) do TriggerClientEvent("services-plus:client:push", target, { type = "settings.updated", timestamp = os.time(), payload = result }) end
    return ServicesPlus.Ok(result)
end

function Api.BroadcastCompany(companyId)
    local company = ServicesPlus.Companies.Get(companyId)
    if not company then return end
    local payload = ServicesPlus.Companies.ToPublic(company)
    for target in pairs(subscribers) do
        TriggerClientEvent("services-plus:client:push", target, {
            type = "company.updated",
            version = payload.version,
            timestamp = os.time(),
            payload = payload
        })
    end
end

function Api.RemoveSubscriber(source)
    subscribers[source] = nil
end

AddEventHandler("playerDropped", function() Api.RemoveSubscriber(source) end)
