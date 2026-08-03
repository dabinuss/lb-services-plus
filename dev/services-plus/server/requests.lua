ServicesPlus.Requests = ServicesPlus.Requests or {}

local Requests = ServicesPlus.Requests
local definitions = ServicesPlus.RequestDefinitions

local function copy(values)
    local result = {}
    for index, value in ipairs(values or {}) do result[index] = value end
    return result
end

local function localeName(value, locale)
    return value and (value[locale] or value.en) or ""
end

local function defaultTemplateIds(company)
    return copy(definitions.categoryTemplates[company.categoryId] or {})
end

local function templateAllowed(company, template)
    return template and template.kind == "specialized" and template.categoryId == company.categoryId
end

local function resolvedTemplateIds(company, storedIds)
    local available = defaultTemplateIds(company)
    if type(storedIds) ~= "table" then return available end
    local allowed = {}; for _, id in ipairs(available) do allowed[id] = true end
    local result, added = {}, {}
    for _, id in ipairs(storedIds) do
        if allowed[id] and not added[id] then result[#result + 1] = id; added[id] = true end
    end
    return #result > 0 and result or available
end

local function defaultPhases(company)
    return copy(definitions.phases[company.categoryId] or definitions.phases.other)
end

local navigationDefaults = {
    taxi_transport = "automatic",
    emergency_medical = "automatic",
    police_justice = "automatic"
}

local function value(request, snake, camel)
    local resolved = request[snake]
    if resolved == nil then resolved = request[camel] end
    return resolved
end

local function assignee(request, includeIdentifier)
    local identifier = value(request, "assigned_identifier", "assignedIdentifier")
    if not identifier then return nil end
    local active = ServicesPlus.Employees.GetByIdentifier(identifier)
    local result = {
        name = value(request, "assigned_name", "assignedName") or (active and active.name) or "",
        role = value(request, "assigned_role", "assignedRole") or (active and active.role) or "",
        source = active and active.source or nil
    }
    if includeIdentifier then result.identifier = identifier end
    return result
end

function Requests.ToPublic(request)
    if not request then return nil end
    local companyId = value(request, "company_id", "companyId")
    local company = companyId and ServicesPlus.Companies.Get(companyId) or nil
    return {
        id = request.id,
        companyId = companyId,
        companyName = request.companyName or (company and company.displayName),
        templateId = value(request, "template_id", "templateId"),
        requestLabel = value(request, "request_label", "requestLabel"),
        status = request.status,
        phaseId = value(request, "phase_id", "phaseId"),
        targetNumberId = value(request, "target_number_id", "targetNumberId"),
        payload = request.payload or {},
        createdAt = value(request, "created_at", "createdAt"),
        updatedAt = value(request, "updated_at", "updatedAt")
    }
end

function Requests.ToCompanyPublic(request)
    local result = Requests.ToPublic(request)
    if result then result.assignee = assignee(request, false) end
    return result
end

function Requests.ToIntegration(request)
    local result = Requests.ToPublic(request)
    if not result then return nil end
    result.assignee = assignee(request, true)
    local x, y = tonumber(value(request, "location_x", "locationX")), tonumber(value(request, "location_y", "locationY"))
    if x and y then result.location = { x = x, y = y } end
    local externalSource, externalId = value(request, "external_source", "externalSource"), value(request, "external_id", "externalId")
    if externalSource and externalId then result.externalReference = { resource = externalSource, id = externalId } end
    result.creatorNumber = value(request, "creator_number", "creatorNumber")
    return result
end

local lifecycleNames = {
    requestAccepted = "accepted", requestPhaseChanged = "phase_changed", requestReturned = "returned",
    requestCompleted = "completed", requestCancelled = "cancelled", requestDeleted = "deleted"
}

local function emitLifecycle(eventName, request)
    TriggerEvent("services-plus:server:requestLifecycle", {
        event = eventName,
        version = ServicesPlus.Constants.ApiVersion,
        timestamp = os.time(),
        request = Requests.ToIntegration(request)
    })
end

function Requests.ResolveSettings(company, locale)
    local stored = ServicesPlus.Repository.GetRequestSettings(company.id) or {}
    local templateIds = resolvedTemplateIds(company, stored.templateIds)
    local phases = {}
    for _, phase in ipairs(defaultPhases(company)) do
        phases[#phases + 1] = { id = phase.id, name = localeName(phase.name, locale) }
    end
    if #phases == 0 then phases = { { id = "accepted", name = locale == "de" and "Angenommen" or "Accepted" }, { id = "completed", name = locale == "de" and "Abgeschlossen" or "Completed" } } end

    local templates = {}
    for _, templateId in ipairs(defaultTemplateIds(company)) do
        local template = definitions.templates[templateId]
        if templateAllowed(company, template) then
            local fields = {}
            for _, configured in ipairs(template.fields) do
                local field = definitions.fields[configured.id]
                local override = stored.fieldSettings and stored.fieldSettings[templateId] and stored.fieldSettings[templateId][configured.id] or nil
                if field then
                    local options = {}
                    for _, option in ipairs(field.options or {}) do options[#options + 1] = { value = option.value, label = localeName(option.label, locale) } end
                    local required = override and type(override.required) == "boolean" and override.required or configured.required == true
                    fields[#fields + 1] = { id = configured.id, type = field.type, label = localeName(field.label, locale), enabled = not override or override.enabled ~= false, required = required,
                        maxLength = field.maxLength, minimum = field.minimum, maximum = field.maximum, options = options }
                end
            end
            templates[#templates + 1] = { id = templateId, kind = template.kind or "specialized", name = localeName(template.name, locale), fields = fields }
        end
    end
    local requestNumbers = {}
    for _, number in ipairs(company.numbers or {}) do
        if number.enabled and number.publicVisible and number.requestsEnabled then requestNumbers[#requestNumbers + 1] = { id = number.id, label = number.label } end
    end
    local numberId = stored.numberId
    local validNumber = false
    for _, number in ipairs(requestNumbers) do if number.id == numberId then validNumber = true break end end
    if not validNumber then numberId = requestNumbers[1] and requestNumbers[1].id or nil end
    return { label = stored.label or (locale == "de" and "Anfrage" or "Request"), createLabel = stored.createLabel or (locale == "de" and "Anfrage erstellen" or "Create request"), templateIds = templateIds, templates = templates, phases = phases, fieldSettings = stored.fieldSettings or {}, numberId = numberId, requestNumbers = requestNumbers, navigationOnAccept = stored.navigationOnAccept or navigationDefaults[company.categoryId] or "disabled" }
end

local function notifyCreator(request, eventType)
    if not request then return end
    local phase = request.phase_id or request.phaseId
    local content = phase and (("%s - %s"):format(request.status or "updated", phase)) or (request.status or "updated")
    if request.creator_number then
        pcall(function()
            exports["lb-phone"]:SendNotification(request.creator_number, { app = ServicesPlus.Constants.AppIdentifier,
                title = request.request_label or request.requestLabel or "Request update", content = content })
        end)
    end
    for _, value in ipairs(GetPlayers()) do
        local target = tonumber(value)
        local player = target and ServicesPlus.Bridge.GetPlayer(target) or nil
        if player and player.identifier == request.creator_identifier then
            TriggerClientEvent("services-plus:client:push", target, { type = "request.citizen.updated", timestamp = os.time(), payload = Requests.ToPublic(request) })
        end
    end
    local integration = Requests.ToIntegration(request)
    TriggerEvent(("services-plus:server:%s"):format(eventType), integration)
    TriggerEvent("services-plus:server:requestUpdated", integration)
    emitLifecycle(lifecycleNames[eventType] or eventType, request)
end

local function requestPosition(source)
    local ok, coords = pcall(function()
        local ped = GetPlayerPed(source)
        return ped and ped ~= 0 and GetEntityCoords(ped) or nil
    end)
    if not ok or not coords then return nil, nil end
    local x, y = tonumber(coords.x), tonumber(coords.y)
    if not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then return nil, nil end
    return x, y
end

local function validateValues(template, values)
    if type(values) ~= "table" then return nil end
    local clean = {}
    local allowed = {}
    for _, field in ipairs(template.fields) do if field.enabled ~= false then allowed[field.id] = true end end
    for fieldId in pairs(values) do if type(fieldId) ~= "string" or not allowed[fieldId] then return nil end end
    for _, field in ipairs(template.fields) do
        if field.enabled ~= false then
        local value = values[field.id]
        if field.type == "select" then
            if value == nil then value = "" end
            if type(value) ~= "string" then return nil end
            local valid = false
            for _, option in ipairs(field.options or {}) do if option.value == value then valid = true break end end
            if field.required and not valid then return nil end
            if value ~= "" and not valid then return nil end
            if valid then clean[field.id] = value end
        elseif field.type == "people" then
            local numeric = tonumber(value)
            if field.required and not numeric then return nil end
            if numeric and (numeric < field.minimum or numeric > field.maximum or numeric % 1 ~= 0) then return nil end
            if numeric then clean[field.id] = numeric end
        else
            if value == nil then value = "" end
            if type(value) ~= "string" or #value > (field.maxLength or 500) or (field.required and #value < 1) then return nil end
            if field.type == "image" and value ~= "" and not value:match("^https?://") then return nil end
            if value ~= "" then clean[field.id] = value end
        end
        end
    end
    return clean
end

local function pushCompany(companyId, eventType, payload, availableOnly)
    local company = ServicesPlus.Companies.Get(companyId)
    if not company then return end
    local clientPayload = eventType:match("^request%.") and Requests.ToCompanyPublic(payload) or payload
    local companies = ServicesPlus.Companies.GetCategoryRequestCompetition(company.categoryId) and ServicesPlus.Companies.GetByCategory(company.categoryId) or { company }
    local sent = {}
    for _, audienceCompany in ipairs(companies) do
    if audienceCompany.requestsEnabled then
    for _, employee in ipairs(ServicesPlus.Employees.GetPublicForCompany(audienceCompany.id)) do
        local numberAllowed = true
        if audienceCompany.id == companyId and payload.target_number_id then
            local internal = ServicesPlus.Employees.Get(employee.source)
            for _, number in ipairs(audienceCompany.numbers) do
                if number.id == payload.target_number_id then numberAllowed = number.requestsEnabled and ServicesPlus.Employees.CanUseNumber(internal, number) break end
            end
        end
        if numberAllowed and not sent[employee.source] and (not availableOnly or (employee.status == "available" and not employee.activeCall and not employee.activeRequest)) then
            sent[employee.source] = true
            TriggerClientEvent("services-plus:client:push", employee.source, { type = eventType, timestamp = os.time(), payload = clientPayload })
            if eventType == "request.offer" then
                pcall(function()
                    exports["lb-phone"]:SendNotification(employee.source, {
                        app = ServicesPlus.Constants.AppIdentifier,
                        title = clientPayload.requestLabel or "New request",
                        content = clientPayload.companyName or "Services+",
                        customData = {
                            buttons = {
                                { title = "-", event = "services-plus:client:requestNotificationAction", data = { id = payload.id, action = "decline" }, remove = true },
                                { title = "+", event = "services-plus:client:requestNotificationAction", data = { id = payload.id, action = "accept" }, remove = true }
                            }
                        }
                    })
                end)
            end
        end
    end
    end
    end
end

function Requests.CanHandle(employee, request)
    if not employee or not request then return false end
    local requestCompanyId = request.company_id or request.companyId
    if employee.companyId == requestCompanyId then
        local targetNumberId = request.target_number_id or request.targetNumberId
        if not targetNumberId then return true end
        local company = ServicesPlus.Companies.Get(employee.companyId)
        for _, number in ipairs(company and company.numbers or {}) do
            if number.id == targetNumberId then return number.requestsEnabled and ServicesPlus.Employees.CanUseNumber(employee, number) end
        end
        return false
    end
    local requestCompany = ServicesPlus.Companies.Get(requestCompanyId)
    local employeeCompany = ServicesPlus.Companies.Get(employee.companyId)
    return requestCompany and employeeCompany and employeeCompany.requestsEnabled and requestCompany.categoryId == employeeCompany.categoryId
        and ServicesPlus.Companies.GetCategoryRequestCompetition(requestCompany.categoryId)
end

function Requests.Create(source, companyId, templateId, values, locale, external)
    local player = ServicesPlus.Bridge.GetPlayer(source)
    local company = ServicesPlus.Companies.Get(companyId)
    if not player or not company or not company.requestsEnabled then return false, "requests_disabled" end
    local resolved = Requests.ResolveSettings(company, locale)
    local enabled = false
    for _, id in ipairs(resolved.templateIds) do if id == templateId then enabled = true break end end
    local template
    for _, candidate in ipairs(resolved.templates) do if candidate.id == templateId then template = candidate break end end
    if not enabled or not template then return false, "template_disabled" end
    local clean = validateValues(template, values)
    if not clean then return false, "validation_failed" end
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(source)
    local locationX, locationY
    if company.categoryId == "taxi_transport" or resolved.navigationOnAccept ~= "disabled" then locationX, locationY = requestPosition(source) end
    if company.categoryId == "taxi_transport" and (not locationX or not locationY) then return false, "location_unavailable" end
    local requestId = ServicesPlus.Repository.CreateStructuredRequest({ identifier = player.identifier, phoneNumber = phoneNumber, companyId = companyId,
        templateId = templateId, requestLabel = resolved.label, values = clean, targetNumberId = resolved.numberId, locationX = locationX, locationY = locationY,
        externalSource = external and external.source or nil, externalId = external and external.id or nil })
    if not requestId then return false, "request_failed" end
    ServicesPlus.Repository.AddRequestEvent(requestId, player.identifier, "created", {})
    local request = ServicesPlus.Repository.GetRequestById(requestId)
    pushCompany(companyId, "request.offer", request, true)
    TriggerEvent("services-plus:server:requestCreated", Requests.ToIntegration(request))
    emitLifecycle("created", request)
    return true, Requests.ToPublic(request)
end

function Requests.Accept(source, requestId)
    ServicesPlus.Employees.ValidateEmployment(source)
    local employee = ServicesPlus.Employees.Get(source)
    local request = ServicesPlus.Repository.GetRequestById(requestId)
    if not Requests.CanHandle(employee, request) or employee.status ~= "available" then return false, "employee_unavailable" end
    local company = ServicesPlus.Companies.Get(request.company_id)
    local phases = Requests.ResolveSettings(company, Config.Locale).phases
    if not ServicesPlus.Repository.AcceptRequest(requestId, employee, phases[1].id) then return false, "already_accepted" end
    local assigned = ServicesPlus.Employees.AssignWork(source, "request", requestId)
    if not assigned then ServicesPlus.Repository.ReturnRequest(requestId, employee.identifier); return false, "employee_unavailable" end
    ServicesPlus.Repository.AddRequestEvent(requestId, employee.identifier, "accepted", { phaseId = phases[1].id })
    request = ServicesPlus.Repository.GetRequestById(requestId)
    pushCompany(request.company_id, "request.updated", request, false)
    local settings = Requests.ResolveSettings(company, Config.Locale)
    if request.location_x and request.location_y then
        local navigation = { id = request.id, x = tonumber(request.location_x), y = tonumber(request.location_y), mode = settings.navigationOnAccept, title = request.request_label }
        if settings.navigationOnAccept == "automatic" then
            TriggerClientEvent("services-plus:client:requestNavigation", source, navigation)
        elseif settings.navigationOnAccept == "ask" then
            pcall(function()
                exports["lb-phone"]:SendNotification(source, { app = ServicesPlus.Constants.AppIdentifier, title = request.request_label or "Request location", content = "Set request location as waypoint?",
                    customData = { buttons = { { title = "Navigate", event = "services-plus:client:requestNavigation", data = navigation, remove = true } } } })
            end)
        end
    end
    notifyCreator(request, "requestAccepted")
    return true, Requests.ToCompanyPublic(request)
end

function Requests.Decline(source, requestId)
    local employee = ServicesPlus.Employees.Get(source)
    local request = ServicesPlus.Repository.GetRequestById(requestId)
    if not Requests.CanHandle(employee, request) or (request.status ~= "pending" and request.status ~= "returned") then return false, "request_unavailable" end
    ServicesPlus.Repository.AddRequestEvent(requestId, employee.identifier, "declined", {})
    return true, { id = requestId }
end

function Requests.Transition(source, requestId, nextPhaseId)
    local employee = ServicesPlus.Employees.Get(source)
    local request = ServicesPlus.Repository.GetRequestById(requestId)
    if not employee or not request or request.assigned_identifier ~= employee.identifier or tostring(employee.activeRequest) ~= tostring(requestId) then return false, "forbidden" end
    local company = ServicesPlus.Companies.Get(request.company_id)
    local phases = Requests.ResolveSettings(company, Config.Locale).phases
    local currentIndex, nextIndex
    for index, phase in ipairs(phases) do if phase.id == request.phase_id then currentIndex = index end; if phase.id == nextPhaseId then nextIndex = index end end
    if not currentIndex or not nextIndex or nextIndex ~= currentIndex + 1 then return false, "invalid_transition" end
    local status = nextIndex == #phases and "completed" or "active"
    if not ServicesPlus.Repository.TransitionRequest(requestId, employee.identifier, status, nextPhaseId) then return false, "transition_failed" end
    ServicesPlus.Repository.AddRequestEvent(requestId, employee.identifier, status == "completed" and "completed" or "phase_changed", { phaseId = nextPhaseId })
    if status == "completed" then ServicesPlus.Employees.ReleaseWorkByIdentifier(employee.identifier, "request", requestId) end
    request = ServicesPlus.Repository.GetRequestById(requestId)
    pushCompany(request.company_id, "request.updated", request, false)
    notifyCreator(request, status == "completed" and "requestCompleted" or "requestPhaseChanged")
    return true, Requests.ToCompanyPublic(request)
end

function Requests.Return(source, requestId)
    local employee = ServicesPlus.Employees.Get(source)
    if not employee or not ServicesPlus.Repository.ReturnRequest(requestId, employee.identifier) then return false, "return_failed" end
    ServicesPlus.Repository.AddRequestEvent(requestId, employee.identifier, "returned", {})
    ServicesPlus.Employees.ReleaseWorkByIdentifier(employee.identifier, "request", requestId)
    local request = ServicesPlus.Repository.GetRequestById(requestId)
    pushCompany(request.company_id, "request.updated", request, false)
    pushCompany(request.company_id, "request.offer", request, true)
    notifyCreator(request, "requestReturned")
    return true, Requests.ToCompanyPublic(request)
end

function Requests.Cancel(source, requestId)
    local player = ServicesPlus.Bridge.GetPlayer(source)
    local request = ServicesPlus.Repository.GetRequestById(requestId)
    if not player or not request or not ServicesPlus.Repository.CancelRequest(requestId, player.identifier) then return false, "cancel_failed" end
    if request.assigned_identifier then ServicesPlus.Employees.ReleaseWorkByIdentifier(request.assigned_identifier, "request", requestId) end
    ServicesPlus.Repository.AddRequestEvent(requestId, player.identifier, "cancelled", {})
    request = ServicesPlus.Repository.GetRequestById(requestId)
    pushCompany(request.company_id, "request.updated", request, false)
    notifyCreator(request, "requestCancelled")
    return true, Requests.ToPublic(request)
end

function Requests.Delete(source, requestId)
    local employee = ServicesPlus.Employees.Get(source)
    local request = ServicesPlus.Repository.GetRequestById(requestId)
    if not employee or not employee.dispatchEnabled or not request or request.company_id ~= employee.companyId then return false, "forbidden" end
    if not ServicesPlus.Repository.DeleteRequest(requestId, employee.companyId, employee.identifier) then return false, "request_unavailable" end
    if request.assigned_identifier then ServicesPlus.Employees.ReleaseWorkByIdentifier(request.assigned_identifier, "request", requestId) end
    ServicesPlus.Repository.AddRequestEvent(requestId, employee.identifier, "deleted", {})
    request = ServicesPlus.Repository.GetRequestById(requestId)
    pushCompany(employee.companyId, "request.updated", request, false)
    notifyCreator(request, "requestDeleted")
    return true, { id = requestId }
end

function Requests.RefreshCategoryCompetition(categoryId)
    local requests = ServicesPlus.Repository.GetPendingRequestsByCategory(categoryId, 100)
    for _, company in ipairs(ServicesPlus.Companies.GetByCategory(categoryId)) do
        for _, employee in ipairs(ServicesPlus.Employees.GetPublicForCompany(company.id)) do
            for _, request in ipairs(requests) do
                TriggerClientEvent("services-plus:client:push", employee.source, { type = "request.offer.removed", timestamp = os.time(), payload = { id = request.id } })
            end
        end
    end
    for _, request in ipairs(requests) do pushCompany(request.company_id, "request.offer", request, true) end
end

function Requests.EmployeeLeft(employee)
    if not employee or not employee.activeRequest then return end
    if ServicesPlus.Repository.ReturnRequest(employee.activeRequest, employee.identifier) then
        ServicesPlus.Repository.AddRequestEvent(employee.activeRequest, employee.identifier, "returned_disconnect", {})
        local request = ServicesPlus.Repository.GetRequestById(employee.activeRequest)
        if request then pushCompany(request.company_id, "request.updated", request, false); pushCompany(request.company_id, "request.offer", request, true); notifyCreator(request, "requestReturned") end
    end
end

function Requests.SaveSettings(source, input)
    local employee = ServicesPlus.Employees.Get(source)
    local company = employee and ServicesPlus.Companies.Get(employee.companyId)
    if not employee or not employee.isLeader or not company or type(input) ~= "table" then return false, "forbidden" end
    if type(input.label) ~= "string" or #input.label < 2 or #input.label > 80 or type(input.createLabel) ~= "string" or #input.createLabel < 2 or #input.createLabel > 80 then return false, "validation_failed" end
    local validTemplates = {}
    for _, id in ipairs(input.templateIds or {}) do local template = definitions.templates[id]; if templateAllowed(company, template) then validTemplates[#validTemplates + 1] = id end end
    if #validTemplates == 0 then return false, "validation_failed" end
    local numberId = nil
    for _, number in ipairs(company.numbers) do if number.id == input.numberId and number.enabled and number.requestsEnabled then numberId = number.id break end end
    local fieldSettings = {}
    for templateId, values in pairs(type(input.fieldSettings) == "table" and input.fieldSettings or {}) do
        local template = definitions.templates[templateId]
        if template and type(values) == "table" then
            local supported = {}; for _, field in ipairs(template.fields) do supported[field.id] = true end
            fieldSettings[templateId] = {}
            for fieldId, setting in pairs(values) do
                if supported[fieldId] and type(setting) == "table" and type(setting.enabled) == "boolean" and type(setting.required) == "boolean" then
                    fieldSettings[templateId][fieldId] = { enabled = setting.enabled, required = setting.required }
                end
            end
        end
    end
    if not ServicesPlus.Constants.NavigationModes[input.navigationOnAccept] then return false, "validation_failed" end
    local settings = { label = input.label, createLabel = input.createLabel, templateIds = validTemplates, fieldSettings = fieldSettings, numberId = numberId, navigationOnAccept = input.navigationOnAccept }
    ServicesPlus.Repository.SaveRequestSettings(company.id, settings)
    return true, Requests.ResolveSettings(company, Config.Locale)
end
