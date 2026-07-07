----------------------------------------------------------------------
-- RaidLead — Modules/CombatReport.lua
-- "Combat Report": a live tracker of key raid utility cooldowns + deaths.
--
-- Tracks (all from the LOCAL combat log, no addon messages sent):
--   * Druid Innervate + Battle Rez (Rebirth) casts - who, on whom, and an
--     inferred cooldown countdown so the raid lead can see how many rezzes
--     / innervates are still available during a fight.
--   * Deaths (UNIT_DIED) of group members, as a timeline.
--   * Warlock Soulstones (live buff scan) - folded into a single
--     "combat rez pool" and a per-death rez suggestion.
--
-- HOW IT KNOWS: COMBAT_LOG_EVENT_UNFILTERED, so it sees anything within
-- combat-log range (~100 yd, effectively the whole raid on a pull). It is
-- LOCAL-ONLY: no addon messages, so it can never contribute to channel
-- spam / disconnects. Cooldown "ready" is INFERRED (the game does not
-- expose another player's real cooldown): a spell is assumed up until we
-- see it cast, then counts down its full cooldown - these are real-world
-- timers, so they persist across pulls (a 20-min Battle Rez spans several).
--
-- The logger only listens while grouped (auto-gated), and can optionally
-- clear its LOG at the start of each pull (cooldown timers are kept).
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local CombatReport = {}
ns.CombatReport = CombatReport

-- Cooldowns (seconds) in TBC.
CombatReport.CD = { innervate = 360, rebirth = 1200, misdirect = 120 }

-- class = the class that owns the spell (used to build the readiness board
-- rows and to know which cells apply to which player).
CombatReport.KINDS = {
    innervate = { label = "Innervate",  class = "DRUID",  icon = "Interface\\Icons\\Spell_Nature_Lightning" },
    rebirth   = { label = "Battle Rez", class = "DRUID",  icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
    misdirect = { label = "Misdirect",  class = "HUNTER", icon = "Interface\\Icons\\Ability_Hunter_Misdirection" },
}

----------------------------------------------------------------------
-- Spell identification
----------------------------------------------------------------------
-- Resolve localized names once so all Rebirth ranks match by name and
-- non-English clients still work. Fall back to the English names.
local INNERVATE_NAME = (GetSpellInfo and GetSpellInfo(29166)) or "Innervate"
local REBIRTH_NAME   = (GetSpellInfo and GetSpellInfo(20484)) or "Rebirth"
local MISDIRECT_NAME = (GetSpellInfo and GetSpellInfo(34477)) or "Misdirection"
local SOULSTONE_NAME = (GetSpellInfo and GetSpellInfo(20707)) or "Soulstone Resurrection"

-- Belt-and-suspenders explicit ID set (all TBC ranks).
local SPELL_KIND = {
    [29166] = "innervate",                                      -- Innervate
    [20484] = "rebirth", [20739] = "rebirth", [20742] = "rebirth",
    [20747] = "rebirth", [20748] = "rebirth",                   -- Rebirth r1-5
    [34477] = "misdirect",                                      -- Misdirection
}

local function KindOf(spellId, spellName)
    if spellId and SPELL_KIND[spellId] then return SPELL_KIND[spellId] end
    if spellName == INNERVATE_NAME then return "innervate" end
    if spellName == REBIRTH_NAME   then return "rebirth"   end
    if spellName == MISDIRECT_NAME then return "misdirect" end
    return nil
end

local function StripRealm(name)
    if not name then return nil end
    return name:match("^[^-]+") or name
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
-- events: chronological, newest appended at the end. kinds:
--   "innervate" | "rebirth" (casts, caster+target) | "death" (caster only)
CombatReport.events   = {}
-- lastCast[caster][kind] = GetTime() of the most recent observed cast.
CombatReport.lastCast = {}
CombatReport.resetAt  = GetTime()

local MAX_EVENTS = 60

----------------------------------------------------------------------
-- Group helpers
----------------------------------------------------------------------
-- Unit tokens for the group, including the player when solo.
local function GroupUnits()
    local units = ns.BuildUnitList()
    if #units == 0 and UnitExists("player") then units = { "player" } end
    return units
end

-- Set of stripped names currently in the group (for death filtering).
local function GroupNameSet()
    local set = {}
    for _, u in ipairs(GroupUnits()) do
        if UnitExists(u) then
            local n = StripRealm(UnitName(u))
            if n then set[n] = true end
        end
    end
    return set
end

----------------------------------------------------------------------
-- Recording
----------------------------------------------------------------------
local function pushEvent(e)
    CombatReport.events[#CombatReport.events + 1] = e
    while #CombatReport.events > MAX_EVENTS do
        table.remove(CombatReport.events, 1)
    end
    if ns.RefreshCombatReport then ns.RefreshCombatReport() end
end

local function RecordCast(caster, target, kind)
    caster = StripRealm(caster)
    target = StripRealm(target)
    if not caster or not kind then return end
    local now = GetTime()
    pushEvent({ t = now, clock = date("%H:%M:%S"), caster = caster, target = target, kind = kind })
    CombatReport.lastCast[caster] = CombatReport.lastCast[caster] or {}
    CombatReport.lastCast[caster][kind] = now
end

local function RecordDeath(name)
    name = StripRealm(name)
    if not name then return end
    pushEvent({ t = GetTime(), clock = date("%H:%M:%S"), caster = name, kind = "death" })
end

-- Clear the cast / death log for a fresh pull. Cooldown timers are KEPT on
-- purpose: they're real-world time (a 20-min Battle Rez spans several pulls),
-- so wiping them would falsely show a druid as Ready when they're not. Used
-- by the Clear Log button and the optional auto-clear-each-pull.
function CombatReport.SoftReset(quiet)
    CombatReport.events  = {}
    CombatReport.resetAt = GetTime()
    if ns.RefreshCombatReport then ns.RefreshCombatReport() end
    if not quiet then
        ns.P("|cFF66CCFFCombat Report log cleared.|r Cooldown timers keep running.")
    end
end

-- Solo/testing helper (/raidlead cdtest): inject a few fake casts.
function CombatReport.InjectTest()
    local me = StripRealm(UnitName("player")) or "You"
    RecordCast("Treebark",   me,         "innervate")
    RecordCast("Feralheart", "Tankadin", "rebirth")
    RecordCast("Huntard",    "Tankadin", "misdirect")
    ns.P("Injected a test Innervate + Battle Rez + Misdirect. Open the |cFFFFCC00Combat|r tab.")
end

----------------------------------------------------------------------
-- Queries
----------------------------------------------------------------------
-- Remaining cooldown (seconds) for caster+kind; <= 0 means ready.
function CombatReport.Remaining(caster, kind)
    local byKind = CombatReport.lastCast[caster]
    local last   = byKind and byKind[kind]
    if not last then return 0 end
    local cd = CombatReport.CD[kind] or 0
    return math.max(0, cd - (GetTime() - last))
end

-- "alive" | "dead" | "offline" | "unknown"
function CombatReport.UnitStatus(unit)
    if not unit or not UnitExists(unit) then return "unknown" end
    if UnitIsConnected and not UnitIsConnected(unit) then return "offline" end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then return "dead" end
    return "alive"
end

-- Ordered list of { name, unit } for every Druid in the group, plus any
-- druid we've only seen via events, and yourself when solo.
function CombatReport.GetDruids()
    local list, seen = {}, {}
    local function add(name, unit)
        name = StripRealm(name)
        if not name or seen[name] then return end
        seen[name] = true
        list[#list + 1] = { name = name, unit = unit }
    end

    for _, u in ipairs(GroupUnits()) do
        if UnitExists(u) then
            local _, class = UnitClass(u)
            if class == "DRUID" then add(UnitName(u), u) end
        end
    end
    for caster in pairs(CombatReport.lastCast) do add(caster, nil) end

    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Which classes own at least one tracked spell (built from KINDS).
local TRACKED_CLASS = {}
for _, meta in pairs(CombatReport.KINDS) do
    if meta.class then TRACKED_CLASS[meta.class] = true end
end

-- Ordered list of { name, unit, class } for every group member of a class we
-- track a cooldown for (Druids, Hunters), plus any caster we've only seen via
-- events. Druids first, then hunters; alphabetical within each. Used to build
-- the readiness board (which shows each spell as a column).
function CombatReport.GetTrackedPlayers()
    local list, seen = {}, {}
    local function add(name, unit, class)
        name = StripRealm(name)
        if not name or seen[name] then return end
        seen[name] = true
        list[#list + 1] = { name = name, unit = unit, class = class }
    end

    for _, u in ipairs(GroupUnits()) do
        if UnitExists(u) then
            local _, class = UnitClass(u)
            if TRACKED_CLASS[class] then add(UnitName(u), u, class) end
        end
    end
    -- Casters seen only via events: infer their class from the spell kind.
    for caster, kinds in pairs(CombatReport.lastCast) do
        if not seen[caster] then
            local class
            for k in pairs(kinds) do
                local meta = CombatReport.KINDS[k]
                if meta and meta.class then class = meta.class end
            end
            add(caster, nil, class)
        end
    end

    -- Druids before hunters (rez cooldowns are the headline), alpha within.
    local RANK = { DRUID = 1, HUNTER = 2 }
    table.sort(list, function(a, b)
        local ra, rb = RANK[a.class] or 9, RANK[b.class] or 9
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)
    return list
end

----------------------------------------------------------------------
-- Soulstones: live buff scan (throttled). Best-effort - a soulstone on a
-- player whose buffs aren't currently readable may be missed until they
-- come into range. Combat log alone would miss pre-pull applications, so a
-- scan is the more reliable source here.
----------------------------------------------------------------------
CombatReport._ss   = {}
CombatReport._ssAt = 0

local function ScanSoulstones()
    local now = GetTime()
    -- Reuse the cached result for up to a second (first call always scans).
    if CombatReport._ssAt ~= 0 and (now - CombatReport._ssAt) < 1 then
        return CombatReport._ss
    end
    CombatReport._ssAt = now

    local found = {}
    for _, u in ipairs(GroupUnits()) do
        if UnitExists(u) then
            for i = 1, 40 do
                local nm = UnitBuff(u, i)
                if not nm then break end
                if nm == SOULSTONE_NAME then
                    local pn = StripRealm(UnitName(u))
                    if pn then found[pn] = true end
                    break
                end
            end
        end
    end
    CombatReport._ss = found
    return found
end
CombatReport.GetSoulstones = ScanSoulstones

----------------------------------------------------------------------
-- Currently-down group members (for the rez plan).
--   { name, unit, class, released (ghost), soulstone }
----------------------------------------------------------------------
function CombatReport.GetDown()
    local ss  = ScanSoulstones()
    local out = {}
    for _, u in ipairs(GroupUnits()) do
        if UnitExists(u) and UnitIsPlayer(u) and UnitIsConnected(u)
            and UnitIsDeadOrGhost(u) then
            local n = StripRealm(UnitName(u))
            if n then
                out[#out + 1] = {
                    name      = n,
                    unit      = u,
                    class     = select(2, UnitClass(u)),
                    released  = (UnitIsGhost and UnitIsGhost(u)) and true or false,
                    soulstone = ss[n] and true or false,
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Availability snapshot across all tracked cooldowns. ready[kind]/total[kind]
-- are bucketed by the spell's owning class, so hunters count for misdirect,
-- druids for innervate/rebirth. Combat-rez pool = ready Rebirths + soulstones.
function CombatReport.Availability()
    local ready, total = {}, {}
    for _, p in ipairs(CombatReport.GetTrackedPlayers()) do
        local st    = p.unit and CombatReport.UnitStatus(p.unit) or "alive"
        local alive = (st ~= "dead" and st ~= "offline")
        for kind, meta in pairs(CombatReport.KINDS) do
            if meta.class == p.class then
                total[kind] = (total[kind] or 0) + 1
                if alive and CombatReport.Remaining(p.name, kind) <= 0 then
                    ready[kind] = (ready[kind] or 0) + 1
                end
            end
        end
    end
    local ssCount = 0
    for _ in pairs(ScanSoulstones()) do ssCount = ssCount + 1 end
    return {
        rezReady = ready.rebirth   or 0, rezTotal = total.rebirth   or 0,
        innReady = ready.innervate or 0, innTotal = total.innervate or 0,
        mdReady  = ready.misdirect or 0, mdTotal  = total.misdirect or 0,
        ssCount  = ssCount,
        pool     = (ready.rebirth or 0) + ssCount,
    }
end

-- Per-death rez suggestion. Returns an ordered list of
--   { name, class, by, kind }   kind = "ss" | "rez" | "none"
-- assigning each ready Rebirth to one corpse in turn.
function CombatReport.BuildRezPlan()
    local down = CombatReport.GetDown()
    local ready = {}
    for _, d in ipairs(CombatReport.GetDruids()) do
        local st = d.unit and CombatReport.UnitStatus(d.unit) or "alive"
        if st == "alive" and CombatReport.Remaining(d.name, "rebirth") <= 0 then
            ready[#ready + 1] = d.name
        end
    end

    local di, plan = 1, {}
    for _, p in ipairs(down) do
        local e = { name = p.name, class = p.class }
        if p.soulstone then
            e.by, e.kind = "Soulstone", "ss"
        elseif p.released then
            e.by, e.kind = "released", "none"
        elseif ready[di] then
            e.by, e.kind = ready[di], "rez"
            di = di + 1
        else
            e.by, e.kind = "no rez", "none"
        end
        plan[#plan + 1] = e
    end
    return plan, down
end

----------------------------------------------------------------------
-- Compact-view line (optional section in the live overlay)
----------------------------------------------------------------------
local function fmtTime(sec)
    sec = math.max(0, math.floor(sec + 0.5))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end
CombatReport.FmtTime = fmtTime

local function readyStr(ready, total)
    return ((ready > 0) and "|cFF44FF44" or "|cFFFF6644") .. ready .. "/" .. total .. "|r ready"
end

function CombatReport.BuildCompactText()
    local a = CombatReport.Availability()
    if a.rezTotal == 0 and a.ssCount == 0 and a.innTotal == 0 and a.mdTotal == 0 then
        return ""
    end

    local lines = {}
    if a.rezTotal > 0 or a.ssCount > 0 then
        lines[#lines + 1] = "Combat rez: |cFF44FF44" .. a.pool .. "|r"
            .. "  |cFF888888(" .. a.rezReady .. " rez + " .. a.ssCount .. " SS)|r"
    end
    if a.innTotal > 0 then
        lines[#lines + 1] = "Innervate: " .. readyStr(a.innReady, a.innTotal)
    end
    if a.mdTotal > 0 then
        lines[#lines + 1] = "Misdirect: " .. readyStr(a.mdReady, a.mdTotal)
    end

    local plan = CombatReport.BuildRezPlan()
    if #plan > 0 then
        local segs = {}
        for _, e in ipairs(plan) do
            segs[#segs + 1] = e.name .. " |cFF888888(" .. e.by .. ")|r"
        end
        lines[#lines + 1] = "|cFFFF6644Down:|r " .. table.concat(segs, ", ")
    end
    return table.concat(lines, "\n")
end

-- Full readiness detail for the compact-panel hover: grouped by ability so
-- you can see exactly WHO has each thing ready, plus soulstones and who's
-- down. Returns color-coded, tooltip-ready strings.
function CombatReport.BuildTooltipLines()
    local lines   = {}
    local players = CombatReport.GetTrackedPlayers()

    for _, kind in ipairs({ "rebirth", "innervate", "misdirect" }) do
        local meta = CombatReport.KINDS[kind]
        local sub  = {}
        for _, p in ipairs(players) do
            if p.class == meta.class then
                local st  = p.unit and CombatReport.UnitStatus(p.unit) or "alive"
                local val
                if st == "offline" then val = "|cFF777777offline|r"
                elseif st == "dead" then val = "|cFFFF6644dead|r"
                else
                    local rem = CombatReport.Remaining(p.name, kind)
                    val = (rem <= 0) and "|cFF44FF44Ready|r"
                        or ("|cFFFFCC00" .. fmtTime(rem) .. "|r")
                end
                sub[#sub + 1] = "  " .. ns.ClassColor(p.class) .. p.name .. "|r  " .. val
            end
        end
        if #sub > 0 then
            lines[#lines + 1] = "|cFF9AD8FF" .. meta.label .. "|r"
            for _, s in ipairs(sub) do lines[#lines + 1] = s end
        end
    end

    local ss = {}
    for nm in pairs(ScanSoulstones()) do ss[#ss + 1] = nm end
    if #ss > 0 then
        table.sort(ss)
        for i, nm in ipairs(ss) do ss[i] = ns.ClassColor(ns.ClassOf(nm)) .. nm .. "|r" end
        lines[#lines + 1] = "|cFF9482C9Soulstone:|r " .. table.concat(ss, ", ")
    end

    local plan = CombatReport.BuildRezPlan()
    if #plan > 0 then
        lines[#lines + 1] = "|cFFFF6644Down:|r"
        for _, e in ipairs(plan) do
            local byCol = (e.kind == "none") and "|cFF888888" or "|cFF66CCFF"
            lines[#lines + 1] = "  " .. ns.ClassColor(e.class) .. e.name .. "|r"
                .. " |cFF999999->|r " .. byCol .. e.by .. "|r"
        end
    end

    return lines
end

----------------------------------------------------------------------
-- Combat-log listener (local-only; never broadcasts). Registration is
-- gated to being in a group by the lifecycle frame below.
----------------------------------------------------------------------
local PLAYER_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400

local cl = CreateFrame("Frame")
cl:SetScript("OnEvent", function()
    if not CombatLogGetCurrentEventInfo then return end
    local _, subevent, _, _, srcName, _, _, _, dstName, dstFlags, _, spellId, spellName =
        CombatLogGetCurrentEventInfo()

    if subevent == "SPELL_CAST_SUCCESS" then
        local kind = KindOf(spellId, spellName)
        if kind then RecordCast(srcName, dstName, kind) end

    elseif subevent == "UNIT_DIED" then
        -- Players only (excludes pets / NPCs), and only our group.
        if not dstName then return end
        if bit and dstFlags and bit.band(dstFlags, PLAYER_FLAG) == 0 then return end
        if GroupNameSet()[StripRealm(dstName)] then RecordDeath(dstName) end
    end
end)

----------------------------------------------------------------------
-- Lifecycle: only listen to the combat log while grouped (zero overhead
-- solo), and optionally soft-reset the log at the start of each pull.
----------------------------------------------------------------------
local listening = false
local function UpdateListening()
    local grouped = (ns.GetGroupType() ~= "solo")
    if grouped and not listening then
        cl:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        listening = true
    elseif not grouped and listening then
        cl:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        listening = false
    end
end

local ctrl = CreateFrame("Frame")
ctrl:RegisterEvent("PLAYER_LOGIN")
ctrl:RegisterEvent("GROUP_ROSTER_UPDATE")
pcall(ctrl.RegisterEvent, ctrl, "PARTY_MEMBERS_CHANGED")
pcall(ctrl.RegisterEvent, ctrl, "RAID_ROSTER_UPDATE")
ctrl:RegisterEvent("PLAYER_REGEN_DISABLED")
ctrl:RegisterEvent("PLAYER_REGEN_ENABLED")

local lastCombatEnd = 0
ctrl:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat. Treat it as a new pull only after a lull, so
        -- brief in-and-out of combat doesn't wipe the log mid-fight.
        local auto = ns.db and ns.db.settings and ns.db.settings.combatAutoReset
        if auto and (GetTime() - lastCombatEnd) > 5 then
            CombatReport.SoftReset(true)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        lastCombatEnd = GetTime()
    else
        UpdateListening()
    end
end)
