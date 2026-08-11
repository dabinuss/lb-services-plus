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

-- customerNumber -> { companyId, numberId, expires }. Deliberately holds NO
-- database row yet - a call is only ever logged once lb-phone confirms one
-- actually started (see lb-phone:newCall below). Otherwise a modified client
-- could call resolveCall repeatedly and never place the real call, filling
-- the history table with rows for calls that never happened (plan review §5).
local pendingByNumber = {}
local pendingByCallId = {} -- callId -> historyId, once a row does exist

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

    if not company or not number or company.calls_enabled ~= 1 or number.calls_enabled ~= 1 then
        return reply(false)
    end

    local customerNumber = Framework.GetPhoneNumber(source)
    if not customerNumber then return reply(false) end

    -- One in-flight resolve per customer number at a time - also closes the
    -- "call resolveCall in a loop, never actually call" spam vector, on top
    -- of the general rate limit (server/callback.lua).
    local existing = pendingByNumber[customerNumber]
    if existing and existing.expires > GetGameTimer() then
        return reply(false)
    end

    local isMain = number.is_main == 1
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

        target = { number = employeeNumber }
    end

    pendingByNumber[customerNumber] = { companyId = companyId, numberId = numberId, expires = GetGameTimer() + 20000 }

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

    pendingByNumber[call.caller.number] = nil

    local historyId = MySQL.insert.await(
        "INSERT INTO phone_services_plus_calls (company_id, number_id, customer_number, state) VALUES (?, ?, ?, 'ringing')",
        { pending.companyId, pending.numberId, call.caller.number }
    )

    pendingByCallId[call.callId] = historyId
end)

AddEventHandler("lb-phone:callAnswered", function(call)
    local historyId = pendingByCallId[call.callId]
    if not historyId then return end

    MySQL.update("UPDATE phone_services_plus_calls SET state = 'answered', employee_number = ? WHERE id = ?", {
        call.callee.number or json.null, historyId,
    })
end)

AddEventHandler("lb-phone:callEnded", function(call)
    local historyId = pendingByCallId[call.callId]
    if not historyId then return end

    pendingByCallId[call.callId] = nil

    -- Only downgrade to 'missed' if it never got marked 'answered' above.
    MySQL.update(
        "UPDATE phone_services_plus_calls SET state = IF(state = 'answered', 'answered', 'missed'), ended_at = NOW() WHERE id = ?",
        { historyId }
    )
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
    end
end)

-- Calls that DID start but never got a matching callEnded (server crash,
-- lb-phone restart mid-call, ...) would otherwise sit at 'ringing' forever.
-- One batched UPDATE, not a query per row - and it self-heals even rows
-- pendingByCallId lost track of across a Services+ restart.
CreateThread(function()
    while true do
        Wait(10 * 60000)

        MySQL.update(
            "UPDATE phone_services_plus_calls SET state = 'missed', ended_at = NOW() WHERE state = 'ringing' AND created_at < NOW() - INTERVAL 1 HOUR"
        )
    end
end)

---@param source number
---@param reply fun(...)
---@param page number?
RegisterCallback("getCallHistory", function(source, reply, page)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company then return reply(false) end

    local rows = MySQL.query.await([[
        SELECT c.id, c.customer_number, c.employee_number, c.state, c.created_at, n.label
        FROM phone_services_plus_calls c
        JOIN phone_services_plus_numbers n ON n.id = c.number_id
        WHERE c.company_id = ?
        ORDER BY c.created_at DESC
        LIMIT ?, ?
    ]], { company.id, ClampPage(page) * Config.PageSize.calls, Config.PageSize.calls })

    reply(rows or {})
end)

---@param source number
---@param reply fun(...)
---@param page number?
RegisterCallback("getMyCalls", function(source, reply, page)
    local number = Framework.GetPhoneNumber(source)
    if not number then return reply({}) end

    local rows = MySQL.query.await([[
        SELECT c.id, c.state, c.created_at, co.name AS company_name, co.icon AS company_icon
        FROM phone_services_plus_calls c
        JOIN phone_services_plus_companies co ON co.id = c.company_id
        WHERE c.customer_number = ?
        ORDER BY c.created_at DESC
        LIMIT ?, ?
    ]], { number, ClampPage(page) * Config.PageSize.calls, Config.PageSize.calls })

    reply(rows or {})
end)
