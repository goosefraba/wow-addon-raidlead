----------------------------------------------------------------------
-- RaidLead   v0.2.0
-- Raid management: buff scanner, healer assignments, boss templates.
-- Entry point — initialization, slash commands, event handling.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
-- NOTE: do NOT register "/rl" — it's a built-in WoW alias for /reload, so
-- some players' clients fire a UI reload instead of this addon. Use the
-- full "/raidlead" or the safe short alias "/rlead".
SLASH_RAIDLEAD1 = "/raidlead"
SLASH_RAIDLEAD2 = "/rlead"

SlashCmdList["RAIDLEAD"] = function(msg)
    msg = (msg or ""):trim()
    local f = ns.mainFrame
    if not f then
        ns.P("|cFFFF4444RaidLead UI failed to load.|r Check for a Lua error on login and /reload.")
        return
    end

    -- No args: toggle panel
    if msg == "" then
        if f:IsShown() then
            f:Hide()
        else
            f:Show()
            ns.BuffScan.ScanGroup()
        end
        return
    end

    local cmd, rest = msg:match("^(%S+)%s*(.*)")
    cmd = (cmd or ""):lower()

    if cmd == "scan" then
        ns.BuffScan.ScanGroup()
        ns.P("Scan complete (" .. #ns.BuffScan.scanSorted .. " players).")

    elseif cmd == "mock" then
        ns.BuffScan.LoadMockData()
        if ns.LootHistory and ns.LootHistory.LoadMockData then
            ns.LootHistory.LoadMockData()
        end
        if not f:IsShown() then f:Show() end

    elseif cmd == "clearmock" then
        if ns.LootHistory and ns.LootHistory.RemoveMockRuns then
            local removed = ns.LootHistory.RemoveMockRuns()
            ns.P("Removed " .. removed .. " mock loot run(s). Real data preserved.")
        end

    elseif cmd == "restorehistory" then
        if ns.LootHistory and ns.LootHistory.RestoreBackup then
            ns.LootHistory.RestoreBackup()
        end

    elseif cmd == "announce" then
        local sub = (rest or ""):lower():trim()
        if sub == "buffs" or sub == "consumables" then
            ns.BuffScan.Announce(nil, "consumables")
        elseif sub == "raidbuffs" or sub == "raid" then
            ns.BuffScan.Announce(nil, "raidbuffs")
        else
            ns.BuffScan.Announce(nil, "all")
        end

    elseif cmd == "sync" then
        if ns.BossTemplates and ns.BossTemplates.RequestSync then
            ns.BossTemplates.RequestSync()
        end

    elseif cmd == "mark" or cmd == "markpack" then
        if ns.AutoMarkPack then ns.AutoMarkPack() end

    elseif cmd == "marknext" then
        local sub = (rest or ""):lower():trim()
        if sub == "reset" then
            if ns.ResetMarkSequence then ns.ResetMarkSequence() end
        elseif ns.MarkNextTarget then
            ns.MarkNextTarget()
        end

    elseif cmd == "settings" or cmd == "config" or cmd == "options" then
        local sp = RaidLeadSettings
        if sp then
            if sp:IsShown() then sp:Hide() else sp:Show() end
        end

    elseif cmd == "debug" then
        ns.DEBUG = not ns.DEBUG
        if ns.db and ns.db.settings then ns.db.settings.debug = ns.DEBUG end
        ns.P("Debug " .. (ns.DEBUG and "|cFF44FF44ON|r" or "|cFFFF4444OFF|r"))

    elseif cmd == "commstats" then
        -- Outbound addon-message counters. Watch these across a zone-in to
        -- confirm the traffic stays under the server's rate limit.
        if ns.Comm and ns.Comm.stats then
            ns.P(string.format("Comm: sent %d, dropped %d, queued %d",
                ns.Comm.stats.sent, ns.Comm.stats.dropped, ns.Comm.QueueDepth()))
        end

    elseif cmd == "cdtest" then
        -- Solo test: inject a fake Innervate + Battle Rez so the Combat tab
        -- populates without a real druid group.
        if ns.CombatReport and ns.CombatReport.InjectTest then
            ns.CombatReport.InjectTest()
            if not f:IsShown() then f:Show() end
            if ns.ShowTab then ns.ShowTab("Combat") end
        end

    elseif cmd == "roletest" then
        -- Solo test: open the role-check popup as if a fake leader sent one.
        local who = (rest and rest ~= "" and rest) or "Tester"
        if ns.ShowRoleCheckDialog then
            ns.ShowRoleCheckDialog(who)
            ns.P("Opened role-check dialog (simulated sender: " .. who .. ").")
        else
            ns.P("|cFFFF4444Role-check dialog not loaded.|r")
        end

    elseif cmd == "vertest" then
        -- Solo test: pretend a peer reported a higher version. Triggers
        -- the chat warning + the banner under the title. Pass any version
        -- string; defaults to bumping the patch by 1.
        local target = (rest and rest ~= "" and rest)
        if not target then
            local maj, min, pat = (ns.VERSION or "1.0.0"):match("^(%d+)%.(%d+)%.?(%d*)$")
            pat = tonumber(pat) or 0
            target = (maj or "1") .. "." .. (min or "0") .. "." .. (pat + 1)
        end
        if ns.db then
            ns.db.knownLatestVersion = target
            ns.db.knownLatestVersionAnnounced = false  -- replay one-shot warn
            ns.db.versions = ns.db.versions or {}
            ns.db.versions["FakePeer"] = target
        end
        if ns.UpdateVersionBanner then ns.UpdateVersionBanner() end
        ns.P("Simulated peer FakePeer on v" .. target .. ". Banner should appear.")

    elseif cmd == "vertestclear" then
        if ns.db then
            ns.db.knownLatestVersion = nil
            ns.db.knownLatestVersionAnnounced = nil
            if ns.db.versions then ns.db.versions["FakePeer"] = nil end
        end
        if ns.UpdateVersionBanner then ns.UpdateVersionBanner() end
        ns.P("Cleared simulated peer version.")

    elseif cmd == "help" then
        ns.P("v" .. ns.ADDON_VERSION .. " \226\128\148 Commands:")
        ns.P("  |cFF888888(short alias: |r|cFFFFCC00/rlead|r|cFF888888)|r")
        ns.P("  |cFFFFCC00/raidlead|r \226\128\148 Toggle main panel")
        ns.P("  |cFFFFCC00/raidlead scan|r \226\128\148 Force re-scan buffs")
        ns.P("  |cFFFFCC00/raidlead mock|r \226\128\148 Load mock test data (solo testing)")
        ns.P("  |cFFFFCC00/raidlead clearmock|r \226\128\148 Remove mock loot history (keep real data)")
        ns.P("  |cFFFFCC00/raidlead restorehistory|r \226\128\148 Restore raid history from the last backup")
        ns.P("  |cFFFFCC00/raidlead announce|r \226\128\148 Post all missing to raid/party")
        ns.P("  |cFFFFCC00/raidlead announce buffs|r \226\128\148 Post missing consumables only")
        ns.P("  |cFFFFCC00/raidlead announce raidbuffs|r \226\128\148 Post missing raid buffs only")
        ns.P("  |cFFFFCC00/raidlead sync|r \226\128\148 Pull boss assignments from group")
        ns.P("  |cFFFFCC00/raidlead mark|r \226\128\148 Mark visible hostiles (Skull, Cross, \226\128\166)")
        ns.P("  |cFFFFCC00/raidlead marknext|r \226\128\148 Mark your target with the next icon (|cFFFFCC00reset|r to restart)")
        ns.P("  |cFFFFCC00/raidlead settings|r \226\128\148 Open settings")
        ns.P("  |cFFFFCC00/raidlead debug|r \226\128\148 Toggle debug mode")
        ns.P("  |cFFFFCC00/raidlead cdtest|r \226\128\148 Inject a test Innervate + Battle Rez (Combat tab)")
        ns.P("  |cFFFFCC00/raidlead roletest [name]|r \226\128\148 Open the role-check popup locally")
        ns.P("  |cFFFFCC00/raidlead vertest [x.y.z]|r \226\128\148 Simulate a peer with a newer version")
        ns.P("  |cFFFFCC00/raidlead vertestclear|r \226\128\148 Clear the simulated peer version")
        ns.P("  |cFFFFCC00/raidlead help|r \226\128\148 This message")

    else
        ns.P("Unknown command: |cFFFF4444" .. cmd .. "|r \226\128\148 type |cFFFFCC00/raidlead help|r")
    end
end

-- Keep /rs as alias with deprecation notice
SLASH_RAIDSPY1 = "/raidspy"
SLASH_RAIDSPY2 = "/rs"
SlashCmdList["RAIDSPY"] = function(msg)
    ns.P("|cFFFFCC00Note:|r RaidSpy is now RaidLead. Use |cFFFFCC00/raidlead|r instead.")
    SlashCmdList["RAIDLEAD"](msg)
end

----------------------------------------------------------------------
-- Event handling
----------------------------------------------------------------------
local loader = CreateFrame("Frame")

-- Wrap RegisterEvent so unknown event names (varies between client versions)
-- don't crash the rest of the file load.
local function SafeRegister(f, eventName)
    pcall(f.RegisterEvent, f, eventName)
end

SafeRegister(loader, "ADDON_LOADED")
SafeRegister(loader, "PLAYER_LOGIN")
SafeRegister(loader, "PLAYER_ENTERING_WORLD")
SafeRegister(loader, "GROUP_ROSTER_UPDATE")
-- TBC fallbacks (may be absent in some clients)
SafeRegister(loader, "PARTY_MEMBERS_CHANGED")
SafeRegister(loader, "RAID_ROSTER_UPDATE")

-- State for auto-sync on join
local wasInGroup = false
local firstEnterDone = false   -- only the first PLAYER_ENTERING_WORLD syncs
local lastSyncRequest = 0
local SYNC_THROTTLE = 30  -- seconds

-- Guard against a transient empty roster during zone changes being read as
-- "just joined a group" (see the GROUP_ROSTER_UPDATE handler below).
local lastZoneChange = 0
local ZONE_GRACE = 12   -- seconds after a zone change that a blip is possible
local lastGroupSig = "" -- who we were grouped with, to spot a genuine new group

-- Cheap identity for the current group: sorted member names. Used to tell a
-- zoning artifact (roster reappears IDENTICAL) apart from actually joining a
-- different group (roster differs), which a timer alone cannot distinguish.
local function GroupSignature()
    local names = {}
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do
            local n = UnitName("raid" .. i)
            if n then names[#names + 1] = n end
        end
    elseif IsInGroup and IsInGroup() then
        names[1] = UnitName("player")
        for i = 1, 4 do
            local n = UnitName("party" .. i)
            if n then names[#names + 1] = n end
        end
    end
    if #names == 0 then return "" end
    table.sort(names)
    return table.concat(names, ",")
end

local function MaybeAutoSync(reason)
    if not ns.BossTemplates or not ns.BossTemplates.RequestSync then return end
    local now = GetTime()
    if now - lastSyncRequest < SYNC_THROTTLE then
        ns.D("Auto-sync skipped (throttled): " .. reason)
        return
    end
    local gt = ns.GetGroupType()
    if gt == "solo" then return end
    lastSyncRequest = now
    ns.D("Auto-sync triggered: " .. reason)
    -- Small delay so the group state has time to fully settle, plus random
    -- jitter: when a whole raid triggers this at the same moment (everyone
    -- zoning in together) a FIXED delay keeps them synchronized and they all
    -- fire their request burst in the same instant. Spreading over ~4s
    -- desynchronizes the group.
    C_Timer.After(2 + math.random() * 4, function()
        ns.BossTemplates.RequestSync()
        -- Push our own self-declared role to the group, and ask everyone
        -- else for theirs. Both are safe no-ops if Roles isn't set up.
        if ns.Roles then
            if ns.Roles.BroadcastMyRole then ns.Roles.BroadcastMyRole() end
            if ns.Roles.RequestAll      then ns.Roles.RequestAll()      end
        end
        -- Same pattern for addon versions
        if ns.Versions then
            if ns.Versions.BroadcastMine then ns.Versions.BroadcastMine() end
            if ns.Versions.RequestAll    then ns.Versions.RequestAll()    end
        end
        -- ...and for self-reported weapon enchants (oils/stones)
        if ns.WeaponEnchant then
            if ns.WeaponEnchant.BroadcastMine then ns.WeaponEnchant.BroadcastMine() end
            if ns.WeaponEnchant.RequestAll    then ns.WeaponEnchant.RequestAll()    end
        end
    end)
end

loader:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end

        ns.InitDB()

        -- Restore frame position & size
        local f = ns.mainFrame
        if ns.db.frame then
            f:ClearAllPoints()
            f:SetPoint(
                ns.db.frame.point    or "CENTER",
                UIParent,
                ns.db.frame.relPoint or "CENTER",
                ns.db.frame.x        or 0,
                ns.db.frame.y        or 0
            )
            f:SetSize(
                ns.db.frame.width  or ns.MIN_W,
                ns.db.frame.height or ns.MIN_H
            )
        end

        -- Default to first tab
        ns.ShowTab("Grid")

        -- Apply compact mode if it was on
        if ns.ApplyCompactMode then ns.ApplyCompactMode() end
        -- Update lock icon to reflect saved state
        if ns.UpdateLockIcon then ns.UpdateLockIcon() end
        -- Update version banner from sticky knownLatestVersion
        if ns.UpdateVersionBanner then ns.UpdateVersionBanner() end

        ns.D("ADDON_LOADED complete")
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        ns.P("v" .. ns.ADDON_VERSION .. " loaded. Type |cFFFFCC00/raidlead|r (or |cFFFFCC00/rlead|r) to open.")
        -- Stamp our own version into the version store so self-lookups work.
        -- UnitName("player") is reliable only from PLAYER_LOGIN onward.
        if ns.Versions and ns.Versions.RecordSelf then
            ns.Versions.RecordSelf()
        end
        -- Seed our own weapon-enchant report so the local row is populated
        -- even before the first scan/broadcast.
        if ns.WeaponEnchant and ns.WeaponEnchant.ScanSelf then
            ns.WeaponEnchant.ScanSelf()
        end
        wasInGroup = (ns.GetGroupType() ~= "solo")
        if wasInGroup then
            MaybeAutoSync("PLAYER_LOGIN in group")
        end
        self:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Fires on login, /reload, AND every zone / instance change. Only
        -- the FIRST one (login or /reload) triggers an auto-sync. Later ones
        -- are zone changes: on an instance transition the WHOLE raid fires
        -- this at the same moment, and a synchronized group-wide sync storm
        -- floods the addon channel and disconnects everyone. State is
        -- already synced, and a genuine new member re-syncs via
        -- GROUP_ROSTER_UPDATE below, so we skip the sync on zone changes.
        -- Stamp the time so the roster handler can tell a zoning artifact
        -- apart from a real group join.
        lastZoneChange = GetTime()
        if not firstEnterDone then
            firstEnterDone = true
            if ns.GetGroupType() ~= "solo" then
                MaybeAutoSync("initial enter (login/reload)")
            end
        end

    elseif event == "GROUP_ROSTER_UPDATE"
        or event == "PARTY_MEMBERS_CHANGED"
        or event == "RAID_ROSTER_UPDATE"
    then
        if ns.db and ns.db.settings and ns.db.settings.autoScan then
            ns.BuffScan.DebouncedScan()
        end

        -- Detect transition from solo -> in group (we just joined).
        --
        -- Careful: during a zone / instance transition the roster APIs can
        -- briefly report an empty group, which then looks like solo -> group
        -- a moment later and re-triggers the auto-sync burst on EVERY raid
        -- member at once. We distinguish that from a real join by comparing
        -- the group's membership: a zoning blip brings back the SAME roster,
        -- whereas actually joining somewhere gives a different one. The
        -- signature is only compared inside the post-zone window, so leaving
        -- and later rejoining the same raid still syncs normally.
        local nowInGroup = (ns.GetGroupType() ~= "solo")
        if nowInGroup then
            local sig = GroupSignature()
            if not wasInGroup then
                if sig ~= "" and sig == lastGroupSig
                   and (GetTime() - lastZoneChange) < ZONE_GRACE then
                    ns.D("Skipping auto-sync: same roster reappearing after a zone change.")
                else
                    MaybeAutoSync("just joined group")
                end
            end
            -- Only remember a real roster; during the blip we read as solo and
            -- deliberately keep the pre-blip signature to compare against.
            if sig ~= "" then lastGroupSig = sig end
        end
        wasInGroup = nowInGroup

        -- Leadership may have changed; refresh leader-gated controls
        if ns.UpdateRoleCheckButton then ns.UpdateRoleCheckButton() end
        if ns.UpdateQuickPollButton then ns.UpdateQuickPollButton() end

        -- Leadership change can flip edit permission; refresh the read-only
        -- indicators (title tag + lock icon).
        if ns.UpdateTitleBar then ns.UpdateTitleBar() end
        if ns.UpdateLockIcon then ns.UpdateLockIcon() end
        if ns.RefreshPollManager then ns.RefreshPollManager() end

        -- Refresh solo message state if panel is open (tab-aware: the
        -- placeholder only shows on the buff-scan tabs).
        local f = ns.mainFrame
        if f:IsShown() and ns.UpdateSoloMsg then
            ns.UpdateSoloMsg()
        end
    end
end)

-- Call InitDB right at file load. SavedVariables are available by this
-- point and we want ns.db ready before any UI interaction. ADDON_LOADED
-- may still re-run it later (idempotent).
if ns.InitDB then ns.InitDB() end
-- Apply lock icon tint now that db is set
if ns.UpdateLockIcon then ns.UpdateLockIcon() end

ns.D(">>> RaidLead loading complete")
