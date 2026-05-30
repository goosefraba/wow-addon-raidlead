----------------------------------------------------------------------
-- RaidLead - UI/BossTemplateWidgets/AlarAssignments.lua
-- Al'ar - position-based tank assignments (NE/SE/SW/NW + Ember Kiter).
-- No raid icons; platforms are compass positions.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BOSS_KEY  = "alar"
local PHASE_KEY = "default"

ns.RegisterBossWidget(BOSS_KEY, function(parent)
    local bossData = ns.BossRegistry:Get(BOSS_KEY)
    if not bossData then return end

    local widget = CreateFrame("Frame", nil, parent)
    widget:SetAllPoints()

    local dropdowns = {}

    if bossData.notes then
        local notes = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        notes:SetPoint("TOPLEFT", widget, "TOPLEFT", 4, -2)
        notes:SetPoint("RIGHT", widget, "RIGHT", -4, 0)
        notes:SetJustifyH("LEFT")
        notes:SetText(bossData.notes)
        notes:SetTextColor(0.6, 0.6, 0.6)
    end

    local sectionHeader = ns.MakeSectionHeader(widget, "Tank Assignments")
    sectionHeader:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, -34)
    sectionHeader:SetPoint("RIGHT", widget, "RIGHT", -4, 0)

    local LABEL_W = 160
    local TANK_W  = 180
    local PAD     = 6

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
    MakeColumnHeader("Position", x, LABEL_W); x = x + LABEL_W + PAD
    MakeColumnHeader("Tank",     x, TANK_W)

    local ROW_H = 28
    for sIdx, slot in ipairs(bossData.slots) do
        local yOff = -22 - (sIdx - 1) * ROW_H
        local row = CreateFrame("Frame", nil, widget)
        row:SetSize(620, ROW_H - 2)
        row:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, yOff)

        local rx = 0

        local labelFrame = CreateFrame("Frame", nil, row)
        labelFrame:SetSize(LABEL_W, ROW_H - 4)
        labelFrame:SetPoint("TOPLEFT", row, "TOPLEFT", rx, -2)
        labelFrame:EnableMouse(true)

        local label = labelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", labelFrame, "LEFT", 0, 0)
        label:SetWidth(LABEL_W)
        label:SetJustifyH("LEFT")
        label:SetText(slot.label)

        local slotTip = slot.tip
        local slotLabel = slot.label
        labelFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(slotLabel, 1, 1, 1)
            if slotTip then
                GameTooltip:AddLine(slotTip, 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        labelFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        rx = rx + LABEL_W + PAD

        dropdowns[slot.key] = {}
        local slotKey = slot.key
        local tankDD = ns.CreatePlayerDropdown(row, TANK_W, function(playerName)
            ns.BossTemplates.SetAssignment(BOSS_KEY, slotKey, PHASE_KEY, 1, playerName)
        end)
        tankDD.respectLock = true
        tankDD:SetPoint("TOPLEFT", row, "TOPLEFT", rx, -2)
        dropdowns[slot.key][1] = tankDD
    end

    local function BuildAnnounceLines()
        local lines = { "== " .. bossData.name .. " - Phase Tanks ==" }
        for _, slot in ipairs(bossData.slots) do
            local tank = ns.BossTemplates.GetAssignment(BOSS_KEY, slot.key, PHASE_KEY, 1) or "?"
            lines[#lines + 1] = slot.label .. ": " .. tank
        end
        return lines
    end

    function widget.BuildCompactText()
        local lines = {}
        lines[#lines + 1] = "|cFFFFCC00" .. bossData.name .. "|r"
        for _, slot in ipairs(bossData.slots) do
            local tank = ns.BossTemplates.GetAssignment(BOSS_KEY, slot.key, PHASE_KEY, 1) or "-"
            lines[#lines + 1] = slot.label .. ": " .. tank
        end
        return table.concat(lines, "\n")
    end

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
        for _, slot in ipairs(bossData.slots) do
            local dd = dropdowns[slot.key][1]
            if dd then dd:SetSelectedPlayer(nil, nil) end
        end
    end)

    function widget.Refresh()
        local roster = ns.BossTemplates.GetPlayerRoster()
        for _, slot in ipairs(bossData.slots) do
            local dd = dropdowns[slot.key][1]
            if dd then
                local saved = ns.BossTemplates.GetAssignment(BOSS_KEY, slot.key, PHASE_KEY, 1)
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
