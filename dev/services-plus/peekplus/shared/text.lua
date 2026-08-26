-- Shared UTF-8 text validation for every PeekPlus presentation field.
-- Limits are Unicode code points, while explicitly byte-based payload
-- limits (for example maxTemplateDataBytes) stay byte-based by design.
PeekPlusText = {}

---@param value any
---@param maximum number
---@param required boolean
---@return string?
---@return string? errorCode
function PeekPlusText.Clean(value, maximum, required)
    if value == nil and not required then return nil end
    if type(value) ~= "string" then return nil, "invalid_text" end

    value = value:gsub("[%z\1-\8\11\12\14-\31]", "")
    if required and value == "" then return nil, "empty_text" end

    local ok, length = pcall(utf8.len, value)
    if not ok or not length then return nil, "invalid_text" end
    if length > maximum then return nil, "text_too_long" end

    return value
end
