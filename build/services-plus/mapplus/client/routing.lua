local currentRoutePoints = {}
local cachedRoute = {}
local cachedDest = nil

local function getWaypointDestination()
    local waypointBlip = GetFirstBlipInfoId(8) -- 8 = Waypoint
    if DoesBlipExist(waypointBlip) then
        local coords = GetBlipInfoIdCoord(waypointBlip)
        if coords and (coords.x ~= 0.0 or coords.y ~= 0.0) then
            return { x = coords.x, y = coords.y }
        end
    end
    return nil
end

local function sampleGpsRoute(destination)
    local points = {}
    local slots = { 0, 1 }
    
    for _, slot in ipairs(slots) do
        local distance = 0.0
        local maxDistance = 30000.0
        local step = 8.0
        local lastPoint = nil
        local consecutiveFails = 0
        
        while distance <= maxDistance and consecutiveFails < 6 do
            local success, coords = GetPosAlongGpsTypeRoute(true, distance, slot)
            if (success == true or success == 1) and coords and (coords.x ~= 0.0 or coords.y ~= 0.0) then
                consecutiveFails = 0
                if not lastPoint or #(vector2(lastPoint.x, lastPoint.y) - vector2(coords.x, coords.y)) > 2.0 then
                    table.insert(points, { x = coords.x, y = coords.y })
                    lastPoint = coords
                end
            else
                consecutiveFails = consecutiveFails + 1
            end
            distance = distance + step
        end
        
        if #points > 1 then
            -- Only connect the last few meters to destination if path actually reached it
            if destination and lastPoint then
                local distToDest = #(vector2(lastPoint.x, lastPoint.y) - vector2(destination.x, destination.y))
                if distToDest > 3.0 and distToDest < 60.0 then
                    table.insert(points, { x = destination.x, y = destination.y })
                end
            end
            return points
        end
        points = {}
    end
    return points
end

local function findClosestRouteIndex(playerPos, points)
    local closestIdx = 1
    local minDist = 999999.0
    for i = 1, #points do
        local d = #(vector2(playerPos.x, playerPos.y) - vector2(points[i].x, points[i].y))
        if d < minDist then
            minDist = d
            closestIdx = i
        end
    end
    return closestIdx, minDist
end

CreateThread(function()
    while true do
        Wait(300)
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local playerHeading = GetEntityHeading(playerPed)
        local destination = getWaypointDestination()
        
        local isNavActive = IsWaypointActive() or destination ~= nil
        
        if isNavActive then
            local destChanged = false
            if destination and cachedDest then
                destChanged = #(vector2(destination.x, destination.y) - vector2(cachedDest.x, cachedDest.y)) > 5.0
            elseif destination ~= cachedDest then
                destChanged = true
            end
            
            local needsResample = (#cachedRoute == 0) or destChanged
            
            if not needsResample and #cachedRoute > 1 then
                local closestIdx, minDist = findClosestRouteIndex(playerCoords, cachedRoute)
                if minDist > 45.0 then
                    -- Player diverged from route, resample from GTA
                    needsResample = true
                else
                    -- Smoothly advance route ahead of player
                    local remaining = { { x = playerCoords.x, y = playerCoords.y } }
                    for i = closestIdx, #cachedRoute do
                        table.insert(remaining, cachedRoute[i])
                    end
                    currentRoutePoints = remaining
                end
            end
            
            if needsResample then
                local freshPoints = sampleGpsRoute(destination)
                if #freshPoints > 1 then
                    cachedRoute = freshPoints
                    cachedDest = destination
                    currentRoutePoints = freshPoints
                end
            end
        else
            currentRoutePoints = {}
            cachedRoute = {}
            cachedDest = nil
        end
        
        -- Always send live player updates even when navigation ends
        SendNUIMessage({
            action = "mapplus:routeUpdate",
            points = currentRoutePoints,
            destination = destination,
            player = {
                x = playerCoords.x,
                y = playerCoords.y,
                heading = playerHeading
            }
        })
    end
end)
