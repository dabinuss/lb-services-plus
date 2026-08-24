--[[
    Framework adapter (plan §59-61).

    Services+ never touches framework internals directly outside this file.
    Every other server script only calls Framework.* so swapping/extending
    framework support means editing this file alone.

    Framework.GetJob(source) returns:
    {
        name       = "police",       -- framework job name
        label      = "Police",       -- display label
        grade      = 4,               -- numeric grade
        gradeLabel = "Chief",         -- display label for the grade
        isBoss     = true,            -- framework-native boss heuristic (fallback only - see Framework.IsBoss)
    }
]]

Framework = { name = "standalone" }

local esxObject = nil
local qbObject = nil

local function detect()
    if Config.Framework ~= "auto" then
        return Config.Framework
    end

    if GetResourceState("es_extended") == "started" then
        return "esx"
    elseif GetResourceState("qbx_core") == "started" then
        return "qbx"
    elseif GetResourceState("qb-core") == "started" then
        return "qb"
    end

    return "standalone"
end

Framework.name = detect()

CreateThread(function()
    if Framework.name == "esx" then
        esxObject = exports["es_extended"]:getSharedObject()
    elseif Framework.name == "qb" then
        qbObject = exports["qb-core"]:GetCoreObject()
    end

    print(("[services-plus] framework adapter: %s"):format(Framework.name))
end)

-- ---------------------------------------------------------------------------
-- Job index (perf §63-64): a 600-player server cannot afford to call
-- GetPlayers() + Framework.GetJob() for every player on every availability
-- check, call, or request - that turns one app bootstrap into thousands of
-- framework lookups. This keeps a maintained `job -> sources` index instead,
-- so GetPlayersByJob() is a plain table read.
--
-- Kept fresh three ways: an initial one-time build over currently-connected
-- players at resource start, framework job/duty-change events (best effort -
-- harmless if a given framework doesn't fire a particular one), and as a
-- side effect of Framework.GetJob() itself, so any normal call anywhere in
-- the app self-heals the index for that one player regardless of events.
-- ---------------------------------------------------------------------------
local JobIndex = { byJob = {}, bySource = {} }
local DutyIndex = {} -- source -> last duty state observed through framework events

function JobIndex.Set(source, job)
    if JobIndex.bySource[source] == job then return end

    local old = JobIndex.bySource[source]
    if old and JobIndex.byJob[old] then
        JobIndex.byJob[old][source] = nil
    end

    JobIndex.bySource[source] = job
    -- Capture the duty value that belongs to this new job immediately. A
    -- second compatibility event for the same framework update can then be
    -- ignored instead of repeating the jobChanged push.
    DutyIndex[source] = job and Framework.GetOnDuty and Framework.GetOnDuty(source) or nil

    if job then
        JobIndex.byJob[job] = JobIndex.byJob[job] or {}
        JobIndex.byJob[job][source] = true
    end

    -- A genuine change only ever reaches here - the early return above
    -- already covers "unchanged" (including nil -> nil). Services+-specific
    -- per-employee state (status/hotlines, see server/employees.lua) is
    -- keyed by `source` alone with no idea which job it belongs to, so
    -- without this a player switching jobs mid-connection (e.g. Police ->
    -- Taxi) carried their old job's Busy/hotline state straight into the
    -- new one (plan review round 6 §3) - framework.lua stays the only file
    -- that touches framework internals, so this is an event, not a direct
    -- call into Employees.* from here.
    TriggerEvent("services-plus:internal:jobChanged", source, old, job)
end

function JobIndex.Remove(source)
    local old = JobIndex.bySource[source]
    if old and JobIndex.byJob[old] then
        JobIndex.byJob[old][source] = nil
    end
    JobIndex.bySource[source] = nil
end

---@param job string
---@return number[]
function JobIndex.Get(job)
    local sources = {}
    local bucket = JobIndex.byJob[job]

    if bucket then
        for source in pairs(bucket) do
            sources[#sources + 1] = source
        end
    end

    return sources
end

---@param source number
---@return { name: string, label: string, grade: number, gradeLabel: string, isBoss: boolean }?
function Framework.GetJob(source)
    local result

    if Framework.name == "esx" then
        local xPlayer = esxObject and esxObject.GetPlayerFromId(source)

        if xPlayer then
            local job = xPlayer.getJob and xPlayer.getJob() or xPlayer.job

            result = {
                name = job.name,
                label = job.label,
                grade = job.grade,
                -- ESX exposes the configured rank title as grade_label (or
                -- grade_name on some versions). Never fall back to the raw
                -- number in the UI when the job title is still available.
                gradeLabel = job.grade_label or job.grade_name or job.label or job.name,
                isBoss = job.grade_name == "boss" or job.grade == 100 or (type(job.grade) == "number" and job.grade >= 100),
            }
        end
    elseif Framework.name == "qb" then
        local Player = qbObject and qbObject.Functions.GetPlayer(source)

        if Player then
            local job = Player.PlayerData.job

            result = {
                name = job.name,
                label = job.label,
                grade = job.grade.level,
                gradeLabel = (job.grade and job.grade.name) or job.label or job.name,
                isBoss = job.isboss == true,
            }
        end
    elseif Framework.name == "qbx" then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)

        if ok and player then
            local job = player.PlayerData.job

            result = {
                name = job.name,
                label = job.label,
                grade = job.grade.level,
                gradeLabel = (job.grade and job.grade.name) or job.label or job.name,
                isBoss = job.isboss == true,
            }
        end
    else
        -- Standalone: Services+ keeps its own minimal job table.
        result = Standalone.GetJob(source)
    end

    JobIndex.Set(source, result and result.name or nil)

    return result
end

---@param source number
---@return string identifier stable across sessions, used as DB key
function Framework.GetIdentifier(source)
    if Framework.name == "esx" then
        local xPlayer = esxObject and esxObject.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or ("source:" .. source)
    elseif Framework.name == "qb" then
        local Player = qbObject and qbObject.Functions.GetPlayer(source)
        return Player and Player.PlayerData.citizenid or ("source:" .. source)
    elseif Framework.name == "qbx" then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
        return (ok and player) and player.PlayerData.citizenid or ("source:" .. source)
    end

    return GetPlayerIdentifierByType(source, "license") or ("source:" .. source)
end

--- The player's currently equipped phone number (not framework-specific,
--- but every other server file needs this so it lives next to the rest of
--- the "who is this player" helpers).
---@param source number
---@return string?
function Framework.GetPhoneNumber(source)
    return exports["lb-phone"]:GetEquippedPhoneNumber(source)
end

---@param source number
---@return string
function Framework.GetPlayerName(source)
    if Framework.name == "esx" then
        local xPlayer = esxObject and esxObject.GetPlayerFromId(source)
        if xPlayer then
            return ("%s %s"):format(xPlayer.get("firstName") or "", xPlayer.get("lastName") or ""):gsub("^%s+", ""):gsub("%s+$", "")
        end
    elseif Framework.name == "qb" or Framework.name == "qbx" then
        local Player = Framework.name == "qb" and qbObject and qbObject.Functions.GetPlayer(source)
            or (function() local ok, p = pcall(function() return exports.qbx_core:GetPlayer(source) end) return ok and p or nil end)()

        if Player then
            local info = Player.PlayerData.charinfo
            return ("%s %s"):format(info.firstname or "", info.lastname or ""):gsub("^%s+", ""):gsub("%s+$", "")
        end
    end

    return GetPlayerName(source) or ("Player " .. source)
end

---@param job string
---@return number[] sources of every online player currently on that job
function Framework.GetPlayersByJob(job)
    return JobIndex.Get(job)
end

--- Sets a player's job/grade (plan §56-57: admin assigns a company leader by
--- either config or a currently-connected player's server ID). Only ever
--- called from the admin area - never from public/employee-facing code.
---@param source number
---@param job string
---@param grade number
---@return boolean
function Framework.SetJob(source, job, grade)
    local ok

    if Framework.name == "esx" then
        local xPlayer = esxObject and esxObject.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.setJob(job, grade)
            ok = true
        end
    elseif Framework.name == "qb" then
        local Player = qbObject and qbObject.Functions.GetPlayer(source)
        ok = Player ~= nil and Player.Functions.SetJob(job, grade) ~= false
    elseif Framework.name == "qbx" then
        local success, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
        ok = success and player ~= nil and player.Functions.SetJob(job, grade) ~= false
    else
        ok = Standalone.SetJob(source, job, grade)
    end

    if ok then JobIndex.Set(source, job) end -- don't wait for the framework's own event to fire

    return ok == true
end

--- The authoritative "is this player the boss of `job`" check. Unlike the
--- framework-native `Framework.GetJob(source).isBoss` heuristic, this always
--- goes through the company's own configurable `boss_grade` when one is
--- given - that field is admin-editable (plan §56) and should actually mean
--- something for every framework, not just standalone.
---@param source number
---@param job string
---@param minGrade? number falls back to the framework's own boss flag if omitted
---@return boolean
function Framework.IsBoss(source, job, minGrade)
    local jobData = Framework.GetJob(source)
    if not jobData or jobData.name ~= job then return false end

    if minGrade then
        return jobData.grade >= minGrade
    end

    return jobData.isBoss == true
end

-- Duty (plan §61: reuse the framework's own duty system where one exists).
-- QBCore/Qbox already track this on the job object. ESX has no universal
-- concept of duty, so - like standalone - Services+ keeps a small manual
-- toggle that defaults to "on duty" whenever the player has the job.
local manualDuty = {} -- source -> boolean (session-scoped for ESX/standalone)

---@param source number
---@return boolean
function Framework.GetOnDuty(source)
    if Framework.name == "qb" then
        local Player = qbObject and qbObject.Functions.GetPlayer(source)
        return Player ~= nil and Player.PlayerData.job.onduty ~= false
    elseif Framework.name == "qbx" then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
        return ok and player ~= nil and player.PlayerData.job.onduty ~= false
    end

    if manualDuty[source] == nil then return true end
    return manualDuty[source]
end

---@param source number
---@param state boolean
---@return boolean
function Framework.SetDuty(source, state)
    if Framework.name == "qb" then
        local Player = qbObject and qbObject.Functions.GetPlayer(source)
        if Player then Player.Functions.SetJobDuty(state) end
        return Player ~= nil
    elseif Framework.name == "qbx" then
        local ok = pcall(function() exports.qbx_core:SetJobDuty(source, state) end)
        return ok
    end

    manualDuty[source] = state
    return true
end

-- Reconciles framework-owned duty with Services+ and suppresses duplicate
-- pushes when QB/Qbox emit more than one compatible event for one change.
-- Also called explicitly after Services+'s own SetDuty so ESX/standalone,
-- which have no universal duty event, use the exact same downstream path.
---@param source number
function Framework.RefreshDuty(source)
    local onDuty = Framework.GetOnDuty(source)
    if DutyIndex[source] == onDuty then return end

    DutyIndex[source] = onDuty
    TriggerEvent("services-plus:internal:dutyChanged", source)
end

-- ---------------------------------------------------------------------------
-- Standalone fallback: a tiny job table for servers without ESX/QBCore/Qbox.
-- Persisted in `phone_services_plus_standalone_jobs` (see sql/install.sql).
-- ---------------------------------------------------------------------------
Standalone = { jobs = {} } -- identifier -> { name, grade }

function Standalone.GetJob(source)
    local identifier = GetPlayerIdentifierByType(source, "license") or ("source:" .. source)
    local job = Standalone.jobs[identifier]

    if not job then
        return nil
    end

    local company = Companies.GetByJob(job.name)

    return {
        name = job.name,
        label = company and company.name or job.name,
        grade = job.grade,
        -- Standalone has no framework-owned rank catalogue. Use the
        -- configured job/company title as a stable display fallback while
        -- keeping the numeric grade exclusively for permission checks.
        gradeLabel = company and company.name or job.name,
        isBoss = company ~= nil and job.grade >= (company.boss_grade or 999),
    }
end

function Standalone.SetJob(source, job, grade)
    local identifier = GetPlayerIdentifierByType(source, "license") or ("source:" .. source)
    Standalone.jobs[identifier] = job and { name = job, grade = grade or 0 } or nil

    if job then
        MySQL.update(
            "REPLACE INTO phone_services_plus_standalone_jobs (identifier, job, grade) VALUES (?, ?, ?)",
            { identifier, job, grade or 0 }
        )
    else
        MySQL.update("DELETE FROM phone_services_plus_standalone_jobs WHERE identifier = ?", { identifier })
    end

    return true
end

CreateThread(function()
    if Framework.name ~= "standalone" then return end

    local rows = MySQL.query.await("SELECT identifier, job, grade FROM phone_services_plus_standalone_jobs") or {}

    for i = 1, #rows do
        Standalone.jobs[rows[i].identifier] = { name = rows[i].job, grade = rows[i].grade }
    end
end)

-- ---------------------------------------------------------------------------
-- Job index maintenance: framework job/duty-change events (best effort -
-- listeners for events an inactive framework never fires are simply inert),
-- disconnect cleanup, and the one-time initial build.
-- ---------------------------------------------------------------------------

local function refreshJobAndDuty(source)
    if type(source) ~= "number" then return end

    local oldJob = JobIndex.bySource[source]
    local job = Framework.GetJob(source)
    local newJob = job and job.name or nil

    -- JobIndex.Set already emitted jobChanged (which includes the player's
    -- own duty/native-call push). Only a stable job can represent a pure
    -- external duty update here.
    if oldJob == newJob then
        Framework.RefreshDuty(source)
    else
        -- jobChanged already pushed the complete new snapshot; remember its
        -- duty value so a second compatibility event for the same framework
        -- update cannot immediately repeat that work.
        DutyIndex[source] = Framework.GetOnDuty(source)
    end
end

local function playerLoaded(source)
    if type(source) ~= "number" then return end
    refreshJobAndDuty(source)
    TriggerEvent("services-plus:internal:playerLoaded", source)
end

AddEventHandler("esx:playerLoaded", function(playerId) playerLoaded(playerId) end)
AddEventHandler("esx:setJob", function(source) refreshJobAndDuty(source) end)

AddEventHandler("QBCore:Server:PlayerLoaded", function(player)
    if player and player.PlayerData then playerLoaded(player.PlayerData.source) end
end)
-- Belt-and-suspenders for Qbox: current qbx_core fires the same
-- "QBCore:Server:PlayerLoaded" above, but this also catches it on setups
-- where that isn't the case (plan review round 3 §1) - inert otherwise.
AddEventHandler("QBCore:Server:OnPlayerLoaded", function(player)
    if player and player.PlayerData then
        playerLoaded(player.PlayerData.source)
    else
        playerLoaded(source)
    end
end)
AddEventHandler("QBCore:Server:OnPlayerUpdated", function(source, key)
    if key == "job" or key == "all" then refreshJobAndDuty(source) end
end)
AddEventHandler("QBCore:Server:OnJobUpdate", function(source) refreshJobAndDuty(source) end)
AddEventHandler("QBCore:Server:SetDuty", function(source) refreshJobAndDuty(source) end)

AddEventHandler("playerDropped", function()
    -- Capture and publish the old job before clearing the index. Other
    -- modules no longer race separate playerDropped handlers to read it.
    local oldJob = JobIndex.bySource[source]
    TriggerEvent("services-plus:internal:playerDropped", source, oldJob)

    manualDuty[source] = nil
    DutyIndex[source] = nil
    JobIndex.Remove(source)
end)

-- Initial build, then a slow periodic re-sync as a framework-agnostic
-- safety net (plan review round 3 §1): the exact "player finished loading"
-- event name varies across framework forks/versions, so rather than bet
-- everything on guessing it right, this guarantees the index self-heals
-- for anyone it missed within at most 2 minutes - a 600-player GetPlayers()
-- scan every 2 minutes is negligible, it's just not a per-transaction cost.
CreateThread(function()
    Wait(2000) -- let the framework finish starting up first

    while true do
        local players = GetPlayers()

        for i = 1, #players do
            Framework.GetJob(tonumber(players[i]))

            -- A 600-player server makes this 600 framework lookups back to
            -- back with no yield at all - individually cheap, but bursting
            -- all of them into the same server tick is still unnecessary
            -- (plan review round 5 §7). Yielding every 25 keeps the self-heal
            -- spread across several ticks instead, with no change to the
            -- outer 2-minute cadence.
            if i % 25 == 0 then Wait(0) end
        end

        Wait(120000)
    end
end)
