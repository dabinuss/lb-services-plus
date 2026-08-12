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
}

-- Default request types (plan §12, §55), seeded once the same way categories
-- are. Managed through the future admin area afterwards, not read again here.
Config.DefaultRequestTypes = {
    {
        category = "taxi", name = "Taxi Pickup", icon = "taxi",
        description = "Request a ride from your current location.",
        locationMode = "auto", passengerCount = true, descriptionEnabled = true, competitionEnabled = true,
    },
    {
        category = "towing", name = "Vehicle Towing", icon = "tow-truck",
        description = "Request a tow for a stranded vehicle.",
        locationMode = "auto", passengerCount = false, descriptionEnabled = true, competitionEnabled = true,
    },
    {
        category = "mechanic", name = "Roadside Assistance", icon = "wrench",
        description = "Request on-site repairs.",
        locationMode = "auto", passengerCount = false, descriptionEnabled = true, competitionEnabled = true,
    },
    {
        category = "police", name = "Police Emergency", icon = "police",
        description = "Request police assistance.",
        locationMode = "auto", passengerCount = false, descriptionEnabled = true, competitionEnabled = false,
    },
    {
        category = "medical", name = "Medical Emergency", icon = "medical",
        description = "Request medical assistance.",
        locationMode = "auto", passengerCount = false, descriptionEnabled = true, competitionEnabled = false,
    },
}

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
