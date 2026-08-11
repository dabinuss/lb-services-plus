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

-- Realtime delta for an already-open conversation (plan review §15).
-- SendCustomAppMessage is a client-only export - it always targets the
-- caller's own NUI - so the server just tells this one client to relay it.
RegisterNetEvent("services-plus:client:newMessage", function(payload)
    exports["lb-phone"]:SendCustomAppMessage(Config.App.identifier, {
        type = "newMessage",
        channelId = payload.channelId,
        message = payload,
    })
end)

CreateThread(function()
    while GetResourceState("lb-phone") ~= "started" do
        Wait(500)
    end

    -- lb-phone's own recommendation: give it a moment after reporting
    -- "started" to finish its own boot before registering against it
    -- (plan review round 3 §12).
    Wait(500)
    registerApp()
end)

-- lb-phone forgets dynamically-registered apps across its own restarts.
AddEventHandler("onResourceStart", function(resource)
    if resource == "lb-phone" then
        Wait(500)
        registerApp()
    end
end)

-- Symmetric cleanup (plan review round 3 §12): without this, restarting
-- just services-plus (not lb-phone) leaves a stale AddCustomApp
-- registration behind - lb-phone has no other way to find out this app is
-- gone until its own next restart.
AddEventHandler("onResourceStop", function(resource)
    if resource == resourceName then
        pcall(function() exports["lb-phone"]:RemoveCustomApp(Config.App.identifier) end)
    end
end)

-- Every handler below just forwards to the matching server RPC (see
-- server/main.lua) and hands the raw result back to the UI. The UI never
-- talks to the server directly - only through these.
local function bridge(action, ...)
    local ok, result = ServerCallback(action, ...)
    return ok and result or false
end

-- Keeps lb-phone's own (global, per-player) company-call reception toggle
-- in sync with Services+ duty/status. "All" call routing for a company's
-- main number rings via lb-phone's native company-job call system (see
-- server/calls.lua's doc comment), which has no idea about Services+'s own
-- Busy/Pause state - ToggleCompanyCalls is the only integration point
-- lb-phone exposes for that (plan review round 2 §3). Only ever called
-- right after the player's own setStatus/toggleDuty action (computed from
-- that exact result) or on bootstrap - never speculatively.
--
-- Trade-off worth knowing: ToggleCompanyCalls is global per player, not
-- scoped to a single job/company - a player also employed at a *native*
-- lb-phone company will have its calls paused too while Busy/Pause/off-duty
-- here. There is no finer-grained native hook to avoid that.
--
-- nil = Services+ isn't currently holding calls off. Non-nil = the native
-- state the player actually had *before* Services+ forced it off, to be
-- restored verbatim instead of hard-setting `true` (plan review round 3
-- §10) - lb-phone's toggle is a player preference, not a Services+-owned
-- flag, so a player who deliberately turned company calls off, then went
-- Busy and back Available in Services+, must not have them silently
-- switched back on.
local priorNativeCompanyCalls = nil

-- Only the very first bootstrap after this script started is allowed to
-- fall back to a hard `true` below - later app-opens with nothing left to
-- restore mean the player is simply still available with nothing Services+
-- ever touched, and must not have their own lb-phone toggle overridden
-- just for reopening the app (plan review round 3 §10).
local hasSyncedOnce = false

---@param result table
---@param isBootstrap? boolean
local function syncNativeCompanyCalls(result, isBootstrap)
    if type(result) ~= "table" then return end

    local shouldReceive = result.onDuty == true and result.status == "available"

    pcall(function()
        if shouldReceive then
            if priorNativeCompanyCalls ~= nil then
                exports["lb-phone"]:ToggleCompanyCalls(priorNativeCompanyCalls)
                priorNativeCompanyCalls = nil
            elseif isBootstrap and not hasSyncedOnce then
                -- Nothing to restore on the very first sync - most likely a
                -- fresh client state (a services-plus restart while Busy
                -- left the native toggle off with no memory of what it was
                -- before). Rather than leave calls silently stuck off
                -- forever, resync to the straightforward default once.
                exports["lb-phone"]:ToggleCompanyCalls(true)
            end
        elseif priorNativeCompanyCalls == nil then
            priorNativeCompanyCalls = exports["lb-phone"]:GetCompanyCallsStatus()
            exports["lb-phone"]:ToggleCompanyCalls(false)
        end
    end)

    if isBootstrap then hasSyncedOnce = true end
end

RegisterNUICallback("bootstrap", function(_, cb)
    local result = bridge("bootstrap")
    if result and result.employee then syncNativeCompanyCalls(result.employee, true) end
    cb(result)
end)

RegisterNUICallback("companyLogin", function(data, cb)
    cb(bridge("companyLogin", data.companyId))
end)

RegisterNUICallback("toggleDuty", function(data, cb)
    local result = bridge("toggleDuty", data.onDuty)
    syncNativeCompanyCalls(result)
    cb(result)
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
    local result = bridge("setStatus", data.status)
    syncNativeCompanyCalls(result)
    cb(result)
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
