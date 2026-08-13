-- Compatibility endpoint only. Current LB Phone versions expose GetSettings
-- on the client, so PeekPlus does not call this during a normal resource
-- start. It remains available for older installations.
local lastSettingsRequest = {}

local function readPhoneSettings(playerSource)
    local okNumber, phoneNumber = pcall(function()
        return exports["lb-phone"]:GetEquippedPhoneNumber(playerSource)
    end)
    if not okNumber or not phoneNumber then return nil end

    local okSettings, settings = pcall(function()
        return exports["lb-phone"]:GetSettings(phoneNumber)
    end)
    return okSettings and type(settings) == "table" and settings or nil
end

local function sanitizeSettings(settings)
    if type(settings) ~= "table" then return nil end
    local sound = type(settings.sound) == "table" and settings.sound or {}
    local notifications = type(settings.notifications) == "table" and settings.notifications or {}
    local app = type(notifications[Config.PeekPlusApp.identifier]) == "table"
        and notifications[Config.PeekPlusApp.identifier] or {}

    return {
        airplaneMode = settings.airplaneMode == true,
        doNotDisturb = settings.doNotDisturb == true,
        silent = sound.silent == true,
        texttone = app.texttone or sound.texttone or "default",
        notificationsEnabled = app.enabled ~= false,
    }
end

RegisterNetEvent("services-plus:server:peekplusSettings", function()
    local playerSource = source
    local now = GetGameTimer()
    if now - (lastSettingsRequest[playerSource] or -1000) < 1000 then return end
    lastSettingsRequest[playerSource] = now
    TriggerClientEvent(
        "services-plus:client:peekplusSettings",
        playerSource,
        sanitizeSettings(readPhoneSettings(playerSource))
    )
end)

AddEventHandler("playerDropped", function()
    lastSettingsRequest[source] = nil
end)
