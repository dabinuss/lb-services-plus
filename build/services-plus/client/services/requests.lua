local owner = GetCurrentResourceName()
local peekByRequest = {}
local requestByPeek = {}
local activeRequestId = nil
local distanceToken = 0
local journeyReporterRequestId = nil
local journeyReporterToken = 0
local customerPeekByRequest = {}
local customerRequestByPeek = {}
local pendingActionByRequest = {}
local requestTypeTemplates = {}
local requestTypeTemplateDefinitions = {}
local rawJourneyConfig = type(Config.RequestJourneyTracking) == "table" and Config.RequestJourneyTracking or {}
local JOURNEY_TRACKING_ENABLED = rawJourneyConfig.enabled ~= false
local JOURNEY_REPORT_INTERVAL = math.max(5000, math.min(60000,
    tonumber(rawJourneyConfig.updateInterval) or 15000))

local function normalizeIdentifier(value)
    if type(value) ~= "string" then return nil end
    local identifier = value:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if identifier == "" then return nil end
    return identifier
end

local function collectTemplates(identifier, definitions)
    identifier = normalizeIdentifier(identifier)
    if not identifier or type(definitions) ~= "table" then return end

    requestTypeTemplateDefinitions[identifier] = requestTypeTemplateDefinitions[identifier] or {}
    for _, state in ipairs({ "pending", "active" }) do
        local definition = definitions[state]
        if type(definition) == "table" then requestTypeTemplateDefinitions[identifier][state] = definition end
    end
end

for i = 1, #(Config.DefaultRequestTypes or {}) do
    local requestType = Config.DefaultRequestTypes[i]
    collectTemplates(requestType.identifier or requestType.name, requestType.templates)
end
for identifier, definitions in pairs(Config.RequestTypeTemplates or {}) do
    collectTemplates(identifier, definitions)
end

for identifier, definitions in pairs(requestTypeTemplateDefinitions) do
    requestTypeTemplates[identifier] = {}
    for _, state in ipairs({ "pending", "active" }) do
        local definition = definitions[state]
        if definition then
            local template, err = PeekPlus.RegisterTemplate(
                owner,
                ("request-type-%s-%s"):format(identifier, state),
                definition
            )
            assert(template, ("Failed to register %s template for request type '%s': %s")
                :format(state, identifier, tostring(err)))
            requestTypeTemplates[identifier][state] = template
        end
    end
end

local function requestTemplate(payload, state)
    local identifier = normalizeIdentifier(payload.requestType or payload.typeIcon)
    local templates = identifier and requestTypeTemplates[identifier] or nil
    return templates and templates[state] or "services"
end

local categoryIcons = {
    police = "police",
    government = "government",
    law = "law",
    medical = "medical",
    taxi = "taxi",
    car_dealer = "car-dealer",
    mechanic = "wrench",
    towing = "tow-truck",
    carwash = "car-wash",
    restaurant = "restaurant",
    bar = "bar",
    barber = "barber",
    tattoo = "tattoo",
    music = "music",
    news = "news",
    shop = "shop",
    community = "people",
    funeral = "funeral",
}

local function requestIcon(payload)
    return categoryIcons[tostring(payload.category or "")] or payload.typeIcon or "request"
end

-- Branding is optional presentation. A stale DB row or old server payload
-- must never suppress the gameplay notification when its image is rejected.
local function companyIconUrl(value)
    if type(value) ~= "string" or #value > 255 or value:find("[%s%c]")
        or value:sub(1, 8):lower() ~= "https://" then return nil end
    local authority = value:sub(9):match("^([^/%?#]+)")
    if not authority or authority:find("@", 1, true)
        or not PeekPlusLBPhone.IsMediaLinkAllowed(value) then return nil end
    return value
end

local function requestId(payload)
    return payload and tonumber(payload.requestId)
end

local function label(payload, key, fallback)
    return payload.labels and payload.labels[key] or fallback
end

local activeDetails

local function distanceFromPlayer(payload)
    if type(payload.x) ~= "number" or type(payload.y) ~= "number" then return nil end
    local coords = GetEntityCoords(PlayerPedId())
    return #(vector2(coords.x, coords.y) - vector2(payload.x, payload.y))
end

-- Uses GTA's road pathfinder directly between two coordinate pairs. It does
-- not read, create, replace or clear the player's personal waypoint/GPS route.
local function independentTravelDistance(payload, coords)
    if type(payload.x) ~= "number" or type(payload.y) ~= "number" then return nil end
    coords = coords or GetEntityCoords(PlayerPedId())
    local airDistance = #(vector2(coords.x, coords.y) - vector2(payload.x, payload.y))
    local roadDistance = CalculateTravelDistanceBetweenPoints(
        coords.x, coords.y, coords.z, payload.x, payload.y, coords.z
    )
    roadDistance = tonumber(roadDistance)
    local maximumPlausible = math.max(airDistance * 4, airDistance + 2000)
    if not roadDistance or roadDistance ~= roadDistance or roadDistance <= 0
        or roadDistance < airDistance * 0.8 or roadDistance > maximumPlausible
        or roadDistance > 100000 then
        return airDistance
    end
    return math.max(roadDistance, airDistance)
end

local function forgetRequest(id)
    local peekId = peekByRequest[id]
    if peekId then requestByPeek[peekId] = nil end
    peekByRequest[id] = nil
    pendingActionByRequest[id] = nil
    if activeRequestId == id then
        activeRequestId = nil
        distanceToken = distanceToken + 1
    end
end

local function removeRequest(id, reason, actionContext)
    local peekId = peekByRequest[id]
    local removed = true
    if peekId then
        if actionContext then
            removed = PeekPlus.ResolveAction(
                peekId,
                owner,
                actionContext.actionToken,
                actionContext.revision,
                { remove = true, reason = reason }
            )
        else
            removed = PeekPlus.Remove(peekId, owner, nil, nil, reason)
        end
    end
    if not removed then return false end
    forgetRequest(id)
    return true
end

local function pendingCard(payload)
    return {
        key = ("service-request:%s"):format(payload.requestId),
        state = "pending",
        variant = "info",
        template = requestTemplate(payload, "pending"),
        layout = "details",
        icon = requestIcon(payload),
        iconUrl = companyIconUrl(payload.companyIcon),
        title = tostring(payload.typeName or label(payload, "newRequest", "New request")),
        subtitle = tostring(payload.companyName or Config.App.name),
        description = tostring(payload.description or ""),
        details = activeDetails(payload, distanceFromPlayer(payload)),
        duration = Config.RequestNotificationPeekDuration or 15000,
        queueTtl = Config.RequestNotificationQueueTtl or 20000,
        hold = false,
        dismissible = true,
        sound = true,
        priority = 0,
        actions = {
            {
                id = "decline",
                label = ("Backspace · %s"):format(label(payload, "decline", "Decline")),
                successLabel = label(payload, "declined", "Declined"),
                key = "BACK",
                color = "danger",
            },
            {
                id = "accept",
                label = ("Enter · %s"):format(label(payload, "accept", "Accept")),
                successLabel = label(payload, "accepted", "Accepted"),
                key = "RETURN",
                color = "success",
            },
        },
    }
end

local function reportedPickup(payload)
    if type(payload.reportedPickup) == "string" and payload.reportedPickup ~= "" then
        return payload.reportedPickup
    end
    if type(payload.x) ~= "number" or type(payload.y) ~= "number" then return label(payload, "markedLocation", "Marked location") end

    local streetHash, crossingHash = GetStreetNameAtCoord(payload.x, payload.y, 0.0)
    local street = streetHash and streetHash ~= 0 and GetStreetNameFromHashKey(streetHash) or ""
    local crossing = crossingHash and crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or ""

    if street == "" then street = label(payload, "markedLocation", "Marked location") end
    if crossing ~= "" and crossing ~= street then street = ("%s / %s"):format(street, crossing) end
    payload.reportedPickup = street
    return street
end

activeDetails = function(payload, distance)
    local details = {}
    if payload.passengerCount ~= nil then
        details[#details + 1] = {
            label = tostring(payload.countLabel or label(payload, "passengerCount", "Passenger count")),
            value = tostring(payload.passengerCount),
            icon = "people",
        }
    end
    details[#details + 1] = { label = label(payload, "reportedLocation", "Reported location"), value = reportedPickup(payload), icon = "location" }
    if type(distance) == "number" then
        details[#details + 1] = {
            label = label(payload, "distance", "Distance"),
            value = ("%.1f mi"):format(distance / 1609.34),
            icon = "distance",
        }
    end
    return details
end

local function activeCard(payload)
    return {
        key = ("service-request:%s"):format(payload.requestId),
        state = "active",
        variant = "success",
        template = requestTemplate(payload, "active"),
        layout = "details",
        icon = requestIcon(payload),
        iconUrl = companyIconUrl(payload.companyIcon),
        templateData = { statusLabel = label(payload, "activeRequest", "Active request") },
        title = tostring(payload.typeName or label(payload, "activeRequest", "Active request")),
        subtitle = tostring(payload.companyName or Config.App.name),
        description = type(payload.description) == "string" and payload.description ~= ""
            and payload.description or nil,
        details = activeDetails(payload),
        duration = -1,
        hold = true,
        sound = false,
        priority = 0,
        actions = {
            {
                id = "cancel",
                label = label(payload, "cancel", "Cancel"),
                successLabel = label(payload, "cancelled", "Cancelled"),
                key = "BACK",
                color = "danger",
                confirm = { label = label(payload, "confirm", "Confirm?"), timeout = 5000 },
            },
            {
                id = "complete",
                label = ("Enter · %s"):format(label(payload, "completeRequest", "Complete request")),
                successLabel = label(payload, "completed", "Completed"),
                key = "RETURN",
                color = "success",
                confirm = { label = label(payload, "confirmCompletion", "Confirm completion?"), timeout = 5000 },
            },
        },
    }
end

local function startDistanceUpdates(payload, peekId)
    distanceToken = distanceToken + 1
    local token = distanceToken
    if type(payload.x) ~= "number" or type(payload.y) ~= "number" then return end

    CreateThread(function()
        while token == distanceToken and activeRequestId == requestId(payload) do
            local coords = GetEntityCoords(PlayerPedId())
            local distance = #(vector2(coords.x, coords.y) - vector2(payload.x, payload.y))
            local current = PeekPlus.Get(peekId, owner)
            if not current then return end
            PeekPlus.UpdatePresentation(peekId, { details = activeDetails(payload, distance) }, owner)
            Wait(2000)
        end
    end)
end

local function stopJourneyReporter(id)
    id = tonumber(id)
    if id and journeyReporterRequestId ~= id then return end
    journeyReporterRequestId = nil
    journeyReporterToken = journeyReporterToken + 1
end

local function startJourneyReporter(payload)
    local id = requestId(payload)
    if not id or type(payload.x) ~= "number" or type(payload.y) ~= "number"
        or not JOURNEY_TRACKING_ENABLED then return end

    journeyReporterToken = journeyReporterToken + 1
    local token = journeyReporterToken
    journeyReporterRequestId = id

    CreateThread(function()
        while token == journeyReporterToken and journeyReporterRequestId == id do
            local coords = GetEntityCoords(PlayerPedId())
            TriggerServerEvent("services-plus:server:requestJourneyProgress", id,
                independentTravelDistance(payload, coords))
            Wait(JOURNEY_REPORT_INTERVAL)
        end
    end)
end

local function upsertPeek(index, id, card, actionContext)
    local peekId = index[id]
    if peekId and PeekPlus.Get(peekId, owner) then
        local updated
        if actionContext then
            updated = PeekPlus.ResolveAction(
                peekId,
                owner,
                actionContext.actionToken,
                actionContext.revision,
                { update = card }
            )
        else
            updated = PeekPlus.Update(peekId, card, owner)
        end
        return updated and peekId or nil
    end
    return PeekPlus.Show(card, owner)
end

local function showPending(payload)
    local id = requestId(payload)
    if not id then return false end
    local existing = peekByRequest[id]
    if existing and PeekPlus.Get(existing, owner) then return true end
    forgetRequest(id)

    local peekId = PeekPlus.Show(pendingCard(payload), owner)
    if not peekId then return false end
    peekByRequest[id] = peekId
    requestByPeek[peekId] = { requestId = id, payload = payload }
    return true
end

local function showActive(payload)
    local id = requestId(payload)
    if not id then return false end
    local actionContext = pendingActionByRequest[id]
    if actionContext and actionContext.action ~= "accept" then actionContext = nil end
    if actionContext then pendingActionByRequest[id] = nil end
    local peekId = upsertPeek(peekByRequest, id, activeCard(payload), actionContext)
    if not peekId then return false end

    peekByRequest[id] = peekId
    requestByPeek[peekId] = { requestId = id, payload = payload }
    activeRequestId = id
    startDistanceUpdates(payload, peekId)
    startJourneyReporter(payload)
    return true
end

local function customerJourneyCard(payload)
    return {
        key = ("customer-service-request:%s"):format(payload.requestId),
        state = "active",
        variant = payload.arrived and "success" or "info",
        template = "services",
        layout = "details",
        icon = requestIcon(payload),
        iconUrl = companyIconUrl(payload.companyIcon),
        title = tostring(payload.title),
        subtitle = tostring(payload.subtitle or Config.App.name),
        description = payload.description,
        details = payload.details or {},
        duration = payload.arrived and (Config.RequestNotificationPeekDuration or 15000) or -1,
        hold = not payload.arrived,
        sound = true,
        priority = 0,
        actions = {},
    }
end

local function showCustomerJourney(payload)
    local id = payload and tonumber(payload.requestId)
    if not id then return false end
    local peekId = upsertPeek(customerPeekByRequest, id, customerJourneyCard(payload))
    if not peekId then return false end
    customerPeekByRequest[id] = peekId
    customerRequestByPeek[peekId] = id
    return true
end

local function updateCustomerJourney(payload)
    local id = payload and tonumber(payload.requestId)
    if not id then return end
    local peekId = customerPeekByRequest[id]
    if not peekId or not PeekPlus.Get(peekId, owner) then
        return showCustomerJourney(payload)
    end

    if payload.arrived then
        PeekPlus.Update(peekId, customerJourneyCard(payload), owner)
    else
        PeekPlus.UpdatePresentation(peekId, {
            title = payload.title,
            subtitle = payload.subtitle,
            description = payload.description,
            details = payload.details or {},
        }, owner)
    end
end

local function endCustomerJourney(id, reason)
    id = tonumber(id)
    if not id then return end
    local peekId = customerPeekByRequest[id]
    if peekId then
        customerRequestByPeek[peekId] = nil
        PeekPlus.Remove(peekId, owner, nil, nil, reason or "request_ended")
    end
    customerPeekByRequest[id] = nil
end

RegisterNetEvent("services-plus:client:requestNotification", showPending)

RegisterNetEvent("services-plus:client:requestClaimed", function(id)
    id = tonumber(id)
    if id then removeRequest(id, "claimed") end
end)

RegisterNetEvent("services-plus:client:requestAccepted", showActive)

RegisterNetEvent("services-plus:client:requestEnded", function(id, reason)
    id = tonumber(id)
    if id then
        stopJourneyReporter(id)
        local actionId = reason == "completed" and "complete" or reason == "cancelled" and "cancel" or nil
        local actionContext = pendingActionByRequest[id]
        if not actionContext or actionContext.action ~= actionId then actionContext = nil end
        if actionContext then pendingActionByRequest[id] = nil end
        removeRequest(id, reason or "ended", actionContext)
    end
end)

RegisterNetEvent("services-plus:client:requestJourneyStarted", showCustomerJourney)
RegisterNetEvent("services-plus:client:requestJourneyProgress", updateCustomerJourney)

RegisterNetEvent("services-plus:client:requestJourneyEnded", function(id, reason)
    endCustomerJourney(id, reason)
end)

RegisterNetEvent("services-plus:client:requestJourneyReporterStopped", function(id)
    id = tonumber(id)
    if id then stopJourneyReporter(id) end
end)

PeekPlus.RegisterActionHandler(owner, function(data)
    local context = requestByPeek[data.id]
    if not context then return end
    local id = context.requestId

    if data.action == "decline" then
        removeRequest(id, "declined", data)
        return
    end

    if data.action == "accept" then
        pendingActionByRequest[id] = data
        local ok, result = ServerCallback("acceptRequest", id)
        if not (ok and result) then
            if pendingActionByRequest[id] == data then pendingActionByRequest[id] = nil end
            if PeekPlus.Get(data.id, owner) then PeekPlus.ReleaseAction(data.id, owner, data.actionToken) end
        end
        return
    end

    if data.action == "cancel" then
        pendingActionByRequest[id] = data
        local ok, result = ServerCallback("cancelRequest", id)
        if not (ok and result == true) then
            if pendingActionByRequest[id] == data then pendingActionByRequest[id] = nil end
            if PeekPlus.Get(data.id, owner) then PeekPlus.ReleaseAction(data.id, owner, data.actionToken) end
        end
        return
    end

    if data.action == "complete" then
        pendingActionByRequest[id] = data
        local ok, result = ServerCallback("completeRequest", id)
        if not (ok and result == true) then
            if pendingActionByRequest[id] == data then pendingActionByRequest[id] = nil end
            if PeekPlus.Get(data.id, owner) then PeekPlus.ReleaseAction(data.id, owner, data.actionToken) end
        end
        return
    end

    PeekPlus.ReleaseAction(data.id, owner, data.actionToken)
end)

AddEventHandler(("peekplus:lifecycle:%s"):format(owner), function(data)
    if type(data) ~= "table" or data.removed ~= true then return end
    local context = requestByPeek[data.id]
    if context then forgetRequest(context.requestId) end
    local customerRequestId = customerRequestByPeek[data.id]
    if customerRequestId then
        customerRequestByPeek[data.id] = nil
        customerPeekByRequest[customerRequestId] = nil
    end
end)

PeekPlus.RegisterReadyHandler(function()
    local hasActiveCard = activeRequestId and peekByRequest[activeRequestId]
        and PeekPlus.Get(peekByRequest[activeRequestId], owner)
    if not hasActiveCard then
        local ok, payload = ServerCallback("getActiveRequest")
        if ok and payload then showActive(payload) end
    elseif not journeyReporterRequestId then
        local context = requestByPeek[peekByRequest[activeRequestId]]
        if context then startJourneyReporter(context.payload) end
    end

    local journeysOk, journeys = ServerCallback("getCustomerRequestJourneys")
    if journeysOk and type(journeys) == "table" then
        for i = 1, #journeys do showCustomerJourney(journeys[i]) end
    end
end)
