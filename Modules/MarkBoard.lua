----------------------------------------------------------------------
-- RaidLead — Modules/MarkBoard.lua
-- Generic "mark board": each of the 8 raid icons is a unit of pull
-- coordination carrying one player per role (Tank / CC / Interrupt).
-- Pairs with the marking tools (Mark Next, Quick-Mark All, Scan) on the
-- Marks tab. Independent of boss templates — this is the trash-pull tool.
--
-- Storage:  ns.db.markBoard[iconIdx] = { mob = "...", tank=, cc=, interrupt= }
-- Comm:     MARK_SET <icon> <roleKey> <player>   ·   MARK_CLEAR
-- The detected mob name is local (derived from live raid markers via
-- ScanMarkedMobs); only role assignments are broadcast.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local MarkBoard = {}
ns.MarkBoard = MarkBoard

-- Role columns. `classes` filters the player dropdown to capable classes.
-- Adding a role here adds a column to every row automatically.
MarkBoard.ROLES = {
    { key = "tank",      label = "Tank",      classes = { WARRIOR = true, DRUID = true, PALADIN = true } },
    { key = "cc",        label = "CC",        classes = { MAGE = true, WARLOCK = true } },
    { key = "interrupt", label = "Interrupt", classes = { WARRIOR = true, ROGUE = true, SHAMAN = true, MAGE = true } },
}

local function RoleDef(roleKey)
    for _, r in ipairs(MarkBoard.ROLES) do
        if r.key == roleKey then return r end
    end
    return nil
end
MarkBoard.RoleDef = RoleDef

MarkBoard._suppressBroadcast = false

----------------------------------------------------------------------
-- Storage
----------------------------------------------------------------------
local function EnsureDB()
    if not ns.db then
        if RaidLeadDB then ns.db = RaidLeadDB
        elseif ns.InitDB then ns.InitDB() end
    end
    if not ns.db then return false end
    if not ns.db.markBoard then ns.db.markBoard = {} end  -- [icon] = { mob, tank, cc, interrupt }
    return true
end
MarkBoard.EnsureDB = EnsureDB

local function isEmpty(rec)
    if not rec then return true end
    if rec.mob and rec.mob ~= "" then return false end
    for _, r in ipairs(MarkBoard.ROLES) do
        if rec[r.key] and rec[r.key] ~= "" then return false end
    end
    return true
end

function MarkBoard.Get(icon)
    if not EnsureDB() then return nil end
    return ns.db.markBoard[icon]
end

function MarkBoard.GetRole(icon, roleKey)
    local rec = MarkBoard.Get(icon)
    return rec and rec[roleKey] or nil
end

function MarkBoard.SetRole(icon, roleKey, player)
    if not EnsureDB() then return end
    if not icon or not roleKey then return end
    if player == "" then player = nil end

    local rec = ns.db.markBoard[icon] or {}
    local mob = rec.mob
    rec[roleKey] = player
    ns.db.markBoard[icon] = (not isEmpty(rec)) and rec or nil

    -- Remember this assignment against the mob's name so it sticks across
    -- pulls ("this tank always takes this mob"). Only for local edits — we
    -- don't want sync traffic from peers rewriting our memory.
    if not MarkBoard._suppressBroadcast and mob and mob ~= "" then
        MarkBoard.Remember(mob, roleKey, player)
    end

    if not MarkBoard._suppressBroadcast and ns.Comm then
        ns.Comm.Send("MARK_SET", tostring(icon), roleKey, player or "")
    end
end

----------------------------------------------------------------------
-- Sticky memory (keyed by mob name)
----------------------------------------------------------------------
function MarkBoard.Remember(mob, roleKey, player)
    if not EnsureDB() then return end
    if not mob or mob == "" then return end
    ns.db.markMemory = ns.db.markMemory or {}
    if player and player ~= "" then
        local mem = ns.db.markMemory[mob] or {}
        mem[roleKey] = player
        ns.db.markMemory[mob] = mem
    else
        local mem = ns.db.markMemory[mob]
        if mem then
            mem[roleKey] = nil
            local any = false
            for _, r in ipairs(MarkBoard.ROLES) do if mem[r.key] then any = true end end
            if not any then ns.db.markMemory[mob] = nil end
        end
    end
end

-- Pre-fill an icon's empty role slots from the remembered assignees for
-- its detected mob. Lead-side only (it broadcasts the prefill).
function MarkBoard.ApplyMemory(icon)
    if not EnsureDB() then return end
    local rec = ns.db.markBoard[icon]
    if not rec or not rec.mob then return end
    local mem = ns.db.markMemory and ns.db.markMemory[rec.mob]
    if not mem then return end
    for _, r in ipairs(MarkBoard.ROLES) do
        if (not rec[r.key]) and mem[r.key] then
            MarkBoard.SetRole(icon, r.key, mem[r.key])
        end
    end
end

-- Detected mob name is local only (each client reads the live markers).
function MarkBoard.SetDetected(icon, name)
    if not EnsureDB() then return end
    if name == "" then name = nil end
    local rec = ns.db.markBoard[icon] or {}
    rec.mob = name
    ns.db.markBoard[icon] = (not isEmpty(rec)) and rec or nil
end

function MarkBoard.ClearAll()
    if not EnsureDB() then return end
    ns.db.markBoard = {}
    ns.P("Cleared the mark board.")
    if not MarkBoard._suppressBroadcast and ns.Comm then
        ns.Comm.Send("MARK_CLEAR")
    end
end

-- Drop just the role assignees (keeps the detected mobs / marks shown).
function MarkBoard.ClearAssignments()
    if not EnsureDB() then return end
    for icon = 1, 8 do
        local rec = ns.db.markBoard[icon]
        if rec then
            for _, r in ipairs(MarkBoard.ROLES) do rec[r.key] = nil end
            ns.db.markBoard[icon] = (not isEmpty(rec)) and rec or nil
        end
    end
    ns.P("Cleared mark assignments.")
    if not MarkBoard._suppressBroadcast and ns.Comm then
        ns.Comm.Send("MARK_CLEAR")
    end
end

-- Drop just the detected mob names (keeps role assignments). Used after
-- clearing the in-game raid markers. Local only.
function MarkBoard.ClearDetected()
    if not EnsureDB() then return end
    for icon = 1, 8 do
        local rec = ns.db.markBoard[icon]
        if rec then
            rec.mob = nil
            ns.db.markBoard[icon] = (not isEmpty(rec)) and rec or nil
        end
    end
end

-- Refresh detected mob names from the live raid markers. Preserves role
-- assignments. Returns the count of icons with a detected mob.
function MarkBoard.ScanAndUpdate()
    if not EnsureDB() then return 0 end
    if not ns.ScanMarkedMobs then return 0 end
    local ok, detected = pcall(ns.ScanMarkedMobs)
    if not ok or type(detected) ~= "table" then return 0 end

    local found = 0
    for icon = 1, 8 do
        local info = detected[icon]
        if info and info.name then
            MarkBoard.SetDetected(icon, info.name)
            found = found + 1
        end
    end

    -- Auto-prefill remembered assignees for detected mobs (lead only, since
    -- ApplyMemory broadcasts the assignments).
    if (not ns.CanEdit) or ns.CanEdit() then
        for icon = 1, 8 do MarkBoard.ApplyMemory(icon) end
    end
    return found
end

-- Shares the boss-config lock / edit permission.
function MarkBoard.IsLocked()
    return ns.BossTemplates and ns.BossTemplates.IsLocked() or false
end

----------------------------------------------------------------------
-- Announce + whisper builders
----------------------------------------------------------------------
function MarkBoard.BuildAnnounceLines()
    if not EnsureDB() then return { "== Marks ==", "(nothing assigned)" } end
    local lines = { "== Marks ==" }
    local any = false
    for icon = 1, 8 do
        local rec = ns.db.markBoard[icon]
        if rec then
            local parts = {}
            for _, r in ipairs(MarkBoard.ROLES) do
                if rec[r.key] then parts[#parts + 1] = r.label .. " " .. rec[r.key] end
            end
            if #parts > 0 then
                local iconStr = ns.GetRaidIconText and ns.GetRaidIconText(icon) or ""
                local mob = rec.mob and (" (" .. rec.mob .. ")") or ""
                lines[#lines + 1] = iconStr .. mob .. ": " .. table.concat(parts, ", ")
                any = true
            end
        end
    end
    if not any then lines[#lines + 1] = "(nothing assigned)" end
    return lines
end

-- Compact one-line-per-icon view for the live overlay.
function MarkBoard.BuildCompactText()
    if not EnsureDB() then return "" end
    local lines = {}
    for icon = 1, 8 do
        local rec = ns.db.markBoard[icon]
        if rec then
            local parts = {}
            for _, r in ipairs(MarkBoard.ROLES) do
                if rec[r.key] then parts[#parts + 1] = r.label:sub(1, 1) .. ":" .. rec[r.key] end
            end
            if #parts > 0 then
                local tex = ns.GetRaidIconTexture(icon)
                local prefix = tex and ("|T" .. tex .. ":14|t ") or ""
                lines[#lines + 1] = prefix .. table.concat(parts, "  ")
            end
        end
    end
    return table.concat(lines, "\n")
end

-- Per-recipient whisper list ({ name, msg }), combining multiple jobs.
function MarkBoard.BuildWhispers()
    if not EnsureDB() then return {} end
    local byName, order = {}, {}
    local function add(name, part)
        if not name or name == "" then return end
        if not byName[name] then byName[name] = {}; order[#order + 1] = name end
        byName[name][#byName[name] + 1] = part
    end
    for icon = 1, 8 do
        local rec = ns.db.markBoard[icon]
        if rec then
            local iconName = (ns.RAID_ICON_NAMES and ns.RAID_ICON_NAMES[icon]) or ("icon " .. icon)
            local mob = rec.mob and (" (" .. rec.mob .. ")") or ""
            for _, r in ipairs(MarkBoard.ROLES) do
                if rec[r.key] then add(rec[r.key], r.label .. " " .. iconName .. mob) end
            end
        end
    end
    local out = {}
    for _, name in ipairs(order) do
        out[#out + 1] = { name = name, msg = "[RaidLead] You: " .. table.concat(byName[name], "; ") }
    end
    return out
end

----------------------------------------------------------------------
-- Comm handlers
----------------------------------------------------------------------
local function isBulkSync(channel) return channel == "WHISPER" end

if ns.Comm then
    ns.Comm.RegisterHandler("MARK_SET", function(parts, sender, channel)
        local icon    = tonumber(parts[2])
        local roleKey = parts[3]
        local player  = parts[4]
        if not icon or not roleKey or not RoleDef(roleKey) then return end

        MarkBoard._suppressBroadcast = true
        MarkBoard.SetRole(icon, roleKey, player)
        MarkBoard._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " set " .. roleKey .. " on icon " .. icon)
        end
        if ns.RefreshMarksView then ns.RefreshMarksView() end
        if ns.UpdateCompactDisplay then ns.UpdateCompactDisplay() end
    end)

    ns.Comm.RegisterHandler("MARK_CLEAR", function(parts, sender, channel)
        MarkBoard._suppressBroadcast = true
        MarkBoard.ClearAll()
        MarkBoard._suppressBroadcast = false

        if not isBulkSync(channel) then
            ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " cleared the mark board.")
        end
        if ns.RefreshMarksView then ns.RefreshMarksView() end
        if ns.UpdateCompactDisplay then ns.UpdateCompactDisplay() end
    end)
end
