local callbacks = {
    "getInitialState",
    "enterDuty",
    "leaveDuty",
    "updateStatus",
    "toggleDispatch",
    "updateCompanyOperations",
    "startCompanyCall",
    "getEmployeeContact",
    "createRequest",
    "getMyActivity",
    "getAdminState",
    "adminSaveCompany",
    "adminDeleteCompany",
    "adminUpdateSettings"
}

for _, action in ipairs(callbacks) do
    RegisterNUICallback(action, function(data, callback)
        local answered = false
        local function answer(response)
            if answered then return end
            answered = true
            callback(response)
        end

        ServicesPlusClient.RequestServer(action, type(data) == "table" and data or {}, answer)
    end)
end

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

RegisterNUICallback("appClosed", function(_, callback)
    TriggerServerEvent("services-plus:server:appClosed")
    callback(ServicesPlus.Ok({ closed = true }))
end)
