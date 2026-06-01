----------------------------------------------------------------------
-- RaidLead - Modules/Versions.lua
-- Tracks the addon version reported by each peer in the raid.
-- Used to:
--   1) Warn the local player when a newer version exists in the group
--   2) Annotate per-player tooltips ("v1.0.0  (outdated)")
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local Versions = {}
ns.Versions = Versions

----------------------------------------------------------------------
-- Storage
----------------------------------------------------------------------
local function EnsureDB()
    if not ns.EnsureDB() then return false end
    if not ns.db.versions then ns.db.versions = {} end
    return true
end
Versions.EnsureDB = EnsureDB

-- Stamp our own version into the store so GetVersion(self) works.
-- Safe to call repeatedly; overwrites stale entries after upgrades.
function Versions.RecordSelf()
    if not EnsureDB() then return end
    local me = UnitName("player")
    if me and ns.VERSION then
        ns.db.versions[me] = ns.VERSION
    end
end

-- Returns the version reported for a player, or nil if unknown.
-- For the local player, falls back to ns.VERSION even if storage
-- hasn't been seeded yet (defense against load-order races).
function Versions.GetVersion(playerName)
    if not EnsureDB() then return nil end
    if not playerName or playerName == "" then return nil end
    local v = ns.db.versions[playerName]
    if v then return v end
    if playerName == UnitName("player") then
        return ns.VERSION
    end
    return nil
end

function Versions.GetAll()
    if not EnsureDB() then return {} end
    return ns.db.versions
end

-- Highest peer version we've ever seen (sticky across sessions).
function Versions.GetKnownLatest()
    if not EnsureDB() then return nil end
    return ns.db.knownLatestVersion
end

-- Compare an external version to ours.
--  -1 = older, 0 = same, 1 = newer, nil = unknown
function Versions.CompareToMine(v)
    if not v or v == "" then return nil end
    return ns.CompareVersions(v, ns.VERSION or "0.0.0")
end

-- True when we're behind any known peer.
function Versions.MineIsOutdated()
    local known = Versions.GetKnownLatest()
    if not known or known == "" then return false end
    return ns.CompareVersions(known, ns.VERSION or "0.0.0") > 0
end

----------------------------------------------------------------------
-- Internal: store a remote version, possibly update knownLatest +
-- print a one-shot chat warning the first time we discover we're behind.
----------------------------------------------------------------------
local function Store(playerName, version)
    if not EnsureDB() then return end
    if not playerName or playerName == "" then return end
    if not version or version == "" then return end

    ns.db.versions[playerName] = version

    local known = ns.db.knownLatestVersion or "0.0.0"
    if ns.CompareVersions(version, known) > 0 then
        ns.db.knownLatestVersion = version
        local mine = ns.VERSION or "0.0.0"
        if ns.CompareVersions(version, mine) > 0
           and not ns.db.knownLatestVersionAnnounced then
            ns.db.knownLatestVersionAnnounced = true
            ns.P("|cFFFFAA00A newer RaidLead version (v" .. version
                .. ") was seen from a peer.|r You're on v" .. mine .. ".")
        end
    end

    -- Trigger UI updates that surface version (banner, tooltips)
    if ns.UpdateVersionBanner then ns.UpdateVersionBanner() end
end

----------------------------------------------------------------------
-- Broadcast / request
----------------------------------------------------------------------

-- Broadcast our own version. Safe no-op when not in a group.
function Versions.BroadcastMine()
    if not ns.Comm then return end
    ns.Comm.Send("VER", ns.VERSION or "0.0.0")
end

-- Ask the group: "send me your versions." Each peer that has the addon
-- responds via the VER_REQ handler.
function Versions.RequestAll()
    if not ns.Comm then return end
    ns.Comm.Send("VER_REQ")
end

----------------------------------------------------------------------
-- Comm handlers
----------------------------------------------------------------------
if ns.Comm then
    ns.Comm.RegisterHandler("VER", function(parts, sender)
        local v = parts[2]
        Store(sender, v)
    end)

    ns.Comm.RegisterHandler("VER_REQ", function(parts, sender)
        -- Reply directly so we don't spam the raid channel
        if not sender or sender == "" then return end
        ns.Comm.Whisper(sender, "VER", ns.VERSION or "0.0.0")
    end)
end
