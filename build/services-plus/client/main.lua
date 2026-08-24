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

-- Same relay pattern, for a colleague's status/hotline change (plan review
-- round 5 §8) - keeps the Team view in sync without polling.
RegisterNetEvent("services-plus:client:employeeStateChanged", function(payload)
    exports["lb-phone"]:SendCustomAppMessage(Config.App.identifier, {
        type = "employeeStateChanged",
        member = payload,
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
-- right after the player's own setStatus/toggleDuty action, on bootstrap,
-- or from an authoritative server push after an external duty/job change.
--
-- Trade-off worth knowing: ToggleCompanyCalls is global per player, not
-- scoped to a single job/company - a player also employed at a *native*
-- lb-phone company will have its calls paused too while Busy/Pause/off-duty
-- here. There is no finer-grained native hook to avoid that.
--
-- Persisted via client KVP, not a plain Lua local (plan review round 5 §3):
-- a RAM-only var loses this the moment Services+ itself restarts while a
-- player is still Busy/Pause/off-duty. That used to mean two things went
-- wrong at once - the "nothing captured to restore" comment below applied
-- even though something genuinely had been captured before the restart, and
-- worse, the *next* Busy/Pause transition after that restart would read
-- lb-phone's current (already-suppressed, Services+-set) `false` back via
-- GetCompanyCallsStatus() and store that as if it were the player's own
-- original preference - permanently losing the real one. Client KVPs
-- survive a resource restart (this resource's own, and lb-phone's), so the
-- capture/suppress/restore cycle below now does too.
local PRIOR_CALLS_KVP = "servicesPlusPriorNativeCalls"

---@return boolean? nil = Services+ isn't currently holding calls off
local function getPriorNativeCompanyCalls()
    local raw = GetResourceKvpString(PRIOR_CALLS_KVP)
    if raw == nil then return nil end
    return raw == "true"
end

---@param value boolean the native state to restore once Available again
local function setPriorNativeCompanyCalls(value)
    SetResourceKvp(PRIOR_CALLS_KVP, value and "true" or "false")
end

local function clearPriorNativeCompanyCalls()
    DeleteResourceKvp(PRIOR_CALLS_KVP)
end

---@param result table
local function syncNativeCompanyCalls(result)
    if type(result) ~= "table" then return end

    local shouldReceive = result.loggedIn == true and result.onDuty == true and result.status == "available"
    local shouldRelease = result.release == true

    pcall(function()
        if shouldReceive or shouldRelease then
            local prior = getPriorNativeCompanyCalls()
            if prior ~= nil then
                exports["lb-phone"]:ToggleCompanyCalls(prior)
                clearPriorNativeCompanyCalls()
            end
            -- Nothing captured to restore (e.g. a legacy/missing KVP) -
            -- deliberately left alone rather than guessing `true` (plan
            -- review round 4 §7). An earlier version
            -- forced it on once per bootstrap to self-heal that exact case,
            -- but that just re-introduced the original bug: a player who'd
            -- deliberately left native company calls off, then opened
            -- Services+ available+on-duty after a restart, got them
            -- silently switched back on.
        elseif getPriorNativeCompanyCalls() == nil then
            setPriorNativeCompanyCalls(exports["lb-phone"]:GetCompanyCallsStatus())
            exports["lb-phone"]:ToggleCompanyCalls(false)
        end
    end)
end

-- Framework-side duty/job changes can happen without going through this
-- app's NUI callbacks. The server pushes the resulting employee snapshot so
-- native company calls and an already-open app both follow those external
-- changes immediately, without polling.
RegisterNetEvent("services-plus:client:employeeDutyChanged", function(payload)
    local employee = type(payload) == "table" and payload.employee or nil

    -- Leaving every Services+ company must release a native calls toggle
    -- that may still be held from the old job's Busy/Pause/off-duty state.
    syncNativeCompanyCalls(employee or { release = true })

    exports["lb-phone"]:SendCustomAppMessage(Config.App.identifier, {
        type = "employeeDutyChanged",
        employee = employee or false,
        jobChanged = payload and payload.jobChanged == true,
    })
end)

-- Restore lb-phone before unregistering the app. Client KVPs survive a
-- resource restart, so merely removing the custom app used to leave a
-- Services+-set ToggleCompanyCalls(false) active until a later state change.
AddEventHandler("onResourceStop", function(resource)
    if resource ~= resourceName then return end

    local prior = getPriorNativeCompanyCalls()
    if prior ~= nil then
        local restored = pcall(function()
            exports["lb-phone"]:ToggleCompanyCalls(prior)
        end)
        if restored then clearPriorNativeCompanyCalls() end
    end

    pcall(function() exports["lb-phone"]:RemoveCustomApp(Config.App.identifier) end)
end)

RegisterNUICallback("bootstrap", function(_, cb)
    local result = bridge("bootstrap")
    if result and result.employee then syncNativeCompanyCalls(result.employee) end
    cb(result)
end)

RegisterNUICallback("companyLogin", function(data, cb)
    local result = bridge("companyLogin", data.companyId)
    if result and result.employee then syncNativeCompanyCalls(result.employee) end
    cb(result)
end)

-- A boss changing company/number capabilities updates every currently-open
-- Services directory. Otherwise stale clients can still offer a Message
-- button until the app is reopened, even though the server already rejects
-- the action.
RegisterNetEvent("services-plus:client:companiesChanged", function(payload)
    exports["lb-phone"]:SendCustomAppMessage(Config.App.identifier, {
        type = "companiesChanged",
        companies = payload and payload.companies or {},
    })
end)

RegisterNUICallback("companyLogout", function(_, cb)
    local result = bridge("companyLogout")
    syncNativeCompanyCalls(result)
    cb(result and result.ok == true)
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
    cb(bridge("getMessages", data.channelId, data.beforeId))
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

RegisterNUICallback("getTeam", function(data, cb)
    cb(bridge("getTeam", data and data.companyId))
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

RegisterNUICallback("setLocale", function(data, cb)
    cb(bridge("setLocale", data.locale))
end)

RegisterNUICallback("markRead", function(data, cb)
    cb(bridge("markRead", data.scope))
end)

RegisterNUICallback("markConversationRead", function(data, cb)
    cb(bridge("markConversationRead", data.channelId))
end)

local function relayRequestQueueChanged(requestId, status, unreadDelta)
    exports["lb-phone"]:SendCustomAppMessage(Config.App.identifier, {
        type = "requestQueueChanged",
        requestId = tonumber(requestId),
        status = status,
        unreadDelta = unreadDelta or 0,
    })
end

-- These events are already consumed by the PeekPlus request overlay. A
-- second listener keeps the app's queue and badge synchronized even when a
-- colleague acts from that overlay while Services+ is open elsewhere.
RegisterNetEvent("services-plus:client:requestClaimed", function(requestId)
    relayRequestQueueChanged(requestId, "active", -1)
end)

RegisterNetEvent("services-plus:client:requestAccepted", function(payload)
    relayRequestQueueChanged(payload and payload.requestId, "active", -1)
end)

RegisterNetEvent("services-plus:client:requestEnded", function(requestId)
    relayRequestQueueChanged(requestId)
end)

RegisterNetEvent("services-plus:client:requestUpdated", function(payload)
    exports["lb-phone"]:SendCustomAppMessage(Config.App.identifier, {
        type = "requestUpdated",
        request = payload,
    })
end)

-- The PeekPlus request card is handled by client/services/requests.lua.
-- Relay the same arrival to the app as a small realtime delta so the
-- Company/Requests badges and an already-open request list stay current.
RegisterNetEvent("services-plus:client:requestNotification", function(payload)
    exports["lb-phone"]:SendCustomAppMessage(Config.App.identifier, {
        type = "newRequest",
        request = payload,
    })
end)

RegisterNUICallback("getTaxiPricingSettings", function(_, cb)
    cb(bridge("getTaxiPricingSettings"))
end)

RegisterNUICallback("updateTaxiPricingSettings", function(data, cb)
    cb(bridge("updateTaxiPricingSettings", data.requestTypeId, data.settings))
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
    "admin:getServiceSettings", "admin:updateServiceSettings",
    "admin:getCategories", "admin:createCategory", "admin:updateCategory", "admin:deleteCategory",
    "admin:getCompanies", "admin:createCompany", "admin:updateCompany", "admin:deleteCompany",
    "admin:setCompanyCeiling", "admin:assignBoss",
    "admin:createNumber", "admin:updateNumber", "admin:deleteNumber", "admin:enableNumber",
    "admin:getRequestTypes", "admin:createRequestType", "admin:updateRequestType", "admin:deleteRequestType",
}

for i = 1, #ADMIN_ACTIONS do
    local action = ADMIN_ACTIONS[i]
    RegisterNUICallback(action, function(data, cb)
        cb(bridge(action, data))
    end)
end
