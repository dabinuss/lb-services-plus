ServicesPlus = ServicesPlus or {}

ServicesPlus.Constants = {
    ResourceName = "services-plus",
    AppIdentifier = "services-plus",
    ApiVersion = 1,
    EmployeeStatuses = {
        available = true,
        busy = true,
        on_break = true,
        off_duty = true
    },
    MutableEmployeeStatuses = {
        available = true,
        on_break = true
    },
    DistributionModes = {
        ring_all = true,
        random = true,
        dispatch_only = true
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
