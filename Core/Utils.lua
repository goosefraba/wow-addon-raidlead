----------------------------------------------------------------------
-- RaidLead — Core/Utils.lua
-- Shared constants, print helpers, class colors, utility functions
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.ADDON_NAME    = ADDON_NAME
ns.ADDON_VERSION = "1.1.0"
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
