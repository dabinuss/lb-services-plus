ServicesPlus.Inboxes = ServicesPlus.Inboxes or {}

local Inboxes = ServicesPlus.Inboxes

local function mediaHostAllowed(url)
    local host = url:match("^https://([^/%?#:]+)")
    if not host then return false end
    host = host:lower()
    for _, configured in ipairs(Config.AllowedMediaDomains or {}) do
        local allowed = tostring(configured):lower()
        if host == allowed then return true end
        if allowed:sub(1, 2) == "*." then
            local suffix = allowed:sub(2)
            if #host > #suffix and host:sub(-#suffix) == suffix then return true end
        end
    end
    return false
end

local function canUseNumber(employee, numberId)
    local company = employee and ServicesPlus.Companies.Get(employee.companyId)
    if not company then return false end
    for _, number in ipairs(company.numbers) do
        if number.id == numberId then return number.enabled and number.inboxEnabled and number.sharedInbox end
    end
    return false
end

local function cleanAttachments(input)
    if input == nil then return {} end
    if type(input) ~= "table" or #input > 4 then return nil end
    local result = {}
    for _, url in ipairs(input) do
        if type(url) ~= "string" or #url > 500 or not mediaHostAllowed(url) then return nil end
        result[#result + 1] = url
    end
    return result
end

local function cleanCoords(input)
    if input == nil then return nil end
    if type(input) ~= "table" then return false end
    local x, y = tonumber(input.x), tonumber(input.y)
    if not x or not y or math.abs(x) > 10000 or math.abs(y) > 10000 then return false end
    return { x = x, y = y }
end

local function pushCompany(companyId, eventType, payload, numberId)
    for _, employee in ipairs(ServicesPlus.Employees.GetPublicForCompany(companyId)) do
        local internal = ServicesPlus.Employees.Get(employee.source)
        if not numberId or canUseNumber(internal, numberId) then
            TriggerClientEvent("services-plus:client:push", employee.source, { type = eventType, timestamp = os.time(), payload = payload })
            if eventType == "inbox.message" then
                pcall(function()
                    exports["lb-phone"]:SendNotification(employee.source, {
                        app = ServicesPlus.Constants.AppIdentifier,
                        title = payload.numberLabel or "Company inbox",
                        content = payload.body ~= "" and payload.body:sub(1, 120) or "New attachment or location"
                    })
                end)
            end
        end
    end
end

local function store(company, number, externalNumber, senderNumber, senderIdentifier, senderType, body, attachments, coords, lbResult)
    local preview = body ~= "" and body:sub(1, 500) or (coords and "Location" or "Attachment")
    local conversation = ServicesPlus.Repository.UpsertConversation(company.id, number.id, externalNumber, lbResult and lbResult.channelId or nil, preview)
    if not conversation then return nil end
    local messageId = ServicesPlus.Repository.InsertInboxMessage(conversation.id, {
        lbMessageId = lbResult and (lbResult.messageId or lbResult.id) or nil, senderNumber = senderNumber,
        senderIdentifier = senderIdentifier, senderType = senderType, body = body, attachments = attachments, coords = coords
    })
    if not messageId or messageId == 0 then return { duplicate = true, conversationId = conversation.id } end
    local payload = { conversationId = conversation.id, messageId = messageId, companyId = company.id, numberId = number.id, numberLabel = number.label, externalNumber = externalNumber, body = body, senderType = senderType, attachments = attachments, coords = coords, createdAt = os.date("!%Y-%m-%dT%H:%M:%SZ") }
    pushCompany(company.id, "inbox.message", payload, number.id)
    TriggerEvent("services-plus:server:messageReceived", payload)
    return payload
end

function Inboxes.SendCitizen(source, payload)
    local company = type(payload) == "table" and ServicesPlus.Companies.Get(payload.companyId) or nil
    if not company or not company.messagesEnabled or type(payload.body) ~= "string" or #payload.body > 2000 then return false, "validation_failed" end
    local number = company.numbers[1]
    if type(payload.numberId) == "string" then for _, candidate in ipairs(company.numbers) do if candidate.id == payload.numberId then number = candidate break end end end
    if not number or not number.enabled or not number.publicVisible or not number.inboxEnabled or not number.sharedInbox then return false, "inbox_disabled" end
    local attachments = cleanAttachments(payload.attachments); local coords = cleanCoords(payload.coords)
    if not attachments or coords == false or (#payload.body < 1 and #attachments == 0 and not coords) then return false, "validation_failed" end
    local player = ServicesPlus.Bridge.GetPlayer(source); if not player then return false, "player_unavailable" end
    local senderNumber = exports["lb-phone"]:GetEquippedPhoneNumber(source); if not senderNumber then return false, "phone_required" end
    local result
    if coords and payload.body == "" and #attachments == 0 then
        exports["lb-phone"]:SendCoords(senderNumber, number.number, vector2(coords.x, coords.y))
    else
        result = exports["lb-phone"]:SendMessage(senderNumber, number.number, payload.body, attachments)
        if not result then return false, "message_failed" end
    end
    local stored = store(company, number, senderNumber, senderNumber, player.identifier, "citizen", payload.body, attachments, coords, result)
    return stored ~= nil, stored or "message_failed"
end

function Inboxes.SendEmployee(source, payload)
    local employee = ServicesPlus.Employees.Get(source)
    if not employee or type(payload) ~= "table" or type(payload.conversationId) ~= "number" or type(payload.body) ~= "string" or #payload.body > 2000 then return false, "validation_failed" end
    local conversation = ServicesPlus.Repository.GetConversation(employee.companyId, payload.conversationId)
    if not conversation or conversation.shared_inbox ~= 1 or not canUseNumber(employee, conversation.number_id) then return false, "forbidden" end
    local attachments = cleanAttachments(payload.attachments); local coords = cleanCoords(payload.coords)
    if not attachments or coords == false or (#payload.body < 1 and #attachments == 0 and not coords) then return false, "validation_failed" end
    local result
    if coords and payload.body == "" and #attachments == 0 then
        exports["lb-phone"]:SendCoords(conversation.company_number, conversation.external_number, vector2(coords.x, coords.y))
    else
        result = exports["lb-phone"]:SendMessage(conversation.company_number, conversation.external_number, payload.body, attachments, nil, conversation.channel_id)
        if not result then return false, "message_failed" end
    end
    local company, number = ServicesPlus.Companies.FindByNumber(conversation.company_number)
    local stored = store(company, number, conversation.external_number, conversation.company_number, employee.identifier, "employee", payload.body, attachments, coords, result)
    return stored ~= nil, stored or "message_failed"
end

function Inboxes.GetCompanyList(source, cursor, limit, numberId)
    local employee = ServicesPlus.Employees.Get(source); if not employee then return false, "not_on_duty" end
    if numberId and not canUseNumber(employee, numberId) then return false, "inbox_disabled" end
    local visible = {}
    for _, conversation in ipairs(ServicesPlus.Repository.GetCompanyConversations(employee.companyId, employee.identifier, cursor, limit, numberId)) do
        if canUseNumber(employee, conversation.numberId) then visible[#visible + 1] = conversation end
    end
    return true, visible
end

function Inboxes.ValidateConfiguration()
    local domains, seen = Config.AllowedMediaDomains or {}, {}
    if #domains == 0 then
        ServicesPlus.Logger.Warn("No media domains are configured; message attachments will be rejected")
        return false
    end
    for _, configured in ipairs(domains) do
        local domain = tostring(configured):lower()
        local host = domain:sub(1, 2) == "*." and domain:sub(3) or domain
        if host == "" or host:find("[^a-z0-9%.%-]") or host:sub(1, 1) == "." or host:sub(-1) == "." then
            ServicesPlus.Logger.Warn("Invalid media domain configuration", { domain = configured })
            return false
        end
        if seen[domain] then ServicesPlus.Logger.Warn("Duplicate media domain configuration", { domain = configured }) end
        seen[domain] = true
    end
    ServicesPlus.Logger.Info("Media attachment allow-list validated", { domains = #domains })
    return true
end

function Inboxes.GetCitizenList(source, cursor, limit)
    local number = exports["lb-phone"]:GetEquippedPhoneNumber(source); if not number then return false, "phone_required" end
    return true, ServicesPlus.Repository.GetCitizenConversations(number, cursor, limit)
end

function Inboxes.GetMessages(source, conversationId, cursor, limit, citizen)
    local conversation, actorKey
    if citizen then
        local number = exports["lb-phone"]:GetEquippedPhoneNumber(source)
        conversation = MySQL.single.await("SELECT * FROM `services_plus_inbox_conversations` WHERE `id` = ? AND `external_number` = ? AND `deleted_at` IS NULL", { conversationId, number })
        actorKey = number and ("phone:" .. number) or nil
    else
        local employee = ServicesPlus.Employees.Get(source)
        conversation = employee and ServicesPlus.Repository.GetConversation(employee.companyId, conversationId) or nil
        if conversation and not canUseNumber(employee, conversation.number_id) then conversation = nil end
        actorKey = employee and ("employee:" .. employee.identifier) or nil
    end
    if not conversation then return false, "forbidden" end
    local messages = ServicesPlus.Repository.GetConversationMessages(conversationId, cursor, limit, actorKey)
    if not citizen then
        local employee = ServicesPlus.Employees.Get(source)
        if messages[1] then ServicesPlus.Repository.MarkConversationRead(conversationId, employee.identifier, messages[1].id) end
    end
    return true, { conversation = { id = conversation.id, companyId = conversation.company_id, numberId = conversation.number_id, externalNumber = conversation.external_number }, messages = messages }
end

function Inboxes.DeleteConversation(source, conversationId)
    local employee = ServicesPlus.Employees.Get(source)
    if not employee or not employee.dispatchEnabled then return false, "forbidden" end
    local conversation = ServicesPlus.Repository.GetConversation(employee.companyId, conversationId)
    if not conversation or conversation.shared_inbox ~= 1 or not canUseNumber(employee, conversation.number_id) then return false, "forbidden" end
    if not ServicesPlus.Repository.DeleteConversation(conversationId, employee.companyId, employee.identifier) then return false, "conversation_unavailable" end
    pushCompany(employee.companyId, "inbox.deleted", { id = conversationId, companyId = employee.companyId }, conversation.number_id)
    return true, { id = conversationId }
end

function Inboxes.DeleteMessage(source, messageId)
    local employee = ServicesPlus.Employees.Get(source)
    local context = ServicesPlus.Repository.GetMessageContext(messageId)
    if not employee or not employee.dispatchEnabled or not context or employee.companyId ~= context.company_id
        or context.shared_inbox ~= 1 or not canUseNumber(employee, context.number_id) then return false, "forbidden" end
    if not ServicesPlus.Repository.DeleteInboxMessage(messageId, employee.identifier) then return false, "message_unavailable" end
    pushCompany(employee.companyId, "inbox.message.deleted", { messageId = messageId, conversationId = context.conversation_id }, context.number_id)
    return true, { id = messageId, conversationId = context.conversation_id }
end

function Inboxes.React(source, payload)
    local messageId = type(payload) == "table" and tonumber(payload.messageId) or nil
    local emoji = type(payload) == "table" and payload.emoji or nil
    if not messageId or type(emoji) ~= "string" or not ServicesPlus.Constants.MessageReactions[emoji] then return false, "validation_failed" end
    local context = ServicesPlus.Repository.GetMessageContext(messageId)
    if not context then return false, "message_unavailable" end

    local actorKey
    if payload.citizen == true then
        local number = exports["lb-phone"]:GetEquippedPhoneNumber(source)
        if not number or number ~= context.external_number then return false, "forbidden" end
        actorKey = "phone:" .. number
    else
        local employee = ServicesPlus.Employees.Get(source)
        if not employee or employee.companyId ~= context.company_id or context.shared_inbox ~= 1 or not canUseNumber(employee, context.number_id) then return false, "forbidden" end
        actorKey = "employee:" .. employee.identifier
    end

    local reactions = ServicesPlus.Repository.ToggleMessageReaction(messageId, actorKey, emoji)
    local publicReactions = {}
    for _, reaction in ipairs(reactions) do publicReactions[#publicReactions + 1] = { emoji = reaction.emoji, count = reaction.count, mine = false } end
    local update = { messageId = messageId, conversationId = context.conversation_id, reactions = publicReactions }
    pushCompany(context.company_id, "inbox.reaction", update, context.number_id)
    local citizenSource = exports["lb-phone"]:GetSourceFromNumber(context.external_number)
    if citizenSource then TriggerClientEvent("services-plus:client:push", citizenSource, { type = "inbox.reaction", timestamp = os.time(), payload = update }) end
    return true, { messageId = messageId, conversationId = context.conversation_id, reactions = reactions }
end

AddEventHandler("lb-phone:messages:messageSent", function(message)
    if type(message) ~= "table" then return end
    local company, number = ServicesPlus.Companies.FindByNumber(message.recipient)
    if not company or not number or not company.messagesEnabled or not number.enabled or not number.inboxEnabled or not number.sharedInbox then return end
    local attachments = message.attachments
    if type(attachments) == "string" then local ok, decoded = pcall(json.decode, attachments); attachments = ok and decoded or {} end
    attachments = cleanAttachments(attachments or {})
    if not attachments then
        ServicesPlus.Logger.Warn("Rejected LB Phone message with disallowed attachment URL", { numberId = number.id })
        return
    end
    local senderSource = exports["lb-phone"]:GetSourceFromNumber(message.sender)
    local player = senderSource and ServicesPlus.Bridge.GetPlayer(senderSource) or nil
    store(company, number, message.sender, message.sender, player and player.identifier or nil, "citizen", message.message or "", attachments, nil, { channelId = message.channelId, messageId = message.messageId })
end)

AddEventHandler("lb-phone:newCompanyMessage", function(message)
    if type(message) ~= "table" or message.sentByEmployee then return end
    local company = ServicesPlus.Companies.Get(message.company) or ServicesPlus.Companies.FindByJob(message.company)
    if not company or not company.messagesEnabled then return end
    local number
    for _, candidate in ipairs(company.numbers) do if candidate.enabled and candidate.inboxEnabled and candidate.sharedInbox then number = candidate break end end
    if not number then return end
    store(company, number, message.sender, message.sender, nil, "citizen", message.message or "", {}, message.coords, nil)
end)
