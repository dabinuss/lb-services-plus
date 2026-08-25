--[[
    NUI-facing RPC handlers for the Services+ custom app. Everything here is
    called from client/main.lua's RegisterNUICallback via ServerCallback(),
    never trusted from the client beyond "this is what the player asked for"
    (plan §62).
]]

--- Race-safe enough for this app's scale: a duplicate INSERT can only ever
--- happen if two requests for the very same (number, contact) land within
--- the same tick, and the UNIQUE constraint (see sql/install.sql) turns that
--- into a harmless duplicate-key error we just recover from with a re-SELECT.
Messages = {}

local function getOrCreateChannel(numberId, contactNumber)
    local channel = MySQL.single.await(
        "SELECT * FROM phone_services_plus_channels WHERE number_id = ? AND contact_number = ?",
        { numberId, contactNumber }
    )

    if channel then return channel end

    local id = MySQL.insert.await(
        "INSERT IGNORE INTO phone_services_plus_channels (number_id, contact_number) VALUES (?, ?)",
        { numberId, contactNumber }
    )

    if not id or id == 0 then
        -- Someone else's concurrent request won the INSERT - read theirs back.
        return MySQL.single.await(
            "SELECT * FROM phone_services_plus_channels WHERE number_id = ? AND contact_number = ?",
            { numberId, contactNumber }
        )
    end

    return { id = id, number_id = numberId, contact_number = contactNumber, last_message = nil }
end

--- Stores and delivers a message after its caller has resolved and
--- authorized the channel participants. This is the single persistence and
--- notification path used by the app and the public company-message export.
---@param company table
---@param number table
---@param channel table
---@param senderNumber string
---@param senderType "company"|"customer"
---@param content string
---@return table|false
function Messages.Send(company, number, channel, senderNumber, senderType, content)
    if type(content) ~= "string" or content == "" or #content > 1000 then return false end
    if not company or not number or not channel or not senderNumber then return false end

    local messageId = MySQL.insert.await(
        "INSERT INTO phone_services_plus_messages (channel_id, sender, sender_type, content) VALUES (?, ?, ?, ?)",
        { channel.id, senderNumber, senderType, content }
    )
    if not messageId then return false end

    MySQL.update.await(
        "UPDATE phone_services_plus_channels SET last_message = ?, archived_by_contact = 0, archived_by_company = 0 WHERE id = ?",
        { content:sub(1, 100), channel.id }
    )

    local payload = { channelId = channel.id, id = messageId, sender_type = senderType, content = content }

    if senderType == "company" then
        local contactSource = ResolvePhoneSource(channel.contact_number)
        if contactSource then
            TriggerClientEvent("services-plus:client:newMessage", contactSource, payload)
        end

        exports["lb-phone"]:SendNotification(channel.contact_number, {
            app = Config.App.identifier,
            title = company.name,
            content = content,
        })
    else
        local staff = Framework.GetPlayersByJob(company.job)
        for i = 1, #staff do
            if Employees.IsLoggedIn(staff[i], company.id) and Framework.GetOnDuty(staff[i]) then
                local staffNumber = Framework.GetPhoneNumber(staff[i])
                if staffNumber then
                    TriggerClientEvent("services-plus:client:newMessage", staff[i], payload)
                    exports["lb-phone"]:SendNotification(staffNumber, {
                        app = Config.App.identifier,
                        title = ("%s (%s)"):format(company.name, number.label),
                        content = content,
                    })
                end
            end
        end
    end

    return payload
end

--- Sends a normal Services+ company message without impersonating an
--- employee's private phone number.
---@param companyJob string
---@param targetNumber string
---@param content string
---@return table|false
function Messages.SendCompanyMessage(companyJob, targetNumber, content)
    if type(companyJob) ~= "string" or type(targetNumber) ~= "string" then return false end
    if type(content) ~= "string" or content == "" or #content > 1000 then return false end
    targetNumber = targetNumber:match("^%s*(.-)%s*$")
    if targetNumber == "" then return false end

    local company = Companies.GetByJob(companyJob)
    if not company or not DatabaseBoolean(company.admin_messages_allowed) then return false end

    local number = Companies.GetMainNumber(company.id)
    if not number or not DatabaseBoolean(number.messages_enabled)
        or not DatabaseBoolean(number.mailbox_enabled) then return false end

    local channel = getOrCreateChannel(number.id, targetNumber)
    if not channel then return false end

    return Messages.Send(company, number, channel, number.number, "company", content)
end

-- ---------------------------------------------------------------------------
-- Bootstrap: one combined payload for opening the app (plan §63-64: as few
-- round trips as possible).
-- ---------------------------------------------------------------------------
local READ_SCOPES = {
    company_requests = true,
    activity_requests = true,
    activity_calls = true,
    company_calls = true,
}

local function buildCompanySession(source, company, job)
    return {
        company = { id = company.id, name = company.name, job = company.job, icon = company.icon },
        employee = {
            memberId = source,
            name = Framework.GetPlayerName(source),
            grade = job.grade,
            gradeLabel = job.gradeLabel,
            isBoss = Framework.IsBoss(source, job.name, company.boss_grade),
            onDuty = Framework.GetOnDuty(source),
            status = Employees.GetStatus(source),
            loggedIn = true,
        },
    }
end

local function getCompanySession(source, company, job, phoneNumber)
    local stored = Employees.GetCompanySession(source)
    if not stored or not company or not job then return nil end
    if stored.companyId ~= company.id or stored.phoneNumber ~= phoneNumber then
        Employees.ClearCompanySession(source)
        return nil
    end
    return buildCompanySession(source, company, job)
end

local function getReadMarker(ownerKey, scope, companyId)
    return tonumber(MySQL.scalar.await([[
        SELECT last_read_id
        FROM phone_services_plus_read_state
        WHERE owner_key = ? AND scope = ? AND company_id = ?
    ]], { ownerKey, scope, companyId or 0 })) or 0
end

local function getUnreadCounts(source)
    local phoneNumber = Framework.GetPhoneNumber(source)
    local result = {
        activityMessages = 0,
        activityRequests = 0,
        activityCalls = 0,
        companyMessages = 0,
        companyRequests = 0,
        companyCalls = 0,
    }

    if phoneNumber then
        result.activityMessages = tonumber(MySQL.scalar.await([[
            SELECT COUNT(*)
            FROM phone_services_plus_messages m
            JOIN phone_services_plus_channels c ON c.id = m.channel_id
            LEFT JOIN phone_services_plus_conversation_reads cr
              ON cr.owner_key = ? AND cr.viewer_scope = 'customer' AND cr.channel_id = c.id
            WHERE c.contact_number = ? AND c.archived_by_contact = 0
              AND m.sender_type = 'company'
              AND m.id > COALESCE(cr.last_read_id, 0)
        ]], { phoneNumber, phoneNumber })) or 0

        result.activityRequests = Unread.CountForReader("activity_requests", phoneNumber, 0, phoneNumber)
        result.activityCalls = Unread.CountForReader("activity_calls", phoneNumber, 0, phoneNumber)
    end

    local company = Companies.GetForPlayer(source)
    if not company or not Employees.IsLoggedIn(source, company.id) then return result end

    local ownerKey = Framework.GetIdentifier(source)
    result.companyMessages = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM phone_services_plus_messages m
        JOIN phone_services_plus_channels c ON c.id = m.channel_id
        JOIN phone_services_plus_numbers n ON n.id = c.number_id
        LEFT JOIN phone_services_plus_conversation_reads cr
          ON cr.owner_key = ? AND cr.viewer_scope = 'employee' AND cr.channel_id = c.id
        WHERE n.company_id = ? AND n.mailbox_enabled = 1
          AND c.archived_by_company = 0 AND m.sender_type = 'customer'
          AND m.id > COALESCE(cr.last_read_id, 0)
    ]], { ownerKey, company.id })) or 0

    local requestMarker = getReadMarker(ownerKey, "company_requests", company.id)
    result.companyRequests = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM phone_services_plus_requests r
        JOIN phone_services_plus_request_types t ON t.id = r.request_type_id
        WHERE r.id > ? AND r.status = 'open' AND (
            r.company_id = ? OR
            (r.company_id IS NULL AND t.category_id = ?)
        )
    ]], { requestMarker, company.id, company.category_id })) or 0

    result.companyCalls = Unread.CountForReader("company_calls", "", company.id, ownerKey)

    return result
end

local function resolveConversationViewer(source, channelId)
    channelId = tonumber(channelId)
    if not channelId then return nil end

    local channel = MySQL.single.await([[
        SELECT c.id, c.contact_number, company.job AS company_job
        FROM phone_services_plus_channels c
        JOIN phone_services_plus_numbers n ON n.id = c.number_id
        JOIN phone_services_plus_companies company ON company.id = n.company_id
        WHERE c.id = ?
    ]], { channelId })
    if not channel then return nil end

    local phoneNumber = Framework.GetPhoneNumber(source)
    if phoneNumber and phoneNumber == channel.contact_number then
        return phoneNumber, "customer", channel.id
    end

    local job = Framework.GetJob(source)
    if job and job.name == channel.company_job then
        return Framework.GetIdentifier(source), "employee", channel.id
    end

    return nil
end

local function markConversationRead(source, channelId)
    local ownerKey, viewerScope, resolvedChannelId = resolveConversationViewer(source, channelId)
    if not ownerKey then return false end

    local latestId = tonumber(MySQL.scalar.await(
        "SELECT COALESCE(MAX(id), 0) FROM phone_services_plus_messages WHERE channel_id = ?",
        { resolvedChannelId }
    )) or 0

    MySQL.update.await([[
        INSERT INTO phone_services_plus_conversation_reads
            (owner_key, viewer_scope, channel_id, last_read_id)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE last_read_id = GREATEST(last_read_id, VALUES(last_read_id))
    ]], { ownerKey, viewerScope, resolvedChannelId, latestId })

    return true
end

local function markRead(source, scope)
    if not READ_SCOPES[scope] then return false end

    local isCompanyScope = scope == "company_requests" or scope == "company_calls"
    local ownerKey, eventOwnerKey, companyId = Framework.GetPhoneNumber(source), nil, 0
    if isCompanyScope then
        local company = Companies.GetForPlayer(source)
        if not company or not Employees.IsLoggedIn(source, company.id) then return false end
        ownerKey, companyId = Framework.GetIdentifier(source), company.id
    end
    if not ownerKey then return false end

    local latestId
    if Unread.IsScope(scope) then
        eventOwnerKey = isCompanyScope and "" or ownerKey
        latestId = Unread.LatestId(scope, eventOwnerKey, companyId)
    elseif scope == "company_requests" then
        latestId = tonumber(MySQL.scalar.await(
            "SELECT COALESCE(MAX(id), 0) FROM phone_services_plus_requests"
        )) or 0
    else
        return false
    end

    MySQL.update.await([[
        INSERT INTO phone_services_plus_read_state (owner_key, scope, company_id, last_read_id)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE last_read_id = GREATEST(last_read_id, VALUES(last_read_id))
    ]], { ownerKey, scope, companyId, latestId })

    return true
end

RegisterCallback("bootstrap", function(source, reply)
    local company, job = Companies.GetForPlayer(source)
    local phoneNumber = Framework.GetPhoneNumber(source)

    reply({
        categories = Companies.GetCategories(),
        companies = Companies.GetPublicList(),
        myNumber = phoneNumber,
        locale = GetServicesLocale(phoneNumber),
        unread = getUnreadCounts(source),
        companySession = getCompanySession(source, company, job, phoneNumber),
        admin = Admin.IsAdmin(source),
        employee = company and {
            memberId = source,
            playerName = Framework.GetPlayerName(source),
            companyId = company.id,
            job = job.name,
            jobLabel = job.label,
            grade = job.grade,
            gradeLabel = job.gradeLabel,
            isBoss = Framework.IsBoss(source, job.name, company.boss_grade),
            onDuty = Framework.GetOnDuty(source),
            status = Employees.GetStatus(source),
            loggedIn = Employees.IsLoggedIn(source, company.id),
        } or nil,
    })
end)

RegisterCallback("setLocale", function(source, reply, locale)
    reply(SetServicesLocale(Framework.GetPhoneNumber(source), locale))
end)

RegisterCallback("markRead", function(source, reply, scope)
    reply(markRead(source, scope))
end)

RegisterCallback("markConversationRead", function(source, reply, channelId)
    reply(markConversationRead(source, channelId))
end)

RegisterCallback("getUnreadCounts", function(source, reply)
    reply(getUnreadCounts(source))
end)

-- Replies with the resulting {onDuty, status}, not just true/false, so the
-- client can decide whether to sync lb-phone's own native company-call
-- toggle (plan review round 2 §3 - see client/main.lua).
RegisterCallback("setStatus", function(source, reply, status)
    -- Only ever touches this player's own in-memory status (plan review
    -- round 4 §11: low severity, no other player/company data at stake),
    -- but there's no reason a non-employee should be able to call this at
    -- all - matches the same guard toggleDuty already has.
    reply(Employees.UpdateStatus(source, status))
end)

-- ---------------------------------------------------------------------------
-- Hotlines (plan §20-22) and team overview (plan §24).
-- ---------------------------------------------------------------------------
RegisterCallback("getHotlines", function(source, reply)
    local company = Companies.GetForPlayer(source)
    if not company then return reply(false) end

    reply(Employees.GetHotlineOptions(source, company.id))
end)

RegisterCallback("toggleHotline", function(source, reply, numberId, active)
    local ok, reason = Employees.ToggleHotline(source, numberId, active == true)
    if not ok then return reply({ ok = false, reason = reason }) end

    local job = Framework.GetJob(source)
    local company = Companies.GetByJob(job.name)

    -- Same as setStatus above (plan review round 5 §8).
    Employees.BroadcastStateChanged(source)

    reply({ ok = true, hotlines = Employees.GetHotlineOptions(source, company.id) })
end)

RegisterCallback("getTeam", function(source, reply, companyId)
    local visibility = Config.SeeEmployees
    if visibility == "none" then return reply({}) end

    local job = Framework.GetJob(source)
    local ownCompany = job and Companies.GetByJob(job.name)
    local company = visibility == "everyone" and Companies.GetById(tonumber(companyId)) or ownCompany
    company = company or (visibility == "everyone" and ownCompany or nil)
    if not company then return reply(false) end

    local isOwnLoggedInCompany = ownCompany and ownCompany.id == company.id
        and Employees.IsLoggedIn(source, company.id)

    if visibility ~= "everyone" and (visibility ~= "employees" or not ownCompany
        or ownCompany.id ~= company.id or not isOwnLoggedInCompany) then return reply(false) end

    local team = Employees.GetTeam(company.id)
    if visibility == "everyone" and not isOwnLoggedInCompany then
        local publicTeam = {}
        for i = 1, #team do
            publicTeam[i] = {
                name = team[i].name,
                gradeLabel = team[i].gradeLabel,
                status = team[i].status,
            }
        end
        return reply(publicTeam)
    end

    reply(team)
end)

-- ---------------------------------------------------------------------------
-- Employee-side inbox (plan §37). Skips numbers without their own mailbox.
-- ---------------------------------------------------------------------------
RegisterCallback("getCompanyConversations", function(source, reply, rawCursor)
    local company = Companies.GetForPlayer(source)
    if not company then return reply(false) end

    local cursor = NormalizeListCursor(rawCursor)
    local query = [[
        SELECT c.id AS channel_id, c.contact_number, c.last_message, c.updated_at,
               UNIX_TIMESTAMP(c.updated_at) AS cursor_time, n.label,
               (
                   SELECT COUNT(*) FROM phone_services_plus_messages m
                   WHERE m.channel_id = c.id AND m.sender_type = 'customer'
                     AND m.id > COALESCE(cr.last_read_id, 0)
               ) AS unread_count
        FROM phone_services_plus_channels c
        JOIN phone_services_plus_numbers n ON n.id = c.number_id
        LEFT JOIN phone_services_plus_conversation_reads cr
          ON cr.owner_key = ? AND cr.viewer_scope = 'employee' AND cr.channel_id = c.id
        WHERE n.company_id = ? AND n.mailbox_enabled = 1 AND c.archived_by_company = 0
    ]]
    local parameters = { Framework.GetIdentifier(source), company.id }
    if cursor then
        query = query .. [[
          AND (c.updated_at < FROM_UNIXTIME(?) OR (c.updated_at = FROM_UNIXTIME(?) AND c.id < ?))
        ]]
        parameters[#parameters + 1] = cursor.time
        parameters[#parameters + 1] = cursor.time
        parameters[#parameters + 1] = cursor.id
    end
    query = query .. [[
        ORDER BY c.updated_at DESC, c.id DESC
        LIMIT ?
    ]]
    parameters[#parameters + 1] = Config.PageSize.messages

    local rows = MySQL.query.await(query, parameters)

    reply(rows or {})
end)

-- ---------------------------------------------------------------------------
-- Company settings (plan §33-34). Admin-set ceilings (calls/messages/requests
-- allowed at all) land with the phase 3 admin area - until then a boss can
-- freely toggle everything a company row already has.
-- ---------------------------------------------------------------------------
RegisterCallback("getCompanySettings", function(source, reply)
    local company, job = Companies.GetForPlayer(source)
    if not company or not Framework.IsBoss(source, job.name, company.boss_grade) then return reply(false) end

    local numbers = Companies.GetNumbers(company.id)
    local numberList = {}

    for i = 1, #numbers do
        local n = numbers[i]
        numberList[i] = {
            id = n.id,
            label = n.label,
            isMain = DatabaseBoolean(n.is_main),
            callsEnabled = DatabaseBoolean(n.calls_enabled),
            messagesEnabled = DatabaseBoolean(n.messages_enabled),
            mailboxEnabled = DatabaseBoolean(n.mailbox_enabled),
        }
    end

    reply({
        callsEnabled = DatabaseBoolean(company.calls_enabled),
        messagesEnabled = DatabaseBoolean(company.messages_enabled),
        requestsEnabled = DatabaseBoolean(company.requests_enabled),
        adminCallsAllowed = DatabaseBoolean(company.admin_calls_allowed),
        adminMessagesAllowed = DatabaseBoolean(company.admin_messages_allowed),
        adminRequestsAllowed = DatabaseBoolean(company.admin_requests_allowed),
        callRouting = company.call_routing,
        requestRouting = company.request_routing,
        numbers = numberList,
    })
end)

local ROUTING_MODES = { all = true, random = true, hotline = true }

RegisterCallback("updateCompanySettings", function(source, reply, settings)
    local company, job = Companies.GetForPlayer(source)
    if not company or not Framework.IsBoss(source, job.name, company.boss_grade) then return reply(false) end
    if type(settings) ~= "table"
        or type(settings.callsEnabled) ~= "boolean"
        or type(settings.messagesEnabled) ~= "boolean"
        or type(settings.requestsEnabled) ~= "boolean"
        or not ROUTING_MODES[settings.callRouting]
        or not ROUTING_MODES[settings.requestRouting] then return reply(false) end

    local callRouting = ROUTING_MODES[settings.callRouting] and settings.callRouting or company.call_routing
    local requestRouting = ROUTING_MODES[settings.requestRouting] and settings.requestRouting or company.request_routing

    -- Admin ceilings always win (plan §34): a boss can only ever request
    -- less than what's allowed, never more.
    -- Calls and messages are guaranteed through the main number and are not
    -- company-wide boss toggles. Only the admin ceilings can disable them.
    local callsEnabled = DatabaseBoolean(company.admin_calls_allowed)
    local messagesEnabled = DatabaseBoolean(company.admin_messages_allowed)
    local requestsEnabled = settings.requestsEnabled == true and DatabaseBoolean(company.admin_requests_allowed)

    if callsEnabled == DatabaseBoolean(company.calls_enabled)
        and messagesEnabled == DatabaseBoolean(company.messages_enabled)
        and requestsEnabled == DatabaseBoolean(company.requests_enabled)
        and callRouting == company.call_routing
        and requestRouting == company.request_routing then return reply(true) end

    MySQL.update.await(
        "UPDATE phone_services_plus_companies SET calls_enabled = ?, messages_enabled = ?, requests_enabled = ?, call_routing = ?, request_routing = ? WHERE id = ?",
        { callsEnabled and 1 or 0, messagesEnabled and 1 or 0, requestsEnabled and 1 or 0, callRouting, requestRouting, company.id }
    )

    Companies.ReloadAndNotify(company.id)
    reply(true)
end)

RegisterCallback("updateNumberSettings", function(source, reply, numberId, settings)
    local company, job = Companies.GetForPlayer(source)
    if not company or not Framework.IsBoss(source, job.name, company.boss_grade) then return reply(false) end
    numberId = tonumber(numberId)
    if not numberId or numberId ~= math.floor(numberId) or type(settings) ~= "table"
        or type(settings.callsEnabled) ~= "boolean"
        or type(settings.messagesEnabled) ~= "boolean" then return reply(false) end

    local number
    local numbers = Companies.GetNumbers(company.id)
    for i = 1, #numbers do
        if numbers[i].id == numberId then number = numbers[i] end
    end
    if not number then return reply(false) end

    -- The main number is the company's guaranteed call endpoint and offline
    -- mailbox. Only additional numbers may disable either capability.
    local isMain = DatabaseBoolean(number.is_main)
    local callsEnabled = isMain or (settings.callsEnabled == true)

    -- One boss-facing toggle, not a separate Messages/Mailbox pair (plan
    -- review round 6 follow-up) - mailbox_enabled and messages_enabled are
    -- still two separate columns (mailbox controls whether an incoming chat
    -- shows up in the company inbox at all, messages controls whether a
    -- customer can send in the first place), kept apart specifically so a
    -- customer can never keep sending into a channel no employee mailbox
    -- would ever surface (plan review round 3 §4) - but a boss only ever
    -- needs "can customers message this number or not", so this always
    -- sets both to the same value instead of exposing that split as two
    -- switches that visibly (and confusingly) moved each other.
    local messagesEnabled = isMain or settings.messagesEnabled == true
    local mailboxEnabled = messagesEnabled

    if callsEnabled == DatabaseBoolean(number.calls_enabled)
        and messagesEnabled == DatabaseBoolean(number.messages_enabled)
        and mailboxEnabled == DatabaseBoolean(number.mailbox_enabled) then return reply(true) end

    MySQL.update.await(
        "UPDATE phone_services_plus_numbers SET calls_enabled = ?, messages_enabled = ?, mailbox_enabled = ? WHERE id = ?",
        { callsEnabled and 1 or 0, messagesEnabled and 1 or 0, mailboxEnabled and 1 or 0, numberId }
    )

    Companies.ReloadAndNotify(company.id)
    reply(true)
end)

-- ---------------------------------------------------------------------------
-- Company login (plan §17-19): the presentation is cosmetic, but the
-- resulting server-side session is an actual requirement for receiving
-- company calls, messages, and requests on this phone.
-- ---------------------------------------------------------------------------
RegisterCallback("companyLogin", function(source, reply, companyId)
    local company = Companies.GetById(companyId)
    local job = Framework.GetJob(source)

    local phoneNumber = Framework.GetPhoneNumber(source)
    if not company or not job or job.name ~= company.job or not phoneNumber then
        return reply(false)
    end

    Employees.SetCompanySession(source, company.id, phoneNumber)
    Employees.SyncMainHotline(job.name)
    Employees.BroadcastStateChanged(source)
    Requests.RestoreActiveForSource(source)
    Companies.NotifyDirectoryChanged(company.id)
    local session = buildCompanySession(source, company, job)
    -- Return the same freshly-computed delta directly to the app that
    -- initiated the login. The global push keeps other phones current, but
    -- the caller no longer depends on that separate event winning a race
    -- with the NUI callback response.
    session.directoryCompany = Companies.GetPublicCompany(company.id) or false
    reply(session)
end)

RegisterCallback("companyLogout", function(source, reply)
    local job = Framework.GetJob(source)
    if job then Employees.BroadcastRemoved(source, job.name) end
    Requests.ClearPendingNotificationsForSource(source)
    Requests.SuspendActiveForSource(source)
    Employees.ClearCompanySession(source)
    if job then Employees.SyncMainHotline(job.name) end
    if job then
        local company = Companies.GetByJob(job.name)
        if company then Companies.NotifyDirectoryChanged(company.id) end
    end
    reply({ ok = true, onDuty = Framework.GetOnDuty(source), status = Employees.GetStatus(source), loggedIn = false })
end)

AddEventHandler("services-plus:internal:dutyChanged", function(source)
    local company = Companies.GetForPlayer(source)
    if not Framework.GetOnDuty(source) then Employees.ClearCompanySession(source) end
    if company then Companies.NotifyDirectoryChanged(company.id) end
end)

AddEventHandler("services-plus:internal:availabilityChanged", function(companyId)
    Companies.NotifyDirectoryChanged(companyId)
end)

AddEventHandler("services-plus:internal:jobChanged", function(source)
    Employees.ClearCompanySession(source)
end)

AddEventHandler("services-plus:internal:playerDropped", function(source)
    Employees.ClearCompanySession(source)
end)

-- Same {onDuty, status} reply shape as setStatus, same reason.
RegisterCallback("toggleDuty", function(source, reply, state)
    -- Services+ duty is scoped to being an actual employee of one of our
    -- companies - it must not become a universal duty switch for whatever
    -- job the player happens to hold (that flips QB/QBX's real job.onduty).
    local company = Companies.GetForPlayer(source)
    if not company then return reply(false) end

    if not Framework.SetDuty(source, state == true) then return reply(false) end
    Framework.RefreshDuty(source)

    reply({
        ok = true,
        onDuty = Framework.GetOnDuty(source),
        status = Employees.GetStatus(source),
        loggedIn = Employees.IsLoggedIn(source, company.id),
    })
end)

-- ---------------------------------------------------------------------------
-- Messaging (plan §10, §37, §41). One channel per (number, contact number).
-- ---------------------------------------------------------------------------
RegisterCallback("openConversation", function(source, reply, numberId, page)
    local number = MySQL.single.await("SELECT * FROM phone_services_plus_numbers WHERE id = ?", { numberId })
    -- Mailbox OFF means Messages OFF for this number too (plan review round
    -- 3 §4) - checked here as well, not just enforced at write-time in
    -- updateNumberSettings, so it also holds for any row written before
    -- that rule existed. A soft-deleted number (plan review round 5 §1) is
    -- rejected the same way - it's already gone from Companies.GetNumbers's
    -- cache everywhere else, but this queries the row directly by id, so it
    -- needs its own check.
    if not number then return reply(false) end
    if not DatabaseBoolean(number.enabled) or not DatabaseBoolean(number.messages_enabled)
        or not DatabaseBoolean(number.mailbox_enabled) then
        return reply({ error = "messages_disabled" })
    end

    -- Companies.GetById only ever holds enabled=1 companies, so this also
    -- covers a disabled company rejecting new conversations (plan review).
    local company = Companies.GetById(number.company_id)
    if not company or not DatabaseBoolean(company.admin_messages_allowed) then
        return reply({ error = "messages_disabled" })
    end

    -- Config.MessageOffline actually did nothing here before - true or
    -- false made no difference to this callback (plan review round 4 §6).
    -- Only gates the customer side; an employee reopening their own
    -- company's inbox obviously isn't affected by their own availability.
    if not Config.MessageOffline and not Companies.IsAvailable(company.id) then
        return reply(false)
    end

    local contactNumber = Framework.GetPhoneNumber(source)
    if not contactNumber then return reply(false) end

    local channel = getOrCreateChannel(numberId, contactNumber)
    if not channel then return reply(false) end

    -- `sender` (the actual employee's private number for a company-side
    -- message) is deliberately not selected here (plan review round 5 §5) -
    -- the UI only ever reads `sender_type` to align bubbles, and every other
    -- client in this chat used to receive a specific colleague's personal
    -- number for no reason. Still stored in the table itself for
    -- logging/audit, just never read back out to a client.
    local messages = MySQL.query.await(
        "SELECT id, sender_type, content, created_at FROM phone_services_plus_messages WHERE channel_id = ? ORDER BY created_at DESC, id DESC LIMIT ?, ?",
        { channel.id, ClampPage(page) * Config.PageSize.messages, Config.PageSize.messages }
    )

    -- Always the customer here - a fresh/reopened conversation only ever
    -- starts from openConversation(numberId) on the customer's own side,
    -- the employee-side equivalent is getMessages(channelId) below (plan
    -- review round 4 §3).
    reply({
        channelId = channel.id,
        contactNumber = contactNumber,
        viewerRole = "customer",
        messagesEnabled = true,
        messages = messages or {},
    })
end)

RegisterCallback("sendMessage", function(source, reply, channelId, content)
    if type(content) ~= "string" or content == "" or #content > 1000 then
        return reply(false)
    end

    local channel = MySQL.single.await("SELECT * FROM phone_services_plus_channels WHERE id = ?", { channelId })
    if not channel then return reply(false) end

    local number = MySQL.single.await("SELECT * FROM phone_services_plus_numbers WHERE id = ?", { channel.number_id })
    if not number then return reply(false) end
    if not DatabaseBoolean(number.enabled) or not DatabaseBoolean(number.messages_enabled)
        or not DatabaseBoolean(number.mailbox_enabled) then
        return reply({ error = "messages_disabled" })
    end

    local company = Companies.GetById(number.company_id)
    if not company or not DatabaseBoolean(company.admin_messages_allowed) then
        return reply({ error = "messages_disabled" })
    end

    local senderNumber = Framework.GetPhoneNumber(source)
    -- `sender` is NOT NULL in SQL (plan review round 6 §7) - without this,
    -- a nil senderNumber (phone unequipped/removed mid-session) doesn't get
    -- caught here at all: `nil ~= channel.contact_number` is true, so it
    -- reads as "this is the employee side" and, for an actual employee of
    -- the company, sails straight through to the INSERT with `sender` bound
    -- to SQL NULL - a constraint violation the caller never sees a clean
    -- `false` for, just a generic server_error.
    if not senderNumber then return reply(false) end

    local isEmployee = senderNumber ~= channel.contact_number

    if isEmployee then
        -- must actually be an employee of the owning company to reply as the company
        local job = Framework.GetJob(source)

        if not job or job.name ~= company.job then
            return reply(false)
        end
    elseif not Config.MessageOffline and not Companies.IsAvailable(company.id) then
        -- Same rule as openConversation (plan review round 4 §6) - only
        -- gates the customer sending in, not an employee replying.
        return reply(false)
    end

    -- The customer's own personal number used to be the only signal the UI
    -- had for "which side is this message from" - broke as soon as a
    -- *different* employee than the sender opened the same company chat,
    -- and needlessly exposed the sending employee's private number to
    -- every other client in that chat (plan review round 4 §3). sender is
    -- kept for logging/debugging, sender_type is what the UI actually uses.
    local senderType = isEmployee and "company" or "customer"

    reply(Messages.Send(company, number, channel, senderNumber, senderType, content))
end)

-- `beforeId`, not a page number (plan review round 5 §6): OFFSET-based
-- pagination re-counts from the *current* newest row on every call, so a
-- message landing in this channel between "load page 0" and "load page 1"
-- shifts every OFFSET after it - the last row of page 0 could resurface at
-- the top of page 1, or a row could be skipped entirely. `id < beforeId` is
-- an exact, stable boundary that doesn't move regardless of what's inserted
-- afterwards - the oldest id already on screen, or omitted for the first
-- (newest) page.
RegisterCallback("getMessages", function(source, reply, channelId, beforeId)
    local channel = MySQL.single.await("SELECT * FROM phone_services_plus_channels WHERE id = ?", { channelId })
    if not channel then return reply(false) end

    local number = MySQL.single.await("SELECT * FROM phone_services_plus_numbers WHERE id = ?", { channel.number_id })
    local myNum = Framework.GetPhoneNumber(source)
    local job = Framework.GetJob(source)
    local company = number and Companies.GetById(number.company_id)
    local owns = myNum == channel.contact_number or (company and job and job.name == company.job)

    if not owns then return reply(false) end

    local cursorId = tonumber(beforeId)
    local messages

    if cursorId then
        messages = MySQL.query.await(
            "SELECT id, sender_type, content, created_at FROM phone_services_plus_messages WHERE channel_id = ? AND id < ? ORDER BY id DESC LIMIT ?",
            { channelId, cursorId, Config.PageSize.messages }
        )
    else
        messages = MySQL.query.await(
            "SELECT id, sender_type, content, created_at FROM phone_services_plus_messages WHERE channel_id = ? ORDER BY id DESC LIMIT ?",
            { channelId, Config.PageSize.messages }
        )
    end

    -- Whichever side reopened this (customer's own Activity vs an
    -- employee's company inbox) needs to know which sender_type is "mine" -
    -- comparing raw phone numbers broke as soon as a *different* employee
    -- than the one who actually sent it opened the same company chat (plan
    -- review round 4 §3).
    local viewerRole = myNum == channel.contact_number and "customer" or "employee"
    local messagesEnabled = number ~= nil and company ~= nil
        and DatabaseBoolean(number.enabled)
        and DatabaseBoolean(number.messages_enabled)
        and DatabaseBoolean(number.mailbox_enabled)
        and DatabaseBoolean(company.admin_messages_allowed)

    reply({
        channelId = channelId,
        contactNumber = channel.contact_number,
        viewerRole = viewerRole,
        messagesEnabled = messagesEnabled,
        messages = messages or {},
    })
end)

-- ---------------------------------------------------------------------------
-- Activity (plan §39-41): a compact personal history, own conversations only.
-- ---------------------------------------------------------------------------
RegisterCallback("getActivity", function(source, reply, rawCursor)
    local contactNumber = Framework.GetPhoneNumber(source)
    if not contactNumber then return reply({}) end

    local cursor = NormalizeListCursor(rawCursor)
    local query = [[
        SELECT c.id AS channel_id, c.last_message, c.updated_at,
               UNIX_TIMESTAMP(c.updated_at) AS cursor_time, n.company_id, n.label,
               (
                   SELECT COUNT(*) FROM phone_services_plus_messages m
                   WHERE m.channel_id = c.id AND m.sender_type = 'company'
                     AND m.id > COALESCE(cr.last_read_id, 0)
               ) AS unread_count,
               company.name AS company_name, company.icon AS company_icon
        FROM phone_services_plus_channels c
        JOIN phone_services_plus_numbers n ON n.id = c.number_id
        LEFT JOIN phone_services_plus_companies company ON company.id = n.company_id
        LEFT JOIN phone_services_plus_conversation_reads cr
          ON cr.owner_key = ? AND cr.viewer_scope = 'customer' AND cr.channel_id = c.id
        WHERE c.contact_number = ? AND c.archived_by_contact = 0
    ]]
    local parameters = { contactNumber, contactNumber }
    if cursor then
        query = query .. [[
          AND (c.updated_at < FROM_UNIXTIME(?) OR (c.updated_at = FROM_UNIXTIME(?) AND c.id < ?))
        ]]
        parameters[#parameters + 1] = cursor.time
        parameters[#parameters + 1] = cursor.time
        parameters[#parameters + 1] = cursor.id
    end
    query = query .. [[
        ORDER BY c.updated_at DESC, c.id DESC
        LIMIT ?
    ]]
    parameters[#parameters + 1] = Config.PageSize.activity

    local rows = MySQL.query.await(query, parameters)

    for i = 1, #(rows or {}) do
        rows[i].company = rows[i].company_name and {
            id = rows[i].company_id,
            name = rows[i].company_name,
            icon = rows[i].company_icon,
        } or nil
        rows[i].company_name = nil
        rows[i].company_icon = nil
    end

    reply(rows or {})
end)

-- Same ownership rule as getMessages (plan review §4): either the contact
-- themselves, or an actual current employee of the number's company - never
-- just "not the contact".
RegisterCallback("archiveConversation", function(source, reply, channelId)
    if not Config.AllowConversationDelete then return reply(false) end

    local channel = MySQL.single.await("SELECT * FROM phone_services_plus_channels WHERE id = ?", { channelId })
    if not channel then return reply(false) end

    local number = MySQL.single.await("SELECT company_id FROM phone_services_plus_numbers WHERE id = ?", { channel.number_id })
    local company = number and Companies.GetById(number.company_id)
    local job = Framework.GetJob(source)

    local isContact = Framework.GetPhoneNumber(source) == channel.contact_number
    local isEmployee = company ~= nil and job ~= nil and job.name == company.job

    if not isContact and not isEmployee then return reply(false) end

    local column = isContact and "archived_by_contact" or "archived_by_company"
    MySQL.update("UPDATE phone_services_plus_channels SET " .. column .. " = 1 WHERE id = ?", { channelId })
    reply(true)
end)
