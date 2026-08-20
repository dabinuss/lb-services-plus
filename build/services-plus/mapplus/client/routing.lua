-- =============================================================================
-- MapPlus - periodically refreshed GTA GPS route controller
-- GTA remains the pathfinder; local trimming is display state only.
-- =============================================================================

local settings = Config.MapPlus or {}

local function positiveNumber(value, fallback)
    value = tonumber(value)
    return value and value > 0 and value or fallback
end

local SAMPLE_STEP = positiveNumber(settings.SampleStep, 5.0)
local NATIVE_REFRESH_MS = positiveNumber(settings.NativeRefreshMs, 1200)
local OFF_ROUTE_REFRESH_COOLDOWN_MS = math.min(NATIVE_REFRESH_MS, 600)
local TRIM_STEP = math.max(1, math.floor(positiveNumber(settings.TrimStep, 4)))
local BEHIND_POINTS = math.max(0, math.floor(tonumber(settings.BehindPoints) or 2))
local OFF_ROUTE_DISTANCE = positiveNumber(settings.OffRouteDistance, 45.0)
local STALE_GRACE_MS = positiveNumber(settings.StaleGraceMs, 2500)
local REROUTE_DISTANCE = positiveNumber(settings.RerouteDistance, 25.0)
local DEBUG = settings.Debug == true

local nativeRoute = {}
local displayRoute = {}
local activeGeneration = -1
local lastClosestIndex = 1
local lastSentStartIndex = 1
local lastNativeRefreshAt = 0
local staleSince = nil
local routeVisible = false

local function distanceBetween(a, b)
    return #(vector2(a.x, a.y) - vector2(b.x, b.y))
end

local function isRouteComplete(points, destination, gtaRouteLength, lastSuccessfulDistance)
    if #points < 2 then return false end
    if gtaRouteLength > 0 and lastSuccessfulDistance > 0 then
        return lastSuccessfulDistance >= gtaRouteLength - 25.0
    end
    return destination and distanceBetween(points[#points], destination) < 100.0
end

local function sampleGpsRoute(playerCoords, navigation)
    local startedAt = GetGameTimer()
    local gtaRouteLength = 0.0
    local ok, routeLength = pcall(GetGpsBlipRouteLength)
    if ok and type(routeLength) == "number" and routeLength > 0 then gtaRouteLength = routeLength end

    local directDistance = distanceBetween(playerCoords, navigation.destination)
    local maxDistance = gtaRouteLength > 0
        and gtaRouteLength + 100.0
        or math.min(math.max(directDistance * 2.5, 2000.0), 30000.0)
    local maxConsecutiveFailures = 15
    local points = {}
    local distance = 0.0
    local lastPoint = nil
    local lastSuccessfulDistance = 0.0
    local consecutiveFailures = 0

    while distance <= maxDistance and consecutiveFailures < maxConsecutiveFailures do
        local success, coords = GetPosAlongGpsTypeRoute(true, distance, navigation.slot)
        if (success == true or success == 1)
            and coords
            and (coords.x ~= 0.0 or coords.y ~= 0.0)
        then
            consecutiveFailures = 0
            lastSuccessfulDistance = distance
            if not lastPoint or distanceBetween(lastPoint, coords) > 1.5 then
                points[#points + 1] = { x = coords.x, y = coords.y }
                lastPoint = coords
            end
        else
            consecutiveFailures = consecutiveFailures + 1
        end
        distance = distance + SAMPLE_STEP
    end

    local sampledPointCount = #points
    local firstDistance = sampledPointCount > 0 and distanceBetween(playerCoords, points[1]) or -1
    local lastDistance = sampledPointCount > 0
        and distanceBetween(points[sampledPointCount], navigation.destination)
        or -1
    local complete = isRouteComplete(points, navigation.destination, gtaRouteLength, lastSuccessfulDistance)
    if not complete then
        points = {}
    end

    return points, {
        durationMs = GetGameTimer() - startedAt,
        routeLength = gtaRouteLength,
        sampledPointCount = sampledPointCount,
        complete = complete,
        firstDistance = firstDistance,
        lastDistance = lastDistance,
    }
end

local function findClosestRouteIndex(playerPos, points, lastIndex)
    local windowStart = math.max(1, lastIndex)
    local windowEnd = math.min(#points, lastIndex + 120)
    local closestIndex = lastIndex
    local minimumDistance = math.huge

    for index = windowStart, windowEnd do
        local distance = distanceBetween(playerPos, points[index])
        if distance < minimumDistance then
            minimumDistance = distance
            closestIndex = index
        end
    end

    return closestIndex, minimumDistance
end

local function copyRouteFrom(points, startIndex)
    local result = {}
    for index = math.max(1, startIndex), #points do result[#result + 1] = points[index] end
    return result
end

local function pointAtDistance(points, targetDistance)
    if #points == 0 then return nil end
    local travelled = 0.0
    for index = 2, #points do
        local segmentLength = distanceBetween(points[index - 1], points[index])
        if segmentLength > 0.0 and travelled + segmentLength >= targetDistance then
            local ratio = (targetDistance - travelled) / segmentLength
            return {
                x = points[index - 1].x + (points[index].x - points[index - 1].x) * ratio,
                y = points[index - 1].y + (points[index].y - points[index - 1].y) * ratio,
            }
        end
        travelled = travelled + segmentLength
    end
    return nil
end

local function distanceToSegment(point, startPoint, endPoint)
    local dx = endPoint.x - startPoint.x
    local dy = endPoint.y - startPoint.y
    local lengthSquared = dx * dx + dy * dy
    if lengthSquared <= 0.0001 then return distanceBetween(point, startPoint) end
    local projection = ((point.x - startPoint.x) * dx + (point.y - startPoint.y) * dy) / lengthSquared
    projection = math.max(0.0, math.min(1.0, projection))
    return distanceBetween(point, {
        x = startPoint.x + projection * dx,
        y = startPoint.y + projection * dy,
    })
end

local function distanceToRoute(point, points, maximumRouteDistance)
    local minimumDistance = math.huge
    local travelled = 0.0
    for index = 2, #points do
        local segmentLength = distanceBetween(points[index - 1], points[index])
        minimumDistance = math.min(minimumDistance, distanceToSegment(point, points[index - 1], points[index]))
        travelled = travelled + segmentLength
        if maximumRouteDistance and travelled >= maximumRouteDistance then break end
    end
    return minimumDistance
end

local function classifyRefresh(previousRoute, freshRoute)
    if #previousRoute < 2 then return "reroute" end

    local compared = 0
    local outsideCorridor = 0
    for _, checkpoint in ipairs({ 50.0, 100.0, 200.0, 400.0 }) do
        local point = pointAtDistance(freshRoute, checkpoint)
        if point then
            compared = compared + 1
            if distanceToRoute(point, previousRoute, 550.0) > REROUTE_DISTANCE then
                outsideCorridor = outsideCorridor + 1
            end
        end
    end

    return compared >= 2 and outsideCorridor >= 2 and "reroute" or "trim"
end

local function sendRouteUpdate(points, destination, reason, metrics)
    local message = {
        action = "mapplus:routeUpdate",
        points = points,
        destination = destination,
        reason = reason,
    }
    SendNUIMessage(message)

    if DEBUG then
        local payloadSize = json and #json.encode(message) or -1
        print(("[MapPlus] reason=%s points=%d route=%.0fm sample=%dms payload=%dB first=%.1fm last=%.1fm")
            :format(reason, #points, metrics and metrics.routeLength or 0,
                metrics and metrics.durationMs or 0, payloadSize,
                metrics and metrics.firstDistance or -1,
                metrics and metrics.lastDistance or -1))
    end
end

local function clearRoute(destination)
    nativeRoute = {}
    displayRoute = {}
    lastClosestIndex = 1
    lastSentStartIndex = 1
    routeVisible = false
    sendRouteUpdate({}, destination, "clear")
end

CreateThread(function()
    while true do
        Wait(300)
        MapPlusNavigation.ValidateWaypoint()
        local navigation = MapPlusNavigation.GetSnapshot()

        if not navigation.active then
            if routeVisible or activeGeneration ~= navigation.generation then
                clearRoute(nil)
                activeGeneration = navigation.generation
            end
        else
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            SendNUIMessage({
                action = "mapplus:playerUpdate",
                player = {
                    x = playerCoords.x,
                    y = playerCoords.y,
                    heading = GetEntityHeading(playerPed),
                },
            })

            local isNewSession = activeGeneration ~= navigation.generation
            if isNewSession then
                nativeRoute = {}
                displayRoute = {}
                activeGeneration = navigation.generation
                lastClosestIndex = 1
                lastSentStartIndex = 1
                lastNativeRefreshAt = 0
                staleSince = nil
            end

            local offRoute = false
            local pendingTrim = false
            if #nativeRoute > 1 then
                local closestIndex, minimumDistance = findClosestRouteIndex(
                    playerCoords,
                    nativeRoute,
                    lastClosestIndex
                )
                lastClosestIndex = closestIndex
                offRoute = minimumDistance > OFF_ROUTE_DISTANCE

                if not offRoute then
                    local displayStartIndex = math.max(1, closestIndex - BEHIND_POINTS)
                    displayRoute = copyRouteFrom(nativeRoute, displayStartIndex)
                    if displayStartIndex - lastSentStartIndex >= TRIM_STEP then
                        lastSentStartIndex = displayStartIndex
                        pendingTrim = true
                    end
                end
            end

            local now = GetGameTimer()
            local refreshDue = isNewSession
                or now - lastNativeRefreshAt >= NATIVE_REFRESH_MS
                or (offRoute and now - lastNativeRefreshAt >= OFF_ROUTE_REFRESH_COOLDOWN_MS)

            if pendingTrim and not refreshDue then
                routeVisible = true
                sendRouteUpdate(displayRoute, navigation.destination, "trim")
            end

            if refreshDue then
                lastNativeRefreshAt = now
                local previousDisplayRoute = displayRoute
                local freshRoute, metrics = sampleGpsRoute(playerCoords, navigation)
                if #freshRoute > 1 then
                    local reason
                    if isNewSession then
                        reason = "new"
                    elseif #nativeRoute < 2 then
                        reason = "reroute"
                    else
                        reason = classifyRefresh(previousDisplayRoute, freshRoute)
                    end

                    nativeRoute = freshRoute
                    displayRoute = freshRoute
                    lastClosestIndex = 1
                    lastSentStartIndex = 1
                    staleSince = nil
                    routeVisible = true
                    sendRouteUpdate(displayRoute, navigation.destination, reason, metrics)
                else
                    if DEBUG then
                        print(("[MapPlus] native sample failed points=%d route=%.0fm sample=%dms complete=%s")
                            :format(metrics.sampledPointCount, metrics.routeLength, metrics.durationMs,
                                tostring(metrics.complete)))
                    end
                    staleSince = staleSince or now
                    if isNewSession then
                        clearRoute(navigation.destination)
                    elseif routeVisible and now - staleSince >= STALE_GRACE_MS then
                        clearRoute(navigation.destination)
                    end
                end
            end
        end
    end
end)
