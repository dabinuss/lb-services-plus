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

--- Single place that transitions to the active-request card, used by the
--- server-pushed accept confirmation, the "ready" rehydration, and nothing
--- else - accept itself no longer sets `active` locally (see overlayAction
--- below), so this always reflects the server's word regardless of whether
--- Accept was pressed here or from the in-app Requests tab (plan review
--- round 2 §4).
local function showActive(payload)
    shown = nil
    shownPayload = nil
    active = payload

    if type(payload.x) == "number" and type(payload.y) == "number" then
        SetNewWaypoint(payload.x, payload.y)
    end

    sendToOverlay("showActive", { payload = payload })
    startDistanceUpdates()
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

-- Sent by the server right after ANY successful accept of a request this
-- player ended up winning - whether Accept was pressed here in the overlay
-- or in the in-app Requests tab (plan review round 2 §4).
RegisterNetEvent("services-plus:client:requestAccepted", function(payload)
    showActive(payload)
end)

-- Sent by the server right after ANY successful complete/cancel of a
-- request this player had active - whether that happened here in the
-- overlay, the in-app Requests tab, or (for cancel) the customer's own app
-- (plan review round 3 §2). Single place that clears the active card so it
-- can never linger on a surface the completing/cancelling action didn't
-- itself touch.
RegisterNetEvent("services-plus:client:requestEnded", function(requestId)
    if active and active.requestId == requestId then
        active = nil
        stopDistanceUpdates()
        sendToOverlay("clearActive", {})
        showNext()
    end
end)

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

        if not (ok and result) then
            if shown == requestId then
                shown = nil
                shownPayload = nil
            end
            sendToOverlay("dismiss", { requestId = requestId })
            showNext()
        end
        -- Success path intentionally does nothing else here - the server's
        -- services-plus:client:requestAccepted event (fired right after a
        -- successful accept) is what calls showActive(), so acceptance
        -- always renders the same way no matter which UI triggered it.

        return cb(ok and result ~= false)
    end

    if action == "complete" or action == "cancel" then
        local ok, result = ServerCallback(action == "complete" and "completeRequest" or "cancelRequest", requestId)
        -- Success path intentionally does nothing else here - the server's
        -- services-plus:client:requestEnded event (fired right after) is
        -- what clears `active`, same reasoning as the accept branch above.

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
            showActive(result)
        end
    end

    cb(true)
end)
