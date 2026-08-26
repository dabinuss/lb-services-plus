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

    Billing starts only once the assigned driver reaches the pickup radius.
    From there, the existing low-frequency journey reporter supplies
    server-owned player positions. Distance is accumulated between plausible
    samples and persisted periodically; per-minute uses the same billable
    service start. Dispatch acceptance and travel to the customer are never
    charged.
]]

TaxiPricing = {}

local FEATURE = "taxi_pricing"
local BILLING_MODES = { per_minute = true, per_100m = true }
local MIN_RATE, MAX_RATE = 0, 1000
local METER_PERSIST_INTERVAL = 60
local MAX_METRES_PER_SECOND = 120
local activeMeters = {} -- requestId -> sampled billable journey state

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

--- Requests.Accept hook - freezes the tariff, but deliberately does not
--- start billing. The service clock/meter starts on pickup arrival.
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

    MySQL.update.await(
        "UPDATE phone_services_plus_requests SET accepted_at = NOW(), service_started_at = NULL, travelled_distance = 0, pickup_distance = NULL, feature_data = ? WHERE id = ?",
        { json.encode({ feature = FEATURE, billingMode = billingMode, rate = rate }), requestId }
    )
    activeMeters[tonumber(requestId)] = nil
end

local function newMeterState(requestId, coords, distance)
    local now = os.time()
    local state = {
        distance = math.max(0, tonumber(distance) or 0),
        lastX = coords and tonumber(coords.x) or nil,
        lastY = coords and tonumber(coords.y) or nil,
        lastSampleAt = now,
        lastPersistAt = now,
    }
    activeMeters[tonumber(requestId)] = state
    return state
end

local function loadMeterState(requestId, coords)
    local row = MySQL.single.await([[
        SELECT r.travelled_distance, r.service_started_at, t.feature
        FROM phone_services_plus_requests r
        JOIN phone_services_plus_request_types t ON t.id = r.request_type_id
        WHERE r.id = ?
    ]], { requestId })
    if not row or row.feature ~= FEATURE or not row.service_started_at then return nil end
    return newMeterState(requestId, coords, row.travelled_distance)
end

local function sampleMeter(requestId, coords, forcePersist)
    local id = tonumber(requestId)
    if not id or not coords then return nil end
    local x, y = tonumber(coords.x), tonumber(coords.y)
    if not x or not y then return nil end

    local state = activeMeters[id] or loadMeterState(id, coords)
    if not state then return nil end

    local now = os.time()
    if state.lastX and state.lastY then
        local dx, dy = x - state.lastX, y - state.lastY
        local delta = math.sqrt(dx * dx + dy * dy)
        local elapsed = math.max(1, now - state.lastSampleAt)
        -- Ignore teleports or corrupted samples. 120 m/s leaves generous
        -- headroom for GTA driving while preventing one jump from billing
        -- kilometres that were never driven.
        if delta <= math.max(250, elapsed * MAX_METRES_PER_SECOND) then
            state.distance = state.distance + delta
        end
    end

    state.lastX, state.lastY, state.lastSampleAt = x, y, now
    if forcePersist or now - state.lastPersistAt >= METER_PERSIST_INTERVAL then
        MySQL.update.await(
            "UPDATE phone_services_plus_requests SET travelled_distance = ? WHERE id = ? AND service_started_at IS NOT NULL",
            { state.distance, id }
        )
        state.lastPersistAt = now
    end
    return state.distance
end

---@param requestId number
---@param employeeSource number
---@param coords table
function TaxiPricing.OnServiceStarted(requestId, employeeSource, coords)
    local row = MySQL.single.await([[
        SELECT t.feature
        FROM phone_services_plus_requests r
        JOIN phone_services_plus_request_types t ON t.id = r.request_type_id
        WHERE r.id = ? AND r.status = 'active'
    ]], { requestId })
    if not row or row.feature ~= FEATURE then return end

    MySQL.update.await([[
        UPDATE phone_services_plus_requests
        SET service_started_at = COALESCE(service_started_at, NOW())
        WHERE id = ? AND status = 'active'
    ]], { requestId })
    newMeterState(requestId, coords, 0)
end

---@param requestId number
---@param employeeSource number
---@param coords table
function TaxiPricing.OnProgress(requestId, employeeSource, coords)
    sampleMeter(requestId, coords, false)
end

--- Uses the tariff captured at acceptance and the actual service metric.
--- Requests accepted before tariff snapshots existed fall back to the
--- current company setting once for backwards compatibility.
---@param requestId number
---@param employeeSource? number
function TaxiPricing.OnComplete(requestId, employeeSource)
    if employeeSource then
        local ped = GetPlayerPed(employeeSource)
        if ped and ped ~= 0 then sampleMeter(requestId, GetEntityCoords(ped), true) end
    end

    local row = MySQL.single.await([[
        SELECT r.company_id, r.request_type_id, r.service_started_at, r.travelled_distance, r.feature_data, t.feature
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
        local seconds = row.service_started_at and MySQL.scalar.await(
            "SELECT TIMESTAMPDIFF(SECOND, service_started_at, NOW()) FROM phone_services_plus_requests WHERE id = ?",
            { requestId }
        ) or 0
        metric = math.max(0, tonumber(seconds) or 0) / 60
    else
        metric = math.max(0, tonumber(row.travelled_distance) or 0)
    end

    local amount = billingMode == "per_minute" and (rate * metric) or (rate * (metric / 100))
    amount = math.floor(amount * 100 + 0.5) / 100

    MySQL.update.await(
        "UPDATE phone_services_plus_requests SET feature_data = ? WHERE id = ?",
        { json.encode({ feature = FEATURE, billingMode = billingMode, rate = rate, metric = metric, amount = amount }), requestId }
    )
    activeMeters[tonumber(requestId)] = nil
end

function TaxiPricing.OnCancel(requestId)
    activeMeters[tonumber(requestId)] = nil
end

RegisterCallback("getTaxiPricingSettings", function(source, reply)
    local company, job = Companies.GetForPlayer(source)
    if not company or not Employees.IsLoggedIn(source, company.id) or not Framework.GetOnDuty(source)
        or not Framework.IsBoss(source, job.name, company.boss_grade) then return reply(false) end
    reply(TaxiPricing.GetCompanySettings(company))
end)

RegisterCallback("updateTaxiPricingSettings", function(source, reply, requestTypeId, settings)
    local company, job = Companies.GetForPlayer(source)
    if not company or not Employees.IsLoggedIn(source, company.id) or not Framework.GetOnDuty(source)
        or not Framework.IsBoss(source, job.name, company.boss_grade) then return reply(false) end
    reply(TaxiPricing.UpdateCompanySettings(company, requestTypeId, settings))
end)

Features.Register(FEATURE, {
    OnAccept = TaxiPricing.OnAccept,
    OnServiceStarted = TaxiPricing.OnServiceStarted,
    OnProgress = TaxiPricing.OnProgress,
    OnComplete = TaxiPricing.OnComplete,
    OnCancel = TaxiPricing.OnCancel,
})
