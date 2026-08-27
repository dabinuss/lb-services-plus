--[[
    Call routing + history (plan §25-29, §38).

    Services+ never places calls itself - it only resolves *who* a call
    should reach, then the client places a completely native lb-phone call
    (createCall). This keeps calling itself 100% native (ringtone, UI,
    answer/decline, everything) instead of reinventing it.

    Practical consequence: a true "ring every eligible employee, first to
    answer wins" group-ring only exists natively for a company's main job
    number (createCall({ company = job }) - this is exactly what lb-phone's
    own native Services app relies on too). So:

    - Main number, routing "all"      -> createCall({ company = job }) (native ring-group)
    - Main number, routing "random"   -> one random on-duty, non-busy employee
    - Main number, routing "hotline"  -> one random employee who activated the main hotline
    - Any secondary number            -> always one random employee who activated that hotline

    Call history is populated passively from lb-phone's own call events, not
    written up front, so it only ever reflects calls that actually happened.
]]

-- customerNumber -> { companyId, numberId, expectedCompany?, expectedNumber?, expires }.
-- Deliberately holds NO database row yet - a call is only ever logged once
-- lb-phone confirms one actually started (see lb-phone:newCall below).
-- Otherwise a modified client could call resolveCall repeatedly and never
-- place the real call, filling the history table with rows for calls that
-- never happened (plan review §5). `expectedCompany`/`expectedNumber` is
-- what the eventual real call must actually match - without it, a player
-- could resolveCall for a taxi and then dial someone else entirely inside
-- the pending window and have THAT call logged as the taxi request
-- (plan review round 2 §1). There is no in-memory callId map anymore
-- (`pendingByCallId` used to be here) - see lb_call_id on the calls table
-- instead, which survives a Services+ restart mid-call (plan review round 2 §2).
local pendingByNumber = {}
local answeredByCallId = {}

local function notifyCallChanged(source, scope, referenceId, unreadDelta)
    if not source or GetPlayerName(source) == nil then return end
    TriggerClientEvent("services-plus:client:callChanged", source, {
        scope = scope,
        unreadDelta = tonumber(unreadDelta) or 0,
        referenceId = referenceId,
    })
end

local function notifyCompanyStaff(callRow, unreadDelta)
    local company = Companies.GetById(callRow.company_id)
    if not company then return end

    local staff = Framework.GetPlayersByJob(company.job)
    for i = 1, #staff do
        if Employees.IsLoggedIn(staff[i], company.id) and Framework.GetOnDuty(staff[i]) then
            notifyCallChanged(staff[i], "company_calls", callRow.id, unreadDelta)
        end
    end
end

local function publishMissedCall(callRow)
    if not callRow or not callRow.id then return end
    local eventKey = ("call:%s:missed"):format(callRow.id)

    if callRow.customer_number
        and Unread.Push("activity_calls", callRow.customer_number, 0, eventKey) then
        notifyCallChanged(ResolvePhoneSource(callRow.customer_number), "activity_calls", callRow.id, 1)
    end

    local company = Companies.GetById(callRow.company_id)
    if not company or not Unread.Push("company_calls", "", company.id, eventKey) then return end
    notifyCompanyStaff(callRow, 1)
end

local function publishAnsweredCall(callRow)
    if not callRow or not callRow.id then return end
    notifyCallChanged(ResolvePhoneSource(callRow.customer_number), "activity_calls", callRow.id, 0)
    notifyCompanyStaff(callRow, 0)
end

---@param companyId number
---@param numberId number
---@return { id: number }[]
local function numberOf(companyId, numberId)
    local numbers = Companies.GetNumbers(companyId)
    for i = 1, #numbers do
        if numbers[i].id == numberId then return numbers[i] end
    end
    return nil
end

---@param source number
---@param reply fun(...)
---@param companyId number
---@param numberId number
RegisterCallback("resolveCall", function(source, reply, companyId, numberId)
    local company = Companies.GetById(companyId)
    local number = company and numberOf(companyId, numberId)

    if not company or not number or not DatabaseBoolean(company.calls_enabled)
        or not DatabaseBoolean(number.calls_enabled) then
        return reply(false)
    end
    if not Companies.IsAvailable(company.id) then return reply(false) end

    local customerNumber = Framework.GetPhoneNumber(source)
    if not customerNumber then return reply(false) end

    -- One in-flight resolve per customer number at a time - also closes the
    -- "call resolveCall in a loop, never actually call" spam vector, on top
    -- of the general rate limit (server/callback.lua).
    local existing = pendingByNumber[customerNumber]
    if existing and existing.expires > GetGameTimer() then
        return reply(false)
    end

    local isMain = DatabaseBoolean(number.is_main)
    local target

    if isMain and company.call_routing == "all" then
        target = { company = company.job }
    else
        local requireHotline = not isMain or company.call_routing == "hotline"
        local eligible = Employees.GetEligible(companyId, numberId, requireHotline)

        if #eligible == 0 then return reply(false) end

        local chosen = eligible[math.random(1, #eligible)]
        local employeeNumber = Framework.GetPhoneNumber(chosen)
        if not employeeNumber then return reply(false) end

        target = { number = employeeNumber, employeeIdentifier = Framework.GetIdentifier(chosen) }
    end

    pendingByNumber[customerNumber] = {
        companyId = companyId,
        numberId = numberId,
        expectedCompany = target.company,
        expectedNumber = target.number,
        employeeIdentifier = target.employeeIdentifier,
        expires = GetGameTimer() + 20000,
    }

    reply(target)
end)

-- ---------------------------------------------------------------------------
-- Passive call logging via lb-phone's own events (see server/calls.lua doc
-- comment above for why Services+ doesn't place calls itself). The history
-- row is only ever created here, once lb-phone confirms a call genuinely
-- started - never speculatively at resolveCall time.
-- ---------------------------------------------------------------------------

AddEventHandler("lb-phone:newCall", function(call)
    local pending = pendingByNumber[call.caller.number]
    if not pending then return end

    -- Must match what resolveCall actually resolved - not just "this
    -- customer number placed *a* call" (plan review round 2 §1).
    local matches = (pending.expectedCompany and call.company == pending.expectedCompany)
        or (pending.expectedNumber and call.callee.number == pending.expectedNumber)
    if not matches then return end

    pendingByNumber[call.caller.number] = nil

    MySQL.insert.await(
        "INSERT INTO phone_services_plus_calls (company_id, number_id, customer_number, employee_identifier, lb_call_id, state) VALUES (?, ?, ?, ?, ?, 'ringing')",
        { pending.companyId, pending.numberId, call.caller.number, pending.employeeIdentifier or json.null, call.callId }
    )
end)

-- callAnswered/callEnded correlate purely via lb_call_id in the database -
-- no in-memory callId map, so a Services+ restart mid-call doesn't strand
-- the row at 'ringing' forever (plan review round 2 §2).

AddEventHandler("lb-phone:callAnswered", function(call)
    local employeeNumber = call.callee and call.callee.number or nil
    local employeeSource = call.callee and tonumber(call.callee.source or call.callee.serverId or call.callee.playerId)
        or ResolvePhoneSource(employeeNumber)
    local employeeIdentifier = employeeSource and Framework.GetIdentifier(employeeSource) or nil

    -- Record synchronously before yielding to MySQL. callEnded can otherwise
    -- run while this UPDATE is still in flight and briefly persist/publish a
    -- false missed call even though lb-phone emitted Answered first.
    answeredByCallId[tostring(call.callId)] = {
        number = employeeNumber,
        identifier = employeeIdentifier,
        expires = GetGameTimer() + (2 * 60 * 60000),
    }
    MySQL.update.await("UPDATE phone_services_plus_calls SET state = 'answered', employee_number = ?, employee_identifier = COALESCE(?, employee_identifier) WHERE lb_call_id = ?", {
        employeeNumber or json.null, employeeIdentifier or json.null, call.callId,
    })
    publishAnsweredCall(MySQL.single.await([[
        SELECT id, company_id, customer_number
        FROM phone_services_plus_calls
        WHERE lb_call_id = ?
    ]], { call.callId }))
end)

AddEventHandler("lb-phone:callEnded", function(call)
    local answered = answeredByCallId[tostring(call.callId)]
    answeredByCallId[tostring(call.callId)] = nil
    -- Only downgrade to 'missed' if it never got marked 'answered' above.
    local affected = MySQL.update.await(
        "UPDATE phone_services_plus_calls SET state = IF(? = 1 OR state = 'answered', 'answered', 'missed'), employee_number = COALESCE(employee_number, ?), employee_identifier = COALESCE(employee_identifier, ?), ended_at = NOW() WHERE lb_call_id = ? AND ended_at IS NULL",
        {
            answered and 1 or 0,
            answered and answered.number or json.null,
            answered and answered.identifier or json.null,
            call.callId,
        }
    )
    if affected == 0 then return end

    local row = MySQL.single.await([[
        SELECT id, company_id, customer_number, state
        FROM phone_services_plus_calls
        WHERE lb_call_id = ?
    ]], { call.callId })
    if row and row.state == "missed" then
        publishMissedCall(row)
    elseif row and row.state == "answered" then
        publishAnsweredCall(row)
    end
end)

-- Resolved-but-never-placed calls (client dropped the app before dialing,
-- or lied about it) would otherwise sit in pendingByNumber forever. No
-- database row exists for these yet, so this is a pure in-memory sweep -
-- not a single query involved (plan review §2's "no DB call in a loop").
CreateThread(function()
    while true do
        Wait(15000)

        local now = GetGameTimer()
        for number, pending in pairs(pendingByNumber) do
            if pending.expires < now then
                pendingByNumber[number] = nil
            end
        end
        for callId, answered in pairs(answeredByCallId) do
            if answered.expires < now then answeredByCallId[callId] = nil end
        end
    end
end)

-- Calls that DID start but never got a matching callEnded (server crash,
-- lb-phone restart mid-call, ...) would otherwise sit at 'ringing' forever.
-- Each conditional UPDATE claims exactly one transition so a concurrent
-- callEnded handler and this cleanup can never both publish the same call.
CreateThread(function()
    while true do
        Wait(10 * 60000)

        local stale = MySQL.query.await([[
            SELECT id, company_id, customer_number
            FROM phone_services_plus_calls
            WHERE state = 'ringing' AND ended_at IS NULL
              AND created_at < NOW() - INTERVAL 1 HOUR
            ORDER BY id
            LIMIT 500
        ]]) or {}
        if #stale > 0 then
            for i = 1, #stale do
                local row = stale[i]
                local affected = MySQL.update.await([[
                    UPDATE phone_services_plus_calls
                    SET state = 'missed', ended_at = NOW()
                    WHERE id = ? AND state = 'ringing' AND ended_at IS NULL
                      AND created_at < NOW() - INTERVAL 1 HOUR
                ]], { row.id })

                if affected == 1 then publishMissedCall(row) end
            end
        end
    end
end)

---@param source number
---@param reply fun(...)
---@param rawCursor table?
RegisterCallback("getCallHistory", function(source, reply, rawCursor)
    local company = Companies.GetForPlayer(source)
    if not company or not Employees.IsLoggedIn(source, company.id) or not Framework.GetOnDuty(source) then return reply(false) end

    local cursor = NormalizeListCursor(rawCursor)
    local query = [[
        SELECT c.id, c.customer_number, c.state, c.created_at,
               UNIX_TIMESTAMP(c.created_at) AS cursor_time, n.label
        FROM phone_services_plus_calls c
        JOIN phone_services_plus_numbers n ON n.id = c.number_id
        WHERE c.company_id = ?
    ]]
    local parameters = { company.id }
    if cursor then
        query = query .. [[
          AND (c.created_at < FROM_UNIXTIME(?) OR (c.created_at = FROM_UNIXTIME(?) AND c.id < ?))
        ]]
        parameters[#parameters + 1] = cursor.time
        parameters[#parameters + 1] = cursor.time
        parameters[#parameters + 1] = cursor.id
    end
    query = query .. [[
        ORDER BY c.created_at DESC, c.id DESC
        LIMIT ?
    ]]
    parameters[#parameters + 1] = Config.PageSize.calls

    local rows = MySQL.query.await(query, parameters)

    reply(rows or {})
end)

---@param source number
---@param reply fun(...)
---@param rawCursor table?
RegisterCallback("getMyCalls", function(source, reply, rawCursor)
    local number = Framework.GetPhoneNumber(source)
    if not number then return reply({}) end

    local cursor = NormalizeListCursor(rawCursor)
    local query = [[
        SELECT c.id, c.state, c.created_at, UNIX_TIMESTAMP(c.created_at) AS cursor_time,
               c.company_id, c.number_id,
               co.name AS company_name, co.icon AS company_icon
        FROM phone_services_plus_calls c
        JOIN phone_services_plus_companies co ON co.id = c.company_id
        WHERE c.customer_number = ?
    ]]
    local parameters = { number }
    if cursor then
        query = query .. [[
          AND (c.created_at < FROM_UNIXTIME(?) OR (c.created_at = FROM_UNIXTIME(?) AND c.id < ?))
        ]]
        parameters[#parameters + 1] = cursor.time
        parameters[#parameters + 1] = cursor.time
        parameters[#parameters + 1] = cursor.id
    end
    query = query .. [[
        ORDER BY c.created_at DESC, c.id DESC
        LIMIT ?
    ]]
    parameters[#parameters + 1] = Config.PageSize.calls

    local rows = MySQL.query.await(query, parameters)

    for i = 1, #(rows or {}) do
        rows[i].company_icon = Companies.NormalizeMediaUrl(rows[i].company_icon)
    end

    reply(rows or {})
end)
