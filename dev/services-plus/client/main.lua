CreateThread(function()
    for _ = 1, 40 do
        if GetResourceState("lb-phone") == "started" then break end
        Wait(250)
    end
    if GetResourceState("lb-phone") ~= "started" then
        print("[services-plus] Required dependency lb-phone did not start within 10 seconds.")
        return
    end
    Wait(Config.RegistrationDelayMs)
    ServicesPlusClient.RegisterApp()
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= "lb-phone" and resourceName ~= GetCurrentResourceName() then return end
    if resourceName == "lb-phone" then
        ServicesPlusClient.State.registered = false
        ServicesPlusClient.State.registering = false
    end
    SetTimeout(Config.RegistrationDelayMs, function()
        ServicesPlusClient.RegisterApp()
        if resourceName == "lb-phone" then
            ServicesPlusClient.RequestServer("getInitialState", {}, function(response)
                local user = response.success and response.data and response.data.currentUser or nil
                if not user or not user.employment or not user.employment.onDuty then return end
                for _, company in ipairs(response.data.companies or {}) do
                    if company.id == user.employment.companyId then
                        local active = {}; for _, id in ipairs(user.employment.employee and user.employment.employee.activeNumberIds or {}) do active[id] = true end
                        local numbers = {}; for _, number in ipairs(company.numbers or {}) do if active[number.id] and number.callsEnabled then numbers[#numbers + 1] = number end end
                        ServicesPlusClient.Integrations.SyncCompanyNumbers(numbers); break
                    end
                end
            end)
        end
    end)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == "lb-phone" then
        ServicesPlusClient.State.registered = false
        ServicesPlusClient.State.registering = false
        ServicesPlusClient.Integrations.ResetCompanyNumbers()
        return
    end
    if resourceName ~= GetCurrentResourceName() then return end
    ServicesPlusClient.RemoveApp()
    ServicesPlusClient.Integrations.ClearCompanyNumbers()
    for requestId, callback in pairs(ServicesPlusClient.State.pending) do
        callback(ServicesPlus.Error("resource_stopped", "Services+ stopped before the request completed.", true))
        ServicesPlusClient.State.pending[requestId] = nil
    end
end)

RegisterNetEvent("lb-phone:numberChanged", function()
    TriggerServerEvent("services-plus:server:phoneChanged")
end)
