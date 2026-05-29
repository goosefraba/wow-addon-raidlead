----------------------------------------------------------------------
-- RaidLead — Core/Comm.lua
-- Lightweight addon-to-addon message layer (no Ace3 needed)
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local Comm = {}
ns.Comm = Comm

Comm.PREFIX = "RaidLead"
Comm.SEP    = "\t"

-- Register the addon message prefix (server-side filter)
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(Comm.PREFIX)
elseif RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(Comm.PREFIX)
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function GetBroadcastChannel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    -- TBC fallbacks
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then return "RAID" end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then return "PARTY" end
    return nil
end

local function SendRaw(msg, channel)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(Comm.PREFIX, msg, channel)
    elseif SendAddonMessage then
        SendAddonMessage(Comm.PREFIX, msg, channel)
    end
end

----------------------------------------------------------------------
-- Outgoing API
----------------------------------------------------------------------

local function PackMessage(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[i] = tostring(v == nil and "" or v)
    end
    return table.concat(parts, Comm.SEP)
end

local function SendWithTarget(msg, channel, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(Comm.PREFIX, msg, channel, target)
    elseif SendAddonMessage then
        SendAddonMessage(Comm.PREFIX, msg, channel, target)
    end
end

-- Broadcast to current RAID/PARTY
function Comm.Send(...)
    local channel = GetBroadcastChannel()
    if not channel then
        ns.D("Comm.Send skipped (not in group)")
        return
    end
    local msg = PackMessage(...)
    SendWithTarget(msg, channel)
    ns.D("Comm.Send -> " .. channel .. ": " .. msg)
end

-- Whisper directly to a specific player (used for sync replies)
function Comm.Whisper(target, ...)
    if not target or target == "" then return end
    local msg = PackMessage(...)
    SendWithTarget(msg, "WHISPER", target)
    ns.D("Comm.Whisper -> " .. target .. ": " .. msg)
end

----------------------------------------------------------------------
-- Handler registry
----------------------------------------------------------------------
local handlers = {}

function Comm.RegisterHandler(msgType, fn)
    handlers[msgType] = fn
end

----------------------------------------------------------------------
-- Incoming dispatcher
----------------------------------------------------------------------
local function OnReceive(prefix, msg, channel, sender)
    if prefix ~= Comm.PREFIX then return end
    if not msg or msg == "" then return end

    -- Ignore our own messages (server echoes them back)
    local me = UnitName("player")
    local senderName = sender:match("^([^-]+)") or sender
    if senderName == me then return end

    -- Channel filter:
    --   RAID/PARTY/INSTANCE_CHAT - server already scopes these to our group
    --   WHISPER - accept only from current group members (sync replies)
    --   anything else - reject
    if channel == "RAID" or channel == "PARTY" or channel == "INSTANCE_CHAT" then
        -- ok
    elseif channel == "WHISPER" then
        if not (UnitInRaid and UnitInRaid(senderName))
           and not (UnitInParty and UnitInParty(senderName)) then
            ns.D("Comm: rejecting whisper from non-group sender " .. senderName)
            return
        end
    else
        ns.D("Comm: ignoring message from channel " .. tostring(channel))
        return
    end

    -- Split by SEP
    local parts = {}
    for part in (msg .. Comm.SEP):gmatch("([^" .. Comm.SEP .. "]*)" .. Comm.SEP) do
        parts[#parts + 1] = part
    end

    local msgType = parts[1]
    local fn = handlers[msgType]
    if fn then
        -- Handlers receive (parts, sender, channel). Channel lets them
        -- distinguish real-time broadcasts (RAID/PARTY - notify-worthy)
        -- from bulk sync replies (WHISPER - keep quiet to avoid spam).
        local ok, err = pcall(fn, parts, senderName, channel)
        if not ok then
            ns.D("Comm handler error (" .. tostring(msgType) .. "): " .. tostring(err))
        end
    else
        ns.D("Comm: unknown message type '" .. tostring(msgType) .. "' from " .. senderName)
    end
end

----------------------------------------------------------------------
-- Event listener
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        OnReceive(...)
    end
end)
