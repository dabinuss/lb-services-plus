local function invokingOwner()
    local owner = GetInvokingResource()
    if type(owner) ~= "string" or owner == "" then return nil end
    return owner
end

exports("ShowPeek", function(spec)
    local owner = invokingOwner()
    if not owner then return nil, "missing_invoking_resource" end
    return PeekPlus.Show(spec, owner)
end)

exports("UpdatePeek", function(id, patch, expectedRevision, actionToken)
    local owner = invokingOwner()
    if not owner then return false, "missing_invoking_resource" end
    return PeekPlus.Update(id, patch, owner, expectedRevision, actionToken)
end)

exports("UpdatePeekPresentation", function(id, patch)
    local owner = invokingOwner()
    if not owner then return false, "missing_invoking_resource" end
    return PeekPlus.UpdatePresentation(id, patch, owner)
end)

exports("RemovePeek", function(id, expectedRevision, actionToken, reason)
    local owner = invokingOwner()
    if not owner then return false, "missing_invoking_resource" end
    return PeekPlus.Remove(id, owner, expectedRevision, actionToken, reason)
end)

exports("ClearPeeks", function()
    local owner = invokingOwner()
    if not owner then return false, "missing_invoking_resource" end
    return PeekPlus.ClearOwner(owner)
end)

exports("ReleasePeekAction", function(id, actionToken)
    local owner = invokingOwner()
    if not owner then return false, "missing_invoking_resource" end
    return PeekPlus.ReleaseAction(id, owner, actionToken)
end)

exports("ResolvePeekAction", function(id, actionToken, expectedRevision, resolution)
    local owner = invokingOwner()
    if not owner then return false, "missing_invoking_resource" end
    return PeekPlus.ResolveAction(id, owner, actionToken, expectedRevision, resolution)
end)

exports("GetPeek", function(id)
    local owner = invokingOwner()
    if not owner then return nil, "missing_invoking_resource" end
    return PeekPlus.Get(id, owner)
end)

exports("GetPeekHistory", function()
    local owner = invokingOwner()
    if not owner then return nil, "missing_invoking_resource" end
    return PeekPlus.GetHistory(owner)
end)

exports("MarkPeekHistoryRead", function(historyId, read)
    local owner = invokingOwner()
    if not owner then return false, "missing_invoking_resource" end
    return PeekPlus.MarkHistoryRead(historyId, owner, read)
end)

exports("ClearPeekHistory", function(historyId)
    local owner = invokingOwner()
    if not owner then return false, "missing_invoking_resource" end
    return PeekPlus.ClearHistory(owner, historyId)
end)

exports("RegisterPeekTemplate", function(name, definition)
    local owner = invokingOwner()
    if not owner then return nil, "missing_invoking_resource" end
    return PeekPlus.RegisterTemplate(owner, name, definition)
end)

exports("UnregisterPeekTemplate", function(name)
    local owner = invokingOwner()
    if not owner then return false, "missing_invoking_resource" end
    return PeekPlus.UnregisterTemplate(owner, name)
end)
