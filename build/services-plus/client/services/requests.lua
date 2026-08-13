local owner = GetCurrentResourceName()
local peekByRequest = {}
local requestByPeek = {}
local activeRequestId = nil
local distanceToken = 0

local function requestId(payload)
    return payload and tonumber(payload.requestId)
end

local function forgetRequest(id)
    local peekId = peekByRequest[id]
    if peekId then requestByPeek[peekId] = nil end
    peekByRequest[id] = nil
    if activeRequestId == id then
        activeRequestId = nil
        distanceToken = distanceToken + 1
    end
end

local function removeRequest(id, reason)
    local peekId = peekByRequest[id]
    if peekId then PeekPlus.Remove(peekId, owner, nil, nil, reason) end
    forgetRequest(id)
end

local function pendingCard(payload)
    return {
        key = ("service-request:%s"):format(payload.requestId),
        state = "pending",
        variant = "info",
        template = "action",
        title = tostring(payload.typeName or "New request"),
        subtitle = tostring(payload.companyName or Config.App.name),
        description = tostring(payload.description or ""),
        duration = Config.RequestNotificationPeekDuration or 15000,
        hold = false,
        sound = true,
        priority = 0,
        actions = {
            { id = "decline", label = "Backspace · Decline", key = "BACK", color = "danger" },
            { id = "accept", label = "Enter · Accept", key = "RETURN", color = "success" },
        },
    }
end

local function activeDescription(payload, distance)
    local parts = {}
    if payload.passengerCount then
        parts[#parts + 1] = ("%s: %s"):format(payload.countLabel or "Passenger count", payload.passengerCount)
    end
    if type(distance) == "number" then parts[#parts + 1] = ("%.1f mi"):format(distance / 1609.34) end
    return table.concat(parts, " · ")
end

local function activeCard(payload)
    return {
        key = ("service-request:%s"):format(payload.requestId),
        state = "active",
        variant = "success",
        template = "action",
        title = tostring(payload.typeName or "Active request"),
        subtitle = tostring(payload.companyName or Config.App.name),
        description = activeDescription(payload),
        duration = -1,
        hold = true,
        sound = false,
        priority = 0,
        actions = {
            {
                id = "cancel",
                label = "Cancel",
                key = "BACK",
                color = "danger",
                confirm = { label = "Confirm?", timeout = 5000 },
            },
            { id = "complete", label = "Complete", color = "success" },
        },
    }
end

local function startDistanceUpdates(payload, peekId)
    distanceToken = distanceToken + 1
    local token = distanceToken
    if type(payload.x) ~= "number" or type(payload.y) ~= "number" then return end

    SetNewWaypoint(payload.x, payload.y)
    CreateThread(function()
        while token == distanceToken and activeRequestId == requestId(payload) do
            local coords = GetEntityCoords(PlayerPedId())
            local distance = #(vector2(coords.x, coords.y) - vector2(payload.x, payload.y))
            local current = PeekPlus.Get(peekId, owner)
            if not current then return end
            PeekPlus.UpdatePresentation(peekId, { description = activeDescription(payload, distance) }, owner)
            Wait(2000)
        end
    end)
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
    local peekId = peekByRequest[id]
    local success = false
    if peekId and PeekPlus.Get(peekId, owner) then
        success = PeekPlus.Update(peekId, activeCard(payload), owner)
    else
        peekId = PeekPlus.Show(activeCard(payload), owner)
        success = peekId ~= nil
    end
    if not success then return false end

    peekByRequest[id] = peekId
    requestByPeek[peekId] = { requestId = id, payload = payload }
    activeRequestId = id
    startDistanceUpdates(payload, peekId)
    return true
end

RegisterNetEvent("services-plus:client:requestNotification", showPending)

RegisterNetEvent("services-plus:client:requestClaimed", function(id)
    id = tonumber(id)
    if id then removeRequest(id, "claimed") end
end)

RegisterNetEvent("services-plus:client:requestAccepted", showActive)

RegisterNetEvent("services-plus:client:requestEnded", function(id)
    id = tonumber(id)
    if id then removeRequest(id, "ended") end
end)

PeekPlus.RegisterActionHandler(owner, function(data)
    local context = requestByPeek[data.id]
    if not context then return end
    local id = context.requestId

    if data.action == "decline" then
        removeRequest(id, "declined")
        return
    end

    if data.action == "accept" then
        local ok, result = ServerCallback("acceptRequest", id)
        if not (ok and result) then removeRequest(id, "accept_failed") end
        return
    end

    if data.action == "cancel" then
        local ok, result = ServerCallback("cancelRequest", id)
        if not (ok and result == true) and PeekPlus.Get(data.id, owner) then
            PeekPlus.ReleaseAction(data.id, owner, data.actionToken)
        end
        return
    end

    if data.action == "complete" then
        local ok, result = ServerCallback("completeRequest", id)
        if not (ok and result == true) and PeekPlus.Get(data.id, owner) then
            PeekPlus.ReleaseAction(data.id, owner, data.actionToken)
        end
        return
    end

    PeekPlus.ReleaseAction(data.id, owner, data.actionToken)
end)

AddEventHandler(("peekplus:lifecycle:%s"):format(owner), function(data)
    if type(data) ~= "table" or data.removed ~= true then return end
    local context = requestByPeek[data.id]
    if context then forgetRequest(context.requestId) end
end)

PeekPlus.RegisterReadyHandler(function()
    if activeRequestId and peekByRequest[activeRequestId]
        and PeekPlus.Get(peekByRequest[activeRequestId], owner) then return end
    local ok, payload = ServerCallback("getActiveRequest")
    if ok and payload then showActive(payload) end
end)
