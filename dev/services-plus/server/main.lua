--[[
    NUI-facing RPC handlers for the Services+ custom app. Everything here is
    called from client/main.lua's RegisterNUICallback via ServerCallback(),
    never trusted from the client beyond "this is what the player asked for"
    (plan §62).
]]

local function getOrCreateChannel(numberId, contactNumber)
    local channel = MySQL.single.await(
        "SELECT * FROM phone_services_plus_channels WHERE number_id = ? AND contact_number = ?",
        { numberId, contactNumber }
    )

    if channel then return channel end

    local id = MySQL.insert.await(
        "INSERT INTO phone_services_plus_channels (number_id, contact_number) VALUES (?, ?)",
        { numberId, contactNumber }
    )

    return { id = id, number_id = numberId, contact_number = contactNumber, last_message = nil }
end

-- ---------------------------------------------------------------------------
-- Bootstrap: one combined payload for opening the app (plan §63-64: as few
-- round trips as possible).
-- ---------------------------------------------------------------------------
RegisterCallback("bootstrap", function(source, reply)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)

    reply({
        categories = Companies.GetCategories(),
        companies = Companies.GetPublicList(),
        myNumber = Framework.GetPhoneNumber(source),
        admin = Admin.IsAdmin(source),
        employee = company and {
            companyId = company.id,
            job = job.name,
            jobLabel = job.label,
            grade = job.grade,
            gradeLabel = job.gradeLabel,
            isBoss = job.isBoss,
            onDuty = Framework.GetOnDuty(source),
            status = Employees.GetStatus(source),
        } or nil,
    })
end)

RegisterCallback("setStatus", function(source, reply, status)
    reply(Employees.SetStatus(source, status))
end)

-- ---------------------------------------------------------------------------
-- Hotlines (plan §20-22) and team overview (plan §24).
-- ---------------------------------------------------------------------------
RegisterCallback("getHotlines", function(source, reply)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company then return reply(false) end

    reply(Employees.GetHotlineOptions(source, company.id))
end)

RegisterCallback("toggleHotline", function(source, reply, numberId, active)
    local ok, reason = Employees.ToggleHotline(source, numberId, active == true)
    if not ok then return reply({ ok = false, reason = reason }) end

    local job = Framework.GetJob(source)
    local company = Companies.GetByJob(job.name)

    reply({ ok = true, hotlines = Employees.GetHotlineOptions(source, company.id) })
end)

RegisterCallback("getTeam", function(source, reply)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company then return reply(false) end

    reply(Employees.GetTeam(company.id))
end)

-- ---------------------------------------------------------------------------
-- Employee-side inbox (plan §37). Skips numbers without their own mailbox.
-- ---------------------------------------------------------------------------
RegisterCallback("getCompanyConversations", function(source, reply, page)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company then return reply(false) end

    local rows = MySQL.query.await([[
        SELECT c.id AS channel_id, c.contact_number, c.last_message, c.updated_at, n.label
        FROM phone_services_plus_channels c
        JOIN phone_services_plus_numbers n ON n.id = c.number_id
        WHERE n.company_id = ? AND n.mailbox_enabled = 1 AND c.archived_by_company = 0
        ORDER BY c.updated_at DESC
        LIMIT ?, ?
    ]], { company.id, (page or 0) * Config.PageSize.messages, Config.PageSize.messages })

    reply(rows or {})
end)

-- ---------------------------------------------------------------------------
-- Company settings (plan §33-34). Admin-set ceilings (calls/messages/requests
-- allowed at all) land with the phase 3 admin area - until then a boss can
-- freely toggle everything a company row already has.
-- ---------------------------------------------------------------------------
RegisterCallback("getCompanySettings", function(source, reply)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company or not job.isBoss then return reply(false) end

    local numbers = Companies.GetNumbers(company.id)
    local numberList = {}

    for i = 1, #numbers do
        local n = numbers[i]
        numberList[i] = {
            id = n.id,
            label = n.label,
            isMain = n.is_main == 1,
            callsEnabled = n.calls_enabled == 1,
            messagesEnabled = n.messages_enabled == 1,
            mailboxEnabled = n.mailbox_enabled == 1,
        }
    end

    reply({
        callsEnabled = company.calls_enabled == 1,
        messagesEnabled = company.messages_enabled == 1,
        requestsEnabled = company.requests_enabled == 1,
        adminCallsAllowed = company.admin_calls_allowed == 1,
        adminMessagesAllowed = company.admin_messages_allowed == 1,
        adminRequestsAllowed = company.admin_requests_allowed == 1,
        callRouting = company.call_routing,
        requestRouting = company.request_routing,
        numbers = numberList,
    })
end)

local ROUTING_MODES = { all = true, random = true, hotline = true }

RegisterCallback("updateCompanySettings", function(source, reply, settings)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company or not job.isBoss then return reply(false) end

    local callRouting = ROUTING_MODES[settings.callRouting] and settings.callRouting or company.call_routing
    local requestRouting = ROUTING_MODES[settings.requestRouting] and settings.requestRouting or company.request_routing

    -- Admin ceilings always win (plan §34): a boss can only ever request
    -- less than what's allowed, never more.
    local callsEnabled = settings.callsEnabled and company.admin_calls_allowed == 1
    local messagesEnabled = settings.messagesEnabled and company.admin_messages_allowed == 1
    local requestsEnabled = settings.requestsEnabled and company.admin_requests_allowed == 1

    MySQL.update.await(
        "UPDATE phone_services_plus_companies SET calls_enabled = ?, messages_enabled = ?, requests_enabled = ?, call_routing = ?, request_routing = ? WHERE id = ?",
        { callsEnabled and 1 or 0, messagesEnabled and 1 or 0, requestsEnabled and 1 or 0, callRouting, requestRouting, company.id }
    )

    Companies.Reload()
    reply(true)
end)

RegisterCallback("updateNumberSettings", function(source, reply, numberId, settings)
    local job = Framework.GetJob(source)
    local company = job and Companies.GetByJob(job.name)
    if not company or not job.isBoss then return reply(false) end

    local number
    local numbers = Companies.GetNumbers(company.id)
    for i = 1, #numbers do
        if numbers[i].id == numberId then number = numbers[i] end
    end
    if not number then return reply(false) end

    -- the main number's calls/messages can never be fully disabled (plan §8)
    local callsEnabled = number.is_main == 1 or (settings.callsEnabled == true)
    local messagesEnabled = number.is_main == 1 or (settings.messagesEnabled == true)

    MySQL.update.await(
        "UPDATE phone_services_plus_numbers SET calls_enabled = ?, messages_enabled = ?, mailbox_enabled = ? WHERE id = ?",
        { callsEnabled and 1 or 0, messagesEnabled and 1 or 0, settings.mailboxEnabled and 1 or 0, numberId }
    )

    Companies.Reload()
    reply(true)
end)

-- ---------------------------------------------------------------------------
-- Company "fake login" (plan §17-19): server-side authority check, the
-- animation/username/password on the client side is purely cosmetic.
-- ---------------------------------------------------------------------------
RegisterCallback("companyLogin", function(source, reply, companyId)
    local company = Companies.GetById(companyId)
    local job = Framework.GetJob(source)

    if not company or not job or job.name ~= company.job then
        return reply(false)
    end

    reply({
        company = { id = company.id, name = company.name, job = company.job, icon = company.icon },
        employee = {
            name = Framework.GetPlayerName(source),
            grade = job.grade,
            gradeLabel = job.gradeLabel,
            isBoss = job.isBoss,
            onDuty = Framework.GetOnDuty(source),
        },
    })
end)

RegisterCallback("toggleDuty", function(source, reply, state)
    reply(Framework.SetDuty(source, state == true))
end)

-- ---------------------------------------------------------------------------
-- Messaging (plan §10, §37, §41). One channel per (number, contact number).
-- ---------------------------------------------------------------------------
RegisterCallback("openConversation", function(source, reply, numberId, page)
    local number = MySQL.single.await("SELECT * FROM phone_services_plus_numbers WHERE id = ?", { numberId })
    if not number or number.messages_enabled ~= 1 then return reply(false) end

    local contactNumber = Framework.GetPhoneNumber(source)
    if not contactNumber then return reply(false) end

    local channel = getOrCreateChannel(numberId, contactNumber)

    local messages = MySQL.query.await(
        "SELECT id, sender, content, created_at FROM phone_services_plus_messages WHERE channel_id = ? ORDER BY created_at DESC LIMIT ?, ?",
        { channel.id, (page or 0) * Config.PageSize.messages, Config.PageSize.messages }
    )

    reply({ channelId = channel.id, contactNumber = contactNumber, messages = messages or {} })
end)

RegisterCallback("sendMessage", function(source, reply, channelId, content)
    if type(content) ~= "string" or content == "" or #content > 1000 then
        return reply(false)
    end

    local channel = MySQL.single.await("SELECT * FROM phone_services_plus_channels WHERE id = ?", { channelId })
    if not channel then return reply(false) end

    local number = MySQL.single.await("SELECT * FROM phone_services_plus_numbers WHERE id = ?", { channel.number_id })
    if not number or number.messages_enabled ~= 1 then return reply(false) end

    local senderNumber = Framework.GetPhoneNumber(source)
    local isEmployee = senderNumber ~= channel.contact_number

    if isEmployee then
        -- must actually be an employee of the owning company to reply as the company
        local company = Companies.GetById(number.company_id)
        local job = Framework.GetJob(source)

        if not company or not job or job.name ~= company.job then
            return reply(false)
        end
    end

    local messageId = MySQL.insert.await(
        "INSERT INTO phone_services_plus_messages (channel_id, sender, content) VALUES (?, ?, ?)",
        { channelId, senderNumber, content }
    )

    MySQL.update("UPDATE phone_services_plus_channels SET last_message = ? WHERE id = ?", { content:sub(1, 100), channelId })

    local payload = { channelId = channelId, id = messageId, sender = senderNumber, content = content }

    if isEmployee then
        exports["lb-phone"]:SendNotification(channel.contact_number, {
            app = Config.App.name,
            title = Companies.GetById(number.company_id).name,
            content = content,
        })
    else
        local company = Companies.GetById(number.company_id)
        if company then
            local staff = Framework.GetPlayersByJob(company.job)

            for i = 1, #staff do
                if Framework.GetOnDuty(staff[i]) then
                    local staffNumber = Framework.GetPhoneNumber(staff[i])
                    if staffNumber then
                        exports["lb-phone"]:SendNotification(staffNumber, {
                            app = Config.App.name,
                            title = ("%s (%s)"):format(company.name, number.label),
                            content = content,
                        })
                    end
                end
            end
        end
    end

    reply(payload)
end)

RegisterCallback("getMessages", function(source, reply, channelId, page)
    local channel = MySQL.single.await("SELECT * FROM phone_services_plus_channels WHERE id = ?", { channelId })
    if not channel then return reply(false) end

    local number = MySQL.single.await("SELECT * FROM phone_services_plus_numbers WHERE id = ?", { channel.number_id })
    local myNum = Framework.GetPhoneNumber(source)
    local job = Framework.GetJob(source)
    local company = number and Companies.GetById(number.company_id)
    local owns = myNum == channel.contact_number or (company and job and job.name == company.job)

    if not owns then return reply(false) end

    local messages = MySQL.query.await(
        "SELECT id, sender, content, created_at FROM phone_services_plus_messages WHERE channel_id = ? ORDER BY created_at DESC LIMIT ?, ?",
        { channelId, (page or 0) * Config.PageSize.messages, Config.PageSize.messages }
    )

    reply({ channelId = channelId, contactNumber = channel.contact_number, messages = messages or {} })
end)

-- ---------------------------------------------------------------------------
-- Activity (plan §39-41): a compact personal history, own conversations only.
-- ---------------------------------------------------------------------------
RegisterCallback("getActivity", function(source, reply, page)
    local contactNumber = Framework.GetPhoneNumber(source)
    if not contactNumber then return reply({}) end

    local rows = MySQL.query.await([[
        SELECT c.id AS channel_id, c.last_message, c.updated_at, n.company_id, n.label
        FROM phone_services_plus_channels c
        JOIN phone_services_plus_numbers n ON n.id = c.number_id
        WHERE c.contact_number = ? AND c.archived_by_contact = 0
        ORDER BY c.updated_at DESC
        LIMIT ?, ?
    ]], { contactNumber, (page or 0) * Config.PageSize.activity, Config.PageSize.activity })

    for i = 1, #(rows or {}) do
        local company = Companies.GetById(rows[i].company_id)
        rows[i].company = company and { id = company.id, name = company.name, icon = company.icon } or nil
    end

    reply(rows or {})
end)

RegisterCallback("archiveConversation", function(source, reply, channelId)
    if not Config.AllowConversationDelete then return reply(false) end

    local channel = MySQL.single.await("SELECT * FROM phone_services_plus_channels WHERE id = ?", { channelId })
    if not channel then return reply(false) end

    local contactNumber = Framework.GetPhoneNumber(source)
    local column = contactNumber == channel.contact_number and "archived_by_contact" or "archived_by_company"

    MySQL.update("UPDATE phone_services_plus_channels SET " .. column .. " = 1 WHERE id = ?", { channelId })
    reply(true)
end)
