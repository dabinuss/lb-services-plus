--[[
    Registers the "medical_emergency" request type - appended to
    Config.DefaultRequestTypes (initialized by shared/categories.lua, which
    must load first - see fxmanifest.lua's shared_scripts) rather than
    declared there directly, so everything this request type owns (this
    file, its dispatch card) lives together under request-types/medical_emergency/.
    See shared/categories.lua's own comment for why only type-specific
    request types get their own register.lua like this.
]]

local medicalTemplate = {
    ui = "request-types/medical_emergency/index.html",
    height = 300,
    fullCard = true,
}

table.insert(Config.DefaultRequestTypes, {
    identifier = "medical_emergency", category = "medical", name = "Medical Emergency",
    description = "Request medical assistance.",
    locationMode = "auto", passengerMode = "required", countLabel = "Number of injured people",
    -- Was "disabled" - the dispatch card's Notes/situation box needs a
    -- free-text field to show, so callers must be able to write one.
    noteMode = "optional", competitionEnabled = false,
    templates = {
        pending = medicalTemplate,
        active = medicalTemplate,
    },
})
