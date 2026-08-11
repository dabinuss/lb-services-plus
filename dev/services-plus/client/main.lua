--[[
    Registers Services+ as an LB-Phone custom app (dynamically, via the
    AddCustomApp export - no files are copied into lb-phone and no line is
    added to its config, per plan §2/§61 and SIBLING-NUI.md's "don't touch
    lb-phone" philosophy) and bridges the app's NUI callbacks to the server.
]]

local resourceName = GetCurrentResourceName()

local function registerApp()
    local added, errorMessage = exports["lb-phone"]:AddCustomApp({
        identifier = Config.App.identifier,

        name = Config.App.name,
        description = Config.App.description,
        developer = Config.App.developer,
        icon = ("https://cfx-nui-%s/ui/dist/icon.svg"):format(resourceName),

        defaultApp = Config.App.defaultApp,
        size = Config.App.size,

        ui = ("%s/ui/dist/index.html"):format(resourceName),
        fixBlur = true, -- our CSS uses rem/em, not px
    })

    if not added then
        print(("^1[services-plus] could not register app: %s^7"):format(errorMessage))
    end
end

CreateThread(function()
    while GetResourceState("lb-phone") ~= "started" do
        Wait(500)
    end

    registerApp()
end)

-- lb-phone forgets dynamically-registered apps across its own restarts.
AddEventHandler("onResourceStart", function(resource)
    if resource == "lb-phone" then
        registerApp()
    end
end)

-- Every handler below just forwards to the matching server RPC (see
-- server/main.lua) and hands the raw result back to the UI. The UI never
-- talks to the server directly - only through these.
local function bridge(action, ...)
    local ok, result = ServerCallback(action, ...)
    return ok and result or false
end

RegisterNUICallback("bootstrap", function(_, cb)
    cb(bridge("bootstrap"))
end)

RegisterNUICallback("companyLogin", function(data, cb)
    cb(bridge("companyLogin", data.companyId))
end)

RegisterNUICallback("toggleDuty", function(data, cb)
    cb(bridge("toggleDuty", data.onDuty))
end)

RegisterNUICallback("openConversation", function(data, cb)
    cb(bridge("openConversation", data.numberId, data.page))
end)

RegisterNUICallback("sendMessage", function(data, cb)
    cb(bridge("sendMessage", data.channelId, data.content))
end)

RegisterNUICallback("getMessages", function(data, cb)
    cb(bridge("getMessages", data.channelId, data.page))
end)

RegisterNUICallback("getActivity", function(data, cb)
    cb(bridge("getActivity", data.page))
end)

RegisterNUICallback("archiveConversation", function(data, cb)
    cb(bridge("archiveConversation", data.channelId))
end)

-- --------------------------------------------------------- calls (phase 2)

RegisterNUICallback("resolveCall", function(data, cb)
    cb(bridge("resolveCall", data.companyId, data.numberId))
end)

RegisterNUICallback("getCallHistory", function(data, cb)
    cb(bridge("getCallHistory", data.page))
end)

RegisterNUICallback("getMyCalls", function(data, cb)
    cb(bridge("getMyCalls", data.page))
end)

-- ------------------------------------------------- employees / team / hotlines

RegisterNUICallback("setStatus", function(data, cb)
    cb(bridge("setStatus", data.status))
end)

RegisterNUICallback("getHotlines", function(_, cb)
    cb(bridge("getHotlines"))
end)

RegisterNUICallback("toggleHotline", function(data, cb)
    cb(bridge("toggleHotline", data.numberId, data.active))
end)

RegisterNUICallback("getTeam", function(_, cb)
    cb(bridge("getTeam"))
end)

RegisterNUICallback("getCompanyConversations", function(data, cb)
    cb(bridge("getCompanyConversations", data.page))
end)

-- ------------------------------------------------------- company settings

RegisterNUICallback("getCompanySettings", function(_, cb)
    cb(bridge("getCompanySettings"))
end)

RegisterNUICallback("updateCompanySettings", function(data, cb)
    cb(bridge("updateCompanySettings", data.settings))
end)

RegisterNUICallback("updateNumberSettings", function(data, cb)
    cb(bridge("updateNumberSettings", data.numberId, data.settings))
end)

-- --------------------------------------------------------------- requests

RegisterNUICallback("getRequestTypes", function(data, cb)
    cb(bridge("getRequestTypes", data.categoryId))
end)

RegisterNUICallback("createRequest", function(data, cb)
    cb(bridge("createRequest", data.companyId, data.requestTypeId, data.passengerCount, data.description))
end)

RegisterNUICallback("acceptRequest", function(data, cb)
    cb(bridge("acceptRequest", data.requestId))
end)

RegisterNUICallback("completeRequest", function(data, cb)
    cb(bridge("completeRequest", data.requestId))
end)

RegisterNUICallback("cancelRequest", function(data, cb)
    cb(bridge("cancelRequest", data.requestId))
end)

RegisterNUICallback("getCompanyRequests", function(data, cb)
    cb(bridge("getCompanyRequests", data.page))
end)

RegisterNUICallback("getMyRequests", function(data, cb)
    cb(bridge("getMyRequests", data.page))
end)

-- Purely client-side: drops a GTA waypoint on an accepted request's location
-- (plan §46 - no custom navigation system, just the native map).
RegisterNUICallback("setWaypoint", function(data, cb)
    if type(data.x) == "number" and type(data.y) == "number" then
        SetNewWaypoint(data.x, data.y)
    end
    cb(true)
end)

-- --------------------------------------------------------- admin (phase 3)
-- Every admin:* server callback takes the NUI payload as a single table, so
-- these all forward it as-is instead of unpacking individual fields.
local ADMIN_ACTIONS = {
    "admin:getCategories", "admin:createCategory", "admin:updateCategory", "admin:deleteCategory",
    "admin:getCompanies", "admin:createCompany", "admin:updateCompany", "admin:deleteCompany",
    "admin:setCompanyCeiling", "admin:assignBoss",
    "admin:createNumber", "admin:deleteNumber",
    "admin:getRequestTypes", "admin:createRequestType", "admin:updateRequestType", "admin:deleteRequestType",
}

for i = 1, #ADMIN_ACTIONS do
    local action = ADMIN_ACTIONS[i]
    RegisterNUICallback(action, function(data, cb)
        cb(bridge(action, data))
    end)
end
