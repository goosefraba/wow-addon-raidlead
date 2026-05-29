----------------------------------------------------------------------
-- RaidLead — Core/DataStore.lua
-- SavedVariables management, defaults, migration from RaidSpy
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.SETTINGS_DEFAULTS = {
    announceStyle  = "buff",      -- "buff" | "category" | "player"
    trackFlasks    = true,
    trackFood      = true,
    trackRaidBuffs = true,
    autoScan       = true,
    debug          = false,
    compactMode    = false,
    bossLocked     = true,        -- protect boss configs from accidental changes
    -- Compact view options
    compactAlpha           = 0.92,  -- 0.3 .. 1.0 transparency in compact mode
    compactShowBoss        = true,
    compactShowHealers     = false,
    compactShowMisdirects  = false,
}

ns.FRAME_DEFAULTS = {
    point    = "CENTER",
    relPoint = "CENTER",
    x        = 0,
    y        = 0,
    width    = 580,
    height   = 400,
}

function ns.InitDB()
    -- Migrate from RaidSpy if needed
    if not RaidLeadDB and RaidSpyDB then
        ns.D("Migrating RaidSpyDB → RaidLeadDB")
        RaidLeadDB = {}
        if RaidSpyDB.settings then
            RaidLeadDB.settings = {}
            for k, v in pairs(RaidSpyDB.settings) do
                RaidLeadDB.settings[k] = v
            end
        end
        if RaidSpyDB.frame then
            RaidLeadDB.frame = {}
            for k, v in pairs(RaidSpyDB.frame) do
                RaidLeadDB.frame[k] = v
            end
        end
        RaidSpyDB = nil
        ns.P("Migrated settings from RaidSpy.")
    end

    if not RaidLeadDB then RaidLeadDB = {} end
    ns.db = RaidLeadDB

    -- Settings
    if not ns.db.settings then ns.db.settings = {} end
    for k, v in pairs(ns.SETTINGS_DEFAULTS) do
        if ns.db.settings[k] == nil then ns.db.settings[k] = v end
    end

    -- Frame position
    if not ns.db.frame then ns.db.frame = {} end
    for k, v in pairs(ns.FRAME_DEFAULTS) do
        if ns.db.frame[k] == nil then ns.db.frame[k] = v end
    end

    -- Boss templates
    if not ns.db.bossTemplates then ns.db.bossTemplates = {} end

    -- Always start locked on each reload as a safety measure -
    -- prevents accidental edits during raid prep.
    ns.db.settings.bossLocked = true

    -- Apply debug flag
    ns.DEBUG = ns.db.settings.debug or false
end
