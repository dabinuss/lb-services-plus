--[[
    Tiny dependency-free server callback registry, so Services+ does not
    require ox_lib just to answer NUI requests. Mirrors the shape of
    lb-phone's own BaseCallback/TriggerCallback pair.

    Everything arrives through this one NetEvent with a client-supplied
    callback name (plan review §3) - a modified client can call any
    registered RPC directly, no UI involved, as fast as it likes. Two things
    guard against that here: a token-bucket rate limit (global per player,
    plus tighter per-action limits for the expensive/abusable ones) and never
    forwarding raw pcall error text to the client (plan review §13 - that's
    for the server log only).
]]

local handlers = {}

---@param name string
---@param fn fun(source: number, reply: fun(...), ...)
function RegisterCallback(name, fn)
    handlers[name] = fn
end

-- ---------------------------------------------------------------------------
-- Rate limiting: classic token bucket, refilled continuously by elapsed
-- time rather than on a tick loop (so idle players cost nothing).
-- ---------------------------------------------------------------------------

local GLOBAL_LIMIT = { capacity = 30, refill = 15 } -- generous burst, ~15/s sustained
local ADMIN_WRITE_LIMIT = { capacity = 10, refill = 2 }
local ACTION_LIMITS = {
    sendMessage = { capacity = 5, refill = 1 },
    createRequest = { capacity = 3, refill = 0.1 },
    resolveCall = { capacity = 5, refill = 0.3 },
    archiveConversation = { capacity = 5, refill = 0.5 },
    acceptRequest = { capacity = 5, refill = 0.5 },
    toggleHotline = { capacity = 5, refill = 0.5 },
    setStatus = { capacity = 5, refill = 0.5 },
    toggleDuty = { capacity = 5, refill = 0.2 },
}

local globalBuckets = {} -- source -> { tokens, last }
local actionBuckets = {} -- source -> { [action] = { tokens, last } }

local function consume(bucket, limit)
    local now = GetGameTimer() / 1000.0

    if not bucket.last then
        bucket.tokens = limit.capacity
        bucket.last = now
    else
        bucket.tokens = math.min(limit.capacity, bucket.tokens + (now - bucket.last) * limit.refill)
        bucket.last = now
    end

    if bucket.tokens < 1 then return false end

    bucket.tokens = bucket.tokens - 1
    return true
end

local function isAdminWrite(name)
    -- "admin:get" is 9 chars - sub(1, 10) here would compare a 10-char
    -- slice against a 9-char literal and never match, silently rate-limiting
    -- every admin:get* read as if it were a write (plan review round 2 §8).
    return name:sub(1, 6) == "admin:" and name:sub(1, 9) ~= "admin:get"
end

---@param source number
---@param name string
---@return boolean allowed
local function checkRateLimit(source, name)
    globalBuckets[source] = globalBuckets[source] or {}
    if not consume(globalBuckets[source], GLOBAL_LIMIT) then return false end

    local actionLimit = ACTION_LIMITS[name] or (isAdminWrite(name) and ADMIN_WRITE_LIMIT or nil)
    if not actionLimit then return true end

    actionBuckets[source] = actionBuckets[source] or {}
    actionBuckets[source][name] = actionBuckets[source][name] or {}

    return consume(actionBuckets[source][name], actionLimit)
end

AddEventHandler("playerDropped", function()
    globalBuckets[source] = nil
    actionBuckets[source] = nil
end)

-- ---------------------------------------------------------------------------

RegisterNetEvent("services-plus:server:callback", function(name, requestId, ...)
    local src = source

    local function fail(reason)
        TriggerClientEvent("services-plus:client:callbackResponse", src, requestId, false, reason)
    end

    local handler = handlers[name]
    if not handler then return fail("unknown_callback") end

    if not checkRateLimit(src, name) then return fail("rate_limited") end

    local function reply(...)
        TriggerClientEvent("services-plus:client:callbackResponse", src, requestId, true, ...)
    end

    local ok, err = pcall(handler, src, reply, ...)

    if not ok then
        -- The actual error (SQL text, stack trace, ...) stays server-side.
        print(("^1[services-plus] callback '%s' errored: %s^7"):format(name, tostring(err)))
        fail("server_error")
    end
end)
