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
    ServicesPlus.Repository.RecoverActiveRequests()
    ServicesPlus.Integrations.Refresh()
    ServicesPlus.Employees.ClearAll()
    ServicesPlus.Employees.RestoreOnlineDuty()
    initialized = true
    ServicesPlus.Ready = true
    ServicesPlus.Logger.Info("Phase 2 server initialized", { framework = bridgeResult })
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
