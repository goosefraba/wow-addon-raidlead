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
    if not ns.db then
        if RaidLeadDB then ns.db = RaidLeadDB
        elseif ns.InitDB then ns.InitDB() end
    end
    if not ns.db then return false end
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

function Roles.SetMyRole(role)
    if not EnsureDB() then return end
    if role == "" then role = nil end
    ns.db.myRole = role

    local me = UnitName("player")
    if me then
        ns.db.roles[me] = role
    end

    ns.D("Roles.SetMyRole -> " .. tostring(role))

    if not Roles._suppressBroadcast and ns.Comm and me then
        ns.Comm.Send("ROLE_SET", me, role or "")
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

    local gt = ns.GetGroupType and ns.GetGroupType() or "solo"
    if gt == "solo" then
        ns.P("|cFF88CCFF[role check]|r solo - opening dialog for you.")
    else
        ns.P("|cFF88CCFF[role check]|r sent to RaidLead users in the raid.")
    end
end

----------------------------------------------------------------------
-- Comm handlers
----------------------------------------------------------------------
if ns.Comm then
    ns.Comm.RegisterHandler("ROLE_SET", function(parts, sender)
        local playerName = parts[2]
        local role       = parts[3]
        if not playerName or playerName == "" then return end
        if role == "" then role = nil end

        StoreLocal(playerName, role)
        ns.D("Roles: received ROLE_SET " .. playerName .. " -> " .. tostring(role))

        if ns.RefreshHealAssign   then ns.RefreshHealAssign()   end
        if ns.RefreshGridTab      then ns.RefreshGridTab()      end
        if ns.RefreshRolesRoster  then ns.RefreshRolesRoster()  end
    end)

    ns.Comm.RegisterHandler("ROLE_REQ", function(parts, sender)
        if not sender or sender == "" then return end
        local me     = UnitName("player")
        local myRole = Roles.GetMyRole()
        if me and myRole then
            ns.Comm.Whisper(sender, "ROLE_SET", me, myRole)
        end
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
