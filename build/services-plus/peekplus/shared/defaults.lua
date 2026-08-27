PeekPlusDefaults = {
    version = "1.9.0",
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
        BACK = true,
    },
    allowedColors = {
        default = true,
        primary = true,
        success = true,
        danger = true,
    },
    allowedVariants = {
        neutral = true,
        info = true,
        success = true,
        warning = true,
        error = true,
    },
    allowedLayouts = {
        text = true,
        details = true,
        actions = true,
        progress = true,
        timer = true,
        custom = true,
    },
    standardTemplates = {
        default = "text",
        compact = "text",
        detail = "details",
        action = "actions",
        services = "actions",
        progress = "progress",
        timer = "timer",
    },
}

assert(type(Config.PeekPlus) == "table", "Config.PeekPlus must be a table")
assert(type(Config.PeekPlusApp) == "table", "Config.PeekPlusApp must be a table")
assert(type(Config.PeekPlusApp.enabled) == "boolean", "Config.PeekPlusApp.enabled must be true or false")
for _, field in ipairs({ "maxCards", "maxCardsPerOwner", "maxActions", "minDuration", "maxDuration", "maxQueueTtl", "maxPriority", "actionTimeout", "soundThrottle", "maxHistory", "maxDetails", "maxTemplateDataBytes", "maxTemplateHeight", "maxTimerDuration" }) do
    local value = Config.PeekPlus[field]
    assert(type(value) == "number" and value % 1 == 0 and value >= 0,
        ("Config.PeekPlus.%s must be a non-negative integer"):format(field))
end
assert(Config.PeekPlus.maxCards > 0, "Config.PeekPlus.maxCards must be greater than zero")
assert(Config.PeekPlus.maxCardsPerOwner > 0, "Config.PeekPlus.maxCardsPerOwner must be greater than zero")
assert(Config.PeekPlus.maxCardsPerOwner <= Config.PeekPlus.maxCards,
    "Config.PeekPlus.maxCardsPerOwner must not exceed maxCards")
assert(Config.PeekPlus.maxActions > 0, "Config.PeekPlus.maxActions must be greater than zero")
assert(Config.PeekPlus.minDuration > 0, "Config.PeekPlus.minDuration must be greater than zero")
assert(Config.PeekPlus.minDuration <= Config.PeekPlus.maxDuration,
    "Config.PeekPlus.minDuration must not exceed maxDuration")
assert(Config.PeekPlus.minDuration <= Config.PeekPlus.maxQueueTtl,
    "Config.PeekPlus.minDuration must not exceed maxQueueTtl")
assert(Config.PeekPlus.minDuration <= Config.PeekPlus.actionTimeout,
    "Config.PeekPlus.minDuration must not exceed actionTimeout")
assert(Config.PeekPlus.maxHistory > 0, "Config.PeekPlus.maxHistory must be greater than zero")
assert(Config.PeekPlus.maxDetails > 0, "Config.PeekPlus.maxDetails must be greater than zero")
assert(Config.PeekPlus.maxTemplateDataBytes > 0, "Config.PeekPlus.maxTemplateDataBytes must be greater than zero")
assert(Config.PeekPlus.maxTemplateHeight > 0, "Config.PeekPlus.maxTemplateHeight must be greater than zero")
assert(Config.PeekPlus.maxTimerDuration > 0, "Config.PeekPlus.maxTimerDuration must be greater than zero")
assert(type(Config.PeekPlus.rootFallback) == "boolean", "Config.PeekPlus.rootFallback must be true or false")
assert(type(Config.PeekPlus.textLimits) == "table", "Config.PeekPlus.textLimits must be a table")
for _, field in ipairs({ "title", "subtitle", "description", "actionId", "actionLabel" }) do
    local value = Config.PeekPlus.textLimits[field]
    assert(type(value) == "number" and value % 1 == 0 and value > 0,
        ("Config.PeekPlus.textLimits.%s must be a positive integer"):format(field))
end
