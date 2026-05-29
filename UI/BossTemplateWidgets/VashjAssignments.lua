----------------------------------------------------------------------
-- RaidLead - UI/BossTemplateWidgets/VashjAssignments.lua
-- Lady Vashj - phase 2 role + core relay assignments.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BOSS_KEY  = "vashj"
local PHASE_KEY = "default"

ns.RegisterBossWidget(BOSS_KEY, function(parent)
    local bossData = ns.BossRegistry:Get(BOSS_KEY)
    if not bossData then return end

    local widget = CreateFrame("Frame", nil, parent)
    widget:SetAllPoints()

    local roleDropdowns = {}
    local coreDropdowns = {}

    if bossData.notes then
        local notes = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        notes:SetPoint("TOPLEFT", widget, "TOPLEFT", 4, -2)
        notes:SetPoint("RIGHT", widget, "RIGHT", -4, 0)
        notes:SetJustifyH("LEFT")
        notes:SetText(bossData.notes)
        notes:SetTextColor(0.6, 0.6, 0.6)
    end

    local roleHeader = ns.MakeSectionHeader(widget, "Core Fight Roles")
    roleHeader:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, -28)
    roleHeader:SetPoint("RIGHT", widget, "RIGHT", -4, 0)

    local ROLE_W = 150
    local DD_W = 190
    local ROW_H = 28

    for idx, role in ipairs(bossData.roles) do
        local row = CreateFrame("Frame", nil, widget)
        row:SetSize(500, ROW_H - 2)
        row:SetPoint("TOPLEFT", roleHeader, "BOTTOMLEFT", 0, -6 - (idx - 1) * ROW_H)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", row, "LEFT", 4, 0)
        label:SetWidth(ROLE_W)
        label:SetJustifyH("LEFT")
        label:SetText(role.label)
        label:SetTextColor(0.9, 0.9, 0.9)

        local hit = CreateFrame("Frame", nil, row)
        hit:SetAllPoints(label)
        hit:EnableMouse(true)
        hit:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(role.label, 1, 0.82, 0)
            GameTooltip:AddLine(role.tip or "", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        hit:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local roleKey = role.key
        local dd = ns.CreatePlayerDropdown(row, DD_W, function(playerName)
            ns.BossTemplates.SetAssignment(BOSS_KEY, roleKey, PHASE_KEY, 1, playerName)
        end)
        dd.respectLock = true
        dd:SetPoint("TOPLEFT", row, "TOPLEFT", ROLE_W + 12, -2)
        roleDropdowns[role.key] = dd
    end

    local roleCount = #bossData.roles
    local coreHeader = ns.MakeSectionHeader(widget, "Core Relay Positions")
    coreHeader:SetPoint("TOPLEFT", roleHeader, "BOTTOMLEFT", 0, -12 - roleCount * ROW_H)
    coreHeader:SetPoint("RIGHT", widget, "RIGHT", -4, 0)

    for idx, pos in ipairs(bossData.corePositions) do
        local row = CreateFrame("Frame", nil, widget)
        row:SetSize(500, ROW_H - 2)
        row:SetPoint("TOPLEFT", coreHeader, "BOTTOMLEFT", 0, -6 - (idx - 1) * ROW_H)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", row, "LEFT", 4, 0)
        label:SetWidth(ROLE_W)
        label:SetJustifyH("LEFT")
        label:SetText(pos.label)
        label:SetTextColor(0.55, 0.85, 1.0)

        local posKey = pos.key
        local dd = ns.CreatePlayerDropdown(row, DD_W, function(playerName)
            ns.BossTemplates.SetAssignment(BOSS_KEY, posKey, PHASE_KEY, 1, playerName)
        end)
        dd.respectLock = true
        dd:SetPoint("TOPLEFT", row, "TOPLEFT", ROLE_W + 12, -2)
        coreDropdowns[pos.key] = dd
    end

    local function BuildAnnounceLines()
        local lines = { "== " .. bossData.name .. " ==" }
        for _, role in ipairs(bossData.roles) do
            local name = ns.BossTemplates.GetAssignment(BOSS_KEY, role.key, PHASE_KEY, 1) or "?"
            lines[#lines + 1] = role.label .. ": " .. name
        end
        lines[#lines + 1] = "----------"
        for _, pos in ipairs(bossData.corePositions) do
            local name = ns.BossTemplates.GetAssignment(BOSS_KEY, pos.key, PHASE_KEY, 1) or "?"
            lines[#lines + 1] = pos.label .. ": " .. name
        end
        return lines
    end

    function widget.BuildCompactText()
        local lines = {}
        lines[#lines + 1] = "|cFFFFCC00" .. bossData.name .. "|r"
        for _, role in ipairs(bossData.roles) do
            local name = ns.BossTemplates.GetAssignment(BOSS_KEY, role.key, PHASE_KEY, 1) or "-"
            lines[#lines + 1] = role.label .. ": " .. name
        end
        lines[#lines + 1] = "|cFF888888---- cores ----|r"
        for _, pos in ipairs(bossData.corePositions) do
            local name = ns.BossTemplates.GetAssignment(BOSS_KEY, pos.key, PHASE_KEY, 1) or "-"
            lines[#lines + 1] = pos.label .. ": " .. name
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
        for _, dd in pairs(roleDropdowns) do dd:SetSelectedPlayer(nil, nil) end
        for _, dd in pairs(coreDropdowns) do dd:SetSelectedPlayer(nil, nil) end
    end)

    local function LoadSlot(key, dd, roster)
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

    function widget.Refresh()
        local roster = ns.BossTemplates.GetPlayerRoster()
        for _, role in ipairs(bossData.roles) do
            LoadSlot(role.key, roleDropdowns[role.key], roster)
        end
        for _, pos in ipairs(bossData.corePositions) do
            LoadSlot(pos.key, coreDropdowns[pos.key], roster)
        end
    end

    widget.Refresh()
    return widget
end)
