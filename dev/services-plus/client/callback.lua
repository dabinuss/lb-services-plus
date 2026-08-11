--[[
    Client side of the server callback registry (see server/callback.lua).
    ServerCallback() yields the current coroutine until the server replies,
    which is safe to call from inside a RegisterNUICallback handler.
]]

local pending = {}
local nextRequestId = 0

-- A resource restart, a dropped response, or a server-side error the
-- callback never explicitly replies to would otherwise leave the calling
-- NUI request (and whatever `await`-ed it) hanging forever (plan review §13).
local TIMEOUT_MS = 10000

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

    CreateThread(function()
        Wait(TIMEOUT_MS)

        if pending[requestId] then
            pending[requestId] = nil
            promiseObj:resolve({ false, "timeout" })
        end
    end)

    local result = Citizen.Await(promiseObj)
    return table.unpack(result)
end
