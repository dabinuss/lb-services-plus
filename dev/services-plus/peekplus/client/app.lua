local resourceName = GetCurrentResourceName()

local function registerNotificationApp()
    if not Config.PeekPlusApp.enabled then
        pcall(function()
            exports["lb-phone"]:RemoveCustomApp(Config.PeekPlusApp.identifier)
        end)
        return
    end

    local added, errorMessage = exports["lb-phone"]:AddCustomApp({
        identifier = Config.PeekPlusApp.identifier,
        name = Config.PeekPlusApp.name,
        description = Config.PeekPlusApp.description,
        developer = Config.PeekPlusApp.developer,
        icon = ("https://cfx-nui-%s/ui/dist/peekplus/notification-icon.svg"):format(resourceName),
        defaultApp = Config.PeekPlusApp.defaultApp,
        size = Config.PeekPlusApp.size,
        ui = ("%s/ui/dist/notifications.html"):format(resourceName),
        fixBlur = true,
    })
    if not added then
        print(("^1[services-plus] could not register PeekPlus app: %s^7"):format(errorMessage))
    end
end

CreateThread(function()
    while GetResourceState("lb-phone") ~= "started" do Wait(500) end
    Wait(500)
    registerNotificationApp()
end)

AddEventHandler("onResourceStart", function(resource)
    if resource ~= "lb-phone" then return end
    Wait(500)
    registerNotificationApp()
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= resourceName then return end
    pcall(function()
        exports["lb-phone"]:RemoveCustomApp(Config.PeekPlusApp.identifier)
    end)
end)
