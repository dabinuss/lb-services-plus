-- =============================================================================
-- MapPlus – GPS Route Sampler (v46)
-- High-precision 5m curve sampling, slot optimization, smart route completeness
-- =============================================================================

local cachedRoute          = {}
local cachedDest           = nil
local lastClosestIndex     = 1
local lastSentClosestIndex = 1   -- tracks when to push a trim update
local lastGoodSlot         = 0   -- cached slot (0 or 1) to halve sampling calls
local staleSince           = nil -- GetGameTimer() timestamp of first failed resample; nil = healthy
local STALE_GRACE_MS       = 2500-- ms to show old route before clearing after failed resamples
local routeVersion         = 0
local TRIM_STEP            = 8   -- send trim update every 8 route points ≈ 40m at 5m/step

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

-- Smart route completion validation:
-- If GTA reported a GPS route length, we verify we sampled almost to the end (within 25m of total length).
-- If not, fallback to checking distance from the last node to destination (< 100m).
local function isRouteComplete(points, destination, gtaRouteLength, lastSuccessfulDist)
    if not points or #points < 2 then return false end
    if gtaRouteLength > 0 and lastSuccessfulDist > 0 then
        return lastSuccessfulDist >= (gtaRouteLength - 25.0)
    end
    if destination then
        local last = points[#points]
        local dist = #(vector2(last.x, last.y) - vector2(destination.x, destination.y))
        return dist < 100.0
    end
    return true
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
        -- Add 100m buffer for safe sampling past the destination blip
        maxDistance = gtaRouteLength + 100.0
    else
        -- Fallback: 2.5× air-line distance, capped 2km–30km
        maxDistance = math.min(math.max(directDist * 2.5, 2000.0), 30000.0)
    end

    local step                  = 5.0  -- 5.0m step for razor-sharp curve tracing without clipping
    local MAX_CONSECUTIVE_FAILS = 15   -- tolerate bridges, junctions and tunnels

    local bestPoints = {}
    local bestScore  = 999999.0
    local anyValid   = false

    -- Try last good slot first to halve sampling cost when route is stable
    local slotsToTry = { lastGoodSlot, (lastGoodSlot == 0) and 1 or 0 }

    for _, slot in ipairs(slotsToTry) do
        local points               = {}
        local distance             = 0.0
        local lastPoint            = nil
        local lastSuccessfulDist   = 0.0
        local consecutiveFails     = 0

        while distance <= maxDistance and consecutiveFails < MAX_CONSECUTIVE_FAILS do
            local success, coords = GetPosAlongGpsTypeRoute(true, distance, slot)
            if (success == true or success == 1)
                and coords
                and (coords.x ~= 0.0 or coords.y ~= 0.0)
            then
                consecutiveFails = 0
                lastSuccessfulDist = distance
                if not lastPoint
                    or #(vector2(lastPoint.x, lastPoint.y) - vector2(coords.x, coords.y)) > 1.5
                then
                    table.insert(points, { x = coords.x, y = coords.y })
                    lastPoint = coords
                end
            else
                consecutiveFails = consecutiveFails + 1
            end
            distance = distance + step
        end

        -- Snap last point to destination only when very close (≤15m) to avoid diagonal cuts
        if destination and lastPoint then
            local distToDest = #(vector2(lastPoint.x, lastPoint.y) - vector2(destination.x, destination.y))
            if distToDest > 1.0 and distToDest <= 15.0 then
                table.insert(points, { x = destination.x, y = destination.y })
            end
        end

        -- Only consider this slot if the route actually reaches the destination
        if isRouteComplete(points, destination, gtaRouteLength, lastSuccessfulDist) then
            anyValid = true
            local score = scoreSlotPoints(points, playerCoords, destination)
            if score < bestScore then
                bestScore    = score
                bestPoints   = points
                lastGoodSlot = slot
            end
            -- If the primary slot was complete and starts right at the player (< 25m), finish immediately
            local firstPt = points[1]
            local startDist = #(vector2(firstPt.x, firstPt.y) - vector2(playerCoords.x, playerCoords.y))
            if startDist < 25.0 then
                break
            end
        end
    end

    if not anyValid then
        return {}
    end
    return bestPoints
end

-- Monotone window search.
-- If minDist > 45m the caller triggers a resample (no global index jumps).
local function findClosestRouteIndex(playerPos, points, lastIdx)
    local windowStart = math.max(1, lastIdx - 10)
    local windowEnd   = math.min(#points, lastIdx + 120) -- 120 * 5m = 600m forward window

    local closestIdx = lastIdx
    local minDist    = 999999.0

    for i = windowStart, windowEnd do
        local d = #(vector2(playerPos.x, playerPos.y) - vector2(points[i].x, points[i].y))
        if d < minDist then
            minDist    = d
            closestIdx = i
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
    local lastRouteVersion   = -1
    local currentRoutePoints = {}
    local routeUpdateReason  = "new"

    while true do
        Wait(300)

        local playerPed     = PlayerPedId()
        local playerCoords  = GetEntityCoords(playerPed)
        local playerHeading = GetEntityHeading(playerPed)
        local destination   = getWaypointDestination()
        local isNavActive   = IsWaypointActive() or destination ~= nil

        -- ── Player update: only stream NUI traffic when navigation is active ──
        if isNavActive then
            SendNUIMessage({
                action = "mapplus:playerUpdate",
                player = { x = playerCoords.x, y = playerCoords.y, heading = playerHeading },
            })
        end

        -- ── Route logic ─────────────────────────────────────────────────────
        if not isNavActive then
            if #cachedRoute > 0 then
                cachedRoute            = {}
                cachedDest             = nil
                lastClosestIndex       = 1
                lastSentClosestIndex   = 1
                staleSince             = nil
                routeVersion           = routeVersion + 1
                routeUpdateReason      = "clear"
                SendNUIMessage({ action = "mapplus:routeUpdate", points = {}, destination = nil, reason = "clear" })
            end
        else
            local isInitialRoute = (#cachedRoute == 0)
            local needsResample  = isInitialRoute or destChanged(destination)

            if not needsResample and #cachedRoute > 1 then
                local closestIdx, minDist = findClosestRouteIndex(playerCoords, cachedRoute, lastClosestIndex)
                lastClosestIndex = closestIdx

                if minDist > 45.0 then
                    -- Too far from known route window → reroute cleanly
                    needsResample = true
                else
                    -- Build trimmed remaining route (no player position prepended)
                    local remaining = {}
                    for i = closestIdx, #cachedRoute do
                        remaining[#remaining + 1] = cachedRoute[i]
                    end
                    currentRoutePoints = remaining

                    -- Send trim update every ~40m of forward progress (8 points * 5m)
                    if closestIdx - lastSentClosestIndex >= TRIM_STEP then
                        lastSentClosestIndex = closestIdx
                        routeVersion         = routeVersion + 1
                        routeUpdateReason    = "trim"
                    end
                end
            end

            if needsResample then
                local freshPoints = sampleGpsRoute(playerCoords, destination)
                if #freshPoints > 1 then
                    staleSince           = nil
                    cachedRoute          = freshPoints
                    cachedDest           = destination
                    lastClosestIndex     = 1
                    lastSentClosestIndex = 1
                    currentRoutePoints   = freshPoints
                    routeVersion         = routeVersion + 1
                    routeUpdateReason    = isInitialRoute and "new" or "reroute"
                else
                    -- Start grace timer on first failure; GTA may be briefly re-routing
                    if staleSince == nil then
                        staleSince = GetGameTimer()
                    end
                    -- Only clear after grace period to avoid flicker during reroutes
                    if (GetGameTimer() - staleSince) >= STALE_GRACE_MS then
                        staleSince           = nil
                        currentRoutePoints   = {}
                        cachedRoute          = {}
                        lastSentClosestIndex = 1
                        routeVersion         = routeVersion + 1
                        routeUpdateReason    = "clear"
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
                    reason      = routeUpdateReason,
                })
            end
        end
    end
end)
