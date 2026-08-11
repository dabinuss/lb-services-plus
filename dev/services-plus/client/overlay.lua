--[[
    Sibling-NUI controller for request notifications (plan §42-49,
    SIBLING-NUI.md). This is the ONLY thing that touches lb-phone's DOM -
    the actual Services+ app stays a normal, independent custom app.

    This resource's own `ui_page` (see fxmanifest.lua) points at
    ui/overlay/index.html, a tiny invisible page whose only job is to find
    the CitizenFX root NUI document and render a notification/active-request
    card into it - reachable and usable even at phone-peek or fully closed
    (plan §44), since it isn't anchored inside the phone's own iframe.
]]

local queue = {} -- pending request notifications, oldest first
local shown = nil -- requestId currently displayed as a *pending* notification
local shownPayload = nil -- its full payload, kept so a NUI reload can re-show it exactly (plan review §14)
local active = nil -- the full accept reply currently displayed as the *active* card
local distanceThread = nil

local function sendToOverlay(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function showNext()
    if shown or active or #queue == 0 then return end

    local payload = table.remove(queue, 1)
    shown = payload.requestId
    shownPayload = payload
    sendToOverlay("requestNotification", { payload = payload })
end

RegisterNetEvent("services-plus:client:requestNotification", function(payload)
    if shown == payload.requestId or active ~= nil and active.requestId == payload.requestId then return end

    table.insert(queue, payload)
    showNext()
end)

RegisterNetEvent("services-plus:client:requestClaimed", function(requestId)
    for i = #queue, 1, -1 do
        if queue[i].requestId == requestId then table.remove(queue, i) end
    end

    if shown == requestId then
        shown = nil
        shownPayload = nil
        sendToOverlay("dismiss", { requestId = requestId })
        showNext()
    end
end)

local function stopDistanceUpdates()
    distanceThread = nil
end

local function startDistanceUpdates()
    local thisThread = {}
    distanceThread = thisThread

    CreateThread(function()
        while distanceThread == thisThread and active do
            local coords = GetEntityCoords(PlayerPedId())
            local distance = #(vector2(coords.x, coords.y) - vector2(active.x, active.y))

            sendToOverlay("updateDistance", { distance = distance })
            Wait(2000)
        end
    end)
end

RegisterNUICallback("overlayAction", function(data, cb)
    local action = data.action
    local requestId = data.requestId

    if action == "decline" then
        if shown == requestId then
            shown = nil
            shownPayload = nil
        end
        showNext()
        return cb(true)
    end

    if action == "accept" then
        local ok, result = ServerCallback("acceptRequest", requestId)

        if ok and result then
            shown = nil
            shownPayload = nil
            active = result

            if type(result.x) == "number" and type(result.y) == "number" then
                SetNewWaypoint(result.x, result.y)
            end

            sendToOverlay("showActive", { payload = result })
            startDistanceUpdates()
        else
            if shown == requestId then
                shown = nil
                shownPayload = nil
            end
            sendToOverlay("dismiss", { requestId = requestId })
        end

        showNext()
        return cb(ok and result ~= false)
    end

    if action == "complete" or action == "cancel" then
        local ok, result = ServerCallback(action == "complete" and "completeRequest" or "cancelRequest", requestId)

        if ok and result and active and active.requestId == requestId then
            active = nil
            stopDistanceUpdates()
            sendToOverlay("clearActive", {})
            showNext()
        end

        return cb(ok and result == true)
    end

    cb(false)
end)

-- Sent once the overlay page's own message listener is ready (see
-- SIBLING-NUI.md's "Bereitschaft an Lua melden") - reply with whatever is
-- currently supposed to be on screen so a reload never loses state.
RegisterNUICallback("ready", function(_, cb)
    if active then
        sendToOverlay("showActive", { payload = active })
        startDistanceUpdates()
    elseif shownPayload then
        sendToOverlay("requestNotification", { payload = shownPayload })
    else
        -- Neither is tracked locally - most likely this client resource
        -- itself just (re)started while the player had an active request.
        -- The database still knows even though our in-memory state doesn't.
        local ok, result = ServerCallback("getActiveRequest")

        if ok and result then
            active = result
            sendToOverlay("showActive", { payload = active })
            startDistanceUpdates()
        end
    end

    cb(true)
end)
