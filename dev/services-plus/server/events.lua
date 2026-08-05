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
        print(("[services-plus] action '%s' rate-limited for source %d"):format(action, requestSource))
        TriggerClientEvent("services-plus:client:response", requestSource, requestId, ServicesPlus.Error("rate_limited", "Too many requests. Please wait.", true))
        return
    end
    local encodeOk, encoded = pcall(json.encode, payload)
    if not encodeOk or #encoded > Config.MaxActionPayloadBytes then
        print(("[services-plus] action '%s' rejected for source %d: payload too large or unencodable"):format(action, requestSource))
        TriggerClientEvent("services-plus:client:response", requestSource, requestId, ServicesPlus.Error("invalid_payload", "The request payload is too large.", false))
        return
    end
    local validPayload, validationError = ServicesPlus.Contracts.ValidateActionPayload(action, payload)
    if not validPayload then
        print(("[services-plus] action '%s' rejected for source %d by contract schema: %s"):format(action, requestSource, tostring(validationError)))
        TriggerClientEvent("services-plus:client:response", requestSource, requestId, ServicesPlus.Error("invalid_payload", validationError or "Invalid payload.", false))
        return
    end

    local ok, response = pcall(ServicesPlus.Api[action], requestSource, payload)
    if not ok then
        ServicesPlus.Logger.Error("API action failed", { action = action, source = requestSource, error = tostring(response) })
        print(("[services-plus] action '%s' threw a Lua error for source %d: %s"):format(action, requestSource, tostring(response)))
        response = ServicesPlus.Error("internal_error", "The request could not be completed.", true)
    end
    if type(response) == "table" and response.success == false and (action == "adminSaveCompany" or action == "updateNumberOperations" or action == "updateStatus") then
        print(("[services-plus] action '%s' returned an error to source %d: %s"):format(action, requestSource, tostring(response.error and response.error.code)))
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
