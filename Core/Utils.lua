----------------------------------------------------------------------
-- RaidLead — Core/Utils.lua
-- Shared constants, print helpers, class colors, utility functions
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.ADDON_NAME    = ADDON_NAME
ns.ADDON_VERSION = "1.7.1"
ns.VERSION       = ns.ADDON_VERSION  -- alias used by version-compare paths
ns.ACCENT        = "FF9933"
ns.PREFIX        = "|cFF" .. ns.ACCENT .. "[RaidLead]|r "
ns.DEBUG         = false

function ns.P(msg) print(ns.PREFIX .. msg) end
function ns.D(msg) if ns.DEBUG then print("|cFF999999[RL-DBG]|r " .. tostring(msg)) end end

----------------------------------------------------------------------
-- Semantic version compare: "X.Y.Z" strings -> -1 / 0 / 1
-- Empty or malformed values are treated as 0.0.0.
----------------------------------------------------------------------
function ns.CompareVersions(a, b)
    a = a or ""
    b = b or ""
    if a == b then return 0 end
    local function parse(v)
        local maj, min, pat = v:match("^(%d+)%.(%d+)%.?(%d*)$")
        return tonumber(maj) or 0, tonumber(min) or 0, tonumber(pat) or 0
    end
    local aMaj, aMin, aPat = parse(a)
    local bMaj, bMin, bPat = parse(b)
    if aMaj ~= bMaj then return aMaj < bMaj and -1 or 1 end
    if aMin ~= bMin then return aMin < bMin and -1 or 1 end
    if aPat ~= bPat then return aPat < bPat and -1 or 1 end
    return 0
end

----------------------------------------------------------------------
-- Class colors
----------------------------------------------------------------------
ns.CLASS_COLORS = {
    WARRIOR     = "C79C6E", PALADIN   = "F58CBA", HUNTER    = "ABD473",
    ROGUE       = "FFF569", PRIEST    = "FFFFFF", SHAMAN    = "0070DE",
    MAGE        = "69CCF0", WARLOCK   = "9482C9", DRUID     = "FF7D0A",
}

function ns.ClassColor(class)
    local c = ns.CLASS_COLORS[(class or ""):upper()] or "AAAAAA"
    return "|cFF" .. c
end

-- Class color as RGB floats (0..1), e.g. for SetTextColor / SetVertexColor.
function ns.ClassColorRGB(class)
    local hex = ns.CLASS_COLORS[(class or ""):upper()] or "AAAAAA"
    return tonumber(hex:sub(1, 2), 16) / 255,
           tonumber(hex:sub(3, 4), 16) / 255,
           tonumber(hex:sub(5, 6), 16) / 255
end

-- Look up a player's class. Checks an optional roster list first, then the
-- last buff-scan results; returns "UNKNOWN" if not found.
function ns.ClassOf(name, roster)
    if not name then return "UNKNOWN" end
    if roster then
        for _, p in ipairs(roster) do
            if p.name == name then return p.class or "UNKNOWN" end
        end
    end
    if ns.BuffScan and ns.BuffScan.scanResults and ns.BuffScan.scanResults[name] then
        return ns.BuffScan.scanResults[name].class or "UNKNOWN"
    end
    return "UNKNOWN"
end

function ns.Timestamp()
    return date("%Y-%m-%d %H:%M")
end

function ns.SetColorTex(tex, r, g, b, a)
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a or 1)
    else
        tex:SetTexture(r, g, b, a or 1)
    end
end

----------------------------------------------------------------------
-- SavedVariables / comm helpers shared by modules
----------------------------------------------------------------------

-- Ensure ns.db is bound (from SavedVariables, or by forcing InitDB).
-- Returns true if ns.db is available. Modules call this, then ensure
-- their own sub-tables.
function ns.EnsureDB()
    if not ns.db then
        if RaidLeadDB then ns.db = RaidLeadDB
        elseif ns.InitDB then ns.InitDB() end
    end
    return ns.db ~= nil
end

-- A sync reply arrives over WHISPER (bulk handshake) vs RAID/PARTY (a
-- live single edit). Used to silence per-entry chat spam during sync.
function ns.IsBulkSync(channel) return channel == "WHISPER" end

-- Accumulate per-recipient whisper parts, then build a { {name,msg}, ... }
-- list. Replaces the byName/order boilerplate in the whisper builders.
function ns.NewWhisperAccumulator()
    local byName, order = {}, {}
    return {
        add = function(name, part)
            if not name or name == "" or not part or part == "" then return end
            if not byName[name] then byName[name] = {}; order[#order + 1] = name end
            byName[name][#byName[name] + 1] = part
        end,
        build = function(prefix)
            local out = {}
            for _, name in ipairs(order) do
                out[#out + 1] = {
                    name = name,
                    msg  = (prefix or "") .. table.concat(byName[name], "; "),
                }
            end
            return out
        end,
    }
end

----------------------------------------------------------------------
-- Group helpers
----------------------------------------------------------------------
function ns.GetGroupType()
    if IsInRaid and IsInRaid() then return "raid" end
    if IsInGroup and IsInGroup() then return "party" end
    -- TBC fallbacks
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then return "raid" end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then return "party" end
    return "solo"
end

-- Scan all raid/party members' targets + mouseover + target for marked mobs.
-- Returns { [raidTargetIndex] = { name = "MobName", count = 1 } }
function ns.ScanMarkedMobs()
    local detected = {}
    local function consider(unit)
        if not UnitExists(unit) then return end
        if UnitIsPlayer(unit) then return end  -- players aren't mobs
        local idx = GetRaidTargetIndex(unit)
        if not idx then return end
        local name = UnitName(unit)
        if not name then return end
        if not detected[idx] then
            detected[idx] = { name = name, count = 1 }
        else
            detected[idx].count = detected[idx].count + 1
        end
    end

    -- Player's own context
    consider("target")
    consider("mouseover")
    consider("focus")

    -- Each raid member's target
    local gt = ns.GetGroupType()
    if gt == "raid" then
        local n = GetNumRaidMembers and GetNumRaidMembers() or 0
        for i = 1, n do
            consider("raid" .. i .. "target")
        end
    elseif gt == "party" then
        local n = GetNumPartyMembers and GetNumPartyMembers() or 0
        for i = 1, n do
            consider("party" .. i .. "target")
        end
    end

    -- Merge in anything captured by a Target Sweep (manually targeting /
    -- mousing over far-away marked mobs). Nameplate/group-target scanning
    -- misses out-of-range mobs; the sweep does not.
    if ns.MarkSweep and ns.MarkSweep.results then
        for idx, name in pairs(ns.MarkSweep.results) do
            if not detected[idx] then detected[idx] = { name = name, count = 1 } end
        end
    end

    return detected
end

----------------------------------------------------------------------
-- Target Sweep: a manual mode for reading marks on mobs that are out of
-- nameplate range. While active, every time you target OR mouse over a
-- marked enemy, its icon -> name is recorded. There is no range limit on
-- reading your target/mouseover, so this catches spread-out council mobs
-- (e.g. Maulgar) that nameplate scanning can't see. ScanMarkedMobs merges
-- these results, so the boss widgets pick them up automatically.
----------------------------------------------------------------------
ns.MarkSweep = { active = false, results = {} }

local sweepFrame = CreateFrame("Frame")
local sweepOnUpdate

local function SweepConsider(unit)
    if not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local idx = GetRaidTargetIndex(unit)
    if not idx then return end
    local name = UnitName(unit)
    if not name then return end
    ns.MarkSweep.results[idx] = name
    if sweepOnUpdate then sweepOnUpdate() end
end

sweepFrame:SetScript("OnEvent", function(_, event)
    if not ns.MarkSweep.active then return end
    if event == "PLAYER_TARGET_CHANGED" then
        SweepConsider("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        SweepConsider("mouseover")
    end
end)

function ns.MarkSweep.Start(onUpdate)
    ns.MarkSweep.results = {}
    ns.MarkSweep.active  = true
    sweepOnUpdate        = onUpdate
    sweepFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    sweepFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    -- Grab whatever is already targeted/hovered right away.
    SweepConsider("target")
    SweepConsider("mouseover")
    ns.P("|cFF88CCFFTarget Sweep on.|r Target or mouse over each marked mob; click again to stop.")
end

function ns.MarkSweep.Stop()
    ns.MarkSweep.active = false
    sweepOnUpdate       = nil
    sweepFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
    sweepFrame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
    local n = 0
    for _ in pairs(ns.MarkSweep.results) do n = n + 1 end
    ns.P("|cFF88CCFFTarget Sweep off.|r Captured " .. n .. " marked mob(s).")
end

function ns.MarkSweep.Clear()
    ns.MarkSweep.results = {}
end

----------------------------------------------------------------------
-- Auto-mark: apply raid target icons to enemies by name.
-- plan = { { iconIdx = 8, mob = "Krosh Firehand" }, ... }
-- Scans visible nameplates + the group's targets / mouseover / focus for
-- hostile units matching each plan entry's mob name and marks them.
-- Entries sharing a mob name (e.g. 5x "Hellfire Channeler") each consume
-- a distinct unit. Returns markedCount, missingNames (table).
----------------------------------------------------------------------
-- Gather unique hostile candidate units from every source we have:
-- visible enemy nameplates + the group's targets / mouseover / focus.
function ns.CollectHostileUnits()
    local units, seen = {}, {}
    local function add(unit)
        if not UnitExists(unit) then return end
        if UnitIsPlayer(unit) then return end
        if not UnitCanAttack("player", unit) then return end
        local guid = UnitGUID(unit)
        if not guid or seen[guid] then return end
        seen[guid] = true
        units[#units + 1] = unit
    end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            if plate.namePlateUnitToken then add(plate.namePlateUnitToken) end
        end
    end
    add("target"); add("mouseover"); add("focus")

    local gt = ns.GetGroupType()
    if gt == "raid" then
        local n = GetNumRaidMembers and GetNumRaidMembers() or 0
        for i = 1, n do add("raid" .. i .. "target") end
    elseif gt == "party" then
        local n = GetNumPartyMembers and GetNumPartyMembers() or 0
        for i = 1, n do add("party" .. i .. "target") end
    end

    return units
end

function ns.AutoMarkByPlan(plan)
    if type(plan) ~= "table" then return 0, {} end

    local units = ns.CollectHostileUnits()

    -- Assign icons, consuming one distinct unit per plan entry.
    local used, marked, missing = {}, 0, {}
    for _, entry in ipairs(plan) do
        if entry.mob and entry.iconIdx then
            local chosen
            for _, unit in ipairs(units) do
                local guid = UnitGUID(unit)
                if not used[guid] and UnitName(unit) == entry.mob then
                    chosen = unit
                    used[guid] = true
                    break
                end
            end
            if chosen then
                SetRaidTarget(chosen, entry.iconIdx)
                marked = marked + 1
            else
                missing[#missing + 1] = entry.mob
            end
        end
    end
    return marked, missing
end

-- Convenience wrapper for boss widgets: builds a plan from a list of
-- { iconIdx, mob, ... } rows, enforces the raid-marker permission, runs
-- the mark, and prints a friendly result. Returns markedCount.
function ns.AutoMarkBoss(list, bossName)
    -- In a raid, only the leader / assistants may place world markers.
    if ns.GetGroupType() == "raid" and ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can place raid markers.|r")
        return 0
    end

    local plan = {}
    for _, e in ipairs(list or {}) do
        if e.mob and e.iconIdx then
            plan[#plan + 1] = { iconIdx = e.iconIdx, mob = e.mob }
        end
    end

    local total = #plan
    local marked, missing = ns.AutoMarkByPlan(plan)

    if marked == 0 then
        ns.P("|cFF888888Auto-mark: no matching mobs in range. Enable enemy nameplates and get the pack on screen (or target them), then retry.|r")
    elseif marked < total then
        local uniq, seenName = {}, {}
        for _, m in ipairs(missing) do
            if not seenName[m] then seenName[m] = true; uniq[#uniq + 1] = m end
        end
        ns.P(string.format("Auto-mark: marked %d/%d. Not found: %s",
            marked, total, table.concat(uniq, ", ")))
    else
        ns.P(string.format("|cFF66CC66Auto-mark:|r all %d mobs marked for %s.",
            marked, bossName or "boss"))
    end
    return marked
end

----------------------------------------------------------------------
-- Generic "mark this pack": apply raid icons to whatever visible hostiles
-- aren't marked yet, in priority order. Independent of any boss data.
-- Icons already on visible mobs are left alone and not reused.
-- Returns markedCount, unmarkedSeen.
----------------------------------------------------------------------
ns.MARK_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 }  -- Skull, Cross, Square, Moon, Triangle, Diamond, Circle, Star

function ns.AutoMarkVisible(opts)
    opts = opts or {}
    local order = opts.icons or ns.MARK_ORDER

    local units = ns.CollectHostileUnits()

    -- Split into already-marked (note their icons) vs. unmarked.
    local usedIcon, unmarked = {}, {}
    for _, u in ipairs(units) do
        local idx = GetRaidTargetIndex(u)
        if idx and idx > 0 then
            usedIcon[idx] = true
        else
            unmarked[#unmarked + 1] = u
        end
    end

    -- Free icons in priority order (skip ones already in use on the pack).
    local freeIcons = {}
    for _, i in ipairs(order) do
        if not usedIcon[i] then freeIcons[#freeIcons + 1] = i end
    end

    local marked = 0
    for _, u in ipairs(unmarked) do
        local icon = freeIcons[marked + 1]
        if not icon then break end
        SetRaidTarget(u, icon)
        marked = marked + 1
    end
    return marked, #unmarked
end

-- Button/slash entry point: permission-gated + friendly reporting.
function ns.AutoMarkPack()
    if ns.GetGroupType() == "raid" and ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can place raid markers.|r")
        return 0
    end

    local marked, unmarkedSeen = ns.AutoMarkVisible()
    if marked == 0 then
        if unmarkedSeen == 0 then
            ns.P("|cFF888888Mark pack: nothing to mark. Get the pack on screen with enemy nameplates on (or target the mobs), then retry.|r")
        else
            ns.P("|cFF888888Mark pack: ran out of free raid icons.|r")
        end
    else
        ns.P(string.format("|cFF66CC66Mark pack:|r marked %d mob(s).", marked))
    end
    return marked
end

----------------------------------------------------------------------
-- One-by-one marking: stamp the player's current target with the next
-- icon in priority order, advancing each call. Targeting reaches much
-- farther than nameplates, so this is the way to mark spread packs.
----------------------------------------------------------------------
local markCursor = 1  -- 1-based index into ns.MARK_ORDER

function ns.GetNextMarkIcon()
    return ns.MARK_ORDER[markCursor]
end

-- Stamp the current target with a specific icon. Validated + permission
-- gated. Returns true on success. Does NOT touch any other unit, so it
-- can never steal an icon from a mob we can't currently see.
function ns.MarkTargetWith(icon)
    if ns.GetGroupType() == "raid" and ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can place raid markers.|r")
        return false
    end
    if not UnitExists("target") then
        ns.P("|cFF888888Target an enemy first.|r")
        return false
    end
    if UnitIsPlayer("target") then
        ns.P("|cFF888888That's a player, not a mob.|r")
        return false
    end
    SetRaidTarget("target", icon)
    return true
end

function ns.ResetMarkSequence()
    markCursor = 1
    if ns.UpdateMarkNextLabel then ns.UpdateMarkNextLabel() end
    ns.P("Mark sequence reset (next: Skull).")
end

function ns.MarkNextTarget()
    local icon = ns.MARK_ORDER[markCursor]
    if not ns.MarkTargetWith(icon) then return end

    local iconName = ns.RAID_ICON_NAMES and ns.RAID_ICON_NAMES[icon] or ("icon " .. icon)
    ns.P("|cFF66CC66Marked|r " .. (UnitName("target") or "target") .. " with " .. iconName .. ".")

    markCursor = markCursor + 1
    if markCursor > #ns.MARK_ORDER then
        markCursor = 1
        ns.P("|cFF888888(all 8 icons used \226\128\148 cycling back to Skull)|r")
    end

    if ns.UpdateMarkNextLabel then ns.UpdateMarkNextLabel() end
    -- Reflect the new mark on the Marks board if it's open.
    if ns.MarkBoard and ns.MarkBoard.ScanAndUpdate then
        ns.MarkBoard.ScanAndUpdate()
        if ns.RefreshMarksView then ns.RefreshMarksView() end
    end
end

-- Remove raid target icons from every visible hostile, and reset the Mark
-- Next sequence. Only clears mobs we can see (nameplates + targets); far
-- ones keep their icons. Returns the count cleared.
function ns.ClearVisibleMarks()
    if ns.GetGroupType() == "raid" and ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can clear raid markers.|r")
        return 0
    end
    local cleared = 0
    for _, u in ipairs(ns.CollectHostileUnits()) do
        if GetRaidTargetIndex(u) then
            SetRaidTarget(u, 0)
            cleared = cleared + 1
        end
    end
    markCursor = 1
    if ns.UpdateMarkNextLabel then ns.UpdateMarkNextLabel() end
    if cleared == 0 then
        ns.P("|cFF888888No visible marked mobs to clear (out of range ones keep their icons).|r")
    else
        ns.P(string.format("|cFF66CC66Cleared|r %d raid marker(s).", cleared))
    end
    return cleared
end

function ns.BuildUnitList()
    local groupType = ns.GetGroupType()
    local units = {}
    if groupType == "raid" then
        local n = GetNumRaidMembers and GetNumRaidMembers() or (GetNumGroupMembers and GetNumGroupMembers() or 0)
        for i = 1, n do
            units[#units + 1] = "raid" .. i
        end
    elseif groupType == "party" then
        units[#units + 1] = "player"
        local n = GetNumPartyMembers and GetNumPartyMembers() or (GetNumGroupMembers and GetNumGroupMembers() - 1 or 0)
        for i = 1, n do
            units[#units + 1] = "party" .. i
        end
    end
    return units, groupType
end

----------------------------------------------------------------------
-- Mock data for solo testing
----------------------------------------------------------------------
function ns.GenerateMockRaid()
    local mockPlayers = {
        { name = "Djaal",       class = "PALADIN"  },
        { name = "Djambalee",   class = "SHAMAN"   },
        { name = "Tankwar",     class = "WARRIOR"  },
        { name = "TreeDruid",   class = "DRUID"    },
        { name = "HolyPala",    class = "PALADIN"  },
        { name = "ShadowP",     class = "PRIEST"   },
        { name = "MageDps",     class = "MAGE"     },
        { name = "WarlockDps",  class = "WARLOCK"  },
        { name = "RogueDps",    class = "ROGUE"    },
        { name = "HunterDps",   class = "HUNTER"   },
        { name = "FeralDruid",  class = "DRUID"    },
        { name = "RetPala",     class = "PALADIN"  },
        { name = "EleSham",     class = "SHAMAN"   },
        { name = "FrostMage",   class = "MAGE"     },
        { name = "AffliLock",   class = "WARLOCK"  },
    }

    local BD = RaidSpyBuffs
    local results = {}
    local sorted = {}

    for _, p in ipairs(mockPlayers) do
        local raidBuffs = {}
        local raidBuffNames = {}
        local raidBuffOrder = {
            "motw", "fort", "ai", "spirit", "shadow",
            "kings", "might", "wisdom", "salvation",
            "battleShout", "commandingShout", "trueshotAura",
        }
        for _, fk in ipairs(raidBuffOrder) do
            raidBuffs[fk] = (math.random() > 0.3)  -- 70% chance to have each buff
            if raidBuffs[fk] and BD and BD.raidBuffs[fk] then
                raidBuffNames[fk] = BD.raidBuffs[fk].buffs[1]
            end
        end

        local hasFlask    = (math.random() > 0.4)
        local hasBattle   = (not hasFlask) and (math.random() > 0.5)
        local hasGuardian = (not hasFlask) and (math.random() > 0.5)

        results[p.name] = {
            name          = p.name,
            realm         = "",
            class         = p.class,
            isDead        = (math.random() > 0.9),
            isOnline      = (math.random() > 0.05),
            outOfRange    = false,
            hasFlask      = hasFlask,
            flaskName     = hasFlask and "Flask of Distilled Wisdom" or nil,
            hasBattle     = hasBattle,
            battleName    = hasBattle and "Elixir of Major Agility" or nil,
            hasGuardian   = hasGuardian,
            guardianName  = hasGuardian and "Elixir of Major Fortitude" or nil,
            hasFood       = (math.random() > 0.3),
            foodName      = "Well Fed",
            raidBuffs     = raidBuffs,
            raidBuffNames = raidBuffNames,
        }
        sorted[#sorted + 1] = p.name
    end

    table.sort(sorted)
    return results, sorted
end
