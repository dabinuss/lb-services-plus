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
local typesByIdentifier = {}

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
                (category_id, name, icon, description, location_mode, passenger_count, passenger_mode, count_label, description_enabled, note_mode, competition_enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            categoryId or json.null, t.name,
            t.identifier or t.name:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", ""):sub(1, 100),
            t.description or json.null, t.locationMode or "auto", t.passengerMode ~= "disabled" and 1 or 0,
            t.passengerMode or "disabled", t.countLabel or "Passenger count",
            t.noteMode ~= "disabled" and 1 or 0, t.noteMode or "optional", t.competitionEnabled and 1 or 0,
        })
    end
end

function Requests.Reload()
    local rows = MySQL.query.await("SELECT * FROM phone_services_plus_request_types") or {}

    typesByCategory = {}
    typesById = {}
    typesByIdentifier = {}

    for i = 1, #rows do
        local t = rows[i]
        typesById[t.id] = t
        if t.icon then typesByIdentifier[t.icon:lower()] = t end
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
        if DatabaseBoolean(all[i].enabled) then out[#out + 1] = all[i] end
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
local disconnectCleanupLocks = {} -- requestId -> true while one cleanup owns it
local clearNotifications

local function getDisconnectGraceMinutes()
    local value = tonumber(MySQL.scalar.await(
        "SELECT value FROM phone_services_plus_settings WHERE `key` = 'active_request_disconnect_grace_minutes'"
    )) or 5

    return math.max(1, math.min(60, math.floor(value)))
end

--- Resolves either a numeric request-type id, its technical identifier, or
--- a category key such as "medical". A category key selects the first
--- enabled type deterministically, which keeps integrations independent of
--- database ids while still leaving all routing decisions inside Services+.
---@param reference number|string
---@return table?
function Requests.ResolveType(reference)
    local numericId = tonumber(reference)
    if numericId then return typesById[numericId] end
    if type(reference) ~= "string" then return nil end

    local key = reference:lower()
    local exact = typesByIdentifier[key]
    if exact then return exact end

    local categories = Companies.GetCategories()
    for i = 1, #categories do
        if categories[i].key and categories[i].key:lower() == key then
            local candidates = Requests.GetTypesForCategory(categories[i].id)
            table.sort(candidates, function(a, b) return a.id < b.id end)
            return candidates[1]
        end
    end

    return nil
end

local function cancelExpiredDisconnectedRequests(identifier)
    local graceMinutes = getDisconnectGraceMinutes()
    local sql = [[
        SELECT id, requester_number
        FROM phone_services_plus_requests
        WHERE status = 'active'
          AND employee_disconnected_at IS NOT NULL
          AND TIMESTAMPADD(MINUTE, ?, employee_disconnected_at) <= NOW()
    ]]
    local params = { graceMinutes }

    if identifier then
        sql = sql .. " AND employee_identifier = ?"
        params[#params + 1] = identifier
    end

    local candidates = MySQL.query.await(sql, params) or {}
    local claimed = {}
    local ids = {}

    for i = 1, #candidates do
        local id = tonumber(candidates[i].id)
        if id and not disconnectCleanupLocks[id] then
            disconnectCleanupLocks[id] = true
            claimed[id] = candidates[i]
            ids[#ids + 1] = id
        end
    end

    if #ids == 0 then return end

    local ok, err = pcall(function()
        -- IDs originate from the unsigned integer primary key, so composing
        -- this bounded IN list is safe and avoids one UPDATE per request.
        local idList = table.concat(ids, ",")
        MySQL.update.await(([=[
            UPDATE phone_services_plus_requests
            SET status = 'cancelled', employee_disconnected_at = NULL
            WHERE id IN (%s) AND status = 'active'
              AND employee_disconnected_at IS NOT NULL
              AND TIMESTAMPADD(MINUTE, ?, employee_disconnected_at) <= NOW()
        ]=]):format(idList), { graceMinutes })

        -- Only rows this cleanup changed have both a claimed id and a
        -- cleared disconnect timestamp. A concurrent reconnect/cancel
        -- therefore cannot receive the wrong notification.
        local cancelled = MySQL.query.await(([=[
            SELECT id
            FROM phone_services_plus_requests
            WHERE id IN (%s) AND status = 'cancelled' AND employee_disconnected_at IS NULL
        ]=]):format(idList)) or {}

        local cancelledIds = {}
        for i = 1, #cancelled do
            local row = claimed[tonumber(cancelled[i].id)]
            cancelledIds[#cancelledIds + 1] = tonumber(cancelled[i].id)
            clearNotifications(tonumber(cancelled[i].id))
            if row and row.requester_number then
                pcall(function()
                    exports["lb-phone"]:SendNotification(row.requester_number, {
                        app = Config.App.identifier,
                        title = Config.App.name,
                        content = "Your request was cancelled because the employee became unavailable.",
                    })
                end)
            end
        end

        local publicRequests = Requests.GetMany(cancelledIds)
        for i = 1, #publicRequests do
            TriggerEvent("services-plus:requestCancelled", publicRequests[i])
        end
    end)

    for i = 1, #ids do disconnectCleanupLocks[ids[i]] = nil end
    if not ok then error(err) end
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

    local category = Companies.GetCategory(requestType.category_id)
    local payload = {
        requestId = request.id,
        requestType = requestType.icon,
        typeName = requestType.name,
        typeIcon = requestType.icon,
        category = category and category.key or nil,
        companyName = company.name,
        companyIcon = company.icon,
        passengerCount = request.passengerCount,
        countLabel = requestType.count_label or "Passenger count",
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
clearNotifications = function(requestId, except)
    local entry = notifiedSources[requestId]
    notifiedSources[requestId] = nil
    if not entry then return end

    for i = 1, #entry.sources do
        if entry.sources[i] ~= except then
            TriggerClientEvent("services-plus:client:requestClaimed", entry.sources[i], requestId)
        end
    end
end

local function sanitizeRequestRow(row)
    if not row then return nil end

    local employeeSource = row.company_job and row.employee_identifier
        and Employees.FindSourceByIdentifier(row.company_job, row.employee_identifier) or nil

    return {
        id = row.id,
        type = row.type_identifier,
        typeId = row.request_type_id,
        typeName = row.type_name,
        category = row.category_key,
        categoryId = row.category_id,
        status = row.status,
        company = row.company_id and {
            id = row.company_id,
            job = row.company_job,
            name = row.company_name,
            icon = row.company_icon,
        } or nil,
        requesterNumber = row.requester_number,
        employeeSource = employeeSource,
        position = { x = row.pos_x, y = row.pos_y },
        passengerCount = row.passenger_count,
        countLabel = row.count_label,
        description = row.description,
        createdAt = row.created_at,
        updatedAt = row.updated_at,
    }
end

---@param requestId number
---@return table?
function Requests.Get(requestId)
    local id = tonumber(requestId)
    if not id then return nil end

    return sanitizeRequestRow(MySQL.single.await([[
        SELECT r.id, r.request_type_id, r.company_id, r.requester_number, r.status,
               r.pos_x, r.pos_y, r.passenger_count, r.description, r.created_at, r.updated_at,
               t.icon AS type_identifier, t.name AS type_name, t.category_id, t.count_label,
               category.`key` AS category_key,
               company.job AS company_job, company.name AS company_name, company.icon AS company_icon,
               r.employee_identifier
        FROM phone_services_plus_requests r
        JOIN phone_services_plus_request_types t ON t.id = r.request_type_id
        LEFT JOIN phone_services_plus_categories category ON category.id = t.category_id
        LEFT JOIN phone_services_plus_companies company ON company.id = r.company_id
        WHERE r.id = ?
    ]], { id }))
end

---@param requestIds number[]
---@return table[]
function Requests.GetMany(requestIds)
    local ids = {}
    for i = 1, #(requestIds or {}) do
        local id = tonumber(requestIds[i])
        if id then ids[#ids + 1] = math.floor(id) end
    end
    if #ids == 0 then return {} end

    local rows = MySQL.query.await(([=[
        SELECT r.id, r.request_type_id, r.company_id, r.requester_number, r.status,
               r.pos_x, r.pos_y, r.passenger_count, r.description, r.created_at, r.updated_at,
               t.icon AS type_identifier, t.name AS type_name, t.category_id, t.count_label,
               category.`key` AS category_key,
               company.job AS company_job, company.name AS company_name, company.icon AS company_icon,
               r.employee_identifier
        FROM phone_services_plus_requests r
        JOIN phone_services_plus_request_types t ON t.id = r.request_type_id
        LEFT JOIN phone_services_plus_categories category ON category.id = t.category_id
        LEFT JOIN phone_services_plus_companies company ON company.id = r.company_id
        WHERE r.id IN (%s)
    ]=]):format(table.concat(ids, ","))) or {}

    local requests = {}
    for i = 1, #rows do requests[#requests + 1] = sanitizeRequestRow(rows[i]) end
    return requests
end

local function emitLifecycle(eventName, requestId)
    local request = Requests.Get(requestId)
    if request then TriggerEvent("services-plus:" .. eventName, request) end
    return request
end

local function chooseCompany(requestType, options)
    local requested
    local selectorProvided = false
    if type(options.companyJob) == "string" then
        selectorProvided = true
        requested = Companies.GetByJob(options.companyJob)
    elseif tonumber(options.companyId) then
        selectorProvided = true
        requested = Companies.GetById(tonumber(options.companyId))
    end

    if selectorProvided and not requested then return nil end
    if requested then
        if requested.category_id ~= requestType.category_id
            or not DatabaseBoolean(requested.requests_enabled) then return nil end
        return requested
    end

    local candidates = Companies.GetByCategory(requestType.category_id)
    table.sort(candidates, function(a, b) return a.id < b.id end)

    local fallback
    for i = 1, #candidates do
        if DatabaseBoolean(candidates[i].requests_enabled) then
            fallback = fallback or candidates[i]
            if Companies.IsAvailable(candidates[i].id) then return candidates[i] end
        end
    end
    return fallback
end

--- Single request-creation implementation used by both the Services+ app
--- and public server API.
---@param source number
---@param requestTypeReference number|string
---@param options? table
---@return table|false
function Requests.Create(source, requestTypeReference, options)
    source = tonumber(source)
    options = type(options) == "table" and options or {}
    if not source or GetPlayerName(source) == nil then return false end

    local requestType = Requests.ResolveType(requestTypeReference)
    if not requestType or not DatabaseBoolean(requestType.enabled) then return false end

    local company = chooseCompany(requestType, options)
    if not company then return false end

    local requesterNumber = Framework.GetPhoneNumber(source)
    if not requesterNumber then return false end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)

    local passengerMode = requestType.passenger_mode
        or (DatabaseBoolean(requestType.passenger_count) and "required" or "disabled")
    local finalPassengerCount
    local passengerCount = options.passengerCount
    if passengerMode ~= "disabled" and passengerCount ~= nil and passengerCount ~= "" then
        local count = tonumber(passengerCount)
        if not count or count ~= math.floor(count) or count < 1 or count > Config.MaxPassengerCount then return false end
        finalPassengerCount = count
    elseif passengerMode == "required" then
        return false
    end

    local noteMode = requestType.note_mode
        or (DatabaseBoolean(requestType.description_enabled) and "optional" or "disabled")
    local note = type(options.description) == "string" and options.description:match("^%s*(.-)%s*$") or ""
    if noteMode == "required" and note == "" then return false end
    local finalDescription = noteMode ~= "disabled" and note ~= "" and note:sub(1, 255) or nil

    local category = Companies.GetCategory(requestType.category_id)
    local competition = DatabaseBoolean(requestType.competition_enabled)
        and category ~= nil and DatabaseBoolean(category.competition_allowed)
    local initialCompanyId = competition and json.null or company.id

    local requestId = MySQL.insert.await([[
        INSERT INTO phone_services_plus_requests
            (request_type_id, company_id, requester_number, status, pos_x, pos_y, passenger_count, description)
        VALUES (?, ?, ?, 'open', ?, ?, ?, ?)
    ]], {
        requestType.id, initialCompanyId, requesterNumber, coords.x, coords.y,
        finalPassengerCount or json.null, finalDescription,
    })
    if not requestId then return false end

    local routingRequest = {
        id = requestId,
        description = finalDescription,
        passengerCount = finalPassengerCount,
        x = coords.x,
        y = coords.y,
    }
    local reached = 0
    if competition then
        local companies = Companies.GetByCategory(company.category_id)
        for i = 1, #companies do
            if DatabaseBoolean(companies[i].requests_enabled) then
                reached = reached + distribute(companies[i], requestType, routingRequest)
            end
        end
    else
        reached = distribute(company, requestType, routingRequest)
    end

    local request = emitLifecycle("requestCreated", requestId)
    return { id = requestId, reached = reached > 0, request = request }
end

RegisterCallback("getRequestTypes", function(source, reply, categoryId)
    reply(Requests.GetTypesForCategory(categoryId))
end)

RegisterCallback("createRequest", function(source, reply, companyId, requestTypeId, passengerCount, description)
    reply(Requests.Create(source, requestTypeId, {
        companyId = companyId,
        passengerCount = passengerCount,
        description = description,
    }))
end)

---@param source number
---@param requestId number
---@return table|false
function Requests.Accept(source, requestId)
    source = tonumber(source)
    requestId = tonumber(requestId)
    if not source or not requestId or GetPlayerName(source) == nil then return false end

    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company then return false end

    local request = MySQL.single.await("SELECT * FROM phone_services_plus_requests WHERE id = ?", { requestId })
    local requestType = request and Requests.GetType(request.request_type_id)
    if not request or not requestType then return false end

    -- must already belong to this company, or be an unclaimed competition
    -- request in this company's category
    local allowed = request.company_id == company.id
        or (request.company_id == nil and requestType.category_id == company.category_id)
    if not allowed then return false end

    -- Requests OFF must apply immediately (plan review round 5 §4) - without
    -- this, createRequest already refuses new requests once a company turns
    -- requests off, but an already-open request's id stays valid forever, so
    -- a direct acceptRequest call for it could still go through.
    if not DatabaseBoolean(company.requests_enabled) then return false end

    -- Re-check the exact same eligibility distribute() used (plan review
    -- §9) - duty, pause/busy and hotline can all have changed since the
    -- notification went out, and a direct RPC call must not be able to skip
    -- them just because the client never actually received one.
    local mainNumber = Companies.GetMainNumber(company.id)
    local requireHotline = company.request_routing == "hotline"
    if not mainNumber or not Employees.IsEligible(source, company.id, mainNumber.id, requireHotline) then
        return false
    end

    local identifier = Framework.GetIdentifier(source)

    if acceptLocks[identifier] then return false end
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

        -- Feature hook (server/taxi_pricing.lua) - a no-op unless this
        -- request's type actually has one turned on. Must run after the
        -- accept UPDATE above so its own accepted_at/pickup_distance write
        -- targets a row that's genuinely 'active' under this employee.
        TaxiPricing.OnAccept(requestId, source)

        clearNotifications(requestId, source)

        exports["lb-phone"]:SendNotification(request.requester_number, {
            app = Config.App.identifier,
            title = company.name,
            content = ("%s is on the way."):format(requestType.name),
        })

        local category = Companies.GetCategory(requestType.category_id)
        local activePayload = {
            requestId = requestId,
            requestType = requestType.icon,
            typeName = requestType.name,
            typeIcon = requestType.icon,
            category = category and category.key or nil,
            companyName = company.name,
            companyIcon = company.icon,
            passengerCount = request.passenger_count,
            countLabel = requestType.count_label or "Passenger count",
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

        emitLifecycle("requestAccepted", requestId)

        return activePayload
    end)

    acceptLocks[identifier] = nil

    -- Re-raise past this pcall so callback.lua's own outer pcall logs it and
    -- replies "server_error" exactly like any other callback failure -
    -- nothing here needs its own special-cased error response, just the
    -- guaranteed unlock above.
    if not ok then error(result) end

    return result
end

RegisterCallback("acceptRequest", function(source, reply, requestId)
    reply(Requests.Accept(source, requestId))
end)

---@param source number
---@return table?
function Requests.GetActive(source)
    source = tonumber(source)
    if not source or GetPlayerName(source) == nil then return nil end

    local identifier = Framework.GetIdentifier(source)
    cancelExpiredDisconnectedRequests(identifier)

    MySQL.update.await([[
        UPDATE phone_services_plus_requests
        SET employee_disconnected_at = NULL
        WHERE employee_identifier = ? AND status = 'active'
    ]], { identifier })

    local requestId = MySQL.scalar.await([[
        SELECT id FROM phone_services_plus_requests
        WHERE employee_identifier = ? AND status = 'active'
        ORDER BY updated_at DESC LIMIT 1
    ]], { identifier })

    if requestId then
        activeAssignments[source] = { identifier = identifier, requestId = requestId }
        return Requests.Get(requestId)
    end

    activeAssignments[source] = nil
    return nil
end

local function toOverlayPayload(request)
    if not request then return nil end
    return {
        requestId = request.id,
        requestType = request.type,
        typeName = request.typeName,
        typeIcon = request.type,
        category = request.category,
        companyName = request.company and request.company.name or nil,
        companyIcon = request.company and request.company.icon or nil,
        passengerCount = request.passengerCount,
        countLabel = request.countLabel or "Passenger count",
        description = request.description,
        x = request.position.x,
        y = request.position.y,
    }
end

---@param requestId number
---@param actorSource? number nil allows the trusted server export to complete any active request
---@return table|false
function Requests.Complete(requestId, actorSource)
    local id = tonumber(requestId)
    if not id then return false end

    local before = Requests.Get(id)
    if not before or before.status ~= "active" then return false end

    local sql = "UPDATE phone_services_plus_requests SET status = 'completed', employee_disconnected_at = NULL WHERE id = ? AND status = 'active'"
    local params = { id }
    if actorSource then
        sql = sql .. " AND employee_identifier = ?"
        params[#params + 1] = Framework.GetIdentifier(actorSource)
    end

    if MySQL.update.await(sql, params) == 0 then return false end

    -- Feature hook (server/taxi_pricing.lua) - a no-op unless this
    -- request's type actually has one turned on. Runs before the customer
    -- notification below so a priced request can mention what it cost.
    TaxiPricing.OnComplete(id)

    if before.employeeSource then
        activeAssignments[before.employeeSource] = nil
        TriggerClientEvent("services-plus:client:requestEnded", before.employeeSource, id)
    end
    if actorSource and actorSource ~= before.employeeSource then
        activeAssignments[actorSource] = nil
        TriggerClientEvent("services-plus:client:requestEnded", actorSource, id)
    end

    if before.requesterNumber then
        local content = "Your request has been completed. Thank you."
        local rawFeatureData = MySQL.scalar.await(
            "SELECT feature_data FROM phone_services_plus_requests WHERE id = ?", { id }
        )
        if type(rawFeatureData) == "string" then
            local ok, decoded = pcall(json.decode, rawFeatureData)
            if ok and type(decoded) == "table" and type(decoded.amount) == "number" then
                content = ("Your request has been completed. Total: $%.2f. Thank you."):format(decoded.amount)
            end
        end

        pcall(function()
            exports["lb-phone"]:SendNotification(before.requesterNumber, {
                app = Config.App.identifier,
                title = before.company and before.company.name or Config.App.name,
                content = content,
            })
        end)
    end

    return emitLifecycle("requestCompleted", id) or false
end

---@param requestId number
---@param actorSource? number nil allows the trusted server export to cancel any open/active request
---@return table|false
function Requests.Cancel(requestId, actorSource)
    local id = tonumber(requestId)
    if not id then return false end

    local before = Requests.Get(id)
    if not before or (before.status ~= "open" and before.status ~= "active") then return false end

    local sql = "UPDATE phone_services_plus_requests SET status = 'cancelled', employee_disconnected_at = NULL WHERE id = ? AND status IN ('open', 'active')"
    local params = { id }
    if actorSource then
        sql = sql .. " AND (requester_number = ? OR employee_identifier = ?)"
        params[#params + 1] = Framework.GetPhoneNumber(actorSource) or ""
        params[#params + 1] = Framework.GetIdentifier(actorSource)
    end

    if MySQL.update.await(sql, params) == 0 then return false end

    clearNotifications(id)
    if before.employeeSource then
        activeAssignments[before.employeeSource] = nil
        TriggerClientEvent("services-plus:client:requestEnded", before.employeeSource, id)
    end
    if actorSource and actorSource ~= before.employeeSource then
        TriggerClientEvent("services-plus:client:requestEnded", actorSource, id)
    end

    return emitLifecycle("requestCancelled", id) or false
end

-- Rehydration for the Sibling-NUI overlay (plan review §14): a client
-- resource restart loses `active` from memory even though the request is
-- still 'active' in the database, so the overlay asks for it back on load.
RegisterCallback("getActiveRequest", function(source, reply)
    reply(toOverlayPayload(Requests.GetActive(source)))
end)

RegisterCallback("completeRequest", function(source, reply, requestId)
    reply(Requests.Complete(requestId, source) ~= false)
end)

RegisterCallback("cancelRequest", function(source, reply, requestId)
    reply(Requests.Cancel(requestId, source) ~= false)
end)

RegisterCallback("getCompanyRequests", function(source, reply, page)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company then return reply(false) end

    local identifier = Framework.GetIdentifier(source)

    local rows = MySQL.query.await([[
        SELECT r.id, r.company_id, r.status, r.pos_x AS x, r.pos_y AS y,
               r.passenger_count, r.description, r.created_at, r.feature_data,
               t.name AS type_name, t.icon AS type_icon, t.count_label,
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
        rows[i].is_mine = DatabaseBoolean(rows[i].is_mine)
        -- Decoded here, not left as a JSON string, so the UI never has to
        -- parse it - same convention as every other reply field.
        if type(rows[i].feature_data) == "string" then
            local ok, decoded = pcall(json.decode, rows[i].feature_data)
            rows[i].feature_data = ok and decoded or nil
        else
            rows[i].feature_data = nil
        end
    end

    reply(rows)
end)

RegisterCallback("getMyRequests", function(source, reply, page)
    local number = Framework.GetPhoneNumber(source)
    if not number then return reply({}) end

    local rows = MySQL.query.await([[
        SELECT r.id, r.status, r.created_at, r.description, r.passenger_count,
               t.name AS type_name, t.icon AS type_icon, t.count_label,
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

        cancelExpiredDisconnectedRequests()
    end
end)

CreateThread(function()
    while true do
        Wait(5 * 60000)

        local expired = MySQL.query.await([[
            SELECT id FROM phone_services_plus_requests
            WHERE status = 'open' AND created_at < NOW() - INTERVAL 30 MINUTE
        ]]) or {}
        local ids = {}
        for i = 1, #expired do
            local id = tonumber(expired[i].id)
            if id then ids[#ids + 1] = id end
        end

        if #ids > 0 then
            local idList = table.concat(ids, ",")
            MySQL.update.await((
                "UPDATE phone_services_plus_requests SET status = 'cancelled' " ..
                "WHERE status = 'open' AND created_at < NOW() - INTERVAL 30 MINUTE AND id IN (%s)"
            ):format(idList))

            local requests = Requests.GetMany(ids)
            for i = 1, #requests do
                if requests[i].status == "cancelled" then
                    clearNotifications(requests[i].id)
                    TriggerEvent("services-plus:requestExpired", requests[i])
                    TriggerEvent("services-plus:requestCancelled", requests[i])
                end
            end
        end
    end
end)
