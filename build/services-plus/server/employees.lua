--[[
    Employee runtime state (plan §20-24, §65). Duty itself stays in
    Framework.GetOnDuty/SetDuty (reuses the framework's own system where one
    exists). Everything here is Services+-only and deliberately short-lived:
    it resets on resource restart / player disconnect and never touches the
    database, matching the "no permanent employee DB next to the framework"
    goal (§56, §65).

    Keyed by `source`, not the framework identifier: this state only ever
    needs to survive the current connection, and re-deriving an identifier
    on playerDropped risks the framework having already torn the player
    down and falling back to a different key than the one it was stored
    under (plan review round 2 §7). `source` needs no lookup at all and is
    guaranteed stable for exactly as long as this state is meaningful.
]]

Employees = {}

-- source -> { status = "available"|"pause"|"busy", hotlines = { [numberId] = true } }
local state = {}

local function ensure(source)
    if not state[source] then
        state[source] = { status = "available", hotlines = {} }
    end
    return state[source]
end

local function mainNumberId(companyId)
    local numbers = Companies.GetNumbers(companyId)
    for i = 1, #numbers do
        if numbers[i].is_main == 1 then return numbers[i].id end
    end
    return nil
end

local function onDutyCountForJob(job)
    local staff = Framework.GetPlayersByJob(job)
    local count = 0
    for i = 1, #staff do
        if Framework.GetOnDuty(staff[i]) then count = count + 1 end
    end
    return count
end

--- How many on-duty employees of `job` (other than `excludeSource`) have
--- `numberId` *genuinely* stored as active - not the sole-employee virtual
--- force below, the real per-employee flag. Used to stop the main-hotline
--- guarantee from being a paper rule: without this, "at least 2 on duty"
--- alone was treated as "someone's covering it", even when neither of them
--- ever actually turned it on (plan review round 3 §3).
---@param job string
---@param numberId number
---@param excludeSource? number
---@return number
local function realHolderCount(job, numberId, excludeSource)
    local staff = Framework.GetPlayersByJob(job)
    local count = 0

    for i = 1, #staff do
        local s = staff[i]
        if s ~= excludeSource and Framework.GetOnDuty(s) and state[s] and state[s].hotlines[numberId] == true then
            count = count + 1
        end
    end

    return count
end

---@param source number
---@return "available"|"pause"|"busy"
function Employees.GetStatus(source)
    return ensure(source).status
end

---@param source number
---@param status "available"|"pause"|"busy"
---@return boolean
function Employees.SetStatus(source, status)
    if status ~= "available" and status ~= "pause" and status ~= "busy" then return false end
    ensure(source).status = status
    return true
end

--- Whether `source` currently has `numberId` activated, including the
--- forced-on main-hotline rule (plan §21: auto-active while they're the only
--- one on duty, and cannot be turned off in that case).
---@param source number
---@param companyId number
---@param numberId number
---@param precomputedOnDutyCount? number pass this in when checking many
---  employees of the same job at once (plan review round 2 §5) - without it,
---  each call re-scans that job's whole staff list on its own.
---@return boolean
function Employees.IsHotlineActive(source, companyId, numberId, precomputedOnDutyCount)
    local job = Framework.GetJob(source)

    if job and numberId == mainNumberId(companyId) then
        local onDutyCount = precomputedOnDutyCount or onDutyCountForJob(job.name)
        if onDutyCount <= 1 then return true end
    end

    return ensure(source).hotlines[numberId] == true
end

---@param source number
---@param companyId number
---@return { numberId: number, label: string, active: boolean, locked: boolean }[]
function Employees.GetHotlineOptions(source, companyId)
    local numbers = Companies.GetNumbers(companyId)
    local job = Framework.GetJob(source)
    local onDutyCount = job and onDutyCountForJob(job.name) or 0
    local out = {}

    for i = 1, #numbers do
        local n = numbers[i]
        local active = Employees.IsHotlineActive(source, companyId, n.id, onDutyCount)

        -- Mirrors ToggleHotline's own block condition (plan review round 3
        -- §3) so the UI greys this out whenever turning it off would
        -- actually be rejected, not just in the onDutyCount <= 1 case.
        local locked = n.is_main == 1 and active
            and (onDutyCount <= 1 or realHolderCount(job.name, n.id, source) == 0)

        out[#out + 1] = {
            numberId = n.id,
            label = n.label,
            active = active,
            locked = locked,
        }
    end

    return out
end

---@param source number
---@param numberId number
---@param active boolean
---@return boolean ok, string? reason
function Employees.ToggleHotline(source, numberId, active)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company then return false, "not_employee" end

    -- Employment alone isn't enough - numberId also has to actually belong
    -- to this employee's own company, or a direct RPC call could toggle a
    -- hotline flag for a completely unrelated company's number (plan
    -- review round 4 §11; harmless on its own since nothing reads a
    -- hotline flag outside its owning company's own eligibility checks,
    -- but still unintended access with no reason to allow it).
    local numbers = Companies.GetNumbers(company.id)
    local numberBelongsToCompany = false
    for i = 1, #numbers do
        if numbers[i].id == numberId then
            numberBelongsToCompany = true
            break
        end
    end
    if not numberBelongsToCompany then return false, "not_employee" end

    if not active and numberId == mainNumberId(company.id) then
        -- Blocking this needs more than "someone else happens to be on
        -- duty" (plan review round 3 §3) - it has to be someone who
        -- actually has Main active, or two employees who never touched the
        -- toggle could each turn "the other one must have it" off in turn
        -- and leave zero real dispatchers.
        if onDutyCountForJob(job.name) <= 1 or realHolderCount(job.name, numberId, source) == 0 then
            return false, "sole_employee"
        end
    end

    ensure(source).hotlines[numberId] = active or nil

    return true
end

--- Keeps the sole-employee Main Hotline guarantee (plan §21) a real, stored
--- fact instead of one only computed on demand: whenever exactly one
--- employee of `job` is on duty, their Main flag is materialized as true so
--- it survives the moment a second employee joins (who never had to touch
--- the toggle either) - see ToggleHotline above and IsHotlineActive's own
--- still-virtual force below, which this keeps in sync with (plan review
--- round 3 §3).
---@param job string
function Employees.SyncMainHotline(job)
    local company = Companies.GetByJob(job)
    local mainId = company and mainNumberId(company.id)
    if not mainId then return end

    local staff = Framework.GetPlayersByJob(job)
    local sole, count = nil, 0

    for i = 1, #staff do
        if Framework.GetOnDuty(staff[i]) then
            count = count + 1
            sole = staff[i]
        end
    end

    if count == 1 then
        ensure(sole).hotlines[mainId] = true
    end
end

--- Finds the currently-connected source for a stable identifier, scoped to
--- one job so this stays a lookup over a handful of people instead of a
--- 600-player scan (uses the same job index as everything else). Needed
--- when an event about a request has to reach whichever employee it's
--- assigned to, not just whoever triggered the RPC (plan review round 3 §2).
---@param job string
---@param identifier string
---@return number? source
function Employees.FindSourceByIdentifier(job, identifier)
    local staff = Framework.GetPlayersByJob(job)

    for i = 1, #staff do
        if Framework.GetIdentifier(staff[i]) == identifier then
            return staff[i]
        end
    end

    return nil
end

--- Whether `source` alone is eligible for a call/request on `numberId`: on
--- duty, not paused/busy, and - if required - has that number's hotline
--- active. The single-source version of GetEligible() below, and also what
--- acceptRequest() re-checks against so a direct RPC call can't accept a
--- request the caller was never actually notified about (plan review §9).
---@param source number
---@param companyId number
---@param numberId number
---@param requireHotline? boolean
---@param precomputedOnDutyCount? number see IsHotlineActive
---@return boolean
function Employees.IsEligible(source, companyId, numberId, requireHotline, precomputedOnDutyCount)
    if not Framework.GetOnDuty(source) then return false end

    local status = Employees.GetStatus(source)
    if status == "pause" or status == "busy" then return false end

    return not requireHotline or Employees.IsHotlineActive(source, companyId, numberId, precomputedOnDutyCount)
end

--- Everyone eligible to receive a call/request for a given number.
--- `requireHotline` additionally filters to staff who activated that
--- specific number - always true for secondary numbers (that's the entire
--- point of a hotline), optional for the main number (a "random" main-number
--- call/request should consider everyone on duty, not just whoever ticked
--- the main-hotline box).
---@param companyId number
---@param numberId number
---@param requireHotline? boolean
---@return number[] sources
function Employees.GetEligible(companyId, numberId, requireHotline)
    local company = Companies.GetById(companyId)
    if not company then return {} end

    local staff = Framework.GetPlayersByJob(company.job)

    -- Computed once for the whole job, not once per employee per hotline
    -- check - the old per-call onDutyCountForJob() turned this into an
    -- O(employees^2) pass for a hotline-routed call/request on a big job
    -- (plan review round 2 §5).
    local onDutyCount = 0
    for i = 1, #staff do
        if Framework.GetOnDuty(staff[i]) then onDutyCount = onDutyCount + 1 end
    end

    local eligible = {}
    for i = 1, #staff do
        if Employees.IsEligible(staff[i], companyId, numberId, requireHotline, onDutyCount) then
            eligible[#eligible + 1] = staff[i]
        end
    end

    return eligible
end

---@param companyId number
---@return table[]
function Employees.GetTeam(companyId)
    local company = Companies.GetById(companyId)
    if not company then return {} end

    local staff = Framework.GetPlayersByJob(company.job)
    local numbers = Companies.GetNumbers(companyId)

    local onDutyCount = 0
    for i = 1, #staff do
        if Framework.GetOnDuty(staff[i]) then onDutyCount = onDutyCount + 1 end
    end

    local team = {}

    for i = 1, #staff do
        local source = staff[i]
        if Framework.GetOnDuty(source) then
            local job = Framework.GetJob(source)
            local activeHotlines = {}

            for n = 1, #numbers do
                if Employees.IsHotlineActive(source, companyId, numbers[n].id, onDutyCount) then
                    activeHotlines[#activeHotlines + 1] = numbers[n].label
                end
            end

            team[#team + 1] = {
                name = Framework.GetPlayerName(source),
                grade = job.grade,
                gradeLabel = job.gradeLabel,
                status = Employees.GetStatus(source),
                hotlines = activeHotlines,
                -- Lets colleagues call each other directly from the merged
                -- Home/Team view (plan review UX follow-up) - a plain
                -- native call, not routed through company call handling.
                phoneNumber = Framework.GetPhoneNumber(source),
            }
        end
    end

    table.sort(team, function(a, b) return a.grade > b.grade end)

    return team
end

AddEventHandler("playerDropped", function()
    state[source] = nil
end)

-- Belt-and-suspenders self-heal for the sole-employee Main Hotline
-- guarantee (plan §21, plan review round 3 §3). The toggleDuty callback
-- (see main.lua) materializes it immediately for the common case, but a
-- disconnect while on duty has no equally reliable hook - by the time
-- playerDropped fires, the framework's own player object is often already
-- gone, so there's nothing there to reliably re-derive "which job just
-- lost its only covered dispatcher" from. This closes that gap (and any
-- other missed transition) within at most 30s instead of leaving Main
-- silently uncovered until someone happens to toggle duty again - the
-- same reasoning as the JobIndex self-heal in framework.lua.
CreateThread(function()
    while true do
        Wait(30000)

        local companies = Companies.GetAll()
        for i = 1, #companies do
            Employees.SyncMainHotline(companies[i].job)
        end
    end
end)
