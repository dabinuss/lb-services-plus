ServicesPlus.Integrations = ServicesPlus.Integrations or {}

local Integrations = ServicesPlus.Integrations
local availability = {}

function Integrations.Refresh()
    for name, integration in pairs(Config.OptionalIntegrations) do
        local configured = integration.enabled and integration.resource ~= ""
        availability[name] = configured and GetResourceState(integration.resource) == "started"
        if configured and not availability[name] then
            print(("[services-plus] [WARN] Optional %s integration '%s' is unavailable; core behavior remains active."):format(name, integration.resource))
        end
    end
end

function Integrations.IsAvailable(name)
    return availability[name] == true
end

AddEventHandler("onResourceStart", function(resourceName)
    for _, integration in pairs(Config.OptionalIntegrations) do
        if integration.resource == resourceName then Integrations.Refresh() end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    for _, integration in pairs(Config.OptionalIntegrations) do
        if integration.resource == resourceName then Integrations.Refresh() end
    end
end)
