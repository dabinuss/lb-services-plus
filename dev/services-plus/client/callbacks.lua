local callbacks = {
    "getInitialState",
    "enterDuty",
    "leaveDuty",
    "updateStatus",
    "toggleDispatch",
    "updateNumberOperations",
    "toggleDispatchLine",
    "startCompanyCall",
    "getEmployeeContact",
    "registerIncomingCall",
    "declineCall",
    "getRequestOptions",
    "getCompanyWorkspace",
    "acceptRequest",
    "declineRequest",
    "returnRequest",
    "navigateToRequest",
    "cancelRequest",
    "updateRequestSettings",
    "sendCitizenMessage",
    "sendEmployeeMessage",
    "getCitizenInbox",
    "getConversationMessages",
    "reactToMessage",
    "createRequest",
    "getMyActivity",
    "getAdminState",
    "adminSaveCompany",
    "adminDeleteCompany",
    "adminRestoreCompany",
    "adminUpdateSettings",
    "adminUpdateCategory",
    "deleteRequest",
    "deleteConversation",
    "deleteMessage"
}

for _, action in ipairs(callbacks) do
    RegisterNUICallback(action, function(data, callback)
        local answered = false
        local function answer(response)
            if answered then return end
            answered = true
            if response.success and (action == "getInitialState" or action == "enterDuty") then
                local data = response.data or {}
                local user = data.currentUser
                if user and user.employment and user.employment.onDuty then
                    for _, company in ipairs(data.companies or {}) do
                        if company.id == user.employment.companyId then
                            local active = {}
                            for _, id in ipairs(user.employment.employee and user.employment.employee.activeNumberIds or {}) do active[id] = true end
                            local numbers = {}
                            for _, number in ipairs(company.numbers or {}) do if active[number.id] and number.callsEnabled then numbers[#numbers + 1] = number end end
                            ServicesPlusClient.Integrations.SyncCompanyNumbers(numbers)
                            break
                        end
                    end
                end
            elseif response.success and action == "leaveDuty" then
                ServicesPlusClient.Integrations.ClearCompanyNumbers()
            end
            callback(response)
        end

        ServicesPlusClient.RequestServer(action, type(data) == "table" and data or {}, answer)
    end)
end

RegisterNUICallback("acceptCall", function(data, callback)
    ServicesPlusClient.RequestServer("acceptCall", type(data) == "table" and data or {}, function(response)
        if not response.success then callback(response) return end
        if not ServicesPlusClient.Integrations.AcceptIncomingCall(response.data.callToken) then
            ServicesPlusClient.RequestServer("endCustomCall", { callToken = response.data.callToken, reoffer = true }, function() end)
            callback(ServicesPlus.Error("native_call_unavailable", "The native call is no longer available.", false))
            return
        end
        callback(response)
    end)
end)

RegisterNUICallback("openEmployeeContact", function(data, callback)
    ServicesPlusClient.RequestServer("getEmployeeContact", type(data) == "table" and data or {}, function(response)
        if not response.success then callback(response) return end
        local ok = pcall(function()
            exports["lb-phone"]:SetContactModal(response.data.number)
        end)
        if not ok then
            callback(ServicesPlus.Error("phone_integration_failed", "The LB Phone contact could not be opened.", true))
            return
        end
        callback(ServicesPlus.Ok({ opened = true }))
    end)
end)

RegisterNUICallback("sendCurrentLocation", function(data, callback)
    data = type(data) == "table" and data or {}
    local citizen = data.citizen == true
    -- The server reads the player's real position itself; the client only requests it.
    local payload = { body = "", attachments = {}, includeCurrentLocation = true }
    if citizen then
        payload.companyId = data.companyId
        payload.numberId = data.numberId
    else
        payload.conversationId = tonumber(data.conversationId)
    end
    ServicesPlusClient.RequestServer(citizen and "sendCitizenMessage" or "sendEmployeeMessage", payload, function(response)
        callback(response)
    end)
end)
