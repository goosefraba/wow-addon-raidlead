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
    compactBorder          = true,  -- draw a border around the compact panel
    compactShowBoss        = true,
    compactShowMarks       = false,
    compactShowHealers     = false,
    compactShowCooldowns   = false,
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

    -- Custom poll questions (lead-managed). Each entry:
    --   { question = "...", options = { "A", "B", ... }, multi = false }
    if not ns.db.customPolls then ns.db.customPolls = {} end

    -- Generic mark board: per raid icon, a player per role (tank/cc/...).
    if not ns.db.markBoard then ns.db.markBoard = {} end

    -- Sticky assignment memory keyed by mob name:
    --   ns.db.markMemory["Fel Handler"] = { tank="X", cc="Y", ... }
    -- so a detected mob auto-prefills its remembered assignees.
    if not ns.db.markMemory then ns.db.markMemory = {} end

    -- Past poll results, kept locally for whoever ran the poll (never
    -- broadcast). Each entry: { question, options = {...}, multi, counts =
    -- {...}, voterTotal, endedAt }. Newest first; capped in Modules/Polls.
    if not ns.db.pollHistory then ns.db.pollHistory = {} end

    -- Per-raid-buff tracking toggles, keyed by family key (motw/fort/...).
    -- Absent or true = tracked; false = hidden from the grid and never
    -- flagged as missing. Defaults to all tracked.
    if not ns.db.raidBuffTracking then ns.db.raidBuffTracking = {} end

    -- Remembered state of the launcher's "chat voting" checkbox (lets
    -- people without the addon vote by typing/whispering). Default on.
    if ns.db.pollChatVoting == nil then ns.db.pollChatVoting = true end

    -- Remembered state of the launcher's "auto-close after 30s" checkbox.
    -- Off by default: polls stay open until the lead ends them manually.
    if ns.db.pollAutoClose == nil then ns.db.pollAutoClose = false end

    -- Seed the built-in presets into the editable list exactly once. After
    -- this they're ordinary entries the lead can edit or delete; the
    -- pollsSeeded flag stops us re-adding ones they've removed.
    if not ns.db.pollsSeeded then
        ns.db.pollsSeeded = true
        for _, p in ipairs((ns.Polls and ns.Polls.PRESETS) or {}) do
            local opts = {}
            for i, o in ipairs(p.options) do opts[i] = o end
            ns.db.customPolls[#ns.db.customPolls + 1] = {
                question = p.question,
                options  = opts,
                multi    = false,
            }
        end
    end

    -- Always start locked on each reload as a safety measure -
    -- prevents accidental edits during raid prep.
    ns.db.settings.bossLocked = true

    -- Apply debug flag
    ns.DEBUG = ns.db.settings.debug or false
end
