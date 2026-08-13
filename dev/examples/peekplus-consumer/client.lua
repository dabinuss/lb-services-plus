local activePeek = nil

local function registerTemplate()
    local id, err = exports["services-plus"]:RegisterPeekTemplate("live-map", {
        ui = "ui/live-map.html",
        height = 150,
    })
    if not id then print(("[peekplus-test-consumer] template registration failed: %s"):format(err or "unknown_error")) end
end

CreateThread(registerTemplate)

AddEventHandler("onClientResourceStart", function(resource)
    if resource == "services-plus" then registerTemplate() end
end)

RegisterCommand("peekplus_test_consumer", function()
    if activePeek then
        exports["services-plus"]:RemovePeek(activePeek)
        activePeek = nil
    end

    local err
    activePeek, err = exports["services-plus"]:ShowPeek({
        key = "consumer-live-map",
        state = "pending",
        title = "Route guidance",
        subtitle = GetCurrentResourceName(),
        description = "Consumer-owned template rendered inside PeekPlus.",
        variant = "info",
        template = "live-map",
        templateData = { street = "Vespucci Boulevard", distance = "350 m", direction = "right" },
        duration = 15000,
        sound = true,
        actions = {
            { id = "dismiss", label = "Dismiss", key = "DELETE", color = "danger" },
            { id = "accept", label = "Accept", key = "RETURN", color = "success" },
        },
    })

    if not activePeek then
        print(("[peekplus-test-consumer] ShowPeek failed: %s"):format(err or "unknown_error"))
    end
end, false)

AddEventHandler("peekplus:action:peekplus-test-consumer", function(data)
    if data.id ~= activePeek then return end
    if data.action == "dismiss" then
        exports["services-plus"]:RemovePeek(data.id, data.revision, data.actionToken)
        activePeek = nil
        return
    end

    if data.action == "accept" then
        local ok = exports["services-plus"]:UpdatePeek(data.id, {
            state = "active",
            description = "The external action was accepted.",
            duration = -1,
            hold = true,
            sound = false,
            actions = {
                {
                    id = "dismiss",
                    label = "Dismiss",
                    key = "DELETE",
                    color = "danger",
                    confirm = { label = "Confirm?", timeout = 5000 },
                },
            },
        }, data.revision, data.actionToken)
        if not ok then exports["services-plus"]:ReleasePeekAction(data.id, data.actionToken) end
    end
end)
