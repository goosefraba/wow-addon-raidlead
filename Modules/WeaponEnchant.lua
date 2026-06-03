----------------------------------------------------------------------
-- RaidLead — Modules/WeaponEnchant.lua
-- Tracks temporary weapon enhancements (mana oils, sharpening / weight
-- stones, etc.).
--
-- IMPORTANT API REALITY: temporary weapon enchants are NOT auras and the
-- game exposes them ONLY for the local player (GetWeaponEnchantInfo).
-- There is no way to read another player's weapon enchant directly. So
-- this works by SELF-REPORT: every RaidLead user checks their own weapons
-- and broadcasts the result over the addon channel. Peers who don't run
-- RaidLead show as "unknown" (no report), exactly like the version column.
--
-- Comm protocol:
--   WENCH     <mhNeeds> <mhHas> <ohNeeds> <ohHas>   (0/1 flags)  broadcast
--   WENCH_REQ                                                     request
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local WeaponEnchant = {}
ns.WeaponEnchant = WeaponEnchant

-- name -> { mhNeeds, mhHas, ohNeeds, ohHas, expires?, t }
-- Transient (not saved): enchant state changes constantly.
WeaponEnchant.reports = {}

local function b(v) return v and "1" or "0" end

----------------------------------------------------------------------
-- Self scan
----------------------------------------------------------------------

-- Off-hand needs an enchant only when it's actually a weapon (not a
-- shield or a held-in-off-hand frill).
local OH_WEAPON_LOC = {
    INVTYPE_WEAPON        = true,
    INVTYPE_WEAPONOFFHAND = true,
}

-- Compute the local player's weapon-enchant status. Returns the report
-- table (also stored in reports[self]).
function WeaponEnchant.ScanSelf()
    local me = UnitName("player")
    if not me then return nil end

    local hasMH, mhExp, _, _, hasOH, ohExp = GetWeaponEnchantInfo()

    -- Main hand: a weapon is (almost) always equipped there.
    local mhNeeds = GetInventoryItemLink("player", 16) ~= nil

    -- Off hand: only a weapon wants an oil/stone.
    local ohNeeds = false
    local ohLink = GetInventoryItemLink("player", 17)
    if ohLink then
        local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(ohLink)
        ohNeeds = OH_WEAPON_LOC[equipLoc] == true
    end

    -- Shortest remaining enchant (ms) -> seconds, for the self tooltip.
    local expires
    if hasMH and mhExp then expires = mhExp end
    if hasOH and ohExp and (not expires or ohExp < expires) then expires = ohExp end

    local rep = {
        mhNeeds = mhNeeds, mhHas = hasMH and true or false,
        ohNeeds = ohNeeds, ohHas = hasOH and true or false,
        expires = expires and (expires / 1000) or nil,
        t       = GetTime(),
    }
    WeaponEnchant.reports[me] = rep
    return rep
end

----------------------------------------------------------------------
-- Query helpers (used by the grid + missing logic)
----------------------------------------------------------------------
function WeaponEnchant.Get(name)
    if not name then return nil end
    return WeaponEnchant.reports[name]
end

-- Does this player have a weapon that wants an enchant at all?
function WeaponEnchant.NeedsAny(rep)
    return rep and (rep.mhNeeds or rep.ohNeeds) or false
end

-- Is a needed enchant missing?
function WeaponEnchant.IsMissing(rep)
    if not rep then return false end
    if rep.mhNeeds and not rep.mhHas then return true end
    if rep.ohNeeds and not rep.ohHas then return true end
    return false
end

----------------------------------------------------------------------
-- Broadcast / request (mirrors Versions.lua)
----------------------------------------------------------------------
local function SendReport(targetFn)
    local r = WeaponEnchant.ScanSelf()
    if not r then return end
    targetFn(b(r.mhNeeds), b(r.mhHas), b(r.ohNeeds), b(r.ohHas))
end

function WeaponEnchant.BroadcastMine()
    if not ns.Comm then return end
    SendReport(function(...) ns.Comm.Send("WENCH", ...) end)
end

function WeaponEnchant.RequestAll()
    if not ns.Comm then return end
    ns.Comm.Send("WENCH_REQ")
end

local function NotifyUI()
    if ns.RefreshGridTab then ns.RefreshGridTab() end
end

----------------------------------------------------------------------
-- Comm handlers
----------------------------------------------------------------------
if ns.Comm then
    ns.Comm.RegisterHandler("WENCH", function(parts, sender)
        if not sender or sender == "" then return end
        WeaponEnchant.reports[sender] = {
            mhNeeds = parts[2] == "1", mhHas = parts[3] == "1",
            ohNeeds = parts[4] == "1", ohHas = parts[5] == "1",
            t       = GetTime(),
        }
        NotifyUI()
    end)

    ns.Comm.RegisterHandler("WENCH_REQ", function(parts, sender)
        if not sender or sender == "" then return end
        SendReport(function(...) ns.Comm.Whisper(sender, "WENCH", ...) end)
    end)
end

----------------------------------------------------------------------
-- Keep our own report fresh when we apply/refresh a weapon enchant.
-- Throttled so a flurry of inventory events doesn't spam the channel.
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
local pending = false
frame:SetScript("OnEvent", function(_, event, unit)
    if unit ~= "player" then return end
    if pending then return end
    pending = true
    C_Timer.After(2, function()
        pending = false
        WeaponEnchant.BroadcastMine()
        NotifyUI()
    end)
end)
