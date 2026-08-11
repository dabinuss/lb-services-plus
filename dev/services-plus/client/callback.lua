--[[
    Client side of the server callback registry (see server/callback.lua).
    ServerCallback() yields the current coroutine until the server replies,
    which is safe to call from inside a RegisterNUICallback handler.
]]

local pending = {}
local nextRequestId = 0

RegisterNetEvent("services-plus:client:callbackResponse", function(requestId, ok, ...)
    local promiseObj = pending[requestId]
    if not promiseObj then return end

    pending[requestId] = nil
    promiseObj:resolve({ ok, ... })
end)

---@param name string
---@return boolean ok, ... result (or an error message when ok is false)
function ServerCallback(name, ...)
    nextRequestId = nextRequestId + 1
    local requestId = nextRequestId

    local promiseObj = promise.new()
    pending[requestId] = promiseObj

    TriggerServerEvent("services-plus:server:callback", name, requestId, ...)

    local result = Citizen.Await(promiseObj)
    return table.unpack(result)
end
