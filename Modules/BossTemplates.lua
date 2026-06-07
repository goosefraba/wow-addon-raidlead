----------------------------------------------------------------------
-- RaidLead — Modules/BossTemplates.lua
-- Boss template assignment logic (storage, get/set, announce)
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BossTemplates = {}
ns.BossTemplates = BossTemplates

----------------------------------------------------------------------
-- Get/Set assignments (stored in SavedVariables)
----------------------------------------------------------------------

-- Returns the full assignment table for a boss, creating if needed
-- Structure: [portalKey][phaseKey][slotIndex] = playerName
function BossTemplates.EnsureDB()
    if not ns.EnsureDB() then return false end
    if not ns.db.bossTemplates then ns.db.bossTemplates = {} end
    return true
end

function BossTemplates.GetAssignments(bossKey)
    if not BossTemplates.EnsureDB() then return {} end
    if not ns.db.bossTemplates[bossKey] then
        ns.db.bossTemplates[bossKey] = {}
    end
    return ns.db.bossTemplates[bossKey]
end

-- Suppress flag — set true while applying remote changes so we don't re-broadcast
BossTemplates._suppressBroadcast = false

-- True when boss configs are read-only: either the lead manually locked
-- them, or this player lacks edit permission (not raid lead/assist).
function BossTemplates.IsLocked()
    if ns.CanEdit and not ns.CanEdit() then return true end
    return ns.db and ns.db.settings and ns.db.settings.bossLocked or false
end

-- Set a single assignment slot
function BossTemplates.SetAssignment(bossKey, portalKey, phaseKey, slotIndex, playerName)
    if not BossTemplates.EnsureDB() then
        ns.P("|cFFFF4444Error:|r Database not loaded yet.")
        return
    end
    if not ns.db.bossTemplates[bossKey] then ns.db.bossTemplates[bossKey] = {} end
    local assignments = ns.db.bossTemplates[bossKey]
    if not assignments[portalKey] then assignments[portalKey] = {} end
    if not assignments[portalKey][phaseKey] then assignments[portalKey][phaseKey] = {} end
    assignments[portalKey][phaseKey][slotIndex] = playerName
    ns.D("Set " .. bossKey .. " " .. tostring(portalKey) .. "/" .. tostring(phaseKey) .. "/" .. tostring(slotIndex) .. " = " .. tostring(playerName))

    -- Broadcast to other addon users (unless we're applying a remote change)
    if not BossTemplates._suppressBroadcast and ns.Comm then
        ns.Comm.Send("ASSIGN", bossKey, portalKey, phaseKey, slotIndex, playerName or "")
    end
end

-- Set arbitrary metadata per boss/key (icons, notes, etc.)
function BossTemplates.SetMeta(bossKey, key, metaKey, value)
    if not BossTemplates.EnsureDB() then return end
    if not ns.db.bossTemplates[bossKey] then ns.db.bossTemplates[bossKey] = {} end
    local bt = ns.db.bossTemplates[bossKey]
    if not bt._meta then bt._meta = {} end
    if not bt._meta[key] then bt._meta[key] = {} end
    bt._meta[key][metaKey] = value

    if not BossTemplates._suppressBroadcast and ns.Comm then
        ns.Comm.Send("META", bossKey, key, metaKey, value or "")
    end
end

function BossTemplates.GetMeta(bossKey, key, metaKey)
    if ns.db and ns.db.bossTemplates and ns.db.bossTemplates[bossKey]
       and ns.db.bossTemplates[bossKey]._meta
       and ns.db.bossTemplates[bossKey]._meta[key]
    then
        return ns.db.bossTemplates[bossKey]._meta[key][metaKey]
    end
    return nil
end

-- Get a single assignment slot
function BossTemplates.GetAssignment(bossKey, portalKey, phaseKey, slotIndex)
    local assignments = BossTemplates.GetAssignments(bossKey)
    if assignments[portalKey] and assignments[portalKey][phaseKey] then
        return assignments[portalKey][phaseKey][slotIndex]
    end
    return nil
end

-- Clear all assignments for a boss
function BossTemplates.ClearAssignments(bossKey)
    if ns.db and ns.db.bossTemplates then
        ns.db.bossTemplates[bossKey] = {}
    end
    ns.P("Cleared all assignments for " .. bossKey .. ".")

    if not BossTemplates._suppressBroadcast and ns.Comm then
        ns.Comm.Send("CLEAR", bossKey)
    end
end

----------------------------------------------------------------------
-- Get the current player's own assignments for a boss
----------------------------------------------------------------------
function BossTemplates.GetMyAssignments(bossKey)
    local bossData = ns.BossRegistry:Get(bossKey)
    if not bossData then return {} end

    local playerName = UnitName("player")
    local mySlots = {}

    for _, portal in ipairs(bossData.portals) do
        for _, phase in ipairs(bossData.phases) do
            for slotIdx, slotLabel in ipairs(bossData.slotsPerPortal) do
                local assigned = BossTemplates.GetAssignment(bossKey, portal.key, phase.key, slotIdx)
                if assigned == playerName then
                    mySlots[#mySlots + 1] = {
                        portal = portal.label,
                        phase  = phase.label,
                        slot   = slotLabel,
                    }
                end
            end
        end
    end
    return mySlots
end

----------------------------------------------------------------------
-- Send / debug-print helpers for announce lines
----------------------------------------------------------------------

-- Split a line longer than 254 chars at the nearest punctuation/whitespace
-- boundary (Paste-style). Returns an array of chunks all <= 254 chars.
local function SplitLongLine(line)
    if #line <= 254 then return { line } end
    local out = {}
    local LIMIT = 254
    while #line > LIMIT do
        local bpt = LIMIT
        -- Walk backwards up to 30 chars looking for a clean break
        for i = LIMIT, math.max(LIMIT - 30, 1), -1 do
            local c = string.sub(line, i, i)
            if c == " " or c:match("%p") then
                bpt = i
                break
            end
        end
        out[#out + 1] = string.sub(line, 1, bpt)
        line = string.sub(line, bpt + 1)
    end
    if #line > 0 then out[#out + 1] = line end
    return out
end

-- Send a list of lines to chat. Inspired by the Paste addon: send in a
-- tight loop with no throttling. WoW handles small bursts fine; only
-- pathological volumes need ChatThrottleLib.
function BossTemplates.SendLines(lines, channel)
    if not channel then
        channel = ns.BuffScan.GetAnnounceChannel()
    end
    if not channel then
        ns.P("|cFFFF8800Not in a group/raid - use the right-click menu and pick 'Preview' instead.|r")
        return
    end
    local sent = 0
    for _, line in ipairs(lines) do
        for _, chunk in ipairs(SplitLongLine(line)) do
            -- SendChatMessage silently drops any message containing the '|'
            -- escape char, so strip it. (Raid-target markers like {rt8} have
            -- no pipe and are unaffected.)
            SendChatMessage((chunk:gsub("|", "")), channel)
            sent = sent + 1
        end
    end
    ns.P("Sent " .. sent .. " line(s) to " .. channel:lower() .. ".")
end

-- Whisper each recipient their own assignment line. `recipients` is a
-- list of { name = "...", msg = "..." }. Gated to leader/assist.
function BossTemplates.WhisperRecipients(recipients, label)
    if ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can whisper assignments.|r")
        return
    end
    if not recipients or #recipients == 0 then
        ns.P("|cFF888888No " .. (label or "assignments") .. " to whisper.|r")
        return
    end
    local n = 0
    for _, r in ipairs(recipients) do
        if r.name and r.msg and r.msg ~= "" then
            -- SendChatMessage rejects the '|' escape char; strip it.
            SendChatMessage((r.msg:gsub("|", "")), "WHISPER", nil, r.name)
            n = n + 1
        end
    end
    ns.P("Whispered " .. n .. " player(s) their " .. (label or "assignment") .. ".")
end

-- Print lines locally (debug / preview)
function BossTemplates.DebugLines(lines)
    local channel = ns.BuffScan.GetAnnounceChannel() or "PREVIEW"
    ns.P("|cFF88CCFF[would send to " .. channel:lower() .. "]|r")
    for _, line in ipairs(lines) do
        ns.P("  " .. line)
    end
end

-- Show channel picker (right-click on Announce button). Pass an optional
-- whisperFn to add a "Whisper each player" entry (used by the Assign tab
-- to DM each person just their own line).
function BossTemplates.ShowChannelMenu(buildLinesFn, whisperFn)
    local menu = {
        { text = "Announce to", isTitle = true },
    }
    local gt = ns.GetGroupType()
    if gt == "raid" then
        menu[#menu + 1] = { text = "Raid",  func = function() BossTemplates.SendLines(buildLinesFn(), "RAID") end }
        menu[#menu + 1] = { text = "Party", func = function() BossTemplates.SendLines(buildLinesFn(), "PARTY") end }
    elseif gt == "party" then
        menu[#menu + 1] = { text = "Party", func = function() BossTemplates.SendLines(buildLinesFn(), "PARTY") end }
    end
    menu[#menu + 1] = { text = "Say", func = function() BossTemplates.SendLines(buildLinesFn(), "SAY") end }
    if whisperFn then
        menu[#menu + 1] = { text = "Whisper each player", func = function() whisperFn() end }
    end
    menu[#menu + 1] = { text = "Preview locally (only you)", func = function() BossTemplates.DebugLines(buildLinesFn()) end }
    ns.ShowContextMenu(menu, "cursor", 0, 0)
end

----------------------------------------------------------------------
-- Build announce lines for a boss
----------------------------------------------------------------------
function BossTemplates.BuildAnnounceLines(bossKey)
    local bossData = ns.BossRegistry:Get(bossKey)
    if not bossData then return {} end

    BossTemplates.EnsureDB()

    -- Multi-line format (one line per portal-per-phase) with a divider
    -- between phases. WoW's chat handles small bursts fine without
    -- throttling. Avoid `|` (escape codes get rejected); names are
    -- uppercase for visibility since chat color codes don't pass through.
    local DIVIDER = "----------"
    local lines = { "== " .. (bossData.announceTitle or (bossData.name .. " - Assignments")) .. " ==" }
    for pIdx, phase in ipairs(bossData.phases) do
        if pIdx > 1 then lines[#lines + 1] = DIVIDER end
        local phaseTag = phase.label:gsub("Phase ", "P")  -- "Phase 1" -> "P1"
        for _, portal in ipairs(bossData.portals) do
            local primary = BossTemplates.GetAssignment(bossKey, portal.key, phase.key, 1) or "?"
            local backup  = BossTemplates.GetAssignment(bossKey, portal.key, phase.key, 2)
            local entry = phaseTag .. " " .. portal.label:upper() .. ": " .. primary
            if backup then entry = entry .. " (backup: " .. backup .. ")" end
            lines[#lines + 1] = entry
        end
    end
    return lines
end

-- Announce boss assignments (local print for now)
function BossTemplates.Announce(bossKey)
    local lines = BossTemplates.BuildAnnounceLines(bossKey)
    local channel = ns.BuffScan.GetAnnounceChannel() or "?"
    for _, line in ipairs(lines) do
        ns.P("|cFF88CCFF[" .. channel .. "]|r " .. line)
    end
end

----------------------------------------------------------------------
-- Get the player roster for dropdown menus
----------------------------------------------------------------------
function BossTemplates.GetPlayerRoster()
    local roster = {}
    -- Use scan data if available
    if #ns.BuffScan.scanSorted > 0 then
        for _, name in ipairs(ns.BuffScan.scanSorted) do
            local r = ns.BuffScan.scanResults[name]
            roster[#roster + 1] = {
                name  = name,
                class = r and r.class or "UNKNOWN",
            }
        end
    else
        -- Fallback: read raid roster directly
        local units = ns.BuildUnitList()
        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                local name = UnitName(unit)
                local _, class = UnitClass(unit)
                if name then
                    roster[#roster + 1] = { name = name, class = class or "UNKNOWN" }
                end
            end
        end
        table.sort(roster, function(a, b) return a.name < b.name end)
    end
    return roster
end

----------------------------------------------------------------------
-- Sync: refresh widgets after a remote change
----------------------------------------------------------------------
-- WHISPER = bulk sync reply, silence the chat notification (one line
-- per assignment * dozens of assignments = screenfuls of spam after a
-- /reload or zone change). RAID/PARTY = real-time edit, notify.
local isBulkSync = ns.IsBulkSync

local function RefreshAfterRemoteChange(changedBossKey, sender, summary, silent)
    -- Refresh ALL cached boss widgets, not just the active one. This way
    -- when the user later navigates to a boss whose data was changed
    -- remotely, its dropdowns are already up-to-date.
    if ns.bossWidgetContainer and ns.bossWidgetContainer.widgets then
        for bossKey, w in pairs(ns.bossWidgetContainer.widgets) do
            if w and w.Refresh then
                pcall(w.Refresh)
            end
        end
    end
    -- Compact display
    if ns.UpdateCompactDisplay then ns.UpdateCompactDisplay() end

    -- Visible notification so users know assignments changed (skipped
    -- during bulk WHISPER sync to avoid flooding the chat).
    if not silent then
        local bossData = ns.BossRegistry:Get(changedBossKey)
        local bossName = bossData and bossData.name or changedBossKey
        ns.P("|cFF88CCFF[sync]|r " .. (sender or "?") .. " updated " .. bossName .. ".")
    end
    if summary then ns.D(summary) end
end

----------------------------------------------------------------------
-- Register Comm handlers
----------------------------------------------------------------------
if ns.Comm then
    ns.Comm.RegisterHandler("ASSIGN", function(parts, sender, channel)
        -- parts: { "ASSIGN", bossKey, portalKey, phaseKey, slotIndex, playerName }
        local bossKey   = parts[2]
        local portalKey = parts[3]
        local phaseKey  = parts[4]
        local slotIndex = tonumber(parts[5])
        local playerName = parts[6]
        if playerName == "" then playerName = nil end
        if not (bossKey and portalKey and phaseKey and slotIndex) then return end

        BossTemplates._suppressBroadcast = true
        BossTemplates.SetAssignment(bossKey, portalKey, phaseKey, slotIndex, playerName)
        BossTemplates._suppressBroadcast = false

        RefreshAfterRemoteChange(bossKey, sender,
            "set " .. bossKey .. "/" .. portalKey .. "/" .. phaseKey .. "/" .. slotIndex
            .. " = " .. tostring(playerName),
            isBulkSync(channel))
    end)

    ns.Comm.RegisterHandler("META", function(parts, sender, channel)
        -- parts: { "META", bossKey, key, metaKey, value }
        local bossKey = parts[2]
        local key     = parts[3]
        local metaKey = parts[4]
        local value   = parts[5]
        if value == "" then value = nil end
        if not (bossKey and key and metaKey) then return end

        -- Coerce numeric meta values (e.g. icon indices)
        local n = tonumber(value)
        if n then value = n end

        BossTemplates._suppressBroadcast = true
        BossTemplates.SetMeta(bossKey, key, metaKey, value)
        BossTemplates._suppressBroadcast = false

        RefreshAfterRemoteChange(bossKey, sender,
            "meta " .. bossKey .. "/" .. key .. "/" .. metaKey .. " = " .. tostring(value),
            isBulkSync(channel))
    end)

    ns.Comm.RegisterHandler("CLEAR", function(parts, sender, channel)
        -- parts: { "CLEAR", bossKey }
        local bossKey = parts[2]
        if not bossKey then return end

        BossTemplates._suppressBroadcast = true
        BossTemplates.ClearAssignments(bossKey)
        BossTemplates._suppressBroadcast = false

        RefreshAfterRemoteChange(bossKey, sender, "cleared " .. bossKey,
            isBulkSync(channel))
    end)

    ----------------------------------------------------------------------
    -- Sync handshake
    ----------------------------------------------------------------------

    -- Iterate local boss data and whisper it back to the requester. We
    -- QUEUE every message and drain a few per timer tick — a fully set-up
    -- raid is 100+ entries, and firing them all in one frame overruns WoW's
    -- addon-message rate limit (silently dropped -> lost sync).
    local SYNC_BURST   = 4      -- messages per tick
    local SYNC_INTERVAL = 0.10  -- seconds between ticks

    local function SendFullStateTo(target)
        if not BossTemplates.EnsureDB() then return 0 end
        local data = ns.db.bossTemplates or {}

        local queue = {}
        local function q(...) queue[#queue + 1] = { ... } end

        for bossKey, bossEntry in pairs(data) do
            if type(bossEntry) == "table" then
                -- Assignments: bossEntry[portalKey][phaseKey][slotIdx] = name
                for portalKey, phases in pairs(bossEntry) do
                    if portalKey ~= "_meta" and type(phases) == "table" then
                        for phaseKey, slots in pairs(phases) do
                            if type(slots) == "table" then
                                for slotIdx, name in pairs(slots) do
                                    if name and name ~= "" then
                                        q("ASSIGN", bossKey, portalKey, phaseKey, slotIdx, name)
                                    end
                                end
                            end
                        end
                    end
                end
                -- Metadata: bossEntry._meta[key][metaKey] = value
                if type(bossEntry._meta) == "table" then
                    for key, metaTbl in pairs(bossEntry._meta) do
                        if type(metaTbl) == "table" then
                            for metaKey, value in pairs(metaTbl) do
                                if value ~= nil then
                                    q("META", bossKey, key, metaKey, value)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Healer assignments
        if ns.db.healers then
            for healerName, cfg in pairs(ns.db.healers) do
                if type(cfg) == "table" and cfg.mode then
                    q("HEAL_SET", healerName, cfg.mode, cfg.target or "")
                end
                if type(cfg) == "table" and cfg.earthShield then
                    q("HEAL_ES", healerName, cfg.earthShield)
                end
            end
        end

        -- Hunter Misdirect assignments
        if ns.db.misdirects then
            for hunterName, mdTarget in pairs(ns.db.misdirects) do
                if mdTarget and mdTarget ~= "" then
                    q("MD_SET", hunterName, mdTarget)
                end
            end
        end

        -- Self-declared roles
        if ns.db.roles then
            for playerName, role in pairs(ns.db.roles) do
                if role and role ~= "" then
                    q("ROLE_SET", playerName, role)
                end
            end
        end

        -- Our own addon version (so the requester can flag outdated peers)
        if ns.VERSION then
            q("VER", ns.VERSION)
        end

        -- Cooldown assignments
        if ns.db.cooldowns then
            for cdKey, rec in pairs(ns.db.cooldowns) do
                if rec and (rec.caster or rec.target) then
                    q("CD_SET", cdKey, rec.caster or "", rec.target or "")
                end
            end
        end

        -- Mark board (per-icon role assignments)
        if ns.db.markBoard and ns.MarkBoard then
            for iconIdx, rec in pairs(ns.db.markBoard) do
                if type(rec) == "table" then
                    for _, role in ipairs(ns.MarkBoard.ROLES) do
                        if rec[role.key] and rec[role.key] ~= "" then
                            q("MARK_SET", tostring(iconIdx), role.key, rec[role.key])
                        end
                    end
                end
            end
        end

        -- Drain the queue gradually.
        local total, i = #queue, 1
        local function pump()
            for _ = 1, SYNC_BURST do
                local msg = queue[i]
                if not msg then return end
                ns.Comm.Whisper(target, unpack(msg))
                i = i + 1
            end
            if queue[i] then C_Timer.After(SYNC_INTERVAL, pump) end
        end
        pump()

        return total
    end

    -- Throttle: don't respond to repeated requests too quickly
    local lastResponseTo = {}  -- [name] = time
    local RESPONSE_COOLDOWN = 5

    ns.Comm.RegisterHandler("REQUEST_SYNC", function(parts, sender)
        if not sender or sender == "" then return end
        local now = GetTime()
        if lastResponseTo[sender] and (now - lastResponseTo[sender]) < RESPONSE_COOLDOWN then
            return
        end
        lastResponseTo[sender] = now

        -- Small random delay so multiple responders don't all reply at once
        C_Timer.After(math.random() * 0.8, function()
            local count = SendFullStateTo(sender) or 0
            if count > 0 then
                ns.D("Sent " .. count .. " sync entries to " .. sender)
            end
        end)
    end)

    -- Public function: ask the group for their data
    function BossTemplates.RequestSync()
        if not ns.Comm then return end
        local channel = nil
        if IsInRaid and IsInRaid() then channel = "RAID"
        elseif IsInGroup and IsInGroup() then channel = "PARTY"
        elseif GetNumRaidMembers and GetNumRaidMembers() > 0 then channel = "RAID"
        elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then channel = "PARTY"
        end
        if not channel then
            ns.P("Not in a group/raid — nothing to sync.")
            return
        end
        ns.Comm.Send("REQUEST_SYNC")
        ns.P("|cFF88CCFFRequesting sync from group...|r")
    end
end
