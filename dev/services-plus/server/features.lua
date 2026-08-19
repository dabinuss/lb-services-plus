--[[
    Generic per-request-type feature registry (plan discussion following the
    Taxameter build). requests.lua calls Features.OnAccept/OnComplete
    unconditionally on every accept/complete - it never names a feature
    module directly, so adding a new request-type feature never means
    editing requests.lua again.

    A feature module (e.g. request-types/taxi/server.lua) registers itself
    here once, by the same technical key it's flagged with on
    phone_services_plus_request_types.feature:

        Features.Register("taxi_pricing", {
            OnAccept = TaxiPricing.OnAccept,
            OnComplete = TaxiPricing.OnComplete,
        })

    Each hook is still expected to self-guard (look up whether the given
    request's type actually carries its own feature key and no-op
    otherwise) exactly like TaxiPricing.OnAccept/OnComplete already did -
    this registry only replaces the hardcoded call in requests.lua, not the
    per-feature matching logic.

    Must be loaded (fxmanifest.lua server_scripts) before any module that
    calls Features.Register at file-load time. Load order relative to
    requests.lua itself doesn't matter - Features.OnAccept/OnComplete are
    only ever called from inside event-handler bodies, resolved at runtime.
]]

Features = { registry = {} }

---@param name string  the request_types.feature value this module handles
---@param hooks { OnAccept: fun(requestId: number, employeeSource: number)?, OnComplete: fun(requestId: number)? }
function Features.Register(name, hooks)
    Features.registry[name] = hooks
end

---@param requestId number
---@param employeeSource number
function Features.OnAccept(requestId, employeeSource)
    for _, hooks in pairs(Features.registry) do
        if hooks.OnAccept then hooks.OnAccept(requestId, employeeSource) end
    end
end

---@param requestId number
function Features.OnComplete(requestId)
    for _, hooks in pairs(Features.registry) do
        if hooks.OnComplete then hooks.OnComplete(requestId) end
    end
end
