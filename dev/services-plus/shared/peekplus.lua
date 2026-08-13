PeekPlusDefaults = {
    version = "1.0.0",
    allowedStates = {
        queued = true,
        pending = true,
        active = true,
        completed = true,
        declined = true,
        removed = true,
    },
    transitions = {
        queued = { pending = true, removed = true },
        pending = { active = true, declined = true, removed = true },
        active = { completed = true, declined = true, removed = true },
        completed = { removed = true },
        declined = { removed = true },
        removed = {},
    },
    allowedKeys = {
        RETURN = true,
        DELETE = true,
    },
    allowedColors = {
        default = true,
        primary = true,
        success = true,
        danger = true,
    },
}

assert(type(Config.PeekPlus) == "table", "Config.PeekPlus must be a table")
for _, field in ipairs({ "maxCards", "maxCardsPerOwner", "maxActions", "maxDuration", "maxPriority", "actionTimeout", "soundThrottle" }) do
    local value = Config.PeekPlus[field]
    assert(type(value) == "number" and value % 1 == 0 and value >= 0,
        ("Config.PeekPlus.%s must be a non-negative integer"):format(field))
end
assert(Config.PeekPlus.maxCards > 0, "Config.PeekPlus.maxCards must be greater than zero")
assert(Config.PeekPlus.maxCardsPerOwner > 0, "Config.PeekPlus.maxCardsPerOwner must be greater than zero")
assert(Config.PeekPlus.maxCardsPerOwner <= Config.PeekPlus.maxCards,
    "Config.PeekPlus.maxCardsPerOwner must not exceed maxCards")
assert(Config.PeekPlus.maxActions > 0, "Config.PeekPlus.maxActions must be greater than zero")
assert(type(Config.PeekPlus.rootFallback) == "boolean", "Config.PeekPlus.rootFallback must be true or false")
assert(type(Config.PeekPlus.textLimits) == "table", "Config.PeekPlus.textLimits must be a table")
for _, field in ipairs({ "title", "subtitle", "description", "actionId", "actionLabel" }) do
    local value = Config.PeekPlus.textLimits[field]
    assert(type(value) == "number" and value % 1 == 0 and value > 0,
        ("Config.PeekPlus.textLimits.%s must be a positive integer"):format(field))
end
