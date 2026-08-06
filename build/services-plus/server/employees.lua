ServicesPlus.Employees = ServicesPlus.Employees or {}

local Employees = ServicesPlus.Employees
local dutyBySource = {}
local companyMembers = {}
local sequence = 0

local function setDutySession(source, employee)
    pcall(function()
        local player = Player(source)
        if not player then return end
        player.state:set("servicesPlusDuty", employee and {
            identifier = employee.identifier,
            companyId = employee.companyId,
            phoneNumber = employee.phoneNumber,
            status = ServicesPlus.Constants.MutableEmployeeStatuses[employee.status] and employee.status or "available"
        } or nil, false)
    end)
end

local function nextSequence()
    sequence = sequence + 1
    return sequence
end

function Employees.CanUseNumber(employee, number)
    if not employee or not number or not number.enabled then return false end
    if number.distribution == "dispatch_only" and not employee.dispatchEnabled then return false end
    if employee.dispatchEnabled then
        return not employee.dispatchNumberSelections or employee.dispatchNumberSelections[number.id] ~= false
    end
    return true
end

function Employees.GetActiveNumberIds(employee)
    local ids = {}
    local company = employee and ServicesPlus.Companies.Get(employee.companyId) or nil
    for _, number in ipairs(company and company.numbers or {}) do
        if Employees.CanUseNumber(employee, number) then ids[#ids + 1] = number.id end
    end
    return ids
end

function Employees.SyncPhoneNumbers(source)
    local employee = dutyBySource[source]
    local company = employee and ServicesPlus.Companies.Get(employee.companyId) or nil
    local numbers = {}
    for _, number in ipairs(company and company.numbers or {}) do
        if employee.status == "available" and number.callsEnabled and Employees.CanUseNumber(employee, number) then
            numbers[#numbers + 1] = { id = number.id, label = number.label, number = number.number }
        end
    end
    TriggerClientEvent("services-plus:client:syncNumbers", source, numbers)
end

local function publicEmployee(employee)
    return {
        source = employee.source,
        name = employee.name,
        role = employee.role,
        grade = employee.grade,
        companyId = employee.companyId,
        status = employee.status,
        dispatchEnabled = employee.dispatchEnabled,
        dispatchForced = employee.dispatchForced,
        isLeader = employee.isLeader,
        activeCall = employee.activeCall ~= nil,
        activeRequest = employee.activeRequest ~= nil,
        activeCallId = employee.activeCall,
        activeRequestId = employee.activeRequest,
        activeNumberIds = Employees.GetActiveNumberIds(employee),
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
            local wasDispatch = employee.dispatchEnabled
            employee.dispatchForced = forced
            employee.dispatchEnabled = nextDispatch
            if nextDispatch and not wasDispatch then
                employee.dispatchNumberSelections = {}
            elseif not nextDispatch then
                employee.dispatchNumberSelections = nil
            end
            employee.version = nextSequence()
            sendToCompany(companyId, "employee.updated", publicEmployee(employee))
            Employees.SyncPhoneNumbers(source)
            if ServicesPlus.Calls and ServicesPlus.Calls.RevalidateEmployee then ServicesPlus.Calls.RevalidateEmployee(source) end
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

function Employees.GetByIdentifier(identifier)
    if not identifier then return nil end
    for _, employee in pairs(dutyBySource) do
        if employee.identifier == identifier then return employee end
    end
    return nil
end

function Employees.GetPublicForCompany(companyId)
    local result = {}
    for source in pairs(companyMembers[companyId] or {}) do
        local employee = dutyBySource[source]
        if employee then result[#result + 1] = publicEmployee(employee) end
    end
    table.sort(result, function(a, b)
        if a.isLeader ~= b.isLeader then return a.isLeader end
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)
    return result
end

function Employees.GetIntegrationForCompany(companyId)
    local result = {}
    for source in pairs(companyMembers[companyId] or {}) do
        local employee = dutyBySource[source]
        if employee then
            local public = publicEmployee(employee)
            public.identifier = employee.identifier
            result[#result + 1] = public
        end
    end
    table.sort(result, function(a, b)
        if a.isLeader ~= b.isLeader then return a.isLeader end
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)
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

    local phoneNumber = ServicesPlus.Bridge.GetEquippedPhoneNumber(source)
    if not phoneNumber then return false, "phone_required" end
    local settings = ServicesPlus.Repository.GetEmployeeSettings(player.identifier, company.id)
    local preferred = settings and ServicesPlus.ToBool(settings.dispatch_preference) or false
    local explicitLeader = settings and ServicesPlus.ToBool(settings.explicit_leader) or false
    local employee = {
        source = source,
        identifier = player.identifier,
        name = player.name ~= "" and player.name or GetPlayerName(source),
        role = player.role or ("Grade %d"):format(player.grade or 0),
        grade = tonumber(player.grade) or 0,
        companyId = company.id,
        phoneNumber = phoneNumber,
        status = "available",
        dispatchPreference = preferred,
        dispatchEnabled = preferred,
        dispatchNumberSelections = preferred and {} or nil,
        dispatchForced = false,
        isLeader = ServicesPlus.Bridge.IsLeader(player, company) or explicitLeader,
        explicitLeader = explicitLeader,
        activeCall = nil,
        activeRequest = nil,
        version = nextSequence()
    }
    dutyBySource[source] = employee
    setDutySession(source, employee)
    companyMembers[company.id] = companyMembers[company.id] or {}
    companyMembers[company.id][source] = true
    rebalance(company.id)
    Employees.SyncPhoneNumbers(source)
    sendToCompany(company.id, "employee.updated", publicEmployee(employee))
    if ServicesPlus.Api and ServicesPlus.Api.BroadcastCompany then ServicesPlus.Api.BroadcastCompany(company.id) end
    return true, publicEmployee(employee)
end

function Employees.LeaveDuty(source, reason)
    local employee = dutyBySource[source]
    if not employee then return true end

    if ServicesPlus.Calls then ServicesPlus.Calls.EmployeeLeft(employee) end
    if ServicesPlus.Requests then ServicesPlus.Requests.EmployeeLeft(employee) end

    local companyId = employee.companyId
    dutyBySource[source] = nil
    setDutySession(source, nil)
    if companyMembers[companyId] then companyMembers[companyId][source] = nil end
    nextSequence()
    sendToCompany(companyId, "employee.removed", { companyId = companyId, source = source, reason = reason })
    rebalance(companyId)
    if ServicesPlus.Api and ServicesPlus.Api.BroadcastCompany then ServicesPlus.Api.BroadcastCompany(companyId) end
    return true
end

function Employees.UpdateStatus(source, status)
    local employee = dutyBySource[source]
    if not employee then
        print(("[services-plus] UpdateStatus rejected for source %d: not on duty (target status '%s')"):format(source, tostring(status)))
        return false, "not_on_duty"
    end
    if not ServicesPlus.Constants.MutableEmployeeStatuses[status] then
        print(("[services-plus] UpdateStatus rejected for source %d: '%s' is not a mutable status"):format(source, tostring(status)))
        return false, "invalid_status"
    end
    if employee.status == "busy" then
        print(("[services-plus] UpdateStatus rejected for source %d: currently busy (activeCall=%s activeRequest=%s)"):format(
            source, tostring(employee.activeCall), tostring(employee.activeRequest)))
        return false, "employee_busy"
    end
    employee.status = status
    employee.version = nextSequence()
    setDutySession(source, employee)
    sendToCompany(employee.companyId, "employee.updated", publicEmployee(employee))
    if ServicesPlus.Calls and ServicesPlus.Calls.RevalidateEmployee then ServicesPlus.Calls.RevalidateEmployee(source) end
    Employees.SyncPhoneNumbers(source)
    if ServicesPlus.Api and ServicesPlus.Api.BroadcastCompany then ServicesPlus.Api.BroadcastCompany(employee.companyId) end
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
    employee.dispatchNumberSelections = enabled and {} or nil
    employee.version = nextSequence()
    sendToCompany(employee.companyId, "employee.updated", publicEmployee(employee))
    if ServicesPlus.Calls and ServicesPlus.Calls.RevalidateEmployee then ServicesPlus.Calls.RevalidateEmployee(source) end
    Employees.SyncPhoneNumbers(source)
    if ServicesPlus.Api and ServicesPlus.Api.BroadcastCompany then ServicesPlus.Api.BroadcastCompany(employee.companyId) end
    return true, publicEmployee(employee)
end

function Employees.ToggleDispatchLine(source, numberId, enabled)
    local employee = dutyBySource[source]
    local company = employee and ServicesPlus.Companies.Get(employee.companyId) or nil
    if not employee or not company or type(enabled) ~= "boolean" then return false, "not_on_duty" end
    local number
    for _, candidate in ipairs(company.numbers) do if candidate.id == numberId then number = candidate break end end
    if not number or not number.enabled then return false, "number_unavailable" end
    if not employee.dispatchEnabled then return false, "dispatch_required" end
    employee.dispatchNumberSelections = employee.dispatchNumberSelections or {}
    employee.dispatchNumberSelections[number.id] = enabled
    employee.version = nextSequence()
    sendToCompany(employee.companyId, "employee.updated", publicEmployee(employee))
    if ServicesPlus.Calls then ServicesPlus.Calls.RevalidateEmployee(source) end
    Employees.SyncPhoneNumbers(source)
    if ServicesPlus.Api and ServicesPlus.Api.BroadcastCompany then ServicesPlus.Api.BroadcastCompany(employee.companyId) end
    return true, publicEmployee(employee)
end

function Employees.NumberHasCoverage(companyId, number, requireCalls)
    for source in pairs(companyMembers[companyId] or {}) do
        local employee = dutyBySource[source]
        if employee and Employees.CanUseNumber(employee, number) and (not requireCalls or (number.callsEnabled and employee.status == "available")) then return true end
    end
    return false
end

function Employees.AssignWork(source, kind, workId)
    local employee = dutyBySource[source]
    if not employee or employee.status ~= "available" or employee.activeCall or employee.activeRequest then return false, "employee_unavailable" end
    employee.previousStatus = employee.status
    employee.status = "busy"
    if kind == "call" then employee.activeCall = workId else employee.activeRequest = workId end
    employee.version = nextSequence()
    setDutySession(source, employee)
    sendToCompany(employee.companyId, "employee.updated", publicEmployee(employee))
    return true, publicEmployee(employee)
end

function Employees.ReleaseWorkByIdentifier(identifier, kind, workId)
    for _, employee in pairs(dutyBySource) do
        local activeId = kind == "call" and employee.activeCall or employee.activeRequest
        if employee.identifier == identifier and (workId == nil or tostring(activeId) == tostring(workId)) then
            if kind == "call" then employee.activeCall = nil else employee.activeRequest = nil end
            if not employee.activeCall and not employee.activeRequest then
                employee.status = (employee.previousStatus == "on_break" or employee.previousStatus == "occupied") and employee.previousStatus or "available"
                employee.previousStatus = nil
            end
            employee.version = nextSequence()
            setDutySession(employee.source, employee)
            sendToCompany(employee.companyId, "employee.updated", publicEmployee(employee))
            if ServicesPlus.Calls then ServicesPlus.Calls.ReofferCompany(employee.companyId) end
            return true
        end
    end
    return false
end

function Employees.GetEligible(companyId, dispatchOnly)
    local result = {}
    for source in pairs(companyMembers[companyId] or {}) do
        local employee = dutyBySource[source]
        if employee and employee.status == "available" and not employee.activeCall and not employee.activeRequest
            and (not dispatchOnly or employee.dispatchEnabled) then result[#result + 1] = employee end
    end
    table.sort(result, function(a, b) return a.source < b.source end)
    return result
end

function Employees.GetEligibleForCategory(categoryId)
    local result = {}
    for _, company in ipairs(ServicesPlus.Companies.GetByCategory(categoryId)) do
        for _, employee in ipairs(Employees.GetEligible(company.id, false)) do result[#result + 1] = employee end
    end
    table.sort(result, function(a, b) return a.source < b.source end)
    return result
end

function Employees.ValidateEmployment(source)
    local employee = dutyBySource[source]
    if not employee then return true end
    local player, company = Employees.ResolveEmployment(source)
    local currentPhone = ServicesPlus.Bridge.GetEquippedPhoneNumber(source)
    local invalidReason = (not currentPhone or currentPhone ~= employee.phoneNumber) and "phone_changed" or nil
    if not player or not company or company.id ~= employee.companyId or player.identifier ~= employee.identifier or invalidReason then
        local reason = invalidReason or "employment_changed"
        Employees.LeaveDuty(source, reason)
        TriggerClientEvent("services-plus:client:push", source, {
            type = "session.invalidated",
            version = nextSequence(),
            timestamp = os.time(),
            payload = { reason = reason }
        })
        return false
    end
    local nextLeader = ServicesPlus.Bridge.IsLeader(player, company) or employee.explicitLeader
    local nextRole = player.role or ("Grade %d"):format(player.grade or 0)
    local nextGrade = tonumber(player.grade) or 0
    if employee.isLeader ~= nextLeader or employee.role ~= nextRole or employee.grade ~= nextGrade then
        employee.isLeader = nextLeader
        employee.role = nextRole
        employee.grade = nextGrade
        employee.version = nextSequence()
        sendToCompany(employee.companyId, "employee.updated", publicEmployee(employee))
    end
    return true
end

function Employees.ValidatePhone(source)
    if not dutyBySource[source] then return true end
    return Employees.ValidateEmployment(source)
end

function Employees.ClearAll()
    dutyBySource = {}
    companyMembers = {}
end

function Employees.RestoreOnlineDuty()
    for _, value in ipairs(GetPlayers()) do
        local source = tonumber(value)
        local saved = source and Player(source).state.servicesPlusDuty or nil
        if type(saved) == "table" then
            local player, company = Employees.ResolveEmployment(source)
            local phoneNumber = ServicesPlus.Bridge.GetEquippedPhoneNumber(source)
            if player and company and player.identifier == saved.identifier and company.id == saved.companyId and phoneNumber == saved.phoneNumber then
                local success = Employees.EnterDuty(source)
                if success and ServicesPlus.Constants.MutableEmployeeStatuses[saved.status] then Employees.UpdateStatus(source, saved.status) end
            else
                setDutySession(source, nil)
            end
        end
    end
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
