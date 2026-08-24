-- Minimal locale helper. Keeps Services+ independent from any specific
-- translation library (ox_lib, etc.) so it stays usable standalone.
Locales = Locales or {}

local loaded = {}
local fallback = "en"
-- Capture this while the shared script is loaded by Services+ so callbacks
-- and server exports always resolve the owning resource.
local resourceName = GetCurrentResourceName()

local function readServerFile(path)
    if not IsDuplicityVersion() or type(io) ~= "table" or type(io.open) ~= "function" then return nil end
    local root = GetResourcePath(resourceName)
    if type(root) ~= "string" or root == "" then return nil end

    local handle = io.open(root .. "/" .. path, "rb")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function loadFile(lang)
    if loaded[lang] then return loaded[lang] end

    local path = ("locales/%s.json"):format(lang)
    -- LoadResourceFile can return nil for non-script files when a local
    -- Windows resource is mounted through an NTFS junction. Server-side we
    -- can still read the same fixed, resource-relative file safely.
    local raw = LoadResourceFile(resourceName, path) or readServerFile(path)
    local decoded
    if raw then
        local ok, result = pcall(json.decode, raw)
        if ok then decoded = result end
    end
    if type(decoded) ~= "table" then
        print(("^1[services-plus] Could not load locale file %s/%s.^7"):format(resourceName, path))
        decoded = {}
    end

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
