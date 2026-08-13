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
local keyIndex = {}
local templates = {}
local history = {}
local historyByCard = {}
local nextHistoryId = 0
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

local function cleanKey(value)
    if value == nil then return nil end
    local key, err = cleanText(value, limits.textLimits.actionId, true)
    if not key then return nil, err end
    if not key:match("^[%w_:%-%.]+$") then return nil, "invalid_key" end
    return key
end

local function cleanHttpsImage(value)
    if value == nil then return nil end
    if type(value) ~= "string" or #value > 255 or value:find("[%s%c]") then return nil, "invalid_image_url" end
    if value:sub(1, 8):lower() ~= "https://" then return nil, "invalid_image_url" end
    local authority = value:sub(9):match("^([^/%?#]+)")
    if not authority or authority:find("@", 1, true) then return nil, "invalid_image_url" end
    return value
end

local function validateDetails(details)
    if details == nil then return nil end
    if type(details) ~= "table" or #details > limits.maxDetails then return nil, "invalid_details" end
    local result = {}
    for index = 1, #details do
        local row = details[index]
        if type(row) ~= "table" then return nil, "invalid_detail" end
        local label, labelError = cleanText(row.label, limits.textLimits.actionLabel, true)
        local value, valueError = cleanText(row.value, limits.textLimits.subtitle, true)
        local icon, iconError = cleanKey(row.icon)
        if not label then return nil, labelError end
        if not value then return nil, valueError end
        if iconError then return nil, iconError end
        result[index] = { label = label, value = value, icon = icon }
    end
    return result
end

local function validateProgress(progress)
    if progress == nil then return nil end
    if type(progress) == "number" then progress = { value = progress, max = 1 } end
    if type(progress) ~= "table" then return nil, "invalid_progress" end
    local value = tonumber(progress.value)
    local maximum = tonumber(progress.max) or 1
    if not value or maximum <= 0 or value < 0 or value > maximum then return nil, "invalid_progress" end
    local label, err = cleanText(progress.label, limits.textLimits.actionLabel, false)
    if err then return nil, err end
    return { value = value, max = maximum, label = label }
end

local function validateTimer(timer)
    if timer == nil then return nil end
    if type(timer) ~= "table" then return nil, "invalid_timer" end
    local elapsed = math.floor(tonumber(timer.elapsed) or 0)
    local duration = timer.duration ~= nil and math.floor(tonumber(timer.duration) or -1) or -1
    if elapsed < 0 or elapsed > limits.maxTimerDuration or duration < -1 or duration > limits.maxTimerDuration then
        return nil, "invalid_timer"
    end
    local countdown = timer.countdown == true
    if countdown and duration < 0 then return nil, "invalid_timer" end
    local label, err = cleanText(timer.label, limits.textLimits.actionLabel, false)
    if err then return nil, err end
    return { elapsed = elapsed, duration = duration, countdown = countdown, label = label }
end

local function resolveTemplate(owner, name)
    name = name or "default"
    if defaults.standardTemplates[name] then
        return name, defaults.standardTemplates[name], nil
    end
    local canonical = name:find(":", 1, true) and name or (owner .. ":" .. name)
    local definition = templates[canonical]
    if not definition or definition.owner ~= owner then return nil, nil, "unknown_template" end
    return canonical, definition.layout, definition
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

local function normalizeSpec(spec, partial, owner)
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

    if spec.icon ~= nil or not partial then
        local icon, err = cleanKey(spec.icon)
        if err then return nil, err end
        result.icon = icon
    end
    if spec.iconUrl ~= nil or not partial then
        local iconUrl, err = cleanHttpsImage(spec.iconUrl)
        if err then return nil, err end
        result.iconUrl = iconUrl
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
    if spec.key ~= nil or not partial then
        local key, err = cleanKey(spec.key)
        if err then return nil, err end
        result.key = key
    end
    if spec.variant ~= nil or not partial then
        local variant = spec.variant or "neutral"
        if not defaults.allowedVariants[variant] then return nil, "invalid_variant" end
        result.variant = variant
    end
    if spec.template ~= nil or not partial then
        local fallback = spec.template
        if fallback == nil then
            local actionCount = result.actions and #result.actions or 0
            fallback = actionCount > 0 and "action" or "default"
        end
        if type(fallback) ~= "string" then return nil, "invalid_template" end
        local template, layout, definitionOrError = resolveTemplate(owner, fallback)
        if not template then return nil, definitionOrError end
        result.template = template
        result.layout = layout
        if spec.layout ~= nil and definitionOrError == nil then
            local requestedLayout = tostring(spec.layout)
            if not defaults.allowedLayouts[requestedLayout] or requestedLayout == "custom" then
                return nil, "invalid_layout"
            end
            result.layout = requestedLayout
        end
        result.templateDefinition = definitionOrError and {
            ui = definitionOrError.ui,
            height = definitionOrError.height,
            fullCard = definitionOrError.fullCard,
        } or nil
    elseif spec.layout ~= nil then
        local layout = tostring(spec.layout)
        if not defaults.allowedLayouts[layout] or layout == "custom" then return nil, "invalid_layout" end
        result.layout = layout
    end
    if spec.details ~= nil or not partial then
        local details, err = validateDetails(spec.details)
        if err then return nil, err end
        result.details = details
    end
    if spec.progress ~= nil or not partial then
        local progress, err = validateProgress(spec.progress)
        if err then return nil, err end
        result.progress = progress
    end
    if spec.timer ~= nil or not partial then
        local timer, err = validateTimer(spec.timer)
        if err then return nil, err end
        result.timer = timer
    end
    if spec.templateData ~= nil or not partial then
        if spec.templateData ~= nil and type(spec.templateData) ~= "table" then return nil, "invalid_template_data" end
        if spec.templateData ~= nil then
            local ok, encoded = pcall(json.encode, spec.templateData)
            if not ok or #encoded > limits.maxTemplateDataBytes then return nil, "template_data_too_large" end
            local decodedOk, decoded = pcall(json.decode, encoded)
            if not decodedOk then return nil, "invalid_template_data" end
            result.templateData = decoded
        end
    end
    if spec.history ~= nil or not partial then result.history = spec.history ~= false end
    if spec.hold ~= nil or not partial then
        result.hold = spec.hold == true or spec.hold == nil and result.state == "active"
    end
    if spec.sound ~= nil or not partial then result.sound = spec.sound ~= false end
    if spec.interrupt ~= nil or not partial then result.interrupt = spec.interrupt == true end
    local effectiveLayout = result.layout
    if effectiveLayout == "details" and result.details == nil and not partial then return nil, "details_required" end
    if effectiveLayout == "progress" and result.progress == nil and not partial then return nil, "progress_required" end
    if effectiveLayout == "timer" and result.timer == nil and not partial then return nil, "timer_required" end
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

local function cloneValue(value, depth)
    if type(value) ~= "table" then return value end
    if (depth or 0) >= 8 then return nil end
    local result = {}
    for key, child in pairs(value) do result[key] = cloneValue(child, (depth or 0) + 1) end
    return result
end

local function publicCard(card)
    if not card then return nil end
    return {
        id = card.id,
        owner = card.owner,
        revision = card.revision,
        state = card.state,
        key = card.key,
        title = card.title,
        subtitle = card.subtitle,
        description = card.description,
        icon = card.icon,
        iconUrl = card.iconUrl,
        variant = card.variant,
        layout = card.layout,
        template = card.template,
        templateDefinition = cloneValue(card.templateDefinition),
        templateData = cloneValue(card.templateData),
        details = cloneValue(card.details),
        progress = cloneValue(card.progress),
        timer = cloneValue(card.timer),
        duration = card.duration,
        hold = card.hold,
        priority = card.priority,
        actions = cloneValue(card.actions),
        createdAt = card.createdAt,
        expiresAt = card.expiresAt,
        actionInFlight = card.actionInFlight ~= nil,
        confirmAction = card.confirmAction,
    }
end

local function emitLifecycle(card, reason, extra)
    if not card then return end
    local data = {
        id = card.id,
        key = card.key,
        owner = card.owner,
        revision = card.revision,
        reason = reason,
        state = card.state,
    }
    if type(extra) == "table" then
        for key, value in pairs(extra) do data[key] = value end
    end
    CreateThread(function()
        TriggerEvent("peekplus:lifecycle", data)
        TriggerEvent(("peekplus:lifecycle:%s"):format(card.owner), data)
    end)
end

local function historySnapshot(card)
    local snapshot = publicCard(card)
    snapshot.actions = nil
    snapshot.templateDefinition = nil
    return snapshot
end

local function notifyHistory()
    pcall(function()
        exports["lb-phone"]:SendCustomAppMessage(Config.PeekPlusApp.identifier, {
            type = "peekplusHistoryChanged",
        })
    end)
end

local function trimHistory()
    while #history > limits.maxHistory do
        local removed = table.remove(history)
        if removed then historyByCard[removed.cardId] = nil end
    end
end

local function addHistory(card)
    if not Config.PeekPlusApp.enabled or card.history == false then return end
    nextHistoryId = nextHistoryId + 1
    local entry = {
        id = nextHistoryId,
        cardId = card.id,
        owner = card.owner,
        createdAt = GetGameTimer(),
        updatedAt = GetGameTimer(),
        read = false,
        result = "shown",
        card = historySnapshot(card),
    }
    table.insert(history, 1, entry)
    historyByCard[card.id] = entry
    trimHistory()
    notifyHistory()
end

local function updateHistory(card, result)
    local entry = historyByCard[card.id]
    if not entry then return end
    entry.updatedAt = GetGameTimer()
    entry.result = result or entry.result
    entry.card = historySnapshot(card)
    notifyHistory()
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
    PeekPlus.Remove(id, card.owner, nil, nil, "expired")
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
            emitLifecycle(cards[id], "resumed")
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
            emitLifecycle(card, "visible")
            renderVisible(playSound ~= false)
            return watchVisible(card)
        end
    end
    renderVisible(false)
end

function PeekPlus.Show(spec, owner)
    owner = type(owner) == "string" and owner or nil
    if not owner or owner == "" then return nil, "invalid_owner" end
    local requestedKey, keyError = cleanKey(type(spec) == "table" and spec.key or nil)
    if keyError then return nil, keyError end
    local indexed = requestedKey and keyIndex[owner .. ":" .. requestedKey] or nil
    if indexed and cards[indexed] then
        local ok, err, existing = PeekPlus.Update(indexed, spec, owner)
        if not ok then return nil, err end
        emitLifecycle(cards[indexed], "deduplicated")
        return indexed, nil, existing, true
    end
    local total, owned = countCards(owner)
    if total >= limits.maxCards then return nil, "card_limit_reached" end
    if owned >= limits.maxCardsPerOwner then return nil, "owner_card_limit_reached" end

    local normalized, err = normalizeSpec(spec, false, owner)
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
    if normalized.key then keyIndex[owner .. ":" .. normalized.key] = id end
    addHistory(normalized)
    emitLifecycle(normalized, "created")

    local visible = visibleId and cards[visibleId] or nil
    if visible and normalized.interrupt and normalized.priority > visible.priority then
        if visible.expiresAt > 0 then
            visible.suspendedRemaining = math.max(0, visible.expiresAt - GetGameTimer())
            visible.expiresAt = 0
        end
        suspended[#suspended + 1] = visibleId
        visible.queued = true
        emitLifecycle(visible, "suspended", { by = id })
        visibleId = id
        normalized.queued = false
        startCardTimer(normalized)
        emitLifecycle(normalized, "visible")
        renderVisible(true)
        watchVisible(normalized)
    else
        queue[#queue + 1] = id
        if visible then emitLifecycle(normalized, "queued") end
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
    local normalized, err = normalizeSpec(patch, true, owner)
    if not normalized then return false, err end

    if normalized.state and normalized.state ~= card.state then
        local transitions = defaults.transitions[card.state] or {}
        if not transitions[normalized.state] then return false, "invalid_transition" end
    end

    local oldKey = card.key
    if normalized.key ~= nil and normalized.key ~= oldKey then
        local nextIndex = normalized.key and keyIndex[owner .. ":" .. normalized.key] or nil
        if nextIndex and nextIndex ~= id and cards[nextIndex] then return false, "duplicate_key" end
        if oldKey then keyIndex[owner .. ":" .. oldKey] = nil end
        if normalized.key then keyIndex[owner .. ":" .. normalized.key] = id end
    end
    for field, value in pairs(normalized) do card[field] = value end
    card.revision = card.revision + 1
    card.actionInFlight = nil
    card.confirmAction = nil
    if normalized.duration ~= nil or normalized.hold ~= nil then
        card.suspendedRemaining = nil
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
    updateHistory(card, card.state)
    emitLifecycle(card, "updated")
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
    if patch.details ~= nil then
        local value, err = validateDetails(patch.details)
        if err then return false, err end
        card.details = value
    end
    if patch.progress ~= nil then
        local value, err = validateProgress(patch.progress)
        if err then return false, err end
        card.progress = value
    end
    if patch.timer ~= nil then
        local value, err = validateTimer(patch.timer)
        if err then return false, err end
        card.timer = value
    end
    if patch.templateData ~= nil then
        if type(patch.templateData) ~= "table" then return false, "invalid_template_data" end
        local ok, encoded = pcall(json.encode, patch.templateData)
        if not ok or #encoded > limits.maxTemplateDataBytes then return false, "template_data_too_large" end
        local decodedOk, decoded = pcall(json.decode, encoded)
        if not decodedOk then return false, "invalid_template_data" end
        card.templateData = decoded
    end
    if visibleId == id then renderVisible(false) end
    return true
end

function PeekPlus.Remove(id, owner, expectedRevision, actionToken, reason)
    local card = cards[id]
    if not card then return false, "card_not_found" end
    if owner and card.owner ~= owner then return false, "not_owner" end
    if expectedRevision and tonumber(expectedRevision) ~= card.revision then return false, "stale_revision" end
    if actionToken and card.actionInFlight ~= actionToken then return false, "stale_action" end
    local removalReason = "removed"
    if reason ~= nil then
        local cleaned, err = cleanText(reason, limits.textLimits.actionLabel, true)
        if not cleaned then return false, err == "invalid_text" and "invalid_reason" or err end
        removalReason = cleaned
    end
    removeFromList(queue, id)
    removeFromList(suspended, id)
    if card.key then keyIndex[card.owner .. ":" .. card.key] = nil end
    if removalReason == "removed" and (card.state == "completed" or card.state == "declined") then
        removalReason = card.state
    end
    updateHistory(card, removalReason)
    emitLifecycle(card, removalReason, { removed = true })
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
    for index = 1, #ids do PeekPlus.Remove(ids[index], owner, nil, nil, "owner_stopped") end
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

function PeekPlus.GetHistory(owner)
    local result = {}
    for index = 1, #history do
        local entry = history[index]
        if not owner or entry.owner == owner then
            local copy = cloneValue(entry)
            copy.ageSeconds = math.max(0, math.floor((GetGameTimer() - entry.createdAt) / 1000))
            result[#result + 1] = copy
        end
    end
    return result
end

function PeekPlus.MarkHistoryRead(historyId, owner, read)
    local changed = 0
    for index = 1, #history do
        local entry = history[index]
        if (historyId == nil or tonumber(historyId) == entry.id)
            and (not owner or entry.owner == owner) then
            entry.read = read ~= false
            changed = changed + 1
        end
    end
    if changed > 0 then notifyHistory() end
    return true, nil, changed
end

function PeekPlus.ClearHistory(owner, historyId)
    local changed = 0
    for index = #history, 1, -1 do
        local entry = history[index]
        if (historyId == nil or tonumber(historyId) == entry.id)
            and (not owner or entry.owner == owner) then
            historyByCard[entry.cardId] = nil
            table.remove(history, index)
            changed = changed + 1
        end
    end
    if changed > 0 then notifyHistory() end
    return true, nil, changed
end

function PeekPlus.RegisterTemplate(owner, name, definition)
    if type(owner) ~= "string" or owner == "" then return nil, "invalid_owner" end
    name = type(name) == "string" and name or ""
    if not name:match("^[%w_%-]+$") or #name > limits.textLimits.actionId then
        return nil, "invalid_template_name"
    end
    if defaults.standardTemplates[name] then return nil, "reserved_template_name" end
    if type(definition) ~= "table" then return nil, "invalid_template" end
    if definition.fullCard ~= nil and type(definition.fullCard) ~= "boolean" then
        return nil, "invalid_full_card"
    end

    local layout = definition.layout or (definition.ui and "custom" or "text")
    if not defaults.allowedLayouts[layout] then return nil, "invalid_layout" end
    local ui = nil
    if definition.ui ~= nil then
        if type(definition.ui) ~= "string" or definition.ui == "" or #definition.ui > 200
            or definition.ui:find("..", 1, true) or definition.ui:sub(1, 1) == "/"
            or not definition.ui:match("^[%w_/%-%.]+%.html$") then
            return nil, "invalid_template_ui"
        end
        layout = "custom"
        ui = ("https://cfx-nui-%s/%s"):format(owner, definition.ui)
    elseif layout == "custom" then
        return nil, "template_ui_required"
    end
    local height = math.floor(tonumber(definition.height) or 160)
    if height < 40 or height > limits.maxTemplateHeight then return nil, "invalid_template_height" end
    local canonical = owner .. ":" .. name
    templates[canonical] = {
        owner = owner,
        name = name,
        layout = layout,
        ui = ui,
        height = height,
        fullCard = definition.fullCard == true,
    }
    return canonical
end

function PeekPlus.UnregisterTemplate(owner, name)
    local canonical = type(name) == "string" and (name:find(":", 1, true) and name or owner .. ":" .. name) or ""
    local definition = templates[canonical]
    if not definition then return false, "template_not_found" end
    if definition.owner ~= owner then return false, "not_owner" end
    for _, card in pairs(cards) do
        if card.template == canonical then return false, "template_in_use" end
    end
    templates[canonical] = nil
    return true
end

function PeekPlus.ClearTemplates(owner)
    for name, definition in pairs(templates) do
        if definition.owner == owner then templates[name] = nil end
    end
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
    TriggerEvent("peekplus:ready", defaults.version)
    for index = 1, #readyHandlers do CreateThread(readyHandlers[index]) end
    callback(true)
end)

local function runPrimaryHotkey()
    local card = visibleId and cards[visibleId] or nil
    if not card then return end
    for index = 1, #card.actions do
        if card.actions[index].key == "RETURN" then
            handleAction({ id = card.id, revision = card.revision, action = card.actions[index].id })
            return
        end
    end
end

-- Keep the existing command name stable for players while describing its
-- consumer-defined purpose accurately in FiveM's key binding settings.
RegisterCommand("peekplus_accept", runPrimaryHotkey, false)
RegisterKeyMapping("peekplus_accept", "PeekPlus: Primäraktion ausführen", "keyboard", "RETURN")

local function runDestructiveHotkey()
    local card = visibleId and cards[visibleId] or nil
    if not card then return end
    for index = 1, #card.actions do
        if card.actions[index].key == "BACK" then
            handleAction({ id = card.id, revision = card.revision, action = card.actions[index].id })
            return
        end
    end
end

-- FiveM calls the Backspace key BACK. Use the same simple command mapping as
-- the working ENTER action.
RegisterCommand("peekplus_back", runDestructiveHotkey, false)
RegisterKeyMapping(
    "peekplus_back",
    "PeekPlus: Benachrichtigung ablehnen/abbrechen",
    "keyboard",
    "BACK"
)

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
    PeekPlus.ClearTemplates(resourceName)
end)
