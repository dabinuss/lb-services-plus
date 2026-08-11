--[[
    Small server-only helpers shared across files. Kept separate from
    shared/ since these are never needed client-side.
]]

local MAX_PAGE = 10000 -- guards against a manipulated client sending a huge OFFSET

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
