--[[
    Taxi pricing ("Taxameter"), the first of what may become several
    per-request-type special features (plan discussion following the
    PeekPlus dispatch-card rework). A company can turn on per-minute or
    per-100m billing for a request type an admin flagged with
    `feature = 'taxi_pricing'`; the two hooks below register into the
    generic Features registry (server/features.lua) and are no-ops for
    every other request, so requests.lua itself never has to know this
    feature exists.

    Everything specific to the taxi request type - this server module, the
    PeekPlus dispatch card (index.html/taxi.css/taxi.js) and the seed
    definition it's registered under in shared/categories.lua - lives
    together under request-types/taxi/.

    Storage is split the same way the rest of the config already is:
    - phone_services_plus_company_features holds the company's own
      billing_mode/rate per request type (generic column, opaque JSON - see
      sql/install.sql). Only this file interprets what's inside it.
    - phone_services_plus_requests.feature_data holds the tariff frozen at
      acceptance and, once completed, the resulting metric/amount. A company
      changing its rate during a ride therefore cannot change that ride's
      price.

    Distance is a proxy, not a real trip odometer (see sql/install.sql's
    `pickup_distance` comment) - this system has no drop-off location or
    route tracking to measure an actual driven distance against. Per-minute
    billing has no such caveat: `accepted_at` -> now is a real duration.
]]

TaxiPricing = {}

local FEATURE = "taxi_pricing"
local BILLING_MODES = { per_minute = true, per_100m = true }
local MIN_RATE, MAX_RATE = 0, 1000

local function clampRate(value)
    local n = tonumber(value)
    if not n then return nil end
    return math.max(MIN_RATE, math.min(MAX_RATE, n))
end

local function decodeConfig(raw)
    if type(raw) == "table" then return raw end
    if type(raw) ~= "string" then return {} end
    local ok, decoded = pcall(json.decode, raw)
    return (ok and type(decoded) == "table") and decoded or {}
end

local function getPricingConfig(companyId, requestTypeId)
    local configRow = MySQL.single.await(
        "SELECT config FROM phone_services_plus_company_features WHERE company_id = ? AND request_type_id = ? AND feature = ?",
        { companyId, requestTypeId, FEATURE }
    )
    local config = decodeConfig(configRow and configRow.config)
    return BILLING_MODES[config.billingMode] and config.billingMode or "per_100m",
        clampRate(config.rate) or 2
end

--- This company's own category's request types that currently expose the
--- feature (enabled or not - callers that need only the live/creatable ones
--- filter that themselves, same convention as Requests.GetTypesForCategory).
---@param categoryId number
---@return table[] { id, name }
local function typesWithFeature(categoryId)
    if not categoryId then return {} end
    return MySQL.query.await(
        "SELECT id, name FROM phone_services_plus_request_types WHERE category_id = ? AND feature = ?",
        { categoryId, FEATURE }
    ) or {}
end

--- Boss-facing config for every feature-enabled request type this
--- company's category has, each with its own billing mode/rate (plan
--- discussion: per-company, not one setting for the whole category).
---@param company table
---@return table[] { requestTypeId, requestTypeName, billingMode, rate }
function TaxiPricing.GetCompanySettings(company)
    local types = typesWithFeature(company.category_id)
    if #types == 0 then return {} end

    local rows = MySQL.query.await(
        "SELECT request_type_id, config FROM phone_services_plus_company_features WHERE company_id = ? AND feature = ?",
        { company.id, FEATURE }
    ) or {}

    local configByType = {}
    for i = 1, #rows do
        configByType[rows[i].request_type_id] = decodeConfig(rows[i].config)
    end

    local out = {}
    for i = 1, #types do
        local config = configByType[types[i].id] or {}
        out[#out + 1] = {
            requestTypeId = types[i].id,
            requestTypeName = types[i].name,
            billingMode = BILLING_MODES[config.billingMode] and config.billingMode or "per_100m",
            rate = clampRate(config.rate) or 2,
        }
    end
    return out
end

---@param company table
---@param requestTypeId number|string
---@param patch { billingMode: string, rate: number }
---@return boolean
function TaxiPricing.UpdateCompanySettings(company, requestTypeId, patch)
    local id = tonumber(requestTypeId)
    if not id or type(patch) ~= "table" then return false end

    -- Must actually be one of this company's own feature-enabled types -
    -- without this a boss could write a config row for any request type id,
    -- including ones belonging to a different category entirely.
    local types = typesWithFeature(company.category_id)
    local valid = false
    for i = 1, #types do
        if types[i].id == id then
            valid = true
            break
        end
    end
    if not valid then return false end

    local billingMode = BILLING_MODES[patch.billingMode] and patch.billingMode or "per_100m"
    local rate = clampRate(patch.rate) or 2

    MySQL.insert.await([[
        INSERT INTO phone_services_plus_company_features (company_id, request_type_id, feature, config)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE config = VALUES(config)
    ]], { company.id, id, FEATURE, json.encode({ billingMode = billingMode, rate = rate }) })

    return true
end

--- Requests.Accept hook - no-op unless this request's type has the feature
--- on. Captures the one distance sample this feature ever gets (see file
--- header), freezes the currently configured tariff, and starts the
--- per-minute clock.
---@param requestId number
---@param employeeSource number
function TaxiPricing.OnAccept(requestId, employeeSource)
    local row = MySQL.single.await([[
        SELECT r.company_id, r.request_type_id, r.pos_x, r.pos_y, t.feature
        FROM phone_services_plus_requests r
        JOIN phone_services_plus_request_types t ON t.id = r.request_type_id
        WHERE r.id = ?
    ]], { requestId })
    if not row or row.feature ~= FEATURE or not row.company_id then return end

    local billingMode, rate = getPricingConfig(row.company_id, row.request_type_id)

    local distance = json.null
    if type(row.pos_x) == "number" and type(row.pos_y) == "number" then
        local ped = GetPlayerPed(employeeSource)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            local dx, dy = coords.x - row.pos_x, coords.y - row.pos_y
            distance = math.sqrt(dx * dx + dy * dy)
        end
    end

    MySQL.update.await(
        "UPDATE phone_services_plus_requests SET accepted_at = NOW(), pickup_distance = ?, feature_data = ? WHERE id = ?",
        { distance, json.encode({ feature = FEATURE, billingMode = billingMode, rate = rate }), requestId }
    )
end

--- Requests.Complete hook - no-op unless this request's type has the
--- feature on. Uses the tariff captured at acceptance and adds the final
--- metric/amount. Requests that were already active before this version
--- fall back to the current setting once for backwards compatibility.
---@param requestId number
function TaxiPricing.OnComplete(requestId)
    local row = MySQL.single.await([[
        SELECT r.company_id, r.request_type_id, r.accepted_at, r.pickup_distance, r.feature_data, t.feature
        FROM phone_services_plus_requests r
        JOIN phone_services_plus_request_types t ON t.id = r.request_type_id
        WHERE r.id = ?
    ]], { requestId })
    if not row or row.feature ~= FEATURE or not row.company_id then return end

    local frozen = decodeConfig(row.feature_data)
    local billingMode = BILLING_MODES[frozen.billingMode] and frozen.billingMode or nil
    local rate = clampRate(frozen.rate)
    if not billingMode or rate == nil then
        billingMode, rate = getPricingConfig(row.company_id, row.request_type_id)
    end

    local metric
    if billingMode == "per_minute" then
        if not row.accepted_at then return end
        local seconds = MySQL.scalar.await(
            "SELECT TIMESTAMPDIFF(SECOND, accepted_at, NOW()) FROM phone_services_plus_requests WHERE id = ?",
            { requestId }
        )
        metric = math.max(0, tonumber(seconds) or 0) / 60
    else
        metric = math.max(0, tonumber(row.pickup_distance) or 0)
    end

    local amount = billingMode == "per_minute" and (rate * metric) or (rate * (metric / 100))
    amount = math.floor(amount * 100 + 0.5) / 100

    MySQL.update.await(
        "UPDATE phone_services_plus_requests SET feature_data = ? WHERE id = ?",
        { json.encode({ feature = FEATURE, billingMode = billingMode, rate = rate, metric = metric, amount = amount }), requestId }
    )
end

RegisterCallback("getTaxiPricingSettings", function(source, reply)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company or not Framework.IsBoss(source, job.name, company.boss_grade) then return reply(false) end
    reply(TaxiPricing.GetCompanySettings(company))
end)

RegisterCallback("updateTaxiPricingSettings", function(source, reply, requestTypeId, settings)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company or not Framework.IsBoss(source, job.name, company.boss_grade) then return reply(false) end
    reply(TaxiPricing.UpdateCompanySettings(company, requestTypeId, settings))
end)

Features.Register(FEATURE, {
    OnAccept = TaxiPricing.OnAccept,
    OnComplete = TaxiPricing.OnComplete,
})
