--[[
    Request system (plan §11-16, §36). Deliberately small state machine:
    open -> active -> completed | cancelled. The plan's own accept flow
    (§45) goes straight from accept to an active display, so there is no
    separate "accepted" holding state here - it would just be dead UI.

    Distribution reuses the exact same Employees.GetEligible() used for call
    routing (plan §29: "Call Routing und Request Routing werden getrennt
    konfiguriert", not that they need separate machinery). Since requests are
    Services+'s own data (not a native phone call), "all" genuinely can
    notify every eligible employee and let the first successful accept win -
    no native ring-group limitation here, unlike calls.

    "Hotline only" request routing is scoped to the company's *main* hotline
    (request types aren't tied to a specific secondary number the way calls
    are) - only employees who activated it are considered.
]]

Requests = {}

local typesByCategory = {} -- categoryId -> ordered list
local typesById = {}

local function seedIfEmpty()
    local count = MySQL.scalar.await("SELECT COUNT(*) FROM phone_services_plus_request_types")
    if count > 0 or #Config.DefaultRequestTypes == 0 then return end

    for i = 1, #Config.DefaultRequestTypes do
        local t = Config.DefaultRequestTypes[i]
        local categoryId = t.category and MySQL.scalar.await(
            "SELECT id FROM phone_services_plus_categories WHERE `key` = ?", { t.category }
        ) or nil

        MySQL.insert.await([[
            INSERT INTO phone_services_plus_request_types
                (category_id, name, icon, description, location_mode, passenger_count, description_enabled, competition_enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            categoryId or json.null, t.name, t.icon or json.null, t.description or json.null, t.locationMode or "auto",
            t.passengerCount and 1 or 0, t.descriptionEnabled and 1 or 0, t.competitionEnabled and 1 or 0,
        })
    end
end

function Requests.Reload()
    local rows = MySQL.query.await("SELECT * FROM phone_services_plus_request_types") or {}

    typesByCategory = {}
    typesById = {}

    for i = 1, #rows do
        local t = rows[i]
        typesById[t.id] = t
        if t.category_id ~= nil then
            typesByCategory[t.category_id] = typesByCategory[t.category_id] or {}
            table.insert(typesByCategory[t.category_id], t)
        end
    end
end

---@param id number
function Requests.GetType(id)
    return typesById[id]
end

---@param categoryId number
---@return table[]
function Requests.GetTypesForCategory(categoryId)
    if not categoryId then return {} end
    -- typesByCategory holds every row, disabled ones included - GetType(id)
    -- below still needs to resolve those for requests that were already
    -- created before a type got disabled (plan review round 3 §9). This is
    -- the one place that specifically offers types for *new* requests, so
    -- it's the one place that filters them out.
    local all = typesByCategory[categoryId] or {}
    local out = {}

    for i = 1, #all do
        if all[i].enabled == 1 then out[#out + 1] = all[i] end
    end

    return out
end

-- requestId -> { sources, createdAt }. `sources` is who got a Sibling-NUI
-- notification for it, so an accept from any one of them (or from the
-- in-app Requests tab) can tell the others to dismiss theirs (plan §45.3).
-- Ephemeral - cleared once the request leaves 'open', or by the pure-RAM TTL
-- sweep below for requests nobody ever acted on (plan review §2: no DB
-- query per entry, `createdAt` is enough to expire this purely in memory).
local notifiedSources = {}
local OPEN_REQUEST_TTL_MS = 30 * 60000

-- identifier -> true while an acceptRequest for that employee is in flight
-- (plan review round 5 §2). The existing-active SELECT followed by the
-- 'open'-scoped UPDATE stops two concurrent accepts from both winning the
-- *same* request, but not two concurrent accepts for two *different*
-- requests by the *same* employee - both could see "no active request yet"
-- in their SELECT before either UPDATE lands. This scopes "only one accept
-- in flight per employee at a time" instead - released in every return path
-- in acceptRequest below. No queue/transaction needed for this app's scale,
-- and no leak risk from a mid-flight disconnect either: MySQL.await still
-- resumes and completes this coroutine even after the player's gone.
local acceptLocks = {}
-- source -> { identifier, requestId } for accepted/rehydrated requests. The
-- stable identifier is captured while the framework player object still
-- exists, because it may already be gone when playerDropped runs.
local activeAssignments = {}

local function getDisconnectGraceMinutes()
    local value = tonumber(MySQL.scalar.await(
        "SELECT value FROM phone_services_plus_settings WHERE `key` = 'active_request_disconnect_grace_minutes'"
    )) or 5

    return math.max(1, math.min(60, math.floor(value)))
end

--- Notifies every eligible employee for `company`'s request routing mode via
--- the Sibling-NUI request card (plan §42-44) and returns how many were
--- reached.
---@param company table
---@param requestType table
---@param request { id: number, description: string?, passengerCount: number?, x: number, y: number }
---@return number reached
local function distribute(company, requestType, request)
    local mainNumber = Companies.GetMainNumber(company.id)
    if not mainNumber then return 0 end

    local requireHotline = company.request_routing == "hotline"
    local eligible = Employees.GetEligible(company.id, mainNumber.id, requireHotline)

    if #eligible == 0 then return 0 end

    if company.request_routing == "random" then
        eligible = { eligible[math.random(1, #eligible)] }
    end

    local payload = {
        requestId = request.id,
        typeName = requestType.name,
        typeIcon = requestType.icon,
        companyName = company.name,
        companyIcon = company.icon,
        passengerCount = request.passengerCount,
        description = request.description,
        x = request.x,
        y = request.y,
    }

    local entry = notifiedSources[request.id]
    if not entry then
        entry = { sources = {}, createdAt = GetGameTimer() }
        notifiedSources[request.id] = entry
    end

    for i = 1, #eligible do
        TriggerClientEvent("services-plus:client:requestNotification", eligible[i], payload)
        table.insert(entry.sources, eligible[i])
    end

    return #eligible
end

--- Tells everyone who was notified about a request (besides whoever just
--- acted on it) to drop it from their screen, then forgets the tracking.
---@param requestId number
---@param except number? a source to skip (the one who just accepted it)
local function clearNotifications(requestId, except)
    local entry = notifiedSources[requestId]
    notifiedSources[requestId] = nil
    if not entry then return end

    for i = 1, #entry.sources do
        if entry.sources[i] ~= except then
            TriggerClientEvent("services-plus:client:requestClaimed", entry.sources[i], requestId)
        end
    end
end

RegisterCallback("getRequestTypes", function(source, reply, categoryId)
    reply(Requests.GetTypesForCategory(categoryId))
end)

RegisterCallback("createRequest", function(source, reply, companyId, requestTypeId, passengerCount, description)
    local requestType = Requests.GetType(requestTypeId)
    local company = Companies.GetById(companyId)

    -- Requests.GetType() deliberately still resolves soft-deleted types too
    -- (so already-open requests of a since-disabled type keep working) -
    -- but that means it alone doesn't stop a client that still has the old
    -- ID from creating brand new requests of a disabled type via a direct
    -- RPC call (plan review round 4 §1). GetTypesForCategory() already
    -- filters these out for the picker; this is the same filter enforced
    -- at the point that actually matters.
    if not requestType or requestType.enabled ~= 1 or not company or company.requests_enabled ~= 1 then
        return reply(false)
    end
    if requestType.category_id ~= company.category_id then return reply(false) end

    local requesterNumber = Framework.GetPhoneNumber(source)
    if not requesterNumber then return reply(false) end

    local coords = GetEntityCoords(GetPlayerPed(source))

    -- Bounded, whole-number only - a bare tonumber() would accept negative
    -- values, decimals or an absurd count (plan review round 2 §6).
    local finalPassengerCount = nil
    if requestType.passenger_count == 1 then
        local n = tonumber(passengerCount)
        if n and n == math.floor(n) and n >= 1 and n <= Config.MaxPassengerCount then
            finalPassengerCount = n
        else
            -- A required field silently failing validation used to still
            -- create the request, just with SQL NULL where the count
            -- should be (plan review round 3 §6) - a manipulated -5, empty,
            -- or 999999 all went through unnoticed instead of being
            -- rejected outright.
            return reply(false)
        end
    end

    local finalDescription = requestType.description_enabled == 1 and type(description) == "string" and description ~= "" and description:sub(1, 255) or nil

    -- Competition needs both the category and the request type to allow it
    -- (plan §16: configurable at either level).
    local category = Companies.GetCategory(requestType.category_id)
    local competition = requestType.competition_enabled == 1 and category ~= nil and category.competition_allowed == 1
    -- NB: `competition and nil or companyId` would NOT work here - Lua's
    -- and/or idiom always falls through to the third operand when the
    -- second one is nil, regardless of the condition. Needs a real branch.
    -- json.null (not plain nil) for anything that isn't the table's last
    -- field - a bare nil there leaves a hole that breaks positional
    -- parameter binding.
    local initialCompanyId = competition and json.null or companyId

    local requestId = MySQL.insert.await([[
        INSERT INTO phone_services_plus_requests
            (request_type_id, company_id, requester_number, status, pos_x, pos_y, passenger_count, description)
        VALUES (?, ?, ?, 'open', ?, ?, ?, ?)
    ]], {
        requestTypeId, initialCompanyId, requesterNumber, coords.x, coords.y,
        finalPassengerCount or json.null, finalDescription,
    })

    local request = {
        id = requestId, description = finalDescription, passengerCount = finalPassengerCount,
        x = coords.x, y = coords.y,
    }
    local reached = 0

    if competition then
        local companies = Companies.GetByCategory(company.category_id)
        for i = 1, #companies do
            if companies[i].requests_enabled == 1 then
                reached = reached + distribute(companies[i], requestType, request)
            end
        end
    else
        reached = distribute(company, requestType, request)
    end

    reply({ id = requestId, reached = reached > 0 })
end)

RegisterCallback("acceptRequest", function(source, reply, requestId)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company then return reply(false) end

    local request = MySQL.single.await("SELECT * FROM phone_services_plus_requests WHERE id = ?", { requestId })
    local requestType = request and Requests.GetType(request.request_type_id)
    if not request or not requestType then return reply(false) end

    -- must already belong to this company, or be an unclaimed competition
    -- request in this company's category
    local allowed = request.company_id == company.id
        or (request.company_id == nil and requestType.category_id == company.category_id)
    if not allowed then return reply(false) end

    -- Requests OFF must apply immediately (plan review round 5 §4) - without
    -- this, createRequest already refuses new requests once a company turns
    -- requests off, but an already-open request's id stays valid forever, so
    -- a direct acceptRequest call for it could still go through.
    if company.requests_enabled ~= 1 then return reply(false) end

    -- Re-check the exact same eligibility distribute() used (plan review
    -- §9) - duty, pause/busy and hotline can all have changed since the
    -- notification went out, and a direct RPC call must not be able to skip
    -- them just because the client never actually received one.
    local mainNumber = Companies.GetMainNumber(company.id)
    local requireHotline = company.request_routing == "hotline"
    if not mainNumber or not Employees.IsEligible(source, company.id, mainNumber.id, requireHotline) then
        return reply(false)
    end

    local identifier = Framework.GetIdentifier(source)

    if acceptLocks[identifier] then return reply(false) end
    acceptLocks[identifier] = true

    -- Wrapped in its own pcall (plan review round 6 §1) - without this, an
    -- error thrown anywhere below (a dropped MySQL connection, a malformed
    -- row, ...) skipped straight past the plain `acceptLocks[identifier] =
    -- nil` a `finish()` helper used to do, out to callback.lua's own outer
    -- pcall. The lock stayed set forever after that - this employee could
    -- never accept another request until a resource restart. This is the
    -- "finally" that guarantees it always gets released, error or not.
    local ok, result = pcall(function()
        -- One active request per employee at a time (plan review round 4
        -- §4): without this, accepting a second request while the first is
        -- still active just silently buries the first one -
        -- getActiveRequest() only ever returns the newest via LIMIT 1, so
        -- it'd never resurface on the overlay/rehydration even though it's
        -- still sitting there `active`. acceptLocks above (plan review
        -- round 5 §2) is what actually makes this check race-safe against a
        -- second concurrent accept for a *different* request - on its own
        -- this SELECT-then-UPDATE pair wasn't atomic.
        local existingActive = MySQL.scalar.await(
            "SELECT id FROM phone_services_plus_requests WHERE employee_identifier = ? AND status = 'active' LIMIT 1",
            { identifier }
        )
        if existingActive then return false end

        -- Atomic first-accept-wins (plan §15): the WHERE status = 'open'
        -- means only one of any number of concurrent accepts can ever
        -- affect a row.
        local affected = MySQL.update.await(
            "UPDATE phone_services_plus_requests SET status = 'active', company_id = ?, employee_identifier = ?, employee_disconnected_at = NULL WHERE id = ? AND status = 'open'",
            { company.id, identifier, requestId }
        )

        if affected == 0 then return false end

        if GetPlayerName(source) == nil then
            -- The disconnect may land while the awaited accept UPDATE is in
            -- flight. Mark that newly-active row immediately so it cannot
            -- escape the playerDropped handler that already ran.
            MySQL.update.await([[
                UPDATE phone_services_plus_requests
                SET employee_disconnected_at = NOW()
                WHERE id = ? AND status = 'active'
            ]], { requestId })
        else
            activeAssignments[source] = { identifier = identifier, requestId = requestId }
        end

        clearNotifications(requestId, source)

        exports["lb-phone"]:SendNotification(request.requester_number, {
            app = Config.App.name,
            title = company.name,
            content = ("%s is on the way."):format(requestType.name),
        })

        local activePayload = {
            requestId = requestId,
            typeName = requestType.name,
            companyName = company.name,
            companyIcon = company.icon,
            passengerCount = request.passenger_count,
            description = request.description,
            x = request.pos_x,
            y = request.pos_y,
        }

        -- The RPC reply only reaches whichever surface (overlay or the
        -- in-app Requests tab) made this exact call - a separate targeted
        -- event to the winner is what actually keeps the Sibling-NUI
        -- active-request card in sync regardless of where Accept was
        -- pressed (plan review round 2 §4).
        TriggerClientEvent("services-plus:client:requestAccepted", source, activePayload)

        return activePayload
    end)

    acceptLocks[identifier] = nil

    -- Re-raise past this pcall so callback.lua's own outer pcall logs it and
    -- replies "server_error" exactly like any other callback failure -
    -- nothing here needs its own special-cased error response, just the
    -- guaranteed unlock above.
    if not ok then error(result) end

    reply(result)
end)

-- Rehydration for the Sibling-NUI overlay (plan review §14): a client
-- resource restart loses `active` from memory even though the request is
-- still 'active' in the database, so the overlay asks for it back on load.
RegisterCallback("getActiveRequest", function(source, reply)
    local identifier = Framework.GetIdentifier(source)
    local graceMinutes = getDisconnectGraceMinutes()

    -- Expired assignments are cancelled here too, before rehydration. This
    -- matters after a server/resource restart where the periodic cleanup
    -- may not have had its first chance to run yet.
    MySQL.update.await([[
        UPDATE phone_services_plus_requests
        SET status = 'cancelled'
        WHERE employee_identifier = ? AND status = 'active'
          AND employee_disconnected_at IS NOT NULL
          AND TIMESTAMPADD(MINUTE, ?, employee_disconnected_at) <= NOW()
    ]], { identifier, graceMinutes })

    -- Rejoining inside the configured grace period keeps the assignment.
    MySQL.update.await([[
        UPDATE phone_services_plus_requests
        SET employee_disconnected_at = NULL
        WHERE employee_identifier = ? AND status = 'active'
    ]], { identifier })

    local request = MySQL.single.await([[
        SELECT r.id AS requestId, r.pos_x AS x, r.pos_y AS y, r.passenger_count AS passengerCount, r.description,
               t.name AS typeName, c.name AS companyName, c.icon AS companyIcon
        FROM phone_services_plus_requests r
        JOIN phone_services_plus_request_types t ON t.id = r.request_type_id
        LEFT JOIN phone_services_plus_companies c ON c.id = r.company_id
        WHERE r.employee_identifier = ? AND r.status = 'active'
        ORDER BY r.updated_at DESC
        LIMIT 1
    ]], { identifier })

    if request then
        activeAssignments[source] = { identifier = identifier, requestId = request.requestId }
    else
        activeAssignments[source] = nil
    end

    reply(request)
end)

RegisterCallback("completeRequest", function(source, reply, requestId)
    local affected = MySQL.update.await(
        "UPDATE phone_services_plus_requests SET status = 'completed' WHERE id = ? AND employee_identifier = ? AND status = 'active'",
        { requestId, Framework.GetIdentifier(source) }
    )

    -- Whichever surface (overlay or in-app Requests tab) this came from,
    -- push the same event so the Sibling-NUI overlay clears its active card
    -- too regardless of which one Complete was actually pressed on (plan
    -- review round 3 §2, mirrors the requestAccepted pattern above).
    if affected > 0 then
        activeAssignments[source] = nil
        TriggerClientEvent("services-plus:client:requestEnded", source, requestId)
    end

    reply(affected > 0)
end)

RegisterCallback("cancelRequest", function(source, reply, requestId)
    -- Grabbed before the update so a customer-initiated cancel can still
    -- resolve who the request was assigned to (source here is the customer,
    -- not the employee, in that case).
    local row = MySQL.single.await([[
        SELECT r.employee_identifier, c.job AS company_job
        FROM phone_services_plus_requests r
        LEFT JOIN phone_services_plus_companies c ON c.id = r.company_id
        WHERE r.id = ?
    ]], { requestId })

    local affected = MySQL.update.await(
        "UPDATE phone_services_plus_requests SET status = 'cancelled' WHERE id = ? AND status IN ('open', 'active') AND (requester_number = ? OR employee_identifier = ?)",
        { requestId, Framework.GetPhoneNumber(source), Framework.GetIdentifier(source) }
    )

    if affected > 0 then
        clearNotifications(requestId)

        -- The assigned employee's overlay/active card needs clearing even
        -- when a *customer* is the one who cancelled - `source` alone only
        -- covers the employee's own surfaces when they cancel their own
        -- accepted request (plan review round 3 §2).
        if row and row.employee_identifier then
            local employeeSource = row.company_job
                and Employees.FindSourceByIdentifier(row.company_job, row.employee_identifier)

            if employeeSource then
                activeAssignments[employeeSource] = nil
                TriggerClientEvent("services-plus:client:requestEnded", employeeSource, requestId)
            end
        end

        TriggerClientEvent("services-plus:client:requestEnded", source, requestId)
    end

    reply(affected > 0)
end)

RegisterCallback("getCompanyRequests", function(source, reply, page)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company then return reply(false) end

    local identifier = Framework.GetIdentifier(source)

    local rows = MySQL.query.await([[
        SELECT r.id, r.company_id, r.status, r.pos_x AS x, r.pos_y AS y,
               r.passenger_count, r.description, r.created_at,
               t.name AS type_name, t.icon AS type_icon,
               (r.employee_identifier = ?) AS is_mine
        FROM phone_services_plus_requests r
        JOIN phone_services_plus_request_types t ON t.id = r.request_type_id
        WHERE r.company_id = ? OR (r.company_id IS NULL AND t.category_id = ? AND r.status = 'open')
        ORDER BY (r.status = 'open') DESC, r.created_at DESC, r.id DESC
        LIMIT ?, ?
    ]], {
        identifier, company.id, company.category_id,
        ClampPage(page) * Config.PageSize.requests, Config.PageSize.requests,
    })

    rows = rows or {}
    for i = 1, #rows do
        rows[i].is_mine = rows[i].is_mine == 1
    end

    reply(rows)
end)

RegisterCallback("getMyRequests", function(source, reply, page)
    local number = Framework.GetPhoneNumber(source)
    if not number then return reply({}) end

    local rows = MySQL.query.await([[
        SELECT r.id, r.status, r.created_at, r.description, r.passenger_count,
               t.name AS type_name, t.icon AS type_icon,
               c.name AS company_name, c.icon AS company_icon
        FROM phone_services_plus_requests r
        JOIN phone_services_plus_request_types t ON t.id = r.request_type_id
        LEFT JOIN phone_services_plus_companies c ON c.id = r.company_id
        WHERE r.requester_number = ?
        ORDER BY r.created_at DESC, r.id DESC
        LIMIT ?, ?
    ]], { number, ClampPage(page) * Config.PageSize.requests, Config.PageSize.requests })

    reply(rows or {})
end)

-- Belt-and-suspenders alongside the pcall/finally in acceptRequest above
-- (plan review round 6 §1) - that's the guaranteed release path, this is
-- just an extra safety net for a disconnect landing at some exotic moment
-- neither covers. Framework.GetIdentifier(source) this late is best-effort
-- only (the framework's own player object may already be gone by
-- playerDropped, same caveat employees.lua documents) - if it falls back to
-- a "source:N" placeholder instead of the real identifier, this is simply a
-- no-op rather than clearing the wrong lock.
AddEventHandler("playerDropped", function()
    local assignment = activeAssignments[source]
    local identifier = assignment and assignment.identifier or Framework.GetIdentifier(source)

    acceptLocks[identifier] = nil
    activeAssignments[source] = nil

    -- Mark instead of immediately cancelling. The periodic cleanup applies
    -- the admin-configured grace period; getActiveRequest clears this again
    -- when the same character reconnects in time.
    MySQL.update([[
        UPDATE phone_services_plus_requests
        SET employee_disconnected_at = NOW()
        WHERE employee_identifier = ? AND status = 'active'
    ]], { identifier })
end)

CreateThread(function()
    seedIfEmpty()
    Requests.Reload()
end)

-- Safety net for requests nobody ever accepted or cancelled (player went
-- offline, the request type doesn't get picked up, ...). Two independent,
-- constant-cost operations - never a query per tracked request (plan review
-- §2): a pure in-memory sweep over `notifiedSources` to stop tracking and
-- tell clients to dismiss, and one single batched UPDATE to actually expire
-- the stale rows in the database (which also self-heals any request that
-- lost its RAM tracking entirely, e.g. across a resource restart).
CreateThread(function()
    while true do
        Wait(60000)

        local now = GetGameTimer()
        for requestId, entry in pairs(notifiedSources) do
            if now - entry.createdAt > OPEN_REQUEST_TTL_MS then
                clearNotifications(requestId)
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30000)

        local graceMinutes = getDisconnectGraceMinutes()

        MySQL.update.await([[
            UPDATE phone_services_plus_requests
            SET status = 'cancelled'
            WHERE status = 'active'
              AND employee_disconnected_at IS NOT NULL
              AND TIMESTAMPADD(MINUTE, ?, employee_disconnected_at) <= NOW()
        ]], { graceMinutes })
    end
end)

CreateThread(function()
    while true do
        Wait(5 * 60000)

        MySQL.update(
            "UPDATE phone_services_plus_requests SET status = 'cancelled' WHERE status = 'open' AND created_at < NOW() - INTERVAL 30 MINUTE"
        )
    end
end)
