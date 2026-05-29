----------------------------------------------------------------------
-- RaidLead — Modules/HealAssign.lua
-- Global healer assignments (cross-heal / dedicated / not healing).
-- Data layer + sync.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local HealAssign = {}
ns.HealAssign = HealAssign

-- TBC healer-capable classes (regardless of spec)
HealAssign.HEALER_CLASSES = {
    PRIEST  = true,
    PALADIN = true,
    DRUID   = true,
    SHAMAN  = true,
}

HealAssign.MODES = { "cross", "dedicated", "none" }
HealAssign.MODE_LABEL = {
    cross     = "Cross-heal",
    dedicated = "Dedicated",
    none      = "Not healing",
}

HealAssign._suppressBroadcast = false

----------------------------------------------------------------------
-- Storage
----------------------------------------------------------------------
local function EnsureDB()
    if not ns.db then
        -- Fallback init in case ADDON_LOADED hasn't run yet
        if RaidLeadDB then
            ns.db = RaidLeadDB
        elseif ns.InitDB then
            ns.InitDB()
        end
    end
    if not ns.db then return false end
    if not ns.db.healers then ns.db.healers = {} end
    return true
end
HealAssign.EnsureDB = EnsureDB

function HealAssign.GetConfig(healerName)
    if not EnsureDB() then return nil end
    return ns.db.healers[healerName]
end

function HealAssign.SetConfig(healerName, mode, target)
    if not EnsureDB() then return end
    if not healerName or healerName == "" then return end

    if mode ~= "dedicated" then target = nil end
    if target == "" then target = nil end

    -- Preserve any existing Earth Shield assignment when changing modes,
    -- except when going to "none" — turning a healer off should also
    -- clear their ES target.
    local existing = ns.db.healers[healerName]
    local existingES = existing and existing.earthShield
    local hadES      = existingES ~= nil

    if mode == "none" then
        ns.db.healers[healerName] = { mode = mode, target = target }
    else
        ns.db.healers[healerName] = {
            mode        = mode,
            target      = target,
            earthShield = existingES,
        }
    end
    ns.D("HealAssign.Set " .. healerName .. " mode=" .. tostring(mode) .. " target=" .. tostring(target))

    if not HealAssign._suppressBroadcast and ns.Comm then
        ns.Comm.Send("HEAL_SET", healerName, mode, target or "")
        -- If we wiped an ES along with the mode change, broadcast that too
        -- so other clients clear their local ES for this healer.
        if mode == "none" and hadES then
            ns.Comm.Send("HEAL_ES", healerName, "")
        end
    end
end

function HealAssign.ClearAll()
    if not EnsureDB() then return end
    ns.db.healers = {}
    ns.P("Cleared all heal assignments.")
    if not HealAssign._suppressBroadcast and ns.Comm then
        ns.Comm.Send("HEAL_CLEAR")
    end
end

----------------------------------------------------------------------
-- Earth Shield (shaman-specific extra target)
----------------------------------------------------------------------
function HealAssign.SetEarthShield(shamanName, target)
    if not EnsureDB() then return end
    if not shamanName or shamanName == "" then return end
    if target == "" then target = nil end

    -- Ensure base config exists
    if not ns.db.healers[shamanName] then
        ns.db.healers[shamanName] = { mode = "cross" }
    end
    ns.db.healers[shamanName].earthShield = target
    ns.D("HealAssign.SetES " .. shamanName .. " -> " .. tostring(target))

    if not HealAssign._suppressBroadcast and ns.Comm then
        ns.Comm.Send("HEAL_ES", shamanName, target or "")
    end
end

function HealAssign.GetEarthShield(shamanName)
    local cfg = HealAssign.GetConfig(shamanName)
    return cfg and cfg.earthShield or nil
end

----------------------------------------------------------------------
-- Hunter Misdirect (global hunter -> tank assignment)
----------------------------------------------------------------------
local function EnsureMisdirectDB()
    if not ns.db then
        if RaidLeadDB then ns.db = RaidLeadDB
        elseif ns.InitDB then ns.InitDB() end
    end
    if not ns.db then return false end
    if not ns.db.misdirects then ns.db.misdirects = {} end
    return true
end
HealAssign.EnsureMisdirectDB = EnsureMisdirectDB

function HealAssign.SetMisdirect(hunterName, target)
    if not EnsureMisdirectDB() then return end
    if not hunterName or hunterName == "" then return end
    if target == "" then target = nil end

    ns.db.misdirects[hunterName] = target
    ns.D("HealAssign.SetMD " .. hunterName .. " -> " .. tostring(target))

    if not HealAssign._suppressBroadcast and ns.Comm then
        ns.Comm.Send("MD_SET", hunterName, target or "")
    end
end

function HealAssign.GetMisdirect(hunterName)
    if not ns.db or not ns.db.misdirects then return nil end
    return ns.db.misdirects[hunterName]
end

function HealAssign.ClearMisdirects()
    if not EnsureMisdirectDB() then return end
    ns.db.misdirects = {}
    ns.P("Cleared all Misdirect assignments.")
    if not HealAssign._suppressBroadcast and ns.Comm then
        ns.Comm.Send("MD_CLEAR")
    end
end

-- Returns sorted list of HUNTER-class players: { {name=, class=}, ... }
function HealAssign.GetHunters()
    local hunters = {}
    if not ns.BuffScan or not ns.BuffScan.scanResults then return hunters end
    for name, r in pairs(ns.BuffScan.scanResults) do
        if r.class == "HUNTER" then
            hunters[#hunters + 1] = { name = name, class = r.class }
        end
    end
    table.sort(hunters, function(a, b) return a.name < b.name end)
    return hunters
end

----------------------------------------------------------------------
-- Roster helpers (read from BuffScan's scan results)
----------------------------------------------------------------------

-- Returns sorted list of healer-class players: { {name=, class=}, ... }
function HealAssign.GetHealers()
    local healers = {}
    if not ns.BuffScan or not ns.BuffScan.scanResults then return healers end

    for name, r in pairs(ns.BuffScan.scanResults) do
        if r.class and HealAssign.HEALER_CLASSES[r.class] then
            healers[#healers + 1] = { name = name, class = r.class }
        end
    end
    table.sort(healers, function(a, b) return a.name < b.name end)
    return healers
end

-- Returns sorted list of all raid members (any class) for target dropdown
function HealAssign.GetAllMembers()
    local members = {}
    if not ns.BuffScan or not ns.BuffScan.scanResults then return members end

    for name, r in pairs(ns.BuffScan.scanResults) do
        members[#members + 1] = { name = name, class = r.class or "UNKNOWN" }
    end
    table.sort(members, function(a, b) return a.name < b.name end)
    return members
end

----------------------------------------------------------------------
-- Main tank detection
-- Reads the in-game raid frame /maintank designations
-- (right-click a raid frame portrait -> "Set Main Tank").
-- pcall-guarded because GetPartyAssignment is missing on some clients.
----------------------------------------------------------------------
function HealAssign.GetMainTanks()
    local mts  = {}
    local seen = {}
    if not GetPartyAssignment then return mts end
    if not ns.BuildUnitList then return mts end

    local units = ns.BuildUnitList()
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local ok, isMT = pcall(GetPartyAssignment, "MAINTANK", unit)
            if ok and isMT then
                local name = UnitName(unit)
                if name and not seen[name] then
                    seen[name] = true
                    mts[#mts + 1] = name
                end
            end
        end
    end
    return mts
end

----------------------------------------------------------------------
-- Auto-assign healers
--
-- Strategy:
--   * Candidate healers = anyone who self-declared role "healer" via
--     the Roles module, plus any healer-class player who has not
--     declared a role yet. People who declared a non-healer role
--     (tank/melee/ranged) are EXCLUDED and have their existing healer
--     config cleared to "none".
--   * Class defaults:
--       PALADIN -> dedicated to a main tank (round-robin across MTs)
--       SHAMAN  -> cross-heal, plus Earth Shield on MT 1
--       PRIEST  -> cross-heal
--       DRUID   -> cross-heal
--   * Main tanks come from the in-game /maintank assignments. If none
--     are set, paladins fall back to cross-heal and we warn.
--
-- Graceful: missing data prints small notes, never errors.
----------------------------------------------------------------------
function HealAssign.AutoAssign()
    if HealAssign.IsLocked() then
        ns.LockedNotice()
        return
    end

    if not ns.BuffScan or not ns.BuffScan.scanResults
       or next(ns.BuffScan.scanResults) == nil then
        ns.P("|cFFFF8800Auto-Assign:|r No raid scan data yet. Run |cFFFFCC00/rl scan|r first.")
        return
    end

    local warnings = {}
    local mts = HealAssign.GetMainTanks()
    if #mts == 0 then
        warnings[#warnings + 1] =
            "no |cFFFFCC00/maintank|r set (right-click a portrait in the default raid frame to mark tanks)"
    end

    -- Build candidates ------------------------------------------------
    local candidates = {}
    for name, info in pairs(ns.BuffScan.scanResults) do
        local class    = info.class
        local declared = ns.Roles and ns.Roles.GetRole(name)
        local isHealerClass = class and HealAssign.HEALER_CLASSES[class]

        local include
        if declared == "healer" then
            include = true
        elseif declared and declared ~= "healer" then
            include = false
        else
            include = isHealerClass and true or false
        end

        if include then
            candidates[#candidates + 1] = { name = name, class = class or "UNKNOWN" }
        end
    end
    table.sort(candidates, function(a, b) return a.name < b.name end)

    if #candidates == 0 then
        ns.P("|cFFFF8800Auto-Assign:|r No healer candidates found.")
        return
    end

    -- Apply rules -----------------------------------------------------
    local palaIdx        = 1
    local assigned       = 0
    local palaFallback   = 0
    local esApplied      = 0

    HealAssign._suppressBroadcast = false  -- send each change so peers update

    for _, c in ipairs(candidates) do
        if c.class == "PALADIN" then
            if #mts > 0 then
                local target = mts[((palaIdx - 1) % #mts) + 1]
                HealAssign.SetConfig(c.name, "dedicated", target)
                palaIdx = palaIdx + 1
            else
                HealAssign.SetConfig(c.name, "cross", nil)
                palaFallback = palaFallback + 1
            end
        elseif c.class == "SHAMAN" then
            HealAssign.SetConfig(c.name, "cross", nil)
            if mts[1] then
                HealAssign.SetEarthShield(c.name, mts[1])
                esApplied = esApplied + 1
            end
        else
            -- PRIEST, DRUID, or unknown but flagged as healer
            HealAssign.SetConfig(c.name, "cross", nil)
        end
        assigned = assigned + 1
    end

    -- Demote: heal-class players that declared a non-healer role ------
    local demoted = 0
    for name, info in pairs(ns.BuffScan.scanResults) do
        local declared = ns.Roles and ns.Roles.GetRole(name)
        if declared and declared ~= "healer"
           and info.class and HealAssign.HEALER_CLASSES[info.class] then
            local existing = HealAssign.GetConfig(name)
            if not existing or existing.mode ~= "none" then
                HealAssign.SetConfig(name, "none", nil)
                demoted = demoted + 1
            end
        end
    end

    -- Summary ---------------------------------------------------------
    local summary = "Auto-assigned " .. assigned .. " healer"
                  .. (assigned == 1 and "" or "s")
                  .. " using " .. #mts .. " main tank"
                  .. (#mts == 1 and "" or "s") .. "."
    ns.P("|cFF44FF44" .. summary .. "|r")

    if esApplied > 0 then
        ns.P("|cFF888888  Earth Shield applied to " .. esApplied
            .. " shaman" .. (esApplied == 1 and "" or "s") .. ".|r")
    end
    if demoted > 0 then
        ns.P("|cFF888888  Marked " .. demoted .. " healer-class player"
            .. (demoted == 1 and "" or "s")
            .. " as Off (self-declared non-healer role).|r")
    end
    if palaFallback > 0 then
        ns.P("|cFFFFCC00Note:|r " .. palaFallback
            .. " paladin(s) defaulted to cross-heal (no main tank set).")
    end
    for _, w in ipairs(warnings) do
        ns.P("|cFFFFCC00Note:|r " .. w)
    end

    if ns.RefreshHealAssign then ns.RefreshHealAssign() end
end

----------------------------------------------------------------------
-- Build chat announce lines
----------------------------------------------------------------------
function HealAssign.BuildAnnounceLines()
    local healers = HealAssign.GetHealers()
    local crossHealers = {}
    local dedicatedPairs = {}
    local esPairs = {}

    for _, h in ipairs(healers) do
        local cfg = HealAssign.GetConfig(h.name) or { mode = "cross" }
        if cfg.mode == "cross" then
            crossHealers[#crossHealers + 1] = h.name
        elseif cfg.mode == "dedicated" and cfg.target then
            dedicatedPairs[#dedicatedPairs + 1] = h.name .. " -> " .. cfg.target
        end
        -- Earth Shield (shaman only, but not when off)
        if h.class == "SHAMAN" and cfg.mode ~= "none" and cfg.earthShield then
            esPairs[#esPairs + 1] = h.name .. " -> " .. cfg.earthShield
        end
        -- skip "none"
    end

    -- Hunter misdirect pairs
    local mdPairs = {}
    if ns.db and ns.db.misdirects then
        local hunters = HealAssign.GetHunters()
        for _, h in ipairs(hunters) do
            local target = ns.db.misdirects[h.name]
            if target then
                mdPairs[#mdPairs + 1] = h.name .. " -> " .. target
            end
        end
    end

    if #dedicatedPairs == 0 and #crossHealers == 0 and #esPairs == 0 and #mdPairs == 0 then
        return { "== Heal Assignments ==", "(none configured)" }
    end

    -- Multi-line format with section dividers between distinct
    -- groups (healers / earth shield / misdirect) for readability.
    local DIVIDER = "----------"
    local lines = { "== Heal Assignments ==" }

    -- Healer block (cross + dedicated)
    local healerBlock = {}
    if #crossHealers > 0 then
        healerBlock[#healerBlock + 1] = "Cross-heal: " .. table.concat(crossHealers, ", ")
    end
    for _, pair in ipairs(dedicatedPairs) do
        healerBlock[#healerBlock + 1] = pair  -- already in "Healer -> Target" form
    end
    for _, line in ipairs(healerBlock) do lines[#lines + 1] = line end

    -- Earth Shield block
    if #esPairs > 0 then
        if #healerBlock > 0 then lines[#lines + 1] = DIVIDER end
        for _, pair in ipairs(esPairs) do
            lines[#lines + 1] = "Earth Shield: " .. pair
        end
    end

    -- Misdirect block
    if #mdPairs > 0 then
        if #healerBlock > 0 or #esPairs > 0 then lines[#lines + 1] = DIVIDER end
        for _, pair in ipairs(mdPairs) do
            lines[#lines + 1] = "Misdirect: " .. pair
        end
    end

    return lines
end

----------------------------------------------------------------------
-- Compact view text builders (used by the compact / live view)
----------------------------------------------------------------------
local function CompactHealerName(name, classKey)
    if ns.ClassColor then
        return ns.ClassColor(classKey or "UNKNOWN") .. name .. "|r"
    end
    return name
end

local function ClassFor(playerName)
    if ns.BuffScan and ns.BuffScan.scanResults
       and ns.BuffScan.scanResults[playerName] then
        return ns.BuffScan.scanResults[playerName].class
    end
    return "UNKNOWN"
end

function HealAssign.BuildHealersCompactText()
    local healers = HealAssign.GetHealers()
    if #healers == 0 then return "" end

    local dedicated = {}
    local cross     = {}
    local es        = {}

    for _, h in ipairs(healers) do
        local cfg = HealAssign.GetConfig(h.name) or { mode = "cross" }
        if cfg.mode == "dedicated" and cfg.target then
            dedicated[#dedicated + 1] =
                CompactHealerName(h.name, h.class) .. " -> " ..
                CompactHealerName(cfg.target, ClassFor(cfg.target))
        elseif cfg.mode == "cross" then
            cross[#cross + 1] = CompactHealerName(h.name, h.class)
        end
        if h.class == "SHAMAN" and cfg.mode ~= "none" and cfg.earthShield then
            es[#es + 1] =
                CompactHealerName(h.name, h.class) .. " -> " ..
                CompactHealerName(cfg.earthShield, ClassFor(cfg.earthShield))
        end
    end

    local lines = {}
    for _, l in ipairs(dedicated) do lines[#lines + 1] = l end
    if #cross > 0 then
        lines[#lines + 1] = "|cFFAAAAAACross:|r " .. table.concat(cross, ", ")
    end
    for _, l in ipairs(es) do
        lines[#lines + 1] = "|cFF55D5FFES:|r " .. l
    end
    return table.concat(lines, "\n")
end

function HealAssign.BuildMisdirectsCompactText()
    if not ns.db or not ns.db.misdirects then return "" end
    local hunters = HealAssign.GetHunters()
    if #hunters == 0 then return "" end

    local lines = {}
    for _, h in ipairs(hunters) do
        local target = ns.db.misdirects[h.name]
        if target then
            lines[#lines + 1] =
                CompactHealerName(h.name, h.class) .. " -> " ..
                CompactHealerName(target, ClassFor(target))
        end
    end
    return table.concat(lines, "\n")
end

----------------------------------------------------------------------
-- Lock check (shares the boss-config lock for now)
----------------------------------------------------------------------
function HealAssign.IsLocked()
    return ns.BossTemplates and ns.BossTemplates.IsLocked() or false
end

----------------------------------------------------------------------
-- Sync handlers
----------------------------------------------------------------------
if ns.Comm then
    -- WHISPER = bulk sync reply, no chat output (would spam dozens of lines
    -- after a /reload or zone change). RAID/PARTY = real-time change, notify.
    local function isBulkSync(channel) return channel == "WHISPER" end

    ns.Comm.RegisterHandler("HEAL_SET", function(parts, sender, channel)
        local healerName = parts[2]
        local mode       = parts[3]
        local target     = parts[4]
        if target == "" then target = nil end
        if not (healerName and mode) then return end

        HealAssign._suppressBroadcast = true
        HealAssign.SetConfig(healerName, mode, target)
        HealAssign._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " set heal: " .. healerName)
        end
        if ns.RefreshHealAssign then ns.RefreshHealAssign() end
    end)

    ns.Comm.RegisterHandler("HEAL_CLEAR", function(parts, sender, channel)
        HealAssign._suppressBroadcast = true
        HealAssign.ClearAll()
        HealAssign._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " cleared heal assignments.")
        end
        if ns.RefreshHealAssign then ns.RefreshHealAssign() end
    end)

    ns.Comm.RegisterHandler("HEAL_ES", function(parts, sender, channel)
        local shamanName = parts[2]
        local target     = parts[3]
        if target == "" then target = nil end
        if not shamanName then return end

        HealAssign._suppressBroadcast = true
        HealAssign.SetEarthShield(shamanName, target)
        HealAssign._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " set ES: " .. shamanName .. " -> " .. (target or "(none)"))
        end
        if ns.RefreshHealAssign then ns.RefreshHealAssign() end
    end)

    ns.Comm.RegisterHandler("MD_SET", function(parts, sender, channel)
        local hunterName = parts[2]
        local target     = parts[3]
        if target == "" then target = nil end
        if not hunterName then return end

        HealAssign._suppressBroadcast = true
        HealAssign.SetMisdirect(hunterName, target)
        HealAssign._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " set Misdirect: " .. hunterName .. " -> " .. (target or "(none)"))
        end
        if ns.RefreshHealAssign then ns.RefreshHealAssign() end
    end)

    ns.Comm.RegisterHandler("MD_CLEAR", function(parts, sender, channel)
        HealAssign._suppressBroadcast = true
        HealAssign.ClearMisdirects()
        HealAssign._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " cleared Misdirect assignments.")
        end
        if ns.RefreshHealAssign then ns.RefreshHealAssign() end
    end)
end
