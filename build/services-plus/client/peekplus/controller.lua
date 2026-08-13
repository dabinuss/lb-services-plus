PeekPlus = {}

local cards = {}
local queue = {}
local visibleId = nil
local suspended = {}
local actionHandlers = {}
local readyHandlers = {}
local nextId = 0
local nextActionToken = 0
local nuiReady = false
local phoneOpen = false
local callActive = false
local lastSoundAt = -math.huge
local peekWatchToken = 0
local interruptedId = nil
local runtimeId = ("%x-%x"):format(GetGameTimer(), math.random(0, 0x7fffffff))

local limits = Config.PeekPlus
local defaults = PeekPlusDefaults

local function sendNui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function countCards(owner)
    local total, owned = 0, 0
    for _, card in pairs(cards) do
        total = total + 1
        if card.owner == owner then owned = owned + 1 end
    end
    return total, owned
end

local function cleanText(value, maximum, required)
    if value == nil and not required then return nil end
    if type(value) ~= "string" then return nil, "invalid_text" end
    value = value:gsub("[%z\1-\8\11\12\14-\31]", "")
    if required and value == "" then return nil, "empty_text" end
    if #value > maximum then return nil, "text_too_long" end
    return value
end

local function validateActions(actions)
    if actions == nil then return {} end
    if type(actions) ~= "table" or #actions > limits.maxActions then
        return nil, "invalid_actions"
    end

    local result, seen = {}, {}
    for index = 1, #actions do
        local action = actions[index]
        if type(action) ~= "table" then return nil, "invalid_action" end
        local id, idError = cleanText(action.id, limits.textLimits.actionId, true)
        local label, labelError = cleanText(action.label, limits.textLimits.actionLabel, true)
        if not id then return nil, idError end
        if not label then return nil, labelError end
        if not id:match("^[%w_%-]+$") or seen[id] then return nil, "invalid_action_id" end
        seen[id] = true

        local key = action.key and tostring(action.key):upper() or nil
        if key and not defaults.allowedKeys[key] then return nil, "invalid_action_key" end
        local color = action.color or "default"
        if not defaults.allowedColors[color] then return nil, "invalid_action_color" end

        local confirm = nil
        if action.confirm ~= nil then
            if type(action.confirm) ~= "table" then return nil, "invalid_confirmation" end
            local confirmLabel, confirmError = cleanText(
                action.confirm.label or "Confirm?",
                limits.textLimits.actionLabel,
                true
            )
            if not confirmLabel then return nil, confirmError end
            local timeout = math.floor(tonumber(action.confirm.timeout) or 5000)
            if timeout < 0 or timeout > limits.actionTimeout then return nil, "invalid_confirmation_timeout" end
            confirm = { label = confirmLabel, timeout = timeout }
        end

        result[index] = { id = id, label = label, key = key, color = color, confirm = confirm }
    end
    return result
end

local function normalizeSpec(spec, partial)
    if type(spec) ~= "table" then return nil, "invalid_card" end
    local result = {}
    for _, field in ipairs({ "title", "subtitle", "description" }) do
        if spec[field] ~= nil or not partial and field == "title" then
            local value, err = cleanText(
                spec[field],
                limits.textLimits[field],
                not partial and field == "title"
            )
            if value == nil and err then return nil, err end
            result[field] = value
        end
    end

    if spec.state ~= nil or not partial then
        local state = spec.state or "pending"
        if not defaults.allowedStates[state] or state == "queued" or state == "removed" then
            return nil, "invalid_state"
        end
        result.state = state
    end
    if spec.duration ~= nil or not partial then
        local duration = math.floor(tonumber(spec.duration) or 15000)
        if duration < -1 or duration > limits.maxDuration then return nil, "invalid_duration" end
        result.duration = duration
    end
    if spec.priority ~= nil or not partial then
        local priority = math.floor(tonumber(spec.priority) or 0)
        if priority < -limits.maxPriority or priority > limits.maxPriority then return nil, "invalid_priority" end
        result.priority = priority
    end
    if spec.actions ~= nil or not partial then
        local actions, err = validateActions(spec.actions)
        if not actions then return nil, err end
        result.actions = actions
    end
    if spec.hold ~= nil or not partial then
        result.hold = spec.hold == true or spec.hold == nil and result.state == "active"
    end
    if spec.sound ~= nil or not partial then result.sound = spec.sound ~= false end
    if spec.interrupt ~= nil or not partial then result.interrupt = spec.interrupt == true end
    return result
end

local function removeFromList(list, id)
    for index = #list, 1, -1 do
        if list[index] == id then table.remove(list, index) end
    end
end

local function sortQueue()
    table.sort(queue, function(leftId, rightId)
        local left, right = cards[leftId], cards[rightId]
        if not left then return false end
        if not right then return true end
        if left.priority ~= right.priority then return left.priority > right.priority end
        return left.createdAt < right.createdAt
    end)
end

local function publicCard(card)
    if not card then return nil end
    return {
        id = card.id,
        owner = card.owner,
        revision = card.revision,
        state = card.state,
        title = card.title,
        subtitle = card.subtitle,
        description = card.description,
        duration = card.duration,
        hold = card.hold,
        priority = card.priority,
        actions = card.actions,
        createdAt = card.createdAt,
        expiresAt = card.expiresAt,
        actionInFlight = card.actionInFlight ~= nil,
        confirmAction = card.confirmAction,
    }
end

local function renderVisible(playSound)
    if not nuiReady then return end
    local card = visibleId and cards[visibleId] or nil
    if not card then
        return sendNui("peekplus:clear", {})
    end

    local canUsePhone = PeekPlusLBPhone.IsUsable()
    local canPlaySound, soundName = PeekPlusLBPhone.GetNotificationSound()
    local now = GetGameTimer()
    local shouldPlaySound = playSound == true and card.sound and not card.soundPlayed
        and canUsePhone and canPlaySound
        and now - lastSoundAt >= limits.soundThrottle
    if shouldPlaySound then
        card.soundPlayed = true
        lastSoundAt = now
    end

    local remaining
    if card.hold or card.duration < 0 then
        remaining = -1
    elseif card.duration == 0 then
        remaining = 0
    else
        remaining = math.max(0, card.expiresAt - now)
    end
    sendNui("peekplus:render", {
        card = publicCard(card),
        phoneOpen = phoneOpen,
        callActive = callActive,
        holdPeek = canUsePhone and not phoneOpen and (card.hold or remaining ~= 0),
        peekDuration = card.hold and -1 or remaining,
        forceFallback = not canUsePhone and limits.rootFallback,
        hidden = not canUsePhone and not limits.rootFallback,
        playSound = shouldPlaySound,
        soundName = soundName,
    })
end

local function watchVisible(card)
    peekWatchToken = peekWatchToken + 1
    local token = peekWatchToken
    interruptedId = nil
    if not card or card.hold or card.expiresAt == 0 then return end
    CreateThread(function()
        while token == peekWatchToken and visibleId == card.id and cards[card.id] do
            local cameraOpen = false
            pcall(function() cameraOpen = exports["lb-phone"]:IsCameraOpen() == true end)
            if cameraOpen then
                interruptedId = card.id
                sendNui("peekplus:release", {})
                return
            end
            Wait(250)
        end
    end)
end

local function expireCard(id, revision)
    local card = cards[id]
    if not card or card.revision ~= revision or card.expiresAt == 0 then return end
    local remaining = card.expiresAt - GetGameTimer()
    if remaining > 0 then
        return SetTimeout(remaining, function() expireCard(id, revision) end)
    end
    PeekPlus.Remove(id, card.owner)
end

local function scheduleExpiry(card)
    if card.expiresAt == 0 then return end
    local remaining = math.max(0, card.expiresAt - GetGameTimer())
    SetTimeout(remaining, function() expireCard(card.id, card.revision) end)
end

local function startCardTimer(card)
    if card.hold or card.duration <= 0 then
        card.expiresAt = 0
    else
        card.expiresAt = GetGameTimer() + card.duration
        scheduleExpiry(card)
    end
end

local function resumeCardTimer(card)
    if card.suspendedRemaining then
        local remaining = card.suspendedRemaining
        card.suspendedRemaining = nil
        if remaining > 0 then
            card.expiresAt = GetGameTimer() + remaining
            scheduleExpiry(card)
            return
        end
    end
    startCardTimer(card)
end

local function showNext(playSound)
    if visibleId and cards[visibleId] then return end
    visibleId = nil

    while #suspended > 0 do
        local id = table.remove(suspended)
        if cards[id] then
            visibleId = id
            cards[id].queued = false
            resumeCardTimer(cards[id])
            renderVisible(false)
            return watchVisible(cards[id])
        end
    end

    sortQueue()
    while #queue > 0 do
        local id = table.remove(queue, 1)
        local card = cards[id]
        if card then
            visibleId = id
            card.queued = false
            startCardTimer(card)
            renderVisible(playSound ~= false)
            return watchVisible(card)
        end
    end
    renderVisible(false)
end

function PeekPlus.Show(spec, owner)
    owner = type(owner) == "string" and owner or nil
    if not owner or owner == "" then return nil, "invalid_owner" end
    local total, owned = countCards(owner)
    if total >= limits.maxCards then return nil, "card_limit_reached" end
    if owned >= limits.maxCardsPerOwner then return nil, "owner_card_limit_reached" end

    local normalized, err = normalizeSpec(spec, false)
    if not normalized then return nil, err end
    nextId = nextId + 1
    local now = GetGameTimer()
    local id = ("peekplus:%s:%s:%d"):format(runtimeId, owner, nextId)
    normalized.id = id
    normalized.owner = owner
    normalized.revision = 1
    normalized.createdAt = now
    normalized.expiresAt = 0
    normalized.queued = true
    normalized.soundPlayed = false
    cards[id] = normalized

    local visible = visibleId and cards[visibleId] or nil
    if visible and normalized.interrupt and normalized.priority > visible.priority then
        if visible.expiresAt > 0 then
            visible.suspendedRemaining = math.max(0, visible.expiresAt - GetGameTimer())
            visible.expiresAt = 0
        end
        suspended[#suspended + 1] = visibleId
        visible.queued = true
        visibleId = id
        normalized.queued = false
        startCardTimer(normalized)
        renderVisible(true)
        watchVisible(normalized)
    else
        queue[#queue + 1] = id
        showNext(true)
    end
    return id, nil, publicCard(normalized)
end

function PeekPlus.Update(id, patch, owner, expectedRevision, actionToken)
    local card = cards[id]
    if not card then return false, "card_not_found" end
    if card.owner ~= owner then return false, "not_owner" end
    if expectedRevision and tonumber(expectedRevision) ~= card.revision then return false, "stale_revision" end
    if actionToken and card.actionInFlight ~= actionToken then return false, "stale_action" end
    local normalized, err = normalizeSpec(patch, true)
    if not normalized then return false, err end

    if normalized.state and normalized.state ~= card.state then
        local transitions = defaults.transitions[card.state] or {}
        if not transitions[normalized.state] then return false, "invalid_transition" end
    end

    for field, value in pairs(normalized) do card[field] = value end
    card.revision = card.revision + 1
    card.actionInFlight = nil
    card.confirmAction = nil
    if normalized.duration ~= nil or normalized.hold ~= nil then
        if card.queued then
            card.expiresAt = 0
        else
            startCardTimer(card)
        end
    end
    if normalized.duration == nil and normalized.hold == nil then scheduleExpiry(card) end
    if normalized.priority ~= nil and card.queued then sortQueue() end
    if visibleId == id then
        renderVisible(false)
        watchVisible(card)
    end
    return true, nil, publicCard(card)
end

-- High-frequency, non-semantic text refresh (for example distance). It does
-- not advance the action revision or unlock an in-flight server operation.
function PeekPlus.UpdatePresentation(id, patch, owner)
    local card = cards[id]
    if not card then return false, "card_not_found" end
    if card.owner ~= owner then return false, "not_owner" end
    if type(patch) ~= "table" then return false, "invalid_card" end
    for _, field in ipairs({ "title", "subtitle", "description" }) do
        if patch[field] ~= nil then
            local value, err = cleanText(patch[field], limits.textLimits[field], field == "title")
            if value == nil and err then return false, err end
            card[field] = value
        end
    end
    if visibleId == id then renderVisible(false) end
    return true
end

function PeekPlus.Remove(id, owner, expectedRevision, actionToken)
    local card = cards[id]
    if not card then return false, "card_not_found" end
    if owner and card.owner ~= owner then return false, "not_owner" end
    if expectedRevision and tonumber(expectedRevision) ~= card.revision then return false, "stale_revision" end
    if actionToken and card.actionInFlight ~= actionToken then return false, "stale_action" end
    removeFromList(queue, id)
    removeFromList(suspended, id)
    cards[id] = nil
    if visibleId == id then
        peekWatchToken = peekWatchToken + 1
        interruptedId = nil
        visibleId = nil
        showNext(true)
    end
    return true
end

function PeekPlus.ClearOwner(owner)
    if type(owner) ~= "string" or owner == "" then return false, "invalid_owner" end
    local ids = {}
    for id, card in pairs(cards) do
        if card.owner == owner then ids[#ids + 1] = id end
    end
    for index = 1, #ids do PeekPlus.Remove(ids[index], owner) end
    return true, nil, #ids
end

function PeekPlus.ReleaseAction(id, owner, actionToken)
    local card = cards[id]
    if not card then return false, "card_not_found" end
    if card.owner ~= owner then return false, "not_owner" end
    if actionToken and card.actionInFlight ~= actionToken then return false, "stale_action" end
    card.actionInFlight = nil
    card.confirmAction = nil
    card.revision = card.revision + 1
    scheduleExpiry(card)
    if visibleId == id then renderVisible(false) end
    return true
end

function PeekPlus.Get(id, owner)
    local card = cards[id]
    if not card or owner and card.owner ~= owner then return nil end
    return publicCard(card)
end

function PeekPlus.Count(owner)
    local total, owned = countCards(owner)
    return owner and owned or total
end

function PeekPlus.RegisterActionHandler(owner, handler)
    if type(owner) ~= "string" or type(handler) ~= "function" then return false end
    actionHandlers[owner] = handler
    return true
end

function PeekPlus.RegisterReadyHandler(handler)
    if type(handler) ~= "function" then return false end
    readyHandlers[#readyHandlers + 1] = handler
    return true
end

local function findAction(card, actionId)
    for index = 1, #card.actions do
        if card.actions[index].id == actionId then return card.actions[index] end
    end
end

local function dispatchAction(card, action, confirmed)
    nextActionToken = nextActionToken + 1
    local token = ("%s:%d"):format(runtimeId, nextActionToken)
    card.actionInFlight = token
    card.confirmAction = nil
    local revision = card.revision
    renderVisible(false)

    local data = {
        id = card.id,
        owner = card.owner,
        action = action.id,
        confirmed = confirmed == true,
        revision = revision,
        actionToken = token,
    }
    CreateThread(function()
        TriggerEvent("peekplus:action", data)
        TriggerEvent(("peekplus:action:%s"):format(card.owner), data)
        local handler = actionHandlers[card.owner]
        if handler then handler(data) end
    end)

    SetTimeout(limits.actionTimeout, function()
        local current = cards[card.id]
        if current and current.actionInFlight == token then
            PeekPlus.ReleaseAction(card.id, card.owner, token)
        end
    end)
end

local function handleAction(data)
    if type(data) ~= "table" or callActive or interruptedId == visibleId then return false end
    local card = visibleId and cards[visibleId] or nil
    if not card or data.id ~= card.id or tonumber(data.revision) ~= card.revision then return false end
    if card.actionInFlight then return false end
    local action = findAction(card, tostring(data.action or ""))
    if not action then return false end

    if action.confirm and card.confirmAction ~= action.id then
        card.confirmAction = action.id
        local revision = card.revision
        renderVisible(false)
        if action.confirm.timeout > 0 then
            SetTimeout(action.confirm.timeout, function()
                local current = cards[card.id]
                if current and current.revision == revision and current.confirmAction == action.id then
                    current.confirmAction = nil
                    if visibleId == current.id then renderVisible(false) end
                end
            end)
        end
        return true
    end

    dispatchAction(card, action, action.confirm ~= nil)
    return true
end

RegisterNUICallback("peekplusAction", function(data, callback)
    callback(handleAction(data))
end)

RegisterNUICallback("peekplusReady", function(data, callback)
    nuiReady = true
    phoneOpen = PeekPlusLBPhone.IsOpen()
    callActive = PeekPlusLBPhone.IsCallActive()
    print(("[services-plus] PeekPlus %s ready (controller %s)"):format(
        defaults.version,
        type(data) == "table" and tostring(data.controllerVersion or "unknown") or "unknown"
    ))
    renderVisible(false)
    for index = 1, #readyHandlers do CreateThread(readyHandlers[index]) end
    callback(true)
end)

RegisterCommand("peekplus_action_return", function()
    local card = visibleId and cards[visibleId] or nil
    if not card then return end
    for index = 1, #card.actions do
        if card.actions[index].key == "RETURN" then
            handleAction({ id = card.id, revision = card.revision, action = card.actions[index].id })
            return
        end
    end
end, false)
RegisterKeyMapping("peekplus_action_return", "Activate primary PeekPlus action", "keyboard", "RETURN")

RegisterCommand("peekplus_action_delete", function()
    local card = visibleId and cards[visibleId] or nil
    if not card then return end
    for index = 1, #card.actions do
        if card.actions[index].key == "DELETE" then
            handleAction({ id = card.id, revision = card.revision, action = card.actions[index].id })
            return
        end
    end
end, false)
RegisterKeyMapping("peekplus_action_delete", "Activate destructive PeekPlus action", "keyboard", "DELETE")

function PeekPlus.SetPhoneOpen(open)
    phoneOpen = open == true
    if not phoneOpen and interruptedId == visibleId then interruptedId = nil end
    sendNui("peekplus:phone", { open = phoneOpen })
    renderVisible(false)
    if not phoneOpen and visibleId then watchVisible(cards[visibleId]) end
end

function PeekPlus.SetCallPriority(active)
    callActive = active == true
    sendNui("peekplus:call", { active = callActive })
    renderVisible(false)
end

function PeekPlus.Reconnect(open)
    phoneOpen = open == true
    sendNui("peekplus:reconnect", {})
    renderVisible(false)
end

function PeekPlus.PhoneUnavailable()
    phoneOpen = false
    sendNui("peekplus:phoneUnavailable", {})
    renderVisible(false)
end

AddEventHandler("onClientResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        sendNui("peekplus:destroy", {})
        return
    end
    PeekPlus.ClearOwner(resourceName)
end)
