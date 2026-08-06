ServicesPlus = ServicesPlus or {}

ServicesPlus.Constants = {
    ResourceName = "services-plus",
    AppIdentifier = "services-plus",
    ApiVersion = 11,
    MessageReactions = {
        ["👍"] = true, ["❤️"] = true, ["😂"] = true, ["😮"] = true, ["😢"] = true,
        ["🚗"] = true, ["💵"] = true, ["🚨"] = true, ["🔧"] = true, ["🍔"] = true
    },
    EmployeeStatuses = {
        available = true,
        busy = true,
        occupied = true,
        on_break = true,
        off_duty = true
    },
    MutableEmployeeStatuses = {
        available = true,
        occupied = true,
        on_break = true
    },
    DistributionModes = {
        ring_all = true,
        random = true,
        dispatch_only = true
    },
    NavigationModes = {
        disabled = true,
        ask = true,
        automatic = true
    }
}

function ServicesPlus.Ok(data)
    return { success = true, data = data }
end

function ServicesPlus.Error(code, message, retryable)
    return {
        success = false,
        error = {
            code = code,
            message = message,
            retryable = retryable == true
        }
    }
end

-- Masks a citizen phone number for employee-facing views, keeping only the last
-- four characters. Returns nil for a missing number (e.g. a hidden/anonymous
-- caller), which the frontend renders as an unknown-number placeholder.
function ServicesPlus.MaskNumber(number)
    if type(number) ~= "string" or number == "" then return nil end
    if #number <= 4 then return number end
    return ("*"):rep(#number - 4) .. number:sub(-4)
end

-- oxmysql does not consistently return TINYINT(1) columns as the Lua number 1/0 -
-- depending on version/driver it can hand back a native boolean or a numeric string
-- instead, and a bare `value == 1` silently evaluates to false for both of those. Every
-- TINYINT(1)/boolean column read from the database must be converted through this
-- instead of compared directly.
function ServicesPlus.ToBool(value)
    return value == 1 or value == "1" or value == true
end
