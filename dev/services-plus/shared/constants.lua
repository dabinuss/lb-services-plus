ServicesPlus = ServicesPlus or {}

ServicesPlus.Constants = {
    ResourceName = "services-plus",
    AppIdentifier = "services-plus",
    ApiVersion = 4,
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
