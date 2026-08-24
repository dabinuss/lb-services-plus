--[[
    Registers the "taxi" request type - appended to Config.DefaultRequestTypes
    (initialized by shared/categories.lua, which must load first - see
    fxmanifest.lua's shared_scripts) rather than declared there directly, so
    everything this request type owns (this file, its dispatch card, its
    server-side Taxameter feature module) lives together under
    request-types/taxi/. See shared/categories.lua's own comment for why
    only type-specific request types get their own register.lua like this.
]]

local taxiTemplate = {
    ui = "request-types/taxi/index.html",
    height = 300,
    fullCard = true,
}

table.insert(Config.DefaultRequestTypes, {
    identifier = "taxi", category = "taxi", name = "Taxi Pickup",
    description = "Request a ride from your current location.",
    locationMode = "auto", passengerMode = "required", noteMode = "optional", competitionEnabled = true,
    templates = {
        pending = taxiTemplate,
        active = taxiTemplate,
    },
})

-- Compatibility for databases seeded before the stable `taxi` identifier
-- was introduced and for the bundled development fixture. Explicit server
-- configuration still wins over these defaults.
Config.RequestTypeTemplates.taxi_pickup = Config.RequestTypeTemplates.taxi_pickup
    or { pending = taxiTemplate, active = taxiTemplate }
Config.RequestTypeTemplates.taxi_ride = Config.RequestTypeTemplates.taxi_ride
    or { pending = taxiTemplate, active = taxiTemplate }
