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
    if not ns.db then
        if RaidLeadDB then ns.db = RaidLeadDB
        elseif ns.InitDB then ns.InitDB() end
    end
    if not ns.db then return false end
    if not ns.db.cooldowns then ns.db.cooldowns = {} end  -- [cdKey] = { caster, target }
    if not ns.db.ccMarks then ns.db.ccMarks = {} end      -- [iconIdx] = { caster, detectedName }
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
-- CC mark CRUD
----------------------------------------------------------------------
function CooldownAssign.GetCC(iconIdx)
    if not EnsureDB() then return nil end
    return ns.db.ccMarks[iconIdx]
end

function CooldownAssign.SetCC(iconIdx, caster, detectedName)
    if not EnsureDB() then return end
    if not iconIdx then return end
    if caster == "" then caster = nil end
    if detectedName == "" then detectedName = nil end

    local existing = ns.db.ccMarks[iconIdx] or {}
    -- Preserve detected name if caller doesn't pass a new one
    detectedName = detectedName or existing.detectedName

    if not caster and not detectedName then
        ns.db.ccMarks[iconIdx] = nil
    else
        ns.db.ccMarks[iconIdx] = { caster = caster, detectedName = detectedName }
    end

    ns.D("CooldownAssign.SetCC icon=" .. iconIdx
        .. " caster=" .. tostring(caster) .. " detected=" .. tostring(detectedName))

    if not CooldownAssign._suppressBroadcast and ns.Comm then
        ns.Comm.Send("CC_SET", tostring(iconIdx), caster or "", detectedName or "")
    end
end

function CooldownAssign.ClearAllCC()
    if not EnsureDB() then return end
    ns.db.ccMarks = {}
    ns.P("Cleared all CC assignments.")
    if not CooldownAssign._suppressBroadcast and ns.Comm then
        ns.Comm.Send("CC_CLEAR")
    end
end

-- Run a fresh ScanMarkedMobs and update the detected-name field of
-- every populated icon. Existing caster assignments are preserved.
-- Returns: count of icons that now have a detected mob.
function CooldownAssign.ScanAndUpdate()
    if not EnsureDB() then return 0 end
    if not ns.ScanMarkedMobs then return 0 end
    local ok, detected = pcall(ns.ScanMarkedMobs)
    if not ok or type(detected) ~= "table" then return 0 end

    local found = 0
    for iconIdx = 1, 8 do
        local info = detected[iconIdx]
        if info and info.name then
            CooldownAssign.SetCC(iconIdx, ns.db.ccMarks[iconIdx]
                and ns.db.ccMarks[iconIdx].caster or nil, info.name)
            found = found + 1
        end
    end
    return found
end

----------------------------------------------------------------------
-- Build announce lines (for the Announce buttons in each view)
----------------------------------------------------------------------
local function isBulkSync(channel) return channel == "WHISPER" end

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

function CooldownAssign.BuildCCLines()
    if not EnsureDB() then return { "(no CC set)" } end
    local lines = { "== Crowd Control ==" }
    local any = false
    for iconIdx = 1, 8 do
        local rec = ns.db.ccMarks[iconIdx]
        if rec and rec.caster then
            local iconStr = ns.GetRaidIconText and ns.GetRaidIconText(iconIdx) or ""
            local mob = rec.detectedName and (" (" .. rec.detectedName .. ")") or ""
            lines[#lines + 1] = iconStr .. " " .. rec.caster .. mob
            any = true
        end
    end
    if not any then lines[#lines + 1] = "(none configured)" end
    return lines
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

    ns.Comm.RegisterHandler("CC_SET", function(parts, sender, channel)
        local iconIdx = tonumber(parts[2])
        local caster  = parts[3]
        local detected = parts[4]
        if not iconIdx then return end

        CooldownAssign._suppressBroadcast = true
        CooldownAssign.SetCC(iconIdx, caster, detected)
        CooldownAssign._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " set CC icon " .. iconIdx)
        end
        if ns.RefreshCcView then ns.RefreshCcView() end
    end)

    ns.Comm.RegisterHandler("CC_CLEAR", function(parts, sender, channel)
        CooldownAssign._suppressBroadcast = true
        CooldownAssign.ClearAllCC()
        CooldownAssign._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " cleared CC assignments.")
        end
        if ns.RefreshCcView then ns.RefreshCcView() end
    end)
end

----------------------------------------------------------------------
-- Lock check shares the boss-config lock
----------------------------------------------------------------------
function CooldownAssign.IsLocked()
    return ns.BossTemplates and ns.BossTemplates.IsLocked() or false
end
