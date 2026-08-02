ServicesPlusClient.Integrations = ServicesPlusClient.Integrations or {}

-- Prototype used by Phase 2 after server-side routing and locking are active.
function ServicesPlusClient.Integrations.CreateCustomNumber(number, handlers)
    if GetResourceState("lb-phone") ~= "started" then return false, "lb-phone unavailable" end
    return exports["lb-phone"]:CreateCustomNumber(number, handlers)
end

function ServicesPlusClient.Integrations.RemoveCustomNumber(number)
    if GetResourceState("lb-phone") ~= "started" then return false, "lb-phone unavailable" end
    return exports["lb-phone"]:RemoveCustomNumber(number)
end
