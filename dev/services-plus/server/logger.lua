ServicesPlus.Logger = ServicesPlus.Logger or {}

local Logger = ServicesPlus.Logger
local levels = { DEBUG = 1, INFO = 2, WARNING = 3, WARN = 3, ERROR = 4 }

local function write(level, message, context)
    local configured = tostring(Config.LogLevel or "info"):upper()
    local minimum = Config.Debug and levels.DEBUG or (levels[configured] or levels.INFO)
    if (levels[level] or levels.INFO) < minimum then return end
    local suffix = context and (" " .. json.encode(context)) or ""
    print(("[services-plus] [%s] %s%s"):format(level, message, suffix))
end

function Logger.Debug(message, context) write("DEBUG", message, context) end
function Logger.Info(message, context) write("INFO", message, context) end
function Logger.Warn(message, context) write("WARNING", message, context) end
function Logger.Error(message, context) write("ERROR", message, context) end
