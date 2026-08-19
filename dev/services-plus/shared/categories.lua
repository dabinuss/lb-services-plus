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
-- `height` is a CEILING, not a fixed size: a fullCard dispatch template (see
-- request-types/_shared/dispatch.js) measures its own natural content
-- height and reports it to overlay.js, which sizes the real iframe to
-- match - the card is only ever as tall as it needs to be, up to this
-- value. Keep it under Config.PeekPlus.maxTemplateHeight (peekplus/shared/
-- config.lua) and the closed-phone peek's own 20rem/320px cap. This applies
-- to any request type that registers a `templates` block, wherever it does
-- so - see the comment below.
--
-- Only request types with nothing type-specific to own (no custom card, no
-- feature module) are declared here directly. A type with its own UI card
-- and/or server-side feature lives entirely under its own
-- request-types/<identifier>/ folder instead - see request-types/taxi/ for
-- the fullest example (index.html/css/js card + server.lua feature module +
-- register.lua, which is what actually appends that type to
-- Config.DefaultRequestTypes below, loaded right after this file - see
-- fxmanifest.lua's shared_scripts). request-types/_shared/ holds only what
-- every full-card template needs (the dispatch card design system), never
-- anything type-specific.
Config.DefaultRequestTypes = {
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
        identifier = "breaking_news", category = "news", name = "Breaking News",
        description = "Report breaking news at your current location.",
        locationMode = "auto", passengerMode = "disabled", noteMode = "disabled", competitionEnabled = false,
    },
}

-- Notification templates belong to a concrete request type, never to a
-- category. Put templates directly on a default type above (or, for a type
-- with its own folder, in that folder's register.lua). Request types
-- created in the admin/database can declare them here by their technical
-- identifier without becoming seed data. `pending` and `active` are
-- independent; an omitted state uses PeekPlus' standard action template.
Config.RequestTypeTemplates = Config.RequestTypeTemplates or {}

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
