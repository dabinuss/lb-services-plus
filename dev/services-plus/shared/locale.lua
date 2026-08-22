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

---@param lang string
---@param key string dot.notation path, e.g. "app.title"
---@param vars? table<string, string|number> values to interpolate as {var}
function LFor(lang, key, vars)
    lang = type(lang) == "string" and lang:lower() or fallback
    local selected = loadFile(lang)
    local fallbackTable = lang ~= fallback and loadFile(fallback) or selected
    local value = selected[key] or fallbackTable[key] or key

    if vars then
        value = value:gsub("{(%w+)}", function(token)
            local replacement = vars[token]
            return replacement ~= nil and tostring(replacement) or ("{" .. token .. "}")
        end)
    end

    return value
end

---@param key string
---@param vars? table<string, string|number>
function L(key, vars)
    return LFor(Config.Locale, key, vars)
end
