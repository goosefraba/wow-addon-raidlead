----------------------------------------------------------------------
-- RaidLead — Modules/LootHistory.lua
-- Per-raid loot history: tracks epic+ loot events in raid instances,
-- grouped by run. Identifies items by ID so display works across locales.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local LootHistory = {}
ns.LootHistory = LootHistory

----------------------------------------------------------------------
-- DB helpers
----------------------------------------------------------------------
local function EnsureDB()
    if not ns.EnsureDB() then return false end
    if not ns.db.lootHistory then ns.db.lootHistory = { runs = {} } end
    if not ns.db.lootHistory.runs then ns.db.lootHistory.runs = {} end
    return true
end

----------------------------------------------------------------------
-- Run lifecycle
----------------------------------------------------------------------
local currentRunId = nil

-- One run per instance per day
local function MakeRunId(instanceMapID, startTime)
    return tostring(instanceMapID or 0) .. ":" .. math.floor((startTime or time()) / 86400)
end

function LootHistory.StartRun()
    if not EnsureDB() then return end
    local zoneName, instanceType, difficulty, _, _, _, _, instanceMapID = GetInstanceInfo()
    if instanceType ~= "raid" then return end

    local startTime = time()
    local runId = MakeRunId(instanceMapID, startTime)
    currentRunId = runId

    if not ns.db.lootHistory.runs[runId] then
        ns.db.lootHistory.runs[runId] = {
            instanceMapId = instanceMapID,
            instanceName  = zoneName or "Unknown",
            difficulty    = difficulty,
            startTime     = startTime,
            attendees     = {},
            loots         = {},
        }
        ns.D("LootHistory: started new run " .. runId .. " (" .. zoneName .. ")")
    else
        ns.D("LootHistory: resumed existing run " .. runId)
    end

    LootHistory.CaptureAttendees()
end

function LootHistory.EndRun()
    if not currentRunId or not EnsureDB() then return end
    local run = ns.db.lootHistory.runs[currentRunId]
    if run then run.endTime = time() end
    currentRunId = nil
end

function LootHistory.CaptureAttendees()
    if not currentRunId or not EnsureDB() then return end
    local run = ns.db.lootHistory.runs[currentRunId]
    if not run then return end

    -- Include the player themselves (with their class)
    local me = UnitName("player")
    if me then
        local _, classFile = UnitClass("player")
        run.attendees[me] = classFile or "UNKNOWN"
    end

    -- Then raid roster (TBC API). GetRaidRosterInfo returns at position 6
    -- the English class key (locale-proof).
    local n = (GetNumRaidMembers and GetNumRaidMembers()) or
              (GetNumGroupMembers and GetNumGroupMembers()) or 0
    for i = 1, n do
        if GetRaidRosterInfo then
            local name, _, _, _, _, classFile = GetRaidRosterInfo(i)
            if name then
                run.attendees[name] = classFile or "UNKNOWN"
            end
        end
    end
end

----------------------------------------------------------------------
-- Loot capture
----------------------------------------------------------------------
function LootHistory.AddLoot(player, itemId, itemLink, quality)
    if not EnsureDB() then return end
    -- Only track loot during an active run
    if not currentRunId then return end
    local run = ns.db.lootHistory.runs[currentRunId]
    if not run then return end

    -- Only epics+ (quality >= 4)
    if not quality or quality < 4 then return end
    if not itemId or not player then return end

    table.insert(run.loots, {
        time     = time(),
        player   = player,
        itemId   = itemId,
        itemLink = itemLink,
        quality  = quality,
    })
    ns.D("LootHistory: " .. player .. " got item " .. itemId)
end

----------------------------------------------------------------------
-- Query API (used by the UI)
----------------------------------------------------------------------

-- Returns array sorted by startTime DESCENDING (most recent first)
function LootHistory.GetRuns()
    if not EnsureDB() then return {} end
    local list = {}
    for runId, run in pairs(ns.db.lootHistory.runs) do
        list[#list + 1] = { id = runId, data = run }
    end
    table.sort(list, function(a, b)
        return (a.data.startTime or 0) > (b.data.startTime or 0)
    end)
    return list
end

function LootHistory.GetRun(runId)
    if not EnsureDB() then return nil end
    return ns.db.lootHistory.runs[runId]
end

-- Per-player totals across all runs (or filtered to a single instance)
function LootHistory.GetPerPlayerTotals(filterInstanceMapId)
    if not EnsureDB() then return {} end
    local totals = {}
    for _, run in pairs(ns.db.lootHistory.runs) do
        if not filterInstanceMapId or run.instanceMapId == filterInstanceMapId then
            for _, loot in ipairs(run.loots or {}) do
                if not totals[loot.player] then
                    totals[loot.player] = { count = 0, lastTime = 0, items = {} }
                end
                local t = totals[loot.player]
                t.count = t.count + 1
                if (loot.time or 0) > t.lastTime then t.lastTime = loot.time end
                t.items[#t.items + 1] = loot
            end
        end
    end
    local list = {}
    for player, info in pairs(totals) do
        list[#list + 1] = { name = player, info = info }
    end
    table.sort(list, function(a, b) return a.info.count > b.info.count end)
    return list
end

-- Aggregate attendance per player across all recorded runs.
-- Returns { { name=, runsAttended=, lastSeen=, totalRuns=, pct= }, ... }
-- sorted by attendance count desc, then alpha.
function LootHistory.GetPerPlayerAttendance(filterInstanceMapId)
    if not EnsureDB() then return {} end

    local totals = {}    -- name -> { runs, lastSeen }
    local totalRuns = 0

    for _, run in pairs(ns.db.lootHistory.runs) do
        if not filterInstanceMapId or run.instanceMapId == filterInstanceMapId then
            totalRuns = totalRuns + 1
            local ts = run.endTime or run.startTime or 0
            -- attendees is a name-keyed map ({ [name] = class }), so iterate
            -- with pairs over its keys (ipairs would skip everything).
            for name in pairs(run.attendees or {}) do
                local t = totals[name]
                if not t then
                    t = { runs = 0, lastSeen = 0 }
                    totals[name] = t
                end
                t.runs = t.runs + 1
                if ts > t.lastSeen then t.lastSeen = ts end
            end
        end
    end

    local list = {}
    for name, t in pairs(totals) do
        list[#list + 1] = {
            name         = name,
            runsAttended = t.runs,
            lastSeen     = t.lastSeen,
            totalRuns    = totalRuns,
            pct          = totalRuns > 0 and (t.runs / totalRuns * 100) or 0,
        }
    end
    table.sort(list, function(a, b)
        if a.runsAttended ~= b.runsAttended then return a.runsAttended > b.runsAttended end
        return a.name < b.name
    end)
    return list
end

-- Distinct instances we've seen (for the filter dropdown)
function LootHistory.GetInstances()
    if not EnsureDB() then return {} end
    local seen = {}
    local list = {}
    for _, run in pairs(ns.db.lootHistory.runs) do
        local key = run.instanceMapId
        if key and not seen[key] then
            seen[key] = true
            list[#list + 1] = { mapId = key, name = run.instanceName or "Unknown" }
        end
    end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    return list
end

----------------------------------------------------------------------
-- Backup / restore safety net. BackupRuns snapshots the REAL (non-mock)
-- runs into a separate slot so a later wipe/mock-load can be undone. The
-- snapshot survives reassignment of ns.db.lootHistory because it lives in
-- its own key and holds the run tables directly.
----------------------------------------------------------------------
function LootHistory.BackupRuns(reason)
    if not EnsureDB() then return end
    local snap, n = {}, 0
    for id, run in pairs(ns.db.lootHistory.runs) do
        if not LootHistory.IsMockRun(run) then
            snap[id] = run
            n = n + 1
        end
    end
    if n == 0 then return end   -- nothing real worth protecting
    ns.db.lootHistoryBackup = { runs = snap, savedAt = time(), reason = reason }
    ns.D("LootHistory: backed up " .. n .. " real run(s) (" .. tostring(reason) .. ").")
end

-- Merge any backed-up runs back into the live history (without clobbering
-- runs that already exist). Returns how many were restored.
function LootHistory.RestoreBackup()
    if not EnsureDB() then return 0 end
    local bk = ns.db.lootHistoryBackup
    if not (bk and bk.runs) then
        ns.P("|cFFFF8800No history backup found to restore.|r")
        return 0
    end
    local restored = 0
    for id, run in pairs(bk.runs) do
        if not ns.db.lootHistory.runs[id] then
            ns.db.lootHistory.runs[id] = run
            restored = restored + 1
        end
    end
    if ns.RefreshLootHistory then ns.RefreshLootHistory() end
    local whenStr = (bk.savedAt and bk.savedAt > 0)
        and date("%Y-%m-%d %H:%M", bk.savedAt) or "?"
    ns.P("Restored " .. restored .. " run(s) from backup (" .. whenStr .. ").")
    return restored
end

----------------------------------------------------------------------
-- Wipe
----------------------------------------------------------------------
function LootHistory.ClearAll()
    if not EnsureDB() then return end
    LootHistory.BackupRuns("before clear all")   -- recoverable via RestoreBackup
    ns.db.lootHistory = { runs = {} }
    currentRunId = nil
    ns.P("Cleared loot history. (Recover with |cFFFFCC00/raidlead restorehistory|r.)")
end

function LootHistory.DeleteRun(runId)
    if not EnsureDB() then return end
    if not ns.db.lootHistory.runs[runId] then return end
    ns.db.lootHistory.runs[runId] = nil
    if currentRunId == runId then currentRunId = nil end
    if ns.RefreshLootHistory then ns.RefreshLootHistory() end
end

-- Heuristic: is this run mock data? Mock runs come from LoadMockData and
-- have attendees drawn entirely from MOCK_PLAYERS (defined below). A real
-- raid will have actual character names.
function LootHistory.IsMockRun(run)
    if run.mock then return true end  -- explicit flag (future mock data)
    if not run.attendees then return false end

    -- Build a set of mock player names (lazy - declared in mock section below)
    -- Heuristic: if >= 80% of attendees match mock names, treat as mock
    local mockNames = LootHistory._mockPlayerNameSet
    if not mockNames then return false end

    local total, mockCount = 0, 0
    for name in pairs(run.attendees) do
        if name ~= UnitName("player") then  -- exclude the player themselves
            total = total + 1
            if mockNames[name] then mockCount = mockCount + 1 end
        end
    end
    if total == 0 then return false end
    return (mockCount / total) >= 0.8
end

function LootHistory.RemoveMockRuns()
    if not EnsureDB() then return 0 end
    local removed = 0
    for runId, run in pairs(ns.db.lootHistory.runs) do
        if LootHistory.IsMockRun(run) then
            ns.db.lootHistory.runs[runId] = nil
            removed = removed + 1
        end
    end
    if ns.RefreshLootHistory then ns.RefreshLootHistory() end
    return removed
end

----------------------------------------------------------------------
-- Event handling
----------------------------------------------------------------------
local frame = CreateFrame("Frame")

-- Some events don't exist in all client versions. Wrap registration so
-- one missing event doesn't crash the file load and prevent every later
-- function (including LoadMockData!) from being defined.
local function SafeRegister(f, eventName)
    local ok, err = pcall(f.RegisterEvent, f, eventName)
    if not ok then
        -- silent fallback - just skip events this client doesn't know
    end
end

SafeRegister(frame, "CHAT_MSG_LOOT")
SafeRegister(frame, "PLAYER_ENTERING_WORLD")
SafeRegister(frame, "GROUP_ROSTER_UPDATE")
SafeRegister(frame, "PARTY_MEMBERS_CHANGED")
SafeRegister(frame, "RAID_ROSTER_UPDATE")
SafeRegister(frame, "GET_ITEM_INFO_RECEIVED")

-- Pending items waiting for GetItemInfo to resolve quality/name
local pendingLootResolves = {}

local function TryAddLoot(player, itemLink)
    if not itemLink then return end
    local itemId = tonumber(itemLink:match("Hitem:(%d+):"))
    if not itemId then return end

    local _, _, quality = GetItemInfo(itemLink)
    if quality == nil then
        -- Async: WoW hasn't loaded item info yet. Queue and resolve later.
        pendingLootResolves[itemId] = pendingLootResolves[itemId] or {}
        table.insert(pendingLootResolves[itemId], {
            player = player, itemLink = itemLink, itemId = itemId, time = time(),
        })
        -- Force a lookup so GET_ITEM_INFO_RECEIVED fires
        GetItemInfo(itemId)
        return
    end

    if quality >= 4 then
        LootHistory.AddLoot(player, itemId, itemLink, quality)
        if ns.RefreshLootHistory then ns.RefreshLootHistory() end
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_LOOT" then
        local msg = ...
        if not msg or msg == "" then return end

        -- Extract the item link out of any locale-formatted loot message
        local itemLink = msg:match("(|c%x+|Hitem:.-|h.-|h|r)")
        if not itemLink then return end

        -- Resolve receiver: "You receive loot:" or "PlayerName receives loot:"
        local player = msg:match("^([^%s]+) receive") or msg:match("^([^%s]+) gets") or "You"
        if player == "You" then player = UnitName("player") end

        TryAddLoot(player, itemLink)

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemId = ...
        local pending = pendingLootResolves[itemId]
        if pending then
            pendingLootResolves[itemId] = nil
            local _, _, quality = GetItemInfo(itemId)
            for _, entry in ipairs(pending) do
                if quality and quality >= 4 then
                    LootHistory.AddLoot(entry.player, entry.itemId, entry.itemLink, quality)
                end
            end
        end
        -- Also refresh the History UI: icons/names for cold-cache items
        -- only become available once WoW finishes loading them.
        if ns.RefreshLootHistory then ns.RefreshLootHistory() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        local _, instanceType = GetInstanceInfo()
        if instanceType == "raid" then
            LootHistory.StartRun()
        else
            LootHistory.EndRun()
        end

    elseif event == "GROUP_ROSTER_UPDATE"
        or event == "PARTY_MEMBERS_CHANGED"
        or event == "RAID_ROSTER_UPDATE"
    then
        LootHistory.CaptureAttendees()
    end
end)

----------------------------------------------------------------------
-- Mock data generator (for solo testing)
----------------------------------------------------------------------

-- Realistic TBC epic item IDs from Karazhan / Gruul's Lair / Magtheridon's Lair.
-- GetItemInfo resolves these to localized names + links on the player's client.
local MOCK_LOOT_POOLS = {
    karazhan = {
        instanceMapId = 532,
        instanceName  = "Karazhan",
        items = {
            28780,  -- Wand of Prismatic Focus
            29156,  -- Cowl of Defiance
            29349,  -- Talisman of Nightbane
            29360,  -- The Lightning Capacitor
            29373,  -- Mass of McGowan
            28736,  -- Beastmaw Pauldrons
            28818,  -- Hammer of the Penitent
            28785,  -- Bone-Inlaid Legguards
            29013,  -- Shoulderpads of Vehemence
            28752,  -- Steelhawk Crossbow
            28632,  -- Pillar of Ferocity
            29251,  -- Headdress of the Tides
        },
    },
    gruul = {
        instanceMapId = 565,
        instanceName  = "Gruul's Lair",
        items = {
            28826,  -- Aldori Legacy Defender
            29022,  -- Bladespire Warbands
            29024,  -- Crown of Endless Knowledge
            29093,  -- Gruul's Longspear
            29094,  -- Slumber Sand
            28825,  -- Maulgar's Warhelm
            28828,  -- Cowl of Beastly Rage
        },
    },
    mag = {
        instanceMapId = 544,
        instanceName  = "Magtheridon's Lair",
        items = {
            29302,  -- Glaive of the Pit
            29303,  -- Eredar Wand of Obliteration
            29304,  -- Karaborian Talisman
            29305,  -- Aegis of the Vindicator
            29306,  -- Crystalheart Pulse-Staff
        },
    },
}

-- Mock players with class info (matches Utils.lua mock raid roster)
local MOCK_PLAYERS = {
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

-- Expose the mock player name set so IsMockRun can identify mock runs
-- (those with attendees drawn from this list).
LootHistory._mockPlayerNameSet = {}
for _, p in ipairs(MOCK_PLAYERS) do
    LootHistory._mockPlayerNameSet[p.name] = true
end

local function RandomChoice(t)
    return t[math.random(1, #t)]
end

local function PickN(source, n)
    -- Pick n distinct from source
    local copy = {}
    for _, v in ipairs(source) do copy[#copy + 1] = v end
    -- shuffle
    for i = #copy, 2, -1 do
        local j = math.random(1, i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    local picked = {}
    for i = 1, math.min(n, #copy) do picked[i] = copy[i] end
    return picked
end

local function MakeMockRun(pool, dayOffset, attendeeCount, lootCount)
    local startTime = time() - dayOffset * 86400 + math.random(-3600, 3600)
    -- Prefix mock ids so they can NEVER collide with (and overwrite) a real
    -- run that happens to share the same instance/day.
    local runId = "mock:" .. pool.instanceMapId .. ":" .. dayOffset

    -- Pick attendees (each a {name=,class=} record) and store with class
    local attendees = {}
    local attendeesArr = {}
    for _, p in ipairs(PickN(MOCK_PLAYERS, attendeeCount)) do
        attendees[p.name] = p.class
        attendeesArr[#attendeesArr + 1] = p.name
    end

    -- Always include the current player so they show up in their own history
    local me = UnitName("player")
    if me and not attendees[me] then
        local _, classFile = UnitClass("player")
        attendees[me] = classFile or "UNKNOWN"
        attendeesArr[#attendeesArr + 1] = me
    end

    local loots = {}
    for i = 1, lootCount do
        local itemId = RandomChoice(pool.items)
        local player = RandomChoice(attendeesArr)
        local _, link, quality = GetItemInfo(itemId)
        loots[#loots + 1] = {
            time     = startTime + i * 600 + math.random(0, 300),
            player   = player,
            itemId   = itemId,
            itemLink = link or ("|cffa335ee|Hitem:" .. itemId .. ":0:0:0:0:0:0:0|h[Item " .. itemId .. "]|h|r"),
            quality  = quality or 4,
        }
    end

    return runId, {
        instanceMapId = pool.instanceMapId,
        instanceName  = pool.instanceName,
        difficulty    = 1,
        startTime     = startTime,
        endTime       = startTime + 3 * 3600,  -- ~3-hour run
        attendees     = attendees,
        loots         = loots,
        mock          = true,  -- explicit flag for reliable cleanup later
    }
end

function LootHistory.LoadMockData()
    if not EnsureDB() then return end

    -- NON-DESTRUCTIVE: never wipe real history. Back it up first, then drop
    -- only pre-existing mock runs and add fresh ones ALONGSIDE real runs.
    -- (Previously this did `ns.db.lootHistory = { runs = {} }`, which
    -- destroyed real raid history when someone ran /raidlead mock.)
    LootHistory.BackupRuns("before mock load")
    LootHistory.RemoveMockRuns()

    local mockRuns = {
        { pool = MOCK_LOOT_POOLS.karazhan, dayOffset = 0,  attendees = 10, loots = 5 },
        { pool = MOCK_LOOT_POOLS.gruul,    dayOffset = 2,  attendees = 22, loots = 3 },
        { pool = MOCK_LOOT_POOLS.karazhan, dayOffset = 5,  attendees = 10, loots = 4 },
        { pool = MOCK_LOOT_POOLS.mag,      dayOffset = 8,  attendees = 25, loots = 2 },
        { pool = MOCK_LOOT_POOLS.karazhan, dayOffset = 12, attendees = 9,  loots = 6 },
    }

    for _, cfg in ipairs(mockRuns) do
        local id, runData = MakeMockRun(cfg.pool, cfg.dayOffset, cfg.attendees, cfg.loots)
        ns.db.lootHistory.runs[id] = runData
    end

    local count = 0
    for _ in pairs(ns.db.lootHistory.runs) do count = count + 1 end
    ns.P("Loaded mock loot history (" .. count .. " runs).")
    if ns.RefreshLootHistory then ns.RefreshLootHistory() end
end
