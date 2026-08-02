-- Phase 1 diagnostics for LB Phone contracts used by later phases.
AddEventHandler("lb-phone:newCall", function(call)
    ServicesPlus.Logger.Debug("Observed LB Phone call start", { callId = call and call.callId, company = call and call.company })
end)

AddEventHandler("lb-phone:callAnswered", function(call)
    ServicesPlus.Logger.Debug("Observed LB Phone call answer", { callId = call and call.callId })
end)

AddEventHandler("lb-phone:callEnded", function(call, endedBy)
    ServicesPlus.Logger.Debug("Observed LB Phone call end", { callId = call and call.callId, endedBy = endedBy })
end)

AddEventHandler("lb-phone:newCompanyMessage", function(message)
    ServicesPlus.Logger.Debug("Observed LB Phone company message", { channelId = message and message.channelId })
end)
