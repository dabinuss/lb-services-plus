--[[
    Registers the "police_emergency" request type - appended to
    Config.DefaultRequestTypes (initialized by shared/categories.lua, which
    must load first - see fxmanifest.lua's shared_scripts) rather than
    declared there directly, so everything this request type owns (this
    file, its dispatch card) lives together under request-types/police_emergency/.
    See shared/categories.lua's own comment for why only type-specific
    request types get their own register.lua like this.
]]

local policeTemplate = {
    ui = "request-types/police_emergency/index.html",
    height = 300,
    fullCard = true,
}

table.insert(Config.DefaultRequestTypes, {
    identifier = "police_emergency", category = "police", name = "Police Emergency",
    description = "Request police assistance.",
    locationMode = "auto", passengerMode = "disabled", noteMode = "optional", competitionEnabled = false,
    templates = {
        pending = policeTemplate,
        active = policeTemplate,
    },
})
