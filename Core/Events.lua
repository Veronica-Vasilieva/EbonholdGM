-- EbonholdGM | Core/Events.lua
-- Lightweight pub/sub event dispatcher for internal addon communication.
-- Usage:
--   GM.Events:Subscribe("EGMGM_TICKET_REFRESH", myFunc)
--   GM.Events:Dispatch("EGMGM_TICKET_REFRESH", ticketData)

local GM = EbonholdGM
GM.Events = {}
local Events = GM.Events

local listeners = {}  -- eventName -> { func, ... }

--- Subscribe a callback to an internal event.
function Events:Subscribe(eventName, func)
    if not listeners[eventName] then
        listeners[eventName] = {}
    end
    table.insert(listeners[eventName], func)
end

--- Unsubscribe a previously registered callback.
function Events:Unsubscribe(eventName, func)
    local list = listeners[eventName]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == func then
            table.remove(list, i)
        end
    end
end

--- Fire an event, passing variadic args to every subscriber.
function Events:Dispatch(eventName, ...)
    local list = listeners[eventName]
    if not list then return end
    for _, func in ipairs(list) do
        local ok, err = pcall(func, ...)
        if not ok then
            GM:PrintError("Event " .. eventName .. " handler error: " .. tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
-- WoW event relay — forwards WoW events through the internal dispatcher
-- so modules don't each need to register their own frame.
-- ---------------------------------------------------------------------------

local relay = CreateFrame("Frame")

-- Events that EbonholdGM modules care about
local RELAY_EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_YELL",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_SYSTEM",
    "GM_TICKET_UPDATE",
    "PLAYER_TARGET_CHANGED",
    "UNIT_NAME_UPDATE",
}

for _, evt in ipairs(RELAY_EVENTS) do
    relay:RegisterEvent(evt)
end

relay:SetScript("OnEvent", function(self, event, ...)
    Events:Dispatch(event, ...)
end)

-- Internal event name constants (avoids typo bugs)
Events.TICKET_REFRESH   = "EGMGM_TICKET_REFRESH"
Events.PLAYER_SELECTED  = "EGMGM_PLAYER_SELECTED"
Events.MODULE_SWITCHED  = "EGMGM_MODULE_SWITCHED"
Events.CHAT_MSG         = "EGMGM_CHAT_MSG"
Events.COMMAND_EXEC     = "EGMGM_COMMAND_EXEC"
