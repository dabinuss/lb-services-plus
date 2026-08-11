--[[
    Tiny dependency-free server callback registry, so Services+ does not
    require ox_lib just to answer NUI requests. Mirrors the shape of
    lb-phone's own BaseCallback/TriggerCallback pair.
]]

local handlers = {}

---@param name string
---@param fn fun(source: number, reply: fun(...), ...)
function RegisterCallback(name, fn)
    handlers[name] = fn
end

RegisterNetEvent("services-plus:server:callback", function(name, requestId, ...)
    local src = source
    local handler = handlers[name]

    if not handler then
        return TriggerClientEvent("services-plus:client:callbackResponse", src, requestId, false, ("unknown callback: %s"):format(name))
    end

    local function reply(...)
        TriggerClientEvent("services-plus:client:callbackResponse", src, requestId, true, ...)
    end

    local ok, err = pcall(handler, src, reply, ...)

    if not ok then
        print(("^1[services-plus] callback '%s' errored: %s^7"):format(name, err))
        TriggerClientEvent("services-plus:client:callbackResponse", src, requestId, false, err)
    end
end)
