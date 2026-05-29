----------------------------------------------------------------------
-- RaidLead — UI/BossTemplateWidgets/MagtheridonAssignments.lua
-- Magtheridon - main tank + 5 cube clickers (one per raid icon)
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BOSS_KEY = "magtheridon"
local PHASE_KEY = "default"
local TANK_KEY = "maintank"

ns.RegisterBossWidget(BOSS_KEY, function(parent)
    local bossData = ns.BossRegistry:Get(BOSS_KEY)
    if not bossData then return end

    local widget = CreateFrame("Frame", nil, parent)
    widget:SetAllPoints()

    local dropdowns = {}  -- [key] = dropdown
    local detectedLabels = {}  -- [key] = font string for detected mob name

    --------------------------------------------------------------------
    -- Notes
    --------------------------------------------------------------------
    if bossData.notes then
        local notes = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        notes:SetPoint("TOPLEFT", widget, "TOPLEFT", 4, -2)
        notes:SetPoint("RIGHT", widget, "RIGHT", -4, 0)
        notes:SetJustifyH("LEFT")
        notes:SetText(bossData.notes)
        notes:SetTextColor(0.53, 0.53, 0.53)
    end

    --------------------------------------------------------------------
    -- Main Tank
    --------------------------------------------------------------------
    local tankHeader = ns.MakeSectionHeader(widget, "Main Tank")
    tankHeader:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, -22)
    tankHeader:SetPoint("RIGHT", widget, "RIGHT", -4, 0)

    local tankRow = CreateFrame("Frame", nil, widget)
    tankRow:SetSize(400, 24)
    tankRow:SetPoint("TOPLEFT", tankHeader, "BOTTOMLEFT", 0, -4)

    local tankLabel = tankRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tankLabel:SetPoint("TOPLEFT", tankRow, "TOPLEFT", 0, -4)
    tankLabel:SetWidth(100)
    tankLabel:SetJustifyH("LEFT")
    tankLabel:SetText(bossData.mainTank.label)
    local tr, tg, tb = bossData.mainTank.color[1], bossData.mainTank.color[2], bossData.mainTank.color[3]
    tankLabel:SetTextColor(tr, tg, tb)

    local tankHitbox = CreateFrame("Frame", nil, tankRow)
    tankHitbox:SetAllPoints(tankLabel)
    tankHitbox:EnableMouse(true)
    tankHitbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(bossData.mainTank.label, tr, tg, tb)
        GameTooltip:AddLine(bossData.mainTank.tip, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    tankHitbox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local tankDD = ns.CreatePlayerDropdown(tankRow, 180, function(playerName)
        ns.BossTemplates.SetAssignment(BOSS_KEY, TANK_KEY, PHASE_KEY, 1, playerName)
    end)
    tankDD.respectLock = true
    tankDD:SetPoint("TOPLEFT", tankRow, "TOPLEFT", 105, -2)
    dropdowns[TANK_KEY] = tankDD

    --------------------------------------------------------------------
    -- Cube Clickers (one per raid icon)
    --------------------------------------------------------------------
    local cubeHeader = ns.MakeSectionHeader(widget, "Cube Clickers (mark channelers, same icon = same cube)")
    cubeHeader:SetPoint("TOPLEFT", tankRow, "BOTTOMLEFT", -4, -14)
    cubeHeader:SetPoint("RIGHT", widget, "RIGHT", -120, 0)  -- leave space for Scan Marks button

    local ROW_H = 28
    local ICON_SIZE = 20

    for cIdx, cube in ipairs(bossData.cubes) do
        local yOff = -6 - (cIdx - 1) * ROW_H

        local row = CreateFrame("Frame", nil, widget)
        row:SetSize(400, ROW_H - 2)
        row:SetPoint("TOPLEFT", cubeHeader, "BOTTOMLEFT", 0, yOff)

        -- Raid icon texture
        local iconFrame = CreateFrame("Frame", nil, row)
        iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
        iconFrame:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        iconFrame:EnableMouse(true)

        local tex = iconFrame:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(ns.GetRaidIconTexture(cube.iconIdx))

        local iconName = ns.RAID_ICON_NAMES[cube.iconIdx] or cube.label
        iconFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(iconName, 1, 1, 1)
            GameTooltip:AddLine("Assign this icon to one Hellfire Channeler in phase 1.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Label + detected mob info
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
        label:SetWidth(160)
        label:SetJustifyH("LEFT")
        label:SetText(cube.label)
        detectedLabels[cube.key] = label

        -- Player dropdown
        local cubeKey = cube.key
        local dd = ns.CreatePlayerDropdown(row, 180, function(playerName)
            ns.BossTemplates.SetAssignment(BOSS_KEY, cubeKey, PHASE_KEY, 1, playerName)
        end)
        dd.respectLock = true
        dd:SetPoint("TOPLEFT", row, "TOPLEFT", 200, -2)
        dropdowns[cube.key] = dd
    end

    --------------------------------------------------------------------
    -- Scan Marks button (detect currently marked mobs)
    --------------------------------------------------------------------
    local function UpdateDetectedLabels()
        local detected = ns.ScanMarkedMobs()
        for _, cube in ipairs(bossData.cubes) do
            local info = detected[cube.iconIdx]
            local lbl = detectedLabels[cube.key]
            if info then
                lbl:SetText(cube.label .. ": |cFF88CCFF" .. info.name .. "|r")
            else
                lbl:SetText(cube.label)
            end
        end
    end

    local scanBtn = ns.MakeSmallButton(widget, "Scan Marks", 100, 22)
    scanBtn:SetPoint("TOPLEFT", cubeHeader, "TOPRIGHT", 12, 2)
    scanBtn:SetScript("OnClick", UpdateDetectedLabels)
    scanBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Scan Marked Mobs", 1, 0.82, 0)
        GameTooltip:AddLine("Checks raid targets for marked mobs and shows their names next to each icon.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    scanBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    --------------------------------------------------------------------
    -- Announce
    --------------------------------------------------------------------
    local function BuildAnnounceLines()
        local lines = { "== " .. bossData.name .. " ==" }
        local tank = ns.BossTemplates.GetAssignment(BOSS_KEY, TANK_KEY, PHASE_KEY, 1) or "?"
        lines[#lines + 1] = "Tank: " .. tank
        for _, cube in ipairs(bossData.cubes) do
            local name = ns.BossTemplates.GetAssignment(BOSS_KEY, cube.key, PHASE_KEY, 1) or "?"
            local iconStr = ns.GetRaidIconText(cube.iconIdx)
            lines[#lines + 1] = iconStr .. " " .. cube.label .. ": " .. name
        end
        return lines
    end

    --------------------------------------------------------------------
    -- Bottom buttons: Announce + Debug + Clear
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
            ns.P("|cFFFF8800Locked.|r Click the lock icon (top-right) to enable editing.")
            return
        end
        ns.BossTemplates.ClearAssignments(BOSS_KEY)
        for _, dd in pairs(dropdowns) do
            dd:SetSelectedPlayer(nil, nil)
        end
        for _, cube in ipairs(bossData.cubes) do
            local lbl = detectedLabels[cube.key]
            if lbl then lbl:SetText(cube.label) end
        end
    end)

    --------------------------------------------------------------------
    -- Compact view text
    --------------------------------------------------------------------
    function widget.BuildCompactText()
        local lines = {}
        lines[#lines + 1] = "|cFFFFCC00" .. bossData.name .. "|r"

        local tank = ns.BossTemplates.GetAssignment(BOSS_KEY, TANK_KEY, PHASE_KEY, 1) or "-"
        lines[#lines + 1] = "|cFFFF6666Tank|r " .. tank

        for _, cube in ipairs(bossData.cubes) do
            local name = ns.BossTemplates.GetAssignment(BOSS_KEY, cube.key, PHASE_KEY, 1) or "-"
            local iconTex = "|T" .. ns.GetRaidIconTexture(cube.iconIdx) .. ":16|t"
            lines[#lines + 1] = iconTex .. " " .. name
        end
        return table.concat(lines, "\n")
    end

    --------------------------------------------------------------------
    -- Refresh
    --------------------------------------------------------------------
    function widget.Refresh()
        local roster = ns.BossTemplates.GetPlayerRoster()
        local function LoadSlot(key)
            local dd = dropdowns[key]
            if not dd then return end
            local saved = ns.BossTemplates.GetAssignment(BOSS_KEY, key, PHASE_KEY, 1)
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
        LoadSlot(TANK_KEY)
        for _, cube in ipairs(bossData.cubes) do
            LoadSlot(cube.key)
        end
    end

    widget.Refresh()
    return widget
end)
