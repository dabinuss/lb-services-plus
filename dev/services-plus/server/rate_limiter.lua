ServicesPlus.RateLimiter = ServicesPlus.RateLimiter or {}

local RateLimiter = ServicesPlus.RateLimiter
local buckets = {}

function RateLimiter.Allow(source, action)
    local rule = Config.RateLimits[action]
    if not rule then return true end

    local now = GetGameTimer()
    local key = ("%s:%s"):format(source, action)
    local bucket = buckets[key]
    if not bucket or now - bucket.startedAt >= rule.windowMs then
        buckets[key] = { startedAt = now, count = 1 }
        return true
    end

    if bucket.count >= rule.limit then return false end
    bucket.count = bucket.count + 1
    return true
end

function RateLimiter.Clear(source)
    local prefix = tostring(source) .. ":"
    for key in pairs(buckets) do
        if key:sub(1, #prefix) == prefix then buckets[key] = nil end
    end
end
