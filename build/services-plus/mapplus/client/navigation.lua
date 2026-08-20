-- =============================================================================
-- MapPlus - owned navigation session state
-- Keeps a Services+ destination independent from the mutable player waypoint.
-- =============================================================================

MapPlusNavigation = MapPlusNavigation or {
    active = false,
    generation = 0,
    sessionId = nil,
    owner = nil,
    destination = nil,
    source = "waypoint",
    slot = 0,
}

local WAYPOINT_TOLERANCE = 5.0
local WAYPOINT_START_GRACE_MS = 1500

local function validCoordinate(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function copyDestination(destination)
    if type(destination) ~= "table"
        or not validCoordinate(destination.x)
        or not validCoordinate(destination.y)
    then
        return nil
    end

    return { x = destination.x + 0.0, y = destination.y + 0.0 }
end

local function getWaypointDestination()
    local waypointBlip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypointBlip) then return nil end

    local coords = GetBlipInfoIdCoord(waypointBlip)
    if not coords or (coords.x == 0.0 and coords.y == 0.0) then return nil end
    return { x = coords.x, y = coords.y }
end

local function waypointMatches(destination)
    local waypoint = getWaypointDestination()
    if not waypoint or not destination then return false end
    return #(vector2(waypoint.x, waypoint.y) - vector2(destination.x, destination.y)) <= WAYPOINT_TOLERANCE
end

function MapPlusNavigation.Start(options)
    if type(options) ~= "table" or options.sessionId == nil or options.owner == nil then
        return false, "sessionId and owner are required"
    end

    local destination = copyDestination(options.destination)
    if not destination then return false, "invalid destination" end

    local source = options.source or "waypoint"
    local slot = tonumber(options.slot) or 0
    local sameSession = MapPlusNavigation.active
        and MapPlusNavigation.sessionId == options.sessionId
        and MapPlusNavigation.owner == options.owner
        and MapPlusNavigation.destination
        and #(vector2(MapPlusNavigation.destination.x, MapPlusNavigation.destination.y)
            - vector2(destination.x, destination.y)) <= WAYPOINT_TOLERANCE

    if sameSession then return true end

    MapPlusNavigation.active = true
    MapPlusNavigation.generation = MapPlusNavigation.generation + 1
    MapPlusNavigation.sessionId = options.sessionId
    MapPlusNavigation.owner = options.owner
    MapPlusNavigation.destination = destination
    MapPlusNavigation.source = source
    MapPlusNavigation.slot = slot
    MapPlusNavigation.startedAt = GetGameTimer()
    MapPlusNavigation.stopReason = nil

    if source == "waypoint" then SetNewWaypoint(destination.x, destination.y) end
    return true
end

function MapPlusNavigation.Stop(sessionId, owner, reason, preserveWaypoint)
    if not MapPlusNavigation.active
        or MapPlusNavigation.sessionId ~= sessionId
        or MapPlusNavigation.owner ~= owner
    then
        return false
    end

    local destination = MapPlusNavigation.destination
    if not preserveWaypoint and MapPlusNavigation.source == "waypoint" and waypointMatches(destination) then
        DeleteWaypoint()
    end

    MapPlusNavigation.active = false
    MapPlusNavigation.generation = MapPlusNavigation.generation + 1
    MapPlusNavigation.sessionId = nil
    MapPlusNavigation.owner = nil
    MapPlusNavigation.destination = nil
    MapPlusNavigation.startedAt = nil
    MapPlusNavigation.stopReason = reason or "stopped"
    return true
end

function MapPlusNavigation.ValidateWaypoint()
    if not MapPlusNavigation.active or MapPlusNavigation.source ~= "waypoint" then return true end
    if waypointMatches(MapPlusNavigation.destination) then return true end

    local startedAt = MapPlusNavigation.startedAt or 0
    if GetGameTimer() - startedAt < WAYPOINT_START_GRACE_MS then return true end

    MapPlusNavigation.Stop(
        MapPlusNavigation.sessionId,
        MapPlusNavigation.owner,
        "waypoint-replaced",
        true
    )
    return false
end

function MapPlusNavigation.GetSnapshot()
    return {
        active = MapPlusNavigation.active,
        generation = MapPlusNavigation.generation,
        sessionId = MapPlusNavigation.sessionId,
        owner = MapPlusNavigation.owner,
        destination = copyDestination(MapPlusNavigation.destination),
        source = MapPlusNavigation.source,
        slot = MapPlusNavigation.slot,
    }
end

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() or not MapPlusNavigation.active then return end
    MapPlusNavigation.Stop(MapPlusNavigation.sessionId, MapPlusNavigation.owner, "resource-stop")
end)
