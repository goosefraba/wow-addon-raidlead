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
    local cubeHeader = ns.MakeSectionHeader(widget, "Channelers — tank (P1) + cube clicker (P2)")
    cubeHeader:SetPoint("TOPLEFT", tankRow, "BOTTOMLEFT", -4, -14)
    cubeHeader:SetPoint("RIGHT", widget, "RIGHT", -120, 0)  -- leave space for Scan Marks button

    local ROW_H    = 28
    local ICON_SIZE = 20
    local LABEL_X  = 28      -- after the icon
    local TANK_X   = 130     -- slot 2 dropdown
    local CLICK_X  = 262     -- slot 1 dropdown
    local DD_W     = 124

    -- Column headers
    local function ColHeader(text, x)
        local fs = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", cubeHeader, "BOTTOMLEFT", x, -4)
        fs:SetText(text)
        fs:SetTextColor(0.85, 0.85, 0.85)
    end
    ColHeader("Mark",    LABEL_X)
    ColHeader("Tank",    TANK_X)
    ColHeader("Clicker", CLICK_X)

    -- cubeDD[cube.key] = { tank = <dd>, clicker = <dd> }
    local cubeDD = {}

    for cIdx, cube in ipairs(bossData.cubes) do
        local yOff = -22 - (cIdx - 1) * ROW_H

        local row = CreateFrame("Frame", nil, widget)
        row:SetSize(420, ROW_H - 2)
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
            GameTooltip:AddLine("Mark one Hellfire Channeler with this icon in phase 1.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Label + detected mob info
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
        label:SetWidth(TANK_X - LABEL_X - 6)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetText(cube.label)
        detectedLabels[cube.key] = label

        local cubeKey = cube.key

        -- Tank (slot 2) — filtered to tank-capable classes
        local tankDD = ns.CreatePlayerDropdown(row, DD_W, function(playerName)
            ns.BossTemplates.SetAssignment(BOSS_KEY, cubeKey, PHASE_KEY, 2, playerName)
        end)
        tankDD.respectLock = true
        tankDD.classFilter = { WARRIOR = true, DRUID = true, PALADIN = true }
        tankDD:SetPoint("TOPLEFT", row, "TOPLEFT", TANK_X, -2)

        -- Clicker (slot 1) — anyone
        local clickDD = ns.CreatePlayerDropdown(row, DD_W, function(playerName)
            ns.BossTemplates.SetAssignment(BOSS_KEY, cubeKey, PHASE_KEY, 1, playerName)
        end)
        clickDD.respectLock = true
        clickDD:SetPoint("TOPLEFT", row, "TOPLEFT", CLICK_X, -2)

        cubeDD[cube.key] = { tank = tankDD, clicker = clickDD }
    end
    widget._cubeDD = cubeDD

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
        local lines = { "== " .. bossData.name .. " - Tanks & Cube Clickers ==" }
        local tank = ns.BossTemplates.GetAssignment(BOSS_KEY, TANK_KEY, PHASE_KEY, 1) or "?"
        lines[#lines + 1] = "Main Tank: " .. tank
        for _, cube in ipairs(bossData.cubes) do
            local clicker = ns.BossTemplates.GetAssignment(BOSS_KEY, cube.key, PHASE_KEY, 1) or "?"
            local ctank   = ns.BossTemplates.GetAssignment(BOSS_KEY, cube.key, PHASE_KEY, 2) or "?"
            local iconStr = ns.GetRaidIconText(cube.iconIdx)
            lines[#lines + 1] = iconStr .. " Tank: " .. ctank .. " | Cube: " .. clicker
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
            ns.LockedNotice()
            return
        end
        ns.BossTemplates.ClearAssignments(BOSS_KEY)
        if dropdowns[TANK_KEY] then dropdowns[TANK_KEY]:SetSelectedPlayer(nil, nil) end
        for _, c in pairs(widget._cubeDD or {}) do
            if c.tank    then c.tank:SetSelectedPlayer(nil, nil) end
            if c.clicker then c.clicker:SetSelectedPlayer(nil, nil) end
        end
        for _, cube in ipairs(bossData.cubes) do
            local lbl = detectedLabels[cube.key]
            if lbl then lbl:SetText(cube.label) end
        end
    end)

    local autoMarkBtn = ns.MakeSmallButton(widget, "Auto-Mark", 100, 24)
    autoMarkBtn:SetPoint("LEFT", clearBtn, "RIGHT", 6, 0)
    autoMarkBtn:SetScript("OnClick", function()
        ns.AutoMarkBoss(bossData.cubes, bossData.name)
        UpdateDetectedLabels()
    end)
    autoMarkBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Auto-Mark Channelers", 1, 0.82, 0.1)
        GameTooltip:AddLine("One-click marks the 5 Hellfire Channelers with "
            .. "Skull/Cross/Square/Moon/Triangle in the order they're found.",
            0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Needs enemy nameplates on, channelers in range, and raid lead/assist.",
            0.85, 0.55, 0.2, true)
        GameTooltip:Show()
    end)
    autoMarkBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    --------------------------------------------------------------------
    -- Compact view text
    --------------------------------------------------------------------
    function widget.BuildCompactText()
        local lines = {}
        lines[#lines + 1] = "|cFFFFCC00" .. bossData.name .. "|r"

        local tank = ns.BossTemplates.GetAssignment(BOSS_KEY, TANK_KEY, PHASE_KEY, 1) or "-"
        lines[#lines + 1] = "|cFFFF6666Tank|r " .. tank

        for _, cube in ipairs(bossData.cubes) do
            local clicker = ns.BossTemplates.GetAssignment(BOSS_KEY, cube.key, PHASE_KEY, 1) or "-"
            local ctank   = ns.BossTemplates.GetAssignment(BOSS_KEY, cube.key, PHASE_KEY, 2) or "-"
            local iconTex = "|T" .. ns.GetRaidIconTexture(cube.iconIdx) .. ":16|t"
            lines[#lines + 1] = iconTex .. " |cFFFF6666" .. ctank .. "|r / " .. clicker
        end
        return table.concat(lines, "\n")
    end

    --------------------------------------------------------------------
    -- Refresh
    --------------------------------------------------------------------
    function widget.Refresh()
        local roster = ns.BossTemplates.GetPlayerRoster()
        local function classOf(name)
            for _, p in ipairs(roster) do
                if p.name == name then return p.class end
            end
            return "UNKNOWN"
        end
        local function load(dd, key, slot)
            if not dd then return end
            local saved = ns.BossTemplates.GetAssignment(BOSS_KEY, key, PHASE_KEY, slot)
            if saved then dd:SetSelectedPlayer(saved, classOf(saved))
            else dd:SetSelectedPlayer(nil, nil) end
        end

        load(dropdowns[TANK_KEY], TANK_KEY, 1)
        for _, cube in ipairs(bossData.cubes) do
            local c = widget._cubeDD and widget._cubeDD[cube.key]
            if c then
                load(c.tank,    cube.key, 2)
                load(c.clicker, cube.key, 1)
            end
        end
    end

    widget.Refresh()
    return widget
end)
