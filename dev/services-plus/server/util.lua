--[[
    Small server-only helpers shared across files. Kept separate from
    shared/ since these are never needed client-side.
]]

-- Guards against a manipulated client sending a huge OFFSET. 200 pages at
-- 25 rows/page is already 5000 rows deep - nobody legitimately paginates
-- that far by hand, and a real "browse everything" need should get a
-- cursor-based query instead of a bigger page number (plan review round 2 §8).
local MAX_PAGE = 200

--- Coerces an NUI-supplied `page` value into a safe, bounded non-negative
--- integer. A modified client can send negative numbers, floats, strings or
--- absurdly large values - all of that gets sanitized here instead of at
--- every call site.
---@param page any
---@return number
function ClampPage(page)
    page = math.floor(tonumber(page) or 0)

    if page < 0 then page = 0 end
    if page > MAX_PAGE then page = MAX_PAGE end

    return page
end

--- Normalizes MySQL boolean columns across drivers. oxmysql can return
--- TINYINT(1) as Lua booleans while other adapters return 0/1 numbers.
---@param value any
---@return boolean
function DatabaseBoolean(value)
    return value == true or value == 1 or value == "1"
end

local supportedLocales = { en = true, de = true }
local localeByNumber = {}

---@param locale any
---@return "en"|"de"
function NormalizeServicesLocale(locale)
    locale = type(locale) == "string" and locale:lower() or ""
    if supportedLocales[locale] then return locale end

    local configured = type(Config.Locale) == "string" and Config.Locale:lower() or "en"
    return supportedLocales[configured] and configured or "en"
end

---@param phoneNumber string
---@return "en"|"de"
function GetServicesLocale(phoneNumber)
    if type(phoneNumber) ~= "string" or phoneNumber == "" then
        return NormalizeServicesLocale(Config.Locale)
    end

    if localeByNumber[phoneNumber] then return localeByNumber[phoneNumber] end

    local locale = MySQL.scalar.await(
        "SELECT locale FROM phone_services_plus_preferences WHERE phone_number = ?",
        { phoneNumber }
    )
    locale = NormalizeServicesLocale(locale)
    localeByNumber[phoneNumber] = locale
    return locale
end

---@param phoneNumber string
---@param locale any
---@return boolean
function SetServicesLocale(phoneNumber, locale)
    if type(phoneNumber) ~= "string" or phoneNumber == "" then return false end
    locale = NormalizeServicesLocale(locale)

    MySQL.update.await([[
        INSERT INTO phone_services_plus_preferences (phone_number, locale)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE locale = VALUES(locale)
    ]], { phoneNumber, locale })

    localeByNumber[phoneNumber] = locale
    return true
end

---@param phoneNumber string
---@param key string
---@param vars? table<string, string|number>
---@return string
function LForNumber(phoneNumber, key, vars)
    return LFor(GetServicesLocale(phoneNumber), key, vars)
end
