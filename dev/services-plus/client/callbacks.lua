local callbacks = {
    "getInitialState",
    "enterDuty",
    "leaveDuty",
    "updateStatus",
    "toggleDispatch",
    "updateCompanyOperations",
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
    "transitionRequest",
    "returnRequest",
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
            ServicesPlusClient.RequestServer("endCustomCall", { callToken = response.data.callToken }, function() end)
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
    local coords = GetEntityCoords(PlayerPedId())
    local payload = { companyId = data.companyId, numberId = data.numberId, conversationId = tonumber(data.conversationId), body = "", attachments = {}, coords = { x = coords.x, y = coords.y } }
    local action = data.citizen == true and "sendCitizenMessage" or "sendEmployeeMessage"
    ServicesPlusClient.RequestServer(action, payload, function(response)
        callback(response)
    end)
end)
