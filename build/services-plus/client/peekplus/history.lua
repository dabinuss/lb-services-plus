RegisterNUICallback("peekplusGetHistory", function(_, callback)
    callback(PeekPlus.GetHistory())
end)

RegisterNUICallback("peekplusMarkHistoryRead", function(data, callback)
    local id = type(data) == "table" and tonumber(data.id) or nil
    local ok, err, changed = PeekPlus.MarkHistoryRead(id, nil, type(data) ~= "table" or data.read ~= false)
    callback({ ok = ok, error = err, changed = changed })
end)

RegisterNUICallback("peekplusClearHistory", function(data, callback)
    local id = type(data) == "table" and tonumber(data.id) or nil
    local ok, err, changed = PeekPlus.ClearHistory(nil, id)
    callback({ ok = ok, error = err, changed = changed })
end)
