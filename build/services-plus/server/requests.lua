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
    if not template or template.kind ~= "specialized" then return false end
    for _, categoryId in ipairs(template.categoryIds or {}) do if categoryId == company.categoryId then return true end end
    return false
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
        targetNumberId = value(request, "target_number_id", "targetNumberId"),
        payload = request.payload or {},
        createdAt = value(request, "created_at", "createdAt"),
        updatedAt = value(request, "updated_at", "updatedAt")
    }
end

function Requests.ToCompanyPublic(request)
    local result = Requests.ToPublic(request)
    if result then
        result.assignee = assignee(request, false)
        local x, y = tonumber(value(request, "location_x", "locationX")), tonumber(value(request, "location_y", "locationY"))
        if x and y then result.location = { x = x, y = y } end
    end
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
    requestAccepted = "accepted", requestReturned = "returned",
    requestCancelled = "cancelled", requestDeleted = "deleted"
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
    -- Navigation on acceptance defaults to automatic for every category now - dispatches
    -- are meant to be zero-config; a leader can only rename the dispatch and change this.
    return { label = stored.label or (locale == "de" and "Anfrage" or "Request"), createLabel = stored.createLabel or stored.label or (locale == "de" and "Anfrage erstellen" or "Create request"), templateIds = templateIds, templates = templates, fieldSettings = stored.fieldSettings or {}, numberId = numberId, requestNumbers = requestNumbers, navigationOnAccept = stored.navigationOnAccept or "automatic" }
end

local function notifyCreator(request, eventType)
    if not request then return end
    local content = request.status or "updated"
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
            if eventType == "request.offer" then
                -- Most companies just get informed - no buttons, and nothing forces the
                -- phone open (see client/app.lua). Only companies that opted into
                -- actionable request notifications (time-critical work: taxi, PD, EMS)
                -- get Accept/Decline right in the notification and the full "looks like
                -- an incoming call" in-app screen, the same as a real call would.
                local actionable = audienceCompany.requestNotificationActionable == true
                local offerPayload = {}
                for key, value in pairs(clientPayload) do offerPayload[key] = value end
                offerPayload.actionable = actionable
                TriggerClientEvent("services-plus:client:push", employee.source, { type = eventType, timestamp = os.time(), payload = offerPayload })
                local notification = {
                    app = ServicesPlus.Constants.AppIdentifier,
                    title = clientPayload.requestLabel or "New request",
                    content = clientPayload.companyName or "Services+"
                }
                if actionable then
                    notification.customData = {
                        buttons = {
                            { title = "-", event = "services-plus:client:requestNotificationAction", data = { id = payload.id, action = "decline" }, remove = true },
                            { title = "+", event = "services-plus:client:requestNotificationAction", data = { id = payload.id, action = "accept" }, remove = true }
                        }
                    }
                end
                pcall(function() exports["lb-phone"]:SendNotification(employee.source, notification) end)
            else
                TriggerClientEvent("services-plus:client:push", employee.source, { type = eventType, timestamp = os.time(), payload = clientPayload })
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

function Requests.Create(source, companyId, templateId, values, locale, external, clientRequestId)
    local player = ServicesPlus.Bridge.GetPlayer(source)
    if not player then return false, "requests_disabled" end
    local scopeKey = clientRequestId and ("createRequest:" .. player.identifier .. ":" .. clientRequestId) or nil
    return ServicesPlus.Idempotency.Resolve(scopeKey, function()
        local company = ServicesPlus.Companies.Get(companyId)
        if not company or not company.requestsEnabled then return false, "requests_disabled" end
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
    end)
end

function Requests.Accept(source, requestId)
    ServicesPlus.Employees.ValidateEmployment(source)
    local employee = ServicesPlus.Employees.Get(source)
    local request = ServicesPlus.Repository.GetRequestById(requestId)
    if not Requests.CanHandle(employee, request) or employee.status ~= "available" then return false, "employee_unavailable" end
    local company = ServicesPlus.Companies.Get(request.company_id)
    if not ServicesPlus.Repository.AcceptRequest(requestId, employee) then return false, "already_accepted" end
    local assigned = ServicesPlus.Employees.AssignWork(source, "request", requestId)
    if not assigned then ServicesPlus.Repository.ReturnRequest(requestId, employee.identifier); return false, "employee_unavailable" end
    ServicesPlus.Repository.AddRequestEvent(requestId, employee.identifier, "accepted", {})
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

-- Lets an eligible employee (re-)set the GPS waypoint to a request's captured
-- location on demand, independent of the accept-time navigationOnAccept setting.
function Requests.Navigate(source, requestId)
    ServicesPlus.Employees.ValidateEmployment(source)
    local employee = ServicesPlus.Employees.Get(source)
    local request = ServicesPlus.Repository.GetRequestById(requestId)
    if not Requests.CanHandle(employee, request) then return false, "forbidden" end
    local x, y = tonumber(value(request, "location_x", "locationX")), tonumber(value(request, "location_y", "locationY"))
    if not x or not y then return false, "location_unavailable" end
    TriggerClientEvent("services-plus:client:requestNavigation", source, { id = request.id, x = x, y = y, title = value(request, "request_label", "requestLabel") })
    return true, { id = requestId }
end

function Requests.Decline(source, requestId)
    local employee = ServicesPlus.Employees.Get(source)
    local request = ServicesPlus.Repository.GetRequestById(requestId)
    if not Requests.CanHandle(employee, request) or (request.status ~= "pending" and request.status ~= "returned") then return false, "request_unavailable" end
    ServicesPlus.Repository.AddRequestEvent(requestId, employee.identifier, "declined", {})
    return true, { id = requestId }
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
    if not employee or not request or request.company_id ~= employee.companyId then return false, "forbidden" end
    -- A dispatcher can clear any of the company's requests; the employee who accepted
    -- one can also resolve it themselves this way - accept/decline/delete is the whole
    -- workflow now, there is no separate "mark as done" step.
    local isAssignee = request.assigned_identifier == employee.identifier
    if not employee.dispatchEnabled and not isAssignee then return false, "forbidden" end
    if not ServicesPlus.Repository.DeleteRequest(requestId, employee.companyId, employee.identifier) then return false, "request_unavailable" end
    if request.assigned_identifier then ServicesPlus.Employees.ReleaseWorkByIdentifier(request.assigned_identifier, "request", requestId) end
    ServicesPlus.Repository.AddRequestEvent(requestId, employee.identifier, "deleted", {})
    request = ServicesPlus.Repository.GetRequestByIdIncludingDeleted(requestId)
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

-- A leader can only rename the dispatch and choose navigation-on-acceptance now - which
-- templates/fields/number apply is derived automatically (all templates configured for
-- the company's category, full fields, first eligible number), no leader config needed.
function Requests.SaveSettings(source, input)
    local employee = ServicesPlus.Employees.Get(source)
    local company = employee and ServicesPlus.Companies.Get(employee.companyId)
    if not employee or not employee.isLeader or not company or type(input) ~= "table" then return false, "forbidden" end
    if type(input.label) ~= "string" or #input.label < 2 or #input.label > 80 then return false, "validation_failed" end
    if not ServicesPlus.Constants.NavigationModes[input.navigationOnAccept] then return false, "validation_failed" end
    ServicesPlus.Repository.SaveRequestSettings(company.id, { label = input.label, createLabel = input.label, navigationOnAccept = input.navigationOnAccept })
    return true, Requests.ResolveSettings(company, Config.Locale)
end
