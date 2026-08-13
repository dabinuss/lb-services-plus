Config = {}

-- "auto" tries ESX -> QBCore -> Qbox -> Standalone, in that order.
-- Set explicitly ("esx", "qb", "qbx", "standalone") if auto-detection picks the wrong one.
Config.Framework = "auto"

Config.Locale = "en"

-- Set to true if you want the script to automatically populate an empty database 
-- with default test companies (Police, Ambulance, Mechanic, Taxi).
-- It will safely skip if companies already exist.
Config.SeedTestData = false

-- Custom app registration (see docs.lbscripts.com/phone/custom-apps)
Config.App = {
    identifier = "services_plus",
    name = "Services+",
    description = "Contact and manage every company on the server.",
    developer = "Dabi",
    defaultApp = true, -- pre-installed, players do not need to download it
    size = 15,
}

-- Services+ admins (ACE permission). Server console/config admins can also be
-- granted via Config.AdminIdentifiers below.
Config.AdminAcePermission = "servicesplus.admin"
Config.AdminIdentifiers = {
    -- "license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
}

-- Companies without anyone on duty:
-- "grey" = shown but greyed out, "hide" = not shown at all
Config.UnavailableCompanyMode = "grey"

-- Allow players to message a company even if nobody is currently on duty.
Config.MessageOffline = true

-- Allow employees to delete/archive conversations from their own view.
Config.AllowConversationDelete = true

-- Who can see a company's on-duty employee list from the public app.
-- "everyone" | "employees" | "none"
Config.SeeEmployees = "employees"

-- Default routing modes used for newly created companies. Company bosses may
-- change this within the limits an admin allows (see phone_services_plus_companies).
Config.DefaultCallRouting = "all" -- "all" | "random" | "hotline"
Config.DefaultRequestRouting = "all" -- "all" | "random" | "hotline"

-- Pagination sizes (see plan §68).
Config.PageSize = {
    messages = 25,
    activity = 25,
    requests = 25,
    calls = 25,
}

-- Highest passenger count a request may claim (server-validated, see
-- server/requests.lua).
Config.MaxPassengerCount = 20

-- Services+-owned request notifications trigger LB Phone's native notification
-- peek, then the Sibling-NUI controller keeps that reached visual state for
-- this duration. Set it to 0 to use LB Phone's native duration only. Once a
-- request is accepted, its active card is held until the request ends.
Config.RequestNotificationPeekDuration = 15000

-- Generic PeekPlus notification layer. The defaults preserve the current
-- Services+ peek behaviour while bounding external consumer input.
Config.PeekPlus = {
    rootFallback = true,       -- Show a safe root notification when no usable phone exists.
    maxCards = 50,             -- Maximum cards held globally on one client.
    maxCardsPerOwner = 10,     -- Maximum cards owned by one consumer resource.
    maxActions = 4,            -- Maximum buttons/actions on one card.
    maxDuration = 300000,      -- Longest temporary peek in milliseconds (5 minutes).
    maxPriority = 100,         -- Highest accepted queue priority.
    actionTimeout = 10000,     -- Re-enable an unanswered action after this many milliseconds.
    soundThrottle = 1000,      -- Minimum time between PeekPlus notification sounds.
    textLimits = {
        title = 100,
        subtitle = 120,
        description = 500,
        actionId = 48,
        actionLabel = 60,
    },
}
