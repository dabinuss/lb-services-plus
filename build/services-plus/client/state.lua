ServicesPlusClient = ServicesPlusClient or {}

ServicesPlusClient.State = {
    registered = false,
    registering = false,
    requestCounter = 0,
    pending = {}
}

function ServicesPlusClient.NextRequestId()
    local state = ServicesPlusClient.State
    state.requestCounter = state.requestCounter + 1
    return ("%s:%s:%s"):format(GetPlayerServerId(PlayerId()), GetGameTimer(), state.requestCounter)
end

function ServicesPlusClient.RequestServer(action, payload, callback)
    local requestId = ServicesPlusClient.NextRequestId()
    ServicesPlusClient.State.pending[requestId] = callback
    TriggerServerEvent("services-plus:server:request", requestId, action, payload or {})

    SetTimeout(Config.ServerCallbackTimeoutMs, function()
        local pending = ServicesPlusClient.State.pending[requestId]
        if not pending then return end
        ServicesPlusClient.State.pending[requestId] = nil
        pending(ServicesPlus.Error("timeout", "The server did not respond in time.", true))
    end)
end

RegisterNetEvent("services-plus:client:response", function(requestId, response)
    if type(requestId) ~= "string" then return end
    local callback = ServicesPlusClient.State.pending[requestId]
    if not callback then return end
    ServicesPlusClient.State.pending[requestId] = nil
    callback(type(response) == "table" and response or ServicesPlus.Error("invalid_response", "The server returned an invalid response.", true))
end)
