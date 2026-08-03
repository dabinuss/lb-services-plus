local allowedActions = ServicesPlus.Contracts.actions

RegisterNetEvent("services-plus:server:request", function(requestId, action, payload)
    local requestSource = source
    if type(requestId) ~= "string" or #requestId < 8 or #requestId > 96 or not allowedActions[action] then
        if type(requestId) == "string" and #requestId <= 96 then
            TriggerClientEvent("services-plus:client:response", requestSource, requestId, ServicesPlus.Error("invalid_request", "Invalid request.", false))
        end
        return
    end
    if not ServicesPlus.Ready then
        TriggerClientEvent("services-plus:client:response", requestSource, requestId, ServicesPlus.Error("service_unavailable", "Services+ is not ready. Check the server configuration.", true))
        return
    end
    if not ServicesPlus.RateLimiter.Allow(requestSource, action) then
        TriggerClientEvent("services-plus:client:response", requestSource, requestId, ServicesPlus.Error("rate_limited", "Too many requests. Please wait.", true))
        return
    end
    local validPayload, validationError = ServicesPlus.Contracts.ValidateActionPayload(action, payload)
    if not validPayload then
        TriggerClientEvent("services-plus:client:response", requestSource, requestId, ServicesPlus.Error("invalid_payload", validationError or "Invalid payload.", false))
        return
    end

    local ok, response = pcall(ServicesPlus.Api[action], requestSource, payload)
    if not ok then
        ServicesPlus.Logger.Error("API action failed", { action = action, source = requestSource, error = tostring(response) })
        response = ServicesPlus.Error("internal_error", "The request could not be completed.", true)
    end
    TriggerClientEvent("services-plus:client:response", requestSource, requestId, response)
end)


RegisterNetEvent("services-plus:server:appClosed", function()
    ServicesPlus.Api.RemoveSubscriber(source)
end)

RegisterNetEvent("services-plus:server:phoneChanged", function()
    local requestSource = source
    if not ServicesPlus.RateLimiter.Allow(requestSource, "phoneChanged") then
        return
    end
    ServicesPlus.Employees.ValidatePhone(requestSource)
end)
