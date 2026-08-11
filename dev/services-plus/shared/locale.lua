-- Minimal locale helper. Keeps Services+ independent from any specific
-- translation library (ox_lib, etc.) so it stays usable standalone.
Locales = Locales or {}

local loaded = {}
local fallback = "en"

local function loadFile(lang)
    if loaded[lang] then return loaded[lang] end

    local raw = LoadResourceFile(GetCurrentResourceName(), ("locales/%s.json"):format(lang))
    local decoded = raw and json.decode(raw) or {}

    loaded[lang] = decoded
    return decoded
end

local current = loadFile(Config.Locale) or {}
local fallbackTable = Config.Locale ~= fallback and loadFile(fallback) or current

---@param key string dot.notation path, e.g. "app.title"
---@param vars? table<string, string|number> values to interpolate as {var}
function L(key, vars)
    local value = current[key] or fallbackTable[key] or key

    if vars then
        value = value:gsub("{(%w+)}", function(token)
            local replacement = vars[token]
            return replacement ~= nil and tostring(replacement) or ("{" .. token .. "}")
        end)
    end

    return value
end
