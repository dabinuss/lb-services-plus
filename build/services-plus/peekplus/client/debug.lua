if Config.Debug ~= true then return end

local owner = GetCurrentResourceName()
local testId = nil

local function stopTest(reason)
    if testId then PeekPlus.Remove(testId, owner) end
    testId = nil
    print(("[services-plus] PeekPlus test %s."):format(reason or "stopped"))
end

local function showTest(duration, label)
    if testId and PeekPlus.Get(testId, owner) then
        return print("[services-plus] PeekPlus test skipped: a test card is already active.")
    end
    if PeekPlus.Count(owner) > 0 then
        return print("[services-plus] PeekPlus test skipped: finish or dismiss the real request first.")
    end
    if PeekPlusLBPhone.IsOpen() then
        return print("[services-plus] PeekPlus test skipped: close the fully opened phone first.")
    end
    testId = PeekPlus.Show({
        state = "pending",
        title = "PeekPlus Test",
        subtitle = "Local F8 test · " .. label,
        description = "Accept with ENTER or decline with BACKSPACE. No server request is created.",
        duration = duration,
        hold = duration < 0,
        sound = true,
        actions = {
            { id = "test_decline", label = "Backspace · Decline", key = "BACK", color = "danger" },
            { id = "test_accept", label = "Enter · Accept", key = "RETURN", color = "success" },
        },
    }, owner)
    if testId then print(("[services-plus] PeekPlus test started (%s)."):format(label)) end
end

PeekPlus.RegisterActionHandler("services-plus-debug", function() end)

AddEventHandler(("peekplus:action:%s"):format(owner), function(data)
    if data.id ~= testId then return end
    if data.action == "test_decline" or data.action == "test_cancel" then
        return stopTest(data.action == "test_decline" and "declined" or "cancelled")
    end
    if data.action == "test_accept" then
        PeekPlus.Update(testId, {
            state = "active",
            title = "PeekPlus Test · Accepted",
            description = "Test request accepted. It remains active until cancelled.",
            duration = -1,
            hold = true,
            sound = false,
            actions = {
                {
                    id = "test_cancel",
                    label = "Cancel test request",
                    key = "BACK",
                    color = "danger",
                    confirm = { label = "Confirm?", timeout = 5000 },
                },
            },
        }, owner)
    end
end)

RegisterCommand("peekplus_test", function(_, args)
    if args[1] == "stop" then return stopTest() end
    if args[1] == "hold" then return showTest(-1, "until stopped") end
    local configured = math.floor((tonumber(Config.RequestNotificationPeekDuration) or 15000) / 1000)
    local seconds = math.max(1, math.min(120, math.floor(tonumber(args[1]) or configured)))
    showTest(seconds * 1000, seconds .. " seconds")
end, false)

RegisterCommand("peekplus_test_hold", function()
    showTest(-1, "until stopped")
end, false)

RegisterCommand("peekplus_test_template", function(_, args)
    local kind = tostring(args[1] or "info"):lower()
    local spec = {
        key = "debug-template",
        title = "PeekPlus " .. kind,
        subtitle = "Local template test",
        description = "This notification is rendered from structured client data.",
        duration = 15000,
        sound = false,
        history = true,
        variant = ({ warning = "warning", error = "error", success = "success" })[kind] or "info",
    }
    if kind == "details" then
        spec.template = "detail"
        spec.details = {
            { label = "Location", value = "Legion Square" },
            { label = "Distance", value = "350 m" },
        }
    elseif kind == "progress" then
        spec.template = "progress"
        spec.progress = { value = 68, max = 100, label = "Download" }
    elseif kind == "timer" then
        spec.template = "timer"
        spec.timer = { elapsed = 0, duration = 60000, countdown = true, label = "Time remaining" }
    else
        spec.template = "compact"
    end
    local id, err = PeekPlus.Show(spec, owner)
    print(id and ("[services-plus] PeekPlus %s template test started."):format(kind)
        or ("[services-plus] PeekPlus template test failed: %s"):format(err or "unknown_error"))
end, false)
