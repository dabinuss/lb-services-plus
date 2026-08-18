-- Default categories used to seed the database on first start (see server/main.lua).
-- Once seeded, categories live in the DB and are managed through the future
-- admin area (plan §54) - this table is only a convenience bootstrap, not the
-- source of truth at runtime.
Config.DefaultCategories = {
    { key = "police", name = "Law Enforcement", icon = "police", sort = 10, competitionAllowed = false },
    -- Government is the broad catch-all for anything state-run that isn't
    -- police: mayor's office, city hall, DMV, courts/D.A. and similar.
    { key = "government", name = "Government", icon = "bank", sort = 20, competitionAllowed = false },
    { key = "law", name = "Law Firms & Attorneys", icon = "law", sort = 30, competitionAllowed = false },
    { key = "medical", name = "Medical & Hospitals", icon = "medical", sort = 40, competitionAllowed = false },
    { key = "taxi", name = "Taxi & Transportation", icon = "taxi", sort = 50, competitionAllowed = true },
    { key = "car_dealer", name = "Car Dealerships", icon = "car-dealer", sort = 60, competitionAllowed = false },
    { key = "mechanic", name = "Auto Repair Shops", icon = "wrench", sort = 70, competitionAllowed = true },
    { key = "towing", name = "Towing Services", icon = "tow-truck", sort = 80, competitionAllowed = true },
    { key = "carwash", name = "Car Washes", icon = "car-wash", sort = 90, competitionAllowed = false },
    { key = "restaurant", name = "Restaurants & Dining", icon = "restaurant", sort = 100, competitionAllowed = false },
    { key = "bar", name = "Clubs & Bars", icon = "bar", sort = 110, competitionAllowed = false },
    { key = "barber", name = "Barbershops", icon = "barber", sort = 120, competitionAllowed = false },
    { key = "tattoo", name = "Tattoo & Piercing Parlors", icon = "tattoo", sort = 130, competitionAllowed = false },
    { key = "music", name = "Record Labels", icon = "music", sort = 140, competitionAllowed = false },
    { key = "news", name = "News & Media", icon = "news", sort = 150, competitionAllowed = false },
    { key = "shop", name = "Retail Stores", icon = "shop", sort = 160, competitionAllowed = false },
    { key = "community", name = "Community & Organizations", icon = "people", sort = 170, competitionAllowed = false },
    { key = "funeral", name = "Funeral Homes", icon = "funeral", sort = 180, competitionAllowed = false },
}

-- Default request types (plan §12, §55), seeded once the same way categories
-- are. Managed through the future admin area afterwards, not read again here.
local taxiTemplate = {
    ui = "services/request-types/taxi/index.html",
    height = 214,
    fullCard = true,
}

Config.DefaultRequestTypes = {
    {
        identifier = "taxi", category = "taxi", name = "Taxi Pickup",
        description = "Request a ride from your current location.",
        locationMode = "auto", passengerMode = "required", noteMode = "optional", competitionEnabled = true,
        templates = {
            pending = taxiTemplate,
            active = taxiTemplate,
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
    or { pending = taxiTemplate, active = taxiTemplate }
Config.RequestTypeTemplates.taxi_ride = Config.RequestTypeTemplates.taxi_ride
    or { pending = taxiTemplate, active = taxiTemplate }

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
