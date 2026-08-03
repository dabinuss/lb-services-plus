ServicesPlus.RateLimiter = ServicesPlus.RateLimiter or {}

local RateLimiter = ServicesPlus.RateLimiter
local buckets = {}
local rejected = { entries = {}, overflow = 0, scheduled = false }

local function flushRejected()
    rejected.scheduled = false
    local total, actions, subjects = rejected.overflow, {}, {}
    for _, entry in pairs(rejected.entries) do
        total = total + entry.count
        actions[entry.action] = (actions[entry.action] or 0) + entry.count
        subjects[entry.subject] = true
    end
    if total > 0 then
        local subjectCount = 0
        for _ in pairs(subjects) do subjectCount = subjectCount + 1 end
        ServicesPlus.Logger.Warn("Rate limit rejection summary", { total = total, actions = actions, subjects = subjectCount, overflow = rejected.overflow })
    end
    rejected.entries, rejected.overflow = {}, 0
end

local function recordRejection(source, action)
    local config = Config.RateLimitTelemetry or {}
    if config.enabled == false then return end
    local key = ("%s:%s"):format(source, action)
    local entry = rejected.entries[key]
    if entry then
        entry.count = entry.count + 1
    else
        local count = 0
        for _ in pairs(rejected.entries) do count = count + 1 end
        if count >= math.max(1, tonumber(config.maxEntries) or 50) then
            rejected.overflow = rejected.overflow + 1
        else
            rejected.entries[key] = { action = action, subject = tostring(source), count = 1 }
        end
    end
    if not rejected.scheduled then
        rejected.scheduled = true
        SetTimeout(math.max(1000, tonumber(config.summaryWindowMs) or 60000), flushRejected)
    end
end

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

    if bucket.count >= rule.limit then
        recordRejection(source, action)
        return false
    end
    bucket.count = bucket.count + 1
    return true
end

function RateLimiter.Clear(source)
    local prefix = tostring(source) .. ":"
    for key in pairs(buckets) do
        if key:sub(1, #prefix) == prefix then buckets[key] = nil end
    end
end
