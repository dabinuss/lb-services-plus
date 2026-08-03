local raw = LoadResourceFile(GetCurrentResourceName(), "shared/api_contracts.json")
local ok, contracts = pcall(json.decode, raw or "")

if not ok or type(contracts) ~= "table" or contracts.version ~= ServicesPlus.Constants.ApiVersion then
    error("Services+ API contract metadata is missing, invalid, or has the wrong version")
end

ServicesPlus.Contracts = contracts

local function validate(schema, value, path)
    if not schema then return true end
    local expected = schema.type
    if expected == "object" then
        if type(value) ~= "table" then return false, path .. " must be an object" end
        for _, field in ipairs(schema.required or {}) do
            if value[field] == nil then return false, path .. "." .. field .. " is required" end
        end
        for field, child in pairs(schema.properties or {}) do
            if value[field] ~= nil then
                local ok, reason = validate(child, value[field], path .. "." .. field)
                if not ok then return false, reason end
            end
        end
    elseif expected == "array" then
        if type(value) ~= "table" then return false, path .. " must be an array" end
        if schema.maxItems and #value > schema.maxItems then return false, path .. " has too many items" end
        for index, item in ipairs(value) do
            local ok, reason = validate(schema.items, item, path .. "[" .. index .. "]")
            if not ok then return false, reason end
        end
    elseif expected == "string" then
        if type(value) ~= "string" then return false, path .. " must be a string" end
        if schema.minLength and #value < schema.minLength then return false, path .. " is too short" end
        if schema.maxLength and #value > schema.maxLength then return false, path .. " is too long" end
    elseif expected == "number" or expected == "integer" then
        if type(value) ~= "number" or expected == "integer" and value % 1 ~= 0 then return false, path .. " must be " .. expected end
        if schema.minimum and value < schema.minimum then return false, path .. " is below the minimum" end
        if schema.maximum and value > schema.maximum then return false, path .. " exceeds the maximum" end
    elseif expected == "boolean" and type(value) ~= "boolean" then
        return false, path .. " must be a boolean"
    end
    if schema.enum then
        for _, allowed in ipairs(schema.enum) do if value == allowed then return true end end
        return false, path .. " has an unsupported value"
    end
    return true
end

function ServicesPlus.Contracts.ValidateActionPayload(action, payload)
    local contract = contracts.actions[action]
    if not contract or not contract.inputSchema then return true end
    return validate(contract.inputSchema, payload == nil and {} or payload, "payload")
end
