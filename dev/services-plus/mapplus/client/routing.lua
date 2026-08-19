-- =============================================================================
-- MapPlus – GPS Route Sampler  (Round 2)
-- Key changes:
--   • isRouteComplete() validation – incomplete routes never replace a good cache
--   • GetGpsBlipRouteLength() as primary maxDistance source
--   • Global fallback in findClosestRouteIndex() removed – bad proximity → resample
--   • Route-trim update every ~40m of progress (not only on full reroute)
--   • Slot selected only from validated (complete) candidates
--   • Destination snap threshold tightened to 15m
-- =============================================================================

local cachedRoute        = {}
local cachedDest         = nil
local lastClosestIndex   = 1
local lastSentClosestIndex = 1   -- tracks when to push a trim update
local staleCount         = 0
local MAX_STALE          = 3
local routeVersion       = 0
local TRIM_STEP          = 5     -- send trim update every 5 route points ≈ 40m at 8m/step

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

-- A route is only valid when its last point is within 100m of the destination.
-- This prevents accepting GPS samples that ran out before reaching the target.
local function isRouteComplete(points, destination)
    if not destination or #points < 2 then return false end
    local last = points[#points]
    local dist = #(vector2(last.x, last.y) - vector2(destination.x, destination.y))
    return dist < 100.0
end

-- Score how well a set of GPS points aligns with player start and destination end.
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
    -- Use GTA's actual GPS route length when available (most accurate)
    local gtaRouteLength = 0.0
    local ok, rLen = pcall(GetGpsBlipRouteLength)
    if ok and type(rLen) == 'number' and rLen > 0 then
        gtaRouteLength = rLen
    end

    local directDist = destination
        and #(vector2(playerCoords.x, playerCoords.y) - vector2(destination.x, destination.y))
        or 2000.0

    local maxDistance
    if gtaRouteLength > 0 then
        -- Add 100m buffer; GTA may not place the final sample exactly at the destination
        maxDistance = gtaRouteLength + 100.0
    else
        -- Fallback: 2.5× air-line distance, capped 2km–30km
        maxDistance = math.min(math.max(directDist * 2.5, 2000.0), 30000.0)
    end

    local step                = 8.0
    local MAX_CONSECUTIVE_FAILS = 15   -- tolerate longer gaps (bridges, tunnels)

    local bestPoints = {}
    local bestScore  = 999999.0
    local anyValid   = false

    for _, slot in ipairs({ 0, 1 }) do
        local points           = {}
        local distance         = 0.0
        local lastPoint        = nil
        local consecutiveFails = 0

        while distance <= maxDistance and consecutiveFails < MAX_CONSECUTIVE_FAILS do
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

        -- Snap last point to destination only when very close (≤15m) to avoid diagonal
        if destination and lastPoint then
            local distToDest = #(vector2(lastPoint.x, lastPoint.y) - vector2(destination.x, destination.y))
            if distToDest > 1.0 and distToDest <= 15.0 then
                table.insert(points, { x = destination.x, y = destination.y })
            end
        end

        -- Only consider this slot if the route actually reaches the destination
        if isRouteComplete(points, destination) then
            anyValid = true
            local score = scoreSlotPoints(points, playerCoords, destination)
            if score < bestScore then
                bestScore  = score
                bestPoints = points
            end
        end
    end

    -- If no slot produced a complete route, return empty to signal failure
    if not anyValid then
        return {}
    end
    return bestPoints
end

-- Monotone window search.
-- IMPORTANT: global fallback removed. If minDist > 45m the caller triggers a resample.
-- This prevents route jumping on parallel roads and loops.
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

    -- No global fallback: if we're too far from the window, just return lastIdx
    -- The caller will see minDist > 45 and trigger a resample.
    return closestIdx, minDist
end

local function destChanged(destination)
    if destination == nil and cachedDest == nil then return false end
    if destination == nil or cachedDest == nil then return true end
    return #(vector2(destination.x, destination.y) - vector2(cachedDest.x, cachedDest.y)) > 5.0
end

CreateThread(function()
    local lastRouteVersion   = -1
    local currentRoutePoints = {}

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
            player = { x = playerCoords.x, y = playerCoords.y, heading = playerHeading },
        })

        -- ── Route logic ─────────────────────────────────────────────────────
        if not isNavActive then
            if #cachedRoute > 0 then
                cachedRoute            = {}
                cachedDest             = nil
                lastClosestIndex       = 1
                lastSentClosestIndex   = 1
                staleCount             = 0
                routeVersion           = routeVersion + 1
                SendNUIMessage({ action = "mapplus:routeUpdate", points = {}, destination = nil })
            end
        else
            local needsResample = (#cachedRoute == 0) or destChanged(destination)

            if not needsResample and #cachedRoute > 1 then
                local closestIdx, minDist = findClosestRouteIndex(playerCoords, cachedRoute, lastClosestIndex)
                lastClosestIndex = closestIdx

                if minDist > 45.0 then
                    -- Too far from known route window → reroute instead of jumping
                    needsResample = true
                else
                    -- Build trimmed remaining route (no player position prepended)
                    local remaining = {}
                    for i = closestIdx, #cachedRoute do
                        remaining[#remaining + 1] = cachedRoute[i]
                    end
                    currentRoutePoints = remaining

                    -- Send trim update every ~40m of forward progress
                    if closestIdx - lastSentClosestIndex >= TRIM_STEP then
                        lastSentClosestIndex = closestIdx
                        routeVersion = routeVersion + 1
                    end
                end
            end

            if needsResample then
                local freshPoints = sampleGpsRoute(playerCoords, destination)
                if #freshPoints > 1 then
                    -- freshPoints is already validated complete by sampleGpsRoute
                    staleCount           = 0
                    cachedRoute          = freshPoints
                    cachedDest           = destination
                    lastClosestIndex     = 1
                    lastSentClosestIndex = 1
                    currentRoutePoints   = freshPoints
                    routeVersion         = routeVersion + 1
                else
                    staleCount = staleCount + 1
                    if staleCount >= MAX_STALE then
                        -- Give up on stale route; clear the display
                        currentRoutePoints   = {}
                        cachedRoute          = {}
                        lastSentClosestIndex = 1
                        routeVersion         = routeVersion + 1
                    end
                end
            end

            -- Only send route message when something actually changed
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
