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

exports("RemovePeek", function(id, expectedRevision, actionToken)
    local owner = invokingOwner()
    if not owner then return false, "missing_invoking_resource" end
    return PeekPlus.Remove(id, owner, expectedRevision, actionToken)
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

exports("GetPeek", function(id)
    local owner = invokingOwner()
    if not owner then return nil, "missing_invoking_resource" end
    return PeekPlus.Get(id, owner)
end)
