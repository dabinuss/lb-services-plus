ServicesPlus.Idempotency = ServicesPlus.Idempotency or {}

local Idempotency = ServicesPlus.Idempotency
local entries = {}
local ttlSeconds = 20

--- Runs `run` once per scope key and replays the cached result for repeated
--- calls with the same key within the TTL, so a retried NUI request or a
--- double click cannot create a duplicate request or message.
---@param scopeKey string? Unique per player, action and client-supplied id; nil skips deduplication.
---@param run fun(): ... Producer invoked at most once per scope key per TTL window.
function Idempotency.Resolve(scopeKey, run)
    if type(scopeKey) ~= "string" or scopeKey == "" then return run() end
    local now = os.time()
    local entry = entries[scopeKey]
    if entry and now - entry.time < ttlSeconds then return table.unpack(entry.result, 1, entry.result.n) end
    local result = table.pack(run())
    entries[scopeKey] = { result = result, time = now }
    return table.unpack(result, 1, result.n)
end

local function cleanup()
    local now = os.time()
    for key, entry in pairs(entries) do
        if now - entry.time >= ttlSeconds then entries[key] = nil end
    end
    SetTimeout(30000, cleanup)
end
SetTimeout(30000, cleanup)
