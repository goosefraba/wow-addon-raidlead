----------------------------------------------------------------------
-- RaidLead — UI/BossTemplateWidgets/MaulgarAssignments.lua
-- High King Maulgar — icon-based tank + healer assignments.
-- Each council member is identified by a raid target icon. Use the
-- "Scan Marks" button to detect which mob has which icon.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BOSS_KEY  = "maulgar"
local PHASE_KEY = "default"

ns.RegisterBossWidget(BOSS_KEY, function(parent)
    local bossData = ns.BossRegistry:Get(BOSS_KEY)
    if not bossData then return end

    local widget = CreateFrame("Frame", nil, parent)
    widget:SetAllPoints()

    local dropdowns = {}        -- [enemyKey][slotIdx] = dropdown
    local detectedLabels = {}   -- [enemyKey] = font string showing detected mob name

    --------------------------------------------------------------------
    -- Notes at top
    --------------------------------------------------------------------
    if bossData.notes then
        local notes = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        notes:SetPoint("TOPLEFT", widget, "TOPLEFT", 4, -2)
        notes:SetPoint("RIGHT", widget, "RIGHT", -120, 0)  -- leave room for Scan Marks button
        notes:SetJustifyH("LEFT")
        notes:SetText(bossData.notes)
        notes:SetTextColor(0.6, 0.6, 0.6)
    end

    --------------------------------------------------------------------
    -- Header
    --------------------------------------------------------------------
    local sectionHeader = ns.MakeSectionHeader(widget, "Council Assignments")
    sectionHeader:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, -34)
    sectionHeader:SetPoint("RIGHT", widget, "RIGHT", -120, 0)  -- leave space for Scan Marks button

    --------------------------------------------------------------------
    -- Scan Marks button (top-right of widget)
    --------------------------------------------------------------------
    local scanBtn = ns.MakeSmallButton(widget, "Scan Marks", 100, 22)
    scanBtn:SetPoint("TOPRIGHT", widget, "TOPRIGHT", -4, 0)
    scanBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Scan Marked Mobs", 1, 0.82, 0)
        GameTooltip:AddLine("Checks raid targets for marked mobs and shows their names next to each icon.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    scanBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- Failsafe scan: if not in a zone with marked mobs, just clears labels
    local function UpdateDetectedLabels()
        local detected = {}
        if ns.ScanMarkedMobs then
            local ok, result = pcall(ns.ScanMarkedMobs)
            if ok and type(result) == "table" then detected = result end
        end
        local foundAny = false
        for _, enemy in ipairs(bossData.enemies) do
            local info = detected[enemy.iconIdx]
            local lbl = detectedLabels[enemy.key]
            if not lbl then
                -- noop
            elseif info and info.name then
                lbl:SetText("|cFF88CCFF" .. info.name .. "|r")
                foundAny = true
            else
                lbl:SetText("")
            end
        end
        if not foundAny then
            ns.P("|cFF888888No marked mobs detected. Make sure you/raid members target the marked council members.|r")
        end
    end
    scanBtn:SetScript("OnClick", UpdateDetectedLabels)

    --------------------------------------------------------------------
    -- Column layout (healer assignments live in the global Healers tab)
    --------------------------------------------------------------------
    local ICON_SIZE   = 20
    local LABEL_W     = 70
    local DETECTED_W  = 140
    local TANK_W      = 180
    local PAD         = 6

    --------------------------------------------------------------------
    -- Column headers
    --------------------------------------------------------------------
    local headerRow = CreateFrame("Frame", nil, widget)
    headerRow:SetHeight(16)
    headerRow:SetPoint("TOPLEFT", sectionHeader, "BOTTOMLEFT", 0, -4)
    headerRow:SetPoint("RIGHT", widget, "RIGHT", 0, 0)

    local function MakeColumnHeader(text, xOff, width)
        local fs = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", headerRow, "TOPLEFT", xOff, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(0.85, 0.85, 0.85)
    end

    local x = 0
    MakeColumnHeader("Mark",        x, ICON_SIZE + 4 + LABEL_W); x = x + ICON_SIZE + 4 + LABEL_W + PAD
    MakeColumnHeader("Detected",    x, DETECTED_W);              x = x + DETECTED_W + PAD
    MakeColumnHeader("Tank",        x, TANK_W)

    --------------------------------------------------------------------
    -- Rows: 1 per icon
    --------------------------------------------------------------------
    local ROW_H = 28
    for eIdx, enemy in ipairs(bossData.enemies) do
        local yOff = -22 - (eIdx - 1) * ROW_H

        local row = CreateFrame("Frame", nil, widget)
        row:SetSize(600, ROW_H - 2)
        row:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, yOff)

        local rx = 0

        -- Raid icon texture
        local iconFrame = CreateFrame("Frame", nil, row)
        iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
        iconFrame:SetPoint("TOPLEFT", row, "TOPLEFT", rx, -2)
        iconFrame:EnableMouse(true)
        local tex = iconFrame:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        if ns.GetRaidIconTexture then
            tex:SetTexture(ns.GetRaidIconTexture(enemy.iconIdx))
        end
        iconFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(enemy.label, 1, 1, 1)
            GameTooltip:AddLine("Mark one council member with this icon in-game.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rx = rx + ICON_SIZE + 4

        -- Static label (Skull / Cross / etc.)
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", iconFrame, "RIGHT", 4, 0)
        label:SetWidth(LABEL_W)
        label:SetJustifyH("LEFT")
        label:SetText(enemy.label)
        rx = rx + LABEL_W + PAD

        -- Detected mob name (filled by Scan button)
        local detected = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        detected:SetPoint("TOPLEFT", row, "TOPLEFT", rx, -4)
        detected:SetWidth(DETECTED_W)
        detected:SetJustifyH("LEFT")
        detected:SetText("")
        detected:SetWordWrap(false)
        detectedLabels[enemy.key] = detected
        rx = rx + DETECTED_W + PAD

        -- Tank dropdown
        dropdowns[enemy.key] = {}
        local enemyKey = enemy.key

        local tankDD = ns.CreatePlayerDropdown(row, TANK_W, function(playerName)
            ns.BossTemplates.SetAssignment(BOSS_KEY, enemyKey, PHASE_KEY, 1, playerName)
        end)
        tankDD.respectLock = true
        tankDD:SetPoint("TOPLEFT", row, "TOPLEFT", rx, -2)
        dropdowns[enemy.key][1] = tankDD
    end

    --------------------------------------------------------------------
    -- Build announce lines (single-line, icon tokens for chat)
    --------------------------------------------------------------------
    local function BuildAnnounceLines()
        local lines = { "== " .. bossData.name .. " ==" }
        for _, enemy in ipairs(bossData.enemies) do
            local tank = ns.BossTemplates.GetAssignment(BOSS_KEY, enemy.key, PHASE_KEY, 1) or "?"
            local iconStr = ns.GetRaidIconText and ns.GetRaidIconText(enemy.iconIdx) or ""
            lines[#lines + 1] = iconStr .. " " .. enemy.label .. ": " .. tank
        end
        return lines
    end

    --------------------------------------------------------------------
    -- Compact view text
    --------------------------------------------------------------------
    function widget.BuildCompactText()
        local lines = {}
        lines[#lines + 1] = "|cFFFFCC00" .. bossData.name .. "|r"
        for _, enemy in ipairs(bossData.enemies) do
            local tank = ns.BossTemplates.GetAssignment(BOSS_KEY, enemy.key, PHASE_KEY, 1) or "-"
            local iconTex = ns.GetRaidIconTexture and ns.GetRaidIconTexture(enemy.iconIdx)
            local prefix = iconTex and ("|T" .. iconTex .. ":16|t ") or (enemy.label .. " ")
            lines[#lines + 1] = prefix .. "Tank: " .. tank
        end
        return table.concat(lines, "\n")
    end

    --------------------------------------------------------------------
    -- Bottom buttons: Announce + Clear
    --------------------------------------------------------------------
    local announceBtn = ns.MakeSmallButton(widget, "Announce", 110, 24)
    announceBtn:SetPoint("BOTTOMLEFT", widget, "BOTTOMLEFT", 0, 4)
    announceBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ns.BossTemplates.ShowChannelMenu(BuildAnnounceLines)
        else
            ns.BossTemplates.SendLines(BuildAnnounceLines())
        end
    end)
    announceBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Announce", 1, 0.82, 0.1)
        GameTooltip:AddLine("Left-click: send to raid/party (auto)", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: pick channel or preview locally", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    announceBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local clearBtn = ns.MakeSmallButton(widget, "Clear All", 80, 24)
    clearBtn:SetPoint("LEFT", announceBtn, "RIGHT", 6, 0)
    clearBtn:SetScript("OnClick", function()
        if ns.BossTemplates.IsLocked() then
            ns.LockedNotice()
            return
        end
        ns.BossTemplates.ClearAssignments(BOSS_KEY)
        for _, enemy in ipairs(bossData.enemies) do
            local dd = dropdowns[enemy.key][1]
            if dd then dd:SetSelectedPlayer(nil, nil) end
            local lbl = detectedLabels[enemy.key]
            if lbl then lbl:SetText("") end
        end
    end)

    local autoMarkBtn = ns.MakeSmallButton(widget, "Auto-Mark", 100, 24)
    autoMarkBtn:SetPoint("LEFT", clearBtn, "RIGHT", 6, 0)
    autoMarkBtn:SetScript("OnClick", function()
        ns.AutoMarkBoss(bossData.enemies, bossData.name)
        UpdateDetectedLabels()
    end)
    autoMarkBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Auto-Mark Council", 1, 0.82, 0.1)
        GameTooltip:AddLine("One-click marks each council member with its icon "
            .. "(Krosh=Skull, Kiggler=Cross, Blindeye=Square, Olm=Moon, Maulgar=Triangle).",
            0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Needs enemy nameplates on, mobs in range, and raid lead/assist.",
            0.85, 0.55, 0.2, true)
        GameTooltip:Show()
    end)
    autoMarkBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    --------------------------------------------------------------------
    -- Refresh: load saved assignments into dropdowns
    --------------------------------------------------------------------
    function widget.Refresh()
        local roster = ns.BossTemplates.GetPlayerRoster()
        for _, enemy in ipairs(bossData.enemies) do
            local dd = dropdowns[enemy.key][1]
            if dd then
                local saved = ns.BossTemplates.GetAssignment(BOSS_KEY, enemy.key, PHASE_KEY, 1)
                if saved then
                    local class = "UNKNOWN"
                    for _, p in ipairs(roster) do
                        if p.name == saved then class = p.class; break end
                    end
                    dd:SetSelectedPlayer(saved, class)
                else
                    dd:SetSelectedPlayer(nil, nil)
                end
            end
        end
    end

    widget.Refresh()
    return widget
end)
