PeekPlusMediaPolicy = {}

local function escapePattern(text)
    return text:gsub("(%W)", "%%%1")
end

local function hostnamePattern(entry)
    local parts = {}
    for segment in entry:gmatch("[^%.]+") do
        parts[#parts + 1] = segment == "*" and "[^.]+" or escapePattern(segment)
    end
    return "^" .. table.concat(parts, "%.") .. "$"
end

local function addHostnamePatterns(target, entries)
    if type(entries) ~= "table" then return end
    for index = 1, #entries do
        if type(entries[index]) == "string" and entries[index] ~= "" then
            target[#target + 1] = hostnamePattern(entries[index])
        end
    end
end

local function addDomainPatterns(target, entries)
    if type(entries) ~= "table" then return end
    for index = 1, #entries do
        if type(entries[index]) == "string" and entries[index] ~= "" then
            local escaped = escapePattern(entries[index])
            target[#target + 1] = "^" .. escaped .. "$"
            target[#target + 1] = "^.+%." .. escaped .. "$"
        end
    end
end

local function matchesAny(hostname, patterns)
    for index = 1, #patterns do
        if hostname:find(patterns[index]) then return true end
    end
    return false
end

-- Mirrors LB Phone's shared/media.lua policy construction. Keeping this in
-- shared code gives PeekPlus cards and Services+ branding one source of truth.
---@param phoneConfig table
---@return table? policy
function PeekPlusMediaPolicy.Build(phoneConfig)
    if type(phoneConfig) ~= "table" then return nil end

    local allowed, blocked = {}, {}
    local anyExternalAllowed = false
    if type(phoneConfig.AllowExternal) == "table" then
        for _, enabled in pairs(phoneConfig.AllowExternal) do
            if enabled then anyExternalAllowed = true break end
        end
    end

    if anyExternalAllowed then
        addHostnamePatterns(allowed, phoneConfig.ExternalWhitelistedHostnames)
        addDomainPatterns(allowed, phoneConfig.ExternalWhitelistedDomains)
        addHostnamePatterns(blocked, phoneConfig.ExternalBlacklistedHostnames)
        addDomainPatterns(blocked, phoneConfig.ExternalBlacklistedDomains)
    end
    addHostnamePatterns(allowed, phoneConfig.UploadWhitelistedHostnames)
    addDomainPatterns(allowed, phoneConfig.UploadWhitelistedDomains)

    return { allowed = allowed, blocked = blocked }
end

---@param link any
---@param policy table?
---@return boolean
function PeekPlusMediaPolicy.IsAllowed(link, policy)
    if type(link) ~= "string" or type(policy) ~= "table" then return false end
    if #policy.allowed == 0 and #policy.blocked == 0 then return true end

    -- Keep extraction and matching order aligned with LB Phone:
    -- blacklist wins; an empty allowlist otherwise allows every hostname.
    local hostname = link:match("^https?://([^/]+)")
    if not hostname or not hostname:find("%.") then return false end
    if matchesAny(hostname, policy.blocked) then return false end
    if #policy.allowed == 0 then return true end
    return matchesAny(hostname, policy.allowed)
end
