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

----------------------------------------------------------------------
-- Seed the RNG.
--
-- Every anti-flood jitter in this addon (reply delays, auto-sync delay)
-- relies on math.random producing DIFFERENT values on different clients.
-- Lua does not seed itself, so without this every client would draw the
-- identical sequence and the jitter would desynchronize nothing - all 25
-- raid members would still fire in the same instant. Seed off the player
-- name so the streams are distinct per character.
----------------------------------------------------------------------
local function SeedRandom()
    local seed = math.floor((GetTime() or 0) * 1000) % 2147483647
    local name = (UnitName and UnitName("player")) or ""
    for i = 1, #name do
        seed = (seed * 31 + name:byte(i)) % 2147483647
    end
    math.randomseed(seed)
    for _ = 1, 5 do math.random() end   -- discard the weak first draws
end

-- Seed once at load with what we have (GetTime differs per client), then
-- again at PLAYER_LOGIN mixing in the character name for a properly distinct
-- stream. Seeding here too means no code path can ever draw from an unseeded
-- RNG - and an unseeded RNG would silently give every client identical
-- jitter, quietly undoing the whole anti-flood design.
SeedRandom()

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

----------------------------------------------------------------------
-- Outbound rate limiter
--
-- The server disconnects clients that exceed the addon-message rate (on
-- the order of 10/sec in TBC). A group-wide event - everyone zoning into
-- an instance at once - used to make every client broadcast a request and
-- every client whisper a reply, which is an N-by-N burst that kicked the
-- whole raid. Callers above no longer touch the wire directly: everything
-- funnels through this queue, which releases at most MAX_PER_SEC messages
-- a second. This is the backstop that makes such a flood structurally
-- impossible regardless of what triggers it.
----------------------------------------------------------------------
local MAX_PER_SEC = 5
local MAX_QUEUE   = 400          -- beyond this we drop rather than grow forever
local INTERVAL    = 1 / MAX_PER_SEC

-- Two lanes. Interactive edits (an assignment the leader just dragged) must
-- not sit behind a bulk state-sync backlog, which can be hundreds of
-- messages, so `hi` is always drained first.
local hi, hiHead, hiTail = {}, 1, 0
local lo, loHead, loTail = {}, 1, 0

Comm.stats = { sent = 0, dropped = 0 }

local function depth(head, tail) return tail - head + 1 end
function Comm.QueueDepth() return depth(hiHead, hiTail) + depth(loHead, loTail) end

local function pop()
    local q, h
    if hiHead <= hiTail then
        q, h = hi, hiHead
        hiHead = hiHead + 1
        if hiHead > hiTail then hi, hiHead, hiTail = {}, 1, 0 end
    elseif loHead <= loTail then
        q, h = lo, loHead
        loHead = loHead + 1
        if loHead > loTail then lo, loHead, loTail = {}, 1, 0 end
    else
        return nil
    end
    local e = q[h]
    q[h] = nil
    return e
end

local pumpFrame = CreateFrame("Frame")
local accum = 0
pumpFrame:SetScript("OnUpdate", function(_, dt)
    if Comm.QueueDepth() <= 0 then accum = 0; return end
    accum = accum + dt
    if accum < INTERVAL then return end
    -- Subtract rather than zero, so a low framerate doesn't silently pace us
    -- slower than MAX_PER_SEC. CLAMP the remainder though: OnUpdate does not
    -- run during a loading screen, so the first frame afterwards carries the
    -- whole elapsed time. Letting that debt accumulate would repay it at
    -- frame rate - dozens of messages in a few hundred ms - which is the very
    -- burst this queue exists to prevent. The server limit is instantaneous,
    -- so credit must never bank up.
    accum = accum - INTERVAL
    if accum > INTERVAL then accum = INTERVAL end
    local e = pop()
    if not e then return end

    -- Resolve the channel at DISPATCH time, not enqueue time: a message can
    -- wait seconds here, and the group may have changed in between.
    local channel = e.channel
    if e.broadcast then
        channel = GetBroadcastChannel()
        if not channel then
            ns.D("Comm: dropping queued broadcast (no longer in a group)")
            return
        end
    end
    SendWithTarget(e.msg, channel, e.target)
    Comm.stats.sent = Comm.stats.sent + 1
end)

-- Bulk traffic is admitted only up to MAX_QUEUE - HI_RESERVE, so a deep sync
-- backlog can never crowd out an interactive edit at the door (which would
-- reintroduce the priority inversion the two lanes exist to remove).
local HI_RESERVE = 100

local function Enqueue(e, priority)
    local bulk  = (priority == "bulk")
    local limit = bulk and (MAX_QUEUE - HI_RESERVE) or MAX_QUEUE
    if Comm.QueueDepth() >= limit then
        Comm.stats.dropped = Comm.stats.dropped + 1
        ns.D("Comm: queue full, dropping message: " .. tostring(e.msg))
        return
    end
    if bulk then
        loTail = loTail + 1; lo[loTail] = e
    else
        hiTail = hiTail + 1; hi[hiTail] = e
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
    Enqueue({ msg = msg, broadcast = true })
    ns.D("Comm.Send -> " .. channel .. ": " .. msg)
end

-- Whisper directly to a specific player (used for sync replies)
function Comm.Whisper(target, ...)
    if not target or target == "" then return end
    local msg = PackMessage(...)
    Enqueue({ msg = msg, channel = "WHISPER", target = target })
    ns.D("Comm.Whisper -> " .. target .. ": " .. msg)
end

-- Bulk variants for large state dumps: same wire, but queued behind anything
-- interactive so a big sync never delays a live edit.
function Comm.WhisperBulk(target, ...)
    if not target or target == "" then return end
    Enqueue({ msg = PackMessage(...), channel = "WHISPER", target = target }, "bulk")
end

----------------------------------------------------------------------
-- Throttled reply helper
--
-- Shared by every "<X>_REQ -> whisper my answer back" handler. Without
-- this each request makes all N addon users answer in the same instant;
-- with 25 people and several request types that is thousands of whispers.
-- Per-sender cooldown kills repeats, random jitter spreads the rest out.
----------------------------------------------------------------------
local REPLY_COOLDOWN = 5
local replyAt = {}   -- ["KEY:sender"] = GetTime() of last reply

function Comm.ThrottledReply(key, sender, maxDelay, fn)
    if not sender or sender == "" then return end
    local k   = key .. ":" .. sender
    local now = GetTime()
    if replyAt[k] and (now - replyAt[k]) < REPLY_COOLDOWN then
        ns.D("Comm: suppressing repeat " .. key .. " reply to " .. sender)
        return
    end
    replyAt[k] = now
    C_Timer.After(math.random() * (maxDelay or 3), fn)
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
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        OnReceive(...)
    elseif event == "PLAYER_LOGIN" then
        -- UnitName("player") is only reliable from PLAYER_LOGIN onward, and
        -- the name is what makes each client's jitter stream distinct.
        SeedRandom()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
