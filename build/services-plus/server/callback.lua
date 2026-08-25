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

-- Set by server/bootstrap.lua after every cache and seed dependency has been
-- initialized in a deterministic order. Keeping this state next to the RPC
-- entry point means no NUI callback can observe half-populated caches.
ServicesPlus = ServicesPlus or { ready = false, initializationError = nil }

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
    updateCompanySettings = { capacity = 3, refill = 1 },
    updateNumberSettings = { capacity = 3, refill = 1 },
    completeRequest = { capacity = 3, refill = 0.5 },
    cancelRequest = { capacity = 3, refill = 0.5 },
    markRead = { capacity = 5, refill = 2 },
    markConversationRead = { capacity = 5, refill = 2 },
    setLocale = { capacity = 3, refill = 0.5 },
    resolveCall = { capacity = 5, refill = 0.3 },
    archiveConversation = { capacity = 5, refill = 0.5 },
    acceptRequest = { capacity = 5, refill = 0.5 },
    toggleHotline = { capacity = 5, refill = 0.5 },
    setStatus = { capacity = 5, refill = 0.5 },
    toggleDuty = { capacity = 5, refill = 0.2 },
    updateTaxiPricingSettings = { capacity = 5, refill = 0.2 },
    getCustomerRequestJourneys = { capacity = 2, refill = 0.1 },
    getEmployeeDailyStats = { capacity = 3, refill = 0.1 },
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
---@return boolean allowed
local function checkGlobalRateLimit(source)
    globalBuckets[source] = globalBuckets[source] or {}
    return consume(globalBuckets[source], GLOBAL_LIMIT)
end

---@param source number
---@param name string
---@return boolean allowed
local function checkActionRateLimit(source, name)
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

    -- Reject malformed envelope data without reflecting anything back. This
    -- keeps invalid request ids out of the response event and bounds the
    -- work done before rate limiting. Valid-but-unknown callback names still
    -- receive an error, but only after consuming a global token.
    if type(name) ~= "string" or #name == 0 or #name > 64
        or not name:match("^[%w_:]+$") then return end
    if type(requestId) ~= "number" or requestId ~= math.floor(requestId)
        or requestId < 1 or requestId > 2147483647 then return end

    local function fail(reason)
        TriggerClientEvent("services-plus:client:callbackResponse", src, requestId, false, reason)
    end

    if not checkGlobalRateLimit(src) then return fail("rate_limited") end

    local handler = handlers[name]
    if not handler then return fail("unknown_callback") end

    if not checkActionRateLimit(src, name) then return fail("rate_limited") end

    -- Hold an early RPC briefly instead of making consumers race the cache
    -- bootstrap. The client callback has a 10-second timeout, so leave it a
    -- two-second margin and return an explicit transient error if startup is
    -- unusually slow.
    local readyDeadline = GetGameTimer() + 8000
    while not ServicesPlus.ready and not ServicesPlus.initializationError
        and GetGameTimer() < readyDeadline and GetPlayerName(src) ~= nil do
        Wait(50)
    end

    if not ServicesPlus.ready then
        return fail(ServicesPlus.initializationError and "initialization_failed" or "not_ready")
    end

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
