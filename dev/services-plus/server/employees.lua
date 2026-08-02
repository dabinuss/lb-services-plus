ServicesPlus.Employees = ServicesPlus.Employees or {}

local Employees = ServicesPlus.Employees
local dutyBySource = {}
local companyMembers = {}
local sequence = 0

local function nextSequence()
    sequence = sequence + 1
    return sequence
end

local function publicEmployee(employee)
    return {
        source = employee.source,
        name = employee.name,
        role = employee.role,
        companyId = employee.companyId,
        status = employee.status,
        dispatchEnabled = employee.dispatchEnabled,
        dispatchForced = employee.dispatchForced,
        isLeader = employee.isLeader,
        activeCall = false,
        activeRequest = false,
        version = employee.version
    }
end

function Employees.ToPublic(employee)
    return employee and publicEmployee(employee) or nil
end

local function sendToCompany(companyId, eventType, payload)
    local members = companyMembers[companyId] or {}
    for source in pairs(members) do
        TriggerClientEvent("services-plus:client:push", source, {
            type = eventType,
            version = sequence,
            timestamp = os.time(),
            payload = payload
        })
    end
end

local function rebalance(companyId)
    local members = companyMembers[companyId] or {}
    local count = 0
    local onlyEmployee = nil
    for source in pairs(members) do
        count = count + 1
        onlyEmployee = dutyBySource[source]
    end

    for source in pairs(members) do
        local employee = dutyBySource[source]
        local forced = count == 1 and employee == onlyEmployee
        local nextDispatch = forced or employee.dispatchPreference
        if employee.dispatchForced ~= forced or employee.dispatchEnabled ~= nextDispatch then
            employee.dispatchForced = forced
            employee.dispatchEnabled = nextDispatch
            employee.version = nextSequence()
            sendToCompany(companyId, "employee.updated", publicEmployee(employee))
        end
    end
end

function Employees.CountForCompany(companyId)
    local count = 0
    for _ in pairs(companyMembers[companyId] or {}) do count = count + 1 end
    return count
end

function Employees.Get(source)
    return dutyBySource[source]
end

function Employees.GetPublicForCompany(companyId)
    local result = {}
    for source in pairs(companyMembers[companyId] or {}) do
        local employee = dutyBySource[source]
        if employee then result[#result + 1] = publicEmployee(employee) end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function Employees.ResolveEmployment(source)
    local player = ServicesPlus.Bridge.GetPlayer(source)
    if not player then return nil, nil end
    return player, ServicesPlus.Companies.FindByJob(player.job)
end

function Employees.EnterDuty(source)
    if dutyBySource[source] then return true, publicEmployee(dutyBySource[source]) end
    local player, company = Employees.ResolveEmployment(source)
    if not player or not company then return false, "not_company_employee" end

    local settings = ServicesPlus.Repository.GetEmployeeSettings(player.identifier, company.id)
    local preferred = settings and settings.dispatch_preference == 1 or false
    local employee = {
        source = source,
        identifier = player.identifier,
        name = player.name ~= "" and player.name or GetPlayerName(source),
        role = player.role or ("Grade %d"):format(player.grade or 0),
        companyId = company.id,
        status = "available",
        dispatchPreference = preferred,
        dispatchEnabled = preferred,
        dispatchForced = false,
        isLeader = ServicesPlus.Bridge.IsLeader(player, company) or (settings and settings.explicit_leader == 1),
        explicitLeader = settings and settings.explicit_leader == 1 or false,
        version = nextSequence()
    }
    dutyBySource[source] = employee
    companyMembers[company.id] = companyMembers[company.id] or {}
    companyMembers[company.id][source] = true
    rebalance(company.id)
    sendToCompany(company.id, "employee.updated", publicEmployee(employee))
    if ServicesPlus.Api and ServicesPlus.Api.BroadcastCompany then ServicesPlus.Api.BroadcastCompany(company.id) end
    return true, publicEmployee(employee)
end

function Employees.LeaveDuty(source, reason)
    local employee = dutyBySource[source]
    if not employee then return true end
    if employee.status == "busy" and reason == "logout" then return false, "employee_busy" end

    local companyId = employee.companyId
    dutyBySource[source] = nil
    if companyMembers[companyId] then companyMembers[companyId][source] = nil end
    nextSequence()
    sendToCompany(companyId, "employee.removed", { companyId = companyId, source = source, reason = reason })
    rebalance(companyId)
    if ServicesPlus.Api and ServicesPlus.Api.BroadcastCompany then ServicesPlus.Api.BroadcastCompany(companyId) end
    return true
end

function Employees.UpdateStatus(source, status)
    local employee = dutyBySource[source]
    if not employee then return false, "not_on_duty" end
    if not ServicesPlus.Constants.MutableEmployeeStatuses[status] then return false, "invalid_status" end
    if employee.status == "busy" then return false, "employee_busy" end
    employee.status = status
    employee.version = nextSequence()
    sendToCompany(employee.companyId, "employee.updated", publicEmployee(employee))
    return true, publicEmployee(employee)
end

function Employees.ToggleDispatch(source, enabled)
    local employee = dutyBySource[source]
    if not employee then return false, "not_on_duty" end
    if type(enabled) ~= "boolean" then return false, "invalid_dispatch_value" end
    if employee.dispatchForced and not enabled then return false, "single_employee_dispatch_required" end
    ServicesPlus.Repository.SaveDispatchPreference(employee.identifier, employee.companyId, enabled)
    employee.dispatchPreference = enabled
    employee.dispatchEnabled = enabled
    employee.version = nextSequence()
    sendToCompany(employee.companyId, "employee.updated", publicEmployee(employee))
    return true, publicEmployee(employee)
end

function Employees.ValidateEmployment(source)
    local employee = dutyBySource[source]
    if not employee then return true end
    local player, company = Employees.ResolveEmployment(source)
    if not player or not company or company.id ~= employee.companyId or player.identifier ~= employee.identifier then
        Employees.LeaveDuty(source, "employment_changed")
        TriggerClientEvent("services-plus:client:push", source, {
            type = "session.invalidated",
            version = nextSequence(),
            timestamp = os.time(),
            payload = { reason = "employment_changed" }
        })
        return false
    end
    local nextLeader = ServicesPlus.Bridge.IsLeader(player, company) or employee.explicitLeader
    local nextRole = player.role or ("Grade %d"):format(player.grade or 0)
    if employee.isLeader ~= nextLeader or employee.role ~= nextRole then
        employee.isLeader = nextLeader
        employee.role = nextRole
        employee.version = nextSequence()
        sendToCompany(employee.companyId, "employee.updated", publicEmployee(employee))
    end
    return true
end

function Employees.ClearAll()
    dutyBySource = {}
    companyMembers = {}
end

function Employees.RevalidateCompany(companyId)
    local sources = {}
    for source in pairs(companyMembers[companyId] or {}) do sources[#sources + 1] = source end
    for _, source in ipairs(sources) do Employees.ValidateEmployment(source) end
end

function Employees.RemoveCompany(companyId)
    local sources = {}
    for source in pairs(companyMembers[companyId] or {}) do sources[#sources + 1] = source end
    for _, source in ipairs(sources) do
        Employees.LeaveDuty(source, "company_removed")
        TriggerClientEvent("services-plus:client:push", source, {
            type = "session.invalidated", version = nextSequence(), timestamp = os.time(), payload = { reason = "company_removed" }
        })
    end
end

AddEventHandler("playerDropped", function()
    local droppedSource = source
    Employees.LeaveDuty(droppedSource, "player_dropped")
    ServicesPlus.RateLimiter.Clear(droppedSource)
end)

local function employmentChanged(sourceId)
    SetTimeout(0, function() Employees.ValidateEmployment(tonumber(sourceId) or 0) end)
end

AddEventHandler("esx:setJob", function(playerId) employmentChanged(playerId or source) end)
AddEventHandler("QBCore:Server:OnJobUpdate", function(playerId) employmentChanged(playerId or source) end)
AddEventHandler("qbx_core:server:onJobUpdate", function(playerId) employmentChanged(playerId or source) end)
