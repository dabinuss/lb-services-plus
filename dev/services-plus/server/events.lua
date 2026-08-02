local allowedActions = {
    getInitialState = true,
    enterDuty = true,
    leaveDuty = true,
    updateStatus = true,
    toggleDispatch = true,
    updateCompanyOperations = true,
    updateNumberOperations = true,
    toggleNumberSubscription = true,
    startCompanyCall = true,
    getEmployeeContact = true,
    registerIncomingCall = true,
    acceptCall = true,
    declineCall = true,
    endCustomCall = true,
    getRequestOptions = true,
    getCompanyWorkspace = true,
    acceptRequest = true,
    declineRequest = true,
    transitionRequest = true,
    returnRequest = true,
    cancelRequest = true,
    updateRequestSettings = true,
    updateNumberEligibility = true,
    sendCitizenMessage = true,
    sendEmployeeMessage = true,
    getCitizenInbox = true,
    getConversationMessages = true,
    reactToMessage = true,
    createRequest = true,
    getMyActivity = true,
    getAdminState = true,
    adminSaveCompany = true,
    adminDeleteCompany = true,
    adminUpdateSettings = true,
    adminUpdateCategory = true,
    deleteRequest = true,
    deleteConversation = true,
    deleteMessage = true
}

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
    ServicesPlus.Employees.ValidatePhone(source)
end)
