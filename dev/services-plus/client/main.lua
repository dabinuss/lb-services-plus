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
    SetTimeout(Config.RegistrationDelayMs, ServicesPlusClient.RegisterApp)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == "lb-phone" then
        ServicesPlusClient.State.registered = false
        ServicesPlusClient.State.registering = false
        return
    end
    if resourceName ~= GetCurrentResourceName() then return end
    ServicesPlusClient.RemoveApp()
    for requestId, callback in pairs(ServicesPlusClient.State.pending) do
        callback(ServicesPlus.Error("resource_stopped", "Services+ stopped before the request completed.", true))
        ServicesPlusClient.State.pending[requestId] = nil
    end
end)
