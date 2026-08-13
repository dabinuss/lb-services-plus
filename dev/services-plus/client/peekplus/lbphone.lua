PeekPlusLBPhone = {}

local settings = {
    airplaneMode = false,
    doNotDisturb = false,
    silent = false,
    texttone = "default",
    notificationsEnabled = true,
}
local phoneOpen = false
local callActive = false

local function safeExport(name, default)
    if GetResourceState("lb-phone") ~= "started" then return default end
    local ok, result = pcall(function()
        return exports["lb-phone"][name](exports["lb-phone"])
    end)
    return ok and result or default
end

local function normalizeSettings(value)
    if type(value) ~= "table" then return end
    local sound = type(value.sound) == "table" and value.sound or {}
    local notifications = type(value.notifications) == "table" and value.notifications or {}
    local app = type(notifications[Config.App.identifier]) == "table"
        and notifications[Config.App.identifier] or {}

    settings = {
        airplaneMode = value.airplaneMode == true,
        doNotDisturb = value.doNotDisturb == true,
        silent = value.silent == true or sound.silent == true,
        texttone = value.texttone or app.texttone or sound.texttone or "default",
        notificationsEnabled = value.notificationsEnabled ~= false and app.enabled ~= false,
    }
end

function PeekPlusLBPhone.IsOpen()
    return phoneOpen
end

function PeekPlusLBPhone.IsUsable()
    if GetResourceState("lb-phone") ~= "started" then return false end
    local phoneNumber = safeExport("GetEquippedPhoneNumber", nil)
    if not phoneNumber then return false end
    return safeExport("IsDisabled", false) ~= true
        and safeExport("IsPhoneDead", false) ~= true
end

function PeekPlusLBPhone.IsCallActive()
    return callActive
end

function PeekPlusLBPhone.GetNotificationSound()
    if callActive or settings.airplaneMode or settings.doNotDisturb
        or settings.silent or not settings.notificationsEnabled then
        return false, nil
    end
    return true, settings.texttone or "default"
end

function PeekPlusLBPhone.RequestSettings()
    TriggerServerEvent("services-plus:server:peekplusSettings")
end

RegisterNetEvent("services-plus:client:peekplusSettings", normalizeSettings)
RegisterNetEvent("lb-phone:settingsUpdated", function(first, second)
    normalizeSettings(type(second) == "table" and second or first)
end)

RegisterNetEvent("lb-phone:numberChanged", function()
    PeekPlusLBPhone.RequestSettings()
end)

RegisterNetEvent("lb-phone:phoneToggled", function(open)
    phoneOpen = open == true
    if PeekPlus and PeekPlus.SetPhoneOpen then PeekPlus.SetPhoneOpen(phoneOpen) end
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() and resourceName ~= "lb-phone" then return end
    SetTimeout(resourceName == "lb-phone" and 500 or 0, function()
        phoneOpen = safeExport("IsOpen", false) == true
        PeekPlusLBPhone.RequestSettings()
        if PeekPlus and PeekPlus.Reconnect then PeekPlus.Reconnect(phoneOpen) end
    end)
end)

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName ~= "lb-phone" then return end
    phoneOpen = false
    if PeekPlus and PeekPlus.PhoneUnavailable then PeekPlus.PhoneUnavailable() end
end)

CreateThread(function()
    while true do
        local onCallWith = LocalPlayer.state.onCallWith
        local nextCallActive = onCallWith ~= nil and onCallWith ~= false
            and onCallWith ~= 0 and onCallWith ~= ""
        if nextCallActive ~= callActive then
            callActive = nextCallActive
            if PeekPlus and PeekPlus.SetCallPriority then
                PeekPlus.SetCallPriority(callActive)
            end
        end
        Wait(100)
    end
end)
