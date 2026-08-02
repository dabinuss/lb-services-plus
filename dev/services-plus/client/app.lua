local APP_IDENTIFIER = ServicesPlus.Constants.AppIdentifier

local function sendLifecycle(eventType)
    if not ServicesPlusClient.State.registered then return end
    local success, errorMessage = exports["lb-phone"]:SendCustomAppMessage(APP_IDENTIFIER, {
        type = eventType,
        timestamp = os.time(),
        payload = {}
    })
    if not success and Config.Debug then
        print(("[services-plus] Lifecycle message failed: %s"):format(errorMessage or "unknown error"))
    end
end

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
        onOpen = function()
            sendLifecycle("app.opened")
        end,
        onClose = function()
            sendLifecycle("app.closed")
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
end)
