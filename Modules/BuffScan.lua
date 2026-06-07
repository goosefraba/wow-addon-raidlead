----------------------------------------------------------------------
-- RaidLead — Modules/BuffScan.lua
-- Buff/consumable scanning engine (ported from RaidSpy)
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BuffScan = {}
ns.BuffScan = BuffScan

----------------------------------------------------------------------
-- Buff data shortcuts
----------------------------------------------------------------------
local BD             = RaidSpyBuffs
local buffLookup     = BD.buffLookup
local raidBuffLookup = BD.raidBuffLookup

-- Ordered list of raid-buff family keys for column display
ns.RAID_BUFF_ORDER = {
    "motw", "fort", "ai", "spirit", "shadow",
    "kings", "might", "wisdom", "salvation",
    "battleShout", "commandingShout", "trueshotAura",
}

-- Per-buff tracking. Untracked buffs are hidden from the grid and never
-- flagged as missing. Defaults to tracked when no preference is stored.
function ns.IsRaidBuffTracked(fk)
    local t = ns.db and ns.db.raidBuffTracking
    return not (t and t[fk] == false)
end

function ns.SetRaidBuffTracked(fk, tracked)
    if not ns.db then return end
    ns.db.raidBuffTracking = ns.db.raidBuffTracking or {}
    ns.db.raidBuffTracking[fk] = tracked and true or false
end

----------------------------------------------------------------------
-- Scan state
----------------------------------------------------------------------
BuffScan.scanResults  = {}   -- [playerName] = { ... }
BuffScan.scanSorted   = {}   -- sorted keys list
BuffScan.scanTime     = nil

----------------------------------------------------------------------
-- Consumable labels
----------------------------------------------------------------------
BuffScan.CONSUMABLE_LABELS = { "Flask/Elixirs", "Battle Elixir", "Guardian Elixir", "Food", "Weapon Oil/Stone" }

----------------------------------------------------------------------
-- Scan a single unit
----------------------------------------------------------------------
function BuffScan.ScanUnit(unit)
    if not UnitExists(unit) then return nil end

    local name, realm = UnitName(unit)
    if not name or name == "Unknown" then return nil end

    local _, engClass = UnitClass(unit)
    local isDead      = UnitIsDeadOrGhost(unit)
    local isOnline    = UnitIsConnected(unit)

    -- Collect all buff names on this unit
    local buffSet = {}
    local buffCount = 0
    for i = 1, 40 do
        local buffName = UnitBuff(unit, i)
        if not buffName then break end
        buffSet[buffName] = true
        buffCount = buffCount + 1
    end

    -- Determine out-of-range: no buffs at all, alive, online
    local outOfRange = (buffCount == 0 and not isDead and isOnline)

    -- Flask / Elixir check
    local hasFlask, hasFlaskName        = false, nil
    local hasBattle, hasBattleName      = false, nil
    local hasGuardian, hasGuardianName  = false, nil

    for buffName in pairs(buffSet) do
        local cat = buffLookup[buffName]
        if cat == "flask" then
            hasFlask = true
            hasFlaskName = buffName
        elseif cat == "battleElixir" then
            hasBattle = true
            hasBattleName = buffName
        elseif cat == "guardianElixir" then
            hasGuardian = true
            hasGuardianName = buffName
        end
    end

    -- Food check
    local hasFood, hasFoodName = false, nil
    for buffName in pairs(buffSet) do
        if buffLookup[buffName] == "food" then
            hasFood = true
            hasFoodName = buffName
            break
        end
    end

    -- Raid buff check
    local raidBuffs = {}
    local raidBuffNames = {}
    for _, familyKey in ipairs(ns.RAID_BUFF_ORDER) do
        raidBuffs[familyKey] = false
        local family = BD.raidBuffs[familyKey]
        if family then
            for _, bName in ipairs(family.buffs) do
                if buffSet[bName] then
                    raidBuffs[familyKey] = true
                    raidBuffNames[familyKey] = bName
                    break
                end
            end
        end
    end

    return {
        name          = name,
        realm         = realm or "",
        class         = engClass or "UNKNOWN",
        isDead        = isDead,
        isOnline      = isOnline,
        outOfRange    = outOfRange,
        hasFlask      = hasFlask,
        flaskName     = hasFlaskName,
        hasBattle     = hasBattle,
        battleName    = hasBattleName,
        hasGuardian   = hasGuardian,
        guardianName  = hasGuardianName,
        hasFood       = hasFood,
        foodName      = hasFoodName,
        raidBuffs     = raidBuffs,
        raidBuffNames = raidBuffNames,
    }
end

----------------------------------------------------------------------
-- Missing buff checks
----------------------------------------------------------------------
function BuffScan.GetMissingConsumables(r)
    if not r or r.outOfRange or r.isDead or not r.isOnline then return {} end
    local s = ns.db and ns.db.settings or ns.SETTINGS_DEFAULTS
    local missing = {}
    if s.trackFlasks then
        if not r.hasFlask and not (r.hasBattle and r.hasGuardian) then
            if not r.hasFlask and not r.hasBattle and not r.hasGuardian then
                missing[#missing + 1] = "Flask/Elixirs"
            elseif r.hasBattle and not r.hasGuardian then
                missing[#missing + 1] = "Guardian Elixir"
            elseif r.hasGuardian and not r.hasBattle then
                missing[#missing + 1] = "Battle Elixir"
            end
        end
    end
    if s.trackFood then
        if not r.hasFood then
            missing[#missing + 1] = "Food"
        end
    end
    -- Weapon oils/stones are self-reported (see WeaponEnchant.lua). Only
    -- flag a player we actually have a report for; unknown peers (no addon)
    -- are never falsely marked missing.
    if s.trackWeaponEnchant and ns.WeaponEnchant then
        local rep = ns.WeaponEnchant.Get(r.name)
        if rep and ns.WeaponEnchant.IsMissing(rep) then
            missing[#missing + 1] = "Weapon Oil/Stone"
        end
    end
    return missing
end

function BuffScan.GetMissingRaidBuffs(r)
    if not r or r.outOfRange or r.isDead or not r.isOnline then return {} end
    local rb = r.raidBuffs or {}   -- guard: partial/comm records may lack it
    local missing = {}
    for _, fk in ipairs(ns.RAID_BUFF_ORDER) do
        if ns.IsRaidBuffTracked(fk) and not rb[fk] then
            local family = BD.raidBuffs[fk]
            if family then
                missing[#missing + 1] = family.label
            end
        end
    end
    return missing
end

-- Combined missing list = consumables + raid buffs (honoring track* flags).
function BuffScan.GetMissing(r)
    local missing = BuffScan.GetMissingConsumables(r)
    local s = ns.db and ns.db.settings or ns.SETTINGS_DEFAULTS
    if s.trackRaidBuffs then
        for _, label in ipairs(BuffScan.GetMissingRaidBuffs(r)) do
            missing[#missing + 1] = label
        end
    end
    return missing
end

----------------------------------------------------------------------
-- Scan group
----------------------------------------------------------------------
function BuffScan.ScanGroup()
    ns.D("ScanGroup called")
    local units, groupType = ns.BuildUnitList()
    BuffScan.scanResults = {}
    BuffScan.scanSorted  = {}
    BuffScan.scanTime    = ns.Timestamp()

    if groupType == "solo" then
        ns.D("solo — skipping scan")
        if ns.RefreshUI then ns.RefreshUI() end
        return
    end

    for _, unit in ipairs(units) do
        local result = BuffScan.ScanUnit(unit)
        if result then
            BuffScan.scanResults[result.name] = result
            BuffScan.scanSorted[#BuffScan.scanSorted + 1] = result.name
        end
    end

    -- Refresh our own weapon-enchant self-report alongside the buff scan
    -- (other players' reports arrive via WeaponEnchant comm).
    if ns.WeaponEnchant and ns.WeaponEnchant.ScanSelf then
        ns.WeaponEnchant.ScanSelf()
    end

    table.sort(BuffScan.scanSorted)
    ns.D("scanned " .. #BuffScan.scanSorted .. " players")
    if ns.RefreshUI then ns.RefreshUI() end
end

-- Load mock data for solo testing
function BuffScan.LoadMockData()
    local results, sorted = ns.GenerateMockRaid()
    BuffScan.scanResults = results
    BuffScan.scanSorted  = sorted
    BuffScan.scanTime    = ns.Timestamp()
    ns.P("Loaded mock data (" .. #sorted .. " players).")
    if ns.RefreshUI then ns.RefreshUI() end
end

-- Debounced auto-scan
local scanTimer = nil
function BuffScan.DebouncedScan()
    if scanTimer then return end
    scanTimer = true
    C_Timer.After(1.5, function()
        scanTimer = nil
        if ns.db and ns.db.settings and ns.db.settings.autoScan then
            BuffScan.ScanGroup()
        end
    end)
end

----------------------------------------------------------------------
-- Announce helpers
----------------------------------------------------------------------
function BuffScan.GetAnnounceChannel()
    local gt = ns.GetGroupType()
    if gt == "raid"  then return "RAID" end
    if gt == "party" then return "PARTY" end
    return nil
end

function BuffScan.BuildAnnounceByCat()
    local catPlayers = {}
    for _, name in ipairs(BuffScan.scanSorted) do
        local r = BuffScan.scanResults[name]
        if r and not r.outOfRange and not r.isDead and r.isOnline then
            local missing = BuffScan.GetMissing(r)
            for _, label in ipairs(missing) do
                if not catPlayers[label] then catPlayers[label] = {} end
                catPlayers[label][#catPlayers[label] + 1] = name
            end
        end
    end
    return catPlayers
end

function BuffScan.BuildAnnounceByPlayer()
    local lines = {}
    for _, name in ipairs(BuffScan.scanSorted) do
        local r = BuffScan.scanResults[name]
        if r and not r.outOfRange and not r.isDead and r.isOnline then
            local missing = BuffScan.GetMissing(r)
            if #missing > 0 then
                lines[#lines + 1] = { name = name, missing = missing }
            end
        end
    end
    return lines
end

----------------------------------------------------------------------
-- Announce
----------------------------------------------------------------------
local ANNOUNCE_HEADERS = {
    all         = "[RaidLead] Buff Check:",
    consumables = "[RaidLead] Consumable Check:",
    raidbuffs   = "[RaidLead] Raid Buff Check:",
}

local function Send(msg, channel)
    -- "PREVIEW" prints locally (only you); anything else is real chat.
    -- SendChatMessage rejects the '|' escape char, so strip it.
    if channel and channel ~= "PREVIEW" then
        SendChatMessage((msg:gsub("|", "")), channel)
    else
        ns.P("|cFF88CCFF[preview]|r " .. msg)
    end
end

function BuffScan.Announce(channel, mode)
    channel = channel or BuffScan.GetAnnounceChannel()
    if not channel then
        ns.P("You are not in a group or raid.")
        return
    end

    -- Broadcasting to the group is leader/assist-gated (party: anyone).
    if channel ~= "PREVIEW" and ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can announce to the group.|r")
        return
    end

    if #BuffScan.scanSorted == 0 then
        ns.P("No scan data. Use /raidlead scan first.")
        return
    end

    mode = mode or "all"
    local s = ns.db and ns.db.settings or ns.SETTINGS_DEFAULTS
    local style = s.announceStyle or "buff"
    local CHANNEL_NAMES = { RAID = "raid", PARTY = "party" }
    ns.P("Announcing to " .. (CHANNEL_NAMES[channel] or channel) .. "...")
    Send(ANNOUNCE_HEADERS[mode] or ANNOUNCE_HEADERS.all, channel)

    -- Build per-buff map
    local function BuildBuffMap()
        local catPlayers = {}
        for _, name in ipairs(BuffScan.scanSorted) do
            local r = BuffScan.scanResults[name]
            if r and not r.outOfRange and not r.isDead and r.isOnline then
                local missing
                if mode == "consumables" then
                    missing = BuffScan.GetMissingConsumables(r)
                elseif mode == "raidbuffs" then
                    missing = BuffScan.GetMissingRaidBuffs(r)
                else
                    missing = BuffScan.GetMissing(r)
                end
                for _, label in ipairs(missing) do
                    if not catPlayers[label] then catPlayers[label] = {} end
                    catPlayers[label][#catPlayers[label] + 1] = name
                end
            end
        end
        return catPlayers
    end

    if style == "buff" then
        local catPlayers = BuildBuffMap()
        local anyMissing = false
        if mode ~= "raidbuffs" then
            for _, label in ipairs(BuffScan.CONSUMABLE_LABELS) do
                if catPlayers[label] then
                    anyMissing = true
                    Send("  " .. label .. ": " .. table.concat(catPlayers[label], ", "), channel)
                end
            end
        end
        if mode ~= "consumables" then
            for _, fk in ipairs(ns.RAID_BUFF_ORDER) do
                local family = BD.raidBuffs[fk]
                if family and catPlayers[family.label] then
                    anyMissing = true
                    Send("  " .. family.label .. ": " .. table.concat(catPlayers[family.label], ", "), channel)
                end
            end
        end
        if not anyMissing then Send("  Everyone is good!", channel) end

    elseif style == "category" then
        local catPlayers = BuildBuffMap()
        local consumableNames, raidBuffNames = {}, {}
        if mode ~= "raidbuffs" then
            for _, label in ipairs(BuffScan.CONSUMABLE_LABELS) do
                if catPlayers[label] then
                    for _, n in ipairs(catPlayers[label]) do
                        consumableNames[n] = consumableNames[n] or {}
                        consumableNames[n][#consumableNames[n] + 1] = label
                    end
                end
            end
        end
        if mode ~= "consumables" then
            for _, fk in ipairs(ns.RAID_BUFF_ORDER) do
                local family = BD.raidBuffs[fk]
                if family and catPlayers[family.label] then
                    for _, n in ipairs(catPlayers[family.label]) do
                        raidBuffNames[n] = raidBuffNames[n] or {}
                        raidBuffNames[n][#raidBuffNames[n] + 1] = family.label
                    end
                end
            end
        end
        local anyMissing = false
        if mode ~= "raidbuffs" and next(consumableNames) then
            anyMissing = true
            Send("  -- Consumables --", channel)
            for _, name in ipairs(BuffScan.scanSorted) do
                if consumableNames[name] then
                    Send("  " .. name .. ": " .. table.concat(consumableNames[name], ", "), channel)
                end
            end
        end
        if mode ~= "consumables" and next(raidBuffNames) then
            anyMissing = true
            Send("  -- Raid Buffs --", channel)
            for _, name in ipairs(BuffScan.scanSorted) do
                if raidBuffNames[name] then
                    Send("  " .. name .. ": " .. table.concat(raidBuffNames[name], ", "), channel)
                end
            end
        end
        if not anyMissing then Send("  Everyone is good!", channel) end

    else
        -- By player
        local anyMissing = false
        for _, name in ipairs(BuffScan.scanSorted) do
            local r = BuffScan.scanResults[name]
            if r and not r.outOfRange and not r.isDead and r.isOnline then
                local missing
                if mode == "consumables" then
                    missing = BuffScan.GetMissingConsumables(r)
                elseif mode == "raidbuffs" then
                    missing = BuffScan.GetMissingRaidBuffs(r)
                else
                    missing = BuffScan.GetMissing(r)
                end
                if #missing > 0 then
                    anyMissing = true
                    Send("  " .. name .. ": " .. table.concat(missing, ", "), channel)
                end
            end
        end
        if not anyMissing then Send("  Everyone is good!", channel) end
    end
end

function BuffScan.WhisperMissing(playerName)
    local r = BuffScan.scanResults[playerName]
    if not r then
        ns.P("No scan data for " .. tostring(playerName))
        return
    end
    local missing = BuffScan.GetMissing(r)
    if #missing == 0 then
        ns.P(playerName .. " is fully buffed.")
        return
    end
    local msg = "[RaidLead] You are missing: " .. table.concat(missing, ", ")
    SendChatMessage((msg:gsub("|", "")), "WHISPER", nil, playerName)
    ns.P("Whispered " .. playerName .. ".")
end

----------------------------------------------------------------------
-- Nudge: ping players missing consumables (flask / elixirs / food).
-- These are the player's own responsibility, so we target them directly
-- rather than spamming the whole raid.
----------------------------------------------------------------------
function BuffScan.BuildConsumableNudges()
    local out = {}
    for _, name in ipairs(BuffScan.scanSorted) do
        local r = BuffScan.scanResults[name]
        local missing = r and BuffScan.GetMissingConsumables(r) or {}
        if #missing > 0 then
            out[#out + 1] = { name = name, missing = missing }
        end
    end
    return out
end

-- Whisper each player who is missing a consumable.
function BuffScan.NudgeWhisper()
    if ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can nudge the group.|r")
        return
    end
    if #BuffScan.scanSorted == 0 then
        ns.P("No scan data. Use /raidlead scan first.")
        return
    end
    local nudges = BuffScan.BuildConsumableNudges()
    if #nudges == 0 then
        ns.P("|cFF66CC66Everyone has their consumables.|r")
        return
    end
    for _, n in ipairs(nudges) do
        local msg = "[RaidLead] Before pull, please grab: " .. table.concat(n.missing, ", ")
        SendChatMessage((msg:gsub("|", "")), "WHISPER", nil, n.name)
    end
    ns.P("Nudged " .. #nudges .. " player(s) about missing consumables.")
end

-- Post a single grouped consumable reminder to raid/party chat.
function BuffScan.NudgeCallout(channel)
    if ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can nudge the group.|r")
        return
    end
    channel = channel or BuffScan.GetAnnounceChannel()
    if not channel then ns.P("You are not in a group or raid."); return end
    if #BuffScan.scanSorted == 0 then ns.P("No scan data. Use /raidlead scan first."); return end

    local cat = {}
    for _, name in ipairs(BuffScan.scanSorted) do
        local r = BuffScan.scanResults[name]
        for _, label in ipairs(r and BuffScan.GetMissingConsumables(r) or {}) do
            cat[label] = cat[label] or {}
            cat[label][#cat[label] + 1] = name
        end
    end

    local lines = {}
    for _, label in ipairs(BuffScan.CONSUMABLE_LABELS) do
        if cat[label] then
            lines[#lines + 1] = "Missing " .. label .. ": " .. table.concat(cat[label], ", ")
        end
    end
    if #lines == 0 then ns.P("|cFF66CC66Everyone has their consumables.|r"); return end

    table.insert(lines, 1, "[RaidLead] Consumable reminder:")
    ns.BossTemplates.SendLines(lines, channel)
end
