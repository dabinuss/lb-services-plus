ServicesPlus.Bridge = ServicesPlus.Bridge or {}

local Bridge = ServicesPlus.Bridge
local activeFramework = nil
local frameworkObject = nil

local function resourceStarted(name)
    return GetResourceState(name) == "started"
end

local function getLicense(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 8) == "license:" then
            return identifier
        end
    end
    return GetPlayerIdentifierByType(source, "license") or GetPlayerIdentifiers(source)[1]
end

local function detectFramework()
    if Config.Framework ~= "auto" then
        return Config.Framework
    end
    if resourceStarted("qbx_core") then return "qbox" end
    if resourceStarted("qb-core") then return "qbcore" end
    if resourceStarted("es_extended") then return "esx" end
    return "standalone"
end

function Bridge.Initialize()
    activeFramework = detectFramework()

    if activeFramework == "qbox" and resourceStarted("qbx_core") then
        frameworkObject = exports.qbx_core
    elseif activeFramework == "qbcore" and resourceStarted("qb-core") then
        frameworkObject = exports["qb-core"]:GetCoreObject()
    elseif activeFramework == "esx" and resourceStarted("es_extended") then
        frameworkObject = exports.es_extended:getSharedObject()
    elseif activeFramework ~= "standalone" then
        return false, ("Configured framework '%s' is not running"):format(activeFramework)
    end

    return true, activeFramework
end

function Bridge.GetName()
    return activeFramework or "uninitialized"
end

function Bridge.GetPlayer(source)
    if not source or source <= 0 then return nil end

    if activeFramework == "qbox" then
        local player = frameworkObject:GetPlayer(source)
        if not player then return nil end
        local data = player.PlayerData
        local info = data.charinfo or {}
        local gradeData = data.job.grade
        local grade = type(gradeData) == "table" and (gradeData.level or 0) or (gradeData or 0)
        return {
            source = source,
            identifier = data.citizenid or getLicense(source),
            name = ((info.firstname or "") .. " " .. (info.lastname or "")):gsub("^%s*(.-)%s*$", "%1"),
            job = data.job.name,
            grade = tonumber(grade) or 0,
            role = type(gradeData) == "table" and (gradeData.name or gradeData.label) or data.job.label
        }
    end

    if activeFramework == "qbcore" then
        local player = frameworkObject.Functions.GetPlayer(source)
        if not player then return nil end
        local data = player.PlayerData
        local info = data.charinfo or {}
        local gradeData = data.job.grade
        local grade = type(gradeData) == "table" and (gradeData.level or 0) or (gradeData or 0)
        return {
            source = source,
            identifier = data.citizenid or getLicense(source),
            name = ((info.firstname or "") .. " " .. (info.lastname or "")):gsub("^%s*(.-)%s*$", "%1"),
            job = data.job.name,
            grade = tonumber(grade) or 0,
            role = type(gradeData) == "table" and (gradeData.name or gradeData.label) or data.job.label
        }
    end

    if activeFramework == "esx" then
        local player = frameworkObject.GetPlayerFromId(source)
        if not player then return nil end
        local job = player.getJob()
        return {
            source = source,
            identifier = player.getIdentifier(),
            name = player.getName(),
            job = job.name,
            grade = tonumber(job.grade) or 0,
            role = job.grade_label or job.label
        }
    end

    local identifier = getLicense(source)
    local configured = identifier and Config.StandalonePlayers[identifier]
    return {
        source = source,
        identifier = identifier,
        name = configured and configured.name or GetPlayerName(source) or ("Player %d"):format(source),
        job = configured and configured.job or "unemployed",
        grade = configured and tonumber(configured.grade) or 0,
        role = configured and configured.role or "Employee"
    }
end

function Bridge.IsLeader(player, company)
    if not player or not company then return false end
    if Config.ExplicitLeaders[player.identifier] == company.id then return true end
    local minimumGrade = Config.LeaderGrades[company.job]
    return minimumGrade ~= nil and player.job == company.job and player.grade >= minimumGrade
end

function Bridge.HasEquippedPhone(source)
    if not Config.RequireEquippedPhone then return true end
    local ok, number = pcall(function()
        return exports["lb-phone"]:GetEquippedPhoneNumber(source)
    end)
    return ok and type(number) == "string" and number ~= ""
end

function Bridge.GetEquippedPhoneNumber(source)
    if not Config.RequireEquippedPhone then return "phone-not-required" end
    local ok, number = pcall(function() return exports["lb-phone"]:GetEquippedPhoneNumber(source) end)
    return ok and type(number) == "string" and number ~= "" and number or nil
end

function Bridge.IsServerAdmin(source)
    if IsPlayerAceAllowed(source, Config.AdminAce) then return true end
    local identifier = getLicense(source)
    if identifier and Config.StandaloneAdmins[identifier] then return true end
    if activeFramework == "esx" then
        local player = frameworkObject.GetPlayerFromId(source)
        local group = player and player.getGroup and player.getGroup() or "user"
        return group == "admin" or group == "superadmin"
    end
    if activeFramework == "qbcore" and frameworkObject.Functions.HasPermission then
        return frameworkObject.Functions.HasPermission(source, "admin") or frameworkObject.Functions.HasPermission(source, "god")
    end
    return false
end
