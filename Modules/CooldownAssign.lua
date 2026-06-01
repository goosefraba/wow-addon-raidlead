----------------------------------------------------------------------
-- RaidLead - Modules/CooldownAssign.lua
-- Two assignment systems sharing one file:
--
--   1) Cooldowns - predefined raid CDs (PI / Pain Sup / Innervate /
--      Tranquility / Aura Mastery / Bloodlust / Salvation / Soulstone)
--      with caster + optional target dropdowns.
--
--   2) CC marks - per-raid-icon (skull / cross / etc.) assignment of
--      a crowd-control caster. Pairs with a "Scan Marks" action that
--      detects currently-marked mobs and surfaces their names so the
--      lead can match them with the right CC.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local CooldownAssign = {}
ns.CooldownAssign = CooldownAssign

CooldownAssign._suppressBroadcast = false

----------------------------------------------------------------------
-- Standard cooldown catalogue. Each entry:
--   key       - stable string id used in storage / comm
--   label     - display name
--   class     - class hint (used for class-color tint of the label
--               and for auto-assign suggestions later)
--   needsTarget - true for "target a specific person" CDs;
--                 false for raid-wide effects (Tranq, Aura Mastery, BL)
--   tip       - short hover description
----------------------------------------------------------------------
CooldownAssign.COOLDOWNS = {
    { key = "pi",        label = "Power Infusion",     class = "PRIEST",   needsTarget = true,
      tip = "Disc/Holy Priest. 20s of bonus spell power / haste on the target." },
    { key = "pain_sup",  label = "Pain Suppression",   class = "PRIEST",   needsTarget = true,
      tip = "Disc Priest. 8s of damage reduction on the target tank." },
    { key = "inn_1",     label = "Innervate 1",        class = "DRUID",    needsTarget = true,
      tip = "Resto Druid. 20s of mana regen for one healer." },
    { key = "inn_2",     label = "Innervate 2",        class = "DRUID",    needsTarget = true,
      tip = "Second Innervate slot if you have multiple resto druids." },
    { key = "salvation", label = "Hand of Salvation",  class = "PALADIN",  needsTarget = true,
      tip = "Paladin. Drops the target's threat by 30%. Useful pre-pull on hunters / mages." },
    { key = "soulstone", label = "Soulstone",          class = "WARLOCK",  needsTarget = true,
      tip = "Warlock. Combat rez stone on a healer or tank before the pull." },
    { key = "tranq",     label = "Tranquility",        class = "DRUID",    needsTarget = false,
      tip = "Resto Druid. 8s of channeled raid HoT. Assign which druid + which phase." },
    { key = "aura_mast", label = "Aura Mastery",       class = "PALADIN",  needsTarget = false,
      tip = "Holy Paladin. 6s of doubled aura strength (e.g. Conc Aura = silence immunity)." },
    { key = "heroism",   label = "Heroism / Bloodlust", class = "SHAMAN",  needsTarget = false,
      tip = "Shaman. 30% haste for 40s. Save for execute phases." },
}

----------------------------------------------------------------------
-- Storage
----------------------------------------------------------------------
local function EnsureDB()
    if not ns.EnsureDB() then return false end
    if not ns.db.cooldowns then ns.db.cooldowns = {} end  -- [cdKey] = { caster, target }
    return true
end
CooldownAssign.EnsureDB = EnsureDB

----------------------------------------------------------------------
-- Cooldown CRUD
----------------------------------------------------------------------
function CooldownAssign.GetCD(cdKey)
    if not EnsureDB() then return nil end
    return ns.db.cooldowns[cdKey]
end

function CooldownAssign.SetCD(cdKey, caster, target)
    if not EnsureDB() then return end
    if not cdKey or cdKey == "" then return end
    if caster == "" then caster = nil end
    if target == "" then target = nil end

    if not caster and not target then
        ns.db.cooldowns[cdKey] = nil
    else
        ns.db.cooldowns[cdKey] = { caster = caster, target = target }
    end

    ns.D("CooldownAssign.SetCD " .. cdKey
        .. " caster=" .. tostring(caster) .. " target=" .. tostring(target))

    if not CooldownAssign._suppressBroadcast and ns.Comm then
        ns.Comm.Send("CD_SET", cdKey, caster or "", target or "")
    end
end

function CooldownAssign.ClearAllCDs()
    if not EnsureDB() then return end
    ns.db.cooldowns = {}
    ns.P("Cleared all cooldown assignments.")
    if not CooldownAssign._suppressBroadcast and ns.Comm then
        ns.Comm.Send("CD_CLEAR")
    end
end

----------------------------------------------------------------------
-- Build announce lines (for the Announce buttons in each view)
----------------------------------------------------------------------
local isBulkSync = ns.IsBulkSync

function CooldownAssign.BuildCooldownLines()
    if not EnsureDB() then return { "(no cooldowns set)" } end
    local lines = { "== Cooldown Assignments ==" }
    local any = false
    for _, cd in ipairs(CooldownAssign.COOLDOWNS) do
        local rec = ns.db.cooldowns[cd.key]
        if rec and (rec.caster or rec.target) then
            local left = cd.label .. ": " .. (rec.caster or "?")
            if cd.needsTarget then
                left = left .. " -> " .. (rec.target or "?")
            end
            lines[#lines + 1] = left
            any = true
        end
    end
    if not any then lines[#lines + 1] = "(none configured)" end
    return lines
end

-- Compact one-line-per-cooldown view for the live overlay.
function CooldownAssign.BuildCompactText()
    if not EnsureDB() then return "" end
    local lines = {}
    for _, cd in ipairs(CooldownAssign.COOLDOWNS) do
        local rec = ns.db.cooldowns[cd.key]
        if rec and rec.caster then
            local who = rec.caster
            if cd.needsTarget and rec.target then who = who .. " > " .. rec.target end
            lines[#lines + 1] = cd.label .. ": " .. who
        end
    end
    return table.concat(lines, "\n")
end

----------------------------------------------------------------------
-- Per-player whisper builders (one combined message per recipient).
----------------------------------------------------------------------
function CooldownAssign.BuildCooldownWhispers()
    if not EnsureDB() then return {} end
    local acc = ns.NewWhisperAccumulator()
    for _, cd in ipairs(CooldownAssign.COOLDOWNS) do
        local rec = ns.db.cooldowns[cd.key]
        if rec and rec.caster then
            local part = cd.label
            if cd.needsTarget and rec.target then part = part .. " on " .. rec.target end
            acc.add(rec.caster, part)
        end
    end
    return acc.build("[RaidLead] Cooldown: ")
end

----------------------------------------------------------------------
-- Comm handlers
----------------------------------------------------------------------
if ns.Comm then
    ns.Comm.RegisterHandler("CD_SET", function(parts, sender, channel)
        local cdKey  = parts[2]
        local caster = parts[3]
        local target = parts[4]
        if not cdKey then return end

        CooldownAssign._suppressBroadcast = true
        CooldownAssign.SetCD(cdKey, caster, target)
        CooldownAssign._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " set CD: " .. cdKey)
        end
        if ns.RefreshCooldownsView then ns.RefreshCooldownsView() end
    end)

    ns.Comm.RegisterHandler("CD_CLEAR", function(parts, sender, channel)
        CooldownAssign._suppressBroadcast = true
        CooldownAssign.ClearAllCDs()
        CooldownAssign._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " cleared cooldowns.")
        end
        if ns.RefreshCooldownsView then ns.RefreshCooldownsView() end
    end)

end

----------------------------------------------------------------------
-- Lock check shares the boss-config lock
----------------------------------------------------------------------
function CooldownAssign.IsLocked()
    return ns.BossTemplates and ns.BossTemplates.IsLocked() or false
end
