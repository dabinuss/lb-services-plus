local function invokingResourceAllowed()
    local resource = GetInvokingResource()
    if not resource or resource == GetCurrentResourceName() then return true, resource end
    for _, allowed in ipairs(Config.ApiAllowedResources or {}) do
        if allowed == resource then return true, resource end
    end
    ServicesPlus.Logger.Warn("Rejected external Services+ API call", { resource = resource })
    return false, resource
end

local function guarded(handler)
    local allowed, resource = invokingResourceAllowed()
    if not allowed then return ServicesPlus.Error("integration_forbidden", "The invoking resource is not allowed to use the Services+ API.", false) end
    if not ServicesPlus.Ready then return ServicesPlus.Error("service_unavailable", "Services+ is not ready.", true) end
    local ok, result = pcall(handler, resource)
    if ok then return result end
    ServicesPlus.Logger.Error("External Services+ API call failed", { resource = resource, error = tostring(result) })
    return ServicesPlus.Error("internal_error", "The Services+ API call failed.", true)
end

exports("GetCompany", function(companyId)
    return guarded(function()
        local company = type(companyId) == "string" and ServicesPlus.Companies.Get(companyId) or nil
        return company and ServicesPlus.Ok(ServicesPlus.Companies.ToPublic(company)) or ServicesPlus.Error("company_not_found", "Company not found.", false)
    end)
end)

exports("GetCompanyNumbers", function(companyId)
    return guarded(function()
        local company = type(companyId) == "string" and ServicesPlus.Companies.Get(companyId) or nil
        if not company then return ServicesPlus.Error("company_not_found", "Company not found.", false) end
        return ServicesPlus.Ok(ServicesPlus.Companies.ToPublic(company).numbers)
    end)
end)

exports("GetRequest", function(requestId)
    return guarded(function()
        local request = ServicesPlus.Repository.GetRequestById(tonumber(requestId))
        return request and ServicesPlus.Ok(request) or ServicesPlus.Error("request_not_found", "Request not found.", false)
    end)
end)

exports("GetCompanyRequests", function(companyId, options)
    return guarded(function()
        if not ServicesPlus.Companies.Get(companyId) then return ServicesPlus.Error("company_not_found", "Company not found.", false) end
        local limit = math.max(1, math.min(math.floor(tonumber(options and options.limit) or 30), 50))
        local cursor = math.max(1, math.floor(tonumber(options and options.cursor) or 9007199254740991))
        return ServicesPlus.Ok(ServicesPlus.Repository.GetCompanyRequests(companyId, cursor, limit, options and options.activeOnly == true))
    end)
end)

exports("CreateRequest", function(source, payload)
    return guarded(function(resource)
        if not ServicesPlus.RateLimiter.Allow(tonumber(source) or 0, "externalCreateRequest") then return ServicesPlus.Error("rate_limited", "Too many external requests.", true) end
        if type(payload) ~= "table" or type(payload.companyId) ~= "string" or type(payload.templateId) ~= "string"
            or type(payload.values) ~= "table" or type(payload.externalId) ~= "string" or #payload.externalId < 1 or #payload.externalId > 96 then
            return ServicesPlus.Error("validation_failed", "Invalid external request payload.", false)
        end
        local existing = ServicesPlus.Repository.GetRequestByExternal(resource, payload.externalId)
        if existing then return ServicesPlus.Ok(existing) end
        local success, result = ServicesPlus.Requests.Create(tonumber(source), payload.companyId, payload.templateId, payload.values,
            payload.locale == "de" and "de" or "en", { source = resource, id = payload.externalId })
        return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The external request could not be created.", false)
    end)
end)

exports("TransitionRequest", function(source, requestId, phaseId)
    return guarded(function()
        if not ServicesPlus.RateLimiter.Allow(tonumber(source) or 0, "externalTransitionRequest") then return ServicesPlus.Error("rate_limited", "Too many external transitions.", true) end
        local success, result = ServicesPlus.Requests.Transition(tonumber(source), tonumber(requestId), phaseId)
        return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The request transition was rejected.", false)
    end)
end)

exports("SendCompanyMessage", function(source, payload)
    return guarded(function()
        if not ServicesPlus.RateLimiter.Allow(tonumber(source) or 0, "externalSendCompanyMessage") then return ServicesPlus.Error("rate_limited", "Too many external messages.", true) end
        local success, result = ServicesPlus.Inboxes.SendEmployee(tonumber(source), payload)
        return success and ServicesPlus.Ok(result) or ServicesPlus.Error(result, "The company message was rejected.", false)
    end)
end)
