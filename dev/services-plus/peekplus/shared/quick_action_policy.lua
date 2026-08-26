-- Pure quick-action policy shared by the runtime and the private client
-- matrix tests. Context collection stays in controller.lua because only it
-- owns the current phone/call state and GTA natives.
PeekPlusQuickActionPolicy = {}

---@param context table?
---@return string? reason nil means the Peek hotkey is safe to execute
function PeekPlusQuickActionPolicy.BlockReason(context)
    context = type(context) == "table" and context or {}

    if context.callActive then return "call_active" end
    if context.phoneOpen then return "phone_open" end
    if context.pauseMenuActive then return "pause_menu" end
    if context.nuiFocused then return "nui_focus" end
    if context.playerControlOn == false then return "player_control_disabled" end
    if context.controlEnabled == false then return "frontend_control_disabled" end
    if context.screenTransition then return "screen_transition" end
    if context.invalidPed then return "invalid_ped" end
    if context.deadOrInjured then return "dead_or_injured" end
    if context.cuffed then return "cuffed" end
    if context.blockedPlayerState then return "blocked_player_state" end

    return nil
end

---@param context table?
---@return boolean
function PeekPlusQuickActionPolicy.IsBlocked(context)
    return PeekPlusQuickActionPolicy.BlockReason(context) ~= nil
end
