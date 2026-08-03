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
    local company = ServicesPlus.Companies.Get(payload.companyId)
    if #(ServicesPlus.RequestDefinitions.categoryTemplates[company.categoryId] or {}) == 0 then patch.requestsEnabled = false end

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

function Api.updateNumberOperations(source, payload)
    ServicesPlus.Employees.ValidateEmployment(source)
    local employee = ServicesPlus.Employees.Get(source)
    local company = employee and ServicesPlus.Companies.Get(employee.companyId) or nil
    local updates = type(payload) == "table" and payload.numbers or nil
    if not employee or not employee.isLeader or not company or type(updates) ~= "table" or #updates > 10 then
        return ServicesPlus.Error("forbidden", "Leader access is required.", false)
    end
    local clean = {}
    local requestsAvailable = #(ServicesPlus.RequestDefinitions.categoryTemplates[company.categoryId] or {}) > 0
    for _, number in ipairs(updates) do
        if type(number) ~= "table" or type(number.id) ~= "string" or type(number.enabled) ~= "boolean"
            or type(number.callsEnabled) ~= "boolean" or type(number.inboxEnabled) ~= "boolean" or type(number.requestsEnabled) ~= "boolean"
            or type(number.publicVisible) ~= "boolean" or not ServicesPlus.Constants.DistributionModes[number.distribution] then
            return ServicesPlus.Error("validation_failed", "Invalid number operations.", false)
        end
        if not requestsAvailable then number.requestsEnabled = false end
        clean[#clean + 1] = number
    end
    local success, result = ServicesPlus.Companies.UpdateNumberOperations(company.id, clean)
    if not success then return ServicesPlus.Error(result, "Number operations could not be saved.", true) end
    for _, member in ipairs(ServicesPlus.Employees.GetPublicForCompany(company.id)) do
        ServicesPlus.Employees.SyncPhoneNumbers(member.source)
        ServicesPlus.Calls.RevalidateEmployee(member.source)
    end
    Api.BroadcastCompany(company.id)
    return ServicesPlus.Ok(result)
end

function Api.toggleDispatchLine(source, payload)
    ServicesPlus.Employees.ValidateEmployment(source)
    local numberId = type(payload) == "table" and payload.numberId or nil
    local enabled = type(payload) == "table" and payload.enabled or nil
    if type(numberId) ~= "string" or type(enabled) ~= "boolean" then return ServicesPlus.Error("invalid_payload", "Invalid line subscription.", false) end
    local success, result = ServicesPlus.Employees.ToggleDispatchLine(source, numberId, enabled)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The line subscription could not be changed.", false)
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
    if not number or not number.enabled or not number.publicVisible or not number.callsEnabled or not ServicesPlus.Employees.NumberHasCoverage(company.id, number, true) then
        return ServicesPlus.Error("number_unavailable", "The selected company number is not currently available.", false)
    end
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
    if type(payload) ~= "table" or type(payload.companyId) ~= "string" then return ServicesPlus.Error("validation_failed", "Request details are invalid.", false) end
    local settings = ServicesPlus.Companies.GetSettings()
    local company = ServicesPlus.Companies.Get(payload.companyId)
    if not settings.requestsEnabled or not company or not company.requestsEnabled then
        return ServicesPlus.Error("requests_disabled", "Requests are not enabled for this company.", false)
    end
    local templateId = type(payload.templateId) == "string" and payload.templateId or "general"
    local values = type(payload.values) == "table" and payload.values or { description = payload.details, location = payload.location }
    local locale = payload.locale == "de" and "de" or "en"
    local success, result = ServicesPlus.Requests.Create(source, company.id, templateId, values, locale)
    if not success then return ServicesPlus.Error(result, "The request could not be created.", result == "request_failed") end
    return ServicesPlus.Ok(result)
end

local function pagination(payload, maximum)
    local limit = type(payload) == "table" and tonumber(payload.limit) or 30
    local cursor = type(payload) == "table" and tonumber(payload.cursor) or 9007199254740991
    return math.max(1, math.min(math.floor(limit or 30), maximum or 50)), math.max(1, math.floor(cursor or 9007199254740991))
end

function Api.getRequestOptions(source, payload)
    local phoneError = requirePhone(source); if phoneError then return phoneError end
    local company = type(payload) == "table" and ServicesPlus.Companies.Get(payload.companyId) or nil
    if not company or not company.requestsEnabled then return ServicesPlus.Error("requests_disabled", "Requests are not enabled for this company.", false) end
    local settings = ServicesPlus.Requests.ResolveSettings(company, payload.locale == "de" and "de" or "en")
    if #settings.templates == 0 then return ServicesPlus.Error("requests_disabled", "No specialized requests are configured for this category.", false) end
    local phoneNumber = ServicesPlus.Bridge.GetEquippedPhoneNumber(source)
    settings.defaultPhone = phoneNumber and tostring(phoneNumber) or ""
    return ServicesPlus.Ok(settings)
end

function Api.registerIncomingCall(source, payload)
    local success, result = ServicesPlus.Calls.RegisterIncoming(source, payload)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The incoming call could not be registered.", false)
end

function Api.acceptCall(source, payload)
    local queueId = type(payload) == "table" and tonumber(payload.id) or nil
    if not queueId then return ServicesPlus.Error("invalid_payload", "Invalid call identifier.", false) end
    local success, result = ServicesPlus.Calls.Accept(source, queueId)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, result == "already_accepted" and "Another employee already accepted this call." or "The call could not be accepted.", false)
end

function Api.declineCall(source, payload)
    local queueId = type(payload) == "table" and tonumber(payload.id) or nil
    if not queueId then return ServicesPlus.Error("invalid_payload", "Invalid call identifier.", false) end
    local success, result = ServicesPlus.Calls.Decline(source, queueId)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The call could not be declined.", false)
end

function Api.endCustomCall(source, payload)
    local token = type(payload) == "table" and tostring(payload.callToken or "") or ""
    if #token < 1 or #token > 96 or not ServicesPlus.Calls.EndFromClient(source, token) then return ServicesPlus.Error("invalid_call", "The call could not be ended.", false) end
    return ServicesPlus.Ok({ ended = true })
end

function Api.getCompanyWorkspace(source, payload)
    ServicesPlus.Employees.ValidateEmployment(source)
    local employee = ServicesPlus.Employees.Get(source)
    if not employee then return ServicesPlus.Error("not_on_duty", "Company duty is required.", false) end
    payload = type(payload) == "table" and payload or {}
    local limit = math.max(1, math.min(math.floor(tonumber(payload.limit) or 24), 50))
    local requested = { conversations = true, requests = true, calls = true }
    if type(payload.sections) == "table" then
        requested = {}
        for _, section in ipairs(payload.sections) do
            if section == "conversations" or section == "requests" or section == "calls" then requested[section] = true end
        end
    end
    local cursors = type(payload.cursors) == "table" and payload.cursors or {}
    local function cursorFor(section)
        return math.max(1, math.floor(tonumber(cursors[section]) or 9007199254740991))
    end
    local function page(rows)
        local hasMore = #rows > limit
        if hasMore then table.remove(rows) end
        return rows, { nextCursor = rows[#rows] and rows[#rows].id or nil, hasMore = hasMore }
    end

    local conversations, conversationPage = {}, { hasMore = false }
    if requested.conversations then
        local inboxOk, rows = ServicesPlus.Inboxes.GetCompanyList(source, cursorFor("conversations"), limit + 1)
        conversations, conversationPage = page(inboxOk and rows or {})
    end
    local company = ServicesPlus.Companies.Get(employee.companyId)
    local queriedRequests = requested.requests and ServicesPlus.Repository.GetVisibleRequests(employee.companyId, employee.identifier, company.categoryId, company.requestsEnabled and ServicesPlus.Companies.GetCategoryRequestCompetition(company.categoryId), cursorFor("requests"), limit + 1, ServicesPlus.Employees.GetActiveNumberIds(employee)) or {}
    local rawRequestPage
    queriedRequests, rawRequestPage = page(queriedRequests)
    local visibleRequests = {}
    for _, request in ipairs(queriedRequests) do
        if ServicesPlus.Requests.CanHandle(employee, request) or request.assignedIdentifier == employee.identifier then visibleRequests[#visibleRequests + 1] = request end
    end
    for index, request in ipairs(visibleRequests) do
        local owner = ServicesPlus.Companies.Get(request.companyId or request.company_id)
        local public = ServicesPlus.Requests.ToCompanyPublic(request)
        public.phases = owner and ServicesPlus.Requests.ResolveSettings(owner, type(payload) == "table" and payload.locale == "de" and "de" or "en").phases or {}
        visibleRequests[index] = public
    end
    local calls, callPage = {}, { hasMore = false }
    if requested.calls then calls, callPage = page(ServicesPlus.Repository.GetCompanyCalls(employee.companyId, cursorFor("calls"), limit + 1)) end
    local numberStates = {}
    for _, number in ipairs(company.numbers) do
        numberStates[#numberStates + 1] = {
            numberId = number.id,
            label = number.label,
            enabled = number.enabled,
            callsEnabled = number.callsEnabled,
            inboxEnabled = number.inboxEnabled and number.sharedInbox,
            requestsEnabled = number.requestsEnabled,
            canSelectForDispatch = employee.dispatchEnabled,
            selectedForDispatch = employee.dispatchEnabled and ServicesPlus.Employees.CanUseNumber(employee, number)
        }
    end
    return ServicesPlus.Ok({
        companyId = employee.companyId,
        conversations = conversations,
        requests = visibleRequests,
        calls = calls,
        requestSettings = ServicesPlus.Requests.ResolveSettings(company, type(payload) == "table" and payload.locale == "de" and "de" or "en"),
        numberStates = numberStates,
        pagination = { conversations = conversationPage, requests = rawRequestPage, calls = callPage }
    })
end

function Api.acceptRequest(source, payload)
    local id = type(payload) == "table" and tonumber(payload.id) or nil
    if not id then return ServicesPlus.Error("invalid_payload", "Invalid request identifier.", false) end
    local success, result = ServicesPlus.Requests.Accept(source, id)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, result == "already_accepted" and "Another employee already accepted this request." or "The request could not be accepted.", false)
end

function Api.declineRequest(source, payload)
    local id = type(payload) == "table" and tonumber(payload.id) or nil
    if not id then return ServicesPlus.Error("invalid_payload", "Invalid request identifier.", false) end
    local success, result = ServicesPlus.Requests.Decline(source, id)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The request could not be declined.", false)
end

function Api.transitionRequest(source, payload)
    local id = type(payload) == "table" and tonumber(payload.id) or nil
    if not id or type(payload.phaseId) ~= "string" then return ServicesPlus.Error("invalid_payload", "Invalid request transition.", false) end
    local success, result = ServicesPlus.Requests.Transition(source, id, payload.phaseId)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The request phase could not be changed.", false)
end

function Api.returnRequest(source, payload)
    local id = type(payload) == "table" and tonumber(payload.id) or nil
    if not id then return ServicesPlus.Error("invalid_payload", "Invalid request identifier.", false) end
    local success, result = ServicesPlus.Requests.Return(source, id)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The request could not be returned.", false)
end

function Api.cancelRequest(source, payload)
    local id = type(payload) == "table" and tonumber(payload.id) or nil
    if not id then return ServicesPlus.Error("invalid_payload", "Invalid request identifier.", false) end
    local success, result = ServicesPlus.Requests.Cancel(source, id)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The request could not be cancelled.", false)
end

function Api.deleteRequest(source, payload)
    local id = type(payload) == "table" and tonumber(payload.id) or nil
    if not id then return ServicesPlus.Error("invalid_payload", "Invalid request identifier.", false) end
    local success, result = ServicesPlus.Requests.Delete(source, id)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "Only the active dispatch may delete company requests.", false)
end

function Api.updateRequestSettings(source, payload)
    local success, result = ServicesPlus.Requests.SaveSettings(source, type(payload) == "table" and payload.settings or nil)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "Request settings could not be saved.", false)
end

function Api.sendCitizenMessage(source, payload)
    local phoneError = requirePhone(source); if phoneError then return phoneError end
    local success, result = ServicesPlus.Inboxes.SendCitizen(source, payload)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The message could not be sent.", result == "message_failed")
end

function Api.sendEmployeeMessage(source, payload)
    local success, result = ServicesPlus.Inboxes.SendEmployee(source, payload)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The reply could not be sent.", result == "message_failed")
end

function Api.getCitizenInbox(source, payload)
    local limit, cursor = pagination(payload, 50)
    local success, result = ServicesPlus.Inboxes.GetCitizenList(source, cursor, limit)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The inbox could not be loaded.", false)
end

function Api.getConversationMessages(source, payload)
    local limit, cursor = pagination(payload, 50)
    local conversationId = type(payload) == "table" and tonumber(payload.conversationId) or nil
    if not conversationId then return ServicesPlus.Error("invalid_payload", "Invalid conversation identifier.", false) end
    local success, result = ServicesPlus.Inboxes.GetMessages(source, conversationId, cursor, limit, payload.citizen == true)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The conversation could not be loaded.", false)
end

function Api.reactToMessage(source, payload)
    local success, result = ServicesPlus.Inboxes.React(source, payload)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The reaction could not be updated.", false)
end

function Api.deleteConversation(source, payload)
    local id = type(payload) == "table" and tonumber(payload.id) or nil
    if not id then return ServicesPlus.Error("invalid_payload", "Invalid conversation identifier.", false) end
    local success, result = ServicesPlus.Inboxes.DeleteConversation(source, id)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "Only the active dispatch may delete company conversations.", false)
end

function Api.deleteMessage(source, payload)
    local id = type(payload) == "table" and tonumber(payload.id) or nil
    if not id then return ServicesPlus.Error("invalid_payload", "Invalid message identifier.", false) end
    local success, result = ServicesPlus.Inboxes.DeleteMessage(source, id)
    return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "Only the active dispatch may delete company messages.", false)
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
            or not ServicesPlus.Constants.DistributionModes[number.distribution]
            or type(number.sharedInbox) ~= "boolean" or type(number.enabled) ~= "boolean" or type(number.callsEnabled) ~= "boolean"
            or type(number.inboxEnabled) ~= "boolean" or type(number.requestsEnabled) ~= "boolean" or type(number.publicVisible) ~= "boolean" then return nil end
        if number.id ~= nil and (not validateString(number.id, 2, 64) or not number.id:match("^[a-z0-9][a-z0-9_-]+$")) then return nil end
        local requestsAvailable = #(ServicesPlus.RequestDefinitions.categoryTemplates[input.categoryId] or {}) > 0
        numbers[#numbers + 1] = { id = number.id, label = number.label, number = number.number, distribution = number.distribution, sharedInbox = number.sharedInbox,
            enabled = number.enabled, callsEnabled = number.callsEnabled, inboxEnabled = number.inboxEnabled, requestsEnabled = requestsAvailable and number.requestsEnabled or false,
            publicVisible = number.publicVisible }
    end
    local keywords = {}
    for _, keyword in ipairs(input.keywords) do
        if not validateString(keyword, 1, 40) then return nil end
        keywords[#keywords + 1] = keyword
    end
    return { id = input.id, job = input.job, displayName = input.displayName, logo = input.logo or "", backgroundImage = input.backgroundImage or "", categoryId = input.categoryId,
        description = input.description or "", location = input.location or "", openingHours = input.openingHours or "", keywords = keywords,
        requestsEnabled = #(ServicesPlus.RequestDefinitions.categoryTemplates[input.categoryId] or {}) > 0 and input.requestsEnabled or false, messagesEnabled = input.messagesEnabled, dispatchMode = input.dispatchMode, numbers = numbers }
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
    for _, member in ipairs(ServicesPlus.Employees.GetPublicForCompany(company.id)) do
        ServicesPlus.Employees.SyncPhoneNumbers(member.source)
        ServicesPlus.Calls.RevalidateEmployee(member.source)
    end
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

function Api.adminUpdateCategory(source, payload)
    local adminError = requireAdmin(source)
    if adminError then return adminError end
    local categoryId = type(payload) == "table" and payload.categoryId or nil
    local enabled = type(payload) == "table" and payload.requestCompetition or nil
    if type(categoryId) ~= "string" or type(enabled) ~= "boolean" then return ServicesPlus.Error("invalid_payload", "Invalid category settings.", false) end
    local success, errorCode = ServicesPlus.Companies.UpdateCategoryCompetition(categoryId, enabled)
    if not success then return ServicesPlus.Error(errorCode, "Category settings could not be updated.", true) end
    ServicesPlus.Requests.RefreshCategoryCompetition(categoryId)
    local category
    for _, item in ipairs(ServicesPlus.Companies.GetCategoryList(Config.Locale)) do if item.id == categoryId then category = item break end end
    for target in pairs(subscribers) do TriggerClientEvent("services-plus:client:push", target, { type = "category.updated", timestamp = os.time(), payload = category }) end
    return ServicesPlus.Ok(category)
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
