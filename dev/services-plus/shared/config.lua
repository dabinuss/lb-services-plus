Config = {}

-- Enables local development helpers such as PeekPlus test commands.
Config.Debug = false

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

-- Maximum number of still-unclaimed requests one phone number may have at
-- the same company. Competition requests share one limit for their category
-- because each such request is distributed to every participating company.
-- Active requests that an employee is already handling do not count.
Config.MaxOpenRequestsPerPhoneNumberPerCompany = 3

-- Services+-owned request notifications trigger LB Phone's native notification
-- peek, then the Sibling-NUI controller keeps that reached visual state for
-- this duration. Set it to 0 to use LB Phone's native duration only. Once a
-- request is accepted, its active card is held until the request ends.
Config.RequestNotificationPeekDuration = 15000
Config.RequestNotificationQueueTtl = 20000

-- Customer-facing tracking for accepted requests. Road distance is calculated
-- independently on the assigned employee's client; it never reads, creates or
-- clears that player's personal GTA waypoint. The server remains authoritative
-- for the assignment and arrival check.
Config.RequestJourneyTracking = {
    enabled = true,
    updateInterval = 15000, -- milliseconds between route-distance samples
    arrivalRadius = 50,     -- metres from the original reported location
    averageSpeedKmh = 35,   -- deliberately coarse ETA, not a traffic prediction
}
