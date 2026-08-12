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
