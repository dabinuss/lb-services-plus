local function invokingResourceAllowed()
    local resource = GetInvokingResource()
    if not resource or resource == GetCurrentResourceName() then return true, resource end
    for _, allowed in ipairs(Config.ApiAllowedResources or {}) do
        if allowed == resource then return true, resource end
    end
    ServicesPlus.Logger.Warn("Rejected external Services+ API call", { resource = resource })
    return false, resource
end

local function guarded(handler, rateAction)
    local allowed, resource = invokingResourceAllowed()
    if not allowed then return ServicesPlus.Error("integration_forbidden", "The invoking resource is not allowed to use the Services+ API.", false) end
    if not ServicesPlus.Ready then return ServicesPlus.Error("service_unavailable", "Services+ is not ready.", true) end
    if rateAction and resource and resource ~= GetCurrentResourceName()
        and not ServicesPlus.RateLimiter.Allow("resource:" .. resource, rateAction) then
        return ServicesPlus.Error("rate_limited", "The invoking resource exceeded its Services+ API limit.", true)
    end
    local ok, result = pcall(handler, resource)
    if ok then return result end
    ServicesPlus.Logger.Error("External Services+ API call failed", { resource = resource, error = tostring(result) })
    return ServicesPlus.Error("internal_error", "The Services+ API call failed.", true)
end

local function integrationRequest(requestId)
    local request = ServicesPlus.Repository.GetRequestById(tonumber(requestId))
    return request and ServicesPlus.Requests.ToIntegration(request) or nil
end

local function requestAction(source, requestId, action, failureMessage)
    source, requestId = tonumber(source), tonumber(requestId)
    if not source or not requestId then return ServicesPlus.Error("validation_failed", "Invalid request action payload.", false) end
    if not ServicesPlus.RateLimiter.Allow(source, "externalRequestAction") then return ServicesPlus.Error("rate_limited", "Too many external request actions.", true) end
    local success, result = action(source, requestId)
    if not success then return ServicesPlus.Error(result, failureMessage, false) end
    return ServicesPlus.Ok(integrationRequest(requestId) or result)
end

exports("GetCompany", function(companyId)
    return guarded(function()
        local company = type(companyId) == "string" and ServicesPlus.Companies.Get(companyId) or nil
        return company and ServicesPlus.Ok(ServicesPlus.Companies.ToPublic(company)) or ServicesPlus.Error("company_not_found", "Company not found.", false)
    end, "externalRead")
end)

exports("GetCompanyNumbers", function(companyId)
    return guarded(function()
        local company = type(companyId) == "string" and ServicesPlus.Companies.Get(companyId) or nil
        if not company then return ServicesPlus.Error("company_not_found", "Company not found.", false) end
        return ServicesPlus.Ok(ServicesPlus.Companies.ToPublic(company).numbers)
    end, "externalRead")
end)

exports("GetCompanyEmployees", function(companyId)
    return guarded(function()
        if type(companyId) ~= "string" or not ServicesPlus.Companies.Get(companyId) then return ServicesPlus.Error("company_not_found", "Company not found.", false) end
        return ServicesPlus.Ok(ServicesPlus.Employees.GetIntegrationForCompany(companyId))
    end, "externalRead")
end)

exports("GetRequest", function(requestId)
    return guarded(function()
        local request = integrationRequest(requestId)
        return request and ServicesPlus.Ok(request) or ServicesPlus.Error("request_not_found", "Request not found.", false)
    end, "externalRead")
end)

exports("GetCompanyRequests", function(companyId, options)
    return guarded(function()
        if not ServicesPlus.Companies.Get(companyId) then return ServicesPlus.Error("company_not_found", "Company not found.", false) end
        local limit = math.max(1, math.min(math.floor(tonumber(options and options.limit) or 30), 50))
        local cursor = math.max(1, math.floor(tonumber(options and options.cursor) or 9007199254740991))
        local requests = ServicesPlus.Repository.GetCompanyRequests(companyId, cursor, limit, options and options.activeOnly == true)
        for index, request in ipairs(requests) do requests[index] = ServicesPlus.Requests.ToIntegration(request) end
        return ServicesPlus.Ok(requests)
    end, "externalList")
end)

exports("CreateRequest", function(source, payload)
    return guarded(function(resource)
        if not ServicesPlus.RateLimiter.Allow(tonumber(source) or 0, "externalCreateRequest") then return ServicesPlus.Error("rate_limited", "Too many external requests.", true) end
        if type(payload) ~= "table" or type(payload.companyId) ~= "string" or type(payload.templateId) ~= "string"
            or type(payload.values) ~= "table" or type(payload.externalId) ~= "string" or #payload.externalId < 1 or #payload.externalId > 96 then
            return ServicesPlus.Error("validation_failed", "Invalid external request payload.", false)
        end
        local existing = ServicesPlus.Repository.GetRequestByExternal(resource, payload.externalId)
        if existing then return ServicesPlus.Ok(ServicesPlus.Requests.ToIntegration(existing)) end
        local success, result = ServicesPlus.Requests.Create(tonumber(source), payload.companyId, payload.templateId, payload.values,
            payload.locale == "de" and "de" or "en", { source = resource, id = payload.externalId })
        return success and ServicesPlus.Ok(integrationRequest(result.id) or result) or ServicesPlus.Error(result, "The external request could not be created.", false)
    end, "externalWrite")
end)

exports("AcceptRequest", function(source, requestId)
    return guarded(function()
        return requestAction(source, requestId, ServicesPlus.Requests.Accept, "The external request acceptance was rejected.")
    end, "externalWrite")
end)

exports("DeclineRequest", function(source, requestId)
    return guarded(function()
        return requestAction(source, requestId, ServicesPlus.Requests.Decline, "The external request decline was rejected.")
    end, "externalWrite")
end)

exports("ReturnRequest", function(source, requestId)
    return guarded(function()
        return requestAction(source, requestId, ServicesPlus.Requests.Return, "The external request return was rejected.")
    end, "externalWrite")
end)

exports("TransitionRequest", function(source, requestId, phaseId)
    return guarded(function()
        if not ServicesPlus.RateLimiter.Allow(tonumber(source) or 0, "externalTransitionRequest") then return ServicesPlus.Error("rate_limited", "Too many external transitions.", true) end
        local success, result = ServicesPlus.Requests.Transition(tonumber(source), tonumber(requestId), phaseId)
        return success and ServicesPlus.Ok(integrationRequest(requestId) or result) or ServicesPlus.Error(result, "The request transition was rejected.", false)
    end, "externalWrite")
end)

exports("SendCompanyMessage", function(source, payload)
    return guarded(function()
        if not ServicesPlus.RateLimiter.Allow(tonumber(source) or 0, "externalSendCompanyMessage") then return ServicesPlus.Error("rate_limited", "Too many external messages.", true) end
        local success, result = ServicesPlus.Inboxes.SendEmployee(tonumber(source), payload)
        return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The company message was rejected.", false)
    end, "externalWrite")
end)
