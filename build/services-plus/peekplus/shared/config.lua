-- PeekPlus' local notification centre. It is a second LB Phone app backed by
-- the same resource and never sends notification history to the server.
Config.PeekPlusApp = {
    enabled = true,                        -- Register the app and collect local notification history.
    identifier = "peekplus_notifications", -- Unique internal LB Phone app identifier.
    name = "Notifications",                -- Name shown below the app icon.
    description = "Your recent PeekPlus notifications.", -- App Store description.
    developer = "Dabi",                   -- Developer shown by LB Phone.
    defaultApp = true,                     -- Install automatically for every player.
    size = 8,                              -- Displayed app size in kB.
}

-- Generic PeekPlus notification layer. These limits bound input from
-- consumer resources without involving the server in card presentation.
Config.PeekPlus = {
    rootFallback = true,       -- Show a safe root notification when no usable phone exists.
    maxCards = 50,             -- Maximum cards held globally on one client.
    maxCardsPerOwner = 10,     -- Maximum cards owned by one consumer resource.
    maxActions = 4,            -- Maximum buttons/actions on one card.
    minDuration = 250,         -- Shortest temporary display/queue lifetime in milliseconds.
    maxDuration = 300000,      -- Longest temporary peek in milliseconds (5 minutes).
    maxQueueTtl = 3600000,     -- Longest time a card may wait for first display (1 hour).
    maxPriority = 100,         -- Highest accepted queue priority.
    actionTimeout = 10000,     -- Re-enable an unanswered action after this many milliseconds.
    soundThrottle = 1000,      -- Minimum time between PeekPlus notification sounds.
    maxHistory = 100,          -- Local session-history entries retained on one client.
    maxDetails = 8,            -- Maximum label/value rows in a details card.
    maxTemplateDataBytes = 4096, -- Maximum JSON payload passed to a custom template.
    maxTemplateHeight = 320,   -- Maximum custom-template iframe height in CSS pixels.
    maxTimerDuration = 86400000, -- Maximum timer/countdown duration (24 hours).
    textLimits = {
        title = 100,
        subtitle = 120,
        description = 500,
        actionId = 48,
        actionLabel = 60,
    },
}
