local APP_IDENTIFIER = ServicesPlus.Constants.AppIdentifier
local activeRequestOfferId
local requestActionPending = false

function ServicesPlusClient.RegisterApp()
    local state = ServicesPlusClient.State
    if state.registered or state.registering then return end
    if GetResourceState("lb-phone") ~= "started" then return end
    state.registering = true

    local success, errorMessage = exports["lb-phone"]:AddCustomApp({
        identifier = APP_IDENTIFIER,
        name = "Services+",
        description = "Companies, public services and employee duty portal",
        developer = "Services+",
        defaultApp = Config.AppDefaultInstalled,
        ui = "web/index.html",
        icon = Config.AppIcon,
        fixBlur = true,
        onClose = function()
            TriggerServerEvent("services-plus:server:appClosed")
        end
    })

    state.registering = false
    state.registered = success == true
    if not success then
        print(("[services-plus] Failed to register LB Phone app: %s"):format(errorMessage or "unknown error"))
    elseif Config.Debug then
        print("[services-plus] LB Phone app registered")
    end
end

function ServicesPlusClient.RemoveApp()
    local state = ServicesPlusClient.State
    if not state.registered or GetResourceState("lb-phone") ~= "started" then
        state.registered = false
        return
    end
    local success, errorMessage = exports["lb-phone"]:RemoveCustomApp(APP_IDENTIFIER)
    state.registered = false
    if not success then
        print(("[services-plus] Failed to remove LB Phone app: %s"):format(errorMessage or "unknown error"))
    end
end

RegisterNetEvent("services-plus:client:push", function(message)
    if type(message) ~= "table" or type(message.type) ~= "string" then return end
    local success, errorMessage = exports["lb-phone"]:SendCustomAppMessage(APP_IDENTIFIER, message)
    if not success and Config.Debug then
        print(("[services-plus] Push message failed: %s"):format(errorMessage or "unknown error"))
    end
    local payload = type(message.payload) == "table" and message.payload or {}
    if message.type == "request.offer" and type(payload.id) == "number" then
        activeRequestOfferId = payload.id
        SetTimeout(100, function()
            if activeRequestOfferId ~= payload.id or GetResourceState("lb-phone") ~= "started" then return end
            pcall(function()
                if exports["lb-phone"]:IsDisabled() or exports["lb-phone"]:IsInCall() then return end
                exports["lb-phone"]:ToggleOpen(true, true)
                exports["lb-phone"]:OpenApp(APP_IDENTIFIER)
            end)
        end)
    elseif message.type == "request.offer.removed" and payload.id == activeRequestOfferId then
        activeRequestOfferId = nil
    elseif message.type == "request.updated" and payload.id == activeRequestOfferId and payload.status ~= "pending" and payload.status ~= "returned" then
        activeRequestOfferId = nil
    elseif message.type == "session.invalidated" then
        ServicesPlusClient.Integrations.ClearCompanyNumbers()
    end
end)

local function handleRequestOfferAction(requestId, offerAction)
    if requestActionPending or type(requestId) ~= "number" or (offerAction ~= "accept" and offerAction ~= "decline") then return end
    requestActionPending = true
    local action = offerAction == "accept" and "acceptRequest" or "declineRequest"
    ServicesPlusClient.RequestServer(action, { id = requestId }, function(response)
        requestActionPending = false
        if response.success then
            if activeRequestOfferId == requestId then activeRequestOfferId = nil end
            exports["lb-phone"]:SendCustomAppMessage(APP_IDENTIFIER, {
                type = "request.offer.removed",
                timestamp = os.time(),
                payload = { id = requestId }
            })
            return
        end
        pcall(function()
            exports["lb-phone"]:SendNotification({
                app = APP_IDENTIFIER,
                title = Config.Locale == "de" and "Anfrage nicht verfügbar" or "Request unavailable",
                content = Config.Locale == "de" and "Die Anfrage wurde bereits bearbeitet oder kann nicht angenommen werden." or "The request was already handled or cannot be accepted."
            })
        end)
    end)
end

RegisterNetEvent("services-plus:client:requestNotificationAction", function(data)
    if type(data) ~= "table" then return end
    handleRequestOfferAction(data.id, data.action)
end)

RegisterNetEvent("services-plus:client:requestNavigation", function(data)
    local x, y = type(data) == "table" and tonumber(data.x) or nil, type(data) == "table" and tonumber(data.y) or nil
    if not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then return end
    SetNewWaypoint(x, y)
    pcall(function()
        exports["lb-phone"]:SendNotification({ app = APP_IDENTIFIER,
            title = Config.Locale == "de" and "Navigation gestartet" or "Navigation started",
            content = type(data.title) == "string" and data.title or "Services+ request" })
    end)
end)

RegisterCommand("servicesPlusAcceptRequest", function()
    if activeRequestOfferId then handleRequestOfferAction(activeRequestOfferId, "accept") end
end, false)

RegisterCommand("servicesPlusDeclineRequest", function()
    if activeRequestOfferId then handleRequestOfferAction(activeRequestOfferId, "decline") end
end, false)

RegisterKeyMapping("servicesPlusAcceptRequest", "Accept Services+ request", "keyboard", "RETURN")
RegisterKeyMapping("servicesPlusDeclineRequest", "Decline Services+ request", "keyboard", "BACK")
