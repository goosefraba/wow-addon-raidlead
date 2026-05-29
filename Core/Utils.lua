----------------------------------------------------------------------
-- RaidLead — Core/Utils.lua
-- Shared constants, print helpers, class colors, utility functions
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.ADDON_NAME    = ADDON_NAME
ns.ADDON_VERSION = "1.2.7"
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

    return detected
end

----------------------------------------------------------------------
-- Auto-mark: apply raid target icons to enemies by name.
-- plan = { { iconIdx = 8, mob = "Krosh Firehand" }, ... }
-- Scans visible nameplates + the group's targets / mouseover / focus for
-- hostile units matching each plan entry's mob name and marks them.
-- Entries sharing a mob name (e.g. 5x "Hellfire Channeler") each consume
-- a distinct unit. Returns markedCount, missingNames (table).
----------------------------------------------------------------------
function ns.AutoMarkByPlan(plan)
    if type(plan) ~= "table" then return 0, {} end

    -- Gather unique hostile candidate units from every source we have.
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
