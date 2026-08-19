-- =============================================================================
-- MapPlus – GPS Route Sampler
-- Sends mapplus:playerUpdate every tick (lightweight).
-- Sends mapplus:routeUpdate only when route actually changes.
-- =============================================================================

local cachedRoute       = {}
local cachedDest        = nil
local lastClosestIndex  = 1
local staleCount        = 0   -- consecutive failed resamples
local MAX_STALE         = 3   -- hide route after this many failed attempts
local routeVersion      = 0   -- increments on every successful new route

local function getWaypointDestination()
    local waypointBlip = GetFirstBlipInfoId(8)
    if DoesBlipExist(waypointBlip) then
        local coords = GetBlipInfoIdCoord(waypointBlip)
        if coords and (coords.x ~= 0.0 or coords.y ~= 0.0) then
            return { x = coords.x, y = coords.y }
        end
    end
    return nil
end

-- Pick the best slot by scoring how well its endpoints match player+destination
local function scoreSlotPoints(points, playerCoords, destination)
    if #points < 2 then return 999999.0 end
    local first = points[1]
    local last  = points[#points]
    local dFirst = #(vector2(first.x, first.y) - vector2(playerCoords.x, playerCoords.y))
    local dLast  = destination
        and #(vector2(last.x, last.y) - vector2(destination.x, destination.y))
        or 0.0
    return dFirst + dLast
end

local function sampleGpsRoute(playerCoords, destination)
    local directDist = destination
        and #(vector2(playerCoords.x, playerCoords.y) - vector2(destination.x, destination.y))
        or 2000.0

    -- Give GTA 2.5× the direct distance, capped between 2km and 30km
    local maxDistance = math.min(math.max(directDist * 2.5, 2000.0), 30000.0)
    local step        = 8.0

    local bestPoints = {}
    local bestScore  = 999999.0

    for _, slot in ipairs({ 0, 1 }) do
        local points            = {}
        local distance          = 0.0
        local lastPoint         = nil
        local consecutiveFails  = 0

        while distance <= maxDistance and consecutiveFails < 6 do
            local success, coords = GetPosAlongGpsTypeRoute(true, distance, slot)
            if (success == true or success == 1)
                and coords
                and (coords.x ~= 0.0 or coords.y ~= 0.0)
            then
                consecutiveFails = 0
                if not lastPoint
                    or #(vector2(lastPoint.x, lastPoint.y) - vector2(coords.x, coords.y)) > 2.0
                then
                    table.insert(points, { x = coords.x, y = coords.y })
                    lastPoint = coords
                end
            else
                consecutiveFails = consecutiveFails + 1
            end
            distance = distance + step
        end

        -- Optionally snap final point to destination if within arm's reach
        if destination and lastPoint then
            local distToDest = #(vector2(lastPoint.x, lastPoint.y) - vector2(destination.x, destination.y))
            if distToDest > 3.0 and distToDest < 60.0 then
                table.insert(points, { x = destination.x, y = destination.y })
            end
        end

        local score = scoreSlotPoints(points, playerCoords, destination)
        if score < bestScore then
            bestScore  = score
            bestPoints = points
        end
    end

    return bestPoints
end

-- Monotone window search – prevents route from jumping on parallel roads / loops
local function findClosestRouteIndex(playerPos, points, lastIdx)
    local windowStart = math.max(1, lastIdx - 10)
    local windowEnd   = math.min(#points, lastIdx + 80)

    local closestIdx = lastIdx
    local minDist    = 999999.0

    for i = windowStart, windowEnd do
        local d = #(vector2(playerPos.x, playerPos.y) - vector2(points[i].x, points[i].y))
        if d < minDist then
            minDist    = d
            closestIdx = i
        end
    end

    -- Global fallback only when far off the known window
    if minDist > 45.0 then
        for i = 1, #points do
            local d = #(vector2(playerPos.x, playerPos.y) - vector2(points[i].x, points[i].y))
            if d < minDist then
                minDist    = d
                closestIdx = i
            end
        end
    end

    return closestIdx, minDist
end

local function destChanged(destination)
    if destination == nil and cachedDest == nil then return false end
    if destination == nil or cachedDest == nil then return true end
    return #(vector2(destination.x, destination.y) - vector2(cachedDest.x, cachedDest.y)) > 5.0
end

CreateThread(function()
    local lastRouteVersion    = -1
    local currentRoutePoints  = {}

    while true do
        Wait(300)

        local playerPed     = PlayerPedId()
        local playerCoords  = GetEntityCoords(playerPed)
        local playerHeading = GetEntityHeading(playerPed)
        local destination   = getWaypointDestination()
        local isNavActive   = IsWaypointActive() or destination ~= nil

        -- ── Player update (always, every tick) ──────────────────────────────
        SendNUIMessage({
            action = "mapplus:playerUpdate",
            player = {
                x       = playerCoords.x,
                y       = playerCoords.y,
                heading = playerHeading,
            },
        })

        -- ── Route logic ─────────────────────────────────────────────────────
        if not isNavActive then
            if #cachedRoute > 0 then
                cachedRoute      = {}
                cachedDest       = nil
                lastClosestIndex = 1
                staleCount       = 0
                routeVersion     = routeVersion + 1
                SendNUIMessage({
                    action      = "mapplus:routeUpdate",
                    points      = {},
                    destination = nil,
                })
            end
        else
            local needsResample = (#cachedRoute == 0) or destChanged(destination)

            if not needsResample and #cachedRoute > 1 then
                local closestIdx, minDist = findClosestRouteIndex(playerCoords, cachedRoute, lastClosestIndex)
                lastClosestIndex = closestIdx

                if minDist > 45.0 then
                    needsResample = true
                else
                    -- Trim consumed portion of route (do NOT prepend player position)
                    local remaining = {}
                    for i = closestIdx, #cachedRoute do
                        remaining[#remaining + 1] = cachedRoute[i]
                    end
                    currentRoutePoints = remaining
                end
            end

            if needsResample then
                local freshPoints = sampleGpsRoute(playerCoords, destination)
                if #freshPoints > 1 then
                    staleCount        = 0
                    cachedRoute       = freshPoints
                    cachedDest        = destination
                    lastClosestIndex  = 1
                    currentRoutePoints = freshPoints
                    routeVersion      = routeVersion + 1
                else
                    staleCount = staleCount + 1
                    if staleCount >= MAX_STALE then
                        -- Give up showing a stale route; let NUI clear it
                        currentRoutePoints = {}
                        routeVersion       = routeVersion + 1
                    end
                end
            end

            -- Only send route message when it actually changed
            if routeVersion ~= lastRouteVersion then
                lastRouteVersion = routeVersion
                SendNUIMessage({
                    action      = "mapplus:routeUpdate",
                    points      = currentRoutePoints,
                    destination = destination,
                })
            end
        end
    end
end)
