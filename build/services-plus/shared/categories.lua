-- Default categories used to seed the database on first start (see server/main.lua).
-- Once seeded, categories live in the DB and are managed through the future
-- admin area (plan §54) - this table is only a convenience bootstrap, not the
-- source of truth at runtime.
Config.DefaultCategories = {
    { key = "police", name = "Police", icon = "police", sort = 10, competitionAllowed = false },
    { key = "medical", name = "Medical", icon = "medical", sort = 20, competitionAllowed = false },
    { key = "taxi", name = "Taxi", icon = "taxi", sort = 30, competitionAllowed = true },
    { key = "mechanic", name = "Mechanic", icon = "wrench", sort = 40, competitionAllowed = true },
    { key = "towing", name = "Towing", icon = "tow-truck", sort = 50, competitionAllowed = true },
    { key = "government", name = "Government", icon = "bank", sort = 60, competitionAllowed = false },
    { key = "news", name = "News", icon = "news", sort = 70, competitionAllowed = false },
}

-- Default request types (plan §12, §55), seeded once the same way categories
-- are. Managed through the future admin area afterwards, not read again here.
local taxiActiveTemplate = {
    ui = "services/templates/active-request/index.html",
    height = 178,
    fullCard = true,
}

Config.DefaultRequestTypes = {
    {
        identifier = "taxi", category = "taxi", name = "Taxi Pickup",
        description = "Request a ride from your current location.",
        locationMode = "auto", passengerMode = "required", noteMode = "optional", competitionEnabled = true,
        templates = {
            active = taxiActiveTemplate,
        },
    },
    {
        identifier = "vehicle_towing", category = "towing", name = "Vehicle Towing",
        description = "Request a tow for a stranded vehicle.",
        locationMode = "auto", passengerMode = "disabled", noteMode = "optional", competitionEnabled = true,
    },
    {
        identifier = "roadside_assistance", category = "mechanic", name = "Roadside Assistance",
        description = "Request on-site repairs.",
        locationMode = "auto", passengerMode = "disabled", noteMode = "optional", competitionEnabled = true,
    },
    {
        identifier = "police_emergency", category = "police", name = "Police Emergency",
        description = "Request police assistance.",
        locationMode = "auto", passengerMode = "disabled", noteMode = "optional", competitionEnabled = false,
    },
    {
        identifier = "medical_emergency", category = "medical", name = "Medical Emergency",
        description = "Request medical assistance.",
        locationMode = "auto", passengerMode = "required", countLabel = "Number of injured people",
        noteMode = "disabled", competitionEnabled = false,
    },
    {
        identifier = "breaking_news", category = "news", name = "Breaking News",
        description = "Report breaking news at your current location.",
        locationMode = "auto", passengerMode = "disabled", noteMode = "disabled", competitionEnabled = false,
    },
}

-- Notification templates belong to a concrete request type, never to a
-- category. Put templates directly on a default type above. Request types
-- created in the admin/database can declare them here by their technical
-- identifier without becoming seed data. `pending` and `active` are
-- independent; an omitted state uses PeekPlus' standard action template.
Config.RequestTypeTemplates = Config.RequestTypeTemplates or {}

-- Compatibility for databases seeded before the stable `taxi` identifier
-- was introduced and for the bundled development fixture. Explicit server
-- configuration still wins over these defaults.
Config.RequestTypeTemplates.taxi_pickup = Config.RequestTypeTemplates.taxi_pickup
    or { active = taxiActiveTemplate }
Config.RequestTypeTemplates.taxi_ride = Config.RequestTypeTemplates.taxi_ride
    or { active = taxiActiveTemplate }

-- Example:
-- Config.RequestTypeTemplates.medical_emergency = {
--     pending = { ui = "services/request-types/medical_emergency/pending.html", height = 150, fullCard = true },
-- }

-- Optional seed companies for local development. Leave empty on a real server
-- and create companies through the admin area instead (plan §51).
Config.DefaultCompanies = {
    -- {
    --     job = "police",
    --     name = "Los Santos Police Department",
    --     category = "police",
    --     icon = "https://cdn-icons-png.flaticon.com/512/7211/7211100.png",
    --     background = nil,
    --     bossGrade = 4,
    --     mainNumber = "911",
    -- },
}
