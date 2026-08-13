--[[
    Sibling-NUI controller for request notifications (plan §42-49,
    SIBLING-NUI.md). This is the ONLY thing that touches lb-phone's DOM -
    the actual Services+ app stays a normal, independent custom app.

    This resource's own `ui_page` (see fxmanifest.lua) points at
    peekplus/ui/overlay/index.html, a tiny invisible page whose only job is to find
    the CitizenFX root NUI document and render a notification/active-request
    card into it. The controller now mounts the card into LB Phone's real
    `.full-phone` tree and owns a bounded visual peek lock for Services+
    notifications; the root document remains its reconnect/fallback path.
]]

local queue = {} -- pending request notifications, oldest first
local shown = nil -- requestId currently displayed as a *pending* notification
local shownPayload = nil -- its full payload, kept so a NUI reload can re-show it exactly (plan review §14)
local active = nil -- the full accept reply currently displayed as the *active* card
local distanceThread = nil
local peekWatchToken = 0
local ownedPeekUntil = 0
local forceOverlayFallback = false
local overlayControllerVersion = "not-ready"
local testPeekActive = false
local testPeekState = nil -- nil | "pending" | "active"
local testPeekPayload = nil
local phoneFullOpen = false
local showNextToken = 0
local requestActionInFlight = false
local activeCancelArmed = false
local showNext
local scheduleShowNext
local sendToOverlay
local stopPeekTest
local acceptPeekTest

local function isPhoneOpen()
    local ok, open = pcall(function() return exports["lb-phone"]:IsOpen() end)
    return ok and open == true
end

local function canUsePhonePeek()
    local ok, number = pcall(function() return exports["lb-phone"]:GetEquippedPhoneNumber() end)
    if not ok or not number then return false end

    local disabled = false
    pcall(function() disabled = exports["lb-phone"]:IsDisabled() == true end)
    local dead = false
    pcall(function() dead = exports["lb-phone"]:IsPhoneDead() == true end)
    return not disabled and not dead
end

local function isCallActive()
    local onCallWith = LocalPlayer.state.onCallWith
    return onCallWith ~= nil
        and onCallWith ~= false
        and onCallWith ~= 0
        and onCallWith ~= ""
end

CreateThread(function()
    local previous = nil
    while true do
        local current = isCallActive()
        if current ~= previous then
            previous = current
            sendToOverlay("setCallPriority", { active = current })
        end
        Wait(100)
    end
end)

local function getNotificationSound()
    if isCallActive() then return false, nil end
    local ok, settings = pcall(function() return exports["lb-phone"]:GetSettings() end)
    if not ok or type(settings) ~= "table" then return true, "default" end
    if settings.airplaneMode or settings.doNotDisturb or settings.sound and settings.sound.silent then
        return false, nil
    end

    local appSettings = settings.notifications and settings.notifications[Config.App.identifier]
    if type(appSettings) == "table" and appSettings.enabled == false then return false, nil end
    return true, type(appSettings) == "table" and appSettings.texttone
        or settings.sound and settings.sound.texttone
        or "default"
end

sendToOverlay = function(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function watchPeekOwnership(duration, interruptible, debugLabel)
    duration = tonumber(duration) or 0
    if duration == 0 then return end

    peekWatchToken = peekWatchToken + 1
    local token = peekWatchToken
    local expiresAt = duration < 0 and nil or (GetGameTimer() + duration)

    CreateThread(function()
        while peekWatchToken == token and (not expiresAt or GetGameTimer() < expiresAt) do
            local cameraOpen = false
            pcall(function() cameraOpen = exports["lb-phone"]:IsCameraOpen() == true end)

            if interruptible and cameraOpen then
                peekWatchToken = peekWatchToken + 1
                ownedPeekUntil = 0
                sendToOverlay("releasePeek", {})
                return
            end

            Wait(250)
        end

        if peekWatchToken == token and expiresAt and GetGameTimer() >= expiresAt then
            ownedPeekUntil = 0
            if debugLabel then
                testPeekActive = false
                testPeekState = nil
                testPeekPayload = nil
                sendToOverlay("clearTest", {})
                if scheduleShowNext then scheduleShowNext() end
                print(("[services-plus] Peek test ended after %d seconds (%s)")
                    :format(math.floor(duration / 1000), debugLabel))
            else
                sendToOverlay("releasePeek", {})
            end
        end
    end)
end

local function rememberOwnedPeek(duration, owned)
    duration = tonumber(duration) or 0
    ownedPeekUntil = owned and (duration < 0 and -1 or duration > 0 and (GetGameTimer() + duration)) or 0
end

showNext = function()
    if testPeekActive or shown or active or #queue == 0 then return end

    local payload = table.remove(queue, 1)
    shown = payload.requestId
    shownPayload = payload

    local canPeek = canUsePhonePeek()
    local phoneWasOpen = phoneFullOpen
    local playSound, soundName = getNotificationSound()
    forceOverlayFallback = not canPeek
    sendToOverlay("requestNotification", {
        payload = payload,
        peekDuration = Config.RequestNotificationPeekDuration or 0,
        playSound = canPeek and playSound,
        soundName = soundName,
        holdPeek = canPeek and not phoneWasOpen,
        forceFallback = forceOverlayFallback,
    })
    rememberOwnedPeek(Config.RequestNotificationPeekDuration, canPeek and not phoneWasOpen)
    if canPeek and not phoneWasOpen then watchPeekOwnership(Config.RequestNotificationPeekDuration, true) end
end

scheduleShowNext = function()
    showNextToken = showNextToken + 1
    local token = showNextToken
    SetTimeout(600, function()
        if showNextToken == token then showNext() end
    end)
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
    activeCancelArmed = false

    if type(payload.x) == "number" and type(payload.y) == "number" then
        SetNewWaypoint(payload.x, payload.y)
    end

    local canPeek = canUsePhonePeek()
    local phoneWasOpen = phoneFullOpen
    forceOverlayFallback = not canPeek
    sendToOverlay("showActive", {
        payload = payload,
        peekDuration = -1,
        playSound = false,
        holdPeek = canPeek and not phoneWasOpen,
        forceFallback = forceOverlayFallback,
    })
    rememberOwnedPeek(-1, canPeek and not phoneWasOpen)
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
        rememberOwnedPeek(0, false)
        scheduleShowNext()
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
        activeCancelArmed = false
        stopDistanceUpdates()
        sendToOverlay("clearActive", {})
        rememberOwnedPeek(0, false)
        scheduleShowNext()
    end
end)

-- The full phone takes ownership of its geometry. While its lockscreen is
-- visible, the Sibling-NUI card moves into LB Phone's native notification
-- stack; closing the phone restores an active request to the held peek.
RegisterNetEvent("lb-phone:phoneToggled", function(open)
    phoneFullOpen = open == true
    sendToOverlay("setPhoneOpen", { open = phoneFullOpen })

    if phoneFullOpen then
        -- The full phone owns its geometry. The Sibling-NUI controller moves
        -- the card into LB Phone's native lockscreen notification stack when
        -- that stack exists, and keeps it away from normal app/home screens.
        return
    end

    -- Closing the normal full-phone view restores an accepted request as a
    -- permanent peek. Pending requests only return while their original
    -- notification duration is still running.
    if active then
        showActive(active)
    elseif testPeekActive and testPeekState == "active" and testPeekPayload then
        acceptPeekTest(true)
    elseif shownPayload then
        local remaining = ownedPeekUntil == -1 and -1 or math.max(0, ownedPeekUntil - GetGameTimer())
        if remaining ~= 0 then
            sendToOverlay("requestNotification", {
                payload = shownPayload,
                peekDuration = remaining,
                playSound = false,
                holdPeek = canUsePhonePeek(),
                forceFallback = forceOverlayFallback,
            })
            watchPeekOwnership(remaining, true)
        end
    end
end)

local function declineShownRequest()
    if requestActionInFlight or isCallActive() then return false end
    if testPeekActive and testPeekState == "pending" then
        stopPeekTest("declined")
        return true
    end
    if not shown then return false end

    local requestId = shown
    shown = nil
    shownPayload = nil
    rememberOwnedPeek(0, false)
    sendToOverlay("dismiss", { requestId = requestId })
    scheduleShowNext()
    return true
end

local function acceptShownRequest()
    if requestActionInFlight or isCallActive() then return false end
    if testPeekActive and testPeekState == "pending" then
        acceptPeekTest(false)
        return true
    end
    if not shown then return false end

    requestActionInFlight = true
    local requestId = shown
    local ok, result = ServerCallback("acceptRequest", requestId)
    requestActionInFlight = false

    if not (ok and result) then
        if shown == requestId then
            shown = nil
            shownPayload = nil
        end
        sendToOverlay("dismiss", { requestId = requestId })
        scheduleShowNext()
    end

    return ok and result ~= false
end

local function cancelActiveRequest()
    if requestActionInFlight or isCallActive() then return false end

    local isTestActive = testPeekActive and testPeekState == "active"
    if not active and not isTestActive then return false end

    if not activeCancelArmed then
        activeCancelArmed = true
        sendToOverlay("setCancelConfirm", { active = true })
        return true
    end

    activeCancelArmed = false
    sendToOverlay("setCancelConfirm", { active = false })

    if isTestActive then
        stopPeekTest("cancelled")
        return true
    end

    requestActionInFlight = true
    local ok, result = ServerCallback("cancelRequest", active.requestId)
    requestActionInFlight = false
    return ok and result == true
end

local function handleDeleteRequest()
    if active or testPeekActive and testPeekState == "active" then
        return cancelActiveRequest()
    end
    return declineShownRequest()
end

RegisterCommand("peekplus_accept", function()
    acceptShownRequest()
end, false)
RegisterKeyMapping("peekplus_accept", "PeekPlus: Benachrichtigung annehmen", "keyboard", "RETURN")

RegisterCommand("peekplus_decline", function()
    handleDeleteRequest()
end, false)
RegisterKeyMapping("peekplus_decline", "PeekPlus: Benachrichtigung ablehnen/abbrechen", "keyboard", "DELETE")

RegisterNUICallback("overlayAction", function(data, cb)
    local action = data.action
    local requestId = data.requestId

    if action == "testClose" then
        stopPeekTest("cancelled")
        return cb(true)
    end

    if action == "testCancel" then
        return cb(cancelActiveRequest())
    end

    if action == "decline" then
        return cb((testPeekActive and testPeekState == "pending" or shown == requestId) and declineShownRequest())
    end

    if action == "accept" then
        return cb((testPeekActive and testPeekState == "pending" or shown == requestId) and acceptShownRequest())
    end

    if action == "cancel" then
        return cb(active and active.requestId == requestId and cancelActiveRequest())
    end

    if action == "complete" then
        local ok, result = ServerCallback("completeRequest", requestId)
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
RegisterNUICallback("ready", function(data, cb)
    overlayControllerVersion = type(data) == "table" and data.controllerVersion or "unknown"
    phoneFullOpen = isPhoneOpen()
    print(("[services-plus] Peek controller ready: %s"):format(overlayControllerVersion))
    sendToOverlay("setPhoneOpen", { open = phoneFullOpen })
    sendToOverlay("setCallPriority", { active = isCallActive() })
    if active then
        sendToOverlay("showActive", {
            payload = active,
            peekDuration = -1,
            playSound = false,
            holdPeek = not phoneFullOpen,
            forceFallback = forceOverlayFallback,
        })
        rememberOwnedPeek(-1, not phoneFullOpen)
        startDistanceUpdates()
    elseif testPeekActive and testPeekState == "active" and testPeekPayload then
        sendToOverlay("showActive", {
            payload = testPeekPayload,
            peekDuration = -1,
            playSound = false,
            holdPeek = not phoneFullOpen,
            forceFallback = forceOverlayFallback,
        })
        rememberOwnedPeek(-1, not phoneFullOpen)
    elseif shownPayload then
        local remaining = ownedPeekUntil == -1 and -1 or math.max(0, ownedPeekUntil - GetGameTimer())
        sendToOverlay("requestNotification", {
            payload = shownPayload,
            peekDuration = remaining,
            playSound = false,
            holdPeek = remaining ~= 0,
            forceFallback = forceOverlayFallback,
        })
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

AddEventHandler("onClientResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        peekWatchToken = peekWatchToken + 1
        rememberOwnedPeek(0, false)
        sendToOverlay("destroy", {})
    end
end)

stopPeekTest = function(reason)
    peekWatchToken = peekWatchToken + 1
    rememberOwnedPeek(0, false)
    testPeekActive = false
    testPeekState = nil
    testPeekPayload = nil
    activeCancelArmed = false
    sendToOverlay("clearTest", {})
    scheduleShowNext()
    print(("[services-plus] Peek test %s."):format(reason or "stopped"))
end

acceptPeekTest = function(restoring)
    if not testPeekActive or not testPeekPayload then return false end

    peekWatchToken = peekWatchToken + 1
    testPeekState = "active"
    activeCancelArmed = false
    testPeekPayload.accepted = true
    testPeekPayload.description = "Test request accepted. It remains active until cancelled."

    local canPeek = canUsePhonePeek()
    forceOverlayFallback = not canPeek
    sendToOverlay("showActive", {
        payload = testPeekPayload,
        peekDuration = -1,
        playSound = false,
        holdPeek = canPeek and not phoneFullOpen,
        forceFallback = forceOverlayFallback,
    })
    rememberOwnedPeek(-1, canPeek and not phoneFullOpen)

    if not restoring then
        print("[services-plus] Peek test request accepted; active peek is now held until cancelled.")
    end
    return true
end

local function runPeekTest(duration, durationLabel)
    if testPeekActive then
        print("[services-plus] Peek test skipped: another test peek is still active. Use peekplus_test stop first.")
        return
    end

    if shown or active then
        print("[services-plus] Peek test skipped: finish or dismiss the real request currently on screen first.")
        return
    end

    if isPhoneOpen() then
        print("[services-plus] Peek test skipped: close the fully opened phone and run the command again.")
        return
    end

    local canPeek = canUsePhonePeek()
    local phoneWasOpen = isPhoneOpen()
    local playSound, soundName = getNotificationSound()
    local payload = {
        requestId = -(GetGameTimer() + 1),
        typeName = "PeekPlus Test",
        companyName = "Local F8 test · " .. durationLabel,
        description = "Accept with ENTER or decline with DELETE. No server request is created.",
        test = true,
    }

    print(("[services-plus] Starting peek test (%s), controller=%s, phone=%s")
        :format(durationLabel, overlayControllerVersion, canPeek and "ready" or "unavailable"))

    testPeekActive = true
    testPeekState = "pending"
    testPeekPayload = payload

    if not canPeek then
        print("[services-plus] No usable equipped phone; showing the root-overlay fallback instead of a phone peek.")
    end
    forceOverlayFallback = not canPeek
    sendToOverlay("requestNotification", {
        payload = payload,
        peekDuration = duration,
        playSound = canPeek and playSound,
        soundName = soundName,
        holdPeek = canPeek and not phoneWasOpen,
        forceFallback = forceOverlayFallback,
    })
    rememberOwnedPeek(duration, canPeek and not phoneWasOpen)
    -- A smoke test must measure exactly the command duration. Runtime safety
    -- interruptions remain enabled for real request peeks above.
    watchPeekOwnership(duration, false, durationLabel)
end

-- Local F8 smoke tests for the complete native-notification + Sibling-NUI
-- peek path. They never create a database request and have no server actions.
-- Usage: peekplus_test [seconds|hold|stop]
RegisterCommand("peekplus_test", function(_, args)
    if args[1] == "stop" then return stopPeekTest() end
    if args[1] == "hold" then return runPeekTest(-1, "until stopped") end

    local configured = math.floor((tonumber(Config.RequestNotificationPeekDuration) or 15000) / 1000)
    local seconds = math.max(1, math.min(120, math.floor(tonumber(args[1]) or configured)))
    runPeekTest(seconds * 1000, seconds .. " seconds")
end, false)

RegisterCommand("peekplus_test_hold", function()
    runPeekTest(-1, "until stopped")
end, false)
