ServicesPlusClient.Integrations = ServicesPlusClient.Integrations or {}

local registeredNumbers = {}
local incomingCalls = {}

function ServicesPlusClient.Integrations.CreateCustomNumber(number, handlers)
    if GetResourceState("lb-phone") ~= "started" then return false, "lb-phone unavailable" end
    return exports["lb-phone"]:CreateCustomNumber(number, handlers)
end

function ServicesPlusClient.Integrations.RemoveCustomNumber(number)
    if GetResourceState("lb-phone") ~= "started" then return false, "lb-phone unavailable" end
    return exports["lb-phone"]:RemoveCustomNumber(number)
end

function ServicesPlusClient.Integrations.SyncCompanyNumbers(numbers)
    local wanted = {}
    for _, number in ipairs(numbers or {}) do
        wanted[number.number] = true
        if not registeredNumbers[number.number] then
            local success, reason = ServicesPlusClient.Integrations.CreateCustomNumber(number.number, {
                onCall = function(incomingCall)
                    local token = tostring(incomingCall.id)
                    incomingCalls[token] = incomingCall
                    incomingCall.setName(number.label)
                    ServicesPlusClient.RequestServer("registerIncomingCall", { number = number.number, callToken = token }, function(response)
                        if not response.success then
                            incomingCalls[token] = nil
                            incomingCall.deny()
                        end
                    end)
                end,
                onEnd = function()
                    for token, call in pairs(incomingCalls) do
                        if call.hasEnded() then
                            incomingCalls[token] = nil
                            ServicesPlusClient.RequestServer("endCustomCall", { callToken = token }, function() end)
                        end
                    end
                end
            })
            if success then registeredNumbers[number.number] = true elseif Config.Debug then print(("[services-plus] Custom number %s failed: %s"):format(number.number, reason or "unknown")) end
        end
    end
    for value in pairs(registeredNumbers) do
        if not wanted[value] then ServicesPlusClient.Integrations.RemoveCustomNumber(value); registeredNumbers[value] = nil end
    end
end

function ServicesPlusClient.Integrations.ClearCompanyNumbers()
    for value in pairs(registeredNumbers) do ServicesPlusClient.Integrations.RemoveCustomNumber(value) end
    registeredNumbers = {}
    incomingCalls = {}
end

function ServicesPlusClient.Integrations.ResetCompanyNumbers()
    registeredNumbers = {}
    incomingCalls = {}
end

function ServicesPlusClient.Integrations.AcceptIncomingCall(token)
    local incomingCall = incomingCalls[tostring(token)]
    if not incomingCall or incomingCall.hasEnded() then return false end
    incomingCall.accept()
    return true
end

RegisterNetEvent("services-plus:client:syncNumbers", function(numbers)
    ServicesPlusClient.Integrations.SyncCompanyNumbers(type(numbers) == "table" and numbers or {})
end)
