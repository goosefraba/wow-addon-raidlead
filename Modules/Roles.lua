----------------------------------------------------------------------
-- RaidLead — Modules/Roles.lua
-- Self-declared player roles, shared across all raid members that
-- have this addon. Each player picks their role for "today"; the
-- choice is broadcast over Comm and stored locally for everyone.
--
-- For now used only by the healer auto-assign feature, but the data
-- is general purpose (tank / healer / melee / ranged).
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local Roles = {}
ns.Roles = Roles

----------------------------------------------------------------------
-- Role definitions
----------------------------------------------------------------------
Roles.ROLE_KEYS = { "tank", "healer", "melee", "ranged" }

Roles.ROLE_LABELS = {
    tank   = "Tank",
    healer = "Healer",
    melee  = "Melee DPS",
    ranged = "Ranged DPS",
}

-- Short tag for inline display next to names
Roles.ROLE_TAGS = {
    tank   = "Tank",
    healer = "Heal",
    melee  = "Melee",
    ranged = "Ranged",
}

-- ARGB hex colors used in chat / FontString markup
Roles.ROLE_COLORS = {
    tank   = "FF4488CC",  -- blue
    healer = "FF44CC88",  -- green
    melee  = "FFDD5555",  -- red
    ranged = "FFDDAA55",  -- orange
}

----------------------------------------------------------------------
-- Role icons.
--
-- We deliberately use standard ability/item icons here instead of the
-- LFG atlas at Interface\LFGFrame\UI-LFG-ICON-ROLES: that atlas has
-- transparent backgrounds which bleed through the button textures in
-- TBC Classic, and its sprite layout differs between client versions.
-- Ability icons are solid 64x64 textures that look clean on any
-- background and exist on every WoW client.
----------------------------------------------------------------------
local ROLE_ICON_PATHS = {
    tank   = "Interface\\Icons\\INV_Shield_06",
    healer = "Interface\\Icons\\Spell_Holy_FlashHeal",
    melee  = "Interface\\Icons\\Ability_Warrior_Cleave",
    ranged = "Interface\\Icons\\Ability_Hunter_AimedShot",
}

-- The standard icon border crop (8% on each side trims the dark frame)
local ICON_CROP = { 0.08, 0.92, 0.08, 0.92 }

-- Create a texture for the given role on `parent`. Returns the texture
-- object (already sized). Caller is responsible for SetPoint. Rendered
-- on OVERLAY so it draws above button background textures.
function Roles.MakeRoleIcon(parent, roleKey, size)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetSize(size, size)
    local path = ROLE_ICON_PATHS[roleKey] or "Interface\\Icons\\INV_Misc_QuestionMark"
    tex:SetTexture(path)
    tex:SetTexCoord(ICON_CROP[1], ICON_CROP[2], ICON_CROP[3], ICON_CROP[4])
    return tex
end

-- Inline-texture string for use in FontStrings, button text, chat, etc.
function Roles.IconString(roleKey, size)
    size = size or 14
    local path = ROLE_ICON_PATHS[roleKey]
    if not path then return "" end
    -- |Tpath:height:width:offsetX:offsetY:texWidth:texHeight:left:right:top:bottom|t
    -- Pixel offsets are out of 64; 5..59 == 0.08..0.92 (the border crop).
    return string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", path, size, size)
end

Roles._suppressBroadcast = false

----------------------------------------------------------------------
-- Storage
----------------------------------------------------------------------
local function EnsureDB()
    if not ns.EnsureDB() then return false end
    if not ns.db.roles then ns.db.roles = {} end
    return true
end
Roles.EnsureDB = EnsureDB

function Roles.GetMyRole()
    if not EnsureDB() then return nil end
    return ns.db.myRole
end

-- Local setter that does not broadcast (used by sync handlers)
local function StoreLocal(playerName, role)
    if not EnsureDB() then return end
    if role == "" then role = nil end
    ns.db.roles[playerName] = role
end

-- Apply a role tagged with its SOURCE:
--   "self"    - the player chose it themselves (authoritative)
--   "derived" - inferred from a chat role check (shared, but lower priority)
-- A derived role never overwrites a self-declared one, so a player's own
-- setting always wins. Returns true if the store actually changed.
local function ApplyRole(playerName, role, source)
    if not EnsureDB() then return false end
    if not playerName or playerName == "" then return false end
    if role == "" then role = nil end
    source = (source == "derived") and "derived" or "self"
    ns.db.roleSource = ns.db.roleSource or {}
    if source == "derived" and ns.db.roleSource[playerName] == "self" then
        return false   -- respect the player's own choice
    end
    ns.db.roles[playerName]      = role
    ns.db.roleSource[playerName] = role and source or nil
    return true
end
Roles.ApplyRole = ApplyRole

function Roles.SetMyRole(role)
    if not EnsureDB() then return end
    if role == "" then role = nil end
    ns.db.myRole = role

    local me = UnitName("player")
    if me then
        -- Your own choice is authoritative ("self" source).
        ApplyRole(me, role, "self")
    end

    ns.D("Roles.SetMyRole -> " .. tostring(role))

    if not Roles._suppressBroadcast and ns.Comm and me then
        ns.Comm.Send("ROLE_SET", me, role or "", "self")
    end
end

function Roles.GetRole(playerName)
    if not EnsureDB() then return nil end
    if not playerName or playerName == "" then return nil end
    return ns.db.roles[playerName]
end

function Roles.GetAllRoles()
    if not EnsureDB() then return {} end
    return ns.db.roles
end

-- Wrap a name with the role-color hex (returns the name unchanged if
-- the role is unknown).
function Roles.ColorTag(role)
    local label = role and Roles.ROLE_TAGS[role]
    local color = role and Roles.ROLE_COLORS[role]
    if not (label and color) then return nil end
    return "|c" .. color .. label .. "|r"
end

----------------------------------------------------------------------
-- Broadcast / request
----------------------------------------------------------------------

-- Push our own role to all groupmates. Safe to call when not in a
-- group (Comm.Send is a no-op then).
function Roles.BroadcastMyRole()
    if not ns.Comm then return end
    local me = UnitName("player")
    if not me then return end
    local role = Roles.GetMyRole()
    if not role then return end
    ns.Comm.Send("ROLE_SET", me, role)
end

-- Ask the group: "please tell me your roles". Each peer that has
-- a role set whispers it back.
function Roles.RequestAll()
    if not ns.Comm then return end
    ns.Comm.Send("ROLE_REQ")
end

----------------------------------------------------------------------
-- Role check: like the in-game LFD role check. A raid lead can ask
-- everyone with the addon to confirm their role; receivers see a
-- popup dialog.
----------------------------------------------------------------------
local lastRoleCheckSent = 0
local ROLE_CHECK_THROTTLE = 15  -- seconds between sends

function Roles.SendRoleCheck()
    if not ns.Comm then return end

    -- Permission: leader only when actually in a group
    if ns.CanSendRoleCheck and not ns.CanSendRoleCheck() then
        ns.P("|cFFFF8800Only the raid leader can send a role check.|r")
        return
    end

    local now = GetTime()
    if now - lastRoleCheckSent < ROLE_CHECK_THROTTLE then
        local left = math.ceil(ROLE_CHECK_THROTTLE - (now - lastRoleCheckSent))
        ns.P("|cFFFFAA00Role check throttled.|r Try again in " .. left .. "s.")
        return
    end
    lastRoleCheckSent = now

    -- Broadcast to everyone else in the raid (no-op when solo)
    ns.Comm.Send("ROLE_CHECK")

    -- Also open the dialog locally for the sender. The Comm layer
    -- filters out our own broadcasts (server echo), so without this
    -- the initiator would never see the popup themselves - useful
    -- both for solo testing AND so the lead can confirm their own
    -- role alongside everyone else.
    if ns.ShowRoleCheckDialog then
        ns.ShowRoleCheckDialog(nil)  -- nil sender -> generic "Please confirm your role."
    end

    -- Listen for chat / whisper replies too. Players without the addon see
    -- no popup at all, and even addon users often just whisper "4" instead of
    -- clicking. Without this the listener stays off and every such reply is
    -- silently discarded - the player keeps showing as Unknown.
    if Roles.ActivateListening then Roles.ActivateListening() end

    local gt = ns.GetGroupType and ns.GetGroupType() or "solo"
    if gt == "solo" then
        ns.P("|cFF88CCFF[role check]|r solo - opening dialog for you.")
    else
        ns.P("|cFF88CCFF[role check]|r sent to RaidLead users in the raid. "
            .. "Also reading chat/whisper replies.")
    end
end

----------------------------------------------------------------------
-- Chat role check: ask the WHOLE raid (including players without the
-- addon) for their role in chat. The lead scans chat + whisper replies
-- and sets each player's role locally, so healer / role assignments work
-- even when not everyone runs RaidLead.
----------------------------------------------------------------------
local CHAT_ROLE_DURATION = 300  -- safety auto-stop (seconds)

local roleChatFrame  = CreateFrame("Frame")
local roleChatActive = false
local roleChatOnUpdate
local roleChatCount  = 0

-- Lookup tables for the fast-path replies. File-level so they are built once
-- rather than re-allocated on every chat line while a role check is active.
--   Numeric replies are the preferred form (what the chat prompt asks for):
--   1 = Tank, 2 = Heal, 3 = Melee, 4 = Ranged.
local ROLE_BY_NUMBER = { ["1"] = "tank", ["2"] = "healer", ["3"] = "melee", ["4"] = "ranged" }
--   Single-letter shorthand (t/h/m/r) tolerated as a fallback.
local ROLE_BY_LETTER = { t = "tank", h = "healer", m = "melee", r = "ranged" }

-- Map one chat line to a role key, or nil. Deliberately tolerant of the
-- common shorthands but ignores long sentences so normal chatter is not
-- mistaken for a reply.
local function ParseRole(text)
    if not text then return nil end
    local m = tostring(text):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if m == "" or #m > 24 then return nil end
    if ROLE_BY_NUMBER[m] then return ROLE_BY_NUMBER[m] end
    if #m == 1 then
        return ROLE_BY_LETTER[m]
    end
    if m:find("tank", 1, true)  or m:find("prot", 1, true)   then return "tank" end
    if m:find("heal", 1, true)  or m == "resto" or m == "holy" or m == "disc" then return "healer" end
    if m:find("melee", 1, true) or m == "mdps"               then return "melee" end
    if m:find("range", 1, true) or m:find("caster", 1, true) or m == "rdps" then return "ranged" end
    return nil
end
Roles.ParseRole = ParseRole

local ROLE_CHAT_EVENTS = {
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_WHISPER",
}

roleChatFrame:SetScript("OnEvent", function(_, event, text, sender)
    if not roleChatActive then return end
    local name = sender and sender:match("^[^-]+") or sender   -- strip realm
    if not name or name == "" then return end
    local role = ParseRole(text)
    if not role then return end
    -- "derived" - won't override a player's own self-declared role.
    if not ApplyRole(name, role, "derived") then return end
    roleChatCount = roleChatCount + 1
    ns.P("|cFF88CCFF[roles]|r " .. name .. " -> " .. (Roles.ROLE_LABELS[role] or role))
    -- Share the derived role with other RaidLead users (they apply the
    -- same self-wins precedence).
    if ns.Comm then ns.Comm.Send("ROLE_SET", name, role, "derived") end
    if ns.RefreshHealAssign  then ns.RefreshHealAssign()  end
    if ns.RefreshGridTab     then ns.RefreshGridTab()     end
    if ns.RefreshRolesRoster then ns.RefreshRolesRoster() end
    if roleChatOnUpdate then roleChatOnUpdate() end
end)

function Roles.IsChatRoleCheckActive() return roleChatActive end

-- Turn on chat/whisper reply reading. Shared by the full role check and the
-- "ask only the missing players" follow-up. The generation counter matters:
-- without it, starting a second check would leave the FIRST check's auto-stop
-- timer running, and it would cut the new one short.
local roleChatGen = 0
local ActivateListening
function ActivateListening(onUpdate)
    roleChatActive   = true
    roleChatOnUpdate = onUpdate
    roleChatCount    = 0
    roleChatGen      = roleChatGen + 1
    local gen        = roleChatGen
    for _, e in ipairs(ROLE_CHAT_EVENTS) do roleChatFrame:RegisterEvent(e) end
    C_Timer.After(CHAT_ROLE_DURATION, function()
        if roleChatActive and roleChatGen == gen then Roles.StopChatRoleCheck() end
    end)
end
Roles.ActivateListening = ActivateListening

----------------------------------------------------------------------
-- Follow-up: ask ONLY the players we still have no role for.
----------------------------------------------------------------------

-- Paced whisper sender. Firing SendChatMessage in a tight loop for a dozen
-- players trips the server's chat flood protection (dropped messages, or a
-- disconnect), so they go out one at a time.
local WHISPER_INTERVAL = 0.6
local whisperQueue, whisperPumping = {}, false

local function PumpWhispers()
    local e = table.remove(whisperQueue, 1)
    if not e then whisperPumping = false; return end
    SendChatMessage(e.text, "WHISPER", nil, e.name)
    C_Timer.After(WHISPER_INTERVAL, PumpWhispers)
end

local function QueueWhisper(name, text)
    whisperQueue[#whisperQueue + 1] = { name = name, text = text }
    if not whisperPumping then
        whisperPumping = true
        C_Timer.After(0, PumpWhispers)
    end
end

local function GroupUnits()
    local units = {}
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do
            if UnitExists("raid" .. i) then units[#units + 1] = "raid" .. i end
        end
    elseif IsInGroup and IsInGroup() then
        units[1] = "player"
        for i = 1, 4 do
            if UnitExists("party" .. i) then units[#units + 1] = "party" .. i end
        end
    end
    return units
end

-- Group members we still have no role for. Offline players are skipped (they
-- cannot answer), and so are we - the lead sets their own role in the panel.
function Roles.GetMissingRolePlayers()
    local me, out = UnitName("player"), {}
    for _, unit in ipairs(GroupUnits()) do
        local name = UnitName(unit)
        if name and name ~= me and not Roles.GetRole(name)
           and (not UnitIsConnected or UnitIsConnected(unit)) then
            out[#out + 1] = name
        end
    end
    table.sort(out)
    return out
end

-- Whisper just the players still missing a role, instead of re-polling the
-- whole raid. Players who also run RaidLead get the in-addon popup (a
-- targeted whisper, so nobody else is disturbed); everyone else gets a plain
-- whisper they can reply to with a number.
function Roles.AskMissingRoles(onUpdate)
    if ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can run a role check.|r")
        return false
    end

    local missing = Roles.GetMissingRolePlayers()
    if #missing == 0 then
        ns.P("|cFF88CCFFEveryone in the group already has a role.|r")
        return false
    end

    local popped, asked = 0, 0
    for _, name in ipairs(missing) do
        local hasAddon = ns.Versions and ns.Versions.GetVersion
                         and ns.Versions.GetVersion(name)
        if hasAddon and ns.Comm then
            -- Addon user: a targeted ROLE_CHECK opens their popup only.
            ns.Comm.Whisper(name, "ROLE_CHECK")
            popped = popped + 1
        else
            -- No colour escapes here - SendChatMessage mangles the pipe char.
            QueueWhisper(name, "[RaidLead] Role check: reply to this whisper "
                .. "with a NUMBER - 1 = Tank, 2 = Heal, 3 = Melee, 4 = Ranged")
            asked = asked + 1
        end
    end

    ActivateListening(onUpdate)
    ns.P(string.format("|cFF88CCFFAsking %d player(s) missing a role|r (%d popup, %d whisper). "
        .. "Reading replies; click again to stop.", #missing, popped, asked))
    return true
end

function Roles.StartChatRoleCheck(onUpdate)
    if ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can run a role check.|r")
        return false
    end

    local channel = ns.BuffScan and ns.BuffScan.GetAnnounceChannel
        and ns.BuffScan.GetAnnounceChannel()
    if channel then
        SendChatMessage("[RaidLead] Role check - reply with a NUMBER:", channel)
        SendChatMessage("  1 = Tank   2 = Heal   3 = Melee   4 = Ranged   (or whisper me)", channel)
    end

    -- Players who ALSO run RaidLead get the in-addon popup instead of having
    -- to type: one click sets their role and syncs it back (self-declared,
    -- which beats any chat-derived guess). Non-addon players still reply in
    -- chat. Our own broadcast is filtered by the Comm layer, so the lead
    -- doesn't get a popup here.
    if ns.Comm then ns.Comm.Send("ROLE_CHECK") end

    ActivateListening(onUpdate)
    ns.P("|cFF88CCFFRole check on.|r Reading chat/whisper replies; click again to stop.")
    return true
end

function Roles.StopChatRoleCheck()
    if not roleChatActive then return end
    roleChatActive = false
    roleChatFrame:UnregisterAllEvents()
    local cb = roleChatOnUpdate
    roleChatOnUpdate = nil
    ns.P("|cFF88CCFFRole check off.|r Set " .. roleChatCount .. " role(s) from chat.")
    if cb then cb() end
end

----------------------------------------------------------------------
-- Comm handlers
----------------------------------------------------------------------
if ns.Comm then
    ns.Comm.RegisterHandler("ROLE_SET", function(parts, sender)
        local playerName = parts[2]
        local role       = parts[3]
        local source     = parts[4]   -- "self" | "derived"; absent (old clients) = self
        if not playerName or playerName == "" then return end
        if role == "" then role = nil end

        -- ApplyRole enforces "self beats derived", so a synced derived role
        -- can't clobber a player's own setting.
        if ApplyRole(playerName, role, source) then
            ns.D("Roles: ROLE_SET " .. playerName .. " -> " .. tostring(role)
                .. " (" .. (source == "derived" and "derived" or "self") .. ")")
            if ns.RefreshHealAssign   then ns.RefreshHealAssign()   end
            if ns.RefreshGridTab      then ns.RefreshGridTab()      end
            if ns.RefreshRolesRoster  then ns.RefreshRolesRoster()  end
        end
    end)

    ns.Comm.RegisterHandler("ROLE_REQ", function(parts, sender)
        -- Check we actually have something to say BEFORE throttling, so a
        -- roleless player doesn't burn their cooldown on a no-op and then
        -- stay silent once they do pick a role.
        local me     = UnitName("player")
        local myRole = Roles.GetMyRole()
        if not (me and myRole) then return end
        -- Jittered + per-sender throttled: every addon user answers this, so
        -- replying immediately means N simultaneous whispers per request.
        ns.Comm.ThrottledReply("ROLE_REQ", sender, 3, function()
            ns.Comm.Whisper(sender, "ROLE_SET", me, myRole)
        end)
    end)

    ns.Comm.RegisterHandler("ROLE_CHECK", function(parts, sender)
        if not sender or sender == "" then return end
        if ns.ShowRoleCheckDialog then
            ns.ShowRoleCheckDialog(sender)
        else
            -- Fallback: dialog file missing for some reason
            ns.P("|cFF88CCFF" .. sender
                .. "|r requested a role check. Open the Profile tab to set your role.")
        end
    end)
end
