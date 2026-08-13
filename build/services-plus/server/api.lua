--[[
    Stable public server API for integrations. This file deliberately only
    delegates to the owning systems and shapes public return values; request
    routing, persistence, authorization and notifications remain internal.
]]

local function publicCompany(company)
    if not company then return nil end
    return {
        id = company.id,
        job = company.job,
        name = company.name,
        categoryId = company.category_id,
        icon = company.icon,
        background = company.background,
        available = Companies.IsAvailable(company.id),
        callsEnabled = DatabaseBoolean(company.calls_enabled),
        messagesEnabled = DatabaseBoolean(company.messages_enabled),
        requestsEnabled = DatabaseBoolean(company.requests_enabled),
    }
end

exports("CreateRequestForPlayer", function(source, requestType, options)
    return Requests.Create(source, requestType, options)
end)

exports("GetRequest", function(requestId)
    return Requests.Get(requestId)
end)

exports("GetActiveRequest", function(source)
    return Requests.GetActive(source)
end)

exports("CancelRequest", function(requestId)
    return Requests.Cancel(requestId) ~= false
end)

exports("CompleteRequest", function(requestId)
    return Requests.Complete(requestId) ~= false
end)

exports("GetCompany", function(jobName)
    if type(jobName) ~= "string" then return nil end
    return publicCompany(Companies.GetByJob(jobName))
end)

exports("IsCompanyAvailable", function(jobName)
    if type(jobName) ~= "string" then return false end
    local company = Companies.GetByJob(jobName)
    return company ~= nil and Companies.IsAvailable(company.id) or false
end)

exports("GetCompanyNumbers", function(jobName)
    if type(jobName) ~= "string" then return {} end
    local company = Companies.GetByJob(jobName)
    if not company then return {} end

    local rows = Companies.GetNumbers(company.id)
    local numbers = {}
    for i = 1, #rows do
        numbers[#numbers + 1] = {
            id = rows[i].id,
            label = rows[i].label,
            number = rows[i].number,
            isMain = DatabaseBoolean(rows[i].is_main),
            callsEnabled = DatabaseBoolean(rows[i].calls_enabled),
            messagesEnabled = DatabaseBoolean(rows[i].messages_enabled),
        }
    end
    return numbers
end)

exports("GetEmployeeState", function(source)
    source = tonumber(source)
    if not source or GetPlayerName(source) == nil then return nil end
    local job = Framework.GetJob(source)
    if not job or not Companies.GetByJob(job.name) then return nil end

    return {
        status = Employees.GetStatus(source),
        onDuty = Framework.GetOnDuty(source),
    }
end)

exports("SetEmployeeStatus", function(source, status)
    return Employees.UpdateStatus(tonumber(source), status)
end)

exports("SendCompanyMessage", function(companyJob, targetNumber, message)
    return Messages.SendCompanyMessage(companyJob, targetNumber, message) ~= false
end)
