--[[
    Employee runtime state (plan §20-24, §65). Duty itself stays in
    Framework.GetOnDuty/SetDuty (reuses the framework's own system where one
    exists). Everything here is Services+-only and deliberately short-lived:
    it resets on resource restart / player disconnect and never touches the
    database, matching the "no permanent employee DB next to the framework"
    goal (§56, §65).
]]

Employees = {}

-- identifier -> { status = "available"|"pause"|"busy", hotlines = { [numberId] = true } }
local state = {}

local function ensure(identifier)
    if not state[identifier] then
        state[identifier] = { status = "available", hotlines = {} }
    end
    return state[identifier]
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

---@param source number
---@return "available"|"pause"|"busy"
function Employees.GetStatus(source)
    return ensure(Framework.GetIdentifier(source)).status
end

---@param source number
---@param status "available"|"pause"|"busy"
---@return boolean
function Employees.SetStatus(source, status)
    if status ~= "available" and status ~= "pause" and status ~= "busy" then return false end
    ensure(Framework.GetIdentifier(source)).status = status
    return true
end

--- Whether `source` currently has `numberId` activated, including the
--- forced-on main-hotline rule (plan §21: auto-active while they're the only
--- one on duty, and cannot be turned off in that case).
---@param source number
---@param companyId number
---@param numberId number
---@return boolean
function Employees.IsHotlineActive(source, companyId, numberId)
    local job = Framework.GetJob(source)
    if job and numberId == mainNumberId(companyId) and onDutyCountForJob(job.name) <= 1 then
        return true
    end

    return ensure(Framework.GetIdentifier(source)).hotlines[numberId] == true
end

---@param source number
---@param companyId number
---@return { numberId: number, label: string, active: boolean, locked: boolean }[]
function Employees.GetHotlineOptions(source, companyId)
    local numbers = Companies.GetNumbers(companyId)
    local out = {}

    for i = 1, #numbers do
        local n = numbers[i]
        local active = Employees.IsHotlineActive(source, companyId, n.id)

        out[#out + 1] = {
            numberId = n.id,
            label = n.label,
            active = active,
            locked = n.is_main == 1 and active and (function()
                local job = Framework.GetJob(source)
                return job ~= nil and onDutyCountForJob(job.name) <= 1
            end)(),
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

    if not active and numberId == mainNumberId(company.id) and onDutyCountForJob(job.name) <= 1 then
        return false, "sole_employee"
    end

    ensure(Framework.GetIdentifier(source)).hotlines[numberId] = active or nil

    return true
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
---@return boolean
function Employees.IsEligible(source, companyId, numberId, requireHotline)
    if not Framework.GetOnDuty(source) then return false end

    local status = Employees.GetStatus(source)
    if status == "pause" or status == "busy" then return false end

    return not requireHotline or Employees.IsHotlineActive(source, companyId, numberId)
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
    local eligible = {}

    for i = 1, #staff do
        if Employees.IsEligible(staff[i], companyId, numberId, requireHotline) then
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
    local team = {}

    for i = 1, #staff do
        local source = staff[i]
        if Framework.GetOnDuty(source) then
            local job = Framework.GetJob(source)
            local activeHotlines = {}

            for n = 1, #numbers do
                if Employees.IsHotlineActive(source, companyId, numbers[n].id) then
                    activeHotlines[#activeHotlines + 1] = numbers[n].label
                end
            end

            team[#team + 1] = {
                name = Framework.GetPlayerName(source),
                grade = job.grade,
                gradeLabel = job.gradeLabel,
                status = Employees.GetStatus(source),
                hotlines = activeHotlines,
            }
        end
    end

    table.sort(team, function(a, b) return a.grade > b.grade end)

    return team
end

AddEventHandler("playerDropped", function()
    state[Framework.GetIdentifier(source)] = nil
end)
