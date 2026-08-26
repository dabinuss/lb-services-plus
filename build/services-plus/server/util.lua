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

--- Validates a keyset-pagination cursor supplied by NUI. List queries expose
--- their timestamp as a numeric UNIX value, so clients never need to send a
--- driver-specific DATETIME representation back to MySQL.
---@param cursor any
---@return table?
function NormalizeListCursor(cursor)
    if type(cursor) ~= "table" then return nil end

    local id = math.floor(tonumber(cursor.id) or 0)
    local timestamp = tonumber(cursor.time)
    if id < 1 or not timestamp or timestamp ~= timestamp or timestamp < 0 or timestamp > 4102444800 then return nil end

    return {
        id = id,
        time = timestamp,
        open = DatabaseBoolean(cursor.open) and 1 or 0,
    }
end

--- Normalizes MySQL boolean columns across drivers. oxmysql can return
--- TINYINT(1) as Lua booleans while other adapters return 0/1 numbers.
---@param value any
---@return boolean
function DatabaseBoolean(value)
    return value == true or value == 1 or value == "1"
end

--- Validates UTF-8 and measures user-facing text in Unicode code points
--- rather than bytes. MySQL's utf8mb4 VARCHAR limits use characters too.
---@param value any
---@param minLength number
---@param maxLength number
---@return boolean
---@return number?
function IsValidUtf8Length(value, minLength, maxLength)
    if type(value) ~= "string" then return false end
    local ok, length = pcall(utf8.len, value)
    if not ok or not length or length < minLength or length > maxLength then return false end
    return true, length
end

--- Truncates valid UTF-8 at a character boundary.
---@param value string
---@param maxLength number
---@return string?
function TruncateUtf8(value, maxLength)
    local valid, length = IsValidUtf8Length(value, 0, math.maxinteger)
    if not valid then return nil end
    if length <= maxLength then return value end

    local nextCharacter = utf8.offset(value, maxLength + 1)
    return nextCharacter and value:sub(1, nextCharacter - 1) or value
end

--- Safely resolves the currently connected source that owns a phone number.
--- LB Phone may throw while stopping/restarting, so every caller shares the
--- same guarded lookup and online-player validation.
---@param phoneNumber string?
---@return number?
function ResolvePhoneSource(phoneNumber)
    if type(phoneNumber) ~= "string" or phoneNumber == "" then return nil end
    local ok, playerSource = pcall(function()
        return exports["lb-phone"]:GetSourceFromNumber(phoneNumber)
    end)
    playerSource = ok and tonumber(playerSource) or nil
    return playerSource and playerSource > 0 and GetPlayerName(playerSource) ~= nil and playerSource or nil
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
