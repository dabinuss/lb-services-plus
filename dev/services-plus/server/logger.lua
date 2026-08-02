ServicesPlus.Logger = ServicesPlus.Logger or {}

local Logger = ServicesPlus.Logger

local function write(level, message, context)
    if level == "DEBUG" and not Config.Debug then return end
    local suffix = context and (" " .. json.encode(context)) or ""
    print(("[services-plus] [%s] %s%s"):format(level, message, suffix))
end

function Logger.Debug(message, context) write("DEBUG", message, context) end
function Logger.Info(message, context) write("INFO", message, context) end
function Logger.Warn(message, context) write("WARN", message, context) end
function Logger.Error(message, context) write("ERROR", message, context) end
