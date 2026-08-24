-- Persistent badge events for state changes that cannot be represented by
-- a source table's row id alone. A request keeps the same id as its status
-- changes, and a call may become missed after a player has already opened
-- the Calls tab. Each transition therefore gets its own monotonic event id.
Unread = {}

local VALID_SCOPES = {
    activity_requests = true,
    activity_calls = true,
    company_calls = true,
}

---@param scope string
---@param ownerKey string? customer phone for Activity; empty for company-wide events
---@param companyId number?
---@param eventKey string stable idempotency key such as request:12:active
---@return number|false event id, or false when this event already existed
function Unread.Push(scope, ownerKey, companyId, eventKey)
    if not VALID_SCOPES[scope] or type(eventKey) ~= "string" or eventKey == "" then return false end

    local id = MySQL.insert.await([[
        INSERT IGNORE INTO phone_services_plus_unread_events
            (scope, owner_key, company_id, event_key)
        VALUES (?, ?, ?, ?)
    ]], { scope, ownerKey or "", tonumber(companyId) or 0, eventKey:sub(1, 100) })

    id = tonumber(id)
    return id and id > 0 and id or false
end

---@param scope string
---@param eventOwnerKey string? owner stored on the event (empty for company-wide events)
---@param companyId number?
---@param readerOwnerKey string phone number or employee identifier owning the read marker
---@return number
function Unread.CountForReader(scope, eventOwnerKey, companyId, readerOwnerKey)
    if not VALID_SCOPES[scope] or not readerOwnerKey then return 0 end

    return tonumber(MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM phone_services_plus_unread_events e
        LEFT JOIN phone_services_plus_read_state rs
          ON rs.owner_key = ? AND rs.scope = ? AND rs.company_id = ?
        WHERE e.scope = ? AND e.owner_key = ? AND e.company_id = ?
          AND e.id > COALESCE(rs.last_read_id, 0)
    ]], {
        readerOwnerKey, scope, tonumber(companyId) or 0,
        scope, eventOwnerKey or "", tonumber(companyId) or 0,
    })) or 0
end

---@param scope string
---@param ownerKey string?
---@param companyId number?
---@return number
function Unread.LatestId(scope, ownerKey, companyId)
    if not VALID_SCOPES[scope] then return 0 end

    return tonumber(MySQL.scalar.await([[
        SELECT COALESCE(MAX(id), 0)
        FROM phone_services_plus_unread_events
        WHERE scope = ? AND owner_key = ? AND company_id = ?
    ]], { scope, ownerKey or "", tonumber(companyId) or 0 })) or 0
end

function Unread.IsScope(scope)
    return VALID_SCOPES[scope] == true
end
