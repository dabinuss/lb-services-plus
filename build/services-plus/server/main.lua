local initialized = false
ServicesPlus.Ready = false

local function initialize()
    if initialized then return end
    if GetResourceState("lb-phone") ~= "started" then
        ServicesPlus.Logger.Error("Required dependency lb-phone is not running. Start it before services-plus.")
        return
    end
    if GetResourceState("oxmysql") ~= "started" then
        ServicesPlus.Logger.Error("Required dependency oxmysql is not running.")
        return
    end

    local bridgeOk, bridgeResult = ServicesPlus.Bridge.Initialize()
    if not bridgeOk then
        ServicesPlus.Logger.Error("Framework bridge initialization failed", { error = bridgeResult })
        return
    end

    local migrationOk, migrationError = ServicesPlus.Migrations.Validate()
    if not migrationOk then
        ServicesPlus.Logger.Error(migrationError)
        return
    end

    ServicesPlus.Repository.SeedConfiguredCompanies()
    ServicesPlus.Companies.Load()
    ServicesPlus.Inboxes.ValidateConfiguration()
    ServicesPlus.Repository.RecoverActiveRequests()
    ServicesPlus.Integrations.Refresh()
    ServicesPlus.Employees.ClearAll()
    ServicesPlus.Employees.RestoreOnlineDuty()
    initialized = true
    ServicesPlus.Ready = true
    ServicesPlus.Logger.Info("Services+ server initialized", { framework = bridgeResult })
end

CreateThread(function()
    for _ = 1, 40 do
        if GetResourceState("oxmysql") == "started" then break end
        Wait(250)
    end
    if GetResourceState("oxmysql") ~= "started" then
        ServicesPlus.Logger.Error("Required dependency oxmysql did not start within 10 seconds.")
        return
    end
    initialize()
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == "lb-phone" or resourceName == "oxmysql" then
        SetTimeout(750, initialize)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    ServicesPlus.Ready = false
    ServicesPlus.Employees.ClearAll()
end)

-- Dev helper: prints your own identifiers so you can add yourself to
-- Config.StandalonePlayers / Config.StandaloneAdmins in config.lua. Not permission-gated
-- since it can only ever reveal the calling player's own identifiers.
RegisterCommand("spwhoami", function(source)
    if source == 0 then return end
    local identifiers = GetPlayerIdentifiers(source)
    local license = nil
    for _, identifier in ipairs(identifiers) do
        if identifier:sub(1, 8) == "license:" then license = identifier break end
    end
    print(("[services-plus] %s (source %d) identifiers: %s"):format(GetPlayerName(source), source, table.concat(identifiers, ", ")))
    TriggerClientEvent("chat:addMessage", source, { args = { "[Services+]", ("License: %s"):format(license or "not found") } })
    TriggerClientEvent("chat:addMessage", source, { args = { "[Services+]", ("All identifiers: %s"):format(table.concat(identifiers, ", ")) } })
end, false)
