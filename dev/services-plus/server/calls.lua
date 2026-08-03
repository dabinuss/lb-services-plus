ServicesPlus.Calls = ServicesPlus.Calls or {}

local Calls = ServicesPlus.Calls
local runtimeOffers = {}

local function identifiers(employees)
    local result = {}
    for _, employee in ipairs(employees) do result[#result + 1] = employee.identifier end
    return result
end

local function isEligible(employee, company, number)
    if not employee or not number.enabled or not number.callsEnabled or employee.companyId ~= company.id or employee.status ~= "available" or employee.activeCall or employee.activeRequest then return false end
    if not ServicesPlus.Employees.CanUseNumber(employee, number) then return false end
    local mode = number.distribution or company.dispatchMode
    if mode == "dispatch_only" and not employee.dispatchEnabled then return false end
    return true
end

local function selectEmployees(company, number, excluded)
    local mode = number.distribution or company.dispatchMode
    local eligible = ServicesPlus.Employees.GetEligible(company.id, mode == "dispatch_only")
    local filtered = {}
    for _, employee in ipairs(eligible) do if isEligible(employee, company, number) and not (excluded and excluded[employee.identifier]) then filtered[#filtered + 1] = employee end end
    eligible = filtered
    if mode == "random" and #eligible > 1 then
        eligible = { eligible[math.random(1, #eligible)] }
    end
    return eligible
end

local function push(source, eventType, payload)
    TriggerClientEvent("services-plus:client:push", source, { type = eventType, timestamp = os.time(), payload = payload })
end

function Calls.BroadcastQueue(numberId)
    for position, row in ipairs(ServicesPlus.Repository.GetNumberQueue(numberId, Config.MaxQueueBroadcastEntries)) do
        local offer = runtimeOffers[row.call_token]
        if offer and offer.callerSource then
            push(offer.callerSource, "call.queue", { id = row.id, position = position, status = "queued" })
        end
    end
end

function Calls.RegisterIncoming(source, payload)
    local token = type(payload) == "table" and tostring(payload.callToken or "") or ""
    local numberValue = type(payload) == "table" and tostring(payload.number or "") or ""
    if #token < 1 or #token > 96 then return false, "invalid_call" end
    local company, number = ServicesPlus.Companies.FindByNumber(numberValue)
    local employee = ServicesPlus.Employees.Get(source)
    if not company or not number or not employee or employee.companyId ~= company.id then return false, "forbidden" end
    local existing = ServicesPlus.Repository.GetCallQueueByToken(token)
    local selected = selectEmployees(company, number)
    local selectedIds = identifiers(selected)
    local state = #selected > 0 and "offered" or "queued"
    local entry = existing or ServicesPlus.Repository.CreateCallQueue({ callToken = token, companyId = company.id, numberId = number.id, status = state, offeredIdentifiers = selectedIds })
    if not entry then return false, "call_queue_failed" end
    if existing and existing.status == "queued" and #selectedIds > 0 then
        state = "offered"
        ServicesPlus.Repository.UpdateCallOffer(entry.id, state, selectedIds)
    elseif existing then
        state = existing.status
        selectedIds = json.decode(existing.offered_identifiers or "[]") or {}
    else
        ServicesPlus.Repository.UpdateCallOffer(entry.id, state, selectedIds)
    end
    runtimeOffers[token] = runtimeOffers[token] or { declined = {}, sources = {} }
    runtimeOffers[token].sources[source] = true
    local offered = false
    for _, selectedIdentifier in ipairs(selectedIds) do if selectedIdentifier == employee.identifier then offered = true break end end
    if offered then
        push(source, "call.offer", { id = entry.id, callToken = token, companyId = company.id, companyName = company.displayName, numberId = number.id, numberLabel = number.label })
        pcall(function() exports["lb-phone"]:SendNotification(source, { app = ServicesPlus.Constants.AppIdentifier, title = "Incoming company call", content = company.displayName .. " - " .. number.label }) end)
    end
    local position = ServicesPlus.Repository.GetQueuePosition(number.id, entry.id)
    Calls.BroadcastQueue(number.id)
    return true, { id = entry.id, state = state, offered = offered, callToken = token, position = position }
end

function Calls.Accept(source, queueId)
    local employee = ServicesPlus.Employees.Get(source)
    if not employee or employee.status ~= "available" then return false, "employee_unavailable" end
    local row = MySQL.single.await("SELECT * FROM `services_plus_call_queue` WHERE `id` = ?", { queueId })
    if not row or row.company_id ~= employee.companyId then return false, "forbidden" end
    local company = ServicesPlus.Companies.Get(row.company_id)
    local number
    for _, candidate in ipairs(company and company.numbers or {}) do if candidate.id == row.number_id then number = candidate break end end
    if not company or not number or not isEligible(employee, company, number) then return false, "employee_unavailable" end
    local offered = json.decode(row.offered_identifiers or "[]") or {}
    local allowed = false; for _, identifier in ipairs(offered) do if identifier == employee.identifier then allowed = true break end end
    if not allowed or not ServicesPlus.Repository.AcceptCallQueue(queueId, employee.identifier) then return false, "already_accepted" end
    if not ServicesPlus.Employees.AssignWork(source, "call", queueId) then ServicesPlus.Repository.EndCallQueue(queueId, "assignment_failed"); return false, "employee_unavailable" end
    for target in pairs((runtimeOffers[row.call_token] and runtimeOffers[row.call_token].sources) or {}) do
        push(target, target == source and "call.accepted.local" or "call.offer.removed", { id = queueId, callToken = row.call_token })
    end
    Calls.BroadcastQueue(row.number_id)
    return true, { id = queueId, callToken = row.call_token }
end

function Calls.Decline(source, queueId)
    local employee = ServicesPlus.Employees.Get(source)
    local row = MySQL.single.await("SELECT * FROM `services_plus_call_queue` WHERE `id` = ?", { queueId })
    if not employee or not row or row.company_id ~= employee.companyId or row.status ~= "offered" then return false, "call_unavailable" end
    local offered = json.decode(row.offered_identifiers or "[]") or {}
    local wasOffered = false; for _, identifier in ipairs(offered) do if identifier == employee.identifier then wasOffered = true break end end
    if not wasOffered then return false, "forbidden" end
    local offer = runtimeOffers[row.call_token] or { declined = {}, sources = {} }
    runtimeOffers[row.call_token] = offer
    offer.declined[employee.identifier] = true
    push(source, "call.offer.removed", { id = queueId, callToken = row.call_token })
    local allDeclined = true; for _, identifier in ipairs(offered) do if not offer.declined[identifier] then allDeclined = false break end end
    if allDeclined then ServicesPlus.Repository.UpdateCallOffer(queueId, "queued", {}); Calls.BroadcastQueue(row.number_id); Calls.ReofferCompany(row.company_id) end
    return true, { id = queueId }
end

function Calls.EndToken(token, result)
    local row = ServicesPlus.Repository.GetCallQueueByToken(tostring(token))
    if not row then return end
    ServicesPlus.Repository.EndCallQueue(row.id, result or "ended")
    if row.assigned_identifier then ServicesPlus.Employees.ReleaseWorkByIdentifier(row.assigned_identifier, "call", row.id) end
    runtimeOffers[row.call_token] = nil
    Calls.BroadcastQueue(row.number_id)
end

function Calls.EndFromClient(source, token)
    local offer = runtimeOffers[tostring(token)]
    if not offer or not offer.sources[source] then return false end
    Calls.EndToken(token, "ended")
    return true
end

function Calls.ReofferCompany(companyId)
    local company = ServicesPlus.Companies.Get(companyId)
    if not company then return end
    for _, row in ipairs(ServicesPlus.Repository.GetQueuedCalls(companyId, 20)) do
        local number
        for _, candidate in ipairs(company.numbers) do if candidate.id == row.number_id then number = candidate break end end
        if number then
            local offer = runtimeOffers[row.call_token]
            local selected = selectEmployees(company, number, offer and offer.declined or nil)
            if #selected > 0 then
                local selectedIds = identifiers(selected)
                ServicesPlus.Repository.UpdateCallOffer(row.id, "offered", selectedIds)
                for _, employee in ipairs(selected) do
                    if runtimeOffers[row.call_token] and runtimeOffers[row.call_token].sources[employee.source] then
                        push(employee.source, "call.offer", { id = row.id, callToken = row.call_token, companyId = company.id, companyName = company.displayName, numberId = number.id, numberLabel = number.label })
                        pcall(function() exports["lb-phone"]:SendNotification(employee.source, { app = ServicesPlus.Constants.AppIdentifier, title = "Incoming company call", content = company.displayName .. " - " .. number.label }) end)
                    end
                end
            end
        end
    end
end

function Calls.RevalidateEmployee(source)
    local employee = ServicesPlus.Employees.Get(source)
    if not employee then return end
    for token, offer in pairs(runtimeOffers) do
        if offer.sources[source] then
            local row = ServicesPlus.Repository.GetCallQueueByToken(token)
            if row and row.status == "offered" then
                local company = ServicesPlus.Companies.Get(row.company_id)
                local number
                for _, candidate in ipairs(company and company.numbers or {}) do if candidate.id == row.number_id then number = candidate break end end
                if not company or not number or not isEligible(employee, company, number) then
                    local remaining = {}
                    for _, identifier in ipairs(json.decode(row.offered_identifiers or "[]") or {}) do if identifier ~= employee.identifier then remaining[#remaining + 1] = identifier end end
                    ServicesPlus.Repository.UpdateCallOffer(row.id, #remaining > 0 and "offered" or "queued", remaining)
                    push(source, "call.offer.removed", { id = row.id, callToken = token })
                end
            end
        end
    end
    Calls.ReofferCompany(employee.companyId)
end

function Calls.EmployeeLeft(employee)
    if employee and employee.activeCall then
        ServicesPlus.Repository.EndCallQueue(employee.activeCall, "employee_disconnected")
        pcall(function() exports["lb-phone"]:EndCall(employee.source) end)
    end
end

function Calls.PhoneStopped()
    for _, row in ipairs(ServicesPlus.Repository.EndOpenCalls("phone_restarted")) do
        if row.assigned_identifier then ServicesPlus.Employees.ReleaseWorkByIdentifier(row.assigned_identifier, "call", row.id) end
    end
    runtimeOffers = {}
end

AddEventHandler("lb-phone:newCall", function(call)
    if type(call) ~= "table" then return end
    local token = tostring(call.callId or "")
    local caller = call.caller or {}
    local callee = call.callee or {}
    local player = caller.source and ServicesPlus.Bridge.GetPlayer(caller.source) or nil
    local company, number = ServicesPlus.Companies.FindByNumber(callee.number or call.company)
    if company and number then
        local row = ServicesPlus.Repository.CreateCallQueue({ callToken = token, lbCallId = call.callId, callerIdentifier = player and player.identifier or nil, callerNumber = caller.number, companyId = company.id, numberId = number.id, status = "queued", offeredIdentifiers = {} })
        runtimeOffers[token] = runtimeOffers[token] or { declined = {}, sources = {}, callerSource = caller.source }
        runtimeOffers[token].callerSource = caller.source
        if row then ServicesPlus.Repository.AttachCallHistory(player and player.identifier or nil, company.id, number.id, row.id) end
        if caller.source and row then push(caller.source, "call.queue", { id = row.id, companyId = company.id, position = ServicesPlus.Repository.GetQueuePosition(number.id, row.id), status = row.status }) end
        Calls.BroadcastQueue(number.id)
    else
        ServicesPlus.Repository.AttachLbCall(token, call.callId, player and player.identifier or nil, caller.number)
    end
end)

AddEventHandler("lb-phone:callEnded", function(call)
    if type(call) ~= "table" then return end
    local row = call.callId and ServicesPlus.Repository.GetCallQueueByLbId(call.callId) or nil
    if row then Calls.EndToken(row.call_token, call.answered and "completed" or "missed") end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == "lb-phone" then Calls.PhoneStopped() end
end)
